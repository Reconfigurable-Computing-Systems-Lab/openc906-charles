#!/usr/bin/env python3
"""
Convert a directory of fsdbreport CSV files into pickled pandas DataFrames.

Each input CSV is converted independently. The first column is treated as the
time column, converted to nanoseconds, and stored as the DataFrame index named
time_ns. Data values with power units are converted to watts; data values
without power units are converted to integers with missing/NaN-like values set
to 0. Rows are downsampled with pandas block averaging.

Example:
    ./csv_to_pkl.py --indir ../funcsim_db/_csv --downsample 10 \
        --processes 14 --out-dir ../funcsim_db --rm-prefix
"""

from __future__ import annotations

import argparse
import json
import multiprocessing as mp
import os
import re
import sys
import time
import traceback
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

import numpy as np
import pandas as pd


#region agent log
def _agent_log(run_id: str, hypothesis_id: str, location: str, message: str, data: dict) -> None:
    try:
        payload = {
            "sessionId": "76823a",
            "runId": run_id,
            "hypothesisId": hypothesis_id,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": int(time.time() * 1000),
        }
        with open("/dfs/usrhome/jjiangan/github/openc906-charles-imp/.cursor/debug-76823a.log", "a") as f:
            f.write(json.dumps(payload, sort_keys=True) + "\n")
    except Exception:
        pass
#endregion


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
    "fs": 1e-6, "ps": 1e-3, "ns": 1.0, "us": 1_000.0,
    "ms": 1_000_000.0, "s": 1_000_000_000.0,
    "f": 1e-6, "p": 1e-3, "n": 1.0, "u": 1_000.0, "m": 1_000_000.0,
}
MISSING_VALUES = {"", "nan", "na", "n/a", "none", "null", "x", "z"}
STREAM_WINDOWS_PER_CHUNK = 5000


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
    #region agent log
    _agent_log("initial", "H2,H3", "csv_to_pkl.py:_flatten_values", "before flatten stack", {
        "pid": os.getpid(),
        "shape": list(values.shape),
        "columns": len(values.columns),
    })
    #endregion
    flat = values.stack(future_stack=True).astype("string").str.strip()
    #region agent log
    _agent_log("initial", "H2,H3", "csv_to_pkl.py:_flatten_values", "after flatten stack", {
        "pid": os.getpid(),
        "flat_len": int(len(flat)),
    })
    #endregion
    return flat


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
    #region agent log
    _agent_log("initial", "H4", "csv_to_pkl.py:_convert_integer_values", "before integer conversion", {
        "pid": os.getpid(),
        "shape": list(values.shape),
        "columns": len(values.columns),
    })
    #endregion
    normalized = values.astype("string").map(_normalise_binary_string)
    #region agent log
    _agent_log("initial", "H4", "csv_to_pkl.py:_convert_integer_values", "after normalize strings", {
        "pid": os.getpid(),
        "shape": list(normalized.shape),
    })
    #endregion
    out = normalized.map(lambda s: int(s, 2)).astype(object)
    #region agent log
    _agent_log("initial", "H4", "csv_to_pkl.py:_convert_integer_values", "after integer map", {
        "pid": os.getpid(),
        "shape": list(out.shape),
    })
    #endregion
    return out


def _remove_common_prefix(columns: Iterable[str]) -> Dict[str, str]:
    cols = [str(c) for c in columns]
    if len(cols) < 2:
        return {}

    common = os.path.commonprefix(cols)
    if not common:
        return {}

    cut = max(common.rfind(delim) for delim in ("/", ".", "_"))
    prefix = common[:cut + 1] if cut >= 0 else common
    if not prefix:
        return {}

    renamed = {c: c[len(prefix):] for c in cols if c.startswith(prefix)}
    if len(renamed) != len(cols) or any(not v for v in renamed.values()):
        return {}
    return renamed


def _downsample(df: pd.DataFrame, window: int) -> pd.DataFrame:
    #region agent log
    _agent_log("initial", "H5", "csv_to_pkl.py:_downsample", "downsample entry", {
        "pid": os.getpid(),
        "shape": list(df.shape),
        "window": window,
    })
    #endregion
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
        missing = [v for v in pd.unique(series) if v not in cache]
        for value in missing:
            cache[value] = float(int(_normalise_binary_string(value), 2))
        out[col] = series.map(cache)
    df = pd.DataFrame(out, index=values.index).astype("float64")
    #region agent log
    _agent_log("post-fix", "H4", "csv_to_pkl.py:_convert_integer_values_cached", "cached integer conversion complete", {
        "pid": os.getpid(),
        "shape": list(df.shape),
        "cache_size": len(cache),
    })
    #endregion
    return df


