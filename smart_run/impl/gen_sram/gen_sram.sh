#!/bin/tcsh
# Generate all SRAM macros required by openc906 (aq_spsram_*) using TSMC mc-2 compilers.
# Usage: source gen_sram.sh
#
# All eight C906 SRAM wrappers expose the canonical TSMC SP-SRAM pinout
# (A, CEN, CLK, D, GWEN, Q, WEN) with WE_WIDTH == DATA_WIDTH, i.e. a true
# per-bit BWEB.  Every compiler invocation below therefore keeps BWEB enabled
# (no -NonBWEB flag).
#
# Macros generated (one per C906 instantiated wrapper):
#   d127 (HVT, large array, byte-organized 8:1 mux):
#     ts1n28hpcphvtb1024x64m8s        <-- aq_spsram_1024x64 (D-cache data)
#   uhd (SVT, 4:1 mux, write-mask):
#     ts1n28hpcpuhdsvtb2048x32m4sw    <-- aq_spsram_2048x32 (I-cache data)
#     ts1n28hpcpuhdsvtb1024x16m4sw    <-- aq_spsram_1024x16 (BHT)
#   uhd (SVT, 2:1 mux, write-mask):
#     ts1n28hpcpuhdsvtb256x59m2sw     <-- aq_spsram_256x59  (I-cache tag)
#     ts1n28hpcpuhdsvtb64x58m2sw      <-- aq_spsram_64x58   (D-cache tag)
#     ts1n28hpcpuhdsvtb64x88m2sw      <-- aq_spsram_64x88   (JTLB data)
#     ts1n28hpcpuhdsvtb64x98m2sw      <-- aq_spsram_64x98   (JTLB tag)
#   1prf (SVT, register-file, 2:1 mux, write-mask):
#     ts5n28hpcpsvta128x8m2fw         <-- aq_spsram_128x8   (D-cache dirty)

# ---------------------------------------------------------------
# preparation
# ---------------------------------------------------------------
# clean workspace
rm -rf ts1*1*0a ts5*1*0a

# source the mc tool
source /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SRAM/Compiler/tsmc_n28hpcpmc_20120200_110a/cshrc.mc2

# ---------------------------------------------------------------
# generate (high-density 1-port SRAM, HVT, bit-write):
#   ts1n28hpcphvtb1024x64m8s
# ---------------------------------------------------------------
setenv MC_HOME /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SRAM/Compiler/tsn28hpcpd127spsram_20120200_180a
${MC_HOME}/tsn28hpcpd127spsram_180a.pl -file config/ts1n_28hpcp_hvt_b1024x64_m8s.txt \
    -NonBIST -NonAWT

# ---------------------------------------------------------------
# generate (ultra-high-density 1-port SRAM, SVT, write-mask):
#   ts1n28hpcpuhdsvtb2048x32m4sw
#   ts1n28hpcpuhdsvtb1024x16m4sw
#   ts1n28hpcpuhdsvtb256x59m2sw
#   ts1n28hpcpuhdsvtb64x58m2sw
#   ts1n28hpcpuhdsvtb64x88m2sw
#   ts1n28hpcpuhdsvtb64x98m2sw
# ---------------------------------------------------------------
setenv MC_HOME /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SRAM/Compiler/tsn28hpcpuhdspsram_20120200_170a
${MC_HOME}/tsn28hpcpuhdspsram_170a.pl -file config/ts1n_28hpcp_uhd_svt_m4s_w.txt \
    -SVT -NonBIST
${MC_HOME}/tsn28hpcpuhdspsram_170a.pl -file config/ts1n_28hpcp_uhd_svt_m2s_w.txt \
    -SVT -NonBIST -NonSLP -NonSD

# ---------------------------------------------------------------
# generate (1-port register file, SVT, write-mask):
#   ts5n28hpcpsvta128x8m2fw
# ---------------------------------------------------------------
setenv MC_HOME /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SRAM/Compiler/tsn28hpcp1prf_20120200_130a
${MC_HOME}/tsn28hpcp1prf_130a.pl -file config/ts5n_28hpcp_svt_a128x8_m2f_w.txt \
    -SVT -NonBIST -NonSLP -NonSD

# ---------------------------------------------------------------
# clean up compiler temp files
# ---------------------------------------------------------------
# rm -rf *.cfg
echo ""
echo "SRAM generation complete. Run cvrt_lib2db.sh to convert .lib to .db."
