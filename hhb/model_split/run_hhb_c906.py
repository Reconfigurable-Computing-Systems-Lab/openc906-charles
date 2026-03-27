#!/usr/bin/env python3
"""
run_hhb_c906.py — Batch compile & simulate ONNX models on C906 via HHB + QEMU.

Usage:
    python3 run_hhb_c906.py [OPTIONS]

Options:
    --workers N         Parallel workers for codegen/compile (default: cpu_count)
    --force             Ignore checkpoint, rerun everything
    --codegen-only      Stop after HHB codegen (Stage 1)
    --compile-only      Stop after cross-compilation (Stage 2)
    --quant SCHEMES     Comma-separated quant schemes (default: int8_sym,float16,float32)
    --model NAMES       Comma-separated model dir names to process (default: all)
    --verbose           Print full subprocess output
    --timeout SECS      Per-job timeout in seconds (default: 600 for codegen/compile, 3600 for sim)
"""

import argparse
import datetime
import json
import logging
import multiprocessing
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
MODEL_SPLIT_DIR = SCRIPT_DIR  # hhb/model_split/

HHB_BIN = "/usr/local/bin/hhb"
RISCV_GCC = "/opt/Xuantie-900-gcc-linux-6.6.36-glibc-x86_64-V3.3.0/bin/riscv64-unknown-linux-gnu-gcc"
QEMU = "/opt/Xuantie-qemu-x86_64-Ubuntu-20.04-V5.2.8-B20250721-0303/bin/qemu-riscv64"
# The c906 SHL library is compiled with RVV 1.0 extensions (by GCC 14), so we must
# simulate on a QEMU CPU that supports those instructions. c907fdvm is the closest
# match that works (c906fd lacks RVV 1.0 and will give "Illegal instruction").
QEMU_CPU = "c907fdvm"

HHB_INSTALL = Path("/usr/local/lib/python3.8/dist-packages/hhb")
# c906 only has lib/ (no include/); use c907 headers (arch-independent)
NN2_INCLUDE = HHB_INSTALL / "install_nn2" / "c907" / "include"
NN2_C906_LIB = HHB_INSTALL / "install_nn2" / "c906" / "lib"
PREBUILT_RT = HHB_INSTALL / "prebuilt" / "runtime" / "riscv_linux"
CMD_PARSE = HHB_INSTALL / "prebuilt" / "runtime" / "cmd_parse"
DECODE_LIB = HHB_INSTALL / "prebuilt" / "decode" / "install" / "lib" / "rv"

QUANT_SCHEMES = ["int8_sym", "float16", "float32"]

CHECKPOINT_FILE = MODEL_SPLIT_DIR / "c906_checkpoint.json"
RESULTS_FILE = MODEL_SPLIT_DIR / "c906_results.json"
LOG_FILE = MODEL_SPLIT_DIR / "c906_run.log"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logger = logging.getLogger("hhb_c906")


def setup_logging(verbose: bool = False):
    logger.setLevel(logging.DEBUG)
    fmt = logging.Formatter("[%(asctime)s] %(levelname)-5s %(message)s", datefmt="%H:%M:%S")

    fh = logging.FileHandler(LOG_FILE, mode="a")
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    sh = logging.StreamHandler(sys.stderr)
    sh.setLevel(logging.DEBUG if verbose else logging.INFO)
    sh.setFormatter(fmt)
    logger.addHandler(sh)


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class ModelPart:
    """One ONNX model part discovered from manifest.json."""
    model_name: str
    part_index: int
    onnx_path: str        # relative to MODEL_SPLIT_DIR
    input_npz_path: str   # relative to MODEL_SPLIT_DIR
    input_names: List[str]
    input_shapes: List[List[int]]  # actual shapes from npz
    output_names: List[str]
    gops: float = 0.0     # total giga-operations (MAC*2 / 1e9)
    mac_count: int = 0    # total multiply-accumulate count


@dataclass
class JobResult:
    """Tracks a single (model_part, quant_scheme) job."""
    job_id: str           # "<model>/<partN>_c906_<quant>"
    model_name: str
    part_index: int
    quant: str
    status: str = "pending"
    codegen_rc: Optional[int] = None
    compile_rc: Optional[int] = None
    sim_rc: Optional[int] = None
    runtime_ms: Optional[float] = None
    gops: float = 0.0
    gops_per_s: Optional[float] = None
    error: Optional[str] = None
    updated_at: Optional[str] = None


