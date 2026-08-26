// Extra compile options + files for the ifu_random case.
// Pulled in via SIM_FILELIST from setup/smart_cfg.mk. Paths are relative to
// smart_run/work, which is the cwd of every simulator invocation.
//
// Enabling IFU_TOGGLE_MON both compiles the monitor module (the whole file is
// inside the `ifdef) and makes tb.v instantiate it.
+define+IFU_TOGGLE_MON
../tests/cases/ifu_random/ifu_toggle_mon.v
