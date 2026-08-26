# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RTL source and simulation environment for the **T-Head OpenC906**, a 64-bit RISC-V core (RV64GCV + Xtheadc custom extensions). The repo contains synthesizable Verilog RTL (`C906_RTL_FACTORY/`), a demo SoC + self-checking testbench (`smart_run/`), an ML inference stack (`csi-nn2/` submodule + `hhb/` scripts), and a full ASIC flow (SRAM generation → DC synthesis with clock gating → SDF gate-level sim → PrimePower) under `smart_run/impl/` (TSMC 28HPC+; see `smart_run/impl/README_FLOW.md`).

## Build & Simulation Commands

All simulation runs from `smart_run/`; artifacts land in `smart_run/work/`.

**Environment setup (required first, csh):** copy/edit `smart_run/setup/example_setup.csh` — its hardcoded `/dfs/usrhome/...` paths are for a remote server and must be changed. Two variables:
- `CODE_BASE_PATH` — absolute path to `C906_RTL_FACTORY/` (consumed by filelists)
- `TOOL_EXTENSION` — `bin/` of a Xuantie riscv64-unknown-elf-gcc install (missing value only *warns* at `tool-chain-chk`; the build then fails later inside `work/`)

```bash
make showcase                        # list all valid CASE names
make compile [SIM=vcs|nc|iverilog|verilator] [DUMP=on|off]   # compile RTL + TB (default SIM=vcs, DUMP=on)
make buildcase CASE=ISA_INT          # cross-compile one test to inst.pat/data.pat
make runcase CASE=ISA_INT [SIM=...] [DUMP=...]     # compile + build + run one test
make regress [REGRESS_LIST="..."]    # sequential full regression; report at <repo>/regress/regress_report
make cleansim / cleancase / clean    # remove sim products / case products / all of work/
make covreport / cleancov            # per-unit coverage report / remove smart_run/cov/
```

Extra knobs: `SIM_ARGS=+MAX_SIM_TIME=4e6` passes plusargs to the run step (there
was no other way to reach them from `make`); `COVERAGE=line|all` turns on code
coverage (Verilator `--coverage-line[+--coverage-toggle]`, VCS `-cm`), which
forces `DUMP=off` unless `COV_ALLOW_DUMP=1`; `MON=all` compiles all five per-unit
port-toggle monitors so any case can be measured against every pipeline unit at
once. Coverage artifacts accumulate in `smart_run/cov/` (gitignored) — `work/` is
wiped between regression cases.

`iverilog` (open-source) is fully supported even though `make help` only mentions vcs/nc. `DUMP=off` defines `NO_DUMP` (skip waveforms — use for regressions). Waveforms: FSDB for VCS, VCD for irun/iverilog, in `work/`.

**Test output**: result in `work/run_case.report` (PASS/FAIL + UART text), sim log `work/run.{vcs,irun,iverilog}.log`, build log `work/<CASE>_build.case.log`.

**Runtime timeout**: default 3s sim time (`MAX_RUN_TIME 3_000_000_000.0` ns in tb.v); override per-run with `make runcase ... SIM_ARGS=+MAX_SIM_TIME=<ns>` (accepts reals). This matters: a livelock that *retires* instructions is invisible to the 50,000-cycle no-retire watchdog, so only the sim-time limit catches it — and 3e9 ns at Verilator's ~118 kcycle/s is hours.

Test cases (`CASE_LIST` in `smart_run/setup/smart_cfg.mk`): `ISA_THEAD ISA_INT ISA_LS ISA_FP coremark MMU interrupt exception debug csr cache conv_softmax cp0_random iu_random vidu_random idu_random ifu_random`. Others exist under `tests/cases/` (e.g. `ISA/ISA_VECTOR/`) but must be added to `smart_cfg.mk` first. `REGRESS_LIST` (default `CASE_LIST`) selects what `make regress` runs — use `REGRESS_LIST="$(filter-out $(RAND_CASES),$(CASE_LIST))"` to skip the randomized cases.

`cp0_random` is the randomized CP0 stress test (`doc/specs/cp0-design-and-test.md` Part II): ~100K seeded dynamic iterations over 42 operation groups, tuned by `CP0_ITERS` / `CP0_SEED` / `CP0_EXTRA`. It writes a per-port toggle report for `aq_cp0_top` to `work/cp0_toggle.report` alongside the usual PASS/FAIL, and `tests/cases/cp0_random/run_groups.sh` bisects one group at a time. Not supported under `SIM=iverilog` (its filelist carries a `+define+`).

