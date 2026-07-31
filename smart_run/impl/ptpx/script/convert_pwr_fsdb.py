#!/usr/bin/env python3
"""
Convert PTPX power FSDB files to per-cycle pandas DataFrame pickles.

For each non-mb32 power FSDB under smart_run/impl/ptpx/<testcase>/results/openC906_pwr.fsdb:
1. Extract 29 power signals (aq_core + submodules) via fsdbreport at 100ps period
2. Parse power values to watts (float64)
3. Average every 10 samples -> per-cycle (1ns) power
4. Save as {testcase}_pwr.pkl under ./pwr/

Example:
    python3 convert_pwr_fsdb.py --only csr
    python3 convert_pwr_fsdb.py --processes 4 --skip-exist
"""

from __future__ import annotations

import argparse
import multiprocessing as mp
import os
import sys
import time
import traceback
from typing import Optional

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fsdb_to_pkl import (
    run_fsdbreport,
    _csv_to_dataframe_streaming,
)

CLK_PERIOD_NS = 1.0
SUBSAMPLE = 10
SAMPLE_PERIOD_NS = CLK_PERIOD_NS / SUBSAMPLE
PICKLE_PROTOCOL = 5

TESTCASES = [
    "conv_softmax", "coremark", "ISA_FP", "ISA_LS", "ISA_INT", "ISA_THEAD",
    "debug", "exception", "cache", "MMU", "interrupt", "csr",
]

TARGET_SIGNALS = [
    "/openC906/x_aq_top_0/Pc(x_aq_core)",
    "/openC906/x_aq_top_0/x_aq_core/Pc(x_aq_cp0_top)",
    "/openC906/x_aq_top_0/x_aq_core/Pc(x_aq_idu_top)",
    "/openC906/x_aq_top_0/x_aq_core/Pc(x_aq_ifu_top)",
    "/openC906/x_aq_top_0/x_aq_core/Pc(x_aq_iu_top)",
    "/openC906/x_aq_top_0/x_aq_core/Pc(x_aq_lsu_top)",
    "/openC906/x_aq_top_0/x_aq_core/Pc(x_aq_rtu_top)",
    "/openC906/x_aq_top_0/x_aq_core/Pc(x_aq_vidu_top)",
    "/openC906/x_aq_top_0/x_aq_core/Pc(x_aq_vpu_top)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_vidu_top/Pc(x_aq_vidu_vid_ctrl_fp)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_vidu_top/Pc(x_aq_vidu_vid_dp_fp)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_vidu_top/Pc(x_aq_vidu_vid_gpr_fp)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_vidu_top/Pc(x_aq_vidu_vid_split_fp)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_vidu_top/Pc(x_aq_vidu_vid_wbt_fp)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_dcache_top)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_ag)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_amo_alu)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_amr)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_arb)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_dc)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_dtif)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_icc)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_lfb)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_lm)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_mcic)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_pfb_top)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_rdl)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_stb)",
    "/openC906/x_aq_top_0/x_aq_core/x_aq_lsu_top/Pc(x_aq_lsu_vb)",
]


def _override_cycle_index(df: pd.DataFrame, cycle_ns: float = CLK_PERIOD_NS) -> pd.DataFrame:
    n = len(df)
    df.index = pd.Index(np.arange(n, dtype="float64") * cycle_ns, name="time_ns")
    return df


def _resolve_fsdb(ptpx_root: str, testcase: str) -> str:
    path = os.path.join(ptpx_root, testcase, "results", "openC906_pwr.fsdb")
    if not os.path.isfile(path):
        raise FileNotFoundError(f"FSDB not found for testcase '{testcase}': {path}")
    return path


