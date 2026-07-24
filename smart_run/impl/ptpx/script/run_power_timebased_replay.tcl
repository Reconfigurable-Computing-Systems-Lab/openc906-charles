################################################################################
# PrimePower Time-Based Power Analysis Script  (gate-level FSDB replay)
# Design : openC906 (T-Head C906 core top)
# Process: TSMC 28nm HPC+
# FSDB   : gate-level simulation waveform (smart_run/impl/gls results)
################################################################################

################################################################################
# Step 0: project paths and directories
################################################################################
set PROJ_ROOT /dfs/usrhome/jjiangan/github/hw_charles
set SYN_ROOT  ${PROJ_ROOT}/smart_run/impl/syn

# Parse the input directory (synthesis results)
if {[info exists ::env(IN_DIR)]} {
  set IN_DIR $::env(IN_DIR)
} else {
  puts "Error: IN_DIR environment variable is not set."
  puts "Usage: run_ptpx_parallel.py --in_dir <input_directory> --fsdb_names <fsdb>"
  exit 1
}

# Parse the output directory (reports and results)
if {[info exists ::env(OUT_DIR)]} {
  set OUT_DIR $::env(OUT_DIR)
} else {
  puts "Error: OUT_DIR environment variable is not set."
  puts "Usage: run_ptpx_parallel.py --in_dir <input_directory> --fsdb_names <fsdb>"
  exit 1
}

# Parse the FSDB name
if {[info exists ::env(FSDB_NAME)]} {
  set FSDB_NAME $::env(FSDB_NAME)
} else {
  puts "Error: FSDB_NAME environment variable is not set."
  puts "Usage: run_ptpx_parallel.py --fsdb_names <fsdb>"
  exit 1
}

# Parse start/end ns from environment variables (default to empty if not set)
set START_NS ""
set END_NS ""
if {[info exists ::env(START_NS)]} {
  set START_NS $::env(START_NS)
}
if {[info exists ::env(END_NS)]} {
  set END_NS $::env(END_NS)
}

# Parse clock period
if {[info exists ::env(CLK_PERIOD)]} {
  set CLK_PERIOD $::env(CLK_PERIOD)
} else {
  puts "Error: CLK_PERIOD environment variable is not set."
  puts "Usage: run_ptpx_parallel.py --clk_period <clock_period>"
  exit 1
}

# Validate: both must be set or both must be empty
if {($START_NS ne "" && $END_NS eq "") || ($START_NS eq "" && $END_NS ne "")} {
  puts "Error: Both START_NS and END_NS must be set, or both must be empty."
  exit 1
}

set USE_TIME_WINDOW [expr {$START_NS ne "" && $END_NS ne ""}]

# Set design parameters
set DESIGN_TOP openC906
set STRIP_PATH tb/x_soc/x_cpu_sub_system_axi/x_c906_wrapper/x_cpu_top

# Create output directories
file mkdir ${OUT_DIR}/reports
file mkdir ${OUT_DIR}/results

################################################################################
# Step 1: library setup  (TSMC 28nm HPC+ CCS, matching syn/dc.tcl)
################################################################################
set SRAM_DB_DIR ${PROJ_ROOT}/smart_run/impl/gen_sram/db

set_app_var search_path [list . \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140/tcbn28hpcplusbwp30p140_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140_180a/ \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140hvt/tcbn28hpcplusbwp30p140hvt_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140hvt_180a/ \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140lvt/tcbn28hpcplusbwp30p140lvt_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140lvt_180a/ \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp40p140ehvt/tcbn28hpcplusbwp40p140ehvt_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp40p140ehvt_170a \
  ${SRAM_DB_DIR} \
]

# --- Standard-cell libraries (must match syn/dc.tcl target_library) ---
set_app_var target_library [list \
  tcbn28hpcplusbwp30p140tt1v25c_ccs.db \
  tcbn28hpcplusbwp30p140hvttt1v25c_ccs.db \
  tcbn28hpcplusbwp30p140lvttt1v25c_ccs.db \
  tcbn28hpcplusbwp40p140ehvttt1v25c_ccs.db \
]

