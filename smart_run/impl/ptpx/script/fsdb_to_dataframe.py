#!/usr/bin/env python3
"""
Convert FSDB simulation results (functional + power) into pandas
DataFrames using Synopsys `fsdbreport`.

Reads `ptpx_summary.csv` (the index produced by the ptpx flow), runs
`fsdbreport` on every job's functional FSDB and/or power FSDB, parses
the resulting CSVs, converts the values, downsamples by averaging, and
persists per-job CSVs and pickled DataFrames in parallel.

Requires: pandas (Anaconda python recommended), `fsdbreport` on PATH.
"""

from __future__ import annotations

import argparse
import csv
import multiprocessing as mp
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import traceback
from typing import List, Optional, Tuple

import pandas as pd
from pandas import NA


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

POWER_UNITS = {
    "w":  1.0,
    "mw": 1e-3,
    "uw": 1e-6,
    "\u00b5w": 1e-6,   # µW
    "nw": 1e-9,
    "pw": 1e-12,
    "fw": 1e-15,
    "aw": 1e-18,
}

PWR_RE = re.compile(r"^\s*([+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\s*([a-zA-Zµ]+)?\s*$")
TIME_HDR_RE = re.compile(r"Time\((\d+)([a-zA-Z]+)\)")
# Single-letter aliases used by some fsdbreport variants (e.g. "Time(1n)").
_TIME_UNIT_PS = {
    "fs": 0.001, "ps": 1, "ns": 1000, "us": 1_000_000,
    "ms": 1_000_000_000, "s": 1_000_000_000_000,
    "f": 0.001, "p": 1, "n": 1000, "u": 1_000_000, "m": 1_000_000_000,
}

ADD_SIGNAL_RE = re.compile(r"^addSignal\b.*?\s(/\S+)\s*$")


# ---------------------------------------------------------------------------
# rc parsing
# ---------------------------------------------------------------------------

def parse_rc_signals(rc_path: str) -> List[str]:
    """Return list of signal paths found in `addSignal` lines."""
    sigs: List[str] = []
    with open(rc_path) as f:
        for ln in f:
            m = ADD_SIGNAL_RE.match(ln)
            if m:
                sigs.append(m.group(1))
    if not sigs:
        raise RuntimeError(f"no addSignal entries found in rc: {rc_path}")
    return sigs


# ---------------------------------------------------------------------------
# fsdbreport invocation
# ---------------------------------------------------------------------------

def run_fsdbreport(
    fsdb: str,
    out_csv: str,
    period_ns: float,
    start_ns: Optional[int],
    end_ns: Optional[int],
    signals: Optional[List[str]],
) -> None:
    """Invoke fsdbreport via a `-f` config file (signal list may be huge)."""
    if shutil.which("fsdbreport") is None:
        raise RuntimeError("fsdbreport not on PATH; source Verdi setup")
    if not os.path.isfile(fsdb):
        raise RuntimeError(f"fsdb not found: {fsdb}")

    period_str = _fmt_ns(period_ns)
    out_csv_abs = os.path.abspath(out_csv)
    os.makedirs(os.path.dirname(out_csv_abs), exist_ok=True)
    # Place tempdir next to the output (on the same large filesystem) instead
    # of relying on /tmp, which can be small or full on shared hosts.
    tmp_parent = os.path.dirname(out_csv_abs)
    with tempfile.TemporaryDirectory(dir=tmp_parent) as tmp:
        cfg_path = os.path.join(tmp, "fsdbreport.cfg")
        with open(cfg_path, "w") as f:
            f.write(f"-csv -nolog -period {period_str}\n")
            if start_ns is not None:
                f.write(f"-bt {start_ns}ns\n")
            if end_ns is not None:
                f.write(f"-et {end_ns}ns\n")
            f.write(f"-o {out_csv_abs}\n")
            f.write("-s\n")
            if signals:
                for s in signals:
                    f.write(f'"{s}"\n')
            else:
                f.write('"/*"\n')

        proc = subprocess.run(
            ["fsdbreport", os.path.abspath(fsdb), "-f", cfg_path],
            cwd=tmp,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            universal_newlines=True,
        )
    if not os.path.isfile(out_csv_abs) or os.path.getsize(out_csv_abs) == 0:
        raise RuntimeError(
            f"fsdbreport produced no output (exit {proc.returncode}).\n"
            f"--- last fsdbreport output ---\n{proc.stdout[-2000:]}"
        )


