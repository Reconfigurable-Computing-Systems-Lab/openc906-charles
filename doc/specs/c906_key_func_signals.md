# Key Signal Reference for C906 RTL Simulation

This document describes the signals in `smart_run/key_signal.rc`, organized by
functional group. These signals are useful for debugging and profiling the
Conv2D + Softmax (or any other) workload running on the C906 core.

---

## Hierarchy Abbreviations

| Short Name | Full Hierarchy Path |
|------------|---------------------|
| **SRAM** | `tb.x_soc.x_axi_slave128` |
| **CPU** | `tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top` |
| **CORE** | `...x_cpu_top.x_aq_top_0.x_aq_core` |
| **CP0** | `...x_aq_core.x_aq_cp0_top` |

---

## L3 SRAM Architecture

The L3 SRAM (`axi_slave128`) is the main memory for the simulation. It is a
128-bit wide AXI slave backed by two `f_spsram_8388608x128` instances:

- **`x_f_spsram_8388608x128_L`** (Low bank) — selected when `mem_addr[27] == 0`
  - Address range: `0x00000000`–`0x07FFFFFF` (**128 MB**)
  - This is where **all .pat files are loaded** and where all current firmware
    memory accesses land (code, data, stack, heap, input).

- **`x_f_spsram_8388608x128_H`** (High bank) — selected when `mem_addr[27] == 1`
  - Address range: `0x08000000`–`0x0FFFFFFF` (**128 MB**)
  - **Currently unused** — defined in `tb.v` as `RTL_MEM2` but never
    referenced. Available as extra storage if needed.

**Total hardware capacity: 256 MB** (128 MB per bank).

### .pat File Loading

The testbench loads `.pat` files **once at simulation start** via `$readmemh`
in an `initial` block. There is no runtime streaming — if a `.pat` file exceeds
its temp array, it is silently truncated.

Current temp array sizes and memory map (all in the Low bank):

| Region | Temp Array | 32-bit Words | Bytes | Row Offset | Address Range |
|--------|-----------|-------------|-------|------------|---------------|
| `inst.pat` (code) | `mem_inst_temp[1048576]` | 1,048,576 | **4 MB** | `0x00000` | `0x00000000`–`0x003FFFFF` |
| `data.pat` (data/BSS/weights) | `mem_data_temp[1048576]` | 1,048,576 | **4 MB** | `0x40000` | `0x00400000`–`0x007FFFFF` |
| `input.pat` (float32 input) | `mem_input_temp[262144]` | 262,144 | **1 MB** | `0x80000` | `0x00800000`–`0x008FFFFF` |

**Total .pat loadable: ~9 MB** out of 128 MB available in the Low bank.

To load larger inputs (e.g., 1 MB), increase `mem_input_temp` size and adjust
the row offset to avoid overlapping the data region ending at `0x007FFFFF`. For
inputs beyond ~4 MB, move the input base address above the stack, or move
the stack higher in `linker.lcf`.

### Memory Row Addressing

Each 128-bit row = 16 bytes. The SRAM address is `mem_addr[26:4]` (23 bits =
8,388,608 rows). Four consecutive 32-bit words from a `.pat` file fill one row,
distributed across 16 RAM banks with byte-swizzle:

```
.pat word 0 → ram0 [31:24], ram1 [23:16], ram2 [15:8],  ram3 [7:0]
.pat word 1 → ram4 [31:24], ram5 [23:16], ram6 [15:8],  ram7 [7:0]
.pat word 2 → ram8 [31:24], ram9 [23:16], ram10 [15:8], ram11 [7:0]
.pat word 3 → ram12[31:24], ram13[23:16], ram14[15:8],  ram15[7:0]
```

---

## Group 1: CPU Clock

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `forever_cpuclk` | 1 | CPU | **Ungated CPU clock**. Always toggles at the core frequency (1 GHz). This is the raw clock input before any gating. |

---

