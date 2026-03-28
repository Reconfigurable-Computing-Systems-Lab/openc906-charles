#!/usr/bin/env python3
"""
fsdb_merge.py - Merge time-segmented FSDB files back into a single FSDB.

This is the counterpart to fsdb_segment.py. It reassembles per-segment PTPX
power waveform FSDBs (produced by the split -> PTPX -> collect pipeline)
into a single continuous FSDB file using Synopsys `fsdbmerge -sw`.

File naming convention (produced by fsdb_segment.py / collect_fsdb.py):
    {prefix}_{begin_time}ns_{end_time}ns.fsdb

Usage examples:
  # Merge all coremark segments:
  python3 fsdb_merge.py \\
    --dir /path/to/result \\
    --prefix ptpx_coremark

  # Merge with compact output and dry-run preview:
  python3 fsdb_merge.py \\
    --dir /path/to/result \\
    --prefix ptpx_sgemm \\
    --compact --dry-run
"""

import argparse
import logging
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List, Tuple

# fsdbmerge cannot merge more than 31 files in a single invocation.
MAX_MERGE_FILES = 31

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------

def setup_logging(log_file=None):
    # type: (str) -> logging.Logger
    """Configure logger to write to both console and an optional log file."""
    logger = logging.getLogger("fsdb_merge")
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

    # File handler — DEBUG and above (optional)
    if log_file:
        fh = logging.FileHandler(log_file, mode="w")
        fh.setLevel(logging.DEBUG)
        fh.setFormatter(fmt)
        logger.addHandler(fh)

    return logger


# ---------------------------------------------------------------------------
# Core logic
# ---------------------------------------------------------------------------

def discover_segments(dir_path, prefix, logger):
    # type: (str, str, logging.Logger) -> List[Tuple[int, int, str]]
    """
    Scan *dir_path* for files matching ``{prefix}_{begin}ns_{end}ns.fsdb``.

    Returns a list of (begin_time, end_time, absolute_path) sorted by
    begin_time ascending.
    """
    pattern = re.compile(
        r"^" + re.escape(prefix) + r"_(\d+)ns_(\d+)ns\.fsdb$"
    )

    segments = []  # type: List[Tuple[int, int, str]]
    for fname in os.listdir(dir_path):
        m = pattern.match(fname)
        if m:
            bt = int(m.group(1))
            et = int(m.group(2))
            segments.append((bt, et, os.path.join(dir_path, fname)))

    segments.sort(key=lambda x: x[0])
    return segments


def validate_segments(segments, logger):
    # type: (List[Tuple[int, int, str]], logging.Logger) -> bool
    """
    Check that segments are contiguous. Warn on gaps/overlaps.
    Returns True if all segments are contiguous, False otherwise.
    """
    all_ok = True
    for i in range(len(segments) - 1):
        _, et_curr, fname_curr = segments[i]
        bt_next, _, fname_next = segments[i + 1]
        if et_curr != bt_next:
            gap = bt_next - et_curr
            if gap > 0:
                logger.warning(
                    "Gap of %d ns detected between segments:\n"
                    "  %s (end: %d ns)\n"
                    "  %s (begin: %d ns)",
                    gap,
                    os.path.basename(fname_curr), et_curr,
                    os.path.basename(fname_next), bt_next,
                )
            else:
                logger.warning(
                    "Overlap of %d ns detected between segments:\n"
                    "  %s (end: %d ns)\n"
                    "  %s (begin: %d ns)",
                    -gap,
                    os.path.basename(fname_curr), et_curr,
                    os.path.basename(fname_next), bt_next,
                )
            all_ok = False
    return all_ok


def build_command(segments, output_path, compact=False, show_disjoint_warning=False):
    # type: (List[Tuple[int, int, str]], str, bool, bool) -> List[str]
    """Build the fsdbmerge command-line argument list."""
    cmd = ["fsdbmerge"]

    # Input files in time-ascending order
    for _, _, fpath in segments:
        cmd.append(fpath)

    # Merge mode: same signals / switch-dump style
    cmd.append("-sw")

    # Output
    cmd.extend(["-o", output_path])

    # Optional flags
    if compact:
        cmd.append("-compact")
    if show_disjoint_warning:
        cmd.append("-show_disjoint_warning")

    return cmd