# ---------------------------------------------------------------------------
# Checkpoint
# ---------------------------------------------------------------------------

class Checkpoint:
    def __init__(self, path: Path, force: bool = False):
        self.path = path
        self.data: Dict[str, dict] = {}
        if not force and path.exists():
            with open(path) as f:
                self.data = json.load(f)
            logger.info(f"Loaded checkpoint with {len(self.data)} jobs")

    def get(self, job_id: str) -> Optional[dict]:
        return self.data.get(job_id)

    def save_job(self, result: JobResult):
        result.updated_at = datetime.datetime.now().isoformat()
        self.data[result.job_id] = asdict(result)
        self._flush()

    def _flush(self):
        tmp = self.path.with_suffix(".tmp")
        with open(tmp, "w") as f:
            json.dump(self.data, f, indent=2)
        tmp.rename(self.path)

    def is_done(self, job_id: str) -> bool:
        j = self.data.get(job_id)
        return j is not None and j.get("status") == "sim_done"

    def stage_done(self, job_id: str, stage: str) -> bool:
        """Check if a specific stage is already done."""
        j = self.data.get(job_id)
        if j is None:
            return False
        status = j.get("status", "")
        stage_order = ["codegen_done", "compile_done", "sim_done"]
        check_order = {
            "codegen": ["codegen_done", "compile_done", "sim_done"],
            "compile": ["compile_done", "sim_done"],
            "sim": ["sim_done"],
        }
        return status in check_order.get(stage, [])


# ---------------------------------------------------------------------------
# GOPS Counting (static ONNX analysis)
# ---------------------------------------------------------------------------

def count_macs_onnx(onnx_path: str, input_shapes: Dict[str, List[int]]) -> int:
    """Count total MACs by analyzing ONNX graph node types and shapes.

    Supports: MatMul, Gemm, Conv. Other ops counted as element-wise
    (product of output shape, negligible).
    """
    import onnx
    import numpy as np
    from onnx import numpy_helper, TensorProto

    model = onnx.load(onnx_path)
    graph = model.graph

    # Build shape map from inputs and initializers
    shape_map: Dict[str, List[int]] = {}

    # From user-provided input shapes (these are the ground-truth from npz)
    for name, shape in input_shapes.items():
        shape_map[name] = list(shape)

    # From initializers (weights)
    init_map: Dict[str, Any] = {}
    for init in graph.initializer:
        shape_map[init.name] = list(init.dims)
        init_map[init.name] = init

    # From value_info (intermediate shapes if available)
    for vi in graph.value_info:
        if vi.name not in shape_map:
            dims = []
            for d in vi.type.tensor_type.shape.dim:
                dims.append(d.dim_value if d.dim_value > 0 else 1)
            if dims:
                shape_map[vi.name] = dims

    # From graph outputs
    for out in graph.output:
        if out.name not in shape_map:
            dims = []
            for d in out.type.tensor_type.shape.dim:
                dims.append(d.dim_value if d.dim_value > 0 else 1)
            if dims:
                shape_map[out.name] = dims

    total_macs = 0

    for node in graph.node:
        op = node.op_type

        if op in ("MatMul", "Gemm"):
            # MatMul: A[..., M, K] x B[..., K, N] → MACs = batch * M * K * N
            a_shape = shape_map.get(node.input[0], [])
            b_shape = shape_map.get(node.input[1], [])
            if len(a_shape) >= 2 and len(b_shape) >= 2:
                M = a_shape[-2]
                K = a_shape[-1]
                N = b_shape[-1]
                # batch dimensions
                batch = 1
                for d in a_shape[:-2]:
                    batch *= max(d, 1)
                macs = batch * M * K * N
                total_macs += macs

                # For Gemm, there may be a bias add, but it's negligible vs. M*K*N
            # Propagate output shape
            if len(a_shape) >= 2 and len(b_shape) >= 2:
                out_shape = list(a_shape[:-1]) + [b_shape[-1]]
                if node.output[0]:
                    shape_map[node.output[0]] = out_shape

        elif op == "Conv":
            # Conv: weight shape = [out_ch, in_ch/groups, kH, kW]
            w_name = node.input[1] if len(node.input) > 1 else None
            w_shape = shape_map.get(w_name, []) if w_name else []
            x_shape = shape_map.get(node.input[0], [])

            if len(w_shape) >= 4 and len(x_shape) >= 4:
                out_ch = w_shape[0]
                in_ch_per_group = w_shape[1]
                kH, kW = w_shape[2], w_shape[3]
                batch = max(x_shape[0], 1)
                in_H, in_W = x_shape[2], x_shape[3]

                # Parse Conv attributes for strides, pads, dilations, groups
                groups = 1
                strides = [1, 1]
                pads = [0, 0, 0, 0]
                dilations = [1, 1]
                for attr in node.attribute:
                    if attr.name == "group":
                        groups = attr.i
                    elif attr.name == "strides":
                        strides = list(attr.ints)
                    elif attr.name == "pads":
                        pads = list(attr.ints)
                    elif attr.name == "dilations":
                        dilations = list(attr.ints)

                # Compute output spatial dimensions
                pad_h = pads[0] + pads[2] if len(pads) >= 4 else 0
                pad_w = pads[1] + pads[3] if len(pads) >= 4 else 0
                eff_kH = (kH - 1) * dilations[0] + 1
                eff_kW = (kW - 1) * dilations[1] + 1
                out_H = (in_H + pad_h - eff_kH) // strides[0] + 1
                out_W = (in_W + pad_w - eff_kW) // strides[1] + 1

                macs = batch * out_ch * out_H * out_W * in_ch_per_group * kH * kW
                total_macs += macs

                out_shape = [batch, out_ch, out_H, out_W]
                if node.output[0]:
                    shape_map[node.output[0]] = out_shape
            else:
                # Can't compute, propagate what we can
                if node.output[0] and node.output[0] not in shape_map:
                    pass
        else:
            # Element-wise or shape ops — propagate shapes, count as negligible
            # Try to propagate output shape from first input
            if node.input and node.output:
                in_shape = shape_map.get(node.input[0], [])
                for out_name in node.output:
                    if out_name and out_name not in shape_map and in_shape:
                        shape_map[out_name] = in_shape

    return total_macs


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

