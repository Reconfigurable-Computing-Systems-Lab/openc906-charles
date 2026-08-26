#!/usr/bin/env bash
# Run each iu_random operation group in isolation under Verilator and report
# PASS/FAIL per group. This is the bring-up and bisect harness: a group that
# hangs the core shows up here immediately instead of somewhere in a 20k-
# iteration run.
#
# Usage (from smart_run/):
#   bash tests/cases/iu_random/run_groups.sh [first] [last] [iters]
#
# Requires the design to have been verilated once already:
#   make compile CASE=iu_random SIM=verilator DUMP=off
#
# Group 40 (jump8m) is compiled out unless IU_ENABLE_JUMP8M is set, so by
# default it runs as a no-op and reports PASS. To actually exercise it:
#   IU_EXTRA_BASE=-DIU_ENABLE_JUMP8M bash tests/cases/iu_random/run_groups.sh 40 40
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # -> smart_run
export CODE_BASE_PATH="$(cd "$REPO/.." && pwd)/C906_RTL_FACTORY"
export TOOL_EXTENSION="${TOOL_EXTENSION:-$HOME/tools/riscv-wrap}"
export CONVERT="${CONVERT:-python3 $REPO/tests/bin/srec2vmem.py}"
export THEAD_GCC="${THEAD_GCC:-0}"
export PATH="$HOME/.local/bin:$HOME/homebrew/bin:$TOOL_EXTENSION:$PATH"

FIRST=${1:-0}
LAST=${2:-43}
ITERS=${3:-40}
IU_EXTRA_BASE=${IU_EXTRA_BASE:-}
# 8 ms of simulated time is well over what 40 iterations of the slowest group
# (div_ff1, ~26 divisions per dispatch, plus the 64-instruction immediate
# sweeps) needs, but small enough that a livelock is caught in seconds rather
# than hours. Deliberately short: a *stall* trips the testbench's
# 50,000-cycle no-retire watchdog on its own, but a livelock retires
# instructions the whole time and is only ever caught by this limit.
SIMTIME=${SIMTIME:-8e6}

NAMES=(add_sub cmp addsl shift_reg shift_imm srri ext extu logic ff tst \
       tstnbz rev mov br_cond br_mispred br_ldep jal_jalr auipc \
       mul_nosplit mul_split mul_acc div_normal div_ff1 div_special \
       div_buffer div_wb fwd_alu fwd_lsu fwd_mul fwd_bju c_ext \
       mul_flush div_flush mul_div_mix br_dense ras_deep word_bound \
       x0_fwd hpcp jump8m traps stress_mix report_probe)

cd "$REPO"
for g in $(seq "$FIRST" "$LAST"); do
    name=${NAMES[$g]:-group$g}
    make buildcase CASE=iu_random IU_ITERS="$ITERS" \
         IU_EXTRA="-DIU_ONLY_GROUP=$g $IU_EXTRA_BASE" >/dev/null 2>&1
    if [ ! -f work/inst.pat ]; then
        printf '%2d %-14s BUILD-FAIL\n' "$g" "$name"
        grep -E 'error|Error' work/iu_random_build.case.log 2>/dev/null | head -5
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
    printf '%2d %-14s %s\n' "$g" "$name" "$res"
done
