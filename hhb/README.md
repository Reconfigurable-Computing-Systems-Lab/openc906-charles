# HHB Model Pipeline for C906

End-to-end workflow for splitting large ONNX models, compiling them with the
[HHB](https://www.xrvm.com/document?temp=hhb-user-manual&slug=hhb-user-manual)
toolchain targeting the T-Head C906 RISC-V core, simulating via QEMU, and
collecting the results.

## Directory Layout

```
hhb/
├── split_onnx_models.py   # Step 1 — Split ONNX models into subgraphs
├── run_hhb_c906.py        # Step 2 — Compile & simulate on C906
├── result_collect.py      # Step 3 — Collect passed artifacts
├── model/                 # Source ONNX models (input to Step 1)
├── model_split/           # Split subgraphs + manifests (output of Step 1, input to Step 2)
└── model_compiled/        # Collected artifacts from passed cases (output of Step 3)
```

## Prerequisites

| Tool | Path |
|------|------|
| HHB  | `/usr/local/bin/hhb` (v3.2+) |
| RISC-V GCC | `/opt/Xuantie-900-gcc-linux-*.../bin/riscv64-unknown-linux-gnu-gcc` |
| QEMU | `/opt/Xuantie-qemu-*.../bin/qemu-riscv64` |
| Python | 3.8+ with `onnx`, `numpy` |

## Step 1 — Split ONNX Models

`split_onnx_models.py` scans `model/` for ONNX files, splits models whose
initializer weights exceed a size threshold into sequential subgraphs, and
writes the parts to `model_split/`.

```bash
python3 split_onnx_models.py [OPTIONS]
```

| Option | Default | Description |
|--------|---------|-------------|
| `--model-root DIR` | `hhb/model/` | Directory with per-model folders containing `.onnx` files |
| `--output-root DIR` | `hhb/model_split/` | Output directory for split models |
| `--max-weight-kb N` | `128` | Max initializer size per submodel (KB) |
| `--max-weight-bytes N` | — | Byte-level override for max weight size |
| `--dry-run` | off | Report predicted splits without writing files |
| `--no-resume` | off | Ignore checkpoint, reprocess everything |
| `--force` | off | Rewrite output even if checkpoint says success |

Each model directory in the output gets a `manifest.json` describing its parts,
input/output names, shapes, and paths to the `.onnx` and `_input.npz` files.

## Step 2 — Compile & Simulate

`run_hhb_c906.py` reads the split models from `model_split/`, compiles each
part with HHB for C906 using three quantization schemes (int8 symmetric,
float16, float32), cross-compiles the generated C code, and simulates via QEMU.

```bash
python3 run_hhb_c906.py [OPTIONS]
```

| Option | Default | Description |
|--------|---------|-------------|
| `--workers N` | CPU count | Parallel workers for codegen & compile stages |
| `--quant SCHEMES` | `int8_sym,float16,float32` | Comma-separated quantization schemes |
| `--model NAMES` | all | Comma-separated model directory names to process |
| `--force` | off | Ignore checkpoint, rerun everything |
| `--codegen-only` | off | Stop after HHB codegen (Stage 1) |
| `--compile-only` | off | Stop after cross-compilation (Stage 2) |
| `--verbose` | off | Print full subprocess output |
| `--codegen-timeout` | 600 | Timeout per codegen job (seconds) |
| `--compile-timeout` | 300 | Timeout per compile job (seconds) |
| `--sim-timeout` | 3600 | Timeout per simulation job (seconds) |

### Pipeline Stages

1. **Discovery** — Reads `manifest.json` files, counts MACs/GOPS from ONNX
   graphs (Conv, MatMul, Gemm; 1 MAC = 2 OPs).
2. **HHB Codegen** — Parallel. Runs `hhb -C --board c906` to generate C code,
   binary model (`hhb.bm`), and input bin files.
3. **Cross-Compile** — Parallel. Compiles generated C with the Xuantie RISC-V
   GCC toolchain, linking against the C906 SHL library.
4. **QEMU Simulation** — Sequential. Runs each binary under QEMU (`c907fdvm`
   CPU) and parses the `Run graph execution time` output.

### Checkpoint & Resume

Progress is saved to `model_split/c906_checkpoint.json` after each job.
Re-running the script skips all previously succeeded jobs. Failed jobs are
retried. Use `--force` to ignore the checkpoint and rerun everything.

### Output

| File | Description |
|------|-------------|
| `model_split/c906_results.json` | Full results: GOPS, runtime, GOPS/s, status per job |
| `model_split/c906_checkpoint.json` | Checkpoint for resume |
| `model_split/c906_run.log` | Detailed execution log |
| `model_split/<model>/<part>_c906_<quant>/` | Per-job build artifacts |

## Step 3 — Collect Results

`result_collect.py` reads `c906_results.json`, copies key artifacts from passed
cases into a flat output directory, and writes a filtered results JSON.

```bash
python3 result_collect.py [OPTIONS]
```

| Option | Default | Description |
|--------|---------|-------------|
| `--results FILE` | `model_split/c906_results.json` | Path to results JSON |
| `--output-dir DIR` | `hhb/model_compiled/` | Output directory |
| `--clean` | off | Remove output directory before collecting |

### Collected Files (per passed case)

Output directories are flat, e.g. `model_compiled/conv_softmax_part000_c906_float16/`:

- `model.c` — HHB-generated inference graph
- `model.params` — Quantized model weights
- `*.N.bin` — Input binary files for simulation

A `c906_compiled_results.json` in the output directory lists all collected cases
with their GOPS, runtime, and GOPS/s metrics.

## Example: Full Pipeline

```bash
cd hhb/

# 1. Split models (if not already done)
python3 split_onnx_models.py

# 2. Compile & simulate all splits
python3 run_hhb_c906.py --workers 4

# 3. Collect passed artifacts
python3 result_collect.py --clean
```
