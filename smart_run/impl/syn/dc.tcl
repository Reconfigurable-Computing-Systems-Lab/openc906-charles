################################################################################
# User configuration
################################################################################
set PROJ_ROOT       /dfs/usrhome/jjiangan/github/openc906-charles-imp
set RTL_ROOT        ${PROJ_ROOT}/C906_RTL_FACTORY
set SDC_ROOT        ${PROJ_ROOT}/smart_run/impl/sdc
set TOP_MODULE_NAME openC906

# C906 filelists embed paths as ${CODE_BASE_PATH}/gen_rtl/...
# Export it so read_filelist can substitute the token while loading.
set ::env(CODE_BASE_PATH) ${RTL_ROOT}

# Create a timestamped batch directory for all outputs
# Read BATCH_DIR from environment if set, otherwise auto-generate
if {[info exists ::env(BATCH_DIR)] && $::env(BATCH_DIR) ne ""} {
  set BATCH_DIR $::env(BATCH_DIR)
} else {
  set date_hour [clock format [clock seconds] -format "%Y%m%d_%H"]
  set BATCH_DIR "batch_${date_hour}"
}
file mkdir ${BATCH_DIR}/reports   ;# timing/area/power reports
file mkdir ${BATCH_DIR}/results   ;# synthesized netlist and constraints

################################################################################
# Step 1: library setup
################################################################################
# set library
set SRAM_DB_DIR ${PROJ_ROOT}/smart_run/impl/gen_sram/db

set search_path [list . \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140/tcbn28hpcplusbwp30p140_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140_180a/ \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140hvt/tcbn28hpcplusbwp30p140hvt_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140hvt_180a/ \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp30p140lvt/tcbn28hpcplusbwp30p140lvt_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp30p140lvt_180a/ \
  /dfs/app/tsmc_icdc/tsmc028/28HPCplus_RF/SC/tcbn28hpcplusbwp40p140ehvt/tcbn28hpcplusbwp40p140ehvt_190a/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp40p140ehvt_170a \
  ${SRAM_DB_DIR} \
]

# --- Standard-cell libraries (synthesis target) ---
set target_library [list \
  tcbn28hpcplusbwp30p140tt1v25c_ccs.db \
  tcbn28hpcplusbwp30p140hvttt1v25c_ccs.db \
  tcbn28hpcplusbwp30p140lvttt1v25c_ccs.db \
  tcbn28hpcplusbwp40p140ehvttt1v25c_ccs.db \
]

# --- Link library: std cells + SRAM hard macros ---
set sram_db_list [glob -nocomplain -directory ${SRAM_DB_DIR} *.db]

set link_library [concat [list {*}] $target_library $sram_db_list]

# naming rules
define_name_rules lab_vlog   -type  port  \
        -allowed {a-zA-Z0-9[]_} \
        -equal_ports_nets    \
        -first_restricted  "0-9_"  \
        -max_length   256
define_name_rules lab_vlog   -type  net  \
        -allowed "a-zA-Z0-9_" \
        -equal_ports_nets    \
        -first_restricted  "0-9_"  \
        -max_length   256
define_name_rules lab_vlog   -type  cell  \
        -allowed "a-zA-Z0-9_" \
        -first_restricted  "0-9_"  \
        -map {{{"\[","_","\]",""},{"\[","_"}}}  \
        -max_length   256
define_name_rules slash   -restricted  {/}  -replace  {_}

################################################################################
# Step 2: import design
################################################################################
define_design_lib WORK -path ${BATCH_DIR}/WORK

# Helper proc: read a filelist and resolve relative paths from the filelist dir.
# Also expands ${ENV_VAR} tokens (the C906 filelists use ${CODE_BASE_PATH}).
proc read_filelist {fl_path} {
    set fl_dir [file dirname $fl_path]
    set files {}
    set fp [open $fl_path r]
    while {[gets $fp line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "#*" $line] || [string match "+*" $line]} continue
        # Expand ${VAR} tokens against the process environment.
        while {[regexp {\$\{([A-Za-z_][A-Za-z0-9_]*)\}} $line -> var]} {
            if {![info exists ::env($var)]} {
                error "read_filelist: environment variable '$var' is not set (referenced in $fl_path)"
            }
            set line [string map [list "\${$var}" $::env($var)] $line]
        }
        lappend files [file normalize [file join $fl_dir $line]]
    }
    close $fp
    return $files
}

# Read C906 RTL filelist
set all_rtl_files [read_filelist ${RTL_ROOT}/gen_rtl/filelists/C906_asic_rtl.fl]

