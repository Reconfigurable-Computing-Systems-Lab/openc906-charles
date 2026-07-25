# AGENTS.md

This file provides guidance to the AI agent when working with code in this repository.

## What this is

RTL source + simulation environment for the T-Head C906 (64-bit RISC-V, RV64GCVXtheadc). Detailed architecture, memory map, pipeline, and testbench docs live in `.github/copilot-instructions.md` — read it before touching RTL or testbench code. Bare-metal ML workflow: `doc/csi-nn2-bare-metal-guide.md`.

## Environment setup (required before any build)

**First run only** — run `./setup_repo.sh` from the repo root. It pulls the `csi-nn2` submodule and restores the large sim artifacts that aren't in git (`smart_run/work`, `smart_run/work_par`, `smart_run/tests/cases/model_compiled`, `hhb/model`) from Baidu Netdisk. Needs `BaiduPCS-Go` + `python3` on PATH and a graphical session for the login browser (`./setup_repo.sh --login` to force re-login). Without this, `make compile` fails (no `work/` dir).

Per-session env — the login shell is **tcsh**, so setup scripts use `setenv`, not `export`:

```tcsh
cd C906_RTL_FACTORY && source setup/setup.csh && cd ../smart_run
setenv TOOL_EXTENSION /dfs/usrhome/jjiangan/apps/Xuantie-900-gcc-elf-newlib-x86_64-V3.3.0/bin
```

`setup.csh` derives `CODE_BASE_PATH` from `pwd` (correct). **Do not source `smart_run/setup/example_setup.csh`** — its hardcoded `CODE_BASE_PATH` points at `../openc906-charles/` (this repo is `-imp`), so filelists that use `${CODE_BASE_PATH}` will break. `setup.csh` does not set `TOOL_EXTENSION`; set it separately as above.

## Build / simulate (from `smart_run/`)

```tcsh
make runcase CASE=ISA_INT [SIM=vcs|nc|iverilog] [DUMP=on|off]   # build + run one case
make compile                                                    # compile RTL + TB only
make showcase                                                   # list cases
make regress                                                    # run all cases
make clean                                                      # wipe work/
```

`SIM=vcs` is default; `iverilog` is the open-source option. Results: `work/run_case.report` (PASS/FAIL + UART output), `work/run.{vcs,irun}.log`.

## Two Verilog styles — do not mix

- **Existing C906 RTL** (`C906_RTL_FACTORY/gen_rtl/`): T-Head convention. Modules prefixed `aq_`, signals named `source_dest_signal` (e.g. `biu_ifu_arready`), pad signals `pad_`, active-low `_b`, FF suffix `_ff`, valid suffix `_vld`. `// &Depend(...)`, `// &ModuleBeg;` comments are T-Head tool directives — leave them. Do not rewrite this code to another style.
- **New synthesizable RTL you author**: follow `.claude/skills/verilog-style/SKILL.md` — `i_`/`o_` port prefix, `U_*` instances, `DFF_*`/`CMB_*` block names, `always_ff`/`always_comb` only (no bare `always`), no `logic`. Applies to new `.v` files only, not existing T-Head RTL or testbench `.sv`.

## Toolchain & ISA gotchas

- C906 implements **RVV 0.7.1, not 1.0**. GCC 14+ emits RVV 1.0 — for CSI-NN2 use the reference C backend, never the vector-optimized one.
- `CPU_ARCH_FLAG_0` selects arch: `c906` (no FP), `c906fd` (FP, the default in `smart_cfg.mk`), `c906fdv` (FP+Vector).

## Known RTL bugs — respect these when compiling

- **Indirect-jump tail-call hang**: `jr` through function pointers in BSS can hang the core. Compile function-pointer-dispatch code (e.g. CSI-NN2) with `-fno-optimize-sibling-calls`. See `doc/csi-nn2-bare-metal-guide.md` §7.
- **crt0.s trap table**: trap vector entries are `.long` (4B) but loaded with `ld` (8B) → infinite exception loop. Override the trap handler in bare-metal code that needs working traps.

## Testbench gotcha

`CLK_PERIOD` in `smart_run/logical/tb/tb.v` must stay a **real literal** (e.g. `1.0`, not `1`); integer `1/2 = 0` in Verilog causes a zero-delay infinite loop.

## NN model cases

Any directory `smart_run/tests/cases/model_compiled/<name>/model.c` is auto-appended to `CASE_LIST` via a generic build recipe — no manual `_build` target needed. Run with `make runcase CASE=<name>`.

## Commit style

Lowercase, terse, no conventional-commits prefix (e.g. `add claude md`, `improve extract rc`, `upd sdc to solve the synthesis problem`). Never amend published commits.
