#!/staff/ee/jjiangan/anaconda3/bin/python
"""run_ptpx_parallel.py - Parallel PrimePower (PTPX) job runner.

Launches ``pwr_shell`` for each FSDB file in parallel with configurable
concurrency, per-job timeout, periodic monitoring, graceful signal handling,
and a final summary report.

Use the conda Python in ``~/anaconda3``:

    ~/anaconda3/bin/python run_ptpx_parallel.py \
        --in_dir /path/to/syn/batch_dir \
        --clk_period 1 \
        --fsdb_list_file fsdb_run_list.txt

Example usage
-------------
# Using a list file (recommended for many FSDBs):
~/anaconda3/bin/python run_ptpx_parallel.py \
    --in_dir /path/to/syn/batch_dir \
    --clk_period 1 \
    --fsdb_list_file fsdb_run_list.txt

# Using explicit FSDB paths:
~/anaconda3/bin/python run_ptpx_parallel.py \
    --in_dir /path/to/syn/batch_dir \
    --clk_period 1 \
    --fsdb_names /path/to/a.fsdb /path/to/b.fsdb

# Full options:
~/anaconda3/bin/python run_ptpx_parallel.py \
    --in_dir /path/to/syn/batch_dir \
    --clk_period 1 \
    --fsdb_list_file fsdb_run_list.txt \
    --max_jobs 8 \
    --monitor_interval 300 \
    --timeout 7200 \
    --start_ns 100 --end_ns 5000 \
    --skip_completed \
    --dry_run
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import signal
import subprocess
import sys
import threading
import time
from concurrent.futures import Future, ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum, auto
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
_VERSION = "1.0.0-c906"
_COMPLETION_MARKER = "*_power_hier.rpt"

# ---------------------------------------------------------------------------
# Enums / Data
# ---------------------------------------------------------------------------


class JobStatus(Enum):
    """Possible states for a PTPX job."""

    PENDING = auto()
    RUNNING = auto()
    COMPLETED = auto()
    FAILED = auto()
    TIMEOUT = auto()
    SKIPPED = auto()
    INTERRUPTED = auto()


@dataclass
class JobInfo:
    """Book-keeping for a single pwr_shell invocation."""

    name: str
    fsdb_path: Path
    out_dir: Path
    status: JobStatus = JobStatus.PENDING
    returncode: int | None = None
    start_time: float | None = None
    end_time: float | None = None
    log_file: Path | None = None
    process: subprocess.Popen | None = field(default=None, repr=False)

    @property
    def elapsed(self) -> float:
        if self.start_time is None:
            return 0.0
        end = self.end_time if self.end_time is not None else time.time()
        return end - self.start_time

    @property
    def elapsed_str(self) -> str:
        return str(timedelta(seconds=int(self.elapsed)))


# ---------------------------------------------------------------------------
# Globals shared with signal handler
# ---------------------------------------------------------------------------
_lock = threading.Lock()
_jobs: list[JobInfo] = []
_shutdown = threading.Event()

log = logging.getLogger("ptpx_runner")

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run PrimePower time-based power analysis in parallel.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {_VERSION}")

    # -- required --------------------------------------------------------
    parser.add_argument(
        "--in_dir",
        required=True,
        help="Synthesis input directory (passed as IN_DIR to the Tcl script).",
    )
    parser.add_argument(
        "--clk_period",
        required=True,
        help="Clock period in ns (passed as CLK_PERIOD).",
    )

    # -- FSDB source (mutually exclusive, one required) -------------------
    fsdb = parser.add_mutually_exclusive_group(required=True)
    fsdb.add_argument(
        "--fsdb_names",
        nargs="+",
        metavar="FSDB",
        help="One or more FSDB file paths.",
    )
    fsdb.add_argument(
        "--fsdb_list_file",
        metavar="FILE",
        help="Text file listing FSDB paths, one per line (blank / # lines ignored).",
    )

    # -- optional --------------------------------------------------------
    parser.add_argument(
        "--max_jobs",
        type=int,
        default=5,
        help="Maximum parallel jobs (default: 5).",
    )
    parser.add_argument(
        "--monitor_interval",
        type=int,
        default=600,
        help="Status report interval in seconds (default: 600).",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=0,
        help="Per-job wall-clock timeout in seconds (0 = unlimited).",
    )
    parser.add_argument("--start_ns", default="", help="FSDB start time in ns (optional).")
    parser.add_argument("--end_ns", default="", help="FSDB end time in ns (optional).")
    parser.add_argument(
        "--skip_completed",
        action="store_true",
        help="Skip jobs whose output reports already exist.",
    )
    parser.add_argument(
        "--dry_run",
        action="store_true",
        help="Print commands without executing them.",
    )
    parser.add_argument(
        "--tcl_script",
        default="",
        help="Absolute path to the Tcl script (auto-resolved if omitted).",
    )

    args = parser.parse_args(argv)

    if bool(args.start_ns) != bool(args.end_ns):
        parser.error("--start_ns and --end_ns must both be set or both omitted.")
    if args.max_jobs < 1:
        parser.error("--max_jobs must be >= 1.")
    if args.monitor_interval < 1:
        parser.error("--monitor_interval must be >= 1.")

    return args


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------


def resolve_tcl_script(user_path: str) -> Path:
    """Return the absolute path to the Tcl script."""
    if user_path:
        path = Path(user_path).resolve()
        if not path.is_file():
            log.error("Tcl script not found: %s", path)
            sys.exit(1)
        return path

    script_dir = Path(__file__).resolve().parent
    path = script_dir / "run_power_timebased_replay.tcl"
    if not path.is_file():
        log.error("Tcl script not found at %s; use --tcl_script to specify.", path)
        sys.exit(1)
    return path


def resolve_ptpx_root() -> Path:
    """Return the ptpx root directory (parent of script/)."""
    return Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------------------
# FSDB list handling
# ---------------------------------------------------------------------------


def load_fsdb_list(args: argparse.Namespace) -> list[Path]:
    """Load and validate FSDB paths from CLI or file."""
    if args.fsdb_names:
        raw_paths = [Path(path) for path in args.fsdb_names]
    else:
        list_file = Path(args.fsdb_list_file)
        if not list_file.is_file():
            log.error("FSDB list file not found: %s", list_file)
            sys.exit(1)
        raw_paths = []
        with open(list_file) as fh:
            for line in fh:
                line = line.strip()
                if line and not line.startswith("#") and line.endswith(".fsdb"):
                    raw_paths.append(Path(line))

    if not raw_paths:
        log.error("No FSDB files found.")
        sys.exit(1)

    for path in raw_paths:
        if not path.is_file():
            log.warning("FSDB file does not exist (yet): %s", path)

    return raw_paths


# ---------------------------------------------------------------------------
# Job construction
# ---------------------------------------------------------------------------


def is_job_completed(out_dir: Path) -> bool:
    """Return true if the job appears to have completed previously."""
    reports_dir = out_dir / "reports"
    if not reports_dir.is_dir():
        return False
    return bool(list(reports_dir.glob(_COMPLETION_MARKER)))


def build_jobs(
    fsdb_list: list[Path],
    ptpx_root: Path,
    skip_completed: bool,
) -> list[JobInfo]:
    """Create a JobInfo for each FSDB file."""
    jobs: list[JobInfo] = []
    seen_names: set[str] = set()
    for fsdb_path in fsdb_list:
        name = fsdb_path.stem
        orig_name = name
        counter = 2
        while name in seen_names:
            name = f"{orig_name}_{counter}"
            counter += 1
        seen_names.add(name)

        out_dir = (ptpx_root / name).resolve()
        job = JobInfo(name=name, fsdb_path=fsdb_path, out_dir=out_dir)
        if skip_completed and is_job_completed(out_dir):
            job.status = JobStatus.SKIPPED
            log.info("SKIP   %-30s  (output already exists)", name)
        jobs.append(job)
    return jobs


# ---------------------------------------------------------------------------
# Single-job execution (runs inside a worker thread)
# ---------------------------------------------------------------------------


def run_single_job(
    job: JobInfo,
    in_dir: str,
    clk_period: str,
    tcl_script: Path,
    start_ns: str,
    end_ns: str,
    timeout: int,
) -> None:
    """Launch pwr_shell for job and block until it finishes."""
    if _shutdown.is_set():
        job.status = JobStatus.INTERRUPTED
        return
    if job.status == JobStatus.SKIPPED:
        return

    job.out_dir.mkdir(parents=True, exist_ok=True)
    job.log_file = job.out_dir / "run_ptpx.log"

    env = os.environ.copy()
    env["IN_DIR"] = in_dir
    env["OUT_DIR"] = str(job.out_dir)
    env["FSDB_NAME"] = str(job.fsdb_path)
    env["CLK_PERIOD"] = clk_period
    if start_ns:
        env["START_NS"] = start_ns
    if end_ns:
        env["END_NS"] = end_ns

    job.status = JobStatus.RUNNING
    job.start_time = time.time()
    log.info("START  %-30s  dir=%s", job.name, job.out_dir)

    proc: subprocess.Popen | None = None
    try:
        with open(job.log_file, "w") as log_fh:
            proc = subprocess.Popen(
                ["pwr_shell", "-f", str(tcl_script)],
                cwd=str(job.out_dir),
                env=env,
                stdout=log_fh,
                stderr=subprocess.STDOUT,
            )
            with _lock:
                job.process = proc

            effective_timeout = timeout if timeout > 0 else None
            proc.wait(timeout=effective_timeout)

        job.returncode = proc.returncode
        if proc.returncode == 0:
            job.status = JobStatus.COMPLETED
        else:
            job.status = JobStatus.FAILED

    except subprocess.TimeoutExpired:
        log.warning("TIMEOUT %-30s  after %d s; killing", job.name, timeout)
        if proc is not None:
            proc.kill()
            proc.wait()
        job.returncode = -9
        job.status = JobStatus.TIMEOUT
    except FileNotFoundError:
        log.error("ERROR  %-30s  'pwr_shell' not found; is PrimePower on PATH?", job.name)
        job.status = JobStatus.FAILED
        job.returncode = -1
    except Exception as exc:
        log.error("ERROR  %-30s  %s", job.name, exc)
        job.status = JobStatus.FAILED
        job.returncode = -1
    finally:
        job.end_time = time.time()
        with _lock:
            job.process = None
        cmd_log = job.out_dir / "pwr_shell_command.log"
        if cmd_log.exists():
            try:
                cmd_log.unlink()
            except OSError:
                pass

    log.info(
        "FINISH %-30s  status=%-11s  rc=%-4s  elapsed=%s",
        job.name,
        job.status.name,
        job.returncode,
        job.elapsed_str,
    )


# ---------------------------------------------------------------------------
# Monitor thread
# ---------------------------------------------------------------------------


def monitor_loop(jobs: list[JobInfo], interval: int) -> None:
    """Periodically log a status summary until shutdown."""
    while not _shutdown.wait(timeout=interval):
        counts: dict[str, int] = {}
        for job in jobs:
            counts[job.status.name] = counts.get(job.status.name, 0) + 1
        running_names = [job.name for job in jobs if job.status == JobStatus.RUNNING]
        log.info(
            "=== MONITOR ===  Total: %d | %s | Running: [%s]",
            len(jobs),
            " | ".join(f"{key}: {value}" for key, value in sorted(counts.items())),
            ", ".join(running_names) if running_names else "none",
        )


# ---------------------------------------------------------------------------
# Summary / Reporting
# ---------------------------------------------------------------------------


def write_summary_csv(jobs: list[JobInfo], ptpx_root: Path) -> Path:
    """Write a CSV summary to ptpx_root/ptpx_summary.csv."""
    path = ptpx_root / "ptpx_summary.csv"
    with open(path, "w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(
            ["Job", "FSDB", "PtpxFsdb", "Status", "ReturnCode", "Elapsed", "LogFile"]
        )
        for job in jobs:
            ptpx_fsdbs = sorted(job.out_dir.glob("results/openC906_pwr*.fsdb*"))
            ptpx_fsdb_col = ";".join(str(p) for p in ptpx_fsdbs)
            writer.writerow(
                [
                    job.name,
                    str(job.fsdb_path),
                    ptpx_fsdb_col,
                    job.status.name,
                    job.returncode if job.returncode is not None else "",
                    job.elapsed_str,
                    str(job.log_file) if job.log_file else "",
                ]
            )
    return path


def print_final_report(jobs: list[JobInfo], wall_time: float) -> None:
    """Print a human-readable summary table to the console."""
    header = f"{'#':<4} {'Job':<35} {'Status':<12} {'RC':<5} {'Elapsed':<12} {'Log'}"
    sep = "-" * len(header)
    lines = [
        "",
        "=" * 70,
        "  PTPX Parallel Run - Final Report",
        "=" * 70,
        header,
        sep,
    ]
    for idx, job in enumerate(jobs, 1):
        log_short = str(job.log_file) if job.log_file else "-"
        rc_str = str(job.returncode) if job.returncode is not None else "-"
        lines.append(
            f"{idx:<4} {job.name:<35} {job.status.name:<12} {rc_str:<5} "
            f"{job.elapsed_str:<12} {log_short}"
        )
    lines.append(sep)

    counts: dict[str, int] = {}
    for job in jobs:
        counts[job.status.name] = counts.get(job.status.name, 0) + 1
    tally = "  ".join(f"{key}: {value}" for key, value in sorted(counts.items()))
    lines.append(f"Total: {len(jobs)}  |  {tally}")
    lines.append(f"Wall-clock time: {timedelta(seconds=int(wall_time))}")
    lines.append("=" * 70)
    log.info("\n".join(lines))


# ---------------------------------------------------------------------------
# Signal handling
# ---------------------------------------------------------------------------


def _install_signal_handlers() -> None:
    """Register graceful shutdown on SIGINT / SIGTERM."""

    def handler(signum: int, frame: object) -> None:
        sig_name = signal.Signals(signum).name
        log.warning("Received %s; terminating running jobs", sig_name)
        _shutdown.set()
        with _lock:
            for job in _jobs:
                if job.process is not None and job.process.poll() is None:
                    log.warning("  Killing job: %s (PID %d)", job.name, job.process.pid)
                    try:
                        job.process.kill()
                    except OSError:
                        pass
                    job.status = JobStatus.INTERRUPTED
                    job.end_time = time.time()

    signal.signal(signal.SIGINT, handler)
    signal.signal(signal.SIGTERM, handler)


# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------


def setup_logging(ptpx_root: Path) -> None:
    """Configure logging to console and to a per-run timestamped log file.

    Each invocation creates a fresh ``ptpx_root/ptpx_runner_<YYYYMMDD_HHMMSS>.log``
    instead of appending to a shared file.
    """
    root = logging.getLogger()
    root.setLevel(logging.DEBUG)

    fmt = logging.Formatter(
        "%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    console = logging.StreamHandler(sys.stdout)
    console.setLevel(logging.INFO)
    console.setFormatter(fmt)
    root.addHandler(console)

    run_ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = ptpx_root / f"ptpx_runner_{run_ts}.log"
    file_handler = logging.FileHandler(log_file, mode="w")
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(fmt)
    root.addHandler(file_handler)

    log.info("Log file: %s", log_file)


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    global _jobs

    args = parse_args(argv)

    ptpx_root = resolve_ptpx_root()
    tcl_script = resolve_tcl_script(args.tcl_script)
    in_dir = str(Path(args.in_dir).resolve())

    setup_logging(ptpx_root)

    fsdb_list = load_fsdb_list(args)
    _jobs = build_jobs(fsdb_list, ptpx_root, args.skip_completed)
    pending = [job for job in _jobs if job.status != JobStatus.SKIPPED]

    log.info("PTPX Parallel Runner v%s", _VERSION)
    log.info("  Python         : %s", sys.executable)
    log.info("  Tcl script     : %s", tcl_script)
    log.info("  in_dir         : %s", in_dir)
    log.info("  clk_period     : %s ns", args.clk_period)
    log.info("  start_ns       : %s", args.start_ns or "(full)")
    log.info("  end_ns         : %s", args.end_ns or "(full)")
    log.info(
        "  Total jobs     : %d  (pending: %d, skipped: %d)",
        len(_jobs),
        len(pending),
        len(_jobs) - len(pending),
    )
    log.info("  max_jobs       : %d", args.max_jobs)
    log.info("  timeout        : %s", f"{args.timeout} s" if args.timeout else "none")
    log.info("  monitor_interval: %d s", args.monitor_interval)
    log.info("  skip_completed : %s", args.skip_completed)

    if args.dry_run:
        log.info("")
        log.info("=== DRY RUN - commands that would be executed ===")
        for job in pending:
            env_parts = [
                f"IN_DIR={in_dir}",
                f"OUT_DIR={job.out_dir}",
                f"FSDB_NAME={job.fsdb_path}",
                f"CLK_PERIOD={args.clk_period}",
            ]
            if args.start_ns:
                env_parts.append(f"START_NS={args.start_ns}")
            if args.end_ns:
                env_parts.append(f"END_NS={args.end_ns}")
            log.info(
                "  cd %s && %s pwr_shell -f %s",
                job.out_dir,
                " ".join(env_parts),
                tcl_script,
            )
        log.info("=== END DRY RUN ===")
        return 0

    if not pending:
        log.info("Nothing to do; all jobs skipped.")
        print_final_report(_jobs, 0.0)
        write_summary_csv(_jobs, ptpx_root)
        return 0

    _install_signal_handlers()

    monitor = threading.Thread(
        target=monitor_loop,
        args=(_jobs, args.monitor_interval),
        daemon=True,
    )
    monitor.start()

    wall_start = time.time()

    with ThreadPoolExecutor(
        max_workers=args.max_jobs,
        thread_name_prefix="ptpx",
    ) as pool:
        futures: dict[Future, JobInfo] = {}
        for job in pending:
            if _shutdown.is_set():
                for remaining in pending:
                    if remaining.status == JobStatus.PENDING:
                        remaining.status = JobStatus.INTERRUPTED
                break
            future = pool.submit(
                run_single_job,
                job,
                in_dir,
                args.clk_period,
                tcl_script,
                args.start_ns,
                args.end_ns,
                args.timeout,
            )
            futures[future] = job

        for future in futures:
            try:
                future.result()
            except Exception as exc:
                job = futures[future]
                log.error("Unhandled exception in job %s: %s", job.name, exc)
                job.status = JobStatus.FAILED

    wall_elapsed = time.time() - wall_start
    _shutdown.set()

    print_final_report(_jobs, wall_elapsed)
    summary_path = write_summary_csv(_jobs, ptpx_root)
    log.info("Summary CSV written to: %s", summary_path)

    n_bad = sum(
        1
        for job in _jobs
        if job.status in (JobStatus.FAILED, JobStatus.TIMEOUT, JobStatus.INTERRUPTED)
    )
    if n_bad:
        log.warning("%d job(s) did not complete successfully.", n_bad)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
