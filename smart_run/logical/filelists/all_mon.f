// All five per-unit port-toggle monitors, plus their guard macros.
//
// Selected with MON=all (see setup/smart_cfg.mk), which overrides the per-case
// monitor filelist. This lets *any* case be measured against every pipeline
// unit at once -- the reference measurement for the randomized stress tests is
//
//   make runcase CASE=coremark SIM=verilator DUMP=off MON=all COVERAGE=line
//
// which produces the "what a real workload already reaches" baseline that the
// random cases are scored against. Without it, "97/115 IFU ports toggled" is a
// number with nothing to compare it to.
//
// Paths are relative to smart_run/work, the cwd of every simulator run.
// Not usable with SIM=iverilog: its -c filelists take filenames only, not
// options, so the +define+ lines below are rejected.
//
// Cost note: this samples ~600 ports every posedge. Use it for measurement
// runs, not for long soaks.
+define+CP0_TOGGLE_MON
+define+IU_TOGGLE_MON
+define+VIDU_TOGGLE_MON
+define+IDU_TOGGLE_MON
+define+IFU_TOGGLE_MON
../tests/cases/cp0_random/cp0_toggle_mon.v
../tests/cases/iu_random/iu_toggle_mon.v
../tests/cases/vidu_random/vidu_toggle_mon.v
../tests/cases/idu_random/idu_toggle_mon.v
../tests/cases/ifu_random/ifu_toggle_mon.v