## Group 2: L3 SRAM (axi\_slave128)

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `cur_state` | [1:0] | SRAM | **AXI slave FSM state**. See alias map below. |
| `mem_addr` | [26:4] | SRAM | **SRAM row address**. 23-bit row index into the 8388608-entry SRAM. Byte address = row × 16. |
| `mem_cen_0` | 1 | SRAM | **Chip enable for Low bank** (active low). Asserted when `mem_addr[23]==0` and the SRAM is accessed. |
| `mem_wen` | [15:0] | SRAM | **Per-byte write enable** (active low). Each bit controls one byte of the 128-bit data word. All HIGH = read; selective LOW bits = partial write. |
| `mem_din` | [127:0] | SRAM | **128-bit write data** input to SRAM. |
| `mem_dout` | [127:0] | SRAM | **128-bit read data** output (muxed from Low/High bank based on address). |

### AXI Slave State Machine (`axi_slave128.cur_state`)

| Value | State | Meaning |
|-------|-------|---------|
| `2'b00` | IDLE | No active transaction |
| `2'b01` | WRITE | Processing AXI write data beats |
| `2'b10` | WRITE_RESP | Sending write response to master |
| `2'b11` | READ | Processing AXI read, returning data |

---

## Group 3: Instruction Issue & Retire

These signals track when instructions enter and leave the pipeline.

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `ifu_idu_id_inst_vld` | 1 | CORE | **Instruction fetch valid**. HIGH when IFU delivers a valid instruction to IDU for decoding. Indicates an instruction is being issued into the pipeline. |
| `ifu_idu_id_inst` | [31:0] | CORE | **Fetched instruction encoding**. The raw 32-bit RISC-V instruction word being delivered from IFU to IDU. |
| `idu_iu_ex1_inst_vld` | 1 | CORE | **Decoded instruction valid to IU**. HIGH when IDU dispatches a valid decoded instruction to the Integer Unit for EX1 stage execution. |
| `idu_iu_ex1_pipedown_vld` | 1 | CORE | **Pipeline-down valid**. HIGH when the decoded instruction is accepted and proceeds down the IU pipeline (not stalled). |
| `rtu_pad_retire` | 1 | CORE | **Instruction retire**. HIGH when an instruction is committed (retired) by RTU. This is the primary retire indicator — one pulse per retired instruction. |
| `rtu_pad_retire_pc` | [39:0] | CORE | **Retire PC**. The program counter of the instruction being retired. Useful for correlating waveform activity with disassembly. |
| `rtu_hpcp_retire_inst_vld` | 1 | CORE | **Non-split retire valid**. Like `rtu_pad_retire` but excludes split (multi-micro-op) instructions, used by hardware performance counters (HPCP). |
| `rtu_hpcp_retire_pc` | [39:0] | CORE | **HPCP retire PC**. PC for the HPCP retire event (same as `rtu_pad_retire_pc` for non-split instructions). |
| `rtu_dtu_retire_vld` | 1 | CORE | **Debug/trace retire valid**. Retire signal sent to the Debug/Trace Unit (DTU). Used for debug breakpoints and trace generation. |
| `rtu_idu_commit` | 1 | CORE | **Commit to IDU**. Tells IDU that the oldest instruction has committed, freeing pipeline resources (write-back table entries, etc.). |

---

## Group 4: CP0 Running State

These signals from the Control/Status Register unit (CP0) indicate the
processor's operating state.

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `cp0_rtu_in_lpmd` | 1 | CP0 | **In low-power mode**. `0` = CPU is **running normally**. `1` = CPU is in low-power mode (halted/sleeping after WFI). This is the primary "CPU is running" indicator. |
| `cp0_ifu_in_lpmd` | 1 | CP0 | **IFU low-power signal**. Same as `cp0_rtu_in_lpmd` but routed to IFU; when HIGH, IFU stops fetching instructions. |
| `cp0_yy_clk_en` | 1 | CP0 | **Global clock enable**. HIGH = CPU clocks are active. Goes LOW when entering low-power mode. Controls all `gated_clk_cell` instances in the CPU. |
| `cp0_yy_priv_mode` | [1:0] | CP0 | **Privilege mode**. `2'b11` = Machine (M-mode), `2'b01` = Supervisor (S-mode), `2'b00` = User (U-mode). Bare-metal tests run in M-mode. |
| `cp0_biu_lpmd_b` | [1:0] | CP0 | **BIU low-power mode** (active low). Signals to the Bus Interface Unit which low-power state the CPU is entering. |
| `cp0_ifu_lpmd_req` | 1 | CP0 | **Low-power mode request to IFU**. HIGH when CP0 requests IFU to enter low-power mode (in response to WFI instruction). |
| `cp0_mmu_lpmd_req` | 1 | CP0 | **Low-power mode request to MMU**. HIGH when CP0 requests MMU to enter low-power mode. |