def convert_one(task: dict) -> dict:
    testcase = task["testcase"]
    fsdb = task["fsdb"]
    out_pkl = task["out_pkl"]
    csv_dir = task["csv_dir"]
    start_ns = task["start_ns"]
    end_ns = task["end_ns"]
    skip_exist = task["skip_exist"]

    t0 = time.time()
    try:
        if skip_exist and os.path.isfile(out_pkl):
            return {
                "testcase": testcase, "ok": True, "skipped": True,
                "pkl": out_pkl, "elapsed": time.time() - t0,
            }

        os.makedirs(csv_dir, exist_ok=True)
        os.makedirs(os.path.dirname(out_pkl), exist_ok=True)

        out_csv = os.path.join(csv_dir, f"{testcase}_pwr.csv")

        run_fsdbreport(
            fsdb=fsdb,
            out_csv=out_csv,
            period_ns=SAMPLE_PERIOD_NS,
            start_ns=start_ns,
            end_ns=end_ns,
            signals=TARGET_SIGNALS,
        )

        df = _csv_to_dataframe_streaming(out_csv, downsample=SUBSAMPLE, rm_prefix=True)
        df.fillna(0, inplace=True)
        df = _override_cycle_index(df, CLK_PERIOD_NS)
        df.to_pickle(out_pkl, protocol=PICKLE_PROTOCOL)

        try:
            os.remove(out_csv)
        except OSError:
            pass

        return {
            "testcase": testcase, "ok": True, "skipped": False,
            "pkl": out_pkl, "rows": len(df), "cols": df.shape[1],
            "elapsed": time.time() - t0,
        }
    except Exception as e:
        return {
            "testcase": testcase, "ok": False, "skipped": False,
            "pkl": out_pkl, "error": f"{type(e).__name__}: {e}",
            "tb": traceback.format_exc(),
            "elapsed": time.time() - t0,
        }


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Convert PTPX power FSDBs to per-cycle DataFrame pickles."
    )
    ap.add_argument("--ptpx-root", default=None,
                     help="root dir containing <testcase>/results/openC906_pwr.fsdb "
                          "(default: parent of script dir)")
    ap.add_argument("--out-dir", default="./pwr",
                     help="output directory for {testcase}_pwr.pkl (default: ./pwr)")
    ap.add_argument("--csv-dir", default=None,
                     help="intermediate CSV directory (default: <out-dir>/_csv)")
    ap.add_argument("--processes", type=int, default=1,
                     help="parallel worker processes (default: 1)")
    ap.add_argument("--start", type=int, default=None,
                     help="start time in ns (optional)")
    ap.add_argument("--end", type=int, default=None,
                     help="end time in ns (optional)")
    ap.add_argument("--skip-exist", action="store_true",
                     help="skip testcases whose pkl already exists")
    ap.add_argument("--only", default=None,
                     help="restrict to a single testcase")
    args = ap.parse_args()

    if args.processes <= 0:
        sys.exit("error: --processes must be > 0")
    if args.start is not None and args.start < 0:
        sys.exit("error: --start must be >= 0")
    if args.end is not None and args.end < 0:
        sys.exit("error: --end must be >= 0")
    if args.start is not None and args.end is not None and args.end <= args.start:
        sys.exit("error: --end must be > --start")

    if args.ptpx_root is None:
        args.ptpx_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if args.csv_dir is None:
        args.csv_dir = os.path.join(args.out_dir, "_csv")

    testcases = TESTCASES
    if args.only:
        if args.only not in TESTCASES:
            sys.exit(f"error: testcase '{args.only}' not in {TESTCASES}")
        testcases = [args.only]

    tasks = []
    for tc in testcases:
        try:
            fsdb = _resolve_fsdb(args.ptpx_root, tc)
        except FileNotFoundError as e:
            print(f"SKIP {tc}: {e}")
            continue
        tasks.append(dict(
            testcase=tc,
            fsdb=fsdb,
            out_pkl=os.path.join(args.out_dir, f"{tc}_pwr.pkl"),
            csv_dir=args.csv_dir,
            start_ns=args.start,
            end_ns=args.end,
            skip_exist=args.skip_exist,
        ))

    if not tasks:
        sys.exit("error: no FSDB files found")

    total = len(tasks)
    n_workers = min(args.processes, total)
    print(f"processing {total} testcase(s) on {n_workers} process(es); "
          f"sample_period={SAMPLE_PERIOD_NS}ns, out_dir={args.out_dir}")

    n_ok = n_skip = n_fail = 0
    done = 0

    def report(res: dict) -> None:
        nonlocal done, n_ok, n_skip, n_fail
        done += 1
        tc = res["testcase"]
        el = res["elapsed"]
        if res.get("skipped"):
            n_skip += 1
            print(f"[{done}/{total}] SKIP {tc:<20s} {el:.1f}s -> {res['pkl']}", flush=True)
        elif res["ok"]:
            n_ok += 1
            print(f"[{done}/{total}] OK   {tc:<20s} rows={res['rows']:<8d} "
                  f"cols={res['cols']:<4d} {el:.1f}s -> {res['pkl']}", flush=True)
        else:
            n_fail += 1
            print(f"[{done}/{total}] FAIL {tc:<20s} {el:.1f}s : {res['error']}", flush=True)
            if "tb" in res:
                print(res["tb"], flush=True)

    if n_workers == 1:
        for task in tasks:
            report(convert_one(task))
    else:
        with mp.Pool(n_workers) as pool:
            for result in pool.imap_unordered(convert_one, tasks):
                report(result)

    print(f"summary: {n_ok} ok, {n_skip} skipped, {n_fail} failed")
    sys.exit(0 if n_fail == 0 else 1)


if __name__ == "__main__":
    main()