# --- Link library: std cells + SRAM hard macros ---
set sram_db_list [glob -nocomplain -directory ${SRAM_DB_DIR} *.db]
set_app_var link_library [concat [list {*}] $target_library $sram_db_list]

################################################################################
# Step 2: power analysis mode
################################################################################
set_app_var power_enable_analysis        true
set_app_var power_analysis_mode          time_based
set_app_var power_enable_timing_analysis true

################################################################################
# Step 3: read synthesized gate-level netlist
################################################################################
# Use DDC instead of Verilog to avoid SVR-15 port-width mismatch errors caused by
# GTECH/DesignWare synthetic operators in emitted Verilog netlists.
set DDC_FILE ${IN_DIR}/results/${DESIGN_TOP}.mapped.ddc
if {![file exists ${DDC_FILE}]} {
  puts "Fatal: mapped DDC not found: ${DDC_FILE}"
  exit 1
}

read_ddc ${DDC_FILE}
current_design ${DESIGN_TOP}
link_design

################################################################################
# Step 4: read timing constraints (from DC output)
################################################################################
set SDC_FILE ${IN_DIR}/results/${DESIGN_TOP}.mapped.sdc
if {![file exists ${SDC_FILE}]} {
  puts "Fatal: mapped SDC not found: ${SDC_FILE}"
  exit 1
}
read_sdc ${SDC_FILE}

################################################################################
# Step 5: back-annotation
################################################################################
# No SPEF file -- skipping parasitic annotation.
# (For post-layout accuracy, add read_parasitics here.)

################################################################################
# Step 6: timing analysis  (must run before power analysis)
################################################################################
check_timing > ${OUT_DIR}/reports/${DESIGN_TOP}_check_timing.rpt
update_timing
report_timing > ${OUT_DIR}/reports/${DESIGN_TOP}_timing.rpt

################################################################################
# Step 7: read switching activity from the gate-level simulation FSDB
################################################################################
# The FSDB comes from the SDF-annotated gate-level sim (smart_run/impl/gls),
# which uses the same testbench hierarchy as the behavioral sim, so only the
# testbench prefix has to be stripped; signal names already match the netlist
# (no -rtl flag, no DC ptpxmap needed).
#
# When START_NS / END_NS are provided, pass -time to read_fsdb so that only the
# requested window of the FSDB is loaded (saves memory and runtime).
if {$USE_TIME_WINDOW} {
  puts "INFO: Reading FSDB time window \[${START_NS} ns .. ${END_NS} ns\]"
  read_fsdb -strip_path ${STRIP_PATH} \
    -time [list $START_NS $END_NS] \
    ${FSDB_NAME}
} else {
  puts "INFO: Reading full FSDB (no time window specified)"
  read_fsdb -strip_path ${STRIP_PATH} ${FSDB_NAME}
}

################################################################################
# Step 8: power analysis
################################################################################
# Output power waveform in FSDB format (viewable in Verdi/nWave).
check_power > ${OUT_DIR}/reports/${DESIGN_TOP}_check_power.rpt

set_power_analysis_options \
  -waveform_format fsdb \
  -waveform_output ${OUT_DIR}/results/${DESIGN_TOP}_pwr
update_power

################################################################################
# Step 9: power reports
################################################################################
set_app_var power_report_leakage_breakdowns true

report_power -hierarchy       > ${OUT_DIR}/reports/${DESIGN_TOP}_power_hier.rpt
report_power -hierarchy -area > ${OUT_DIR}/reports/${DESIGN_TOP}_power_area.rpt

################################################################################
# Step 10: switching activity coverage report
################################################################################
report_switching_activity -coverage \
  > ${OUT_DIR}/reports/${DESIGN_TOP}_switching_coverage.rpt

################################################################################
# Save session and exit
################################################################################
# save_session ${OUT_DIR}/results/${DESIGN_TOP}.session
exit