def run_merge(cmd, dry_run, logger):
    # type: (List[str], bool, logging.Logger) -> int
    """Execute the fsdbmerge command. Returns the process return code (0 on dry-run)."""
    # Separate input files from options for display
    input_files = []
    options = []
    for tok in cmd[1:]:
        if tok.startswith("-") or (options and options[-1] == "-o"):
            options.append(tok)
        else:
            input_files.append(tok)

    # Pretty-print
    cmd_display = (
        f"{cmd[0]} \\\n  "
        + " \\\n  ".join(input_files)
        + " \\\n  "
        + " ".join(options)
    )
    logger.info("fsdbmerge command:\n%s", cmd_display)

    if dry_run:
        logger.info("[DRY-RUN] Command not executed.")
        return 0

    logger.info("Running fsdbmerge with %d input files ...", len(input_files))
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError:
        logger.error(
            "fsdbmerge executable not found. Ensure Synopsys Verdi is in PATH."
        )
        return 1

    if proc.stdout.strip():
        logger.debug("fsdbmerge stdout:\n%s", proc.stdout.strip())
    if proc.stderr.strip():
        logger.warning("fsdbmerge stderr:\n%s", proc.stderr.strip())

    if proc.returncode != 0:
        logger.error("fsdbmerge exited with return code %d", proc.returncode)
    else:
        logger.info("fsdbmerge completed successfully (rc=0).")

    return proc.returncode


def _chunks(lst, n):
    """Yield successive n-sized chunks from *lst*."""
    for i in range(0, len(lst), n):
        yield lst[i : i + n]


def hierarchical_merge(
    segments, output_path, compact, show_disjoint_warning, dry_run, logger
):
    # type: (List[Tuple[int,int,str]], str, bool, bool, bool, logging.Logger) -> int
    """
    Merge *segments* into *output_path*, working around the fsdbmerge
    31-file limit by performing multi-pass hierarchical merging.

    Pass 0: merge input files in groups of <=31 -> intermediate files
    Pass 1: merge intermediates in groups of <=31 -> next intermediates
    ...repeat until only one file remains.
    """
    total = len(segments)
    if total <= MAX_MERGE_FILES:
        # Simple single-pass merge
        cmd = build_command(
            segments, output_path,
            compact=compact,
            show_disjoint_warning=show_disjoint_warning,
        )
        return run_merge(cmd, dry_run, logger)

    # --- Multi-pass merge required ---
    num_passes = math.ceil(math.log(total, MAX_MERGE_FILES))
    logger.info(
        "Input count (%d) exceeds fsdbmerge limit of %d files. "
        "Using hierarchical merge (%d estimated passes).",
        total, MAX_MERGE_FILES, num_passes,
    )

    # Temporary directory for intermediate files
    tmp_dir = tempfile.mkdtemp(
        prefix="fsdb_merge_tmp_", dir=os.path.dirname(output_path)
    )
    logger.info("Temporary directory: %s", tmp_dir)

    # current_files tracks the list of file paths to merge in the next pass
    current_files = [fpath for _, _, fpath in segments]
    pass_idx = 0
    intermediate_files = []  # track all temp files for cleanup

    try:
        while len(current_files) > MAX_MERGE_FILES:
            pass_idx += 1
            batches = list(_chunks(current_files, MAX_MERGE_FILES))
            logger.info(
                "Pass %d: merging %d files in %d batches ...",
                pass_idx, len(current_files), len(batches),
            )
            next_files = []
            for batch_idx, batch in enumerate(batches):
                if len(batch) == 1:
                    # Only one file in this batch — no merge needed
                    next_files.append(batch[0])
                    continue

                tmp_out = os.path.join(
                    tmp_dir,
                    f"pass{pass_idx}_batch{batch_idx}.fsdb",
                )
                intermediate_files.append(tmp_out)

                # Build a pseudo-segment list for build_command
                pseudo = [(0, 0, f) for f in batch]
                cmd = build_command(
                    pseudo, tmp_out,
                    compact=compact,
                    show_disjoint_warning=show_disjoint_warning,
                )
                rc = run_merge(cmd, dry_run, logger)
                if rc != 0:
                    logger.error(
                        "Pass %d batch %d failed (rc=%d). Aborting.",
                        pass_idx, batch_idx, rc,
                    )
                    return rc

                if not dry_run and not os.path.isfile(tmp_out):
                    logger.error(
                        "Intermediate file not produced: %s", tmp_out
                    )
                    return 1

                next_files.append(tmp_out)

            current_files = next_files
            logger.info(
                "Pass %d complete: %d intermediate files.",
                pass_idx, len(current_files),
            )

        # Final pass — current_files is now <= MAX_MERGE_FILES
        pass_idx += 1
        logger.info(
            "Final pass (%d): merging %d files into output ...",
            pass_idx, len(current_files),
        )
        pseudo = [(0, 0, f) for f in current_files]
        cmd = build_command(
            pseudo, output_path,
            compact=compact,
            show_disjoint_warning=show_disjoint_warning,
        )
        rc = run_merge(cmd, dry_run, logger)
        return rc

    finally:
        # Clean up temporary directory
        if os.path.isdir(tmp_dir):
            if dry_run:
                logger.info("[DRY-RUN] Would remove temp dir: %s", tmp_dir)
            else:
                logger.info("Cleaning up temporary directory: %s", tmp_dir)
                shutil.rmtree(tmp_dir, ignore_errors=True)