def _fmt_ns(period_ns: float) -> str:
    """Format a period in ns as a fsdbreport-friendly time string.
    Uses ps when sub-ns to avoid floating-point artefacts."""
    if period_ns >= 1.0 and float(period_ns).is_integer():
        return f"{int(period_ns)}ns"
    ps = round(period_ns * 1000.0)
    if ps <= 0:
        raise ValueError(f"sample period must be > 0 (got {period_ns} ns)")
    return f"{ps}ps"


# ---------------------------------------------------------------------------
# CSV parsing & value conversion
# ---------------------------------------------------------------------------

def _read_fsdbreport_csv(csv_path: str) -> Tuple[pd.DataFrame, str, int]:
    """Read fsdbreport CSV with all columns as strings.
    Returns (df, time_col_name, time_unit_ps)."""
    df = pd.read_csv(csv_path, dtype=str, keep_default_na=False)
    if df.shape[1] < 2:
        raise RuntimeError(f"unexpected fsdbreport CSV: {csv_path}")
    time_col = df.columns[0]
    m = TIME_HDR_RE.match(time_col)
    if not m:
        raise RuntimeError(f"unrecognised time header '{time_col}' in {csv_path}")
    scale = int(m.group(1))
    unit = m.group(2).lower()
    unit_ps = _TIME_UNIT_PS[unit]
    return df, time_col, int(scale * unit_ps)


def _bin_to_int(v: str):
    """Convert a binary value string to a Python int. x/z → pd.NA."""
    if v == "" or v is None:
        return NA
    s = v.strip()
    if not s:
        return NA
    low = s.lower()
    if "x" in low or "z" in low:
        return NA
    # Strip a leading verilog-style width prefix like 8'b ...
    if "'" in s:
        s = s.split("'", 1)[1]
        if s and s[0].lower() in ("b", "o", "d", "h"):
            base = {"b": 2, "o": 8, "d": 10, "h": 16}[s[0].lower()]
            s = s[1:]
            return int(s, base)
    # Plain binary string (default fsdbreport output)
    if set(s) <= {"0", "1"}:
        return int(s, 2)
    # Fallback: try base 16 then 10
    try:
        return int(s, 16)
    except ValueError:
        return int(s)


def _power_to_w(v: str):
    """Convert a power value string with optional unit suffix to watts (float).
    Empty / x / z → NaN."""
    if v is None:
        return float("nan")
    s = v.strip()
    if not s:
        return float("nan")
    if s.lower() in ("x", "z"):
        return float("nan")
    m = PWR_RE.match(s)
    if not m:
        # Sometimes power dumps as plain float w/o unit → assume W
        try:
            return float(s)
        except ValueError:
            return float("nan")
    num = float(m.group(1))
    unit = (m.group(2) or "w").lower()
    mult = POWER_UNITS.get(unit)
    if mult is None:
        raise RuntimeError(f"unknown power unit '{unit}' in value '{v}'")
    return num * mult


def csv_to_dataframe(csv_path: str, sim_kind: str) -> pd.DataFrame:
    """Load and convert the fsdbreport CSV into a typed DataFrame."""
    df, time_col, unit_ps = _read_fsdbreport_csv(csv_path)
    # Time column → int picoseconds
    df.rename(columns={time_col: "time_ps"}, inplace=True)
    df["time_ps"] = pd.to_numeric(df["time_ps"], errors="coerce").astype("int64") * unit_ps

    value_cols = [c for c in df.columns if c != "time_ps"]
    if sim_kind == "func":
        for c in value_cols:
            df[c] = df[c].map(_bin_to_int).astype(object)
    elif sim_kind == "pwr":
        for c in value_cols:
            df[c] = df[c].map(_power_to_w).astype("float64")
    else:
        raise ValueError(f"sim_kind must be 'func' or 'pwr' (got {sim_kind!r})")
    return df


