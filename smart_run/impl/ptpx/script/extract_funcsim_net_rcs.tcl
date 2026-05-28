# Generate Verdi/nWave rc files containing top-level nets for selected
# functional-simulation instances.
#
# Usage:
#   verdi -batch -play smart_run/impl/ptpx/script/extract_funcsim_net_rcs.tcl
#
# Optional overrides:
#   FSDB=/path/to/csr.fsdb RC_ROOT=/path/to/rc verdi -batch -play ...

proc getenv_or_default {name default_value} {
  if {[info exists ::env($name)] && $::env($name) ne ""} {
    return $::env($name)
  }
  return $default_value
}

proc add_nets {win inst} {
  wvAddSignal -win $win -clear
  wvAddSignal -win $win -scope $inst -type net
}

proc save_signal_rc {win out_rc} {
  set save_errors {}

  if {![catch {wvSaveSignal -win $win $out_rc} result] && [file exists $out_rc]} {
    return
  }
  lappend save_errors "wvSaveSignal positional: $result"

  if {![catch {wvSaveSignal -win $win -file $out_rc} result] && [file exists $out_rc]} {
    return
  }
  lappend save_errors "wvSaveSignal -file: $result"

  puts "INFO: wvSaveSignal did not create $out_rc"
  puts "INFO: retrying with wvSaveSignalRC"

  set cwd [pwd]
  set out_dir [file dirname $out_rc]
  set out_tail [file tail $out_rc]
  cd $out_dir
  file delete -force signal.rc
  if {[catch {wvSaveSignalRC -win $win -layout -cursor -marker -scopehier -fsdbinfo -abspath} rc_err]} {
    cd $cwd
    error "failed to save $out_rc: $save_errors; wvSaveSignalRC error: $rc_err"
  }
  if {[file exists signal.rc]} {
    file rename -force signal.rc $out_tail
  } elseif {![file exists $out_tail]} {
    cd $cwd
    error "wvSaveSignalRC completed but no signal.rc or $out_tail was created in $out_dir"
  }
  cd $cwd
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../../../..]]
set default_fsdb [file join $repo_root regress/regress_result/csr.fsdb]
set default_rc_root [file normalize [file join $script_dir ../rc]]

set fsdb [file normalize [getenv_or_default FSDB $default_fsdb]]
set rc_root [file normalize [getenv_or_default RC_ROOT $default_rc_root]]

if {![file exists $fsdb]} {
  error "FSDB not found: $fsdb"
}

set core_path "/tb/x_soc/x_cpu_sub_system_axi/x_c906_wrapper/x_cpu_top/x_aq_top_0/x_aq_core"
set jobs [list \
  [list cp0  "${core_path}/x_aq_cp0_top"] \
  [list iu   "${core_path}/x_aq_iu_top"] \
  [list lsu  "${core_path}/x_aq_lsu_top"] \
  [list rtu  "${core_path}/x_aq_rtu_top"] \
  [list vidu "${core_path}/x_aq_vidu_top"] \
  [list vpu  "${core_path}/x_aq_vpu_top"] \
]

puts "INFO: FSDB=$fsdb"
puts "INFO: RC_ROOT=$rc_root"

set wave_win [wvCreateWindow]
wvOpenFile -win $wave_win $fsdb

foreach job $jobs {
  lassign $job block inst

  set out_dir [file join $rc_root $block]
  set out_rc [file join $out_dir "${block}_net.rc"]
  file mkdir $out_dir

  puts "INFO: extracting nets for $inst"
  add_nets $wave_win $inst
  save_signal_rc $wave_win $out_rc
  puts "INFO: wrote $out_rc"
}

debExit
