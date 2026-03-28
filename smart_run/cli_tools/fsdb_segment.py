#!/usr/bin/env python3
"""
fsdb_segment.py - Automatically split FSDB files into time-based segments.

Uses fsdbdebug and fsdbextract from Synopsys Verdi to:
  1. Query FSDB time range via `fsdbdebug -info`
  2. Split into N equal time segments via `fsdbextract`
  3. Verify each extracted segment via `fsdbdebug -info`

Usage:
  python3 fsdb_segment.py \
    -f /dfs/usrhome/jjiangan/github/npu-charles/C907_eval_rtl_ust-hk_20251010/smart_run/tests/bin/fsdb_extract_list.txt \
    -n 100 -j 10
"""

import argparse
import logging
import math
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path
from typing import Dict, List, Tuple

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------

def setup_logging(log_file):
    # type: (str) -> logging.Logger
    """Configure root logger to write to both console and a log file."""
    logger = logging.getLogger("fsdb_segment")
    logger.setLevel(logging.DEBUG)

    fmt = logging.Formatter(
        "%(asctime)s [%(levelname)-7s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # Console handler — INFO and above
    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.INFO)
    ch.setFormatter(fmt)
    logger.addHandler(ch)

    # File handler — DEBUG and above
    fh = logging.FileHandler(log_file, mode="w")
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    return logger


# ---------------------------------------------------------------------------
# FSDB helpers
# ---------------------------------------------------------------------------

def run_cmd(cmd, timeout=600):
    # type: (List[str], int) -> Tuple[int, str, str]
    """Run a command and return (returncode, stdout, stderr)."""
    proc = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        text=True,
    )
    return proc.returncode, proc.stdout, proc.stderr


def parse_fsdb_info(fsdb_path):
    # type: (str) -> Dict
    """
    Run ``fsdbdebug -info <fsdb_path>`` and parse the output.

    Returns a dict with keys:
        min_time_fs  (int)  – minimum xtag in femtoseconds
        max_time_fs  (int)  – maximum xtag in femtoseconds
        scale_unit   (str)  – e.g. "100fs"
        file_status  (str)  – e.g. "finished"
    Raises RuntimeError on failure.
    """
    cmd = ["fsdbdebug", "-info", fsdb_path]
    rc, stdout, stderr = run_cmd(cmd)
    if rc != 0:
        raise RuntimeError(
            f"fsdbdebug -info failed (rc={rc}) for {fsdb_path}:\n{stderr}\n{stdout}"
        )

    # fsdbdebug writes its info to stderr, so combine both streams for parsing
    output = stdout + "\n" + stderr

    result = {}

    # Parse minimum xtag — e.g. "minimum xtag             : (0 0) or (0fs)"
    m = re.search(r"minimum xtag\s*:\s*\([^)]*\)\s*or\s*\((\d+)fs\)", output)
    if m:
        result["min_time_fs"] = int(m.group(1))
    else:
        raise RuntimeError(
            f"Could not parse minimum xtag from fsdbdebug output for {fsdb_path}"
        )

    # Parse maximum xtag — e.g. "maximum xtag             : (97 680172288) or (41729200000000fs)"
    m = re.search(r"maximum xtag\s*:\s*\([^)]*\)\s*or\s*\((\d+)fs\)", output)
    if m:
        result["max_time_fs"] = int(m.group(1))
    else:
        raise RuntimeError(
            f"Could not parse maximum xtag from fsdbdebug output for {fsdb_path}"
        )

    # Parse scale unit — e.g. "scale unit               : 100fs"
    m = re.search(r"scale unit\s*:\s*(\S+)", output)
    if m:
        result["scale_unit"] = m.group(1)

    # Parse file status — e.g. "file status              : finished"
    m = re.search(r"file status\s*:\s*(\S+)", output)
    if m:
        result["file_status"] = m.group(1)

    return result


