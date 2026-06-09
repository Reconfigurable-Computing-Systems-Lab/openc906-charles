# Generate Verdi/nWave rc files containing top-level input ports, output ports,
# all signals, and internal signals for a selected functional-simulation
# instance.
#
# Usage:
#   verdi -batch -play smart_run/impl/ptpx/script/extract_funcsim_rc.tcl aq_core /tb/x_soc/x_cpu_sub_system_axi/x_c906_wrapper/x_cpu_top/x_aq_top_0/x_aq_core
#
# Optional overrides:
#   FSDB=/path/to/csr.fsdb RC_ROOT=/path/to/rc verdi -batch -play ...

proc usage {} {
  puts "Usage:"
  puts "  verdi -batch -play [info script] <module_name> <module_path>"
  puts ""
  puts "Example:"
  puts "  verdi -batch -play [info script] cp0 /tb/x_soc/x_cpu_sub_system_axi/x_c906_wrapper/x_cpu_top/x_aq_top_0/x_aq_core/x_aq_cp0_top"
}

proc get_script_args {} {
  if {[info exists ::argv]} {
    return $::argv
  }

  set cmdline_file "/proc/[pid]/cmdline"
  if {![file exists $cmdline_file]} {
    return {}
  }

  set fh [open $cmdline_file r]
  set cmdline [read $fh]
  close $fh

  set words [lrange [split $cmdline "\x00"] 0 end-1]
  set script_name [info script]
  set script_norm [file normalize $script_name]

  for {set i 0} {$i < [llength $words]} {incr i} {
    set word [lindex $words $i]
    if {$word eq $script_name} {
      return [lrange $words [expr {$i + 1}] end]
    }
    if {![catch {file normalize $word} word_norm] && $word_norm eq $script_norm} {
      return [lrange $words [expr {$i + 1}] end]
    }
  }

  return {}
}

proc getenv_or_default {name default_value} {
  if {[info exists ::env($name)] && $::env($name) ne ""} {
    return $::env($name)
  }
  return $default_value
}

proc add_signals {win inst signal_types} {
  wvAddSignal -win $win -clear
  wvAddSignal -win $win -scope $inst -type {*}$signal_types
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

proc get_add_signal_key {line current_scope_var} {
  upvar $current_scope_var current_scope

  if {![string match "addSignal *" $line]} {
    return ""
  }
  if {[catch {llength $line}]} {
    return ""
  }

  set signal [lindex $line end]
  if {$signal eq ""} {
    return ""
  }

  if {[lsearch -exact $line "-holdScope"] >= 0} {
    if {$current_scope eq ""} {
      return $signal
    }
    return "${current_scope}/${signal}"
  }

  if {[string match "/*" $signal]} {
    set current_scope [file dirname $signal]
  }
  return $signal
}

proc read_rc_signal_set {rc_file} {
  set signals [dict create]
  set current_scope ""

  set fh [open $rc_file r]
  while {[gets $fh line] >= 0} {
    set signal_key [get_add_signal_key $line current_scope]
    if {$signal_key ne ""} {
      dict set signals $signal_key 1
    }
  }
  close $fh

  return $signals
}

proc expand_hold_scope_signal {line signal_key} {
  if {[lsearch -exact $line "-holdScope"] < 0} {
    return $line
  }

  set tokens $line
  set hold_scope_index [lsearch -exact $tokens "-holdScope"]
  set tokens [lreplace $tokens $hold_scope_index $hold_scope_index]
  lset tokens end $signal_key
  return [join $tokens " "]
}

proc create_internal_rc {all_rc input_rc output_rc internal_rc} {
  set exclude_signals [dict create]

  foreach rc_file [list $input_rc $output_rc] {
    dict for {signal_key _} [read_rc_signal_set $rc_file] {
      dict set exclude_signals $signal_key 1
    }
  }

  set in_fh [open $all_rc r]
  set out_fh [open $internal_rc w]
  set current_scope ""

  while {[gets $in_fh line] >= 0} {
    set signal_key [get_add_signal_key $line current_scope]
    if {$signal_key ne "" && [dict exists $exclude_signals $signal_key]} {
      continue
    }
    if {$signal_key ne ""} {
      set line [expand_hold_scope_signal $line $signal_key]
    }
    puts $out_fh $line
  }

  close $in_fh
  close $out_fh
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../../../..]]
set default_fsdb [file join $repo_root regress/regress_result/csr.fsdb]
set default_rc_root [file normalize [file join $script_dir ../rc]]

set fsdb [file normalize [getenv_or_default FSDB $default_fsdb]]
set rc_root [file normalize [getenv_or_default RC_ROOT $default_rc_root]]

set script_args [get_script_args]

if {[llength $script_args] != 2} {
  usage
  error "expected <module_name> <module_path>"
}

lassign $script_args module_name module_path

if {![file exists $fsdb]} {
  error "FSDB not found: $fsdb"
}

puts "INFO: FSDB=$fsdb"
puts "INFO: RC_ROOT=$rc_root"
puts "INFO: MODULE_NAME=$module_name"
puts "INFO: MODULE_PATH=$module_path"

set wave_win [wvCreateWindow]
wvOpenFile -win $wave_win $fsdb

set out_dir [file join $rc_root $module_name]
file mkdir $out_dir

set signal_specs [list \
  [list [list input] input "input ports"] \
  [list [list output] output "output ports"] \
  [list [list input output inout net register other] all "all top-level signals"] \
]

foreach signal_spec $signal_specs {
  lassign $signal_spec signal_types rc_suffix description

  set out_rc [file join $out_dir "${module_name}_${rc_suffix}.rc"]
  set rc_paths($rc_suffix) $out_rc

  puts "INFO: extracting $description for $module_path"
  add_signals $wave_win $module_path $signal_types
  save_signal_rc $wave_win $out_rc
  puts "INFO: wrote $out_rc"
}

set internal_rc [file join $out_dir "${module_name}_internal.rc"]
puts "INFO: deriving internal signals from all - input - output"
create_internal_rc $rc_paths(all) $rc_paths(input) $rc_paths(output) $internal_rc
puts "INFO: wrote $internal_rc"

debExit