def discover_models(model_filter: Optional[List[str]] = None) -> List[ModelPart]:
    """Read all manifest.json files and build ModelPart list."""
    import numpy as np

    parts: List[ModelPart] = []

    for entry in sorted(MODEL_SPLIT_DIR.iterdir()):
        if not entry.is_dir():
            continue
        manifest_path = entry / "manifest.json"
        if not manifest_path.exists():
            continue
        if model_filter and entry.name not in model_filter:
            continue

        with open(manifest_path) as f:
            manifest = json.load(f)

        for part_info in manifest["parts"]:
            onnx_rel = part_info["onnx_path"]
            npz_rel = part_info["input_npz_path"]
            onnx_abs = MODEL_SPLIT_DIR / onnx_rel
            npz_abs = MODEL_SPLIT_DIR / npz_rel

            if not onnx_abs.exists():
                logger.warning(f"ONNX not found: {onnx_abs}")
                continue
            if not npz_abs.exists():
                logger.warning(f"NPZ not found: {npz_abs}")
                continue

            # Get actual input shapes from npz (ONNX may have dynamic dims)
            npz_data = np.load(str(npz_abs))
            input_names = part_info["input_names"]
            input_shapes = []
            shape_map_for_macs = {}
            for name in input_names:
                if name in npz_data:
                    shape = list(npz_data[name].shape)
                    input_shapes.append(shape)
                    shape_map_for_macs[name] = shape
                else:
                    logger.warning(f"Input '{name}' not found in {npz_rel}, using ONNX shape")
                    input_shapes.append([])

            # Count MACs
            mac_count = count_macs_onnx(str(onnx_abs), shape_map_for_macs)
            gops = (mac_count * 2) / 1e9  # 1 MAC = 2 OPs

            mp = ModelPart(
                model_name=entry.name,
                part_index=part_info["index"],
                onnx_path=onnx_rel,
                input_npz_path=npz_rel,
                input_names=input_names,
                input_shapes=input_shapes,
                output_names=part_info["output_names"],
                gops=gops,
                mac_count=mac_count,
            )
            parts.append(mp)
            logger.info(
                f"Discovered {entry.name}/part{part_info['index']:03d}: "
                f"{mac_count:,} MACs = {gops:.6f} GOPS, "
                f"inputs={list(zip(input_names, input_shapes))}"
            )

    logger.info(f"Total: {len(parts)} model parts discovered")
    return parts


