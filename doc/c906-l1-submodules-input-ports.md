# C906 Level-1 Submodules — Input Port Reference

This document lists all input ports of the eight level-1 submodules of `aq_core`, extracted from the RTL source files in `C906_RTL_FACTORY/gen_rtl/`.

## Port Naming Convention

The C906 RTL uses a `<source>_<destination>_<signal>` naming convention:

| Prefix | Module |
|--------|--------|
| `biu` | Bus Interface Unit (external AXI/APB) |
| `cp0` | Coprocessor 0 (CSR / control-status registers) |
| `dtu` | Debug / Trace Unit |
| `hpcp` | Hardware Performance Counter (PMU) |
| `idu` | Instruction Decode Unit |
| `ifu` | Instruction Fetch Unit |
| `iu` | Integer Unit (ALU / BJU / MUL / DIV) |
| `lsu` | Load / Store Unit |
| `mmu` | Memory Management Unit |
| `pad` | Pad (I/O pad, clock / scan control) |
| `pmp` | Physical Memory Protection |
| `rtu` | Retire / Trap Unit (commit stage) |
| `vidu` | Vector / FP Instruction Decode Unit |
| `vlsu` | Vector Load / Store Unit |
| `vpu` | Vector / FP Processing Unit |
| `sysio` | System I/O |
| `da_xx` | Data-path forwarding (generic) |
| `xx` / `yy` | Cross-module shared signal |

Common suffixes: `_vld` = valid, `_en` = enable, `_req` = request, `_ack` = acknowledge, `_cmplt` = complete, `_wb` = writeback, `_fwd` = forward, `_dp` = data-path, `_sel` = select, `_gateclk` = gated clock, `_flush` = flush, `_stall` = stall, `_expt` = exception, `_int` = interrupt, `_ex1/ex2/ex3` = execution stage 1/2/3.

---

## 1. x_aq_cp0_top (CP0 — Coprocessor 0 / CSR)

**RTL file:** `gen_rtl/cp0/rtl/aq_cp0_top.v`

| Port | Width | Meaning |
|------|-------|---------|
| `biu_cp0_coreid` | [2:0] | Core ID from bus interface |
| `biu_cp0_me_int` | 1 | Machine external interrupt |
| `biu_cp0_ms_int` | 1 | Machine software interrupt |
| `biu_cp0_mt_int` | 1 | Machine timer interrupt |
| `biu_cp0_rvba` | [39:0] | Reset vector base address |
| `biu_cp0_se_int` | 1 | Supervisor external interrupt |
| `biu_cp0_ss_int` | 1 | Supervisor software interrupt |
| `biu_cp0_st_int` | 1 | Supervisor timer interrupt |
| `cpurst_b` | 1 | Reset (active low) |
| `dtu_cp0_dcsr_mprven` | 1 | Debug CSR: MPRV enable |
| `dtu_cp0_dcsr_prv` | [1:0] | Debug CSR: privilege mode |
| `dtu_cp0_rdata` | [63:0] | Debug unit read data |
| `dtu_cp0_wake_up` | 1 | Debug wake-up request |
| `forever_cpuclk` | 1 | Clock (always-on) |
| `hpcp_cp0_data` | [63:0] | PMU read data |
| `hpcp_cp0_int_vld` | 1 | PMU interrupt valid |
| `hpcp_cp0_sce` | 1 | PMU system counter enable |
| `idu_cp0_ex1_dp_sel` | 1 | EX1 data-path select |
| `idu_cp0_ex1_dst0_reg` | [5:0] | EX1 destination register |
| `idu_cp0_ex1_expt_acc_error` | 1 | EX1 access-fault exception |
| `idu_cp0_ex1_expt_high` | 1 | EX1 high-priority exception |
| `idu_cp0_ex1_expt_illegal` | 1 | EX1 illegal instruction |
| `idu_cp0_ex1_expt_page_fault` | 1 | EX1 page-fault exception |
| `idu_cp0_ex1_func` | [19:0] | EX1 function field |
| `idu_cp0_ex1_gateclk_sel` | 1 | EX1 gated-clock select |
| `idu_cp0_ex1_halt_info` | [21:0] | EX1 debug halt info |
| `idu_cp0_ex1_length` | 1 | EX1 instruction length |
| `idu_cp0_ex1_opcode` | [31:0] | EX1 opcode |
| `idu_cp0_ex1_sel` | 1 | EX1 select |
| `idu_cp0_ex1_split` | 1 | EX1 split instruction |
| `idu_cp0_ex1_src0_data` | [63:0] | EX1 source operand 0 |
| `idu_cp0_ex1_src1_data` | [63:0] | EX1 source operand 1 |
| `ifu_cp0_bht_inv_done` | 1 | BHT invalidation done |
| `ifu_cp0_icache_inv_done` | 1 | I-cache invalidation done |
| `ifu_cp0_icache_read_data` | [127:0] | I-cache read data |
| `ifu_cp0_icache_read_data_vld` | 1 | I-cache read data valid |
| `ifu_cp0_rst_inv_req` | 1 | Reset invalidation request |
| `ifu_cp0_warm_up` | 1 | IFU warm-up |
| `ifu_yy_xx_no_op` | 1 | IFU no-operation (idle) |
| `iu_cp0_ex1_cur_pc` | [39:0] | EX1 current PC from IU |
| `lsu_cp0_dcache_read_data` | [127:0] | D-cache read data |
| `lsu_cp0_dcache_read_data_vld` | 1 | D-cache read data valid |
| `lsu_cp0_fence_ack` | 1 | FENCE acknowledge |
| `lsu_cp0_icc_done` | 1 | I-cache clean done |
| `lsu_cp0_sync_ack` | 1 | SYNC acknowledge |
| `mmu_cp0_cmplt` | 1 | MMU complete |
| `mmu_cp0_data` | [63:0] | MMU read data |
| `mmu_cp0_tlb_inv_done` | 1 | TLB invalidation done |
| `mmu_yy_xx_no_op` | 1 | MMU no-operation |
| `pad_yy_icg_scan_en` | 1 | ICG scan enable (DFT) |
| `pmp_cp0_data` | [63:0] | PMP read data |
| `rtu_cp0_epc` | [63:0] | Exception PC |
| `rtu_cp0_exit_debug` | 1 | Exit debug mode |
| `rtu_cp0_fflags` | [4:0] | FP accrued exception flags |
| `rtu_cp0_fflags_updt` | 1 | FP flags update |
| `rtu_cp0_fs_dirty_updt` | 1 | FP dirty state update |
| `rtu_cp0_fs_dirty_updt_dp` | 1 | FP dirty state update (data-path) |
| `rtu_cp0_tval` | [63:0] | Trap value |
| `rtu_cp0_vl` | [7:0] | Vector length (VL) |
| `rtu_cp0_vl_vld` | 1 | VL valid |
| `rtu_cp0_vs_dirty_updt` | 1 | Vector dirty state update |
| `rtu_cp0_vs_dirty_updt_dp` | 1 | Vector dirty state update (data-path) |
| `rtu_cp0_vstart` | [6:0] | Vector start (vstart) |
| `rtu_cp0_vstart_vld` | 1 | vstart valid |
| `rtu_cp0_vxsat` | 1 | Fixed-point saturation flag |
| `rtu_cp0_vxsat_vld` | 1 | vxsat valid |
| `rtu_yy_xx_dbgon` | 1 | Debug mode on |
| `rtu_yy_xx_expt_int` | 1 | Exception or interrupt |
| `rtu_yy_xx_expt_vec` | [4:0] | Exception vector |
| `rtu_yy_xx_expt_vld` | 1 | Exception valid |
| `rtu_yy_xx_flush` | 1 | Pipeline flush |
| `sysio_cp0_apb_base` | [39:0] | APB base address |
| `vidu_cp0_vid_fof_vld` | 1 | VIDU fixed-point overflow valid |

