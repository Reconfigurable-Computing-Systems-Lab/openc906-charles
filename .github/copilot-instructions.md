# Copilot Instructions — OpenC906 RISC-V Processor

## Project Overview

This is the RTL source and simulation environment for the **T-Head C906**, a 64-bit RISC-V processor core supporting RV64GCVXtheadc (Integer, Float, Double, Compressed, Vector, and T-Head custom extensions). The codebase contains synthesizable Verilog RTL, a demo SoC with peripherals, and a self-checking simulation testbench.

A Git submodule `csi-nn2/` provides a neural network inference library (CSI-NN2) for ML workloads on C906.

## Architecture

### Processor Pipeline

The core is in `C906_RTL_FACTORY/gen_rtl/cpu/rtl/` with top-level wrappers:

- `openC906.v` — Processor top (instantiate this for integration)
- `aq_top.v` — System top including CLINT/PLIC
- `aq_core.v` — Core pipeline (~126KB, largest module)

Major pipeline stages live in subdirectories of `gen_rtl/`:

| Unit | Directory | Role |
|------|-----------|------|
| IFU | `ifu/` | Instruction fetch, branch prediction (BHT/BTB/RAS), I-cache |
| IDU | `idu/` | Decode, register file, dispatch |
| IU | `iu/` | ALU, branch/jump, multiply, divide |
| LSU | `lsu/` | Load/store, D-cache, prefetch, store buffer |
| RTU | `rtu/` | Retirement, exception handling |
| CP0 | `cp0/` | CSR registers, trap handling |
| MMU | `mmu/` | JTLB, page table walker, SysMap |
| VDSP/VFALU/VFMAU/VIDU | `vdsp/`, `vfalu/`, `vfmau/`, `vidu/` | Vector/FP execution units |
| DTU/TDT | `dtu/`, `tdt/` | Debug/trace (JTAG) |
| BIU | `biu/` | AXI/AHB bus interface |

### Demo SoC (Simulation)

The SoC wrapper in `smart_run/logical/common/soc.v` connects C906 to:

- **AXI interconnect** (`axi/axi_interconnect128.v`) — 128-bit crossbar
- **L3 Memory** (`mem/f_spsram_524288x128.v`) — 512K×128-bit SRAM
- **UART** (`uart/`) — mapped at `0x10015000`
- **GPIO** (`gpio/`)
- **AHB↔APB bridge** (`ahb/ahb2apb.v`)

The testbench (`smart_run/logical/tb/tb.v`) loads `inst.pat` and `data.pat` into L3 memory, runs the core, and detects pass/fail by monitoring a magic value written to a register (`0x444333222` = PASS, `0x2382348720` = FAIL). It also captures UART output to `run_case.report`.

### Memory Map

| Region | Address Range | Content |
|--------|---------------|---------|
| Text/Code | `0x00000000–0x0003FFFF` | Instructions (inst.pat) |
| Data | `0x00040000–0x000FFFFF` | Data/BSS (data.pat) |
| UART | `0x10015000` | UART data register |
| Stack top | `0x000EE000` | Kernel stack pointer |

## Build & Simulation Commands

All simulation commands run from `smart_run/`. Environment setup is required first:

```bash
cd C906_RTL_FACTORY && source setup/setup.csh && cd ../smart_run
```

The toolchain path must be set in `smart_run/setup/example_setup.csh` (variables `CODE_BASE_PATH` and `TOOL_EXTENSION` pointing to a `riscv64-unknown-elf-gcc` installation).

### Simulator Selection

Set `SIM=vcs` (default), `SIM=nc` (Cadence irun), or `SIM=iverilog` (Icarus Verilog, open-source).

### Key Make Targets

```bash
make showcase                        # List all available test cases
make compile [SIM=vcs]               # Compile RTL + testbench only
make buildcase CASE=ISA_INT          # Compile a single test case to inst.pat/data.pat
make runcase CASE=ISA_INT [SIM=vcs] [DUMP=on]  # Build + run a single test
make regress                         # Run full regression (all tests)
make clean                           # Clean work/ directory
```

### Running a Single Test

```bash
make runcase CASE=ISA_INT SIM=iverilog
```

Available test cases: `ISA_THEAD`, `ISA_INT`, `ISA_LS`, `ISA_FP`, `coremark`, `MMU`, `interrupt`, `exception`, `debug`, `csr`, `cache`.

### Test Output

- Simulation log: `smart_run/work/run.{vcs,irun}.log`
- Test result: `smart_run/work/run_case.report` (contains PASS/FAIL and UART output)
- Waveforms: `smart_run/work/` (VCD for iverilog/irun, FSDB for VCS)
- Regression report: `smart_run/tests/regress/regress_report`

## Test Conventions

### Test Structure

Tests are assembly (`.s`) or C files in `smart_run/tests/cases/<category>/`. Each test:

1. Gets compiled with `crt0.s` (startup code that initializes GPRs, FPU, vector regs, MMU, CSRs)
2. Links against `smart_run/tests/lib/linker.lcf`
3. Produces an ELF → converted to `inst.pat` + `data.pat` (SREC hex patterns)
4. Signals completion by writing the magic pass/fail value

### Adding a New Test

1. Create a directory under `smart_run/tests/cases/<category>/`
2. Add your `.s` or `.c` test file
3. Add a `<NAME>_build` recipe in `smart_run/setup/smart_cfg.mk` following existing patterns
4. Add the case name to `CASE_LIST` in `smart_cfg.mk`

### Toolchain

- Compiler: `riscv64-unknown-elf-gcc` (T-Head extended, supports `-march=rv64imafdcvxtheadc`)
- Architecture flags are set per-test via `CPU_ARCH_FLAG_0`: `c906` (no FP), `c906fd` (FP), `c906fdv` (FP+Vector)

## RTL Conventions

- All RTL modules use the `aq_` prefix (e.g., `aq_ifu_top`, `aq_lsu_top`)
- File lists are in `C906_RTL_FACTORY/gen_rtl/filelists/` (`C906_asic_rtl.fl`, `tdt_dmi_top_rtl.fl`)
- SoC/testbench file lists are in `smart_run/logical/filelists/` (`sim.fl` → `ip.fl` + `smart.fl` + `tb.fl`)
- Testbench macros like `` `CPU_TOP ``, `` `RTL_MEM ``, `` `SOC_TOP `` in `tb.v` provide hierarchical paths into the design for probing signals
- FPGA memory models are in `gen_rtl/fpga/` — used for simulation in place of real SRAM macros

## Key File Paths

| What | Path |
|------|------|
| Processor RTL top | `C906_RTL_FACTORY/gen_rtl/cpu/rtl/openC906.v` |
| SoC wrapper | `smart_run/logical/common/soc.v` |
| Testbench | `smart_run/logical/tb/tb.v` |
| Simulation Makefile | `smart_run/Makefile` |
| Test case configs | `smart_run/setup/smart_cfg.mk` |
| Boot/startup code | `smart_run/tests/lib/crt0.s` |
| Linker script | `smart_run/tests/lib/linker.lcf` |
| Test library (UART, printf) | `smart_run/tests/lib/clib/` |
