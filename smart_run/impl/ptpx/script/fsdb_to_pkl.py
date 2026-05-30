#!/usr/bin/env python3
"""
Convert FSDB simulation results directly into pickled pandas DataFrames.

Reads ptpx_summary.csv, runs Synopsys fsdbreport for every selected job's
functional FSDB and/or power FSDB, converts each generated CSV to a pickle, and
removes that CSV immediately after its pickle is written successfully.

Example:
    ./fsdb_to_pkl.py --summary-csv ../ptpx_summary.csv --clk-period 1 \
        --downsample 10 --func-rc func.rc --mode func-sim \
        --processes 8 --out-dir ../funcsim_db --rm-prefix

    ./fsdb_to_pkl.py --summary-csv ../ptpx_summary.csv --clk-period 1 \
        --downsample 1 --pwr-rc pwr.rc --mode pwr-sim \
        --processes 8 --out-dir ../pwrsim_db --rm-prefix
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
from typing import Dict, Iterable, List, Optional

import numpy as np
import pandas as pd


ADD_SIGNAL_RE = re.compile(r"^addSignal\b.*?\s(/\S+)\s*$")
HOLD_SCOPE_SIGNAL_RE = re.compile(r"^addSignal\b.*?\s-holdScope\s+(\S+)\s*$")

POWER_UNITS = {
    "w": 1.0,
    "mw": 1e-3,
    "uw": 1e-6,
    "\u00b5w": 1e-6,
    "nw": 1e-9,
    "pw": 1e-12,
    "fw": 1e-15,
    "aw": 1e-18,
}

TIME_HDR_RE = re.compile(r"Time\((\d+)([a-zA-Z]+)\)")
POWER_VALUE_RE = re.compile(
    r"^[+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\s*"
    r"(?:w|mw|uw|\u00b5w|nw|pw|fw|aw)$",
    re.IGNORECASE,
)
NUM_UNIT_RE = re.compile(
    r"^\s*([+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\s*([a-zA-Z\u00b5]+)?\s*$"
)
INF_RE = re.compile(r"^[+-]?(?:inf|infinity)(?:\s*[a-zA-Z\u00b5]+)?$", re.IGNORECASE)

TIME_UNIT_NS = {
    "fs": 1e-6,
    "ps": 1e-3,
    "ns": 1.0,
    "us": 1_000.0,
    "ms": 1_000_000.0,
    "s": 1_000_000_000.0,
    "f": 1e-6,
    "p": 1e-3,
    "n": 1.0,
    "u": 1_000.0,
    "m": 1_000_000.0,
}
MISSING_VALUES = {"", "nan", "na", "n/a", "none", "null", "x", "z"}
STREAM_WINDOWS_PER_CHUNK = 5000


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
    # Keep the temp config beside the output to avoid shared-host /tmp limits.
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
                for sig in signals:
                    f.write(f'"{sig}"\n')
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
        for row in csv.DictReader(f):
            if not include_failed and row.get("Status", "").upper() != "COMPLETED":
                continue
            rows.append(row)
    if not rows:
        raise RuntimeError(f"no usable rows in {path}")
    return rows


def _time_unit_ns(time_col: str) -> float:
    m = TIME_HDR_RE.match(time_col)
    if not m:
        raise RuntimeError(f"unrecognised time header '{time_col}'")
    scale = int(m.group(1))
    unit = m.group(2).lower()
    if unit not in TIME_UNIT_NS:
        raise RuntimeError(f"unknown time unit '{unit}' in header '{time_col}'")
    return scale * TIME_UNIT_NS[unit]


def _flatten_values(values: pd.DataFrame) -> pd.Series:
    return values.stack(future_stack=True).astype("string").str.strip()


def _missing_mask(values: pd.Series) -> pd.Series:
    return values.str.lower().isin(MISSING_VALUES)


def _contains_fatal_inf(values: pd.DataFrame) -> bool:
    flat = _flatten_values(values)
    return flat.str.match(INF_RE, na=False).any()


def _contains_power_unit(values: pd.DataFrame) -> bool:
    flat = _flatten_values(values)
    return flat.str.match(POWER_VALUE_RE, na=False).any()


def _normalise_unit(unit: str) -> str:
    unit = unit.lower()
    if unit == "\u00b5w":
        return "uw"
    return unit


def _convert_power_values(values: pd.DataFrame) -> pd.DataFrame:
    flat = _flatten_values(values)
    missing = _missing_mask(flat)
    parsed = flat.str.extract(NUM_UNIT_RE)

    nums = pd.to_numeric(parsed[0], errors="coerce")
    units = parsed[1].fillna("w").map(_normalise_unit)

    known_units = set(POWER_UNITS)
    unknown = (~missing) & nums.notna() & ~units.isin(known_units)
    if unknown.any():
        bad = flat[unknown].iloc[0]
        raise RuntimeError(f"unknown power unit in value '{bad}'")

    multipliers = units.map(POWER_UNITS).astype("float64")
    watts = nums * multipliers
    watts[missing | nums.isna()] = 0.0
    return watts.unstack().astype("float64")


def _normalise_binary_string(value: str) -> str:
    if value is None or pd.isna(value):
        return "0"
    s = str(value).strip()
    if s.lower() in MISSING_VALUES:
        return "0"
    s = re.sub(r"[xXzZ]", "0", s).replace("_", "")
    if not s:
        return "0"
    if set(s) <= {"0", "1"}:
        return s
    raise RuntimeError(f"non-binary value after x/z normalization: {value!r}")


def _convert_integer_values(values: pd.DataFrame) -> pd.DataFrame:
    normalized = values.astype("string").map(_normalise_binary_string)
    return normalized.map(lambda s: int(s, 2)).astype(object)


def _remove_common_prefix(columns: Iterable[str]) -> Dict[str, str]:
    cols = [str(col) for col in columns]
    if len(cols) < 2:
        return {}

    common = os.path.commonprefix(cols)
    if not common:
        return {}

    cut = max(common.rfind(delim) for delim in ("/", ".", "_"))
    prefix = common[: cut + 1] if cut >= 0 else common
    if not prefix:
        return {}

    renamed = {col: col[len(prefix) :] for col in cols if col.startswith(prefix)}
    if len(renamed) != len(cols) or any(not value for value in renamed.values()):
        return {}
    return renamed


def _downsample(df: pd.DataFrame, window: int) -> pd.DataFrame:
    if window <= 1:
        return df
    if len(df) == 0:
        return df.copy()

    rows = (len(df) // window) * window
    if rows == 0:
        rows = len(df)

    work = df.iloc[:rows].reset_index()
    groups = np.arange(len(work)) // window
    out = work.groupby(groups, sort=False).mean(numeric_only=False)
    out.set_index("time_ns", inplace=True)
    return out


def _convert_integer_values_cached(
    values: pd.DataFrame,
    cache: Dict[str, float],
) -> pd.DataFrame:
    out = {}
    for col in values.columns:
        series = values[col]
        missing = [value for value in pd.unique(series) if value not in cache]
        for value in missing:
            cache[value] = float(int(_normalise_binary_string(value), 2))
        out[col] = series.map(cache)
    return pd.DataFrame(out, index=values.index).astype("float64")


def _convert_chunk_values(
    values: pd.DataFrame,
    has_power_unit: bool,
    integer_cache: Optional[Dict[str, float]] = None,
) -> pd.DataFrame:
    if has_power_unit:
        if _contains_fatal_inf(values):
            raise RuntimeError("fatal infinity value found in CSV")
        return _convert_power_values(values)
    if integer_cache is not None:
        return _convert_integer_values_cached(values, integer_cache)
    return _convert_integer_values(values)


def _downsample_converted_chunk(data: pd.DataFrame, time_ns: pd.Series, window: int) -> pd.DataFrame:
    data.index = pd.Index(time_ns, name="time_ns")
    work = data.reset_index()
    groups = np.arange(len(work)) // window
    out = work.groupby(groups, sort=False).mean(numeric_only=False)
    out.set_index("time_ns", inplace=True)
    return out


def _csv_to_dataframe_streaming(csv_path: str, downsample: int, rm_prefix: bool) -> pd.DataFrame:
    chunk_rows = downsample * STREAM_WINDOWS_PER_CHUNK
    reader = pd.read_csv(csv_path, dtype=str, keep_default_na=False, chunksize=chunk_rows)
    pieces: List[pd.DataFrame] = []
    carry = pd.DataFrame()
    time_col = None
    has_power_unit = None
    integer_cache: Dict[str, float] = {}
    total_rows = 0

    for chunk in reader:
        if time_col is None:
            if chunk.shape[1] < 2:
                raise RuntimeError(f"expected at least one time column and one data column: {csv_path}")
            time_col = chunk.columns[0]

        total_rows += len(chunk)
        if not carry.empty:
            chunk = pd.concat([carry, chunk], ignore_index=True)
            carry = pd.DataFrame()

        rows = (len(chunk) // downsample) * downsample
        if rows == 0:
            carry = chunk
            continue

        work = chunk.iloc[:rows].copy()
        if rows < len(chunk):
            carry = chunk.iloc[rows:].copy()

        values = work.drop(columns=[time_col])
        if has_power_unit is None:
            has_power_unit = _contains_power_unit(values)

        time_ns = pd.to_numeric(work[time_col], errors="raise") * _time_unit_ns(time_col)
        data = _convert_chunk_values(values, bool(has_power_unit), integer_cache)
        if rm_prefix:
            data.rename(columns=_remove_common_prefix(data.columns), inplace=True)
        pieces.append(_downsample_converted_chunk(data, time_ns, downsample))

    if time_col is None:
        raise RuntimeError(f"empty CSV: {csv_path}")

    if not carry.empty and not pieces:
        values = carry.drop(columns=[time_col])
        if has_power_unit is None:
            has_power_unit = _contains_power_unit(values)
        time_ns = pd.to_numeric(carry[time_col], errors="raise") * _time_unit_ns(time_col)
        data = _convert_chunk_values(values, bool(has_power_unit), integer_cache)
        if rm_prefix:
            data.rename(columns=_remove_common_prefix(data.columns), inplace=True)
        pieces.append(_downsample_converted_chunk(data, time_ns, downsample))

    if not pieces:
        raise RuntimeError(f"no complete downsample windows found in CSV: {csv_path}")

    out = pd.concat(pieces)
    if not bool(has_power_unit):
        out = out.astype(object)
    return out


def csv_to_dataframe(csv_path: str, downsample: int, rm_prefix: bool) -> pd.DataFrame:
    if downsample > 1:
        return _csv_to_dataframe_streaming(csv_path, downsample, rm_prefix)

    raw = pd.read_csv(csv_path, dtype=str, keep_default_na=False)
    if raw.shape[1] < 2:
        raise RuntimeError(f"expected at least one time column and one data column: {csv_path}")

    time_col = raw.columns[0]
    time_ns = pd.to_numeric(raw[time_col], errors="raise") * _time_unit_ns(time_col)
    values = raw.drop(columns=[time_col])

    if _contains_fatal_inf(values):
        raise RuntimeError("fatal infinity value found in CSV")

    if _contains_power_unit(values):
        data = _convert_power_values(values)
    else:
        data = _convert_integer_values(values)

    data.index = pd.Index(time_ns, name="time_ns")
    if rm_prefix:
        data.rename(columns=_remove_common_prefix(data.columns), inplace=True)

    return _downsample(data, downsample)


def _process_task(task: dict) -> dict:
    job = task["job"]
    sim_kind = task["sim_kind"]
    out_dir = os.path.abspath(task["out_dir"])
    csv_dir = os.path.join(out_dir, "_csv")
    out_csv = os.path.join(csv_dir, f"{job}_{sim_kind}.csv")
    out_pkl = os.path.join(out_dir, f"{job}_{sim_kind}.pkl")

    t0 = time.time()
    try:
        if task["skip_exist"] and os.path.isfile(out_pkl):
            return {
                "job": job,
                "sim_kind": sim_kind,
                "ok": True,
                "skipped": True,
                "csv": out_csv,
                "pkl": out_pkl,
                "elapsed": time.time() - t0,
            }

        os.makedirs(csv_dir, exist_ok=True)
        os.makedirs(out_dir, exist_ok=True)
        run_fsdbreport(
            fsdb=task["fsdb"],
            out_csv=out_csv,
            period_ns=task["period_ns"],
            start_ns=task["start_ns"],
            end_ns=task["end_ns"],
            signals=task["signals"],
        )
        df = csv_to_dataframe(out_csv, task["downsample"], task["rm_prefix"])
        df.fillna(0, inplace=True)
        df.to_pickle(out_pkl)
        os.remove(out_csv)
        return {
            "job": job,
            "sim_kind": sim_kind,
            "ok": True,
            "skipped": False,
            "csv": out_csv,
            "pkl": out_pkl,
            "rows": len(df),
            "cols": df.shape[1],
            "elapsed": time.time() - t0,
        }
    except Exception as e:
        return {
            "job": job,
            "sim_kind": sim_kind,
            "ok": False,
            "skipped": False,
            "csv": out_csv,
            "pkl": out_pkl,
            "error": f"{type(e).__name__}: {e}",
            "tb": traceback.format_exc(),
            "elapsed": time.time() - t0,
        }


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Convert FSDB sim results directly to pandas DataFrame pickles."
    )
    ap.add_argument("--summary-csv", required=True, help="ptpx_summary.csv produced by the ptpx flow")
    ap.add_argument("--clk-period", type=int, required=True, help="clock period in nanoseconds (>0)")
    ap.add_argument(
        "--downsample",
        type=int,
        required=True,
        help="downsample rate (>0); sample period = clk/downsample ns",
    )
    ap.add_argument("--start", type=int, default=None, help="start time in ns (>=0, optional)")
    ap.add_argument("--end", type=int, default=None, help="end time in ns (>=0, optional)")
    ap.add_argument("--func-rc", default=None, help="rc file with addSignal lines for func sim")
    ap.add_argument("--pwr-rc", default=None, help="rc file with addSignal lines for pwr sim")
    ap.add_argument("--mode", required=True, choices=["func-sim", "pwr-sim", "all"])
    ap.add_argument("--processes", type=int, required=True, help="number of parallel worker processes (>0)")
    ap.add_argument("--out-dir", default="./fsdb_dfs", help="output directory (default: ./fsdb_dfs)")
    ap.add_argument("--include-failed", action="store_true", help="also process rows whose Status != COMPLETED")
    ap.add_argument("--only-job", default=None, help="restrict to a single job name (handy for testing)")
    ap.add_argument("--rm-prefix", action="store_true", help="remove the common prefix from data column names")
    ap.add_argument("--skip-exist", action="store_true", help="skip jobs whose target pickle already exists")
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
        rows = [row for row in rows if row["Job"] == args.only_job]
        if not rows:
            sys.exit(f"error: job '{args.only_job}' not in summary")

    os.makedirs(args.out_dir, exist_ok=True)

    tasks = []
    for row in rows:
        job = row["Job"]
        if args.mode in ("func-sim", "all") and row.get("FSDB"):
            tasks.append(
                dict(
                    job=job,
                    sim_kind="func",
                    fsdb=row["FSDB"],
                    out_dir=args.out_dir,
                    period_ns=period_ns,
                    start_ns=args.start,
                    end_ns=args.end,
                    signals=func_signals,
                    downsample=args.downsample,
                    rm_prefix=args.rm_prefix,
                    skip_exist=args.skip_exist,
                )
            )
        if args.mode in ("pwr-sim", "all") and row.get("PtpxFsdb"):
            tasks.append(
                dict(
                    job=job,
                    sim_kind="pwr",
                    fsdb=row["PtpxFsdb"],
                    out_dir=args.out_dir,
                    period_ns=period_ns,
                    start_ns=args.start,
                    end_ns=args.end,
                    signals=pwr_signals,
                    downsample=args.downsample,
                    rm_prefix=args.rm_prefix,
                    skip_exist=args.skip_exist,
                )
            )
    if not tasks:
        sys.exit("error: no tasks to run after filtering")

    total = len(tasks)
    n_workers = min(args.processes, total)
    print(
        f"running {total} task(s) on {n_workers} process(es); "
        f"period={_fmt_ns(period_ns)}, out_dir={args.out_dir}"
    )

    n_ok = n_skip = n_fail = 0
    done = 0

    def report(res: dict) -> None:
        nonlocal done, n_ok, n_skip, n_fail
        done += 1
        if res.get("skipped"):
            n_skip += 1
            print(
                f"[{done}/{total}] SKIP {res['job']:<40s} {res['sim_kind']:<4s} "
                f"{res['elapsed']:.1f}s -> {res['pkl']}",
                flush=True,
            )
        elif res["ok"]:
            n_ok += 1
            print(
                f"[{done}/{total}] OK   {res['job']:<40s} {res['sim_kind']:<4s} "
                f"rows={res['rows']:<7d} cols={res['cols']:<6d} "
                f"{res['elapsed']:.1f}s -> {res['pkl']} (removed {res['csv']})",
                flush=True,
            )
        else:
            n_fail += 1
            print(
                f"[{done}/{total}] FAIL {res['job']:<40s} {res['sim_kind']:<4s} "
                f"{res['elapsed']:.1f}s : {res['error']}",
                flush=True,
            )

    if n_workers == 1:
        for task in tasks:
            report(_process_task(task))
    else:
        with mp.Pool(n_workers) as pool:
            for result in pool.imap_unordered(_process_task, tasks):
                report(result)

    print(f"summary: {n_ok} ok, {n_skip} skipped, {n_fail} failed")
    sys.exit(0 if n_fail == 0 else 1)


if __name__ == "__main__":
    main()