---

## 2. x_aq_idu_top (IDU — Instruction Decode Unit)

**RTL file:** `gen_rtl/idu/rtl/aq_idu_top.v`

| Port | Width | Meaning |
|------|-------|---------|
| `cp0_idu_cskyee` | 1 | C-SKY extension enable |
| `cp0_idu_dis_fence_in_dbg` | 1 | Disable FENCE in debug mode |
| `cp0_idu_frm` | [2:0] | FP rounding mode |
| `cp0_idu_fs` | [1:0] | FP status |
| `cp0_idu_icg_en` | 1 | IDU clock-gating enable |
| `cp0_idu_issue_stall` | 1 | Issue stall (from CSR) |
| `cp0_idu_ucme` | 1 | Unaligned check mode enable |
| `cp0_idu_vill` | 1 | Vector illegal (vill) |
| `cp0_idu_vl_zero` | 1 | Vector length is zero |
| `cp0_idu_vlmul` | [1:0] | Vector LMUL |
| `cp0_idu_vs` | [1:0] | Vector status |
| `cp0_idu_vsetvl_dis_stall` | 1 | vsetvl disable stall |
| `cp0_idu_vsew` | [1:0] | Vector SEW |
| `cp0_idu_vstart` | [6:0] | Vector start |
| `cp0_yy_clk_en` | 1 | Clock enable |
| `cp0_yy_priv_mode` | [1:0] | Privilege mode |
| `cpurst_b` | 1 | Reset (active low) |
| `forever_cpuclk` | 1 | Clock (always-on) |
| `hpcp_idu_cnt_en` | 1 | PMU counter enable |
| `ifu_idu_id_bht_pred` | [1:0] | BHT prediction |
| `ifu_idu_id_expt_acc_error` | 1 | Access-fault exception |
| `ifu_idu_id_expt_high` | 1 | High-priority exception |
| `ifu_idu_id_expt_page_fault` | 1 | Page-fault exception |
| `ifu_idu_id_halt_info` | [21:0] | Debug halt info |
| `ifu_idu_id_inst` | [31:0] | Instruction word |
| `ifu_idu_id_inst_vld` | 1 | Instruction valid |
| `ifu_idu_warm_up` | 1 | IFU warm-up |
| `iu_idu_bju_full` | 1 | BJU pipeline full |
| `iu_idu_bju_global_full` | 1 | BJU global full |
| `iu_idu_div_full` | 1 | Divider pipeline full |
| `iu_idu_mult_full` | 1 | Multiplier pipeline full |
| `iu_idu_mult_issue_stall` | 1 | Multiply issue stall |
| `iu_yy_xx_cancel` | 1 | IU cancel |
| `lsu_idu_full` | 1 | LSU pipeline full |
| `lsu_idu_global_full` | 1 | LSU global full |
| `pad_yy_icg_scan_en` | 1 | ICG scan enable (DFT) |
| `rtu_idu_commit` | 1 | Commit (retire) |
| `rtu_idu_commit_for_bju` | 1 | Commit for BJU |
| `rtu_idu_flush_fe` | 1 | Flush front-end |
| `rtu_idu_flush_stall` | 1 | Flush stall |
| `rtu_idu_flush_wbt` | 1 | Flush writeback |
| `rtu_idu_fwd0_data` | [63:0] | Forward data 0 |
| `rtu_idu_fwd0_reg` | [5:0] | Forward register 0 |
| `rtu_idu_fwd0_vld` | 1 | Forward 0 valid |
| `rtu_idu_fwd1_data` | [63:0] | Forward data 1 |
| `rtu_idu_fwd1_reg` | [5:0] | Forward register 1 |
| `rtu_idu_fwd1_vld` | 1 | Forward 1 valid |
| `rtu_idu_fwd2_data` | [63:0] | Forward data 2 |
| `rtu_idu_fwd2_reg` | [5:0] | Forward register 2 |
| `rtu_idu_fwd2_vld` | 1 | Forward 2 valid |
| `rtu_idu_pipeline_empty` | 1 | RTU pipeline empty |
| `rtu_idu_wb0_data` | [63:0] | Writeback data 0 |
| `rtu_idu_wb0_reg` | [5:0] | Writeback register 0 |
| `rtu_idu_wb0_vld` | 1 | Writeback 0 valid |
| `rtu_idu_wb1_data` | [63:0] | Writeback data 1 |
| `rtu_idu_wb1_reg` | [5:0] | Writeback register 1 |
| `rtu_idu_wb1_vld` | 1 | Writeback 1 valid |
| `rtu_yy_xx_dbgon` | 1 | Debug mode on |
| `vidu_idu_fp_full` | 1 | VIDU FP pipeline full |
| `vidu_idu_vec_full` | 1 | VIDU vector pipeline full |

