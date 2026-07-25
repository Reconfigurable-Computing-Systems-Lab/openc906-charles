#!/usr/bin/env bash
# One-shot repo setup: pulls the csi-nn2 submodule and restores the
# smart_run/work + smart_run/work_par simulation artifacts and the NN model
# artifacts (smart_run/tests/cases/model_compiled, hhb/model) from Baidu Netdisk.
#
# Prerequisites:
#   - BaiduPCS-Go on PATH (brew install baidupcs-go, or a release binary).
#   - python3 for the netdisk helper.
#   - A graphical session ($DISPLAY) so the login browser can open. If you
#     are not already logged in, smart_run/onnx_sim_lib/baidu_netdisk.py launches
#     Chrome/Chromium/Edge (or Firefox as a fallback) pointed at
#     pan.baidu.com and runs `BaiduPCS-Go login` automatically once you log
#     in. Use `./setup_repo.sh --login` to force a browser re-login before
#     downloading.
set -euo pipefail

# ---- args & deps -----------------------------------------------------------
FORCE_LOGIN=0
for arg in "$@"; do
  case "$arg" in
    --login) FORCE_LOGIN=1 ;;
    -h|--help) echo "Usage: $0 [--login]"; exit 0 ;;
    *) echo "setup_repo.sh: unknown argument: $arg" >&2; exit 2 ;;
  esac
done

command -v BaiduPCS-Go >/dev/null 2>&1 || {
  echo "ERROR: BaiduPCS-Go not found on PATH." >&2
  echo "  brew install baidupcs-go  or  https://github.com/qjfoidnh/BaiduPCS-Go/releases" >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found on PATH." >&2; exit 1; }
if [ -z "${DISPLAY:-}" ]; then
  echo "WARNING: \$DISPLAY is unset — the login browser needs a graphical session." >&2
  echo "         Re-run from an X/VNC terminal (or `ssh -X`)." >&2
fi

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="/dev_data/openc906-charles"
TMP_DL="$REPO_ROOT/.netdisk_dl"
NETDISK="python3 $REPO_ROOT/smart_run/onnx_sim_lib/baidu_netdisk.py"

echo "==> [1/3] Pulling csi-nn2 submodule"
git -C "$REPO_ROOT" submodule update --init --recursive csi-nn2

echo "==> [2/3] Downloading tarballs from Baidu Netdisk ($REMOTE_DIR)"
mkdir -p "$TMP_DL"
if [ "$FORCE_LOGIN" = 1 ]; then
  echo "  (forced re-login via browser)"
  $NETDISK login
fi
$NETDISK download \
    "$REMOTE_DIR/work.tar.gz" "$REMOTE_DIR/work_par.tar.gz" \
    "$REMOTE_DIR/model_compiled.tar.gz" "$REMOTE_DIR/hhb_model.tar.gz" \
    --saveto "$TMP_DL"

echo "==> [3/3] Extracting"
tar xzf "$TMP_DL/work.tar.gz" -C "$REPO_ROOT/smart_run"
tar xzf "$TMP_DL/work_par.tar.gz" -C "$REPO_ROOT/smart_run"
tar xzf "$TMP_DL/model_compiled.tar.gz" -C "$REPO_ROOT/smart_run/tests/cases"
tar xzf "$TMP_DL/hhb_model.tar.gz" -C "$REPO_ROOT/hhb"
rm -rf "$TMP_DL"

echo "Done. Restored: smart_run/work, smart_run/work_par, smart_run/tests/cases/model_compiled, hhb/model"
