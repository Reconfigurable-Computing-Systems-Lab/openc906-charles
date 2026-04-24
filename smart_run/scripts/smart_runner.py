#!/usr/bin/env python3
"""smart_runner.py — Python simulation runner for OpenC906 RTL testbench.

Replaces the Makefile with parallel regression support and .pat size checking.

Usage (run from smart_run/ directory):
    python3 scripts/smart_runner.py showcase
    python3 scripts/smart_runner.py compile  [--sim vcs] [--dump on]
    python3 scripts/smart_runner.py buildcase --case CASE
    python3 scripts/smart_runner.py runcase  --case CASE [--sim vcs] [--dump on] [--timeout 1us]
    python3 scripts/smart_runner.py regress  [--sim vcs] [--dump on] [-j 4] [--timeout 1us]
    python3 scripts/smart_runner.py clean
"""

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SRAM_LIMIT_BYTES = 256 * 1024 * 1024  # 256 MB

# CSI-NN2 install path (relative from work dir)
CSI_NN2_INSTALL_REL = "../../csi-nn2/install_nn2/c906"

# All standard cases share CPU_ARCH_FLAG_0=c906fd and little-endian
DEFAULT_CPU_ARCH = "c906fd"
DEFAULT_ENDIAN = "little-endian"

# Standard case definitions: name -> {src, file, [extra_dirs], [rtl_extra]}
STANDARD_CASES = {
    "ISA_THEAD": {
        "src": "tests/cases/ISA/ISA_THEAD",
        "file": "C906_THEAD_ISA_EXTENSION",
    },
    "ISA_INT": {
        "src": "tests/cases/ISA/ISA_INT",
        "file": "C906_INT_SMOKE",
    },
    "ISA_LS": {
        "src": "tests/cases/ISA/ISA_LS",
        "file": "C906_LSU_SMOKE",
    },
    "ISA_FP": {
        "src": "tests/cases/ISA/ISA_FP",
        "file": "C906_FPU_SMOKE",
    },
    "coremark": {
        "src": "tests/cases/coremark",
        "file": "core_main",
        "extra_dirs": ["tests/lib/clib", "tests/lib/newlib_wrap"],
    },
    "MMU": {
        "src": "tests/cases/MMU",
        "file": "C906_mmu_basic",
    },
    "interrupt": {
        "src": "tests/cases/interrupt",
        "file": "C906_plic_int_smoke",
    },
    "exception": {
        "src": "tests/cases/exception",
        "file": "C906_Exception",
    },
    "debug": {
        "src": "tests/cases/debug",
        "file": "C906_DEBUG_PATTERN",
        "rtl_extra": [
            "tests/cases/debug/JTAG_DRV.vh",
            "tests/cases/debug/C906_DEBUG_PATTERN.v",
        ],
    },
    "csr": {
        "src": "tests/cases/csr",
        "file": "C906_CSR_OPERATION",
    },
    "cache": {
        "src": "tests/cases/cache",
        "file": "C906_IDCACHE_OPER",
    },
}