---

## 3. x_aq_ifu_top (IFU — Instruction Fetch Unit)

**RTL file:** `gen_rtl/ifu/rtl/aq_ifu_top.v`

| Port | Width | Meaning |
|------|-------|---------|
| `biu_ifu_arready` | 1 | AXI AR ready (read address) |
| `biu_ifu_rdata` | [127:0] | AXI read data |
| `biu_ifu_rid` | 1 | AXI read ID |
| `biu_ifu_rlast` | 1 | AXI read last |
| `biu_ifu_rresp` | [1:0] | AXI read response |
| `biu_ifu_rvalid` | 1 | AXI read valid |
| `cp0_ifu_bht_en` | 1 | BHT enable |
| `cp0_ifu_bht_inv` | 1 | BHT invalidation |
| `cp0_ifu_btb_clr` | 1 | BTB clear |
| `cp0_ifu_btb_en` | 1 | BTB enable |
| `cp0_ifu_icache_en` | 1 | I-cache enable |
| `cp0_ifu_icache_inv_addr` | [63:0] | I-cache invalidation address |
| `cp0_ifu_icache_inv_req` | 1 | I-cache invalidation request |
| `cp0_ifu_icache_inv_type` | [1:0] | I-cache invalidation type |
| `cp0_ifu_icache_pref_en` | 1 | I-cache prefetch enable |
| `cp0_ifu_icache_read_index` | [13:0] | I-cache read index |
| `cp0_ifu_icache_read_req` | 1 | I-cache read request |
| `cp0_ifu_icache_read_tag` | 1 | I-cache read tag |
| `cp0_ifu_icache_read_way` | 1 | I-cache read way |
| `cp0_ifu_icg_en` | 1 | IFU clock-gating enable |
| `cp0_ifu_in_lpmd` | 1 | Low-power mode |
| `cp0_ifu_iwpe` | 1 | Instruction write-protection enable |
| `cp0_ifu_lpmd_req` | 1 | Low-power mode request |
| `cp0_ifu_ras_en` | 1 | RAS (return address stack) enable |
| `cp0_ifu_rst_inv_done` | 1 | Reset invalidation done |
| `cp0_xx_mrvbr` | [39:0] | Machine-mode reset vector base |
| `cp0_yy_clk_en` | 1 | Clock enable |
| `cpurst_b` | 1 | Reset (active low) |
| `dtu_ifu_debug_inst` | [31:0] | Debug instruction |
| `dtu_ifu_debug_inst_vld` | 1 | Debug instruction valid |
| `dtu_ifu_halt_info0` | [21:0] | Debug halt info 0 |
| `dtu_ifu_halt_info1` | [21:0] | Debug halt info 1 |
| `dtu_ifu_halt_info_vld` | 1 | Debug halt info valid |
| `dtu_ifu_halt_on_reset` | 1 | Halt on reset |
| `forever_cpuclk` | 1 | Clock (always-on) |
| `hpcp_ifu_cnt_en` | 1 | PMU counter enable |
| `idu_ifu_id_stall` | 1 | ID stage stall |
| `iu_ifu_bht_cur_pc` | [39:0] | BHT current PC |
| `iu_ifu_bht_mispred` | 1 | BHT misprediction |
| `iu_ifu_bht_mispred_gate` | 1 | BHT misprediction (gated) |
| `iu_ifu_bht_pred` | [1:0] | BHT prediction |
| `iu_ifu_bht_taken` | 1 | BHT taken |
| `iu_ifu_br_vld` | 1 | Branch valid |
| `iu_ifu_br_vld_gate` | 1 | Branch valid (gated) |
| `iu_ifu_link_vld` | 1 | Link (jalr) valid |
| `iu_ifu_link_vld_gate` | 1 | Link valid (gated) |
| `iu_ifu_pc_mispred` | 1 | PC misprediction |
| `iu_ifu_pc_mispred_gate` | 1 | PC misprediction (gated) |
| `iu_ifu_ret_vld` | 1 | Return valid |
| `iu_ifu_ret_vld_gate` | 1 | Return valid (gated) |
| `iu_ifu_tar_pc` | [63:0] | Target PC |
| `iu_ifu_tar_pc_vld` | 1 | Target PC valid |
| `iu_ifu_tar_pc_vld_gate` | 1 | Target PC valid (gated) |
| `mmu_ifu_access_fault` | 1 | MMU access fault |
| `mmu_ifu_pa` | [27:0] | Physical address |
| `mmu_ifu_pa_vld` | 1 | Physical address valid |
| `mmu_ifu_prot` | [4:0] | Protection bits |
| `pad_yy_icg_scan_en` | 1 | ICG scan enable (DFT) |
| `rtu_ifu_chgflw_pc` | [39:0] | Change-of-flow PC |
| `rtu_ifu_chgflw_vld` | 1 | Change-of-flow valid |
| `rtu_ifu_dbg_mask` | 1 | Debug mask |
| `rtu_ifu_flush_fe` | 1 | Flush front-end |
| `rtu_yy_xx_dbgon` | 1 | Debug mode on |

---

## 4. x_aq_iu_top (IU — Integer Unit: ALU / BJU / MUL / DIV)

**RTL file:** `gen_rtl/iu/rtl/aq_iu_top.v`