def fs_to_ns(fs):
    # type: (int) -> float
    """Convert femtoseconds to nanoseconds."""
    return fs / 1_000_000.0


def ns_to_fs(ns):
    # type: (float) -> int
    """Convert nanoseconds to femtoseconds."""
    return int(ns * 1_000_000)


def format_ns_for_filename(ns):
    # type: (float) -> str
    """
    Format a nanosecond value for use in filenames.
    Uses integer if whole number, otherwise up to 3 decimal places.
    """
    if ns == int(ns):
        return str(int(ns))
    else:
        # Up to 3 decimal places, strip trailing zeros
        return f"{ns:.3f}".rstrip("0").rstrip(".")


# ---------------------------------------------------------------------------
# Segment extraction (runs in worker process)
# ---------------------------------------------------------------------------

def extract_one_segment(
    src_fsdb,
    out_fsdb,
    bt_ns,
    et_ns,
    compact,
    nolog,
    retry=True,
):
    # type: (str, str, float, float, bool, bool, bool) -> Dict
    """
    Extract a single time segment from *src_fsdb* and write to *out_fsdb*.
    After extraction, verify the result with fsdbdebug -info.

    Returns a result dict:
        seg_file, bt_ns, et_ns, success, verified, elapsed_s, error
    """
    result = {
        "seg_file": out_fsdb,
        "bt_ns": bt_ns,
        "et_ns": et_ns,
        "success": False,
        "verified": False,
        "elapsed_s": 0.0,
        "error": None,
    }

    t0 = time.time()

    cmd = [
        "fsdbextract", src_fsdb,
        "-bt", f"{bt_ns}ns",
        "-et", f"{et_ns}ns",
        "-o", out_fsdb,
    ]
    if compact:
        cmd.append("-compact")
    if nolog:
        cmd.append("-nolog")

    for attempt in range(2 if retry else 1):
        try:
            rc, stdout, stderr = run_cmd(cmd, timeout=3600)
            if rc != 0:
                result["error"] = (
                    f"fsdbextract failed (rc={rc}, attempt {attempt+1}):\n"
                    f"{stderr}\n{stdout}"
                )
                if attempt == 0 and retry:
                    continue  # retry once
                break
            else:
                result["success"] = True
                break
        except subprocess.TimeoutExpired:
            result["error"] = f"fsdbextract timed out (attempt {attempt+1})"
            if attempt == 0 and retry:
                continue
            break
        except Exception as e:
            result["error"] = f"fsdbextract exception (attempt {attempt+1}): {e}"
            if attempt == 0 and retry:
                continue
            break

    result["elapsed_s"] = time.time() - t0

    # Verify
    if result["success"] and os.path.isfile(out_fsdb):
        try:
            info = parse_fsdb_info(out_fsdb)
            if info.get("file_status") == "finished":
                # Check time range within tolerance (1 ns ≈ 1_000_000 fs)
                actual_min_ns = fs_to_ns(info["min_time_fs"])
                actual_max_ns = fs_to_ns(info["max_time_fs"])
                tolerance_ns = 1.0  # 1 ns tolerance

                min_ok = abs(actual_min_ns - bt_ns) <= tolerance_ns or actual_min_ns >= bt_ns
                max_ok = abs(actual_max_ns - et_ns) <= tolerance_ns or actual_max_ns <= et_ns

                if min_ok and max_ok:
                    result["verified"] = True
                else:
                    result["error"] = (
                        f"Verification mismatch: expected [{bt_ns}ns, {et_ns}ns], "
                        f"got [{actual_min_ns}ns, {actual_max_ns}ns]"
                    )
            else:
                result["error"] = (
                    f"Verification: file status is '{info.get('file_status')}', "
                    f"expected 'finished'"
                )
        except Exception as e:
            result["error"] = f"Verification failed: {e}"

    return result


# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------