# ---------------------------------------------------------------------------
# Job helpers
# ---------------------------------------------------------------------------

def job_id(model_name: str, part_index: int, quant: str) -> str:
    return f"{model_name}/part{part_index:03d}_c906_{quant}"


def job_output_dir(jid: str) -> Path:
    return MODEL_SPLIT_DIR / jid


def run_cmd(cmd: List[str], cwd: Optional[str] = None, timeout: int = 600,
            verbose: bool = False, use_pty: bool = False) -> Tuple[int, str, str]:
    """Run a command, return (returncode, stdout, stderr).

    If use_pty=True, wraps the command with `script -qc` to allocate a
    pseudo-TTY.  This forces line-buffered stdout so that output printed
    before a crash (e.g. QEMU segfault after printing timing) is captured.
    """
    try:
        if use_pty:
            # Join cmd into a single shell string for script -qc
            import shlex
            shell_cmd = " ".join(shlex.quote(c) for c in cmd)
            wrapped = ["script", "-qc", shell_cmd, "/dev/null"]
            result = subprocess.run(
                wrapped, cwd=cwd, capture_output=True, text=True, timeout=timeout
            )
            # script always returns 0; look for signals in the output
            stdout = result.stdout
            # Strip ANSI escape sequences and carriage returns injected by script
            stdout = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', stdout)
            stdout = stdout.replace('\r\n', '\n').replace('\r', '')
            return result.returncode, stdout, result.stderr
        else:
            result = subprocess.run(
                cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout
            )
            if verbose:
                if result.stdout:
                    logger.debug(f"STDOUT: {result.stdout[:2000]}")
                if result.stderr:
                    logger.debug(f"STDERR: {result.stderr[:2000]}")
            return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", f"Timeout after {timeout}s"
    except Exception as e:
        return -1, "", str(e)


# ---------------------------------------------------------------------------
# Stage 1: HHB Codegen
# ---------------------------------------------------------------------------

def _hhb_codegen_one(args: tuple) -> JobResult:
    """Worker function for parallel HHB codegen."""
    part, quant, verbose, timeout = args
    jid = job_id(part.model_name, part.part_index, quant)
    out_dir = job_output_dir(jid)
    out_dir.mkdir(parents=True, exist_ok=True)

    onnx_abs = str(MODEL_SPLIT_DIR / part.onnx_path)
    npz_abs = str(MODEL_SPLIT_DIR / part.input_npz_path)

    # Build --input-name, --input-shape, --output-name
    input_name_str = ";".join(part.input_names)
    input_shape_str = ";".join(
        " ".join(str(d) for d in shape) for shape in part.input_shapes
    )
    output_name_str = ";".join(part.output_names)

    cmd = [
        HHB_BIN, "-C",
        "-f", onnx_abs,
        "--board", "c906",
        "--quantization-scheme", quant,
        "--input-name", input_name_str,
        "--input-shape", input_shape_str,
        "--output-name", output_name_str,
        "--calibrate-dataset", npz_abs,
        "--simulate-data", npz_abs,
        "--without-preprocess",
        "--model-save", "run_only",
        "-o", str(out_dir),
    ]

    logger.info(f"[codegen] {jid}: starting hhb -C (quant={quant})")
    rc, stdout, stderr = run_cmd(cmd, timeout=timeout, verbose=verbose)

    result = JobResult(
        job_id=jid, model_name=part.model_name,
        part_index=part.part_index, quant=quant,
        gops=part.gops, codegen_rc=rc,
    )

    # Check for expected outputs
    expected_files = ["main.c", "model.c", "io.c", "io.h", "hhb.bm"]
    if rc == 0:
        missing = [f for f in expected_files if not (out_dir / f).exists()]
        if missing:
            result.status = "codegen_failed"
            result.error = f"HHB exited 0 but missing files: {missing}"
            logger.error(f"[codegen] {jid}: FAIL — {result.error}")
        else:
            result.status = "codegen_done"
            logger.info(f"[codegen] {jid}: PASS")
    else:
        result.status = "codegen_failed"
        # Capture meaningful error (last few lines of stderr)
        err_lines = (stderr or stdout or "unknown error").strip().split("\n")
        result.error = "\n".join(err_lines[-5:])
        logger.error(f"[codegen] {jid}: FAIL (rc={rc}) — {err_lines[-1][:200]}")

    return result


