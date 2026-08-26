// Extra compile options + files for the vidu_random case.
// Pulled in via SIM_FILELIST from setup/smart_cfg.mk. Paths are relative to
// smart_run/work, which is the cwd of every simulator invocation.
//
// Enabling VIDU_TOGGLE_MON both compiles the monitor module (the whole file is
// inside the `ifdef) and makes tb.v instantiate it.
+define+VIDU_TOGGLE_MON
../tests/cases/vidu_random/vidu_toggle_mon.v