# ---------------------------------------------------------------------------
# Downsampling (block-mean)
# ---------------------------------------------------------------------------

def downsample(df: pd.DataFrame, n: int) -> pd.DataFrame:
    """Average every `n` consecutive rows (block-mean). Drops trailing
    partial block."""
    if n <= 1:
        return df.reset_index(drop=True)
    if len(df) == 0:
        return df.copy()
    # If we have fewer than n rows, treat the whole frame as one block
    # rather than dropping it (sparse data, e.g. ptpxfsdb at native ns).
    rows = (len(df) // n) * n
    if rows == 0:
        rows = len(df)
    df = df.iloc[:rows].copy()
    grp = df.index // n
    # Convert int-typed object columns to numeric for averaging.
    out = pd.DataFrame()
    out["time_ps"] = df.groupby(grp)["time_ps"].mean().astype("int64")
    for c in df.columns:
        if c == "time_ps":
            continue
        col = df[c]
        if col.dtype == object:
            # Func-sim integers: convert NA → NaN, then mean.
            num = pd.to_numeric(col, errors="coerce")
            out[c] = num.groupby(grp).mean()
        else:
            out[c] = col.groupby(grp).mean()
    out.reset_index(drop=True, inplace=True)
    return out


# ---------------------------------------------------------------------------
# Per-task worker
# ---------------------------------------------------------------------------

def _process_task(task: dict) -> dict:
    """Worker entry point. Returns a status dict."""
    job = task["job"]
    sim_kind = task["sim_kind"]
    fsdb = task["fsdb"]
    out_dir = os.path.abspath(task["out_dir"])
    csv_dir = os.path.join(out_dir, "_csv")
    os.makedirs(csv_dir, exist_ok=True)
    out_csv = os.path.join(csv_dir, f"{job}_{sim_kind}.csv")
    out_pkl = os.path.join(out_dir, f"{job}_{sim_kind}.pkl")

    t0 = time.time()
    try:
        run_fsdbreport(
            fsdb=fsdb,
            out_csv=out_csv,
            period_ns=task["period_ns"],
            start_ns=task["start_ns"],
            end_ns=task["end_ns"],
            signals=task["signals"],
        )
        df = csv_to_dataframe(out_csv, sim_kind)
        df = downsample(df, task["downsample"])
        df.to_pickle(out_pkl)
        return {
            "job": job, "sim_kind": sim_kind, "ok": True,
            "rows": len(df), "cols": df.shape[1],
            "csv": out_csv, "pkl": out_pkl,
            "elapsed": time.time() - t0,
        }
    except Exception as e:
        return {
            "job": job, "sim_kind": sim_kind, "ok": False,
            "error": f"{type(e).__name__}: {e}",
            "tb": traceback.format_exc(),
            "elapsed": time.time() - t0,
        }


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

def _load_summary(path: str, include_failed: bool) -> List[dict]:
    rows = []
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            if not include_failed and r.get("Status", "").upper() != "COMPLETED":
                continue
            rows.append(r)
    if not rows:
        raise RuntimeError(f"no usable rows in {path}")
    return rows


def main():
    ap = argparse.ArgumentParser(
        description="Convert FSDB sim results to pandas DataFrames via fsdbreport."
    )
    ap.add_argument("--summary-csv", required=True,
                    help="ptpx_summary.csv produced by the ptpx flow")
    ap.add_argument("--clk-period", type=int, required=True,
                    help="clock period in nanoseconds (>0)")
    ap.add_argument("--downsample", type=int, required=True,
                    help="downsample rate (>0); sample period = clk/ds ns")
    ap.add_argument("--start", type=int, default=None,
                    help="start time in ns (>=0, optional)")
    ap.add_argument("--end", type=int, default=None,
                    help="end time in ns (>=0, optional)")
    ap.add_argument("--func-rc", default=None,
                    help="rc file with addSignal lines for func sim (optional)")
    ap.add_argument("--pwr-rc", default=None,
                    help="rc file with addSignal lines for pwr sim (optional)")
    ap.add_argument("--mode", required=True, choices=["func-sim", "pwr-sim", "all"])
    ap.add_argument("--processes", type=int, required=True,
                    help="number of parallel worker processes (>0)")
    ap.add_argument("--out-dir", default="./fsdb_dfs",
                    help="output directory (default: ./fsdb_dfs)")
    ap.add_argument("--include-failed", action="store_true",
                    help="also process rows whose Status != COMPLETED")
    ap.add_argument("--only-job", default=None,
                    help="restrict to a single job name (handy for testing)")
    args = ap.parse_args()

    if args.clk_period <= 0:
        sys.exit("error: --clk-period must be > 0")
    if args.downsample <= 0:
        sys.exit("error: --downsample must be > 0")
    if args.processes <= 0:
        sys.exit("error: --processes must be > 0")
    if args.start is not None and args.start < 0:
        sys.exit("error: --start must be >= 0")
    if args.end is not None and args.end < 0:
        sys.exit("error: --end must be >= 0")
    if args.start is not None and args.end is not None and args.end <= args.start:
        sys.exit("error: --end must be > --start")

    period_ns = args.clk_period / args.downsample

    func_signals = parse_rc_signals(args.func_rc) if args.func_rc else None
    pwr_signals = parse_rc_signals(args.pwr_rc) if args.pwr_rc else None

    rows = _load_summary(args.summary_csv, args.include_failed)
    if args.only_job:
        rows = [r for r in rows if r["Job"] == args.only_job]
        if not rows:
            sys.exit(f"error: job '{args.only_job}' not in summary")

    os.makedirs(args.out_dir, exist_ok=True)

    tasks = []
    for r in rows:
        job = r["Job"]
        if args.mode in ("func-sim", "all") and r.get("FSDB"):
            tasks.append(dict(
                job=job, sim_kind="func", fsdb=r["FSDB"],
                out_dir=args.out_dir, period_ns=period_ns,
                start_ns=args.start, end_ns=args.end,
                signals=func_signals, downsample=args.downsample,
            ))
        if args.mode in ("pwr-sim", "all") and r.get("PtpxFsdb"):
            tasks.append(dict(
                job=job, sim_kind="pwr", fsdb=r["PtpxFsdb"],
                out_dir=args.out_dir, period_ns=period_ns,
                start_ns=args.start, end_ns=args.end,
                signals=pwr_signals, downsample=args.downsample,
            ))
    if not tasks:
        sys.exit("error: no tasks to run after filtering")

    print(f"running {len(tasks)} task(s) on {args.processes} process(es); "
          f"period={_fmt_ns(period_ns)}, out_dir={args.out_dir}")
    n_ok = n_fail = 0
    n_workers = min(args.processes, len(tasks))
    if n_workers == 1:
        results = [_process_task(t) for t in tasks]
    else:
        with mp.Pool(n_workers) as pool:
            results = list(pool.imap_unordered(_process_task, tasks))

    for res in results:
        tag = "OK  " if res["ok"] else "FAIL"
        if res["ok"]:
            n_ok += 1
            print(f"  [{tag}] {res['job']:<40s} {res['sim_kind']:<4s} "
                  f"rows={res['rows']:<7d} cols={res['cols']:<6d} "
                  f"{res['elapsed']:.1f}s -> {res['pkl']}")
        else:
            n_fail += 1
            print(f"  [{tag}] {res['job']:<40s} {res['sim_kind']:<4s} "
                  f"{res['elapsed']:.1f}s : {res['error']}")
    print(f"summary: {n_ok} ok, {n_fail} failed")
    sys.exit(0 if n_fail == 0 else 1)


if __name__ == "__main__":
    main()