### CP0 Low-Power Mode FSM (`aq_cp0_lpmd.cur_state`)

| Value | State | Meaning |
|-------|-------|---------|
| `2'b00` | IDLE | CPU running normally |
| `2'b01` | WAIT | WFI executed, waiting for pipeline to drain |
| `2'b10` | LPMD | In low-power mode, clock gated |

---

## Group 5: Pipeline Stall & Busy

These signals indicate whether each functional unit is busy, stalled, or has
valid data. Useful for identifying pipeline bottlenecks.

### IFU (Instruction Fetch Unit)

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `ifu_idu_id_inst_vld` | 1 | CORE | IFU has a valid instruction for IDU (same as Group 3). When LOW, IFU is stalled (I-cache miss, branch mispredict flush, etc.). |
| `ifu_mmu_va_vld` | 1 | CORE | IFU is requesting a virtual-to-physical address translation from MMU. Indicates active instruction fetch. |

### IDU (Instruction Decode Unit)

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `idu_ifu_id_stall` | 1 | CORE | **IDU stall**. HIGH = IDU is stalling IFU (cannot accept new instructions). Caused by backend hazards, resource full, etc. |
| `idu_hpcp_backend_stall` | 1 | CORE | **Backend stall**. HIGH = IDU is stalled due to a backend resource being full (IU, LSU, or VIDU). Reported to HPCP for performance counting. |
| `idu_hpcp_frontend_stall` | 1 | CORE | **Frontend stall**. HIGH = IDU is stalled waiting for IFU (no valid instruction available). |

### IU (Integer Unit)

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `iu_idu_bju_full` | 1 | CORE | **BJU full**. Branch/Jump Unit cannot accept new branch instructions. |
| `iu_idu_bju_global_full` | 1 | CORE | **BJU globally full**. BJU full condition affecting all instruction types (not just branches). |
| `iu_idu_div_full` | 1 | CORE | **Divider full**. Division unit is busy with a previous divide operation. |
| `iu_idu_mult_full` | 1 | CORE | **Multiplier full**. Multiply unit pipeline is full. |
| `iu_idu_mult_issue_stall` | 1 | CORE | **Multiply issue stall**. HIGH = multiply unit is causing a pipeline stall back to IDU. |

### LSU (Load/Store Unit)

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `lsu_idu_full` | 1 | CORE | **LSU full**. Load/store pipeline is full, cannot accept new memory operations. |
| `lsu_idu_global_full` | 1 | CORE | **LSU globally full**. LSU full condition that blocks all instruction types. |
| `lsu_rtu_ex1_wb_vld` | 1 | CORE | **LSU EX1 writeback valid**. LSU has valid data to write back to register file from EX1 stage. |
| `lsu_rtu_ex2_data_vld` | 1 | CORE | **LSU EX2 data valid**. LSU has valid data from EX2 stage (D-cache hit or store buffer). |
| `lsu_vlsu_dc_stall` | 1 | CORE | **D-cache stall**. Data cache is stalling the LSU/VLSU pipeline (D-cache miss, MSB conflict, etc.). |

### RTU (Retirement Unit)

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `rtu_cpu_no_retire` | 1 | CORE | **No retire**. HIGH when no instruction is retiring. Prolonged HIGH indicates a pipeline stall or hang — the testbench watchdog monitors this signal. |
| `rtu_idu_flush_stall` | 1 | CORE | **Flush stall**. RTU is requesting IDU to stall while a pipeline flush is in progress (branch mispredict, exception, etc.). |
| `rtu_yy_xx_expt_vld` | 1 | CORE | **Exception valid**. An exception or interrupt is being taken. Causes pipeline flush and jump to trap handler. |

