# Copilot Instructions — OpenC906 RISC-V Processor

## Project Overview

This is the RTL source and simulation environment for the **T-Head C906**, a 64-bit RISC-V processor core supporting RV64GCVXtheadc (Integer, Float, Double, Compressed, Vector, and T-Head custom extensions). The codebase contains synthesizable Verilog RTL, a demo SoC with peripherals, and a self-checking simulation testbench.

- Git submodule `csi-nn2/` (fork: charlesjiangxm/csi-nn2) provides a neural network inference library for ML workloads on C906.
- The `hhb/` directory contains HHB (Heterogeneous Honey Badger) toolchain scripts — ONNX model splitting and result collection for preparing models before generating CSI-NN2 code. See `doc/csi-nn2-bare-metal-guide.md` for the full bare-metal ML inference workflow.

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

### Compile-Time Configuration

Feature-enable headers in the filelist `C906_asic_rtl.fl` control major options via `` `define `` macros:

| Header | Location | Key Options |
|--------|----------|-------------|
| `cpu_cfig.h` | `gen_rtl/cpu/rtl/` | Cache size (`ICACHE_32K`/`DCACHE_32K`, options: 8K–64K), BHT size (`BHT_16K`), JTLB entries (128), FPU/Vector enable, PA_WIDTH=40, VA_WIDTH=39, PLIC (240 interrupt sources) |
| `aq_idu_cfig.h` | `gen_rtl/idu/rtl/` | Instruction decode field definitions, vector VLEN config (64/128/256) |
| `aq_lsu_cfig.h` | `gen_rtl/lsu/rtl/` | LSU data width (128/64-bit), vector SRAM sizing |
| `aq_dtu_cfig.h` | `gen_rtl/dtu/rtl/` | Debug halt info, trigger config |
| `sysmap.h` | `gen_rtl/mmu/rtl/` | System memory mapping regions (8 regions with base/attributes) |
| `tdt_define.h` | `gen_rtl/tdt/rtl/top/` | JTAG Debug Module definitions |

### Demo SoC (Simulation)

The SoC wrapper in `smart_run/logical/common/soc.v` connects C906 to:

- **AXI interconnect** (`axi/axi_interconnect128.v`) — 128-bit crossbar, 4 slave ports (s0–s3), 40-bit address
- **L3 Memory** — Two-bank 128-bit SRAM via `axi_slave128.v` using `f_spsram_8388608x128` (128MB per bank, 256MB total). Bank select is by address bit `mem_addr[27]`; each bank has 16 byte-wide sub-banks (`ram0`–`ram15`)
- **UART** (`uart/`) — mapped at `0x10015000`
- **GPIO** (`gpio/`) — 8-bit bidirectional Port A
- **AHB↔APB bridge** (`ahb/ahb2apb.v`) — connects Timer, UART, GPIO via AHB bus

### Testbench

The testbench (`smart_run/logical/tb/tb.v`) loads pattern files into L3 SRAM, runs the core, and monitors for completion:

- **Pattern loading**: `$readmemh()` loads `inst.pat` (65536 words = 256KB), `data.pat` (65536 words = 256KB), and `input.pat` (16384 words = 64KB, NN float32 inputs) into temp arrays, then distributes bytes across 16 RAM sub-banks in a byte-swizzled 128-bit row layout.
- **Pass/fail detection**: Watches RTU writeback registers. A test signals PASS by writing `0x444333222` or FAIL by writing `0x2382348720` to any GPR.
- **Deadlock detection**: Every 50,000 cycles, checks that at least one instruction has retired; otherwise declares FAIL.
- **Timeout**: `MAX_RUN_TIME` = 3,000,000,000 time units (3s at 1ns timescale). Override at runtime with the `+MAX_SIM_TIME=<value>` plusarg (e.g., `+MAX_SIM_TIME=1000000` for 1ms).
- **NN input dual-mapping**: `input.pat` is loaded to *both* `0x00080000` (overlaps data region for small models) and `0x01000000` (independent region for larger models with relocated linker scripts).
- **UART capture**: Monitors AXI writes to `0x10015000` and logs characters to `run_case.report`.
- **Clock**: `CLK_PERIOD` = 1.0ns. JTAG clock (`TCLK_PERIOD`): 4.0ns. **Caution**: `CLK_PERIOD` must remain a real literal (e.g., `1.0` not `1`); integer division `1/2 = 0` in Verilog causes a zero-delay infinite loop.
- **Waveforms**: Controlled by `DUMP=on` make variable. VCS → FSDB (`$fsdbDumpvars`), irun/iverilog → VCD (`$dumpvars`).

Key testbench macros for probing signals in the hierarchy:

| Macro | Points to |
|-------|-----------|
| `` `SOC_TOP `` | `tb.x_soc` |
| `` `CPU_TOP `` | `x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top` |
| `` `RTL_MEM `` | `x_axi_slave128.x_f_spsram_*_L` (low SRAM bank) |
| `` `RTL_MEM2 `` | `x_axi_slave128.x_f_spsram_*_H` (high SRAM bank) |

### Memory Map

| Region | Address Range | Content |
|--------|---------------|---------|
| Text/Code | `0x00000000–0x0003FFFF` | Instructions (`inst.pat`, 256KB) |
| Data | `0x00040000–0x000FFFFF` | Data/BSS (`data.pat`, 768KB) |
| NN Input | `0x00080000–0x0008FFFF` | Float32 model input (`input.pat`, 64KB, optional) |
| Stack top | `0x000EE000` | Kernel stack pointer (grows down) |
| UART | `0x10015000` | UART data register |

> **Note**: L3 SRAM was expanded from the original 16MB to 256MB (2×128MB banks). See `doc/expand-sram-plan.md` for details. The linker script still uses the original small regions above; larger programs require updating `linker.lcf` and the testbench temp arrays.

## Build & Simulation Commands

All simulation commands run from `smart_run/`. Environment setup is required first:

```bash
cd C906_RTL_FACTORY && source setup/setup.csh && cd ../smart_run
```

Two environment variables must be set in `smart_run/setup/example_setup.csh`:
- `CODE_BASE_PATH` — absolute path to the `C906_RTL_FACTORY/` directory
- `TOOL_EXTENSION` — absolute path to the `bin/` directory of a `riscv64-unknown-elf-gcc` installation (e.g., `Xuantie-900-gcc-elf-newlib-x86_64-V3.3.0/bin`)

### Simulator Selection

Set `SIM=vcs` (default), `SIM=nc` (Cadence irun), or `SIM=iverilog` (Icarus Verilog, open-source).

### Key Make Targets

```bash
make showcase                        # List all available test cases
make compile [SIM=vcs]               # Compile RTL + testbench only
make buildcase CASE=ISA_INT          # Compile a single test case to inst.pat/data.pat
make runcase CASE=ISA_INT [SIM=vcs] [DUMP=on]  # Build + run a single test
make regress                         # Run full regression (all tests in CASE_LIST)
make cleansim                        # Remove simulator artifacts only
make cleancase                       # Remove compiled test case artifacts only
make clean                           # Clean entire work/ directory
```

### Running a Single Test

```bash
make runcase CASE=ISA_INT SIM=iverilog
```

Available test cases (defined in `CASE_LIST` in `smart_run/setup/smart_cfg.mk`): `ISA_THEAD`, `ISA_INT`, `ISA_LS`, `ISA_FP`, `coremark`, `MMU`, `interrupt`, `exception`, `debug`, `csr`, `cache`, `conv_softmax`.

Additional test directories exist under `smart_run/tests/cases/` (e.g., `ISA/ISA_VECTOR/`) but are not in `CASE_LIST` — add them to `smart_cfg.mk` before use.

**Auto-discovered NN model cases**: Any directory `smart_run/tests/cases/model_compiled/<name>/` containing a `model.c` file is automatically appended to `CASE_LIST` via the `MODEL_CASES` glob in `smart_cfg.mk`. These reuse a generic `NN_MODEL_BUILD` recipe — no manual `_build` target needed. Drop in a HHB-generated `model.c` + weights and run `make runcase CASE=<name>` immediately.

### Test Output

- Simulation log: `smart_run/work/run.{vcs,irun}.log`
- Test result: `smart_run/work/run_case.report` (contains PASS/FAIL and UART output)
- Build log: `smart_run/work/<CASE>_build.case.log`
- Waveforms: `smart_run/work/` (VCD for iverilog/irun, FSDB for VCS)
- Regression report: `smart_run/tests/regress/regress_report`
- FSDB post-processing: `smart_run/cli_tools/` has Python scripts (`collect_fsdb.py`, `fsdb_merge.py`, `fsdb_segment.py`)

## Test Conventions

### Test Structure

Tests are assembly (`.s`) or C files in `smart_run/tests/cases/<category>/`. Each test:

1. Gets compiled with `crt0.s` (startup code: enables T-Head extensions, initializes all GPRs/FPU/vector regs, sets up trap handler, enables caches, jumps to `main`)
2. Links against `smart_run/tests/lib/linker.lcf` (MEM1: 256KB code at `0x0`, MEM2: 768KB data at `0x40000`)
3. Produces an ELF → converted via `Srec2vmem` to `inst.pat` + `data.pat` (hex patterns loaded by testbench)
4. Signals completion by writing the magic pass/fail value to a GPR

A mini C library in `smart_run/tests/lib/clib/` provides `printf()`, UART I/O, interrupt controller setup, and timers. For bare-metal NN/CSI-NN2 tests, use the scaffolding in `smart_run/tests/cases/nn_model_common/` (`bare_main.c` for the entry point, `sbrk.c` for heap, `stubs/` for libc stubs) — this is what auto-discovered `model_compiled/*` cases link against.

### Adding a New Test

1. Create a directory under `smart_run/tests/cases/<category>/`
2. Add your `.s` or `.c` test file
3. Add a `<NAME>_build` recipe in `smart_run/setup/smart_cfg.mk` following existing patterns (see any `*_build:` target for the template — copies sources + lib to `work/`, runs make with `CPU_ARCH_FLAG_0` and `CASENAME`)
4. Add the case name to `CASE_LIST` in `smart_cfg.mk`

### Toolchain

- Compiler: `riscv64-unknown-elf-gcc` (T-Head Xuantie-900 extended)
- Architecture flags are set per-test via `CPU_ARCH_FLAG_0`:
  - `c906` → `-march=rv64imac_zifencei_xtheadc -mabi=lp64` (no FP)
  - `c906fd` → `-march=rv64imafdc_zfh_zifencei_xtheadc -mabi=lp64d` (FP)
  - `c906fdv` → `-march=rv64imafdcv_zfh_zifencei_xtheadc -mabi=lp64d` (FP+Vector)
- Default optimization: `-O2`. The `coremark` case uses `-O3 -mtune=c906 -fno-optimize-sibling-calls -fno-code-hoisting`.
- **C906 implements RVV 0.7.1** (not 1.0). GCC 14+ only targets RVV 1.0 — use the reference C backend for CSI-NN2, not the vector-optimized one.

### Known Bugs

**Indirect jump tail calls (RTL bug)**: Indirect `jr` instructions used for tail-call optimization can hang the CPU when jumping through function pointers in BSS memory. This affects any C code compiled with `-Os` or higher that uses function pointer dispatch (common in CSI-NN2). Always compile with `-fno-optimize-sibling-calls` when linking libraries that use function pointer tables. See `doc/csi-nn2-bare-metal-guide.md` §7 for full analysis.

**crt0.s vector table (startup bug)**: The trap vector table in `crt0.s` uses `.long` (4-byte entries) but the trap handler loads entries with `ld` (8-byte load), causing an infinite exception loop on any trap. Override the trap handler in bare-metal code that needs working interrupts/exceptions.

## RTL Conventions

### Module & Signal Naming

- All core RTL modules use the `aq_` prefix (e.g., `aq_ifu_top`, `aq_lsu_top`). Top-level modules end in `_top`.
- **Signal naming follows `source_dest_signal`** format: `biu_ifu_arready` = BIU→IFU AXI read-ready; `cp0_ifu_icache_en` = CP0→IFU I-cache enable.
- External pad signals use `pad_` prefix: `biu_pad_araddr` (core→pad), `pad_biu_rdata` (pad→core).
- Active-low signals use `_b` suffix (e.g., `pad_cpu_rst_b`).
- Register flip-flops use `_ff` suffix; valid signals use `_vld` suffix.
- RTL sources contain `// &Depend("file.h")`, `// &ModuleBeg;`, `// &Ports;`, `// &Regs;`, `// &Wires;` comments — these are T-Head proprietary tool directives (can be ignored for simulation).

### Filelists

- RTL filelists: `C906_RTL_FACTORY/gen_rtl/filelists/` (`C906_asic_rtl.fl`, `tdt_dmi_top_rtl.fl`)
- SoC/testbench filelists: `smart_run/logical/filelists/`:
  - `sim.fl` — top-level for VCS/NC, includes `ip.fl` + `smart.fl` + `tb.fl`
  - `ip.fl` — references C906 RTL filelists via `${CODE_BASE_PATH}`
  - `smart.fl` — SoC peripherals (`-y` search directories for AXI, AHB, APB, UART, GPIO, memory, clock)
  - `tb.fl` — testbench (`tb.v`) and include paths
  - iverilog uses a different approach: directly includes C906 filelists via `-f` instead of `sim.fl`
- FPGA memory models are in `gen_rtl/fpga/` — behavioral SRAMs (8 variants from 64×58 to 2048×32, plus a generic configurable `fpga_ram.v`) used for simulation in place of foundry macros
- The `debug` test case is special: it includes custom JTAG driver Verilog files (`tests/cases/debug/JTAG_DRV.vh`, `JTAG_DRV.v`) added to the simulator's filelist at compile time

## Key File Paths

| What | Path |
|------|------|
| Processor RTL top | `C906_RTL_FACTORY/gen_rtl/cpu/rtl/openC906.v` |
| CPU configuration | `C906_RTL_FACTORY/gen_rtl/cpu/rtl/cpu_cfig.h` |
| System memory map | `C906_RTL_FACTORY/gen_rtl/mmu/rtl/sysmap.h` |
| SoC wrapper | `smart_run/logical/common/soc.v` |
| Testbench | `smart_run/logical/tb/tb.v` |
| Simulation Makefile | `smart_run/Makefile` |
| Test case configs | `smart_run/setup/smart_cfg.mk` |
| Test compilation Makefile | `smart_run/tests/lib/Makefile` |
| Boot/startup code | `smart_run/tests/lib/crt0.s` |
| Linker script | `smart_run/tests/lib/linker.lcf` |
| Test library (UART, printf) | `smart_run/tests/lib/clib/` |
| SRAM expansion plan | `doc/expand-sram-plan.md` |
| Bare-metal ML guide | `doc/csi-nn2-bare-metal-guide.md` |
| Testbench signal reference | `doc/tb-reference.md` |