# Timeout suffix multipliers (to nanoseconds)
TIMEOUT_MULTIPLIERS = {
    "ps": 1e-3,
    "ns": 1.0,
    "us": 1e3,
    "ms": 1e6,
    "s": 1e9,
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def ensure_smart_run_dir():
    """Verify we're running from the smart_run/ directory."""
    if not os.path.isfile("setup/smart_cfg.mk"):
        print(
            "ERROR: Must run from the smart_run/ directory.\n"
            "  cd smart_run && python3 scripts/smart_runner.py ...",
            file=sys.stderr,
        )
        sys.exit(1)


def check_env():
    """Check required environment variables."""
    missing = []
    for var in ("CODE_BASE_PATH", "TOOL_EXTENSION"):
        if not os.environ.get(var):
            missing.append(var)
    if missing:
        print(
            f"ERROR: Environment variable(s) not set: {', '.join(missing)}\n"
            "  Source setup/example_setup.csh first.",
            file=sys.stderr,
        )
        sys.exit(1)


def run_cmd(cmd, cwd=None, log_file=None, silent=False):
    """Run a shell command. Returns (returncode, stdout+stderr)."""
    if log_file:
        with open(log_file, "w") as lf:
            result = subprocess.run(
                cmd, shell=True, cwd=cwd,
                stdout=lf, stderr=subprocess.STDOUT,
            )
        # Read back for return
        with open(log_file) as lf:
            output = lf.read()
        return result.returncode, output
    else:
        result = subprocess.run(
            cmd, shell=True, cwd=cwd,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            universal_newlines=True,
        )
        if not silent:
            if result.stdout:
                print(result.stdout, end="")
        return result.returncode, result.stdout or ""


def parse_timeout(timeout_str):
    """Parse a timeout string like '1us' into nanoseconds (float).

    Supported suffixes: ps, ns, us, ms, s.
    Returns None if timeout_str is None.
    """
    if timeout_str is None:
        return None
    timeout_str = timeout_str.strip()
    match = re.match(r"^([0-9]*\.?[0-9]+)\s*(ps|ns|us|ms|s)$", timeout_str)
    if not match:
        print(
            f"ERROR: Invalid timeout format '{timeout_str}'.\n"
            "  Use a number followed by ps, ns, us, ms, or s (e.g., 1us, 500ns, 3s).",
            file=sys.stderr,
        )
        sys.exit(1)
    value = float(match.group(1))
    unit = match.group(2)
    return value * TIMEOUT_MULTIPLIERS[unit]


# ---------------------------------------------------------------------------
# Case Discovery
# ---------------------------------------------------------------------------


def discover_nn_model_cases(base_dir="."):
    """Auto-discover NN model cases from model_compiled/*/model.c."""
    model_dir = os.path.join(base_dir, "tests", "cases", "model_compiled")
    cases = {}
    for model_c in glob.glob(os.path.join(model_dir, "*", "model.c")):
        case_name = os.path.basename(os.path.dirname(model_c))
        cases[case_name] = {
            "type": "nn_model",
            "model_dir": os.path.dirname(model_c),
        }
    return cases


def get_all_cases(base_dir="."):
    """Return dict of all cases: standard + conv_softmax + nn_models."""
    cases = {}

    # Standard cases
    for name, info in STANDARD_CASES.items():
        cases[name] = {"type": "standard", **info}

    # conv_softmax (special CSI-NN2 case)
    cases["conv_softmax"] = {
        "type": "conv_softmax",
        "src": "tests/cases/conv_softmax",
        "file": "bare_main",
    }

    # Auto-discovered NN model cases
    cases.update(discover_nn_model_cases(base_dir))

    return cases


# ---------------------------------------------------------------------------
# RTL Compilation
# ---------------------------------------------------------------------------


def get_sim_config(sim, dump, case=None):
    """Return simulator-specific compilation flags."""
    code_base = os.environ["CODE_BASE_PATH"]

    if dump == "on":
        sim_dump = ""
    else:
        if sim == "iverilog":
            sim_dump = "-DNO_DUMP"
        else:
            sim_dump = "+define+NO_DUMP"

    if sim == "vcs":
        timescale = "-timescale=1ns/1ps"
        sim_opt = "-sverilog -full64 -kdb -lca -debug_access +nospecify +notimingchecks"
        sim_def = "+define+no_warning +define+TSMC_NO_WARNING"
        sim_log = "-l comp.vcs.log"
        filelist = "-f ../logical/filelists/sim.fl"
    elif sim == "nc":
        timescale = "-timescale 1ns/1ps"
        sim_opt = (
            "+v2k -sysv +sv +access+wrc +notimingcheck "
            "-default_ext verilog -elaborate +tcl+../setup/nc.tcl"
        )
        sim_def = "+define+no_warning +define+TSMC_NO_WARNING +define+VMC +define+NC_SIM"
        sim_log = "-l comp.nc.log"
        filelist = "-f ../logical/filelists/sim.fl"
    elif sim == "iverilog":
        timescale = ""
        sim_opt = "-o xuantie_core.vvp -Diverilog=1 -g2012"
        sim_def = "-DIVERILOG_SIM"
        sim_log = ""
        filelist = (
            f"-f {code_base}/gen_rtl/filelists/C906_asic_rtl.fl "
            f"-f {code_base}/gen_rtl/filelists/tdt_dmi_top_rtl.fl "
            "-c ../logical/filelists/smart.fl -c ../logical/filelists/tb.fl"
        )
    else:
        print(f"ERROR: Unknown simulator '{sim}'", file=sys.stderr)
        sys.exit(1)

    # Debug case: prepend special debug verilog files to the filelist
    if case == "debug":
        base_dir = os.path.abspath(".")
        debug_files = (
            f"{base_dir}/tests/cases/debug/JTAG_DRV.vh "
            f"{base_dir}/tests/cases/debug/C906_DEBUG_PATTERN.v"
        )
        filelist = debug_files + " " + filelist

    return {
        "timescale": timescale,
        "sim_opt": sim_opt,
        "sim_def": sim_def,
        "sim_log": sim_log,
        "sim_dump": sim_dump,
        "filelist": filelist,
    }


def compile_rtl(sim, dump, work_dir, case=None):
    """Compile RTL testbench. Returns True on success."""
    os.makedirs(work_dir, exist_ok=True)
    cfg = get_sim_config(sim, dump, case=case)

    print(f"  [smart_runner] Compiling RTL ({sim})...")

    # Clean old simulator artifacts for VCS
    if sim == "vcs":
        for item in ("simv", "simv.daidir", "csrc", "ucli.key"):
            path = os.path.join(work_dir, item)
            if os.path.isdir(path):
                shutil.rmtree(path)
            elif os.path.isfile(path):
                os.remove(path)

    if sim == "vcs":
        cmd = (
            f"vcs {cfg['sim_opt']} {cfg['timescale']} {cfg['sim_def']} "
            f"{cfg['filelist']} {cfg['sim_dump']} {cfg['sim_log']}"
        )
    elif sim == "nc":
        cmd = (
            f"irun {cfg['sim_opt']} {cfg['timescale']} {cfg['sim_def']} "
            f"{cfg['filelist']} {cfg['sim_dump']} {cfg['sim_log']}"
        )
    elif sim == "iverilog":
        cmd = (
            f"iverilog {cfg['timescale']} {cfg['sim_opt']} {cfg['sim_def']} "
            f"{cfg['filelist']} {cfg['sim_dump']} {cfg['sim_log']}"
        )

    rc, _ = run_cmd(cmd, cwd=work_dir)
    if rc != 0:
        print(f"  [smart_runner] RTL compilation FAILED (rc={rc})", file=sys.stderr)
        return False
    print("  [smart_runner] RTL compilation OK")
    return True


# ---------------------------------------------------------------------------
# Case Build
# ---------------------------------------------------------------------------


def copy_lib_files(base_dir, work_dir):
    """Copy test library files to work directory."""
    lib_dir = os.path.join(base_dir, "tests", "lib")
    for f in os.listdir(lib_dir):
        src = os.path.join(lib_dir, f)
        if os.path.isfile(src):
            shutil.copy2(src, work_dir)


def build_standard_case(case_name, case_info, base_dir, work_dir):
    """Build a standard test case. Returns True on success."""
    src_dir = os.path.join(base_dir, case_info["src"])
    file_name = case_info["file"]

    # Copy case files
    for f in os.listdir(src_dir):
        src = os.path.join(src_dir, f)
        dst = os.path.join(work_dir, f)
        if os.path.isfile(src):
            shutil.copy2(src, dst)
        elif os.path.isdir(src):
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)

    # Copy extra dirs (e.g., coremark needs clib, newlib_wrap)
    for extra in case_info.get("extra_dirs", []):
        extra_dir = os.path.join(base_dir, extra)
        if os.path.isdir(extra_dir):
            for f in os.listdir(extra_dir):
                src = os.path.join(extra_dir, f)
                if os.path.isfile(src):
                    shutil.copy2(src, work_dir)

    # Copy lib files
    copy_lib_files(base_dir, work_dir)

    # Compute absolute CONVERT path for Srec2vmem
    convert_path = os.path.abspath(os.path.join(base_dir, "tests", "bin", "Srec2vmem"))

    # Build
    log_file = os.path.join(work_dir, f"{case_name}_build.case.log")
    cmd = (
        f"make -s clean && make -s all "
        f"CPU_ARCH_FLAG_0={DEFAULT_CPU_ARCH} ENDIAN_MODE={DEFAULT_ENDIAN} "
        f"CASENAME={case_name} FILE={file_name} "
        f"CONVERT={convert_path}"
    )
    rc, _ = run_cmd(cmd, cwd=work_dir, log_file=log_file)
    return rc == 0


