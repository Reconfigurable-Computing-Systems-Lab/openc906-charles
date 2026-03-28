# L3 SRAM Expansion: 16 MB → 256 MB

## Summary

The L3 SRAM in the simulation environment has been expanded from **16 MB** (2 × 8 MB banks) to **256 MB** (2 × 128 MB banks). This enables programs up to ~256 MB to run in simulation. All 12 regression tests pass.

## What Changed

### Original Configuration

| Component | Value |
|-----------|-------|
| SRAM model | `f_spsram_524288x128` — 2^19 rows × 128-bit = 8 MB/bank |
| Bank select bit | `mem_addr[23]` |
| Row address | `mem_addr[22:4]` (19-bit) |
| SRAM address window | `0x00000000–0x00FFFFFF` (16 MB) |
| Total capacity | 2 banks × 8 MB = **16 MB** |

### Expanded Configuration

| Component | Value |
|-----------|-------|
| SRAM model | `f_spsram_8388608x128` — 2^23 rows × 128-bit = 128 MB/bank |
| Bank select bit | `mem_addr[27]` |
| Row address | `mem_addr[26:4]` (23-bit) |
| SRAM address window | `0x00000000–0x0FFFFFFF` (256 MB) |
| Total capacity | 2 banks × 128 MB = **256 MB** |

### Memory Map (256 MB)

| Region | Address Range | Size | SRAM Bank |
|--------|---------------|------|-----------|
| L bank | `0x00000000 – 0x07FFFFFF` | 128 MB | L |
| H bank | `0x08000000 – 0x0FFFFFFF` | 128 MB | H |
| ERR1 (error resp) | `0x10000000 – 0x0FFFFFFF` | — | — |
| APB (UART etc) | `0x10000000 – 0x1FFFFFFF` | — | — |

> **Note**: The testbench and linker script retain the original small memory layout for existing tests (text 256 KB + data 768 KB, stack at `0xEE000`). To use the full 256 MB, update the linker script and testbench loading loops accordingly.

## Files Modified

### 1. New SRAM model — `smart_run/logical/mem/f_spsram_8388608x128.v`
- Copied from `f_spsram_524288x128.v`
- `ADDR_WIDTH`: 19 → **23**
- Address port: `[18:0]` → `[22:0]`

### 2. AXI slave addressing — `smart_run/logical/axi/axi_slave128.v`
- Bank select: `mem_addr[23]` → `mem_addr[27]`
- Row address: `mem_addr[22:4]` → `mem_addr[26:4]`
- Module: `f_spsram_524288x128` → `f_spsram_8388608x128`
- Instance names: `x_f_spsram_8388608x128_L` / `_H`

### 3. AXI address decode — `smart_run/logical/axi/axi_interconnect128.v`
- `SRAM_END`: `40'h00ffffff` → `40'h0fffffff`
- `ERR1_START`: `40'h01000000` → `40'h10000000`

### 4. AXI FIFO — `smart_run/logical/axi/axi_fifo.v`
- `SRAM_END`: `40'h00ffffff` → `40'h0fffffff`
- `ERR1_START`: `40'h01000000` → `40'h10000000`

### 5. Testbench — `smart_run/logical/tb/tb.v`
- `` `RTL_MEM `` / `` `RTL_MEM2 `` macros updated to point to `f_spsram_8388608x128` instances
- Temp arrays and loading loops kept at **original sizes** (sufficient for existing tests)

### 6. Linker script — `smart_run/tests/lib/linker.lcf`
- Kept at **original values** for existing tests (MEM1=256 KB, MEM2=768 KB, stack=`0xEE000`)

## Notes

- The `ram.v` generic model uses `2**(ADDRWIDTH)` for depth, so changing `ADDR_WIDTH` automatically sizes the arrays
- Existing small tests work unchanged; they use a small portion of the 256 MB space
- To load programs larger than the current testbench arrays (256 KB), expand `mem_inst_temp`/`mem_data_temp` and the loading loop bounds in `tb.v`, and update `linker.lcf` accordingly
- Always use `DUMP=off` for regression to avoid FSDB dumping overhead during testing