### MMU (Memory Management Unit)

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `mmu_ifu_pa_vld` | 1 | CORE | **IFU physical address valid**. MMU has completed the I-side address translation and the physical address is ready. |
| `mmu_lsu_pa_vld` | 1 | CORE | **LSU physical address valid**. MMU has completed the D-side address translation and the physical address is ready. |

### VIDU (Vector Instruction Decode Unit)

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `vidu_vpu_vid_fp_inst_vld` | 1 | CORE | **FP/Vector instruction valid**. VIDU has a valid floating-point or vector instruction dispatched to VPU. |
| `vidu_vpu_vid_fp_inst_dp_vld` | 1 | CORE | **FP/Vector datapath valid**. Valid with datapath resources allocated. |
| `vpu_vidu_vex1_fp_stall` | 1 | CORE | **VPU FP stall**. Vector/FP execution unit is stalling VIDU (resource conflict or pipeline hazard). |

---

## Group 6: Dispatch Unit Select

These one-hot signals indicate which functional unit the IDU is dispatching the
current instruction to. Exactly one is HIGH per dispatched instruction.

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `idu_iu_ex1_alu_sel` | 1 | CORE | Dispatched to **Integer ALU** (add, sub, logic, shift, compare). |
| `idu_iu_ex1_bju_sel` | 1 | CORE | Dispatched to **Branch/Jump Unit** (branches, JAL, JALR). |
| `idu_iu_ex1_mult_sel` | 1 | CORE | Dispatched to **Multiplier** (MUL, MULH, MULW, etc.). |
| `idu_iu_ex1_div_sel` | 1 | CORE | Dispatched to **Divider** (DIV, DIVU, REM, REMU). |
| `idu_lsu_ex1_sel` | 1 | CORE | Dispatched to **Load/Store Unit** (LB, LW, LD, SB, SW, SD, etc.). |
| `idu_vidu_ex1_fp_sel` | 1 | CORE | Dispatched to **Floating-Point Unit** (FADD, FMUL, FLD, FSD, FCVT, etc.). |
| `idu_vidu_ex1_vec_sel` | 1 | CORE | Dispatched to **Vector Unit** (vector load/store, vector arithmetic). |
| `idu_iu_ex1_func` | [19:0] | CORE | **IU function encoding**. Bit-field selecting the specific ALU/shift/branch sub-operation within the Integer Unit. |
| `idu_lsu_ex1_func` | [19:0] | CORE | **LSU function encoding**. Bit-field selecting the specific load/store sub-operation (byte/half/word/double, signed/unsigned, atomic, etc.). |

---

## Group 7: ALU Mode / Data Type

These signals indicate the operand data type (element width) for vector and
floating-point operations.

| Signal | Width | Hierarchy | Meaning |
|--------|-------|-----------|---------|
| `cp0_idu_vsew` | [1:0] | CP0 | **Vector Standard Element Width** (from CSR `vtype`). Encoding: `00` = 8-bit (INT8), `01` = 16-bit (FP16/BF16), `10` = 32-bit (FP32/INT32), `11` = 64-bit (FP64/INT64). Set by `vsetvli` instruction. |
| `idu_lsu_ex1_vsew` | [1:0] | CORE | **LSU element width**. VSEW propagated to the Load/Store Unit for vector load/store element sizing. Same encoding as `cp0_idu_vsew`. |
| `vidu_vpu_vid_fp_inst_eu` | [9:0] | CORE | **Execution Unit select**. One-hot field selecting which sub-unit within VPU handles the FP/vector instruction (e.g., FALU, FMAU, FCNVT, FSPU, VLSU). |
| `vidu_vpu_vid_fp_inst_func` | [19:0] | CORE | **FP/Vector function encoding**. Bit-field specifying the exact FP/vector sub-operation (add, mul, fma, compare, convert, etc.). |
| `vidu_vpu_vid_fp_inst_vld` | 1 | CORE | **FP/Vector instruction valid**. HIGH when a valid FP or vector instruction is being dispatched to VPU. |
| `lsu_vlsu_dc_sew` | [1:0] | CORE | **D-cache side element width**. SEW used by the D-cache interface for vector memory accesses. Same encoding as VSEW. |
| `lsu_vlsu_sew` | [1:0] | CORE | **VLSU element width**. SEW for vector load operations in the Vector Load/Store Unit. |
| `lsu_vlsu_st_sew` | [1:0] | CORE | **VLSU store element width**. SEW for vector store operations. |

