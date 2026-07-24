// SPDX-License-Identifier: Apache-2.0
// Gate-level simulation filelist (paths relative to smart_run/work_gls, where
// vcs is invoked by impl/gls/Makefile). The mapped netlist itself is passed on
// the vcs command line (its location depends on BATCH_DIR).

// --- TSMC 28HPC+ standard-cell Verilog models (all four VT flavors used by
//     syn/dc.tcl target_library). Adjust the kit-internal version directories
//     if your installation differs.
/dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140/tcbn28hpcplusbwp30p140_190a/Front_End/verilog/tcbn28hpcplusbwp30p140_180a/tcbn28hpcplusbwp30p140.v
/dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140hvt/tcbn28hpcplusbwp30p140hvt_190a/Front_End/verilog/tcbn28hpcplusbwp30p140hvt_180a/tcbn28hpcplusbwp30p140hvt.v
/dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140lvt/tcbn28hpcplusbwp30p140lvt_190a/Front_End/verilog/tcbn28hpcplusbwp30p140lvt_180a/tcbn28hpcplusbwp30p140lvt.v
/dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp40p140ehvt/tcbn28hpcplusbwp40p140ehvt_190a/Front_End/verilog/tcbn28hpcplusbwp40p140ehvt_170a/tcbn28hpcplusbwp40p140ehvt.v

// --- TSMC SRAM macro functional models (instantiated inside the netlist via
//     the synthesized aq_umc_spsram_* wrappers).
../impl/gen_sram/verilog/ts1n28hpcphvtb1024x64m8swso_180a_tt1v25c.v
../impl/gen_sram/verilog/ts1n28hpcpuhdsvtb1024x16m4swso_170a_tt1v25c.v
../impl/gen_sram/verilog/ts1n28hpcpuhdsvtb2048x32m4swso_170a_tt1v25c.v
../impl/gen_sram/verilog/ts1n28hpcpuhdsvtb256x59m2sw_170a_tt1v25c.v
../impl/gen_sram/verilog/ts1n28hpcpuhdsvtb64x58m2sw_170a_tt1v25c.v
../impl/gen_sram/verilog/ts1n28hpcpuhdsvtb64x88m2sw_170a_tt1v25c.v
../impl/gen_sram/verilog/ts1n28hpcpuhdsvtb64x98m2sw_170a_tt1v25c.v
../impl/gen_sram/verilog/ts5n28hpcpsvta128x8m2fw_130a_tt1v25c.v

// --- Debug module RTL (tdt_dmi_top sits in the SoC, outside the synthesized
//     openC906 netlist) — same filelist the behavioral sim uses.
-f ${CODE_BASE_PATH}/gen_rtl/filelists/tdt_dmi_top_rtl.fl
