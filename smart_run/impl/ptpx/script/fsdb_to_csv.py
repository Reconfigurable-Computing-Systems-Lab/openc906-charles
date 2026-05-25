#!/usr/bin/env python3
"""
Convert FSDB simulation results into fsdbreport CSV files.

Reads ptpx_summary.csv, runs Synopsys fsdbreport on every selected job's
functional FSDB and/or power FSDB, and writes per-job CSVs under
<out-dir>/_csv.

Example:
    ./fsdb_to_csv.py --summary-csv ../ptpx_summary.csv --clk-period 1 \
        --downsample 10 --func-rc func.rc --mode func-sim \
        --processes 8 --out-dir ../funcsim_db

    ./fsdb_to_csv.py --summary-csv ../ptpx_summary.csv --clk-period 1 \
        --downsample 1 --pwr-rc pwr.rc --mode pwr-sim \
        --processes 8 --out-dir ../pwrsim_db
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
from typing import List, Optional


ADD_SIGNAL_RE = re.compile(r"^addSignal\b.*?\s(/\S+)\s*$")
HOLD_SCOPE_SIGNAL_RE = re.compile(r"^addSignal\b.*?\s-holdScope\s+(\S+)\s*$")


def _parse_rc_signals(rc_path: str) -> List[str]:
    """Return list of signal paths found in addSignal lines."""
    sigs: List[str] = []
    current_scope: Optional[str] = None
    with open(rc_path) as f:
        for ln in f:
            m = ADD_SIGNAL_RE.match(ln)
            if m:
                sig = m.group(1)
                sigs.append(sig)
                current_scope = sig.rsplit("/", 1)[0]
                continue
            m = HOLD_SCOPE_SIGNAL_RE.match(ln)
            if m and current_scope:
                sigs.append(f"{current_scope}/{m.group(1)}")
    if not sigs:
        raise RuntimeError(f"no addSignal entries found in rc: {rc_path}")
    return sigs


def _fmt_ns(period_ns: float) -> str:
    """Format a period in ns as a fsdbreport-friendly time string."""
    if period_ns >= 1.0 and float(period_ns).is_integer():
        return f"{int(period_ns)}ns"
    ps = round(period_ns * 1000.0)
    if ps <= 0:
        raise ValueError(f"sample period must be > 0 (got {period_ns} ns)")
    return f"{ps}ps"


def run_fsdbreport(
    fsdb: str,
    out_csv: str,
    period_ns: float,
    start_ns: Optional[int],
    end_ns: Optional[int],
    signals: Optional[List[str]],
) -> None:
    """Invoke fsdbreport via a -f config file (signal list may be huge)."""
    if shutil.which("fsdbreport") is None:
        raise RuntimeError("fsdbreport not on PATH; source Verdi setup")
    if not os.path.isfile(fsdb):
        raise RuntimeError(f"fsdb not found: {fsdb}")

    period_str = _fmt_ns(period_ns)
    out_csv_abs = os.path.abspath(out_csv)
    os.makedirs(os.path.dirname(out_csv_abs), exist_ok=True)
    # Put the temp config beside the output so shared-host /tmp limits do not
    # block large jobs.
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


def _process_task(task: dict) -> dict:
    job = task["job"]
    sim_kind = task["sim_kind"]
    fsdb = task["fsdb"]
    out_dir = os.path.abspath(task["out_dir"])
    csv_dir = os.path.join(out_dir, "_csv")
    os.makedirs(csv_dir, exist_ok=True)
    out_csv = os.path.join(csv_dir, f"{job}_{sim_kind}.csv")

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
        return {
            "job": job, "sim_kind": sim_kind, "ok": True,
            "csv": out_csv, "elapsed": time.time() - t0,
        }
    except Exception as e:
        return {
            "job": job, "sim_kind": sim_kind, "ok": False,
            "error": f"{type(e).__name__}: {e}",
            "tb": traceback.format_exc(),
            "elapsed": time.time() - t0,
        }


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Convert FSDB sim results to fsdbreport CSV files."
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
                    help="rc file with addSignal lines for func sim")
    ap.add_argument("--pwr-rc", default=None,
                    help="rc file with addSignal lines for pwr sim")
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
    if args.mode in ("func-sim", "all") and not args.func_rc:
        sys.exit("error: --func-rc is required when --mode is func-sim or all")
    if args.mode in ("pwr-sim", "all") and not args.pwr_rc:
        sys.exit("error: --pwr-rc is required when --mode is pwr-sim or all")

    period_ns = args.clk_period / args.downsample
    func_signals = (
        _parse_rc_signals(args.func_rc)
        if args.mode in ("func-sim", "all")
        else None
    )
    pwr_signals = (
        _parse_rc_signals(args.pwr_rc)
        if args.mode in ("pwr-sim", "all")
        else None
    )

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
                signals=func_signals,
            ))
        if args.mode in ("pwr-sim", "all") and r.get("PtpxFsdb"):
            tasks.append(dict(
                job=job, sim_kind="pwr", fsdb=r["PtpxFsdb"],
                out_dir=args.out_dir, period_ns=period_ns,
                start_ns=args.start, end_ns=args.end,
                signals=pwr_signals,
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
                  f"{res['elapsed']:.1f}s -> {res['csv']}")
        else:
            n_fail += 1
            print(f"  [{tag}] {res['job']:<40s} {res['sim_kind']:<4s} "
                  f"{res['elapsed']:.1f}s : {res['error']}")
    print(f"summary: {n_ok} ok, {n_fail} failed")
    sys.exit(0 if n_fail == 0 else 1)


if __name__ == "__main__":
    main()