def read_file_list(file_list_path):
    # type: (str) -> List[str]
    """Read FSDB file paths from a text file. Ignores blank lines and # comments."""
    paths = []
    with open(file_list_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            paths.append(line)
    return paths


def compute_segments(min_time_fs, max_time_fs, num_segments):
    # type: (int, int, int) -> List[Tuple[float, float]]
    """
    Compute *num_segments* equal time segments in nanoseconds.
    Returns list of (bt_ns, et_ns) tuples.
    """
    min_ns = fs_to_ns(min_time_fs)
    max_ns = fs_to_ns(max_time_fs)
    total_ns = max_ns - min_ns
    step_ns = total_ns / num_segments

    segments = []
    for i in range(num_segments):
        bt = min_ns + i * step_ns
        et = min_ns + (i + 1) * step_ns
        # Ensure last segment ends exactly at max
        if i == num_segments - 1:
            et = max_ns
        segments.append((bt, et))
    return segments


def print_progress(total, completed, running, failed):
    # type: (int, int, int, int) -> None
    """Print a single-line progress update."""
    bar_len = 30
    frac = completed / total if total else 1.0
    filled = int(bar_len * frac)
    bar = "█" * filled + "░" * (bar_len - filled)
    line = (
        f"\r  Progress: |{bar}| {completed}/{total} done, "
        f"{running} running, {failed} failed"
    )
    sys.stdout.write(line)
    sys.stdout.flush()


def main():
    parser = argparse.ArgumentParser(
        description="Split FSDB files into time-based segments using fsdbextract.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
Examples:
  %(prog)s -f fsdb_list.txt -n 10 -j 5 -o ./extracted
  %(prog)s -f fsdb_list.txt -n 20 -j 8 -o ./extracted --compact --dry-run
""",
    )
    parser.add_argument(
        "-f", "--file-list", required=True,
        help="Path to text file listing FSDB files (one per line, # for comments)",
    )
    parser.add_argument(
        "-n", "--num-segments", type=int, default=10,
        help="Number of segments per FSDB file (default: 10)",
    )
    parser.add_argument(
        "-j", "--parallel", type=int, default=4,
        help="Max parallel fsdbextract processes (default: 4)",
    )
    parser.add_argument(
        "-o", "--output-dir", required=True,
        help="Output directory for extracted segments",
    )
    parser.add_argument(
        "--compact", action="store_true",
        help="Pass -compact to fsdbextract for smaller output",
    )
    parser.add_argument(
        "--nolog", action="store_true",
        help="Suppress fsdbextract per-run log directories",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show planned extractions without executing",
    )
    parser.add_argument(
        "--resume", action="store_true",
        help="Skip segments whose output files already exist",
    )
    parser.add_argument(
        "--log-file", default=None,
        help="Log file path (default: <output-dir>/extraction.log)",
    )

    args = parser.parse_args()

    # ----- Setup output dir and logging -----
    out_dir = os.path.abspath(args.output_dir)
    os.makedirs(out_dir, exist_ok=True)

    log_file = args.log_file or os.path.join(out_dir, "extraction.log")
    logger = setup_logging(log_file)

    logger.info("=" * 70)
    logger.info("fsdb_segment.py — FSDB segmentation tool")
    logger.info("=" * 70)
    logger.info(f"File list   : {args.file_list}")
    logger.info(f"Segments    : {args.num_segments}")
    logger.info(f"Parallel    : {args.parallel}")
    logger.info(f"Output dir  : {out_dir}")
    logger.info(f"Compact     : {args.compact}")
    logger.info(f"Nolog       : {args.nolog}")
    logger.info(f"Dry-run     : {args.dry_run}")
    logger.info(f"Resume      : {args.resume}")
    logger.info(f"Log file    : {log_file}")
    logger.info("")

    # ----- Read FSDB list -----
    fsdb_files = read_file_list(args.file_list)
    if not fsdb_files:
        logger.error(f"No FSDB files found in {args.file_list}")
        sys.exit(1)
    logger.info(f"Found {len(fsdb_files)} FSDB file(s) to process:")
    for f in fsdb_files:
        logger.info(f"  {f}")
    logger.info("")

    # ----- Plan all extraction jobs -----
    all_jobs = []       # list of dicts describing each segment job
    skipped_files = []  # files skipped due to warnings
    error_files = []    # files skipped due to errors

    for fsdb_path in fsdb_files:
        basename = Path(fsdb_path).stem  # e.g. "sgemm"
        sub_dir = os.path.join(out_dir, basename)

        # Check source exists
        if not os.path.isfile(fsdb_path):
            logger.error(f"Source FSDB not found: {fsdb_path} — skipping")
            error_files.append(fsdb_path)
            continue

        # Query time range
        logger.info(f"Querying time range for: {fsdb_path}")
        try:
            info = parse_fsdb_info(fsdb_path)
        except RuntimeError as e:
            logger.error(f"Failed to parse FSDB info: {e} — skipping")
            error_files.append(fsdb_path)
            continue

        min_fs = info["min_time_fs"]
        max_fs = info["max_time_fs"]
        min_ns = fs_to_ns(min_fs)
        max_ns = fs_to_ns(max_fs)
        total_ns = max_ns - min_ns
        seg_duration_ns = total_ns / args.num_segments

        logger.info(
            f"  Time range: {min_ns}ns — {max_ns}ns  "
            f"(total: {total_ns:.3f}ns, scale: {info.get('scale_unit', '?')})"
        )
        logger.info(f"  Segment duration: {seg_duration_ns:.3f}ns")

        # Minimum segment duration guard
        if seg_duration_ns < 100.0:
            logger.warning(
                f"Skipping {fsdb_path}: segment duration {seg_duration_ns:.3f}ns "
                f"is less than 100ns "
                f"(total: {total_ns:.3f}ns, segments: {args.num_segments})"
            )
            skipped_files.append(fsdb_path)
            continue

        # Compute segments
        segments = compute_segments(min_fs, max_fs, args.num_segments)
        os.makedirs(sub_dir, exist_ok=True)

        for i, (bt_ns, et_ns) in enumerate(segments):
            bt_str = format_ns_for_filename(bt_ns)
            et_str = format_ns_for_filename(et_ns)
            seg_name = f"{basename}_{bt_str}ns_{et_str}ns.fsdb"
            seg_path = os.path.join(sub_dir, seg_name)

            if args.resume and os.path.isfile(seg_path):
                logger.info(f"  [resume] Skipping existing: {seg_name}")
                continue

            all_jobs.append({
                "src_fsdb": fsdb_path,
                "out_fsdb": seg_path,
                "seg_name": seg_name,
                "bt_ns": bt_ns,
                "et_ns": et_ns,
                "basename": basename,
                "seg_index": i + 1,
            })

    total_jobs = len(all_jobs)
    logger.info("")
    logger.info(f"Total extraction jobs planned: {total_jobs}")
    if skipped_files:
        logger.info(f"Files skipped (segment too short): {len(skipped_files)}")
    if error_files:
        logger.info(f"Files skipped (error): {len(error_files)}")
    logger.info("")

    # ----- Dry-run: just display plan -----
    if args.dry_run:
        logger.info("DRY-RUN mode — no extractions will be performed.")
        logger.info("")
        for job in all_jobs:
            logger.info(
                f"  [{job['seg_index']:>3d}] {job['basename']}: "
                f"{job['bt_ns']:.3f}ns → {job['et_ns']:.3f}ns  →  {job['seg_name']}"
            )
        logger.info("")
        logger.info("Dry-run complete.")
        sys.exit(0)

    if total_jobs == 0:
        logger.info("No extraction jobs to run. Exiting.")
        sys.exit(0)

    # ----- Execute extraction jobs in parallel -----
    logger.info(f"Starting extraction with up to {args.parallel} parallel workers...")
    logger.info("")

    completed_count = 0
    failed_count = 0
    running_count = 0
    results_summary = []  # list of result dicts

    print_progress(total_jobs, completed_count, running_count, failed_count)

    with ProcessPoolExecutor(max_workers=args.parallel) as executor:
        future_to_job = {}
        for job in all_jobs:
            future = executor.submit(
                extract_one_segment,
                src_fsdb=job["src_fsdb"],
                out_fsdb=job["out_fsdb"],
                bt_ns=job["bt_ns"],
                et_ns=job["et_ns"],
                compact=args.compact,
                nolog=args.nolog,
                retry=True,
            )
            future_to_job[future] = job
            running_count += 1

        for future in as_completed(future_to_job):
            job = future_to_job[future]
            running_count -= 1

            try:
                res = future.result()
            except Exception as e:
                res = {
                    "seg_file": job["out_fsdb"],
                    "bt_ns": job["bt_ns"],
                    "et_ns": job["et_ns"],
                    "success": False,
                    "verified": False,
                    "elapsed_s": 0.0,
                    "error": f"Worker exception: {e}",
                }

            results_summary.append(res)

            if res["success"] and res["verified"]:
                completed_count += 1
                status = "OK"
            elif res["success"] and not res["verified"]:
                completed_count += 1
                failed_count += 1
                status = "VERIFY_FAIL"
            else:
                completed_count += 1
                failed_count += 1
                status = "FAIL"

            print_progress(total_jobs, completed_count, running_count, failed_count)

            elapsed_str = f"{res['elapsed_s']:.1f}s"
            logger.info(
                f"  [{completed_count:>3d}/{total_jobs}] "
                f"{job['basename']} seg{job['seg_index']:>3d}: "
                f"{status:<12s} ({elapsed_str})  {job['seg_name']}"
            )
            if res["error"] and status != "OK":
                logger.error(f"    Error: {res['error']}")

    # Final newline after progress bar
    sys.stdout.write("\n")
    sys.stdout.flush()

    # ----- Summary -----
    logger.info("")
    logger.info("=" * 70)
    logger.info("SUMMARY")
    logger.info("=" * 70)

    # Group results by basename
    by_file = {}
    for job, res in zip(all_jobs, results_summary):
        bn = job["basename"]
        if bn not in by_file:
            by_file[bn] = {"pass": 0, "fail": 0, "verify_fail": 0}
        if res["success"] and res["verified"]:
            by_file[bn]["pass"] += 1
        elif res["success"]:
            by_file[bn]["verify_fail"] += 1
        else:
            by_file[bn]["fail"] += 1

    logger.info(f"{'FSDB File':<30s} {'Pass':>6s} {'Fail':>6s} {'VerFail':>8s}")
    logger.info("-" * 52)
    for bn, counts in by_file.items():
        logger.info(
            f"{bn:<30s} {counts['pass']:>6d} {counts['fail']:>6d} "
            f"{counts['verify_fail']:>8d}"
        )

    if skipped_files:
        logger.info("")
        logger.info("Files skipped (segment duration < 100ns):")
        for f in skipped_files:
            logger.info(f"  WARNING: {f}")

    if error_files:
        logger.info("")
        logger.info("Files skipped (source error):")
        for f in error_files:
            logger.info(f"  ERROR: {f}")

    total_pass = sum(c["pass"] for c in by_file.values())
    total_fail = sum(c["fail"] + c["verify_fail"] for c in by_file.values())

    logger.info("")
    logger.info(f"Total: {total_pass} passed, {total_fail} failed")
    logger.info(f"Log saved to: {log_file}")

    if total_fail > 0:
        logger.info("Exiting with error code 1 due to failures.")
        sys.exit(1)
    else:
        logger.info("All extractions completed successfully.")
        sys.exit(0)


if __name__ == "__main__":
    main()
