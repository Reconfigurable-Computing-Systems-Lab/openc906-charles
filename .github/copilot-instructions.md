# Copilot Instructions — OpenC906 RISC-V Processor

## Project Overview

This is the RTL source and simulation environment for the **T-Head C906**, a 64-bit RISC-V processor core supporting RV64GCVXtheadc (Integer, Float, Double, Compressed, Vector, and T-Head custom extensions). The codebase contains synthesizable Verilog RTL, a demo SoC with peripherals, and a self-checking simulation testbench.

A Git submodule `csi-nn2/` provides a neural network inference library (CSI-NN2) for ML workloads on C906.

## Architecture

### RTL Instantiation Hierarchy

```
openC906.v          — Processor top (instantiate this for SoC integration)
 └─ aq_top.v        — System top: wraps core + CLINT + PLIC
     ├─ aq_core.v   — Core pipeline (~126KB, largest module): IFU → IDU → IU/LSU → RTU
     ├─ aq_clint.v  — Core Local Interruptor (timer, software interrupts)
     └─ aq_plic.v   — Platform Level Interrupt Controller
```

### Processor Pipeline

The core is in `C906_RTL_FACTORY/gen_rtl/cpu/rtl/`. Major pipeline stages live in subdirectories of `gen_rtl/`:

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

Feature-enable configuration headers (`cpu_cfig.h`, `aq_idu_cfig.h`, `aq_lsu_cfig.h`, `aq_dtu_cfig.h`, `sysmap.h`, `tdt_define.h`) control compile-time options and are referenced in `C906_asic_rtl.fl`.

### Demo SoC (Simulation)

The SoC wrapper in `smart_run/logical/common/soc.v` connects C906 to:

- **AXI interconnect** (`axi/axi_interconnect128.v`) — 128-bit crossbar, 4 slave ports (s0–s3)
- **L3 Memory** — Two-bank 128-bit SRAM via `axi_slave128.v`. Bank select is by address bit; each bank is an `f_spsram_*x128` instance (L = low bank, H = high bank)
- **UART** (`uart/`) — mapped at `0x10015000`
- **GPIO** (`gpio/`)
- **AHB↔APB bridge** (`ahb/ahb2apb.v`)

### Testbench

The testbench (`smart_run/logical/tb/tb.v`) loads `inst.pat` and `data.pat` into L3 SRAM, runs the core, and monitors for completion:

- **Pass/fail detection**: Watches RTU writeback registers (`wb_wb0_data`, `wb_wb1_data`). A test signals PASS by writing `0x444333222` or FAIL by writing `0x2382348720` to any GPR.
- **Deadlock detection**: Every 50,000 cycles, checks that at least one instruction has retired; otherwise declares FAIL.
- **Timeout**: `MAX_RUN_TIME` = 700,000,000 cycles. Simulation aborts as FAIL if exceeded.
- **UART capture**: Monitors AXI writes to `0x10015000` and logs characters to `run_case.report`.
- **Clock**: 10ns period (100MHz). JTAG clock: 40ns period.
- **Waveforms**: Controlled by `DUMP=on` make variable. VCS → FSDB (`$fsdbDumpvars`), irun/iverilog → VCD (`$dumpvars`).

Key testbench macros (defined in `tb.v`) for probing signals in the hierarchy:

| Macro | Points to |
|-------|-----------|
| `` `SOC_TOP `` | `tb.x_soc` |
| `` `CPU_TOP `` | `x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top` |
| `` `RTL_MEM `` | `x_axi_slave128.x_f_spsram_*_L` (low SRAM bank) |
| `` `RTL_MEM2 `` | `x_axi_slave128.x_f_spsram_*_H` (high SRAM bank) |

### Memory Map

| Region | Address Range | Content |
|--------|---------------|---------|
| Text/Code | `0x00000000–0x0003FFFF` | Instructions (inst.pat) |
| Data | `0x00040000–0x000FFFFF` | Data/BSS (data.pat) |
| UART | `0x10015000` | UART data register |
| Stack top | `0x000EE000` | Kernel stack pointer |

> **Note**: An SRAM expansion plan to support 128MB programs is documented in `doc/expand-sram-plan.md`. If implemented, the memory map regions and SRAM module names will change.

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

Additional test directories exist under `smart_run/tests/cases/` (`conv_softmax/`, `ISA/ISA_VECTOR/`) but are not in `CASE_LIST` — add them to `smart_cfg.mk` before use.

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
- SoC/testbench file lists are in `smart_run/logical/filelists/`:
  - `sim.fl` — top-level, includes `ip.fl` + `smart.fl` + `tb.fl`
  - `ip.fl` — references `C906_asic_rtl.fl` and `tdt_dmi_top_rtl.fl` from gen_rtl
  - `smart.fl` — SoC peripherals (AXI, AHB, APB, UART, GPIO, memory, clock)
  - `tb.fl` — testbench (`tb.v`) and include paths
- FPGA memory models are in `gen_rtl/fpga/` — behavioral SRAMs used for simulation in place of foundry macros
- The `debug` test case is special: it includes custom JTAG driver Verilog files (`tests/cases/debug/JTAG_DRV.vh`, `JTAG_DRV.v`) added to the simulator's filelist at compile time

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
