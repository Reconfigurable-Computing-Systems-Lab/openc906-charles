#!/bin/bash
# Debug helper: build a model case with a given -D flag set and run it, print report.
# usage: probe_case.sh <CASE> "<extra cflags>" [MAX_SIM_TIME]
set -e
export CODE_BASE_PATH=/Users/jingbo.jiang/Documents/GitHub/openc906-charles/C906_RTL_FACTORY
export TOOL_EXTENSION=$HOME/tools/riscv-wrap
export CONVERT="python3 /Users/jingbo.jiang/Documents/GitHub/openc906-charles/smart_run/tests/bin/srec2vmem.py"
export THEAD_GCC=0
CASE=$1; XCF="$2"; MST=${3:-3000000000.0}
cd /Users/jingbo.jiang/Documents/GitHub/openc906-charles/smart_run
D=work_probe
mkdir -p $D
# build case with extra cflags injected via PROBE_CFLAGS
make -s buildcase CASE=$CASE PROBE_CFLAGS="$XCF" >/dev/null 2>&1 || { echo BUILD_FAIL; tail -5 work/${CASE}_build.case.log; exit 1; }
cp -f work/obj_dir/simv $D/simv 2>/dev/null || cp -f work/simv $D/simv
cp work/inst.pat work/data.pat work/input.pat $D/
cd $D && rm -f run_case.report
./simv +MAX_SIM_TIME=$MST 2>&1 | grep -aiE "TEST|out |argmax|MISMATCH| ok|finish at|Error|\[[A-F]\]" | grep -avE "Wipe|Init|Read|Load" | tail -15
echo -n "REPORT: "; cat run_case.report 2>/dev/null; echo