def run_codegen(parts: List[ModelPart], quants: List[str], checkpoint: Checkpoint,
                workers: int, verbose: bool, timeout: int) -> List[JobResult]:
    """Stage 1: parallel HHB codegen."""
    logger.info(f"{'='*60}")
    logger.info(f"Stage 1: HHB Codegen ({len(parts)} parts × {len(quants)} quants = {len(parts)*len(quants)} jobs, {workers} workers)")
    logger.info(f"{'='*60}")

    jobs_to_run = []
    results = []

    for part in parts:
        for quant in quants:
            jid = job_id(part.model_name, part.part_index, quant)
            if checkpoint.stage_done(jid, "codegen"):
                logger.info(f"[codegen] {jid}: skipped (checkpoint)")
                r = JobResult(
                    job_id=jid, model_name=part.model_name,
                    part_index=part.part_index, quant=quant,
                    gops=part.gops,
                    **{k: v for k, v in checkpoint.get(jid).items()
                       if k in ("status", "codegen_rc", "compile_rc", "sim_rc",
                                "runtime_ms", "gops_per_s", "error")}
                )
                results.append(r)
            else:
                jobs_to_run.append((part, quant, verbose, timeout))

    if jobs_to_run:
        with multiprocessing.Pool(processes=workers) as pool:
            new_results = pool.map(_hhb_codegen_one, jobs_to_run)
        for r in new_results:
            checkpoint.save_job(r)
            results.append(r)

    passed = sum(1 for r in results if r.status in ("codegen_done", "compile_done", "sim_done"))
    failed = sum(1 for r in results if r.status == "codegen_failed")
    logger.info(f"[codegen] Summary: {passed} passed, {failed} failed, "
                f"{len(results) - passed - failed} skipped")
    return results


# ---------------------------------------------------------------------------
# Stage 2: Cross-compilation
# ---------------------------------------------------------------------------

def _cross_compile_one(args: tuple) -> JobResult:
    """Worker function for parallel cross-compilation."""
    result, verbose, timeout = args
    jid = result.job_id
    out_dir = job_output_dir(jid)

    # Determine which C files exist (some models may not have process.c)
    c_files = []
    for fname in ["main.c", "model.c", "io.c", "process.c"]:
        if (out_dir / fname).exists():
            c_files.append(fname)

    if not c_files:
        result.status = "compile_failed"
        result.error = "No C files found in output directory"
        result.compile_rc = -1
        logger.error(f"[compile] {jid}: FAIL — {result.error}")
        return result

    include_flags = [
        f"-I{NN2_INCLUDE}",
        f"-I{NN2_INCLUDE}/shl_public",
        f"-I{NN2_INCLUDE}/csinn",
        f"-I{CMD_PARSE}",
        f"-I{out_dir}",
    ]
    cflags = ["-O2", "-g", "-mabi=lp64d"] + include_flags

    # Compile each .c → .o
    obj_files = []
    for cfile in c_files:
        ofile = cfile.replace(".c", ".o")
        cmd = [RISCV_GCC] + cflags + ["-c", "-o", ofile, cfile]
        rc, stdout, stderr = run_cmd(cmd, cwd=str(out_dir), timeout=timeout, verbose=verbose)
        if rc != 0:
            result.status = "compile_failed"
            result.compile_rc = rc
            err_lines = (stderr or "").strip().split("\n")
            result.error = f"Compile {cfile} failed: " + (err_lines[-1][:200] if err_lines else "unknown")
            logger.error(f"[compile] {jid}: FAIL compiling {cfile} (rc={rc})")
            return result
        obj_files.append(ofile)

    # Link
    link_flags = [
        f"-L{NN2_C906_LIB}",
        f"-L{PREBUILT_RT}",
        f"-L{DECODE_LIB}",
        "-Wl,--gc-sections", "-O2", "-g", "-mabi=lp64d",
        "-lshl", "-fopenmp", "-static",
        "-lprebuilt_runtime", "-ljpeg", "-lpng", "-lz", "-lstdc++", "-lm",
    ]
    cmd = [RISCV_GCC] + cflags + ["-o", "hhb_runtime"] + obj_files + link_flags
    rc, stdout, stderr = run_cmd(cmd, cwd=str(out_dir), timeout=timeout, verbose=verbose)

    if rc != 0 or not (out_dir / "hhb_runtime").exists():
        result.status = "compile_failed"
        result.compile_rc = rc
        err_lines = (stderr or "").strip().split("\n")
        result.error = f"Link failed: " + (err_lines[-1][:200] if err_lines else "unknown")
        logger.error(f"[compile] {jid}: FAIL linking (rc={rc})")
        return result

    result.status = "compile_done"
    result.compile_rc = 0
    logger.info(f"[compile] {jid}: PASS")
    return result