| Port | Width | Meaning |
|------|-------|---------|
| `cp0_iu_icg_en` | 1 | IU clock-gating enable |
| `cp0_xx_mrvbr` | [39:0] | Machine-mode reset vector base |
| `cp0_yy_clk_en` | 1 | Clock enable |
| `cpurst_b` | 1 | Reset (active low) |
| `da_xx_fwd_data` | [63:0] | Forwarding data |
| `da_xx_fwd_dst_reg` | [5:0] | Forwarding destination register |
| `da_xx_fwd_vld` | 1 | Forwarding valid |
| `forever_cpuclk` | 1 | Clock (always-on) |
| `hpcp_iu_cnt_en` | 1 | PMU counter enable |
| `idu_alu_ex1_gateclk_sel` | 1 | ALU EX1 gated-clock select |
| `idu_bju_ex1_gateclk_sel` | 1 | BJU EX1 gated-clock select |
| `idu_div_ex1_gateclk_sel` | 1 | DIV EX1 gated-clock select |
| `idu_iu_ex1_alu_dp_sel` | 1 | ALU EX1 data-path select |
| `idu_iu_ex1_alu_sel` | 1 | ALU EX1 select |
| `idu_iu_ex1_bht_pred` | [1:0] | BHT prediction |
| `idu_iu_ex1_bju_br_sel` | 1 | BJU branch select |
| `idu_iu_ex1_bju_dp_sel` | 1 | BJU data-path select |
| `idu_iu_ex1_bju_sel` | 1 | BJU select |
| `idu_iu_ex1_div_dp_sel` | 1 | DIV data-path select |
| `idu_iu_ex1_div_sel` | 1 | DIV select |
| `idu_iu_ex1_dst0_reg` | [5:0] | EX1 destination register |
| `idu_iu_ex1_func` | [19:0] | EX1 function field |
| `idu_iu_ex1_inst_vld` | 1 | EX1 instruction valid |
| `idu_iu_ex1_length` | 1 | EX1 instruction length |
| `idu_iu_ex1_mult_dp_sel` | 1 | MUL data-path select |
| `idu_iu_ex1_mult_sel` | 1 | MUL select |
| `idu_iu_ex1_pipedown_vld` | 1 | EX1 pipe-down valid |
| `idu_iu_ex1_split` | 1 | EX1 split instruction |
| `idu_iu_ex1_src0_data` | [63:0] | EX1 source operand 0 |
| `idu_iu_ex1_src0_ready` | 1 | Source 0 ready |
| `idu_iu_ex1_src0_reg` | [5:0] | Source 0 register |
| `idu_iu_ex1_src1_data` | [63:0] | EX1 source operand 1 |
| `idu_iu_ex1_src1_ready` | 1 | Source 1 ready |
| `idu_iu_ex1_src1_reg` | [5:0] | Source 1 register |
| `idu_iu_ex1_src2_data` | [63:0] | EX1 source operand 2 |
| `idu_mult_ex1_gateclk_sel` | 1 | MUL EX1 gated-clock select |
| `ifu_iu_chgflw_pc` | [39:0] | Change-of-flow PC |
| `ifu_iu_chgflw_vld` | 1 | Change-of-flow valid |
| `ifu_iu_ex1_pc_pred` | [39:0] | EX1 predicted PC |
| `ifu_iu_reset_vld` | 1 | Reset valid |
| `ifu_iu_warm_up` | 1 | IFU warm-up |
| `lsu_iu_ex2_data` | [63:0] | LSU EX2 forwarding data |
| `lsu_iu_ex2_data_vld` | 1 | LSU EX2 data valid |
| `lsu_iu_ex2_dest_reg` | [4:0] | LSU EX2 destination register |
| `mmu_xx_mmu_en` | 1 | MMU enable |
| `pad_yy_icg_scan_en` | 1 | ICG scan enable (DFT) |
| `rtu_iu_div_wb_grant` | 1 | DIV writeback grant |
| `rtu_iu_div_wb_grant_for_full` | 1 | DIV writeback grant (full) |
| `rtu_iu_ex1_cmplt` | 1 | EX1 complete |
| `rtu_iu_ex1_cmplt_dp` | 1 | EX1 complete (data-path) |
| `rtu_iu_ex1_inst_len` | 1 | EX1 instruction length |
| `rtu_iu_ex1_inst_split` | 1 | EX1 instruction split |
| `rtu_iu_ex2_cur_pc` | [39:0] | EX2 current PC |
| `rtu_iu_ex2_next_pc` | [39:0] | EX2 next PC |
| `rtu_iu_mul_wb_grant` | 1 | MUL writeback grant |
| `rtu_iu_mul_wb_grant_for_full` | 1 | MUL writeback grant (full) |
| `rtu_yy_xx_flush_fe` | 1 | Flush front-end |

---

## 5. x_aq_lsu_top (LSU — Load / Store Unit)

**RTL file:** `gen_rtl/lsu/rtl/aq_lsu_top.v`