def build_conv_softmax(base_dir, work_dir):
    """Build the conv_softmax case (special CSI-NN2). Returns True on success."""
    src_dir = os.path.join(base_dir, "tests", "cases", "conv_softmax")
    csi_install = os.path.abspath(os.path.join(base_dir, "..", "csi-nn2", "install_nn2", "c906"))

    # Copy case files
    for f in ("bare_main.c", "model.c", "sbrk.c", "test_data.h"):
        shutil.copy2(os.path.join(src_dir, f), work_dir)
    stubs_dst = os.path.join(work_dir, "stubs")
    if os.path.exists(stubs_dst):
        shutil.rmtree(stubs_dst)
    shutil.copytree(os.path.join(src_dir, "stubs"), stubs_dst)

    # Copy lib files
    copy_lib_files(base_dir, work_dir)

    convert_path = os.path.abspath(os.path.join(base_dir, "tests", "bin", "Srec2vmem"))

    extra_cflags = (
        "-DSHL_BUILD_RTOS -isystem stubs "
        f"-I{csi_install}/include "
        f"-I{csi_install}/include/csinn "
        f"-I{csi_install}/include/shl_public "
        "-ffunction-sections -fdata-sections"
    )
    extra_ldflags = (
        f"-Wl,--gc-sections -Wl,-z,muldefs "
        f"{csi_install}/lib/libshl_c906_rtos.a"
    )

    log_file = os.path.join(work_dir, "conv_softmax_build.case.log")
    cmd = (
        f"make -s clean && make -s all "
        f"CPU_ARCH_FLAG_0={DEFAULT_CPU_ARCH} ENDIAN_MODE={DEFAULT_ENDIAN} "
        f'CASENAME=conv_softmax FILE=bare_main '
        f'EXTRA_CFLAGS="{extra_cflags}" '
        f'EXTRA_LDFLAGS="{extra_ldflags}" '
        f"CONVERT={convert_path}"
    )
    rc, _ = run_cmd(cmd, cwd=work_dir, log_file=log_file)
    if rc != 0:
        return False

    # Copy input.pat after build (make clean deletes *.pat)
    input_pat = os.path.join(src_dir, "input.pat")
    if os.path.isfile(input_pat):
        shutil.copy2(input_pat, work_dir)

    return True