`iu_random` / `vidu_random` / `idu_random` / `ifu_random` apply the same methodology to the four pipeline units — **the reference is `doc/specs/unit-random-tests.md`**. Each is a seeded dispatch loop over 42-46 groups aimed at named RTL structures, tuned by `<U>_ITERS` / `<U>_SEED` / `<U>_OPT` / `<U>_EXTRA` (`-D<U>_ONLY_GROUP=n` bisects; each case ships a `run_groups.sh`), and each writes `work/<unit>_toggle.report`. `<U>_OPT` is worth knowing about: changing the optimisation level changes GCC's instruction selection, i.e. changes the stimulus, so `-O0/-O1/-O2/-Os` are four different decode streams for free. All four share `tests/cases/rand_common/` (PRNG, trap handler with a cause histogram and an unwind path, PMP helper, baseline-state restore, D-cache-off UART printer) — `cp0_random` deliberately keeps its own copies; see that directory's README. Like `cp0_random`, none of the four works under `SIM=iverilog`. Two notes that surprise people: **`gen_rtl/vidu/` has no vector logic in this release** (every `*_vec` submodule is a commented-out `&Instance` and `decd_sel[5]=1'b0` makes every RVV instruction trap illegal), so `vidu_random` targets the scalar FP issue unit; and `ifu_random`'s stimulus is *generated code* — `gen_ifu_arena.py` emits a seeded `.text.arena` of raw encodings at build time, because IFU coverage is per-address-layout and C cannot express it.

## Architecture

### RTL Hierarchy

```
openC906.v            — processor top (C906_RTL_FACTORY/gen_rtl/cpu/rtl/); instantiate for SoC integration
 ├─ aq_top.v          — wraps the core; instantiates aq_core (~126KB file, the pipeline)
 ├─ clint_top.v       — CLINT (gen_rtl/clint/rtl/)      ← NOT inside aq_top
 ├─ plic_top.v        — PLIC, 240 sources (gen_rtl/plic/rtl/)
 ├─ aq_biu_top        — AXI bus interface
 └─ aq_sysio_top
```

Pipeline units live in `gen_rtl/<unit>/rtl/`: `ifu` (fetch, BHT/BTB/RAS, I$), `idu` (decode/dispatch), `iu` (ALU/branch/mul/div), `lsu` (load/store, D$, store buffer), `rtu` (retire/exceptions), `cp0` (CSRs), `mmu` (jTLB, PTW, sysmap), `vdsp`/`vfalu`/`vfmau`/`vidu` (vector/FP), `dtu`/`tdt` (debug/JTAG), `biu`.