def run_compile(results: List[JobResult], checkpoint: Checkpoint,
                workers: int, verbose: bool, timeout: int) -> List[JobResult]:
    """Stage 2: parallel cross-compilation."""
    logger.info(f"{'='*60}")
    logger.info(f"Stage 2: RISC-V Cross-Compilation ({workers} workers)")
    logger.info(f"{'='*60}")

    jobs_to_run = []
    updated_results = []

    for r in results:
        if r.status == "codegen_failed":
            updated_results.append(r)
            continue
        if checkpoint.stage_done(r.job_id, "compile"):
            logger.info(f"[compile] {r.job_id}: skipped (checkpoint)")
            updated_results.append(r)
        else:
            jobs_to_run.append((r, verbose, timeout))

    if jobs_to_run:
        with multiprocessing.Pool(processes=workers) as pool:
            new_results = pool.map(_cross_compile_one, jobs_to_run)
        for r in new_results:
            checkpoint.save_job(r)
            updated_results.append(r)

    passed = sum(1 for r in updated_results if r.status in ("compile_done", "sim_done"))
    failed = sum(1 for r in updated_results if r.status == "compile_failed")
    logger.info(f"[compile] Summary: {passed} passed, {failed} failed")
    return updated_results


# ---------------------------------------------------------------------------
# Stage 3: QEMU Simulation
# ---------------------------------------------------------------------------


