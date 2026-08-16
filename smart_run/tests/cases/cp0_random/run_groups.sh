#!/usr/bin/env bash
# Run each cp0_random operation group in isolation under Verilator and report
# PASS/FAIL per group. This is the bring-up and bisect harness: a group that
# hangs the core shows up here immediately instead of somewhere in a 100k-
# iteration run.
#
# Usage (from smart_run/):
#   bash tests/cases/cp0_random/run_groups.sh [first] [last] [iters]
#
# Requires the design to have been verilated once already:
#   make compile CASE=cp0_random SIM=verilator DUMP=off
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
# 4 ms of simulated time is ~50x what 40 iterations of the slowest group needs,
# but small enough that a livelock (which retires instructions, so the retire
# watchdog never fires) is caught in seconds rather than hours.
SIMTIME=${SIMTIME:-4e6}

NAMES=(safe_rw imm_forms no_write read_only ro_zero trap_illegal vector_ill \
       legal_hole mcpuid mip_rmw mhcr mhint mhint2 mxstatus theadisaee_off \
       sxstatus mcor mcins cache_cp0 cache_va fence wfi ecall_ebreak illegal \
       debug_csrs fault tvec vectored smode umode delegate int_soft \
       int_deleg int_external int_hpm hpcp cnt_policy pmp mmu_tlb satp \
       mprv float)

cd "$REPO"
for g in $(seq "$FIRST" "$LAST"); do
    name=${NAMES[$g]:-group$g}
    make buildcase CASE=cp0_random CP0_ITERS="$ITERS" \
         CP0_EXTRA="-DCP0_ONLY_GROUP=$g" >/dev/null 2>&1
    if [ ! -f work/inst.pat ]; then
        printf '%2d %-16s BUILD-FAIL\n' "$g" "$name"
        grep -E 'error|Error' work/cp0_random_build.case.log 2>/dev/null | head -5
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
    printf '%2d %-16s %s\n' "$g" "$name" "$res"
done