| Port | Width | Meaning |
|------|-------|---------|
| `biu_lsu_arready` | 1 | AXI AR ready (read address) |
| `biu_lsu_no_op` | 1 | BIU no-operation |
| `biu_lsu_rdata` | [127:0] | AXI read data |
| `biu_lsu_rid` | [3:0] | AXI read ID |
| `biu_lsu_rlast` | 1 | AXI read last |
| `biu_lsu_rresp` | [1:0] | AXI read response |
| `biu_lsu_rvalid` | 1 | AXI read valid |
| `biu_lsu_stb_awready` | 1 | STB AXI AW ready (write address) |
| `biu_lsu_stb_wready` | 1 | STB AXI W ready (write data) |
| `biu_lsu_vb_awready` | 1 | VB AXI AW ready |
| `biu_lsu_vb_wready` | 1 | VB AXI W ready |
| `cp0_lsu_amr` | [1:0] | Atomic mode register |
| `cp0_lsu_dcache_en` | 1 | D-cache enable |
| `cp0_lsu_dcache_pref_dist` | [1:0] | D-cache prefetch distance |
| `cp0_lsu_dcache_pref_en` | 1 | D-cache prefetch enable |
| `cp0_lsu_dcache_read_idx` | [16:0] | D-cache read index |
| `cp0_lsu_dcache_read_req` | 1 | D-cache read request |
| `cp0_lsu_dcache_read_type` | 1 | D-cache read type |
| `cp0_lsu_dcache_read_way` | [1:0] | D-cache read way |
| `cp0_lsu_dcache_wa` | 1 | D-cache write-allocate |
| `cp0_lsu_dcache_wb` | 1 | D-cache write-back |
| `cp0_lsu_fence_req` | 1 | FENCE request |
| `cp0_lsu_icc_addr` | [63:0] | I-cache clean address |
| `cp0_lsu_icc_op` | [1:0] | I-cache clean operation |
| `cp0_lsu_icc_req` | 1 | I-cache clean request |
| `cp0_lsu_icc_type` | [1:0] | I-cache clean type |
| `cp0_lsu_icg_en` | 1 | LSU clock-gating enable |
| `cp0_lsu_mm` | 1 | Machine mode |
| `cp0_lsu_mpp` | [1:0] | Machine privilege mode pair |
| `cp0_lsu_mprv` | 1 | MPRV (modify privilege) |
| `cp0_lsu_sync_req` | 1 | SYNC request |
| `cp0_lsu_we_en` | 1 | Write-enable |
| `cp0_yy_priv_mode` | [1:0] | Privilege mode |
| `cpurst_b` | 1 | Reset (active low) |
| `dtu_lsu_addr_trig_en` | 1 | Address trigger enable |
| `dtu_lsu_data_trig_en` | 1 | Data trigger enable |
| `dtu_lsu_halt_info` | [21:0] | Debug halt info |
| `dtu_lsu_halt_info_vld` | 1 | Halt info valid |
| `forever_cpuclk` | 1 | Clock (always-on) |
| `hpcp_lsu_cnt_en` | 1 | PMU counter enable |
| `idu_lsu_ex1_dp_sel` | 1 | EX1 data-path select |
| `idu_lsu_ex1_dst0_reg` | [5:0] | EX1 destination 0 |
| `idu_lsu_ex1_dst1_reg` | [5:0] | EX1 destination 1 |
| `idu_lsu_ex1_func` | [19:0] | EX1 function field |
| `idu_lsu_ex1_gateclk_sel` | 1 | EX1 gated-clock select |
| `idu_lsu_ex1_halt_info` | [21:0] | EX1 debug halt info |
| `idu_lsu_ex1_length` | 1 | EX1 instruction length |
| `idu_lsu_ex1_sel` | 1 | EX1 select |
| `idu_lsu_ex1_split` | 1 | EX1 split instruction |
| `idu_lsu_ex1_src0_data` | [63:0] | EX1 source operand 0 |
| `idu_lsu_ex1_src1_data` | [63:0] | EX1 source operand 1 |
| `idu_lsu_ex1_src2_data` | [63:0] | EX1 source operand 2 |
| `idu_lsu_ex1_src2_ready` | 1 | Source 2 ready |
| `idu_lsu_ex1_src2_reg` | [5:0] | Source 2 register |
| `idu_lsu_ex1_vlmul` | [1:0] | Vector LMUL |
| `idu_lsu_ex1_vsew` | [1:0] | Vector SEW |
| `ifu_lsu_warm_up` | 1 | IFU warm-up |
| `iu_lsu_ex1_cur_pc` | [15:0] | EX1 current PC |
| `mmu_lsu_access_fault` | 1 | Access fault |
| `mmu_lsu_buf` | 1 | Bufferable |
| `mmu_lsu_ca` | 1 | Cacheable |
| `mmu_lsu_data_req` | 1 | MMU data request |
| `mmu_lsu_data_req_addr` | [39:0] | MMU data request address |
| `mmu_lsu_data_req_size` | 1 | MMU data request size |
| `mmu_lsu_pa` | [27:0] | Physical address |
| `mmu_lsu_pa_vld` | 1 | PA valid |
| `mmu_lsu_page_fault` | 1 | Page fault |
| `mmu_lsu_sec` | 1 | Security bit |
| `mmu_lsu_sh` | 1 | Shareable |
| `mmu_lsu_so` | 1 | Strong-order |
| `pad_yy_icg_scan_en` | 1 | ICG scan enable (DFT) |
| `rtu_lsu_async_expt_ack` | 1 | Async exception acknowledge |
| `rtu_lsu_expt_ack` | 1 | Exception acknowledge |
| `rtu_lsu_expt_exit` | 1 | Exception exit |
| `rtu_yy_xx_async_flush` | 1 | Async flush |
| `rtu_yy_xx_dbgon` | 1 | Debug mode on |
| `rtu_yy_xx_flush` | 1 | Pipeline flush |
| `vlsu_buf_stall` | 1 | VLSU buffer stall |
| `vlsu_dtu_data` | [63:0] | VLSU debug data |
| `vlsu_dtu_data_vld` | 1 | VLSU debug data valid |
| `vlsu_dtu_data_vld_gate` | 1 | VLSU debug data valid (gated) |
| `vlsu_lsu_data_shift` | [3:0] | VLSU data shift |
| `vlsu_lsu_data_vld` | 1 | VLSU data valid |
| `vlsu_lsu_fwd_data` | [63:0] | VLSU forwarding data |
| `vlsu_lsu_fwd_dest_reg` | [4:0] | VLSU forwarding dest register |
| `vlsu_lsu_fwd_vld` | 1 | VLSU forward valid |
| `vlsu_lsu_src2_depd` | 1 | VLSU source 2 dependency |
| `vlsu_lsu_src2_reg` | [4:0] | VLSU source 2 register |
| `vlsu_lsu_wdata` | [63:0] | VLSU write data |
| `vlsu_xx_no_op` | 1 | VLSU no-operation |