### VSEW Encoding Reference

| `vsew[1:0]` | Element Width | Typical Use |
|--------------|--------------|-------------|
| `2'b00` | 8-bit | INT8 quantized inference, byte operations |
| `2'b01` | 16-bit | FP16 / BF16 inference |
| `2'b10` | 32-bit | FP32 / INT32 computation |
| `2'b11` | 64-bit | FP64 / INT64 computation |

---

## State Machine Alias Maps

The `.rc` file includes alias maps for all major state machines in the design,
allowing Verdi to display human-readable state names instead of raw binary
values. Below is a summary of the state machines and their states.

### SoC / Bus

| Module | Signal | States |
|--------|--------|--------|
| `axi_slave128` | `cur_state[1:0]` | IDLE, WRITE, WRITE_RESP, READ |
| `axi_err128` | `cur_state[1:0]` | IDLE, WRITE, WRITE_RESP, READ |
| `axi2ahb` | `cur_st[8:0]` | FSM_IDLE, RD_AXI, WR_AHB, WR_LAST_DATA, RD_AHB, RD_LAST_DATA, RESP_AXI, WR_AXI, WT_DB_WR |
| `apb_bridge` | `cur_state[2:0]` | IDLE, LATCH, W_SELECT, R_SELECT, ENABLE |

### UART

| Module | Signal | States |
|--------|--------|--------|
| `uart_receive` | `cur_state[5:0]` | IDLE, START, DATA, PARITY, STOP, CLECT_SIG |
| `uart_trans` | `cur_state[4:0]` | IDLE, START, DATA, PARITY, STOP |

### CP0 (Control/Status Registers)

| Module | Signal | States |
|--------|--------|--------|
| `aq_cp0_lpmd` | `cur_state[1:0]` | IDLE (running), WAIT (draining), LPMD (sleeping) |
| `aq_cp0_fence_inst` | `fence_cur_state[2:0]` | FNC_IDLE, FNC_FENC, FNC_CDCA, FNC_CMMU, FNC_IICA, FNC_CMPLT |
| `aq_cp0_rst_ctrl` | `icache_cur_state[1:0]` | RST_IDLE, RST_WFC, RST_DONE |
| `aq_cp0_rst_ctrl` | `dcache_cur_state[1:0]` | RST_IDLE, RST_WFC, RST_DONE |
| `aq_cp0_rst_ctrl` | `bht_cur_state[1:0]` | RST_IDLE, RST_WFC, RST_DONE |
| `aq_cp0_rst_ctrl` | `mmu_cur_state[1:0]` | RST_IDLE, RST_WFC, RST_DONE |

### IFU (Instruction Fetch Unit)

| Module | Signal | States |
|--------|--------|--------|
| `aq_ifu_vec` | `vec_cur_state[1:0]` | IDLE, RESET, HALT, WARM_UP |
| `aq_ifu_icache` | `ref_cur_st[2:0]` | IDLE, REQ, INIT, WFC, WFPA |
| `aq_ifu_icache` | `pf_cur_st[2:0]` | IDLE, PF_READ, PF_CHK, PF_REQ, PF_WFC0–3 |
| `aq_ifu_icache` | `iop_cur_st[1:0]` | IOP_IDLE, IOP_READ, IOP_WRTE, IOP_FLOP |
| `aq_ifu_pred` | `ras_cur_st[0:0]` | RAS_IDLE, RAS_WAIT |
| `aq_ifu_bht` | `bht_inv_cur_st[1:0]` | BHT_INV_IDLE, BHT_INV_READ, BHT_INV_WRTE |
| `aq_ifu_bht` | `bht_ref_cur_st[2:0]` | BHT_REF_IDLE, BHT_REF_READ1, BHT_REF_READ2, BHT_REF_WRTE, BHT_REF_UPD |