# --- ASIC SRAM substitution ---------------------------------------------------
# The C906 RTL wrappers gen_rtl/{ifu,lsu,mmu}/rtl/aq_spsram_*.v hard-code an
# instantiation of aq_f_spsram_* (FPGA behavioral RAM, gen_rtl/fpga/rtl/), which
# DC would synthesise into ~600k flip-flops. For ASIC synthesis we drop those
# behavioural files and substitute:
#   * aq_f_spsram_shim.v     — re-defines aq_f_spsram_* as thin wrappers that
#                              instantiate aq_umc_spsram_* by the same port
#                              names, so no RTL edit is needed upstream.
#   * aq_umc_spsram_wrappers.v (smart_run/impl/MEM_INTF) — instantiates the
#                              TSMC 28HPC+ hard macros (TS1N28HPCPU... /
#                              TS5N28HPCP...) which are linked from the .db
#                              files in smart_run/impl/gen_sram/db/.
set asic_rtl_files {}
foreach f $all_rtl_files {
    if {[string match "*/gen_rtl/fpga/rtl/aq_f_spsram_*.v" $f]} continue
    lappend asic_rtl_files $f
}
set MEM_INTF_DIR ${PROJ_ROOT}/smart_run/impl/MEM_INTF
set SYN_DIR      ${PROJ_ROOT}/smart_run/impl/syn
lappend asic_rtl_files \
    ${SYN_DIR}/aq_f_spsram_shim.v \
    ${MEM_INTF_DIR}/aq_umc_spsram_wrappers.v

# Analyze RTL
# NOTE: .h header files contain `define macros and must be analyzed first (no
#       `include directives exist in this design — macro visibility depends on
#       compile order). The filelist already has .h files listed before the .v
#       files that use them.
analyze -format verilog $asic_rtl_files

elaborate ${TOP_MODULE_NAME}

# store the unmapped results
write -hierarchy -format ddc -output ${BATCH_DIR}/results/${TOP_MODULE_NAME}.unmapped.ddc

################################################################################
# Step 3: constrain your design
################################################################################
# C906_TOP.sdc references MAX_FANOUT/MAX_TRANSITION/LOAD_PIN/DRIVING_CELL but
# only sets them when IF_READ_BUIDIN_VARIABLES==1 (intended for standalone STA,
# not synthesis). For synthesis we inject sensible TSMC 28HPC+ defaults here so
# create_clock actually executes and the design is timed at 1.0 GHz.
set MAX_FANOUT     32
set MAX_TRANSITION 0.5
set LOAD_PIN       "BUFFD2BWP30P140/I"
set DRIVING_CELL   "BUFFD2BWP30P140"

source ${SDC_ROOT}/C906_TOP.sdc

# Create default path groups
set ports_clock_root \
  [filter_collection [get_attribute [get_clocks] sources] object_class==port]
group_path -name REGOUT -to [all_outputs]
group_path -name REGIN -from [remove_from_collection [all_inputs] \
  ${ports_clock_root}]
group_path -name FEEDTHROUGH -from \
  [remove_from_collection [all_inputs] ${ports_clock_root}] -to [all_outputs]

# Prevent assignment statements in the Verilog netlist.
set_fix_multiple_port_nets -all -buffer_constants

# Check for design errors
check_design -summary
check_design > ${BATCH_DIR}/reports/${TOP_MODULE_NAME}.check_design.rpt

################################################################################
# Step 4: compile the design
################################################################################
compile_ultra

# Optional: keep hierarchy for debug
# compile_ultra -no_autoungroup

# High-effort area optimization
optimize_netlist -area

################################################################################
# Step 5: write out final design and reports
################################################################################
change_names -rules verilog -hierarchy

# Write out design
write -format verilog -hierarchy -output ${BATCH_DIR}/results/${TOP_MODULE_NAME}.mapped.v
write -format ddc -hierarchy -output ${BATCH_DIR}/results/${TOP_MODULE_NAME}.mapped.ddc
write_sdf ${BATCH_DIR}/results/${TOP_MODULE_NAME}.mapped.sdf
write_sdc -nosplit ${BATCH_DIR}/results/${TOP_MODULE_NAME}.mapped.sdc

# Write PTPX name mapping file (RTL-to-gate register name mapping)
# This is sourced by PrimePower when annotating RTL VCD/FSDB onto the gate netlist.
saif_map -type ptpx -write_map ${BATCH_DIR}/results/${TOP_MODULE_NAME}.ptpxmap.tcl
report_saif -hier -rtl -missing > ${BATCH_DIR}/reports/${TOP_MODULE_NAME}.saif_annotation.rpt

# Generate reports
report_qor > ${BATCH_DIR}/reports/${TOP_MODULE_NAME}.mapped.qor.rpt
report_timing -transition_time -nets -attribute -nosplit \
  > ${BATCH_DIR}/reports/${TOP_MODULE_NAME}.mapped.timing.rpt
report_area -nosplit > ${BATCH_DIR}/reports/${TOP_MODULE_NAME}.mapped.area.rpt
report_area -hierarchy -nosplit > ${BATCH_DIR}/reports/${TOP_MODULE_NAME}.mapped.area_hier.rpt
report_power -hierarchy -nosplit > ${BATCH_DIR}/reports/${TOP_MODULE_NAME}.mapped.power_hier.rpt

################################################################################
# Exit Design Compiler
################################################################################
exit
