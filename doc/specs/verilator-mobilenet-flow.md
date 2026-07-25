# Verilator RTL simulation of MobileNetV2 (ONNX opset 17) on OpenC906

This documents the end-to-end flow added to run an ONNX-model-zoo **MobileNetV2
(opset 17)** as bare-metal inference on the C906 RTL under **Verilator** on
macOS (Apple Silicon), and the bugs fixed along the way.

## What was added

### 1. Verilator simulation backend (`SIM=verilator`)
`smart_run/Makefile` gained a `verilator` branch alongside `vcs/nc/iverilog`
(GNU make 3.81-safe nested `ifeq`). It verilates the SoC + testbench once with:

```
verilator --binary -j 10 --threads 1 -O3 --top-module tb --timescale 1ns/1ps \
  -Wno-fatal -Wno-TIMESCALEMOD -Wno-IMPLICIT -Wno-WIDTH -Wno-UNOPTFLAT \
  --x-assign fast --x-initial fast -o simv \
  -f $CODE_BASE_PATH/gen_rtl/filelists/C906_asic_rtl.fl \
  -f $CODE_BASE_PATH/gen_rtl/filelists/tdt_dmi_top_rtl.fl \
  -f ../logical/filelists/smart.fl -f ../logical/filelists/tb.fl +define+NO_DUMP
```

Produces `work/obj_dir/simv` (self-contained, relocatable). Runs at ~130 kHz
(≈130k core cycles / wall-second). `smart_run/scripts/smart_runner.py` also
gained a `verilator` backend and a `--cases` filter.

Only **one** tb.v edit was needed (`ifdef VERILATOR` dump guard); every other
risky construct (real-delay clockgen, `#(real)` timeout, `$value$plusargs("%f")`,
`disable` of a named block) works under `--binary --timing`. Two tb.v fixes were
required for the NN path (see Bugs 1–2).

### 2. macOS toolchain / build glue
- `setup/local_setup.sh`: bash replacement for the server csh setup
  (`CODE_BASE_PATH`, `TOOL_EXTENSION`, `CONVERT`, `THEAD_GCC=0`).
- xPack `riscv-none-elf-gcc` 15.2 with a `riscv64-unknown-elf-*` symlink farm.
- `tests/bin/srec2vmem.py`: pure-Python replacement for the Linux-x86 `Srec2vmem`.
- `tests/lib/Makefile`: `THEAD_GCC=0` path with portable `-march`
  (`rv64imafdc_zfh_zicsr_zifencei`, no `xtheadc`); `crt0.s` `mxstatus`→numeric CSR.
- csi-nn2 built with the reference (`CSINN_REF`) backend at `-O2`
  (`CMakeLists.txt` `C906_MARCH` cache var; `__fp16`→`_Float16`, `-std=gnu17`).

### 3. ONNX → CSI-NN2 generator (replaces HHB, which is Linux-only)
`smart_run/scripts/onnx2csinn.py` emits a bare-metal case from any node range of
an ONNX graph: fp32 `CSINN_REF` graph-builder `model.c`, a `blob.bin` =
`[params(qinfo+weights) | input | golden]`, and `model_config.h`. Weights never
enter the ELF — the blob is loaded by the testbench into SRAM at `0x01000000`
(the 32 MB NN window) and `csinn_()` reads through `params_base` pointers.
Goldens are computed with onnxruntime.

`smart_run/scripts/gen_segments.py` splits a model at **articulation points**
(node boundaries crossed by exactly one activation) into balanced, independently
verifiable segments — every segment has one input (fed from the full-model ORT
run) and one golden output, so segments run in parallel and together cover the
whole network. `scripts/run_parallel_models.sh` builds them serially and runs
all sims concurrently (one single-threaded process per core).

The verification harness (`tests/cases/nn_model_common/bare_main.c`,
`PARAMS_IN_SRAM` path) points inputs at the SRAM blob, runs the graph, reads
outputs via `csinn_get_output`, and compares against the golden
(atol 1e-4 / rtol 1e-3, plus argmax for the classifier). PASS only on match.

## Bugs found and fixed

1. **`input.pat` overruns the legacy 16K array** — tb.v `$readmemh("input.pat",
   mem_input_temp)` is fatal in Verilator once the file exceeds 16384 words.
   Fixed with an `ifdef VERILATOR` that loads only the big NN array and mirrors
   its head into the legacy window.
2. **Watchdog false-trip at t=0** — `cycle_count` was uninitialized; under a
   2-state simulator `(count % 50000)==0` fires on the first edge. Initialized to 1.