def run_simulate(results: List[JobResult], checkpoint: Checkpoint,
                 verbose: bool, timeout: int) -> List[JobResult]:
    """Stage 3: sequential QEMU simulation."""
    logger.info(f"{'='*60}")
    logger.info(f"Stage 3: QEMU Simulation (sequential, cpu={QEMU_CPU})")
    logger.info(f"{'='*60}")

    updated_results = []

    for r in results:
        if r.status in ("codegen_failed", "compile_failed"):
            updated_results.append(r)
            continue

        if checkpoint.stage_done(r.job_id, "sim"):
            logger.info(f"[sim] {r.job_id}: skipped (checkpoint)")
            # Restore sim results from checkpoint
            saved = checkpoint.get(r.job_id)
            if saved:
                r.runtime_ms = saved.get("runtime_ms")
                r.gops_per_s = saved.get("gops_per_s")
                r.status = saved["status"]
            updated_results.append(r)
            continue

        out_dir = job_output_dir(r.job_id)

        # HHB generates input bin files from --simulate-data during codegen.
        # Naming varies: input.0.bin, input_1.0.bin, x.0.bin, etc.
        # Pattern: <tensor_name>.<index>.bin — sort by the numeric index.
        bin_re = re.compile(r'^(.+)\.(\d+)\.bin$')
        bin_entries = []
        for f in out_dir.iterdir():
            m = bin_re.match(f.name)
            if m and not f.name.endswith('.tensor'):
                bin_entries.append((int(m.group(2)), f.name))
        bin_entries.sort(key=lambda x: x[0])
        bin_files = [name for _, name in bin_entries]
        if not bin_files:
            r.status = "sim_failed"
            r.error = "No *.N.bin input files found (HHB should have generated them)"
            logger.error(f"[sim] {r.job_id}: FAIL — {r.error}")
            checkpoint.save_job(r)
            updated_results.append(r)
            continue

        # Run QEMU with PTY to capture output before potential segfault
        cmd = [QEMU, "-cpu", QEMU_CPU, "./hhb_runtime", "hhb.bm"] + bin_files
        logger.info(f"[sim] {r.job_id}: starting QEMU simulation")
        rc, stdout, stderr = run_cmd(cmd, cwd=str(out_dir), timeout=timeout,
                                     verbose=verbose, use_pty=True)

        r.sim_rc = rc

        # Parse timing even if rc != 0 — split model parts often segfault AFTER
        # printing timing because the output tensor has a nil data pointer.
        # This is expected for split subgraphs and the timing is still valid.
        match = re.search(r"Run graph execution time:\s*([\d.]+)ms", stdout)
        if match:
            r.runtime_ms = float(match.group(1))
            runtime_s = r.runtime_ms / 1000.0
            r.gops_per_s = r.gops / runtime_s if runtime_s > 0 else 0.0
            r.status = "sim_done"
            extra = ""
            if rc != 0:
                extra = f" (QEMU rc={rc}, likely post-inference segfault — timing is valid)"
            logger.info(
                f"[sim] {r.job_id}: PASS — "
                f"runtime={r.runtime_ms:.3f}ms, "
                f"GOPS={r.gops:.6f}, "
                f"GOPS/s={r.gops_per_s:.6f}{extra}"
            )
        elif rc == 0:
            # QEMU succeeded but no timing in output
            r.status = "sim_done"
            r.runtime_ms = None
            r.gops_per_s = None
            logger.warning(
                f"[sim] {r.job_id}: PASS (no timing in output). "
                f"stdout: {stdout[:500]}"
            )
        else:
            r.status = "sim_failed"
            combined = (stdout + "\n" + stderr).strip()
            err_lines = combined.split("\n")
            r.error = "\n".join(err_lines[-5:])[:500]
            logger.error(f"[sim] {r.job_id}: FAIL (rc={rc}) — {err_lines[-1][:200]}")

        checkpoint.save_job(r)
        updated_results.append(r)

    passed = sum(1 for r in updated_results if r.status == "sim_done")
    failed = sum(1 for r in updated_results if r.status == "sim_failed")
    logger.info(f"[sim] Summary: {passed} passed, {failed} failed")
    return updated_results


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def write_report(results: List[JobResult]):
    """Write c906_results.json and print summary table."""
    report = {
        "generated_at": datetime.datetime.now().isoformat(),
        "results": [],
        "summary": {
            "total_jobs": len(results),
            "codegen_pass": 0, "codegen_fail": 0,
            "compile_pass": 0, "compile_fail": 0,
            "sim_pass": 0, "sim_fail": 0,
        },
    }

    for r in results:
        entry = {
            "model": r.model_name,
            "part": f"part{r.part_index:03d}",
            "quant": r.quant,
            "gops": round(r.gops, 9),
            "runtime_s": round(r.runtime_ms / 1000.0, 6) if r.runtime_ms else None,
            "runtime_ms": round(r.runtime_ms, 3) if r.runtime_ms else None,
            "gops_per_s": round(r.gops_per_s, 6) if r.gops_per_s else None,
            "status": r.status,
            "error": r.error,
        }
        report["results"].append(entry)

        s = report["summary"]
        # A later stage failure implies all earlier stages passed
        if r.status in ("codegen_done", "compile_done", "sim_done",
                        "compile_failed", "sim_failed"):
            s["codegen_pass"] += 1
        elif r.status == "codegen_failed":
            s["codegen_fail"] += 1

        if r.status in ("compile_done", "sim_done", "sim_failed"):
            s["compile_pass"] += 1
        elif r.status == "compile_failed":
            s["compile_fail"] += 1

        if r.status == "sim_done":
            s["sim_pass"] += 1
        elif r.status == "sim_failed":
            s["sim_fail"] += 1

    with open(RESULTS_FILE, "w") as f:
        json.dump(report, f, indent=2)

    # Print summary table
    logger.info(f"\n{'='*90}")
    logger.info("RESULTS SUMMARY")
    logger.info(f"{'='*90}")
    header = f"{'Model':<35} {'Part':<8} {'Quant':<10} {'GOPS':<12} {'Runtime(ms)':<14} {'GOPS/s':<12} {'Status':<15}"
    logger.info(header)
    logger.info("-" * 90)
    for r in sorted(results, key=lambda x: (x.model_name, x.part_index, x.quant)):
        rt_str = f"{r.runtime_ms:.2f}" if r.runtime_ms else "N/A"
        gops_s_str = f"{r.gops_per_s:.6f}" if r.gops_per_s else "N/A"
        logger.info(
            f"{r.model_name:<35} part{r.part_index:03d}  {r.quant:<10} "
            f"{r.gops:<12.6f} {rt_str:<14} {gops_s_str:<12} {r.status}"
        )

    logger.info(f"\n{'='*90}")
    s = report["summary"]
    logger.info(f"Total jobs: {s['total_jobs']}")
    logger.info(f"  Codegen: {s['codegen_pass']} pass, {s['codegen_fail']} fail")
    logger.info(f"  Compile: {s['compile_pass']} pass, {s['compile_fail']} fail")
    logger.info(f"  Simulate: {s['sim_pass']} pass, {s['sim_fail']} fail")

    # Log pass/fail lists
    if any(r.status == "codegen_failed" for r in results):
        logger.info("\nFailed codegen jobs:")
        for r in results:
            if r.status == "codegen_failed":
                logger.info(f"  {r.job_id}: {r.error}")

    if any(r.status == "compile_failed" for r in results):
        logger.info("\nFailed compile jobs:")
        for r in results:
            if r.status == "compile_failed":
                logger.info(f"  {r.job_id}: {r.error}")

    if any(r.status == "sim_failed" for r in results):
        logger.info("\nFailed simulation jobs:")
        for r in results:
            if r.status == "sim_failed":
                logger.info(f"  {r.job_id}: {r.error}")

    logger.info(f"\nResults written to: {RESULTS_FILE}")
    logger.info(f"Full log: {LOG_FILE}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():

    parser = argparse.ArgumentParser(
        description="Batch compile & simulate ONNX models on C906 via HHB + QEMU"
    )
    parser.add_argument("--workers", type=int, default=multiprocessing.cpu_count(),
                        help=f"Parallel workers (default: {multiprocessing.cpu_count()})")
    parser.add_argument("--force", action="store_true",
                        help="Ignore checkpoint, rerun everything")
    parser.add_argument("--codegen-only", action="store_true",
                        help="Stop after HHB codegen")
    parser.add_argument("--compile-only", action="store_true",
                        help="Stop after cross-compilation")
    parser.add_argument("--quant", type=str, default=",".join(QUANT_SCHEMES),
                        help=f"Comma-separated quant schemes (default: {','.join(QUANT_SCHEMES)})")
    parser.add_argument("--model", type=str, default=None,
                        help="Comma-separated model dir names (default: all)")
    parser.add_argument("--verbose", action="store_true",
                        help="Print full subprocess output")
    parser.add_argument("--codegen-timeout", type=int, default=600,
                        help="Timeout per codegen job in seconds (default: 600)")
    parser.add_argument("--compile-timeout", type=int, default=300,
                        help="Timeout per compile job in seconds (default: 300)")
    parser.add_argument("--sim-timeout", type=int, default=3600,
                        help="Timeout per simulation job in seconds (default: 3600)")
    args = parser.parse_args()

    setup_logging(args.verbose)

    logger.info(f"{'='*60}")
    logger.info("HHB C906 Batch Compile & Simulate")
    logger.info(f"{'='*60}")
    logger.info(f"Workers: {args.workers}")
    logger.info(f"Force: {args.force}")
    logger.info(f"Quant schemes: {args.quant}")

    # Parse filters
    quants = [q.strip() for q in args.quant.split(",")]
    model_filter = [m.strip() for m in args.model.split(",")] if args.model else None

    # Prerequisite checks
    for tool, path in [("hhb", HHB_BIN), ("gcc", RISCV_GCC), ("qemu", QEMU)]:
        if not os.path.isfile(path) or not os.access(path, os.X_OK):
            logger.error(f"Tool not found or not executable: {tool} at {path}")
            sys.exit(1)

    # Stage 0: Discovery
    logger.info(f"\n{'='*60}")
    logger.info("Stage 0: Discovery & GOPS Calculation")
    logger.info(f"{'='*60}")
    parts = discover_models(model_filter)

    if not parts:
        logger.error("No model parts discovered. Check hhb/model_split/ directory.")
        sys.exit(1)

    # Initialize checkpoint
    checkpoint = Checkpoint(CHECKPOINT_FILE, force=args.force)

    # Stage 1: HHB Codegen
    results = run_codegen(parts, quants, checkpoint, args.workers, args.verbose, args.codegen_timeout)

    if args.codegen_only:
        write_report(results)
        return

    # Stage 2: Cross-compilation
    results = run_compile(results, checkpoint, args.workers, args.verbose, args.compile_timeout)

    if args.compile_only:
        write_report(results)
        return

    # Stage 3: QEMU Simulation
    results = run_simulate(results, checkpoint, args.verbose, args.sim_timeout)

    # Final report
    write_report(results)


if __name__ == "__main__":
    main()