def _convert_chunk_values(
    values: pd.DataFrame,
    has_power_unit: bool,
    integer_cache: Dict[str, float] | None = None,
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
    emitted_rows = 0

    #region agent log
    _agent_log("post-fix", "H1,H2,H5", "csv_to_pkl.py:_csv_to_dataframe_streaming", "streaming conversion entry", {
        "pid": os.getpid(),
        "csv_path": csv_path,
        "downsample": downsample,
        "chunk_rows": chunk_rows,
    })
    #endregion

    for chunk_idx, chunk in enumerate(reader):
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
            #region agent log
            _agent_log("post-fix", "H3,H4", "csv_to_pkl.py:_csv_to_dataframe_streaming", "streaming detected value type", {
                "pid": os.getpid(),
                "has_power_unit": bool(has_power_unit),
                "first_chunk_shape": list(values.shape),
            })
            #endregion

        time_ns = pd.to_numeric(work[time_col], errors="raise") * _time_unit_ns(time_col)
        data = _convert_chunk_values(values, bool(has_power_unit), integer_cache)
        if rm_prefix and not pieces:
            data.rename(columns=_remove_common_prefix(data.columns), inplace=True)
        elif rm_prefix and pieces:
            data.rename(columns=_remove_common_prefix(data.columns), inplace=True)
        piece = _downsample_converted_chunk(data, time_ns, downsample)
        pieces.append(piece)
        emitted_rows += len(piece)

        #region agent log
        _agent_log("post-fix", "H1,H2,H5", "csv_to_pkl.py:_csv_to_dataframe_streaming", "streaming chunk complete", {
            "pid": os.getpid(),
            "chunk_idx": chunk_idx,
            "input_rows_seen": total_rows,
            "work_shape": list(work.shape),
            "piece_shape": list(piece.shape),
            "emitted_rows": emitted_rows,
            "carry_rows": int(len(carry)),
        })
        #endregion

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
    #region agent log
    _agent_log("post-fix", "H1,H2,H5", "csv_to_pkl.py:_csv_to_dataframe_streaming", "streaming conversion exit", {
        "pid": os.getpid(),
        "total_rows": total_rows,
        "output_shape": list(out.shape),
        "dropped_remainder_rows": int(len(carry)) if total_rows >= downsample else 0,
    })
    #endregion
    return out


def csv_to_dataframe(csv_path: str, downsample: int, rm_prefix: bool) -> pd.DataFrame:
    #region agent log
    _agent_log("initial", "H1", "csv_to_pkl.py:csv_to_dataframe", "before read_csv", {
        "pid": os.getpid(),
        "csv_path": csv_path,
        "file_size": os.path.getsize(csv_path) if os.path.exists(csv_path) else None,
        "downsample": downsample,
        "rm_prefix": rm_prefix,
    })
    #endregion
    if downsample > 1:
        return _csv_to_dataframe_streaming(csv_path, downsample, rm_prefix)

    raw = pd.read_csv(csv_path, dtype=str, keep_default_na=False)
    #region agent log
    _agent_log("initial", "H1", "csv_to_pkl.py:csv_to_dataframe", "after read_csv", {
        "pid": os.getpid(),
        "shape": list(raw.shape),
        "columns": len(raw.columns),
        "memory_bytes_shallow": int(raw.memory_usage(index=True, deep=False).sum()),
    })
    #endregion
    if raw.shape[1] < 2:
        raise RuntimeError(f"expected at least one time column and one data column: {csv_path}")

    time_col = raw.columns[0]
    time_ns = pd.to_numeric(raw[time_col], errors="raise") * _time_unit_ns(time_col)
    values = raw.drop(columns=[time_col])
    #region agent log
    _agent_log("initial", "H1,H2,H3", "csv_to_pkl.py:csv_to_dataframe", "after split time and values", {
        "pid": os.getpid(),
        "time_col": str(time_col),
        "rows": int(len(raw)),
        "value_shape": list(values.shape),
    })
    #endregion

    if _contains_fatal_inf(values):
        raise RuntimeError("fatal infinity value found in CSV")

    has_power_unit = _contains_power_unit(values)
    #region agent log
    _agent_log("initial", "H3,H4", "csv_to_pkl.py:csv_to_dataframe", "after value type detection", {
        "pid": os.getpid(),
        "has_power_unit": bool(has_power_unit),
        "value_shape": list(values.shape),
    })
    #endregion
    if has_power_unit:
        data = _convert_power_values(values)
    else:
        data = _convert_integer_values(values)

    data.index = pd.Index(time_ns, name="time_ns")
    if rm_prefix:
        data.rename(columns=_remove_common_prefix(data.columns), inplace=True)

    return _downsample(data, downsample)


def _process_csv(task: Tuple[str, str, int, bool]) -> dict:
    csv_path, out_dir, downsample, rm_prefix = task
    name = os.path.basename(csv_path)
    out_pkl = os.path.join(out_dir, f"{os.path.splitext(name)[0]}.pkl")
    t0 = time.time()

    try:
        df = csv_to_dataframe(csv_path, downsample, rm_prefix)
        df.fillna(0, inplace=True)
        df.to_pickle(out_pkl)
        return {
            "ok": True,
            "csv": csv_path,
            "pkl": out_pkl,
            "rows": len(df),
            "cols": df.shape[1],
            "elapsed": time.time() - t0,
        }
    except Exception as e:
        #region agent log
        _agent_log("initial", "H1,H2,H3,H4,H5", "csv_to_pkl.py:_process_csv", "conversion failed", {
            "pid": os.getpid(),
            "csv": csv_path,
            "error_type": type(e).__name__,
            "error": str(e),
            "traceback_tail": traceback.format_exc()[-2000:],
            "elapsed": time.time() - t0,
        })
        #endregion
        return {
            "ok": False,
            "csv": csv_path,
            "error": f"{type(e).__name__}: {e}",
            "tb": traceback.format_exc(),
            "elapsed": time.time() - t0,
        }


def _discover_csvs(indir: str) -> List[str]:
    root = Path(indir)
    if not root.is_dir():
        raise RuntimeError(f"input directory not found: {indir}")
    return sorted(str(p) for p in root.glob("*.csv") if p.is_file())


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Convert all CSV files in a directory to pandas DataFrame pickles."
    )
    ap.add_argument("--indir", required=True,
                    help="directory containing input CSV files")
    ap.add_argument("--downsample", type=int, required=True,
                    help="downsample window size (>0)")
    ap.add_argument("--processes", type=int, required=True,
                    help="number of parallel worker processes (>0)")
    ap.add_argument("--out-dir", default="./fsdb_dfs",
                    help="output directory for pickle files (default: ./fsdb_dfs)")
    ap.add_argument("--rm-prefix", action="store_true",
                    help="remove the common prefix from data column names")
    args = ap.parse_args()

    if args.downsample <= 0:
        sys.exit("error: --downsample must be > 0")
    if args.processes <= 0:
        sys.exit("error: --processes must be > 0")

    try:
        csv_paths = _discover_csvs(args.indir)
    except Exception as e:
        sys.exit(f"error: {e}")
    if not csv_paths:
        sys.exit(f"error: no .csv files found in {args.indir}")

    out_dir = os.path.abspath(args.out_dir)
    os.makedirs(out_dir, exist_ok=True)

    tasks = [(path, out_dir, args.downsample, args.rm_prefix) for path in csv_paths]
    total = len(tasks)
    n_workers = min(args.processes, total)

    print(f"converting {total} CSV file(s) with {n_workers} worker(s)")
    print(f"indir={os.path.abspath(args.indir)}, out_dir={out_dir}")

    n_ok = n_fail = 0
    done = 0

    def report(res: dict) -> None:
        nonlocal done, n_ok, n_fail
        done += 1
        name = os.path.basename(res["csv"])
        if res["ok"]:
            n_ok += 1
            print(f"[{done}/{total}] OK   {name:<40s} "
                  f"rows={res['rows']:<7d} cols={res['cols']:<6d} "
                  f"{res['elapsed']:.1f}s -> {res['pkl']}", flush=True)
        else:
            n_fail += 1
            print(f"[{done}/{total}] FAIL {name:<40s} "
                  f"{res['elapsed']:.1f}s : {res['error']}", flush=True)

    if n_workers == 1:
        for task in tasks:
            report(_process_csv(task))
    else:
        with mp.Pool(n_workers) as pool:
            for res in pool.imap_unordered(_process_csv, tasks):
                report(res)

    print(f"summary: {n_ok} ok, {n_fail} failed")
    sys.exit(0 if n_fail == 0 else 1)


if __name__ == "__main__":
    main()