---

## 6. x_aq_rtu_top (RTU — Retire / Trap Unit)

**RTL file:** `gen_rtl/rtu/rtl/aq_rtu_top.v`

| Port | Width | Meaning |
|------|-------|---------|
| `cp0_rtu_ex1_chgflw` | 1 | EX1 change-of-flow |
| `cp0_rtu_ex1_chgflw_pc` | [39:0] | EX1 change-of-flow PC |
| `cp0_rtu_ex1_cmplt` | 1 | EX1 complete |
| `cp0_rtu_ex1_cmplt_dp` | 1 | EX1 complete (data-path) |
| `cp0_rtu_ex1_expt_tval` | [39:0] | EX1 exception trap value |
| `cp0_rtu_ex1_expt_vec` | [4:0] | EX1 exception vector |
| `cp0_rtu_ex1_expt_vld` | 1 | EX1 exception valid |
| `cp0_rtu_ex1_flush` | 1 | EX1 flush |
| `cp0_rtu_ex1_halt_info` | [21:0] | EX1 debug halt info |
| `cp0_rtu_ex1_inst_dret` | 1 | EX1 DRET instruction |
| `cp0_rtu_ex1_inst_ebreak` | 1 | EX1 EBREAK instruction |
| `cp0_rtu_ex1_inst_len` | 1 | EX1 instruction length |
| `cp0_rtu_ex1_inst_mret` | 1 | EX1 MRET instruction |
| `cp0_rtu_ex1_inst_split` | 1 | EX1 instruction split |
| `cp0_rtu_ex1_inst_sret` | 1 | EX1 SRET instruction |
| `cp0_rtu_ex1_vs_dirty` | 1 | EX1 vector dirty |
| `cp0_rtu_ex1_vs_dirty_dp` | 1 | EX1 vector dirty (data-path) |
| `cp0_rtu_ex1_wb_data` | [63:0] | EX1 writeback data |
| `cp0_rtu_ex1_wb_dp` | 1 | EX1 writeback data-path |
| `cp0_rtu_ex1_wb_preg` | [5:0] | EX1 writeback physical register |
| `cp0_rtu_ex1_wb_vld` | 1 | EX1 writeback valid |
| `cp0_rtu_fence_idle` | 1 | FENCE idle |
| `cp0_rtu_icg_en` | 1 | RTU clock-gating enable |
| `cp0_rtu_in_lpmd` | 1 | Low-power mode |
| `cp0_rtu_int_vld` | [14:0] | Interrupt valid |
| `cp0_rtu_trap_pc` | [39:0] | Trap PC |
| `cp0_rtu_vstart_eq_0` | 1 | vstart equals 0 |
| `cp0_yy_clk_en` | 1 | Clock enable |
| `cpurst_b` | 1 | Reset (active low) |
| `dtu_rtu_async_halt_req` | 1 | Async halt request |
| `dtu_rtu_dpc` | [63:0] | Debug PC (DPC) |
| `dtu_rtu_ebreak_action` | 1 | EBREAK action |
| `dtu_rtu_int_mask` | 1 | Interrupt mask |
| `dtu_rtu_pending_tval` | [63:0] | Pending trap value |
| `dtu_rtu_resume_req` | 1 | Resume request |
| `dtu_rtu_step_en` | 1 | Single-step enable |
| `dtu_rtu_sync_flush` | 1 | Sync flush |
| `dtu_rtu_sync_halt_req` | 1 | Sync halt request |
| `forever_cpuclk` | 1 | Clock (always-on) |
| `hpcp_rtu_cnt_en` | 1 | PMU counter enable |
| `ifu_rtu_reset_halt_req` | 1 | Reset halt request |
| `ifu_rtu_warm_up` | 1 | IFU warm-up |
| `iu_rtu_depd_lsu_chgflow_vld` | 1 | Dependent LSU change-of-flow valid |
| `iu_rtu_depd_lsu_next_pc` | [39:0] | Dependent LSU next PC |
| `iu_rtu_div_data` | [63:0] | DIV writeback data |
| `iu_rtu_div_preg` | [5:0] | DIV writeback register |
| `iu_rtu_div_wb_dp` | 1 | DIV writeback data-path |
| `iu_rtu_div_wb_vld` | 1 | DIV writeback valid |
| `iu_rtu_ex1_alu_cmplt` | 1 | ALU EX1 complete |
| `iu_rtu_ex1_alu_cmplt_dp` | 1 | ALU EX1 complete (data-path) |
| `iu_rtu_ex1_alu_data` | [63:0] | ALU EX1 data |
| `iu_rtu_ex1_alu_inst_len` | 1 | ALU EX1 instruction length |
| `iu_rtu_ex1_alu_inst_split` | 1 | ALU EX1 instruction split |
| `iu_rtu_ex1_alu_preg` | [5:0] | ALU EX1 physical register |
| `iu_rtu_ex1_alu_wb_dp` | 1 | ALU EX1 writeback data-path |
| `iu_rtu_ex1_alu_wb_vld` | 1 | ALU EX1 writeback valid |
| `iu_rtu_ex1_bju_cmplt` | 1 | BJU EX1 complete |
| `iu_rtu_ex1_bju_cmplt_dp` | 1 | BJU EX1 complete (data-path) |
| `iu_rtu_ex1_bju_data` | [63:0] | BJU EX1 data |
| `iu_rtu_ex1_bju_inst_len` | 1 | BJU EX1 instruction length |
| `iu_rtu_ex1_bju_preg` | [5:0] | BJU EX1 physical register |
| `iu_rtu_ex1_bju_wb_dp` | 1 | BJU EX1 writeback data-path |
| `iu_rtu_ex1_bju_wb_vld` | 1 | BJU EX1 writeback valid |
| `iu_rtu_ex1_branch_inst` | 1 | EX1 branch instruction |
| `iu_rtu_ex1_cur_pc` | [39:0] | EX1 current PC |
| `iu_rtu_ex1_div_cmplt` | 1 | DIV EX1 complete |
| `iu_rtu_ex1_div_cmplt_dp` | 1 | DIV EX1 complete (data-path) |
| `iu_rtu_ex1_mul_cmplt` | 1 | MUL EX1 complete |
| `iu_rtu_ex1_mul_cmplt_dp` | 1 | MUL EX1 complete (data-path) |
| `iu_rtu_ex1_next_pc` | [39:0] | EX1 next PC |
| `iu_rtu_ex2_bju_ras_mispred` | 1 | BJU EX2 RAS misprediction |
| `iu_rtu_ex3_mul_data` | [63:0] | MUL EX3 data |
| `iu_rtu_ex3_mul_preg` | [5:0] | MUL EX3 physical register |
| `iu_rtu_ex3_mul_wb_vld` | 1 | MUL EX3 writeback valid |
| `iu_xx_no_op` | 1 | IU no-operation |
| `lsu_rtu_async_expt_vld` | 1 | Async exception valid |
| `lsu_rtu_async_ld_inst` | 1 | Async load instruction |
| `lsu_rtu_async_tval` | [39:0] | Async trap value |
| `lsu_rtu_ex1_buffer_vld` | 1 | EX1 buffer valid |
| `lsu_rtu_ex1_cmplt` | 1 | EX1 complete |
| `lsu_rtu_ex1_cmplt_dp` | 1 | EX1 complete (data-path) |
| `lsu_rtu_ex1_cmplt_for_pcgen` | 1 | EX1 complete for PC-gen |
| `lsu_rtu_ex1_data` | [63:0] | EX1 data |
| `lsu_rtu_ex1_dest_reg` | [5:0] | EX1 destination register |
| `lsu_rtu_ex1_expt_tval` | [39:0] | EX1 exception trap value |
| `lsu_rtu_ex1_expt_vec` | [4:0] | EX1 exception vector |
| `lsu_rtu_ex1_expt_vld` | 1 | EX1 exception valid |
| `lsu_rtu_ex1_fs_dirty` | 1 | EX1 FP dirty |
| `lsu_rtu_ex1_halt_info` | [21:0] | EX1 debug halt info |
| `lsu_rtu_ex1_inst_len` | 1 | EX1 instruction length |
| `lsu_rtu_ex1_inst_split` | 1 | EX1 instruction split |
| `lsu_rtu_ex1_tval2_vld` | 1 | EX1 trap value 2 valid |
| `lsu_rtu_ex1_vs_dirty` | 1 | EX1 vector dirty |
| `lsu_rtu_ex1_vstart` | [6:0] | EX1 vstart |
| `lsu_rtu_ex1_vstart_vld` | 1 | EX1 vstart valid |
| `lsu_rtu_ex1_wb_dp` | 1 | EX1 writeback data-path |
| `lsu_rtu_ex1_wb_vld` | 1 | EX1 writeback valid |
| `lsu_rtu_ex2_data` | [63:0] | EX2 data |
| `lsu_rtu_ex2_data_vld` | 1 | EX2 data valid |
| `lsu_rtu_ex2_dest_reg` | [5:0] | EX2 destination register |
| `lsu_rtu_ex2_tval2` | [39:0] | EX2 trap value 2 |
| `lsu_rtu_no_op` | 1 | LSU no-operation |
| `lsu_rtu_wb_data` | [63:0] | Writeback data |
| `lsu_rtu_wb_dest_reg` | [5:0] | Writeback dest register |
| `lsu_rtu_wb_vld` | 1 | Writeback valid |
| `mmu_xx_mmu_en` | 1 | MMU enable |
| `pad_yy_icg_scan_en` | 1 | ICG scan enable (DFT) |
| `vidu_rtu_no_op` | 1 | VIDU no-operation |
| `vlsu_rtu_vl_updt_data` | [7:0] | VL update data |
| `vlsu_rtu_vl_updt_vld` | 1 | VL update valid |
| `vpu_rtu_ex1_cmplt` | 1 | VPU EX1 complete |
| `vpu_rtu_ex1_cmplt_dp` | 1 | VPU EX1 complete (data-path) |
| `vpu_rtu_ex1_fp_dirty` | 1 | VPU EX1 FP dirty |
| `vpu_rtu_ex1_vec_dirty` | 1 | VPU EX1 vector dirty |
| `vpu_rtu_fflag` | [5:0] | VPU FP flags |
| `vpu_rtu_fflag_vld` | 1 | VPU FP flags valid |
| `vpu_rtu_gpr_wb_data` | [63:0] | VPU GPR writeback data |
| `vpu_rtu_gpr_wb_index` | [5:0] | VPU GPR writeback index |
| `vpu_rtu_gpr_wb_req` | 1 | VPU GPR writeback request |
| `vpu_rtu_no_op` | 1 | VPU no-operation |

