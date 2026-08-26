#!/usr/bin/env bash
# Run each ifu_random operation group in isolation under Verilator and report
# PASS/FAIL per group. This is the bring-up and bisect harness: a group that
# hangs the core shows up here immediately instead of somewhere in a 10k-
# iteration run.
#
# Usage (from smart_run/):
#   bash tests/cases/ifu_random/run_groups.sh [first] [last] [iters] [arena_seed]
#
# Requires the design to have been verilated once already:
#   make compile CASE=ifu_random SIM=verilator DUMP=off
#
# The fourth argument re-seeds the CODE LAYOUT rather than the data, so the same
# group can be re-run against a different program:
#   bash tests/cases/ifu_random/run_groups.sh 20 20 40 0xC0FFEE
#
# Groups 19 (sv39_ifetch) and 41 (jit) are compiled out by default, so this
# script adds their -D gate automatically when it reaches them. Group 19's
# fault sub-case additionally needs -DIFU_MMU_FAULT and is left off even here:
# it is expected to cost the run.
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
ARENA_SEED=${4:-}
# 8 ms of simulated time is generous for 40 iterations of every group except 8
# (the 48 KB sled, which is internally sparsed to 1 visit in 32), but small
# enough that a livelock -- which retires instructions, so the testbench's
# 50,000-cycle no-retire watchdog never fires -- is caught in seconds rather
# than hours.
SIMTIME=${SIMTIME:-8e6}

NAMES=(redirect_prio buf_chgflw high_pc reissue lpmd_kill ibuf_full_kill \
       iway_pred set_conflict walk utlb_wfpa refill_abort prefetch \
       noncacheable inv_all inv_pa inv_va_err mcins_readout ifetch_accfault \
       expt_high sv39_ifetch btb_fill16 btb_mispred_clr btb_alias_64k \
       btb_inv_en bht_lfsr_history bht_repair_fsm bht_bypass \
       bht_vghr_restore bht_inv_en ras_depth ras_unbalanced ras_ret_stall \
       ras_16m ras_en_off delay_branch two_branch_group straddle_2mod4 \
       ipack_shapes ibuf_rotate enable_mix no_op_fence jit)

cd "$REPO"
for g in $(seq "$FIRST" "$LAST"); do
    name=${NAMES[$g]:-group$g}
    extra="-DIFU_ONLY_GROUP=$g"
    case $g in
        19) extra="$extra -DIFU_MMU" ;;
        41) extra="$extra -DIFU_JIT" ;;
    esac

    args=(CASE=ifu_random IFU_ITERS="$ITERS" IFU_EXTRA="$extra")
    [ -n "$ARENA_SEED" ] && args+=(IFU_ARENA_SEED="$ARENA_SEED")

    make buildcase "${args[@]}" >/dev/null 2>&1
    if [ ! -f work/inst.pat ]; then
        printf '%2d %-18s BUILD-FAIL\n' "$g" "$name"
        # A layout violation is reported by gen_ifu_arena.py --check and an
        # arena mis-pin by the linker script's ASSERT, so both show up here.
        grep -E 'error|Error|CHECK FAILED|ASSERT' work/ifu_random_build.case.log \
            2>/dev/null | head -5
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