def build_nn_model_case(case_name, case_info, base_dir, work_dir):
    """Build an auto-discovered NN model case. Returns True on success."""
    model_dir = case_info["model_dir"]
    csi_install = os.path.abspath(os.path.join(base_dir, "..", "csi-nn2", "install_nn2", "c906"))
    common_dir = os.path.join(base_dir, "tests", "cases", "nn_model_common")
    prepare_script = os.path.abspath(os.path.join(base_dir, "scripts", "prepare_model.py"))

    # Copy shared bare-metal files
    shutil.copy2(os.path.join(common_dir, "bare_main.c"), work_dir)
    shutil.copy2(os.path.join(common_dir, "sbrk.c"), work_dir)
    stubs_dst = os.path.join(work_dir, "stubs")
    if os.path.exists(stubs_dst):
        shutil.rmtree(stubs_dst)
    shutil.copytree(os.path.join(common_dir, "stubs"), stubs_dst)

    # Run prepare_model.py (generates model.c, test_data.h, model_config.h, input.pat)
    rc, output = run_cmd(
        f"python3 {prepare_script} {os.path.abspath(model_dir)} {os.path.abspath(work_dir)}"
    )
    if rc != 0:
        print(f"  [smart_runner] prepare_model.py failed for {case_name}", file=sys.stderr)
        return False

    # Copy lib files
    copy_lib_files(base_dir, work_dir)

    convert_path = os.path.abspath(os.path.join(base_dir, "tests", "bin", "Srec2vmem"))

    extra_cflags = (
        "-DSHL_BUILD_RTOS -isystem stubs "
        f"-I{csi_install}/include "
        f"-I{csi_install}/include/csinn "
        f"-I{csi_install}/include/shl_public "
        "-ffunction-sections -fdata-sections"
    )
    extra_ldflags = (
        f"-Wl,--gc-sections -Wl,-z,muldefs "
        f"{csi_install}/lib/libshl_c906_rtos.a"
    )

    log_file = os.path.join(work_dir, f"{case_name}_build.case.log")
    cmd = (
        f"make -s clean && make -s all "
        f"CPU_ARCH_FLAG_0={DEFAULT_CPU_ARCH} ENDIAN_MODE={DEFAULT_ENDIAN} "
        f"CASENAME={case_name} FILE=bare_main "
        f'EXTRA_CFLAGS="{extra_cflags}" '
        f'EXTRA_LDFLAGS="{extra_ldflags}" '
        f"CONVERT={convert_path}"
    )
    rc, _ = run_cmd(cmd, cwd=work_dir, log_file=log_file)
    if rc != 0:
        return False

    # Re-run prepare_model.py to restore input.pat (make clean deletes *.pat)
    run_cmd(
        f"python3 {prepare_script} {os.path.abspath(model_dir)} {os.path.abspath(work_dir)}",
        silent=True,
    )
    return True


def build_case(case_name, cases, base_dir, work_dir):
    """Build a case by dispatching to the correct recipe. Returns True on success."""
    if case_name not in cases:
        print(f"ERROR: Unknown case '{case_name}'", file=sys.stderr)
        return False

    info = cases[case_name]
    case_type = info["type"]

    print(f"  [smart_runner] Building {case_name}...")

    if case_type == "standard":
        ok = build_standard_case(case_name, info, base_dir, work_dir)
    elif case_type == "conv_softmax":
        ok = build_conv_softmax(base_dir, work_dir)
    elif case_type == "nn_model":
        ok = build_nn_model_case(case_name, info, base_dir, work_dir)
    else:
        print(f"ERROR: Unknown case type '{case_type}'", file=sys.stderr)
        return False

    if ok:
        print(f"  [smart_runner] Build OK: {case_name}")
    else:
        print(f"  [smart_runner] Build FAILED: {case_name}", file=sys.stderr)
    return ok


