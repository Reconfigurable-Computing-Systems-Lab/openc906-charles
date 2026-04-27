################################################################################
# Read an existing mapped DDC for interactive analysis (timing/area/power).
# Usage:  dc_shell -f read_ddc.tcl   (BATCH_DIR exported by run_dc.csh)
################################################################################
set PROJ_ROOT       /dfs/usrhome/jjiangan/github/openc906-charles-imp
set SRAM_DB_DIR     ${PROJ_ROOT}/smart_run/impl/gen_sram/db
set TOP_MODULE_NAME openC906

# Read BATCH_DIR from environment variable
if {[info exists ::env(BATCH_DIR)]} {
  set BATCH_DIR $::env(BATCH_DIR)
} else {
  puts "Error: BATCH_DIR environment variable is not set."
  puts "Usage: run_dc.csh -mode read_ddc -batch_dir <batch_directory>"
  exit 1
}

################################################################################
# Library setup (must match the original synthesis)
################################################################################
set search_path [list . \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140/tcbn28hpcplusbwp30p140_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140_180a/ \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140hvt/tcbn28hpcplusbwp30p140hvt_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140hvt_180a/ \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140lvt/tcbn28hpcplusbwp30p140lvt_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140lvt_180a/ \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp40p140ehvt/tcbn28hpcplusbwp40p140ehvt_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp40p140ehvt_170a \
  ${SRAM_DB_DIR} \
]

set target_library [list \
  tcbn28hpcplusbwp30p140tt1v25c_ccs.db \
  tcbn28hpcplusbwp30p140hvttt1v25c_ccs.db \
  tcbn28hpcplusbwp30p140lvttt1v25c_ccs.db \
  tcbn28hpcplusbwp40p140ehvttt1v25c_ccs.db \
]

set sram_db_list [glob -nocomplain -directory ${SRAM_DB_DIR} *.db]
set link_library [concat [list {*}] $target_library $sram_db_list]

################################################################################
# Read existing DDC and link
################################################################################
read_ddc ${BATCH_DIR}/results/${TOP_MODULE_NAME}.mapped.ddc
current_design ${TOP_MODULE_NAME}
link