**Compile-time config** via `` `define `` headers listed in `gen_rtl/filelists/C906_asic_rtl.fl`: `cpu/rtl/cpu_cfig.h` (cache sizes 8K–64K, BHT, jTLB, FPU/vector enable, PA=40/VA=39), `idu/rtl/aq_idu_cfig.h` (VLEN 64/128/256), `lsu/rtl/aq_lsu_cfig.h`, `dtu/rtl/aq_dtu_cfig.h`, `mmu/rtl/sysmap.h` (8 memory-attribute regions).

### Demo SoC & Testbench (`smart_run/logical/`)

`common/soc.v`: C906 + 128-bit AXI crossbar (`axi/axi_interconnect128.v`) + L3 SRAM (`axi/axi_slave128.v`: two `f_spsram_8388608x128` banks = 2×128MB, bank select `mem_addr[27]`, window `0x0–0x0FFFFFFF`) + UART/GPIO/Timer via AHB→APB.

`tb/tb.v` loads pattern files into SRAM via `$readmemh`, watches RTU writeback GPRs for magic values — PASS `64'h444333222`, FAIL `64'h2382348720` — and declares FAIL if no instruction retires for 50,000 cycles (deadlock watchdog). `CLK_PERIOD` is `1.0` and must stay a *real* literal (integer `1/2=0` → zero-delay infinite loop). Hierarchy shortcut macros: `` `SOC_TOP ``, `` `CPU_TOP ``, `` `RTL_MEM ``, `` `RTL_MEM2 ``. Signal-probe reference: `smart_run/key_signal.rc` and `doc/specs/c906_key_func_signals.md` (the old `doc/tb-reference.md` no longer exists; trust tb.v itself for the temp-array sizes). **`tb.v:98` wipes SRAM only below `0x0016_3830`** — above that the RAM arrays are uninitialised, which reads as X under VCS and as 0 under Verilator, so never fetch or load there.

Memory map: text `0x0` (inst.pat, 256KB) · data `0x40000` (data.pat, 256KB pattern; linker MEM2 region is 768KB) · NN input dual-mapped at `0x80000` (64KB, small models) and `0x01000000` (up to 32MB, `mem_nn_input_temp`) · stack top `0xEE000` · UART at AXI `0x10015000` (CPU-side address is `0x40015000` in `tests/lib/clib/uart.h`; tb snoops the AXI address for console capture).

### Filelists

`logical/filelists/sim.fl` = `ip.fl` (pulls C906 RTL via `${CODE_BASE_PATH}`) + `smart.fl` (SoC periphs) + `tb.fl`. iverilog bypasses `sim.fl` and passes the C906 filelists directly. The `debug` case swaps in extra JTAG driver files (`tests/cases/debug/JTAG_DRV.vh`, `C906_DEBUG_PATTERN.v`) so it gets its own RTL compile.

## Tests

Each test dir under `tests/cases/<category>/` is compiled with `tests/lib/crt0.s` (inits GPRs/FPU/vector, enables caches, traps, jumps to `main`), linked with `tests/lib/linker.lcf`, converted ELF→`inst.pat`/`data.pat`, and signals completion by writing the magic value to a GPR. Mini libc (printf/UART/interrupts/timer) in `tests/lib/clib/`.

**Adding a test**: create the dir, add a `<NAME>_build` recipe in `setup/smart_cfg.mk` (copy an existing `*_build:` target), append the name to `CASE_LIST`. Copy files into `work/` **one at a time**, never `cp dir/*` — `tests/lib/Makefile` globs every `.c`/`.s`/`.S` in `work/` and links the result, and `make cleancase` deletes `work/*.v`, so monitors, filelists and scripts must stay out. Note also that the case Makefile's `clean` removes `work/*.pat`, which is why `conv_softmax_build` and `ifu_random_build` copy their pattern files in *after* the build.

For a new *randomized* test, start from `tests/cases/rand_common/` (shared PRNG, trap handler with a cause histogram and an unwind path, PMP helper, baseline-state restore, D-cache-off UART printer) and read its README plus `doc/specs/unit-random-tests.md` Part 0 §5 first — most of those rails exist because something hung without them.

**NN model auto-discovery**: any `tests/cases/model_compiled/<name>/model.c` becomes a case automatically (`MODEL_CASES` glob in `smart_cfg.mk`) using the generic `NN_MODEL_BUILD` recipe — it links `tests/cases/nn_model_common/` scaffolding (`bare_main.c` entry, `sbrk.c` heap+stubs, `stubs/`) and runs `onnx_sim_lib/prepare_model.py` (patches `model.c` CSINN_C906→CSINN_REF, generates `test_data.h` + `input.pat`). `model_compiled/` doesn't exist in a fresh checkout — drop HHB output in and `make runcase CASE=<name>` works immediately.

**Toolchain arch flags** (`CPU_ARCH_FLAG_0`, default builds use `c906fd`): `c906` = rv64imac_zifencei_xtheadc/lp64 · `c906fd` = +fd_zfh/lp64d · `c906fdv` = +v. Default `-O2`; coremark uses `-O3 -mtune=c906 -fno-optimize-sibling-calls -fno-code-hoisting`.

## ML Inference — Two Separate Workflows (don't conflate)

**A. QEMU functional/perf sim (`hhb/`)**: `split_onnx_models.py` (split ONNX > 128KB weights into chained subgraphs under `model_split/`) → `run_hhb_c906.py` (HHB codegen → riscv64-linux-gnu cross-compile → QEMU, checkpoint/resume via `model_split/c906_checkpoint.json`) → `result_collect.py` (collect passing artifacts into `hhb/model_compiled/`). Uses the RVV **1.0** SHL library — QEMU must run `-cpu c907fdvm`, not `c906fd` (illegal instruction otherwise). Tool paths are hardcoded in `run_hhb_c906.py`. Split subgraph parts segfaulting after printing timing is expected. See `hhb/README.md`.

**B. Bare-metal RTL sim** (`doc/csi-nn2-bare-metal-guide.md`): real C906 RTL implements RVV **0.7.1**, but GCC 14 emits only RVV 1.0 — so the RTL flow must use the CSI-NN2 reference C backend (`CSINN_REF`), never the vector-optimized one. Build the static lib once:

```bash
cd csi-nn2 && mkdir c906_elf_build && cd c906_elf_build && \
cmake .. -DCMAKE_SYSTEM_NAME=Generic -DCMAKE_C_COMPILER=riscv64-unknown-elf-gcc \
  -DCMAKE_ASM_COMPILER=riscv64-unknown-elf-gcc -DCONFIG_BUILD_RISCV_ELF_C906=ON \
  -DCMAKE_INSTALL_PREFIX=../install_nn2/c906 && make -j8 && make install
```

then `make runcase CASE=conv_softmax SIM=vcs` (or drop HHB output into `model_compiled/`).

## Known Bugs

- **Indirect-jump tail calls hang the RTL**: an indirect jump used as a tail call — `jr <reg>`, i.e. `jalr x0, rs, 0`, with the target loaded from memory — stalls retirement → FAIL. `jalr ra, rs, 0` (a real call) is fine, and so is `ret`, so the trigger is narrower than "any `jalr` with `rd=x0`". Always compile library code with `-fno-optimize-sibling-calls`, and add `-fno-jump-tables` for anything with a large `switch` (GCC's dispatch table is the same construct). No computed `goto`, and no jumping into runtime-generated code with `jr`. Full analysis: `doc/specs/csi-nn2-bare-metal-guide.md` §7 — note the root cause there is an *uninitialised* `static void *table[]` in `.bss` (not in `data.pat`), so `jr` goes to 0, re-enters `__start`, and restarts forever. That livelock retires instructions, which is why the 50,000-cycle watchdog never fires and only `MAX_RUN_TIME` catches it.
- **crt0.s trap vector table**: entries are `.long` (4 bytes) but the handler loads with `ld` (8 bytes) → infinite exception loop on any trap. Install your own `mtvec` handler in bare-metal code that needs traps.

## RTL Conventions

- Core modules use `aq_` prefix; tops end in `_top`. Signals follow `source_dest_signal` (`biu_ifu_arready` = BIU→IFU). Pads: `pad_` prefix. Active-low: `_b` suffix; flops `_ff`; valids `_vld`.
- `// &Depend(...)`, `// &ModuleBeg;`, `// &Ports;` etc. are T-Head proprietary tool directives — leave them alone; they're inert for simulation.
- FPGA-friendly behavioral SRAMs in `gen_rtl/fpga/` replace foundry macros for sim.

## ASIC Implementation Flow (`smart_run/impl/`)

Five-stage server-side flow (TSMC 28HPC+; all `/dfs/...` tool paths and `PROJ_ROOT=/dfs/usrhome/jjiangan/github/hw_charles` are for the owner's Linux server — this checkout only edits scripts). **Full command reference: `smart_run/impl/README_FLOW.md`.** Stage order: `gen_sram` (once) → `syn` → `gls` → `ptpx`; behavioral sim is the functional reference.

- **`impl/gen_sram/`** — TSMC memory-compiler runs (`source gen_sram.sh`, then `cvrt_lib2db.sh`); outputs `verilog/` (functional models, also used by GLS) and `db/` (linked by syn/ptpx) are committed.
- **`impl/syn/`** — DC synthesis, `./run_dc.csh -mode syn` → `batch_YYYYMMDD_HH/`. **Clock gating is enabled**: `set_clock_gating_style` (integrated ICGs) + `compile_ultra -no_autoungroup -gate_clock`, and `gated_clk_cell_syn.v` replaces the RTL pass-through stub (`gen_rtl/clk/rtl/gated_clk_cell.v`, which is `clk_out = clk_in`) with a direct `CKLNQD4BWP30P140` instantiation (`set_size_only`). Check `reports/openC906.mapped.clock_gating.rpt`.
- **`impl/gls/`** — SDF-annotated gate-level VCS sim: `make runcase BATCH_DIR=../syn/batch_... CASE=coremark` (add `NTC=1` for zero-delay/no-SDF fallback). Reuses the smart_run testbench + case builder; runs in `smart_run/work_gls/`; SDF annotates only the core instance (`tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top`). Per-case FSDB/report → `impl/gls/results/`. If TSMC std-cell Verilog model paths differ, edit the top of `impl/gls/gls.f`.
- **`impl/ptpx/`** — PrimePower time-based analysis on the **gate-level FSDBs** from `impl/gls/results/` (no `-rtl`, no DC ptpxmap — the old RTL-replay mode was removed): `python3 run_ptpx_parallel.py --in_dir <syn batch> --clk_period 1 --fsdb_list_file fsdb_run_list.txt`.
- **`impl/sdc/`** — timing constraints; `impl/MEM_INTF/` — SRAM-wrapper/ICG self-tests.

## Power / Waveform Tooling

- `smart_run/impl/ptpx/script/` also hosts the FSDB→pandas-PKL power-dataset flow (`extract_funcsim_rc.tcl`, `fsdb_to_pkl.py`, `run_funcsim_rcs_to_pkl.sh`; see `doc/c906_synthesis_power_flow_report.md` — note its §3 describes the old RTL-FSDB replay; the flow now consumes GLS FSDBs).
- `smart_run/cli_tools/` — stdlib-only Python wrappers around Synopsys Verdi utilities (`fsdbdebug`/`fsdbextract`/`fsdbmerge` must be on PATH):
  - `fsdb_segment.py -f <list> -n 10 -j 4 -o <dir>` — split FSDBs into time segments (parallel, verified, `--resume`)
  - `fsdb_merge.py --dir <d> --prefix <p>` — merge `{prefix}_{begin}ns_{end}ns.fsdb` segments back (auto multi-pass past fsdbmerge's 31-file limit)
  - `collect_fsdb.py --ptpx-dir <d>` — gathers `ad_mp_top_pwr.fsdb` results into `result/` and **deletes the source folders**; use `--dry-run` first
  - `extract_rc.py --fsdb <f> --type all --level '*' --top tb.x_soc...x_cpu_top --out <f.rc>` — emit a Verdi .rc signal list of a module's I/O ports (drops clk/rst-like names)
- Probing huge FSDBs: use windowed `fsdbreport -bt/-et`; monolithic dumps fail (~9.5GB files). See `doc/fsdb-read-coverage-investigation.md`.

Not Verdi-related, but also in `smart_run/cli_tools/` (stdlib-only Python):
- `gen_toggle_mon.py --unit <cp0|iu|idu|ifu|vidu> --out <f.v>` — generate the per-port toggle monitor for a pipeline-unit top by parsing its own `input`/`output` declarations. `--unit` fills in the RTL path, instance path, module name, guard macro and report filename. Bound into the TB behind a `+define+` carried by a `-f` filelist; writes `work/<unit>_toggle.report` at `$finish`.
- `cov_report.py --dat <dir> [--baseline F.json] [--top-cold N]` — per-unit line/branch/toggle coverage from Verilator `coverage.dat` files or a VCS `urg -format text` report, with deltas against a committed baseline and a "coldest files + first uncovered lines" list. Driven by `make covreport`.
- `list_nets.py` — Verilator `--json-only` net listing for a module (see the Verilator flow notes).

## doc/ Index

The tree is `doc/{specs,results,pdfs}/` plus `doc/c906-hier.md` (aq_core level-1 submodule tree).

`doc/specs/`
- `cp0-design-and-test.md` — **the CP0 reference.** §1-§15: hierarchy, CSR map ownership, trap/interrupt/debug architecture, verified RTL gotchas. §16-§23: the `cp0_random` stress test — 42-group coverage matrix, the port-toggle monitor, and the safety rails that WFI / delegation / cache maintenance need.
- `unit-random-tests.md` — **the reference for `iu_random` / `vidu_random` / `idu_random` / `ifu_random`.** Part 0 is common: the shared harness, the knob table, coverage measurement (both simulators), the safety rails, and the reproducibility contract. Then one part per unit, a risk register, and a provenance note. Read Part 0 §5 before writing any new randomized case.
- `c906_key_func_signals.md`, `csi-nn2-bare-metal-guide.md`, `verilator-mobilenet-flow.md`

`doc/results/`
- `cp0_toggle_baseline.report` — the committed `cp0_random` port-toggle baseline (169/201)
- `<unit>_toggle_coremark_ref.report` (cp0/iu/idu/ifu/vidu) and `unit_coverage_baseline.json` — the **reference measurement**: what a real workload (`coremark`, one iteration, `MON=all COVERAGE=line`) already reaches, so each randomized case's contribution can be stated as a delta rather than an uninterpretable absolute
- `aq_core_lvl1_inports.md`, `aq_core_all_net_paths.txt`, `c906_module_hier.txt`

`doc/pdfs/` — official C906 user guide, integration guide, datasheet, the XuanTie C-series comparison table, and the SRAM-compiler guide. **Note these are image-only PDFs**: reading them needs poppler (`brew install poppler` for `pdftoppm`), which is not installed here, so the RTL decode tables are the working source of truth for encodings.