3. **`.pat` byte order** — `prepare_model.py` packed words little-endian, but the
   tb byte-lane wiring places the leftmost hex byte at the lowest address (as
   `Srec2vmem` does for code). Every NN fp32 was byte-reversed in SRAM; undetected
   because no prior case verified output values. Fixed to big-endian (`>I`).
4. **Missing `save_mode`** — generated sessions left `sess->model.save_mode` at
   its zero default `CSINN_SAVE_AND_RUN`, so `csinn_session_setup` tried to
   `fopen` a binary-model file (NULL on bare metal → fault). Set `CSINN_RUN_ONLY`.
5. **Wrong output read** — in graph mode `sess->output[k]->data` is a tensor
   pointer, not a float buffer; outputs must be read via `csinn_get_output` +
   `shl_ref_tensor_transform_f32`.
6. GCC-15 build issues in csi-nn2: `__fp16` (Xuantie-only) and C23 default
   (`func()` prototype) — fixed with `-D__fp16=_Float16 -std=gnu17`.

## Performance note

The reference fp32 kernels run ~100 cyc/MAC in sim (cross-TU index/callback
overhead; no RVV on this GCC). MobileNetV2 at 224×224 is ~300M MACs (~hours even
split) so the flow runs the real network (real weights, all 170 nodes, opset 17)
at reduced input resolution — MobileNetV2 is fully convolutional and accepts any
HxW. 64×64 ≈ 25M MACs, split into 10 parallel segments (~45 min wall).

## Reproduce (Verilator, macOS)

```
source smart_run/setup/local_setup.sh
cd smart_run && make compile SIM=verilator DUMP=off          # verilate once
# real MobileNetV2 (opset 17) segments at 64x64, run in parallel:
python3 scripts/gen_segments.py --onnx ../hhb/model/mbv2_64/mbv2_64.onnx \
    --input-npz ../hhb/model/mbv2_64/random_input.npz --prefix mb64 \
    --out-root tests/cases/model_compiled --target-segments 12
bash scripts/run_parallel_models.sh 8e9 mb64_seg00 mb64_seg01 ... mb64_seg09
```

## VCS backend + per-segment FSDB (for PrimePower)

Verilator produces VCD only; **FSDB is VCS-specific** and targets a machine with
VCS + Verdi (the server). Each segment is an independent simulation, so each
dumps its **own FSDB — there is no merge**.

- **tb.v FSDB block** (VCS/`else` branch, guarded so Verilator/NC/iverilog are
  untouched): filename from `+FSDB=<file>` (default `novas.fsdb`); scope defaults
  to the **core** `$fsdbDumpvars(0, `CPU_TOP)` — `tb.x_soc...x_cpu_top`, matching
  the PTPX `read_fsdb -strip_path` and GLS SDF region, and excluding the two
  256 MB SRAM banks (the old bare `$fsdbDumpvars()` dumped the whole SoC → the
  ~9.5 GB monolith). `+define+FSDB_FULL_SOC` restores full-SoC. Optional dump
  window: `+FSDB_BEGIN=<ns>` / `+FSDB_END=<ns>` (default whole run).
- **Makefile**: `FSDB_SCOPE=core` (default) / `full` selects the scope define.
- **`smart_runner.py regress --sim vcs --dump on`** is the idiomatic path: it
  compiles VCS once, runs each segment in an isolated dir (symlinking
  `simv`+`simv.daidir`), collects each dir's FSDB to
  `tests/regress/regress_result/<case>.fsdb`, and emits `fsdb_run_list.txt`
  (absolute paths, ready for `impl/ptpx/run_ptpx_parallel.py --fsdb_list_file`).
  Its Python NN-build path was aligned with the Makefile `NN_MODEL_BUILD` recipe
  (adds `-fno-optimize-sibling-calls` and the big-heap `linker_model.lcf`).
- `run_parallel_models.sh --sim vcs <MST> <segs...>` does the same via the shell
  runner (compile `SIM=vcs DUMP=on`, snapshot `simv`+`simv.daidir`, run with
  `+FSDB=<case>.fsdb`), collecting `work_par/results/<case>.fsdb` + a
  `fsdb_run_list.txt`.

```
# on a VCS/Verdi machine:
source smart_run/setup/local_setup.sh
cd smart_run
python3 scripts/smart_runner.py regress --sim vcs --dump on -j 8 \
    --cases mb64_seg00,mb64_seg01,...,mb64_seg09
# -> tests/regress/regress_result/<seg>.fsdb (core scope) + fsdb_run_list.txt
python3 impl/ptpx/script/run_ptpx_parallel.py \
    --fsdb_list_file tests/regress/regress_result/fsdb_run_list.txt --clk_period 1
```