### IDU (Instruction Decode Unit)

| Module | Signal | States |
|--------|--------|--------|
| `aq_idu_id_split` | `lsd_cur_state[0:0]` | LSD_IDLE, LSD_SPLIT |
| `aq_idu_id_split` | `amo_cur_state[2:0]` | AMO_IDLE, AMO_AMO, AMO_LR, AMO_SC, AMO_AQ |
| `aq_idu_id_split` | `che_cur_state[0:0]` | CHE_IDLE, CHE_SPLIT |
| `aq_idu_id_split` | `fnc_cur_state[0:0]` | FNC_IDLE, FNC_SPLIT |

### IU (Integer Unit)

| Module | Signal | States |
|--------|--------|--------|
| `aq_iu_div` | `div_cur_state[2:0]` | IDLE, WFI2, ALIGN, ITER, CMPLT, WFWB |
| `aq_iu_mul` | `mul_cur_state[1:0]` | IDLE, SPLIT0, SPLIT1, CMPLT |

### LSU (Load/Store Unit)

| Module | Signal | States |
|--------|--------|--------|
| `aq_lsu_dc` | `dc_cur_state[1:0]` | IDLE, DCS, FRZ, REPLY |
| `aq_lsu_vb` | `vb_cur_state[3:0]` | VB_IDLE, VB_BUS_REQ, VB_BUS_WFC, VB_ALIAS_REQ, VB_ALIAS_WFC, VB_DATA_0–3 |
| `aq_lsu_stb` | `merge_cur_state[2:0]` | MERGE_IDLE, MERGE_FIRST, MERGE_SECND, MERGE_ABORT, MERGE_WFC |
| `aq_lsu_stb` | `burst_cur_state[3:0]` | BURST_WFR0–3, BURST_DATA0–3, BURST_EMPTY1–3 |
| `aq_lsu_stb_entry` | `stb_cur_state[3:0]` | STB_IDLE, STB_WLFB, STB_WCA, STB_MERGE, STB_WBUS, STB_RDL, STB_WRDL, STB_FWD |
| `aq_lsu_lfb_entry` | `lfb_cur_state[2:0]` | LFB_IDLE, LFB_WRDL, LFB_RDL, LFB_RBUS, LFB_REF_1–4 |
| `aq_lsu_rdl` | `rdl_cur_state[3:0]` | RDL_IDLE, RDL_DIRTY_RD, RDL_DIRTY_UPDT, RDL_TAG_RD, RDL_TAG_UPDT, RDL_CHECK, RDL_INV, RDL_ACHECK, RDL_DATA_RD_0–3, RDL_WVB, RDL_LAST |
| `aq_lsu_lm` | `lm_cur_state[0:0]` | LM_OPEN, LM_EXCL |
| `aq_lsu_pfb` | `pfb_cur_state[3:0]` | PF_IDLE, PF_INIT, PF_REQ, PF_CALS, PF_SUSP, PF_CHKS, PF_EVICT |
| `aq_lsu_amr` | `amr_cur_state[2:0]` | AMR_IDLE, AMR_MISS_WAIT, AMR_CALS, AMR_CHCK, AMR_FUNC |
| `aq_lsu_mcic` | `ptw_cur_state[1:0]` | PTW_IDLE, PTW_REQ_DCACHE, PTW_WAIT_DATA |
| `aq_lsu_ag` | `unalign_cur_state[0:0]` | UNALIGN_IDLE, UNALIGN_SECD |
| `aq_lsu_dtif` | `dt_cur_state[2:0]` | IDLE, ADDR_CHK, DATA_CHK, WAIT_DATA, WAIT_PIPE, WAIT_CMPLT |
| `aq_vlsu_lsu_if` | `sseg_cur_state[3:0]` | SSEG_IDLE, SSEG_EXPT_IDLE, SSEG_MERGE, SSEG_WB, SSEG_FWD_DATA_PRE, SSEG_FWD, SSEG_WAIT, SSEG_EXPT |