---

## 7. x_aq_vidu_top (VIDU — Vector / FP Instruction Decode Unit)

**RTL file:** `gen_rtl/vidu/rtl/aq_vidu_top.v`

| Port | Width | Meaning |
|------|-------|---------|
| `cp0_idu_icg_en` | 1 | IDU clock-gating enable (shared) |
| `cp0_yy_clk_en` | 1 | Clock enable |
| `cpurst_b` | 1 | Reset (active low) |
| `forever_cpuclk` | 1 | Clock (always-on) |
| `idu_vidu_ex1_fp_dp_sel` | 1 | FP EX1 data-path select |
| `idu_vidu_ex1_fp_gateclk_sel` | 1 | FP EX1 gated-clock select |
| `idu_vidu_ex1_fp_sel` | 1 | FP EX1 select |
| `idu_vidu_ex1_inst_data` | [179:0] | EX1 instruction data (wide bus) |
| `idu_vidu_ex1_vec_dp_sel` | 1 | Vector EX1 data-path select |
| `idu_vidu_ex1_vec_gateclk_sel` | 1 | Vector EX1 gated-clock select |
| `idu_vidu_ex1_vec_sel` | 1 | Vector EX1 select |
| `ifu_vidu_warm_up` | 1 | IFU warm-up |
| `pad_yy_icg_scan_en` | 1 | ICG scan enable (DFT) |
| `rtu_vidu_flush_wbt` | 1 | Flush writeback |
| `rtu_yy_xx_async_flush` | 1 | Async flush |
| `vpu_vidu_fp_fwd_data` | [63:0] | FP forwarding data |
| `vpu_vidu_fp_fwd_reg` | [4:0] | FP forwarding register |
| `vpu_vidu_fp_fwd_vld` | 1 | FP forward valid |
| `vpu_vidu_fp_wb_data` | [63:0] | FP writeback data |
| `vpu_vidu_fp_wb_reg` | [4:0] | FP writeback register |
| `vpu_vidu_fp_wb_vld` | 1 | FP writeback valid |
| `vpu_vidu_vex1_fp_stall` | 1 | VPU EX1 FP stall |
| `vpu_vidu_wbt_fp_wb0_reg` | [4:0] | WBT FP writeback register 0 |
| `vpu_vidu_wbt_fp_wb0_vld` | 1 | WBT FP writeback 0 valid |
| `vpu_vidu_wbt_fp_wb1_reg` | [4:0] | WBT FP writeback register 1 |
| `vpu_vidu_wbt_fp_wb1_vld` | 1 | WBT FP writeback 1 valid |

