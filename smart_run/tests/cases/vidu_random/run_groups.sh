#!/usr/bin/env bash
# Run each vidu_random operation group in isolation under Verilator and report
# PASS/FAIL per group. This is the bring-up and bisect harness: a group that
# hangs the core shows up here immediately instead of somewhere in a 20k-
# iteration run.
#
# Usage (from smart_run/):
#   bash tests/cases/vidu_random/run_groups.sh [first] [last] [iters]
#
# Requires the design to have been verilated once already:
#   make compile CASE=vidu_random SIM=verilator DUMP=off
#
# Groups worth watching during bring-up:
#   25 frm_dynamic  leaves frm at 5..7 if its restore is ever skipped, which is
#                   a trap storm -- and a trap storm RETIRES, so the testbench's
#                   no-retire watchdog never fires. Only the simulation time
#                   limit catches it, which is why SIMTIME below is deliberately
#                   short.
#   32 fs_off       runs three instructions with mstatus.FS == Off. Recoverable
#                   only because the trap handler contains no FP instruction.
#   39 fp_lowpower  executes WFI. Unrecoverable short of reset if the wake
#                   source is not armed.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # -> smart_run
export CODE_BASE_PATH="$(cd "$REPO/.." && pwd)/C906_RTL_FACTORY"
export TOOL_EXTENSION="${TOOL_EXTENSION:-$HOME/tools/riscv-wrap}"
export CONVERT="${CONVERT:-python3 $REPO/tests/bin/srec2vmem.py}"
export THEAD_GCC="${THEAD_GCC:-0}"
export PATH="$HOME/.local/bin:$HOME/homebrew/bin:$TOOL_EXTENSION:$PATH"

FIRST=${1:-0}
LAST=${2:-41}
ITERS=${3:-40}
# 4 ms of simulated time is far more than 40 iterations of the slowest group
# needs (group 8 sweeps all 32 FP registers twice, group 14 does 192 cold
# memory ops), but small enough that a livelock -- which retires instructions,
# so the retire watchdog never fires -- is caught in seconds rather than hours.
SIMTIME=${SIMTIME:-4e6}

NAMES=(raw_src0 raw_src1 raw_src2 fwd_except fwd_except_vlsu \
       store_src2_except waw waw_except_2fld wbt_all_regs split_skid \
       fp_full fpload_dual_full vex1_stall wb_priority flsu_std flsu_c \
       flsu_xtheadc arith_short arith_fma arith_long cvt cmp_class \
       sgnj_minmax fmv frm_static frm_dynamic rm_illegal fflags fs_dirty \
       flush_wbt int_fp_mix fld_burst fs_off regfile_walk denorm nan_prop \
       h_precision fp_traps fsd_data_dep fp_lowpower fcsr_csr_forms \
       report_probe)

cd "$REPO"
for g in $(seq "$FIRST" "$LAST"); do
    name=${NAMES[$g]:-group$g}
    make buildcase CASE=vidu_random VIDU_ITERS="$ITERS" \
         VIDU_EXTRA="-DVIDU_ONLY_GROUP=$g" >/dev/null 2>&1
    if [ ! -f work/inst.pat ]; then
        printf '%2d %-18s BUILD-FAIL\n' "$g" "$name"
        grep -E 'error|Error' work/vidu_random_build.case.log 2>/dev/null | head -5
        continue
    fi
    out=$(cd work && ./simv "+MAX_SIM_TIME=$SIMTIME" 2>&1)
    if echo "$out" | grep -q 'finished successfully'; then
        res=PASS
    elif echo "$out" | grep -q 'no instructions retired'; then
        res='HANG (retire watchdog)'
    elif echo "$out" | grep -q 'meeting max simulation time'; then
        res='TIMEOUT'
    else
        res='FAIL'
    fi
    printf '%2d %-18s %s\n' "$g" "$name" "$res"
done
