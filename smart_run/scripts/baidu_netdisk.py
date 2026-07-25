#!/usr/bin/env python3
"""Upload/download files or folders to/from Baidu Netdisk via BaiduPCS-Go.

Requires BaiduPCS-Go on PATH (https://github.com/qjfoidnh/BaiduPCS-Go):
    brew install baidupcs-go        # or download a release binary

If not logged in (uploads need both BDUSS and STOKEN), the script launches
Chrome with a throwaway profile pointed at pan.baidu.com, waits for you to
log in, pulls the BDUSS/STOKEN cookies out via the Chrome DevTools Protocol,
and runs `BaiduPCS-Go login` automatically. Stdlib only.

Usage:
    python3 baidu_netdisk.py upload   <local_path>...  <remote_dir>
    python3 baidu_netdisk.py download <remote_path>... [--saveto DIR]
    python3 baidu_netdisk.py login            # force re-login via browser
"""
import argparse
import base64
import http.client
import json
import os
import re
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import time

DEBUG_PORT = 9922
LOGIN_URL = "https://pan.baidu.com/"

# ---------------------------------------------------------------- BaiduPCS-Go

def pcs(*args, capture=False):
    if capture:
        return subprocess.run(["BaiduPCS-Go", *args], capture_output=True, text=True)
    return subprocess.run(["BaiduPCS-Go", *args])


def check_installed():
    if shutil.which("BaiduPCS-Go") is None:
        sys.exit("ERROR: BaiduPCS-Go not found on PATH.\n"
                 "Install it first, e.g.:\n"
                 "  brew install baidupcs-go\n"
                 "or grab a release from https://github.com/qjfoidnh/BaiduPCS-Go/releases")


def logged_in():
    r = pcs("who", capture=True)
    if r.returncode != 0:
        return False
    m = re.search(r"uid:\s*(\d+)", r.stdout)
    return bool(m) and m.group(1) != "0"

# ------------------------------------------------- minimal CDP websocket client

def ws_connect(url):
    m = re.match(r"ws://([^:/]+):(\d+)(/.*)", url)
    host, port, path = m.group(1), int(m.group(2)), m.group(3)
    sock = socket.create_connection((host, port), timeout=10)
    key = base64.b64encode(os.urandom(16)).decode()
    sock.sendall((f"GET {path} HTTP/1.1\r\nHost: {host}:{port}\r\n"
                  "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                  f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
    # read handshake response headers
    buf = b""
    while b"\r\n\r\n" not in buf:
        buf += sock.recv(4096)
    if b" 101 " not in buf.split(b"\r\n", 1)[0]:
        raise RuntimeError("websocket handshake failed")
    return sock


def ws_send(sock, text):
    payload = text.encode()
    mask = os.urandom(4)
    header = b"\x81"  # FIN + text frame
    n = len(payload)
    if n < 126:
        header += struct.pack("B", 0x80 | n)
    elif n < 65536:
        header += struct.pack("!BH", 0x80 | 126, n)
    else:
        header += struct.pack("!BQ", 0x80 | 127, n)
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    sock.sendall(header + mask + masked)


def _recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise RuntimeError("websocket closed")
        buf += chunk
    return buf


def ws_recv(sock):
    b1, b2 = _recv_exact(sock, 2)
    n = b2 & 0x7F
    if n == 126:
        n = struct.unpack("!H", _recv_exact(sock, 2))[0]
    elif n == 127:
        n = struct.unpack("!Q", _recv_exact(sock, 8))[0]
    return _recv_exact(sock, n)


def cdp_call(sock, msg_id, method, params=None):
    ws_send(sock, json.dumps({"id": msg_id, "method": method, "params": params or {}}))
    while True:
        resp = json.loads(ws_recv(sock))
        if resp.get("id") == msg_id:
            return resp.get("result", {})

# ------------------------------------------------------------- browser login

CHROME_CANDIDATES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    shutil.which("google-chrome") or "",
    shutil.which("chromium") or "",
]


def find_chrome():
    for c in CHROME_CANDIDATES:
        if c and os.path.exists(c):
            return c
    sys.exit("ERROR: no Chrome/Chromium/Edge found for the login flow.")


def browser_login():
    chrome = find_chrome()
    profile = tempfile.mkdtemp(prefix="baidu_login_")
    print("Opening a browser window — please log in to Baidu Netdisk...")
    proc = subprocess.Popen(
        [chrome, f"--remote-debugging-port={DEBUG_PORT}", f"--user-data-dir={profile}",
         "--no-first-run", "--no-default-browser-check", LOGIN_URL],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        # wait for the CDP endpoint, get the browser-level websocket URL
        ws_url = None
        for _ in range(60):
            try:
                conn = http.client.HTTPConnection("127.0.0.1", DEBUG_PORT, timeout=2)
                conn.request("GET", "/json/version")
                ws_url = json.loads(conn.getresponse().read())["webSocketDebuggerUrl"]
                break
            except OSError:
                time.sleep(0.5)
        if not ws_url:
            sys.exit("ERROR: could not reach Chrome DevTools endpoint.")

        sock = ws_connect(ws_url)
        deadline = time.time() + 600  # 10 min to log in
        while time.time() < deadline:
            cookies = cdp_call(sock, 1, "Storage.getCookies").get("cookies", [])
            jar = {c["name"]: c["value"] for c in cookies if c["domain"].endswith("baidu.com")}
            if "BDUSS" in jar and "STOKEN" in jar:
                print("Got BDUSS and STOKEN — logging in BaiduPCS-Go...")
                r = pcs("login", f"-bduss={jar['BDUSS']}", f"-stoken={jar['STOKEN']}",
                        capture=True)
                print(r.stdout.strip())
                if r.returncode != 0 or not logged_in():
                    sys.exit("ERROR: BaiduPCS-Go login failed:\n" + r.stdout + r.stderr)
                return
            time.sleep(2)
        sys.exit("ERROR: timed out waiting for Baidu login (10 min).")
    finally:
        proc.terminate()
        shutil.rmtree(profile, ignore_errors=True)

# --------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    up = sub.add_parser("upload", help="upload local files/folders to a netdisk dir")
    up.add_argument("paths", nargs="+", help="local paths... followed by the remote dir")
    dl = sub.add_parser("download", help="download netdisk files/folders")
    dl.add_argument("paths", nargs="+", help="remote paths")
    dl.add_argument("--saveto", default=".", help="local destination dir (default: .)")
    sub.add_parser("login", help="force re-login via browser")
    args = ap.parse_args()

    check_installed()

    if args.cmd == "login" or not logged_in():
        if args.cmd != "login":
            print("Not logged in to Baidu Netdisk.")
        browser_login()
        if args.cmd == "login":
            return

    if args.cmd == "upload":
        if len(args.paths) < 2:
            ap.error("upload needs at least one local path and the remote dir")
        *locals_, remote = args.paths
        for p in locals_:
            if not os.path.exists(p):
                sys.exit(f"ERROR: local path not found: {p}")
        rc = pcs("upload", *locals_, remote).returncode
    else:
        rc = pcs("download", *args.paths, "--saveto", args.saveto, "--ow").returncode
    sys.exit(rc)


if __name__ == "__main__":
    main()