### RTU (Retirement Unit)

| Module | Signal | States |
|--------|--------|--------|
| `aq_rtu_retire` | `flush_cur_state[2:0]` | FLUSH_IDLE, FLUSH_FE, FLUSH_BE, FLUSH_FE_BE, FLUSH_WAIT |

### MMU (Memory Management Unit)

| Module | Signal | States |
|--------|--------|--------|
| `aq_mmu_arb` | `arb_cur_st[1:0]` | ARB_IDLE, ARB_IUTLB, ARB_DUTLB |
| `aq_mmu_arb` | `read_cur_st[1:0]` | READ_IDLE, READ_4K, READ_2M, READ_1G |
| `aq_mmu_ptw` | `ptw_cur_st[4:0]` | PTW_IDLE, PTW_FST_PMP/CHK/DATA, PTW_SCD_PMP/CHK/DATA, PTW_THD_PMP/CHK/DATA, PTW_DATA_VLD, PTW_ABT, PTW_ABT_DATA, PTW_ACC_FLT, PTW_PGE_FLT, PTW_1G_PMP1/2, PTW_2M_PMP1/2, PTW_MACH_PMP |
| `aq_mmu_utlb` | `ref_cur_st[1:0]` | IDLE, WFG, WFC, ABT |
| `aq_mmu_tlboper` | `tlbp_cur_st[1:0]` | PIDLE, PWFG, PWFC |
| `aq_mmu_tlboper` | `tlbr_cur_st[1:0]` | RIDLE, RWFG, RWFC |
| `aq_mmu_tlboper` | `tlbwi_cur_st[1:0]` | WIIDLE, WIWFG, WIWFC |
| `aq_mmu_tlboper` | `tlbwr_cur_st[1:0]` | WRIDLE, WRTAG, WRWFG, WRWFC |
| `aq_mmu_tlboper` | `tlbiasid_cur_st[2:0]` | IASID_IDLE, IASID_RD, IASID_WFC, IASID_WT, IASID_NWT, IASID_FIN |
| `aq_mmu_tlboper` | `tlbiall_cur_st[1:0]` | IALL_IDLE, IALL_WFC, IALL_FIN |
| `aq_mmu_tlboper` | `tlbiva_cur_st[3:0]` | IVA_IDLE, IVA_4K_RD/WR/WT/CMP, IVA_2M_RD/WR/WT/CMP, IVA_1G_RD/WR/WT/CMP, IVA_CMPLT |

### VIDU (Vector Instruction Decode Unit)

| Module | Signal | States |
|--------|--------|--------|
| `aq_vidu_vid_split_fp` | `non_cur_state[0:0]` | NON_IDLE, NON_SPLIT |

### FPU

| Module | Signal | States |
|--------|--------|--------|
| `aq_fdsu_scalar_ctrl` | `fdsu_cur_state[2:0]` | IDLE, WFI2, ITER, RND, PACK, WFWB, ID0, ID1 |

### BIU (Bus Interface Unit)

| Module | Signal | States |
|--------|--------|--------|
| `aq_biu_apbif` | `apb_cur_state[1:0]` | IDLE, WDATA, REQ, PEND |

### Debug

| Module | Signal | States |
|--------|--------|--------|
| `aq_dtu_cdc` | `cur_state[1:0]` | IDLE, PULSE, HAVE_RESET, PENDING |
| `tdt_dm` | `regacc_cur_state[3:0]` | REGACC_IDLE, REGACC_WDSC0, REGACC_RDSC0, ... (register access FSM) |
| `plic_arb_ctrl` | `arb_state[1:0]` | IDLE, ARBTRATE, ARB_DELAY, WRITE_CLAIM |
