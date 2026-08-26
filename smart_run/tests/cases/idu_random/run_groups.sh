#!/usr/bin/env bash
# Run each idu_random operation group in isolation under Verilator and report
# PASS/FAIL per group. This is the bring-up and bisect harness: a group that
# hangs the core shows up here immediately instead of somewhere in a 20k-
# iteration run.
#
# Usage (from smart_run/):
#   bash tests/cases/idu_random/run_groups.sh [first] [last] [iters]
#
# Requires the design to have been verilated once already:
#   make compile CASE=idu_random SIM=verilator DUMP=off
#
# Groups 0..31 are the main rotation and 32..45 the sparse selector; -DIDU_ONLY_
# GROUP reaches all 46 the same way. Group 45 (zvamo_negative) issues an AMO
# opcode with funct3 110/111; it turns out to be a plain illegal instruction
# rather than a dispatch to the absent vector unit, so it runs by default. Pass
# IDU_EXTRA=-DIDU_NO_ZVAMO to compile it out again.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # -> smart_run
export CODE_BASE_PATH="$(cd "$REPO/.." && pwd)/C906_RTL_FACTORY"
export TOOL_EXTENSION="${TOOL_EXTENSION:-$HOME/tools/riscv-wrap}"
export CONVERT="${CONVERT:-python3 $REPO/tests/bin/srec2vmem.py}"
export THEAD_GCC="${THEAD_GCC:-0}"
export PATH="$HOME/.local/bin:$HOME/homebrew/bin:$TOOL_EXTENSION:$PATH"

FIRST=${1:-0}
LAST=${2:-45}
ITERS=${3:-40}
# 4 ms of simulated time is ~50x what 40 iterations of the slowest group needs,
# but small enough that a livelock (which retires instructions, so the retire
# watchdog never fires) is caught in seconds rather than hours. The dangerous
# groups here are 6 (an illegal frm makes every dynamic-rounding FP op trap),
# 19/20 (cracked instructions interrupted mid-crack) and 45 (an encoding whose
# uop names a unit that does not exist), and all three fail by livelock rather
# than by stalling.
#
# Measured 2026-08-26, Verilator 5.048, 40 iterations, -O2: all 46 groups PASS,
# every group finishes inside 55 us of simulated time. Traps seen per group:
#   0 c.ebreak -> 3;      2 ecall/ebreak/illegal -> 11,3,2;  6/7/9/17 -> 2
#   19 misaligned -> 4;   21/29 ecall from U/S -> 8,9;  39 -> 1 (access) + 2
SIMTIME=${SIMTIME:-4e6}

NAMES=(rvc_table base32_alu base32_ls_sys fp_table_sd fp_table_h fma_table \
       fp_rm fs_zero cache_sync_table theadisaee_off xtheadc_alu xtheadc_bits \
       xtheadc_mac xtheadc_lr xtheadc_idxupd xtheadc_stores xtheadc_fp \
       rvv_illegal lsd_split lsd_interrupted amo_matrix che_split fnc_split \
       imm_src1_sweep imm_src2_sweep regidx_sweep illegal_reserved \
       illegal_xtheadc c_illegal priv_cacheops raw_alu_bju raw_load_condbr \
       raw_fwd_bus raw_src2_store waw_cnt2 waw_dst1 wb_same_reg late_forward \
       fp_dep_stall expt_priority expt_override_cp0 ex1_eu_full \
       pipe_sel_cross dis_stall_compose hpcp_class zvamo_negative)

cd "$REPO"
for g in $(seq "$FIRST" "$LAST"); do
    name=${NAMES[$g]:-group$g}
    make buildcase CASE=idu_random IDU_ITERS="$ITERS" \
         IDU_EXTRA="-DIDU_ONLY_GROUP=$g" >/dev/null 2>&1
    if [ ! -f work/inst.pat ]; then
        printf '%2d %-18s BUILD-FAIL\n' "$g" "$name"
        grep -E 'error|Error' work/idu_random_build.case.log 2>/dev/null | head -5
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