# ---------------------------------------------------------------------------
# .pat Size Check
# ---------------------------------------------------------------------------


def count_pat_data_words(pat_file):
    """Count data words in a .pat file (skip @address lines and empty lines)."""
    count = 0
    if not os.path.isfile(pat_file):
        return 0
    with open(pat_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("@") and not line.startswith("//"):
                count += 1
    return count


def check_pat_size(work_dir):
    """Check if .pat data fits in 256MB SRAM.

    Returns (ok: bool, total_bytes: int).
    """
    total_words = 0
    for pat_name in ("inst.pat", "data.pat", "input.pat", "case.pat"):
        pat_path = os.path.join(work_dir, pat_name)
        total_words += count_pat_data_words(pat_path)
    total_bytes = total_words * 4
    return total_bytes <= SRAM_LIMIT_BYTES, total_bytes


# ---------------------------------------------------------------------------
# Simulation
# ---------------------------------------------------------------------------


def get_sim_run_cmd(sim, timeout_ns=None):
    """Return the command to run the compiled simulation."""
    plusarg = ""
    if timeout_ns is not None:
        plusarg = f" +MAX_SIM_TIME={timeout_ns:.6f}"

    if sim == "vcs":
        return f"./simv{plusarg} -l run.vcs.log"
    elif sim == "nc":
        return f"irun -R{plusarg} -l run.irun.log"
    elif sim == "iverilog":
        return f"vvp xuantie_core.vvp{plusarg} -l run.iverilog.log"
    else:
        return f"./simv{plusarg} -l run.vcs.log"


def run_simulation(sim, work_dir, timeout_ns=None):
    """Run the simulation. Returns True if PASS."""
    cmd = get_sim_run_cmd(sim, timeout_ns)
    print(f"  [smart_runner] Running simulation: {cmd}")
    rc, _ = run_cmd(cmd, cwd=work_dir)

    # Check result from run_case.report
    report_file = os.path.join(work_dir, "run_case.report")
    if os.path.isfile(report_file):
        with open(report_file) as f:
            content = f.read()
        if "TEST PASS" in content:
            return True
        elif "TEST FAIL" in content:
            return False
    return False


def get_waveform_files(sim, work_dir):
    """Return list of (src_path, dst_extension) for waveform files in work_dir.

    VCS produces novas.fsdb (and possibly *.fsdb).
    NC/iverilog produce test.vcd.
    """
    results = []
    if sim == "vcs":
        # VCS default waveform: novas.fsdb
        for fname in os.listdir(work_dir):
            if fname.endswith(".fsdb"):
                results.append((os.path.join(work_dir, fname), ".fsdb"))
    elif sim in ("nc", "iverilog"):
        vcd = os.path.join(work_dir, "test.vcd")
        if os.path.isfile(vcd):
            results.append((vcd, ".vcd"))
    return results


# ---------------------------------------------------------------------------
# Work Directory Setup for Parallel Cases
# ---------------------------------------------------------------------------


def setup_case_work_dir(sim, case_name, shared_work_dir, regress_base):
    """Create an isolated work directory for a parallel case.

    Symlinks the compiled simulator binary from shared_work_dir.
    Returns the path to the case work directory.
    """
    case_dir = os.path.join(regress_base, case_name)
    os.makedirs(case_dir, exist_ok=True)

    # Symlink simulator binary
    if sim == "vcs":
        items = ["simv", "simv.daidir"]
    elif sim == "nc":
        items = ["INCA_libs"]
    elif sim == "iverilog":
        items = ["xuantie_core.vvp"]
    else:
        items = ["simv", "simv.daidir"]

    for item in items:
        src = os.path.join(shared_work_dir, item)
        dst = os.path.join(case_dir, item)
        if os.path.exists(dst) or os.path.islink(dst):
            if os.path.isdir(dst) and not os.path.islink(dst):
                shutil.rmtree(dst)
            else:
                os.remove(dst)
        if os.path.exists(src):
            os.symlink(os.path.abspath(src), dst)

    return case_dir


# ---------------------------------------------------------------------------
# Report Generation
# ---------------------------------------------------------------------------


def parse_report(report_file):
    """Parse a run_case.report file. Returns 'PASS', 'FAIL', or 'NOT RUN'."""
    if not os.path.isfile(report_file):
        return "NOT RUN"
    with open(report_file) as f:
        content = f.read()
    if "TEST PASS" in content:
        return "PASS"
    elif "TEST FAIL" in content:
        return "FAIL"
    elif "NOT RUN" in content:
        return "NOT RUN"
    return "NOT RUN"


def generate_report(results, report_dir):
    """Generate a regression report from results dict.

    results: {case_name: 'PASS'|'FAIL'|'NOT RUN'|'SKIP (reason)'}
    """
    os.makedirs(report_dir, exist_ok=True)

    pass_count = 0
    fail_count = 0
    not_run_count = 0

    lines = []
    for i, (case_name, result) in enumerate(sorted(results.items())):
        if result == "PASS":
            pass_count += 1
            display_result = "PASS"
        elif "NOT RUN" in result or "SKIP" in result:
            not_run_count += 1
            display_result = f"=>NOT RUN"
        else:
            fail_count += 1
            display_result = "=>FAIL"
        lines.append((str(i), case_name, display_result))

    total = pass_count + fail_count + not_run_count

    report_file = os.path.join(os.path.dirname(report_dir), "regress_report")
    with open(report_file, "w") as f:
        f.write(f"{'':>45}\n")
        f.write(f" Block      Pattern                   Result\n")
        f.write(f"---------------------------------------------\n")
        for block, pattern, result in lines:
            f.write(f"{block:<10}{pattern:<22}{result:>13}\n")
        f.write(f"---------------------------------------------\n")
        f.write(f" Not run   Pass   Fail   Total\n")
        f.write(f"   {not_run_count}       {pass_count}      {fail_count}      {total}\n")

    return report_file


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------


def cmd_showcase(args):
    """List all available test cases."""
    cases = get_all_cases()
    print("  Case list:")
    for name in sorted(cases.keys()):
        case_type = cases[name]["type"]
        tag = f" [{case_type}]" if case_type == "nn_model" else ""
        print(f"    {name}{tag}")
    print(f"\n  Total: {len(cases)} cases")


def cmd_compile(args):
    """Compile RTL testbench."""
    check_env()
    work_dir = os.path.join(".", "work")
    ok = compile_rtl(args.sim, args.dump, work_dir, case=None)
    sys.exit(0 if ok else 1)


def cmd_buildcase(args):
    """Build a single test case."""
    check_env()
    cases = get_all_cases()
    case_name = args.case
    if case_name not in cases:
        print(f"ERROR: Unknown case '{case_name}'.", file=sys.stderr)
        print("  Run 'python3 scripts/smart_runner.py showcase' for valid cases.", file=sys.stderr)
        sys.exit(1)

    work_dir = os.path.join(".", "work")
    os.makedirs(work_dir, exist_ok=True)

    # Clean case files
    clean_case_files(work_dir)

    ok = build_case(case_name, cases, ".", work_dir)
    if ok:
        pat_ok, pat_bytes = check_pat_size(work_dir)
        pat_mb = pat_bytes / (1024 * 1024)
        print(f"  [smart_runner] .pat data size: {pat_mb:.2f} MB", end="")
        if not pat_ok:
            print(f" — EXCEEDS 256MB SRAM LIMIT!", end="")
        print()
    sys.exit(0 if ok else 1)


def cmd_runcase(args):
    """Compile RTL, build case, and run simulation."""
    check_env()
    cases = get_all_cases()
    case_name = args.case
    if case_name not in cases:
        print(f"ERROR: Unknown case '{case_name}'.", file=sys.stderr)
        sys.exit(1)

    work_dir = os.path.join(".", "work")
    timeout_ns = parse_timeout(args.timeout)

    # Check if debug case needs special RTL compile
    rtl_case = case_name if case_name == "debug" else None

    # Compile RTL
    if not compile_rtl(args.sim, args.dump, work_dir, case=rtl_case):
        sys.exit(1)

    # Clean case files and build
    clean_case_files(work_dir)
    if not build_case(case_name, cases, ".", work_dir):
        sys.exit(1)

    # Check .pat size
    pat_ok, pat_bytes = check_pat_size(work_dir)
    if not pat_ok:
        pat_mb = pat_bytes / (1024 * 1024)
        print(f"  [smart_runner] SRAM overflow: .pat data {pat_mb:.1f}MB > 256MB. Aborting.")
        report_file = os.path.join(work_dir, "run_case.report")
        with open(report_file, "w") as f:
            f.write(f"NOT RUN (SRAM overflow: {pat_mb:.1f}MB > 256MB)\n")
        sys.exit(1)

    # Run simulation
    passed = run_simulation(args.sim, work_dir, timeout_ns)
    print(f"  [smart_runner] Result: {'PASS' if passed else 'FAIL'}")
    sys.exit(0 if passed else 1)


def cmd_regress(args):
    """Run all cases with optional parallelism."""
    check_env()
    cases = get_all_cases()
    jobs = args.j
    timeout_ns = parse_timeout(args.timeout)
    sim = args.sim
    dump = args.dump

    case_list = sorted(cases.keys())
    print(f"  [smart_runner] Regression: {len(case_list)} cases, {jobs} parallel job(s)")
    if timeout_ns is not None:
        print(f"  [smart_runner] Timeout: {args.timeout} ({timeout_ns:.3f} ns)")

    # Setup result directory
    regress_result_dir = os.path.join(".", "tests", "regress", "regress_result")
    if os.path.exists(regress_result_dir):
        shutil.rmtree(regress_result_dir)
    os.makedirs(regress_result_dir, exist_ok=True)

    shared_work_dir = os.path.abspath(os.path.join(".", "work"))
    regress_base = os.path.abspath(os.path.join(".", "work_regress"))
    base_dir = os.path.abspath(".")

    # Separate debug case (needs different RTL compile)
    debug_cases = [c for c in case_list if c == "debug"]
    normal_cases = [c for c in case_list if c != "debug"]

    # Compile RTL for normal cases
    print("\n  [smart_runner] === Phase 1: Compile RTL ===")
    os.makedirs(shared_work_dir, exist_ok=True)
    if not compile_rtl(sim, dump, shared_work_dir, case=None):
        print("  [smart_runner] RTL compilation failed. Aborting.", file=sys.stderr)
        sys.exit(1)

    # Compile RTL for debug case (if present) — must be sibling of work/
    # so that ../logical/ relative paths in sim.fl resolve correctly
    debug_work_dir = None
    if debug_cases:
        debug_work_dir = os.path.abspath(os.path.join(".", "work_debug"))
        os.makedirs(debug_work_dir, exist_ok=True)
        print("  [smart_runner] Compiling RTL for debug case...")
        if not compile_rtl(sim, dump, debug_work_dir, case="debug"):
            print("  [smart_runner] Debug RTL compilation failed.", file=sys.stderr)

    # Clean and prepare regress work area
    if os.path.exists(regress_base):
        for item in os.listdir(regress_base):
            path = os.path.join(regress_base, item)
            if os.path.isdir(path):
                shutil.rmtree(path)

    results = {}

    def run_one_case(case_name):
        """Run a single case in its own work directory. Returns (case_name, result_str)."""
        info = cases[case_name]

        # Determine which RTL compile to use
        if case_name == "debug" and debug_work_dir:
            rtl_dir = debug_work_dir
        else:
            rtl_dir = shared_work_dir

        # Setup isolated work directory
        case_dir = setup_case_work_dir(sim, case_name, rtl_dir, regress_base)

        # Build case
        if not build_case(case_name, cases, base_dir, case_dir):
            # Write report
            report_path = os.path.join(case_dir, "run_case.report")
            with open(report_path, "w") as f:
                f.write("TEST FAIL (build error)\n")
            return case_name, "FAIL"

        # Check .pat size
        pat_ok, pat_bytes = check_pat_size(case_dir)
        if not pat_ok:
            pat_mb = pat_bytes / (1024 * 1024)
            report_path = os.path.join(case_dir, "run_case.report")
            with open(report_path, "w") as f:
                f.write(f"NOT RUN (SRAM overflow: {pat_mb:.1f}MB > 256MB)\n")
            return case_name, f"NOT RUN (SRAM overflow: {pat_mb:.1f}MB)"

        # Run simulation
        passed = run_simulation(sim, case_dir, timeout_ns)
        result = "PASS" if passed else "FAIL"
        return case_name, result

    # Phase 2: Run all cases in parallel
    print(f"\n  [smart_runner] === Phase 2: Run {len(case_list)} cases (j={jobs}) ===")
    all_cases = normal_cases + debug_cases

    with ThreadPoolExecutor(max_workers=jobs) as executor:
        future_to_case = {
            executor.submit(run_one_case, case_name): case_name
            for case_name in all_cases
        }
        completed = 0
        for future in as_completed(future_to_case):
            case_name = future_to_case[future]
            try:
                name, result = future.result()
                results[name] = result
                completed += 1
                status_char = "✓" if result == "PASS" else "✗" if result == "FAIL" else "○"
                print(
                    f"  [{completed}/{len(all_cases)}] {status_char} {name}: {result}"
                )

                # Copy report to regress_result
                case_dir = os.path.join(regress_base, name)
                report_src = os.path.join(case_dir, "run_case.report")
                report_dst = os.path.join(regress_result_dir, f"{name}.report")
                if os.path.isfile(report_src):
                    shutil.copy2(report_src, report_dst)
                else:
                    with open(report_dst, "w") as f:
                        f.write(f"{result}\n")

                # Copy waveform dump files (.fsdb/.vcd) to regress_result
                for wave_src, wave_ext in get_waveform_files(sim, case_dir):
                    wave_dst = os.path.join(
                        regress_result_dir, f"{name}{wave_ext}"
                    )
                    shutil.copy2(wave_src, wave_dst)

            except Exception as e:
                results[case_name] = "FAIL"
                completed += 1
                print(f"  [{completed}/{len(all_cases)}] ✗ {case_name}: ERROR ({e})")
                report_dst = os.path.join(regress_result_dir, f"{case_name}.report")
                with open(report_dst, "w") as f:
                    f.write(f"TEST FAIL (exception: {e})\n")

    # Phase 3: Generate report
    print(f"\n  [smart_runner] === Phase 3: Generate Report ===")
    report_file = generate_report(results, regress_result_dir)
    print()
    with open(report_file) as f:
        print(f.read())

    # Summary
    pass_count = sum(1 for r in results.values() if r == "PASS")
    fail_count = sum(1 for r in results.values() if r == "FAIL")
    skip_count = sum(1 for r in results.values() if "NOT RUN" in r or "SKIP" in r)
    total = len(results)
    print(f"  [smart_runner] Done: {pass_count} passed, {fail_count} failed, "
          f"{skip_count} skipped, {total} total")

    sys.exit(0 if fail_count == 0 else 1)


def cmd_clean(args):
    """Clean work directories."""
    for d in ("work", "work_regress", "work_debug"):
        if os.path.exists(d):
            print(f"  [smart_runner] Removing {d}/")
            shutil.rmtree(d)
    print("  [smart_runner] Clean done")


def clean_case_files(work_dir):
    """Remove case-generated files from a work directory (like cleancase)."""
    patterns = [
        "*.s", "*.S", "*.c", "*.o", "*.pat", "*.h", "*.lcf",
        "*.hex", "*.obj", "*.vh", "*.v", "*.report", "*.elf",
        "Makefile", "*.case.log",
    ]
    for pattern in patterns:
        for f in glob.glob(os.path.join(work_dir, pattern)):
            os.remove(f)
    # Remove stubs directory if present
    stubs_dir = os.path.join(work_dir, "stubs")
    if os.path.isdir(stubs_dir):
        shutil.rmtree(stubs_dir)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    ensure_smart_run_dir()

    parser = argparse.ArgumentParser(
        description="OpenC906 RTL simulation runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python3 scripts/smart_runner.py showcase\n"
            "  python3 scripts/smart_runner.py runcase --case ISA_INT --sim vcs\n"
            "  python3 scripts/smart_runner.py regress --sim vcs -j 4 --timeout 1us\n"
            "  python3 scripts/smart_runner.py regress --sim vcs -j 8 --timeout 3s\n"
        ),
    )
    subparsers = parser.add_subparsers(dest="command", help="Command to run")

    # showcase
    sub = subparsers.add_parser("showcase", help="List all available test cases")
    sub.set_defaults(func=cmd_showcase)

    # compile
    sub = subparsers.add_parser("compile", help="Compile RTL testbench")
    sub.add_argument("--sim", default="vcs", choices=["vcs", "nc", "iverilog"])
    sub.add_argument("--dump", default="on", choices=["on", "off"])
    sub.set_defaults(func=cmd_compile)

    # buildcase
    sub = subparsers.add_parser("buildcase", help="Build a single test case")
    sub.add_argument("--case", required=True, help="Case name")
    sub.set_defaults(func=cmd_buildcase)

    # runcase
    sub = subparsers.add_parser("runcase", help="Compile + build + run a single case")
    sub.add_argument("--case", required=True, help="Case name")
    sub.add_argument("--sim", default="vcs", choices=["vcs", "nc", "iverilog"])
    sub.add_argument("--dump", default="on", choices=["on", "off"])
    sub.add_argument(
        "--timeout", default=None,
        help="Simulation time limit (e.g., 1us, 500ns, 3s, 10ms, 100ps)",
    )
    sub.set_defaults(func=cmd_runcase)

    # regress
    sub = subparsers.add_parser("regress", help="Run all cases (parallel supported)")
    sub.add_argument("--sim", default="vcs", choices=["vcs", "nc", "iverilog"])
    sub.add_argument("--dump", default="on", choices=["on", "off"])
    sub.add_argument(
        "-j", type=int, default=1,
        help="Maximum number of parallel jobs (default: 1)",
    )
    sub.add_argument(
        "--timeout", default=None,
        help="Simulation time limit per case (e.g., 1us, 500ns, 3s)",
    )
    sub.set_defaults(func=cmd_regress)

    # clean
    sub = subparsers.add_parser("clean", help="Clean work directories")
    sub.set_defaults(func=cmd_clean)

    args = parser.parse_args()
    if args.command is None:
        parser.print_help()
        sys.exit(0)

    args.func(args)


if __name__ == "__main__":
    main()