def verify_output(output_path, logger):
    # type: (str, logging.Logger) -> bool
    """Check that the merged output file exists and has non-zero size."""
    if not os.path.isfile(output_path):
        logger.error("Output file not found: %s", output_path)
        return False

    size = os.path.getsize(output_path)
    if size == 0:
        logger.error("Output file is empty: %s", output_path)
        return False

    size_mb = size / (1024 * 1024)
    logger.info("Output: %s (%.2f MB)", output_path, size_mb)
    return True


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Merge time-segmented FSDB files into one using fsdbmerge.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python3 fsdb_merge.py --dir ./result --prefix ptpx_coremark\n"
            "  python3 fsdb_merge.py --dir ./result --prefix ptpx_sgemm --compact --dry-run\n"
        ),
    )
    parser.add_argument(
        "--dir", required=True,
        help="Directory containing the FSDB segment files.",
    )
    parser.add_argument(
        "--prefix", required=True,
        help="Filename prefix to match (e.g., ptpx_coremark). "
             "Files matching {prefix}_{begin}ns_{end}ns.fsdb will be merged.",
    )
    parser.add_argument(
        "-o", "--output", default=None,
        help="Output FSDB path. Default: {dir}/{prefix}.fsdb",
    )
    parser.add_argument(
        "--compact", action="store_true",
        help="Pass -compact to fsdbmerge (smaller output, slower).",
    )
    parser.add_argument(
        "--show-disjoint-warning", action="store_true",
        help="Pass -show_disjoint_warning to fsdbmerge.",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print the fsdbmerge command without executing it.",
    )
    parser.add_argument(
        "--log", default=None,
        help="Path to a log file. If omitted, only console output is produced.",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    logger = setup_logging(args.log)

    # --- Resolve directory ---
    dir_path = os.path.abspath(args.dir)
    if not os.path.isdir(dir_path):
        logger.error("Directory does not exist: %s", dir_path)
        sys.exit(1)

    # --- Discover and sort segments ---
    logger.info("Scanning %s for prefix '%s' ...", dir_path, args.prefix)
    segments = discover_segments(dir_path, args.prefix, logger)

    if len(segments) == 0:
        logger.error(
            "No files matching '%s_{begin}ns_{end}ns.fsdb' found in %s",
            args.prefix, dir_path,
        )
        sys.exit(1)

    if len(segments) == 1:
        logger.error(
            "Only 1 segment found — nothing to merge. File: %s",
            os.path.basename(segments[0][2]),
        )
        sys.exit(1)

    logger.info("Found %d segments:", len(segments))
    logger.info(
        "  First: %s (begin: %d ns)",
        os.path.basename(segments[0][2]), segments[0][0],
    )
    logger.info(
        "  Last:  %s (end:   %d ns)",
        os.path.basename(segments[-1][2]), segments[-1][1],
    )
    logger.info(
        "  Total time range: %d ns - %d ns",
        segments[0][0], segments[-1][1],
    )

    # --- Validate continuity ---
    validate_segments(segments, logger)

    # --- Determine output path ---
    output_path = args.output or os.path.join(dir_path, f"{args.prefix}.fsdb")
    output_path = os.path.abspath(output_path)
    logger.info("Output will be: %s", output_path)

    if os.path.isfile(output_path) and not args.dry_run:
        logger.warning("Output file already exists and will be overwritten.")

    # --- Build and run command (hierarchical if >31 files) ---
    rc = hierarchical_merge(
        segments, output_path,
        compact=args.compact,
        show_disjoint_warning=args.show_disjoint_warning,
        dry_run=args.dry_run,
        logger=logger,
    )

    if rc != 0:
        sys.exit(rc)

    # --- Verify output ---
    if not args.dry_run:
        if not verify_output(output_path, logger):
            sys.exit(1)
        logger.info("Done. Merged %d segments into %s", len(segments), output_path)


if __name__ == "__main__":
    main()