---

## 8. x_aq_vpu_top (VPU — Vector / FP Processing Unit)

**RTL file:** `gen_rtl/vdsp/rtl/aq_vpu_top.v`

| Port | Width | Meaning |
|------|-------|---------|
| `cp0_vpu_icg_en` | 1 | VPU clock-gating enable |
| `cp0_vpu_xx_bf16` | 1 | BFloat16 enable |
| `cp0_vpu_xx_dqnan` | 1 | Default quiet NaN |
| `cp0_vpu_xx_rm` | [2:0] | FP rounding mode |
| `cp0_yy_clk_en` | 1 | Clock enable |
| `cpurst_b` | 1 | Reset (active low) |
| `forever_cpuclk` | 1 | Clock (always-on) |
| `ifu_vpu_warm_up` | 1 | IFU warm-up |
| `lsu_vlsu_bytes_vld` | [7:0] | Valid bytes |
| `lsu_vlsu_data` | [63:0] | Load data |
| `lsu_vlsu_data_grant` | 1 | Data grant |
| `lsu_vlsu_data_vld` | 1 | Data valid |
| `lsu_vlsu_dc_create_vld` | 1 | D-cache create valid |
| `lsu_vlsu_dc_fld_req` | 1 | D-cache fill request |
| `lsu_vlsu_dc_fof` | 1 | Fixed-point overflow flag |
| `lsu_vlsu_dc_nf` | [2:0] | Number of fields |
| `lsu_vlsu_dc_sew` | [1:0] | D-cache SEW |
| `lsu_vlsu_dc_split_cnt` | [9:0] | Split count |
| `lsu_vlsu_dc_sseg_first` | 1 | Segment first |
| `lsu_vlsu_dc_stall` | 1 | D-cache stall |
| `lsu_vlsu_dest_reg` | [4:0] | Destination register |
| `lsu_vlsu_expt_vld` | 1 | Exception valid |
| `lsu_vlsu_func` | [19:0] | Function field |
| `lsu_vlsu_sew` | [1:0] | SEW |
| `lsu_vlsu_split_last` | 1 | Split last |
| `lsu_vlsu_st_expt` | 1 | Store exception |
| `lsu_vlsu_st_offset` | [3:0] | Store offset |
| `lsu_vlsu_st_sew` | [1:0] | Store SEW |
| `lsu_vlsu_st_size` | [1:0] | Store size |
| `lsu_vlsu_vl_update` | 1 | VL update |
| `lsu_vlsu_vl_upval` | [6:0] | VL update value |
| `pad_yy_icg_scan_en` | 1 | ICG scan enable (DFT) |
| `rtu_vpu_gpr_wb_grnt` | 1 | GPR writeback grant |
| `rtu_yy_xx_async_flush` | 1 | Async flush |
| `rtu_yy_xx_flush` | 1 | Pipeline flush |
| `vidu_vpu_vid_fp_inst_dp_vld` | 1 | FP instruction data-path valid |
| `vidu_vpu_vid_fp_inst_dst_reg` | [5:0] | FP instruction dest register |
| `vidu_vpu_vid_fp_inst_dst_vld` | 1 | FP instruction dest valid |
| `vidu_vpu_vid_fp_inst_dste_vld` | 1 | FP instruction dest (element) valid |
| `vidu_vpu_vid_fp_inst_dstf_reg` | [4:0] | FP instruction dest FP register |
| `vidu_vpu_vid_fp_inst_dstf_vld` | 1 | FP instruction dest FP valid |
| `vidu_vpu_vid_fp_inst_eu` | [9:0] | FP instruction execution unit |
| `vidu_vpu_vid_fp_inst_func` | [19:0] | FP instruction function field |
| `vidu_vpu_vid_fp_inst_gateclk_vld` | 1 | FP instruction gated-clock valid |
| `vidu_vpu_vid_fp_inst_src1_data` | [63:0] | FP instruction source 1 data |
| `vidu_vpu_vid_fp_inst_srcf0_data` | [63:0] | FP source FP register 0 data |
| `vidu_vpu_vid_fp_inst_srcf1_data` | [63:0] | FP source FP register 1 data |
| `vidu_vpu_vid_fp_inst_srcf2_data` | [63:0] | FP source FP register 2 data |
| `vidu_vpu_vid_fp_inst_srcf2_rdy` | 1 | FP source 2 ready |
| `vidu_vpu_vid_fp_inst_srcf2_vld` | 1 | FP source 2 valid |
| `vidu_vpu_vid_fp_inst_vld` | 1 | FP instruction valid |
