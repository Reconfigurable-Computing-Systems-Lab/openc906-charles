/*
 * vidu_random -- randomized stress test for the OpenC906 VIDU.
 *
 * VIDU IS THE SCALAR FP ISSUE UNIT. Despite the directory name there is no
 * vector logic in this release: every *_vec submodule in aq_vidu_top.v:416-454
 * is a commented-out `&Instance`, the *_vec.v files do not exist, and :455-473
 * is a "Vector Dummy" block that ties the whole vector interface off. On the
 * decode side decd_sel[5] = 1'b0 (aq_idu_id_decd.v:1011), so every RVV encoding
 * traps illegal, and mstatus.VS, vl and misa.V are hardwired zero. What is left
 * -- and what this test exercises -- is the five-module scalar FP issue
 * pipeline:
 *
 *   aq_vidu_vid_split_fp.v   one-entry skid buffer + its two-state FSM
 *   aq_vidu_vid_ctrl_fp.v    RAW / WAW dependency stalls and their exceptions
 *   aq_vidu_vid_dp_fp.v      operand select, forwarding, srcf2 readiness
 *   aq_vidu_vid_gpr_fp.v     32 x 64b FP register file, three read ports
 *   aq_vidu_vid_wbt.v        32-entry FP writeback scoreboard
 *
 * The build is c906fd. c906fdv must NEVER be used: GCC emits RVV 1.0 and this
 * RTL is RVV 0.7.1, so a vector build produces instructions the core cannot
 * decode and stimulates nothing.
 *
 * WHAT THIS TEST IS NOT. There is deliberately no golden model, no self-check
 * and no expected-value comparison anywhere in this file. PASS means the
 * program ran to completion (main returns -> crt0.s __exit -> the magic value
 * the testbench watches the RTU writeback buses for). Every arithmetic result
 * is folded into rand_sink for one reason only -- so the compiler cannot delete
 * the instruction under test -- and rand_sink is printed at the end purely as a
 * fingerprint. It is NOT compared against anything, here or anywhere else. The
 * evidence that VIDU was stimulated is the port-toggle report, plus the
 * per-group hit counts and the trap-cause histogram this file prints.
 *
 * WHY IT IS NOT REDUNDANT WITH ISA/ISA_FP. C906_FPU_SMOKE.s (3886 lines)
 * already covers the FP *operation matrix* and the static rounding modes, so
 * this test does not try to. What it does cover is the issue machinery and the
 * register and latency space that a straight-line op-matrix test cannot reach:
 * FPU_SMOKE uses only 17 of the 32 FP registers (f13, f16-f19 and f22-f31 never
 * appear), has zero flw/fsw, zero compressed FP loads or stores and zero
 * Xtheadc indexed FP forms, and it never constructs a dependency distance on
 * purpose.
 *
 * KNOWN-UNREACHABLE IN THIS CONFIGURATION -- not targeted, on purpose:
 *   - the nine ctrl_dp_fgpr_reuse_inst_dp_vld mux arms in
 *     aq_vidu_vid_dp_fp.v:242-266 and the reuse arm of dp_wb_inst_type
 *     (:295-296): the select is tied to 1'b0 at aq_vidu_top.v:461
 *   - the reuse terms of aq_vidu_vid_ctrl_fp.v:236-240, same reason
 *   - the vec_sel halves of vpu_rtu_ex1_cmplt / _cmplt_dp
 *     (aq_vidu_vid_ctrl_fp.v:174-184) and the split_vec0/1_ctrl_entry_vld terms
 *     of vidu_idu_fp_full / ctrl_vidu_no_op (:205-211): tied off at
 *     aq_vidu_top.v:470-471
 *   - wbt_ctrl_fp_srcvm_info (aq_vidu_vid_ctrl_fp.v:243), the vector mask read
 *     port
 *   - scoreboard cnt == 2: cnt is one bit (aq_vidu_vid_wbt_entry.v:44, comment
 *     :103-104), so two outstanding producers per FP register is the ceiling
 *   - simultaneous wbt wb0_vld + wb1_vld: mutually exclusive by construction
 *     (aq_vpu_fwd_wb_rbus.v:462, :500)
 *   - viq1_xx_ex1_stall, tied to 1'b0 at aq_vpu_fwd_wb_rbus.v:543, which leaves
 *     only two of the three terms of vpu_vidu_vex1_fp_stall live
 *   - anything requiring RVV. cp0_random group 6 already covers the
 *     RVV-illegal trap; duplicating it here would buy nothing.
 *
 * Robustness is the design constraint. Every group that perturbs persistent
 * state (frm, fflags, fxcr, mstatus.FS) saves and restores it masked to the
 * writable bits, rand_restore_sane_state() re-baselines everything every 4096
 * iterations, and the shared trap handler unwinds to the loop head on any
 * nested or unexpected trap -- so a group that goes wrong costs one iteration,
 * not the run.
 */

#include "rand_common.h"
#include "vidu_defs.h"

#ifndef VIDU_ITERS
#define VIDU_ITERS 20000
#endif
#ifndef VIDU_SEED
#define VIDU_SEED 0x2024C906
#endif

/* Groups 0..NGROUPS-1 are the main rotation; NGROUPS..NGROUPS_TOTAL-1 ride the
 * sparse second selector (and are individually reachable via
 * -DVIDU_ONLY_GROUP=n). */
#define NGROUPS       32
#define NGROUPS_TOTAL 42

/* ==================================================================== *
 * BIT BUDGET OF THE RANDOM WORD -- read this before adding a group.
 *
 * Every group is handed the same 64-bit PRNG output `r`, and the main-rotation
 * group index is r % NGROUPS, i.e. bits [4:0]. That makes bits [4:0] CONSTANT
 * for the whole lifetime of a group: inside g_foo(), r & 31 is always the same
 * number. A sub-case selector that reads any of them therefore does not select
 * anything -- it just picks one arm and pins it there for the entire run, which
 * looks exactly like working code and covers a fraction of what it claims.
 * (Concretely: `(r >> 3) & 3` is bits [4:3], so it is a compile-time constant
 * per group -- one arm out of four, forever. `(r >> 3) % 6` has its low two bits
 * fixed, so it reaches three of six arms.)
 *
 * Fields, all disjoint, all clear of [4:0]:
 *
 *   [4:0]    main-rotation group index        r % NGROUPS
 *   [36:5]   per-group sub-case selector      (unsigned)(r >> 5) & / %  ...
 *   [30:5]   FP operand pool indices          vidu_operands(), 3 bits per slot
 *   [36:32]  which FP register the sweeps use VIDU_FP_SWITCH(r >> 32, ...)
 *   [45:40]  arena base offset                vidu_base()
 *   [53:48]  sparse-group selector            (r >> 48) % 64, arms 0..9
 *
 * The sub-case window and the FP-register window overlap in [36:32] for the
 * modulo selectors; that is harmless because no group uses both. What is NOT
 * harmless is touching [4:0], and that is the mistake this comment exists to
 * prevent. Groups 16, 19 and 25 need more than one choice each and carve extra
 * disjoint fields out of [20:5]; each one lists its own layout locally.
 * ==================================================================== */

/* ==================================================================== *
 * State
 * ==================================================================== */
/* The arena every FP load, store and indexed address in this file points at.
 * 2560 bytes of .bss, 64-byte (one D-cache line) aligned, inside the SRAM
 * window tb.v:98 wipes and loads -- so nothing here can read X under VCS. The
 * size is set by the largest reach of any single sweep: group 16's Xtheadc
 * indexed forms use base + (248 << 3) + 8 = 1992 bytes from arena[0], and
 * vidu_sweep_flsu_std() reaches 702 bytes past a base that vidu_base() places
 * as high as arena[63]. */
#define VIDU_ARENA_N 320
static volatile u64 vidu_arena[VIDU_ARENA_N] __attribute__((aligned(64)));

/* Which FP registers the runtime register switches actually selected. Read by
 * VIDU_FP_SWITCH() in vidu_defs.h, printed at the end: with no golden model
 * this bitmask is the only evidence that the sweeps reached the whole register
 * file rather than the low eight. The .S sweeps are exhaustive by construction
 * and are deliberately NOT folded in, so that this stays a statement about the
 * randomised path only. */
static volatile u64 vidu_regs_touched;

static volatile u64 group_hits[NGROUPS_TOTAL];
static volatile u64 vidu_flags_seen;    /* OR of every fflags value read back */
static volatile u64 vidu_fs_seen;       /* OR of every mstatus.FS read back   */
static volatile u64 vidu_rm_illegal;    /* static rm 101/110 probes issued    */
static volatile u64 vidu_frm_illegal;   /* dynamic-rm probes with frm in 5..7 */
static volatile u64 vidu_fsoff_probes;  /* probes issued with FS == Off       */
static volatile u64 vidu_wfi;           /* WFIs with FP work in flight        */

/* mstatus.FS, written as the field rather than through rand_csrs.h's
 * MSTATUS_FS_CLEAN -- that macro is 0x2000, i.e. FS == 01 (Initial), the same
 * value as MSTATUS_FS_INIT, so it cannot express Clean. */
#define VIDU_FS_OFF    (0UL << 13)
#define VIDU_FS_INIT   (1UL << 13)
#define VIDU_FS_CLEAN  (2UL << 13)
#define VIDU_FS_DIRTY  (3UL << 13)

/* ==================================================================== *
 * Operand staging
 *
 * Every group that needs FP inputs stages eight pool entries into the head of
 * the arena and loads them with fld, rather than materialising constants. Two
 * reasons: a C `double` literal would make GCC allocate an FP register and emit
 * its own load, which is stimulus this file did not choose; and going through
 * memory is what creates the WB_VEC_TYPE_VLSU scoreboard entries that half the
 * dependency groups below depend on existing.
 *
 * The + 5u is load-bearing. Slot i draws its pool index from bits
 * [3i+9 : 3i+5], so slot 0 takes [9:5] rather than [4:0]. Without the offset
 * slot 0's index would be r & 31, i.e. the group number -- every group would see
 * the same single constant in vidu_arena[0] on every hit, and arena[0] is the
 * operand the majority of the groups below load into ft0.
 * ==================================================================== */
static const volatile u64 *vidu_operands(u64 r)
{
    unsigned i;

    for (i = 0; i < 8u; i++)
        vidu_arena[i] = vidu_fp_pool[(unsigned)(r >> (3u * i + 5u)) & 31u];
    return &vidu_arena[0];
}

/* An 8-byte-aligned base inside the arena. Capped at arena[63] so that the
 * largest offset any sweep uses still lands inside the array; this is also what
 * gives the .S sweeps their randomness, since they take no other input. */
static volatile u64 *vidu_base(u64 r)
{
    return &vidu_arena[(unsigned)(r >> 40) & 63u];
}

/* ==================================================================== *
 * Group 0-2: raw_src0 / raw_src1 / raw_src2
 *
 * ctrl_dis_srcf{0,1,2}_raw (aq_vidu_vid_ctrl_fp.v:256-264) feeding
 * ctrl_dis_fp_dep_stall (:220-221). Each of the three source ports gets its own
 * group because they are three separate comparator chains reading three
 * separate scoreboard ports, and because srcf2 exists only on FMA and FP
 * stores.
 *
 * The producer register is the one the RNG picked, out of all 32
 * (VIDU_FP_SWITCH); the arm then walks the three scoreboard flavours -- falu
 * (WB_VEC_TYPE 0, EX3 writeback), vfdsu (long latency) and VLSU (type
 * WB_VEC_TYPE_VLSU with cnt 0) -- at distances 1, 2, 3 and 4. One asm block per
 * arm, because the whole point is the distance in instructions and only a
 * single block guarantees the compiler cannot insert anything into the gap.
 *
 * These macros close over `p`, the staged-operand pointer, as asm operand %0.
 * ==================================================================== */
#define VIDU_RAW0(F) __asm__ volatile (                                       \
        "fadd.d  " #F ", ft0, ft1\n\t"                                        \
        "fmul.d  ft2, " #F ", ft1\n\t"          /* falu producer, distance 1 */\
        "fdiv.d  " #F ", ft0, ft1\n\t"                                        \
        VIDU_GAP(1)                                                           \
        "fmul.s  ft3, " #F ", ft1\n\t"          /* vfdsu producer, distance 2*/\
        "fld     " #F ", 0(%0)\n\t"                                           \
        VIDU_GAP(2)                                                           \
        "fmul.h  ft4, " #F ", ft1\n\t"          /* VLSU producer, distance 3 */\
        "fmadd.d " #F ", ft0, ft1, ft2\n\t"                                   \
        VIDU_GAP(3)                                                           \
        "fadd.d  ft5, " #F ", ft1"              /* vfmau producer, distance 4*/\
        :: "r"(p) : VIDU_FCLOB, "memory")

#define VIDU_RAW1(F) __asm__ volatile (                                       \
        "fadd.d  " #F ", ft0, ft1\n\t"                                        \
        "fmul.d  ft2, ft1, " #F "\n\t"                                        \
        "fdiv.d  " #F ", ft0, ft1\n\t"                                        \
        VIDU_GAP(1)                                                           \
        "fmul.s  ft3, ft1, " #F "\n\t"                                        \
        "fld     " #F ", 8(%0)\n\t"                                           \
        VIDU_GAP(2)                                                           \
        "fmul.h  ft4, ft1, " #F "\n\t"                                        \
        "fmadd.d " #F ", ft0, ft1, ft2\n\t"                                   \
        VIDU_GAP(3)                                                           \
        "fadd.d  ft5, ft1, " #F                                               \
        :: "r"(p) : VIDU_FCLOB, "memory")

/* srcf2 is rs3 of an FMA or the data register of an FP store -- there is no
 * other way to drive it. */
#define VIDU_RAW2(F) __asm__ volatile (                                       \
        "fadd.d  " #F ", ft0, ft1\n\t"                                        \
        "fmadd.d ft2, ft0, ft1, " #F "\n\t"                                   \
        "fdiv.d  " #F ", ft0, ft1\n\t"                                        \
        VIDU_GAP(1)                                                           \
        "fmsub.s ft3, ft0, ft1, " #F "\n\t"                                   \
        "fld     " #F ", 16(%0)\n\t"                                          \
        VIDU_GAP(2)                                                           \
        "fnmadd.h ft4, ft0, ft1, " #F "\n\t"                                  \
        "fmadd.d " #F ", ft0, ft1, ft2\n\t"                                   \
        VIDU_GAP(3)                                                           \
        "fnmsub.d ft5, ft0, ft1, " #F                                         \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_raw_src0(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    VIDU_FP_SWITCH(r >> 32, VIDU_RAW0);
}

static void g_raw_src1(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    VIDU_FP_SWITCH(r >> 32, VIDU_RAW1);
}

static void g_raw_src2(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    VIDU_FP_SWITCH(r >> 32, VIDU_RAW2);
}

/* ==================================================================== *
 * Group 3: fwd_except
 *
 * The forwarding-exception terms of ctrl_dis_srcf{0,1,2}_raw_except
 * (aq_vidu_vid_ctrl_fp.v:275-296). Their source is
 *
 *     vpu_vidu_fp_fwd_vld = |fpr_wb_sel[5:0]      (aq_vpu_fwd_wb_rbus.v:459)
 *     vpu_vidu_fp_fwd_reg = fpr_index             (:461)
 *
 * with fpr_wb_sel built from six requesters -- vlsu, vfdsu, viq0_ex5,
 * viq0_ex4, viq0_ex3, viq1_ex3 (:415-420) -- and fpr_index selected by the
 * six-way casez at :443-455.
 *
 * Each requester has its own latency, so the producer-to-consumer distance at
 * which the forward lands (and the full stall is skipped) is different for
 * each. The six arms below are the six op classes that feed those ports, and
 * each sweeps the gap 1..6 so that whichever port a given class actually
 * arrives on, some gap in the sweep hits its forwarding window. The sweep
 * deliberately does not assume a class-to-port mapping.
 * ==================================================================== */
#define VIDU_FWD_CONS "fadd.d ft6, ft5, ft5\n\t"
#define VIDU_FWD_GAPS(PROD)                                                   \
        PROD VIDU_GAP(1) VIDU_FWD_CONS                                        \
        PROD VIDU_GAP(2) VIDU_FWD_CONS                                        \
        PROD VIDU_GAP(3) VIDU_FWD_CONS                                        \
        PROD VIDU_GAP(4) VIDU_FWD_CONS                                        \
        PROD VIDU_GAP(5) VIDU_FWD_CONS                                        \
        PROD VIDU_GAP(6) VIDU_FWD_CONS

#define VIDU_FWD(PROD) __asm__ volatile (                                     \
        "fld ft0, 0(%0)\n\t"                                                  \
        "fld ft1, 8(%0)\n\t"                                                  \
        "fld ft2, 16(%0)\n\t"                                                 \
        VIDU_FWD_GAPS(PROD)                                                   \
        "nop"                                                                 \
        :: "r"(p), "r"(w) : VIDU_FCLOB, "memory")

static void g_fwd_except(u64 r)
{
    const volatile u64 *p = vidu_operands(r);
    u64 w = r;

    switch ((unsigned)(r >> 5) % 6u) {
    case 0:  VIDU_FWD("fld     ft5, 24(%0)\n\t");            break;
    case 1:  VIDU_FWD("fdiv.d  ft5, ft0, ft1\n\t");          break;
    case 2:  VIDU_FWD("fmadd.d ft5, ft0, ft1, ft2\n\t");     break;
    case 3:  VIDU_FWD("fadd.d  ft5, ft0, ft1\n\t");          break;
    case 4:  VIDU_FWD("fmul.s  ft5, ft0, ft1\n\t");          break;
    default: VIDU_FWD("fcvt.d.l ft5, %1\n\t");               break;
    }
}

/* ==================================================================== *
 * Group 4: fwd_except_vlsu
 *
 * The *negated* qualifier that every one of those three exception terms carries:
 *
 *     && !((srcv_info[WB_VEC_TYPE] == WB_VEC_TYPE_VLSU)
 *       && (srcv_info[WB_VEC_CNT]  == 1'b1))
 *
 * Two FP loads to the same register set cnt = 1 (aq_vidu_vid_wbt_entry.v:119-121:
 * cnt_update_val is asserted only when a new VLSU producer creates over an
 * unretired one), and with TYPE == VLSU && CNT == 1 the forwarding exception is
 * suppressed -- so the consumer takes the full stall even though the data is
 * sitting on the forward bus. That is the only way to reach that branch.
 * ==================================================================== */
#define VIDU_FWDVLSU(F) __asm__ volatile (                                    \
        "fld     " #F ", 0(%0)\n\t"                                           \
        "fld     " #F ", 8(%0)\n\t"      /* waw_except holds: cnt 0 -> 1     */\
        "fadd.d  ft0, " #F ", " #F "\n\t"/* TYPE=VLSU && CNT=1: no fwd       */\
        VIDU_GAP(2)                                                           \
        "fmul.d  ft1, " #F ", ft0\n\t"                                        \
        "fmadd.d ft2, ft0, ft1, " #F                                          \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_fwd_except_vlsu(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    VIDU_FP_SWITCH(r >> 32, VIDU_FWDVLSU);
}

/* ==================================================================== *
 * Group 5: store_src2_except
 *
 * The second arm of ctrl_dis_srcf2_raw_except (aq_vidu_vid_ctrl_fp.v:293-296):
 * an FP store never has to stall on its data register, because the LSU can pick
 * the value up later. The qualifier is dp_ctrl_dis_fp_inst_store
 * (aq_vidu_vid_dp_fp.v:280-281 -- EU_VLSU_SEL && FUNC_STORE_SEL) and the
 * readiness signal it feeds is dp_dis_fp_inst_srcf2_rdy (:322-324).
 *
 * The sequence walks the store past all three scoreboard states of its data
 * register: fresh falu producer, fresh VLSU producer (cnt 0, exception applies)
 * and doubled VLSU producer (cnt 1, exception suppressed).
 * ==================================================================== */
#define VIDU_STSRC2(F) __asm__ volatile (                                     \
        "fadd.d " #F ", ft0, ft1\n\t"                                         \
        "fsd    " #F ", 24(%0)\n\t"      /* store arm of srcf2_raw_except    */\
        "fld    " #F ", 0(%0)\n\t"                                            \
        "fsd    " #F ", 32(%0)\n\t"      /* now TYPE=VLSU, CNT=0             */\
        "fld    " #F ", 8(%0)\n\t"                                            \
        "fld    " #F ", 16(%0)\n\t"      /* cnt -> 1: exception suppressed   */\
        "fsd    " #F ", 40(%0)"                                               \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_store_src2_except(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    VIDU_FP_SWITCH(r >> 32, VIDU_STSRC2);
}

/* ==================================================================== *
 * Group 6: waw
 *
 * ctrl_dis_dstf_waw (aq_vidu_vid_ctrl_fp.v:309-311): a second producer of a
 * register whose first producer has not written back yet. All four
 * producer-pair flavours the RTL can distinguish -- falu+falu, fld+falu,
 * falu+fld, fdsu+falu -- because the WAW exception at :317-322 keys on the
 * *types* of both, so the three pairs that are not VLSU+VLSU must all take the
 * stall.
 * ==================================================================== */
#define VIDU_WAW(F) __asm__ volatile (                                        \
        "fadd.d " #F ", ft0, ft1\n\t"  "fmul.d " #F ", ft0, ft1\n\t"          \
        "fld    " #F ", 0(%0)\n\t"     "fadd.d " #F ", ft0, ft1\n\t"          \
        "fadd.d " #F ", ft0, ft1\n\t"  "fld    " #F ", 8(%0)\n\t"             \
        "fdiv.d " #F ", ft0, ft1\n\t"  "fadd.d " #F ", ft0, ft1\n\t"          \
        "fmul.d ft2, " #F ", ft1"                                             \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_waw(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    VIDU_FP_SWITCH(r >> 32, VIDU_WAW);
}

/* ==================================================================== *
 * Group 7: waw_except_2fld
 *
 * ctrl_dis_dstf_waw_except (aq_vidu_vid_ctrl_fp.v:317-322) is the ONLY
 * exception to the WAW stall, and it needs all three of its conditions at once:
 * the old producer VLSU-typed, the new producer VLSU-typed, and !cnt. So two
 * back-to-back FP loads to the same register must NOT stall (and leave cnt = 1),
 * while a third one MUST.
 *
 * The scoreboard cnt is ONE BIT (aq_vidu_vid_wbt_entry.v:44, comment :103-104:
 * "0: 1 producer left, 1: 2 producers left"), so two outstanding producers per
 * FP register is the architectural ceiling. There is no cnt == 2 to chase, and
 * the third load below is the stalling case, not a deeper count.
 * ==================================================================== */
#define VIDU_WAW2FLD(F) __asm__ volatile (                                    \
        "fld    " #F ", 0(%0)\n\t"                                            \
        "fld    " #F ", 8(%0)\n\t"       /* exception: no stall, cnt -> 1    */\
        "fld    " #F ", 16(%0)\n\t"      /* cnt already 1: full WAW stall    */\
        "fadd.d ft0, " #F ", " #F "\n\t"                                      \
        "fld    " #F ", 24(%0)\n\t"                                           \
        "fsd    " #F ", 32(%0)"                                               \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_waw_except_2fld(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    VIDU_FP_SWITCH(r >> 32, VIDU_WAW2FLD);
}

/* ==================================================================== *
 * Group 8: wbt_all_regs
 *
 * All 32 scoreboard entries (aq_vidu_vid_wbt.v:202+, create_en[31:0]), all
 * 3 x 32 read-port mux arms of the FP register file
 * (aq_vidu_vid_gpr_fp.v:544-610, :620-686, :696-762) and all 32 write decodes.
 * This is the single biggest measurable delta over C906_FPU_SMOKE.s, which
 * never mentions f13, f16-f19 or f22-f31 at all.
 *
 * The sweep itself is a .rept in vidu_sweeps.S -- a register number cannot be a
 * runtime value in an FP instruction, and an assembler loop is the only thing
 * that can vary one across a straight line. The sub-cases here vary the state
 * the sweep starts from.
 * ==================================================================== */
static void g_wbt_all_regs(u64 r)
{
    volatile u64 *b = vidu_base(r);

    (void)vidu_operands(r);
    switch ((unsigned)(r >> 5) & 3u) {
    case 0:
        rand_sink += vidu_sweep_wbt_all_regs(b);
        break;
    case 1:
        /* With a long-latency producer already in flight, so the first half of
         * the sweep dispatches against a busy vfdsu. */
        __asm__ volatile ("fld ft0, 0(%0)\n\t"
                          "fdiv.d ft1, ft0, ft0"
                          :: "r"(b) : VIDU_FCLOB, "memory");
        rand_sink += vidu_sweep_wbt_all_regs(b);
        break;
    case 2:
        /* Twice, so every entry is created over an entry that has just retired. */
        rand_sink += vidu_sweep_wbt_all_regs(b);
        rand_sink += vidu_sweep_wbt_all_regs(b);
        break;
    default:
        rand_sink += vidu_sweep_wbt_all_regs(&vidu_arena[0]);
        break;
    }
}

/* ==================================================================== *
 * Group 9: split_skid
 *
 * The split FSM's NON_IDLE -> NON_SPLIT transition
 * (aq_vidu_vid_split_fp.v:153-179), the buffer write enable non_inst_data_wen
 * (:178-179) and the buffer-versus-input mux (:112-114). The buffer only takes
 * an instruction when one arrives at EX1 while ctrl_split_fp_dis_stall is up,
 * so the recipe is: a long-latency op, a dependent op that stalls dispatch,
 * then a third FP op arriving into that stall.
 *
 * The gap between the stalled op and the third one is swept 0..7: at gap 0 the
 * third op is guaranteed to meet the stall, and by gap 7 the stall may have
 * cleared, so the sweep covers both the entry and the non-entry case.
 * ==================================================================== */
#define VIDU_SKID(N) __asm__ volatile (                                       \
        "fld     ft0, 0(%0)\n\t"                                              \
        "fld     ft1, 8(%0)\n\t"                                              \
        "fdiv.d  ft2, ft0, ft1\n\t"      /* long latency, vfdsu             */\
        "fadd.d  ft3, ft2, ft2\n\t"      /* RAW on ft2 -> dispatch stalls   */\
        VIDU_GAP(N)                                                           \
        "fmul.s  ft4, ft0, ft1\n\t"      /* arrives into the stall: skid    */\
        "fmul.d  ft5, ft0, ft1\n\t"                                           \
        "fadd.h  ft6, ft0, ft1"                                               \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_split_skid(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    switch ((unsigned)(r >> 5) & 7u) {
    case 0:  VIDU_SKID(0); break;
    case 1:  VIDU_SKID(1); break;
    case 2:  VIDU_SKID(2); break;
    case 3:  VIDU_SKID(3); break;
    case 4:  VIDU_SKID(4); break;
    case 5:  VIDU_SKID(5); break;
    case 6:  VIDU_SKID(6); break;
    default: VIDU_SKID(7); break;
    }
}

/* ==================================================================== *
 * Group 10: fp_full
 *
 * vidu_idu_fp_full (aq_vidu_vid_ctrl_fp.v:205-207) back-pressuring
 * idu_vidu_ex1_fp_sel / idu_vidu_ex1_fp_dp_sel (aq_idu_id_ctrl.v:638-639,
 * :650-651), and vidu_rtu_no_op (:209-213) going away for the duration.
 *
 * A long-latency head plus eight dependents keeps the skid entry occupied long
 * enough that the IDU sees full for many consecutive cycles. Each arm uses a
 * different head so the occupancy length varies with the unit's latency.
 * ==================================================================== */
#define VIDU_FPFULL(HEAD) __asm__ volatile (                                  \
        "fld ft0, 0(%0)\n\t"                                                  \
        "fld ft1, 8(%0)\n\t"                                                  \
        HEAD                                                                  \
        "fadd.d ft3, ft2, ft2\n\t"  "fadd.d ft4, ft3, ft3\n\t"                \
        "fadd.d ft5, ft4, ft4\n\t"  "fadd.d ft6, ft5, ft5\n\t"                \
        "fmul.d ft7, ft6, ft6\n\t"  "fmul.s ft8, ft7, ft7\n\t"                \
        "fmul.h ft9, ft8, ft8\n\t"  "fadd.d ft10, ft9, ft9"                   \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_fp_full(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    switch ((unsigned)(r >> 5) & 3u) {
    case 0:  VIDU_FPFULL("fdiv.d  ft2, ft0, ft1\n\t"); break;
    case 1:  VIDU_FPFULL("fsqrt.d ft2, ft0\n\t");      break;
    case 2:  VIDU_FPFULL("fdiv.h  ft2, ft0, ft1\n\t"); break;
    default: VIDU_FPFULL("fsqrt.s ft2, ft0\n\t");      break;
    }
}

/* ==================================================================== *
 * Group 11: fpload_dual_full
 *
 * aq_idu_id_ctrl.v:634-640. An FP load is both an LSU instruction and an FP
 * instruction, so it needs BOTH queues to have room:
 *
 *   idu_lsu_ex1_sel     = ... && !lsu_idu_full && (!EU_FP_SEL || !vidu_idu_fp_full)
 *   idu_vidu_ex1_fp_sel = ... && !vidu_idu_fp_full && (!EU_LSU_SEL || !lsu_idu_full)
 *
 * Two cross-gating terms, and each has to be the blocker in turn. Filling the
 * LSU queue with integer stores to eight distinct cache lines makes
 * lsu_idu_full the cause; a long-latency FP op plus a dependent makes
 * vidu_idu_fp_full the cause. The last two arms do both at once and in the
 * other order.
 * ==================================================================== */
static void g_fpload_dual_full(u64 r)
{
    volatile u64 *b = vidu_base(r);
    u64 v = r;

    (void)vidu_operands(r);
    switch ((unsigned)(r >> 5) & 3u) {
    case 0:
        /* LSU queue first: eight stores to eight different 64-byte lines. */
        __asm__ volatile (
            "sd %1,   0(%0)\n\t" "sd %1,  64(%0)\n\t"
            "sd %1, 128(%0)\n\t" "sd %1, 192(%0)\n\t"
            "sd %1, 256(%0)\n\t" "sd %1, 320(%0)\n\t"
            "sd %1, 384(%0)\n\t" "sd %1, 448(%0)\n\t"
            "fld ft0, 0(%0)\n\t"
            "fadd.d ft1, ft0, ft0"
            :: "r"(b), "r"(v) : VIDU_FCLOB, "memory");
        break;
    case 1:
        /* FP queue first: fdiv plus a dependent holds the skid entry. */
        __asm__ volatile (
            "fld ft0, 0(%0)\n\t"
            "fdiv.d ft1, ft0, ft0\n\t"
            "fadd.d ft2, ft1, ft1\n\t"
            "fld ft3, 8(%0)\n\t"
            "fld ft4, 16(%0)\n\t"
            "fadd.d ft5, ft3, ft4"
            :: "r"(b) : VIDU_FCLOB, "memory");
        break;
    case 2:
        /* Both, LSU first. */
        __asm__ volatile (
            "sd %1,   0(%0)\n\t" "sd %1,  64(%0)\n\t"
            "sd %1, 128(%0)\n\t" "sd %1, 192(%0)\n\t"
            "fld ft0, 0(%0)\n\t"
            "fdiv.d ft1, ft0, ft0\n\t"
            "sd %1, 256(%0)\n\t" "sd %1, 320(%0)\n\t"
            "sd %1, 384(%0)\n\t" "sd %1, 448(%0)\n\t"
            "fld ft2, 8(%0)\n\t"
            "fadd.d ft3, ft1, ft2"
            :: "r"(b), "r"(v) : VIDU_FCLOB, "memory");
        break;
    default:
        /* Both, FP first, and with FP stores in the mix so the FLSU is the one
         * competing for the LSU queue. */
        __asm__ volatile (
            "fld ft0, 0(%0)\n\t"
            "fsqrt.d ft1, ft0\n\t"
            "fsd ft0,   0(%0)\n\t" "fsd ft0,  64(%0)\n\t"
            "fsd ft0, 128(%0)\n\t" "fsd ft0, 192(%0)\n\t"
            "fsd ft0, 256(%0)\n\t" "fsd ft0, 320(%0)\n\t"
            "fld ft2, 8(%0)\n\t"
            "fadd.d ft3, ft1, ft2"
            :: "r"(b) : VIDU_FCLOB, "memory");
        break;
    }
}

/* ==================================================================== *
 * Group 12: vex1_stall
 *
 * vpu_vidu_vex1_fp_stall (aq_vpu_fwd_wb_rbus.v:529) -> ctrl_dis_fp_stall
 * (aq_vidu_vid_ctrl_fp.v:224-225) -> ctrl_split_fp_dis_stall (:227), the one
 * stall source that does NOT come from a dependency. Note that
 * viq1_xx_ex1_stall is tied to 1'b0 (aq_vpu_fwd_wb_rbus.v:543), so only two of
 * the three terms -- viq0_xx_ex1_stall and vlsu_xx_ex1_fp_stall -- are live.
 *
 * The stall is a structural collision: a short op reaching EX1 in the same
 * cycle that a long-latency op wants the writeback. Which gap produces the
 * collision depends on the fdiv/fsqrt latency, so the gap is swept 1..24 rather
 * than guessed.
 * ==================================================================== */
#define VIDU_VEX1(N) __asm__ volatile (                                       \
        "fld ft0, 0(%0)\n\t"                                                  \
        "fld ft1, 8(%0)\n\t"                                                  \
        "fdiv.d  ft2, ft0, ft1\n\t"                                           \
        VIDU_GAP(N)                                                           \
        "fadd.d  ft3, ft0, ft1\n\t"      /* aimed at the fdiv's writeback   */\
        "fmul.d  ft4, ft0, ft1\n\t"                                           \
        "fsqrt.d ft5, ft0\n\t"                                                \
        VIDU_GAP(N)                                                           \
        "fadd.s  ft6, ft0, ft1\n\t"      /* aimed at the fsqrt's writeback  */\
        "fmul.s  ft7, ft0, ft1"                                               \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_vex1_stall(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    switch ((unsigned)(r >> 5) % 24u) {
    case  0: VIDU_VEX1( 1); break;   case  1: VIDU_VEX1( 2); break;
    case  2: VIDU_VEX1( 3); break;   case  3: VIDU_VEX1( 4); break;
    case  4: VIDU_VEX1( 5); break;   case  5: VIDU_VEX1( 6); break;
    case  6: VIDU_VEX1( 7); break;   case  7: VIDU_VEX1( 8); break;
    case  8: VIDU_VEX1( 9); break;   case  9: VIDU_VEX1(10); break;
    case 10: VIDU_VEX1(11); break;   case 11: VIDU_VEX1(12); break;
    case 12: VIDU_VEX1(13); break;   case 13: VIDU_VEX1(14); break;
    case 14: VIDU_VEX1(15); break;   case 15: VIDU_VEX1(16); break;
    case 16: VIDU_VEX1(17); break;   case 17: VIDU_VEX1(18); break;
    case 18: VIDU_VEX1(19); break;   case 19: VIDU_VEX1(20); break;
    case 20: VIDU_VEX1(21); break;   case 21: VIDU_VEX1(22); break;
    case 22: VIDU_VEX1(23); break;   default: VIDU_VEX1(24); break;
    }
}

/* ==================================================================== *
 * Group 13: wb_priority
 *
 * The three writeback muxes in aq_vpu_fwd_wb_rbus.v: the six-way casez that
 * picks fpr_index (:443-455), the four-arm casez that picks fpr_data (:427-434)
 * and the three-arm EX3 sub-mux over vfmau / vfalu / vfcvt (:405-409). The
 * priority arms only show themselves when two requesters collide, so each arm
 * below deliberately aims a pair of producers at the same writeback cycle,
 * using a different gap per arm so the collision window is swept as well as the
 * pairing.
 * ==================================================================== */
#define VIDU_WB_L "fld     ft2, 16(%0)\n\t"     /* vlsu,      fpr_wb_sel[5] */
#define VIDU_WB_D "fdiv.d  ft3, ft0, ft1\n\t"   /* vfdsu,     [4]           */
#define VIDU_WB_Q "fsqrt.d ft4, ft0\n\t"        /* vfdsu                    */
#define VIDU_WB_M "fmadd.d ft5, ft0, ft1, ft0\n\t" /* vfmau, .d -> ex5, [3] */
#define VIDU_WB_E "fadd.d  ft6, ft0, ft1\n\t"   /* vfalu at ex3             */
#define VIDU_WB_U "fmul.s  ft7, ft0, ft1\n\t"   /* vfmau single             */
#define VIDU_WB_C "fcvt.s.d ft8, ft0\n\t"       /* vfcvt at ex3             */

#define VIDU_WBPAIR(A, B, N) __asm__ volatile (                               \
        "fld ft0, 0(%0)\n\t"                                                  \
        "fld ft1, 8(%0)\n\t"                                                  \
        A VIDU_GAP(N) B                                                       \
        "nop"                                                                 \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_wb_priority(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    switch ((unsigned)(r >> 5) % 10u) {
    case 0:  VIDU_WBPAIR(VIDU_WB_D, VIDU_WB_L, 1);  break;
    case 1:  VIDU_WBPAIR(VIDU_WB_D, VIDU_WB_E, 2);  break;
    case 2:  VIDU_WBPAIR(VIDU_WB_D, VIDU_WB_M, 3);  break;
    case 3:  VIDU_WBPAIR(VIDU_WB_Q, VIDU_WB_L, 4);  break;
    case 4:  VIDU_WBPAIR(VIDU_WB_Q, VIDU_WB_E, 5);  break;
    case 5:  VIDU_WBPAIR(VIDU_WB_M, VIDU_WB_L, 6);  break;
    case 6:  VIDU_WBPAIR(VIDU_WB_M, VIDU_WB_E, 7);  break;
    case 7:  VIDU_WBPAIR(VIDU_WB_L, VIDU_WB_C, 8);  break;
    case 8:  VIDU_WBPAIR(VIDU_WB_D, VIDU_WB_Q, 9);  break;
    default: VIDU_WBPAIR(VIDU_WB_M, VIDU_WB_U, 10); break;
    }
}

/* ==================================================================== *
 * Group 14: flsu_std
 *
 * All six standard FP load/store widths over all 32 registers, in
 * vidu_sweeps.S. C906_FPU_SMOKE.s has 4 fld, 2 fsd, 1 flh, 1 fsh and no flw or
 * fsw at all.
 *
 * FP loads and stores take a different completion path from FP arithmetic:
 * vpu_rtu_ex1_cmplt is suppressed for the FLSU
 * (aq_vidu_vid_ctrl_fp.v:174-178), so they retire through the LSU rather than
 * reporting completion at EX1.
 * ==================================================================== */
static void g_flsu_std(u64 r)
{
    volatile u64 *b = vidu_base(r);

    (void)vidu_operands(r);
    switch ((unsigned)(r >> 5) & 3u) {
    case 0:
        rand_sink += vidu_sweep_flsu_std(b);
        break;
    case 1:
        /* Interleaved with a long-latency arithmetic op, so the FLSU and the
         * vfdsu compete for the writeback port throughout. */
        __asm__ volatile ("fld ft0, 0(%0)\n\tfdiv.d ft1, ft0, ft0"
                          :: "r"(b) : VIDU_FCLOB, "memory");
        rand_sink += vidu_sweep_flsu_std(b);
        break;
    case 2:
        rand_sink += vidu_sweep_flsu_std(&vidu_arena[0]);
        break;
    default:
        /* Same sweep with the D-cache lines cold: a clean+invalidate first, so
         * every load in the sweep is a refill rather than a hit. */
        DCACHE_SAFE_POINT();
        rand_sink += vidu_sweep_flsu_std(b);
        break;
    }
}

/* ==================================================================== *
 * Group 15: flsu_c
 *
 * The compressed FP loads and stores -- c.fld, c.fsd, c.fldsp, c.fsdsp -- of
 * which C906_FPU_SMOKE.s contains exactly none. Emitted as raw .2byte in
 * vidu_sweeps.S so the encoding is pinned; the c.f*sp forms are sp-relative,
 * which is why that sweep allocates its own frame.
 * ==================================================================== */
static void g_flsu_c(u64 r)
{
    volatile u64 *b = vidu_base(r);

    (void)vidu_operands(r);
    switch ((unsigned)(r >> 5) & 3u) {
    case 0:
        vidu_sweep_flsu_c(b);
        break;
    case 1:
        vidu_sweep_flsu_c(&vidu_arena[0]);
        break;
    case 2:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfdiv.d ft1, ft0, ft0"
                          :: "r"(b) : VIDU_FCLOB, "memory");
        vidu_sweep_flsu_c(b);
        break;
    default:
        DCACHE_SAFE_POINT();
        vidu_sweep_flsu_c(b);
        break;
    }
}

/* ==================================================================== *
 * Group 16: flsu_xtheadc
 *
 * The eight Xtheadc indexed FP forms -- th.flrw / flrd / flurw / flurd /
 * fsrw / fsrd / fsurw / fsurd (aq_idu_id_decd.v:3671-3726) -- crossed with all
 * four values of the 2-bit shift in inst[26:25]. Raw .word because the build
 * has no xtheadfmemidx in its -march.
 *
 * The index is always a multiple of 8, so base + (index << shift) is 8-byte
 * aligned for every shift and no arm depends on mxstatus.MM hardware misaligned
 * support. The `fd` field is swept as well, and it is the real register field on
 * both the load and the store side: inst[11:7] feeds dstf via
 * decd_inst_dstf_reg_32bit_low and srcf2 via arm 4'b1000 of the srcf2 mux, which
 * decd_inst_vls (opcode == 7'b0001011) selects. See the note on VIDU_TH_FIDX in
 * vidu_defs.h for the RTL line numbers and the assembler cross-check.
 *
 * Own random fields: bits [12:8] pick the index, bits [20:16] pick the arm --
 * both clear of the group selector, see the bit budget at the top of the file.
 * ==================================================================== */
static void g_flsu_xtheadc(u64 r)
{
    volatile u64 *b = &vidu_arena[0];
    u64 i = (u64)((unsigned)(r >> 8) & 31u) * 8u;

    (void)vidu_operands(r);
    switch ((unsigned)(r >> 16) & 31u) {
    case  0: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLRW,   0, 0), b, i); break;
    case  1: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLRW,   5, 1), b, i); break;
    case  2: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLRW,  13, 2), b, i); break;
    case  3: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLRW,  22, 3), b, i); break;
    case  4: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLRD,   1, 0), b, i); break;
    case  5: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLRD,   6, 1), b, i); break;
    case  6: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLRD,  16, 2), b, i); break;
    case  7: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLRD,  23, 3), b, i); break;
    case  8: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLURW,  2, 0), b, i); break;
    case  9: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLURW,  7, 1), b, i); break;
    case 10: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLURW, 17, 2), b, i); break;
    case 11: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLURW, 24, 3), b, i); break;
    case 12: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLURD,  3, 0), b, i); break;
    case 13: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLURD, 10, 1), b, i); break;
    case 14: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLURD, 18, 2), b, i); break;
    case 15: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FLURD, 25, 3), b, i); break;
    case 16: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSRW,   4, 0), b, i); break;
    case 17: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSRW,  11, 1), b, i); break;
    case 18: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSRW,  19, 2), b, i); break;
    case 19: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSRW,  26, 3), b, i); break;
    case 20: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSRD,   8, 0), b, i); break;
    case 21: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSRD,  12, 1), b, i); break;
    case 22: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSRD,  20, 2), b, i); break;
    case 23: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSRD,  27, 3), b, i); break;
    case 24: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSURW,  9, 0), b, i); break;
    case 25: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSURW, 14, 1), b, i); break;
    case 26: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSURW, 21, 2), b, i); break;
    case 27: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSURW, 28, 3), b, i); break;
    case 28: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSURD, 15, 0), b, i); break;
    case 29: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSURD, 29, 1), b, i); break;
    case 30: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSURD, 30, 2), b, i); break;
    default: VIDU_TH_FIDX_OP(VIDU_TH_FIDX(VIDU_TH_FSURD, 31, 3), b, i); break;
    }
    /* One dependent op, so the indexed form's destination is consumed rather
     * than simply overwritten by the next iteration. */
    __asm__ volatile ("fadd.d ft0, ft0, ft0" ::: VIDU_FCLOB);
}

/* ==================================================================== *
 * Group 17: arith_short
 *
 * fadd / fsub / fmul in all three widths, with the register the RNG picked and
 * operands drawn from the pool: signed zeros, denormals, infinities, quiet and
 * signalling NaNs, the largest and smallest normals, and random mantissas.
 * These are the vfalu and vfmau short-latency ops, i.e. the EX3 and EX4
 * writeback sources.
 * ==================================================================== */
#define VIDU_ARITH_SHORT(F) __asm__ volatile (                                \
        "fld    " #F ", 0(%0)\n\t"                                            \
        "fld    ft10, 8(%0)\n\t"                                              \
        "fld    ft11, 16(%0)\n\t"                                             \
        "fadd.d " #F ", ft10, ft11\n\t"                                       \
        "fsub.d ft10, " #F ", ft11\n\t"                                       \
        "fmul.d ft11, ft10, " #F "\n\t"                                       \
        "fadd.s " #F ", ft10, ft11\n\t"                                       \
        "fsub.s ft10, " #F ", ft11\n\t"                                       \
        "fmul.s ft11, ft10, " #F "\n\t"                                       \
        "fadd.h " #F ", ft10, ft11\n\t"                                       \
        "fsub.h ft10, " #F ", ft11\n\t"                                       \
        "fmul.h ft11, ft10, " #F                                              \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_arith_short(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    VIDU_FP_SWITCH(r >> 32, VIDU_ARITH_SHORT);
}

/* ==================================================================== *
 * Group 18: arith_fma
 *
 * fmadd / fmsub / fnmadd / fnmsub in all three widths. The only three-source
 * FP instructions in the ISA, hence the only users of the srcf2 read port
 * outside FP stores, and (for .d) the only source of the viq0_ex5 writeback
 * request that occupies arm 6'b001??? of the fpr_index mux
 * (aq_vpu_fwd_wb_rbus.v:451).
 *
 * The register the RNG picked sits in the rs3 slot throughout, which is the
 * srcf2 index field for the FMA family (aq_idu_id_decd.v:812-817 falls through
 * to its `default` arm, x_inst[31:27], for exactly these opcodes).
 * ==================================================================== */
#define VIDU_ARITH_FMA(F) __asm__ volatile (                                  \
        "fld " #F ", 0(%0)\n\t"                                               \
        "fld ft10, 8(%0)\n\t"                                                 \
        "fld ft11, 16(%0)\n\t"                                                \
        "fmadd.d  ft0, ft10, ft11, " #F "\n\t"                                \
        "fmsub.d  ft1, ft10, ft11, " #F "\n\t"                                \
        "fnmadd.d ft2, ft10, ft11, " #F "\n\t"                                \
        "fnmsub.d ft3, ft10, ft11, " #F "\n\t"                                \
        "fmadd.s  ft4, ft10, ft11, " #F "\n\t"                                \
        "fmsub.s  ft5, ft10, ft11, " #F "\n\t"                                \
        "fnmadd.s ft6, ft10, ft11, " #F "\n\t"                                \
        "fnmsub.s ft7, ft10, ft11, " #F "\n\t"                                \
        "fmadd.h  ft8, ft10, ft11, " #F "\n\t"                                \
        "fmsub.h  ft9, ft10, ft11, " #F "\n\t"                                \
        "fnmadd.h ft0, ft10, ft11, " #F "\n\t"                                \
        "fnmsub.h ft1, ft10, ft11, " #F                                       \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_arith_fma(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    VIDU_FP_SWITCH(r >> 32, VIDU_ARITH_FMA);
}

/* ==================================================================== *
 * Group 19: arith_long
 *
 * fdiv and fsqrt in all three widths -- the vfdsu, the only multi-cycle FP
 * unit and therefore the only thing that makes the skid buffer, fp_full and
 * vex1_stall reachable at all.
 *
 * Both halves of the unit are wanted: the operands come from vidu_fdsu_pool,
 * which is zero, infinity, NaN and exact powers of two (the short path, where
 * the result is produced without entering the iterative datapath) plus pi (the
 * slow path).
 *
 * Own random fields, all disjoint and all clear of the group selector: operand 0
 * from bits [7:5], operand 1 from [10:8], operand 2 from [15:11], the arm from
 * [16] up. Overlapping operand 0 and operand 1 would tie a numerator to its
 * denominator, which is exactly the pairing this group is trying to randomise.
 * ==================================================================== */
static void g_arith_long(u64 r)
{
    volatile u64 *p = &vidu_arena[0];

    vidu_arena[0] = vidu_fdsu_pool[(unsigned)(r >> 5) & 7u];
    vidu_arena[1] = vidu_fdsu_pool[(unsigned)(r >> 8) & 7u];
    vidu_arena[2] = vidu_fp_pool[(unsigned)(r >> 11) & 31u];

    switch ((unsigned)(r >> 16) % 6u) {
    case 0:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 8(%0)\n\t"
                          "fdiv.d ft2, ft0, ft1\n\tfdiv.d ft3, ft1, ft0\n\t"
                          "fadd.d ft4, ft2, ft3"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 1:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 8(%0)\n\t"
                          "fdiv.s ft2, ft0, ft1\n\tfdiv.s ft3, ft1, ft0\n\t"
                          "fadd.s ft4, ft2, ft3"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 2:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 8(%0)\n\t"
                          "fdiv.h ft2, ft0, ft1\n\tfdiv.h ft3, ft1, ft0\n\t"
                          "fadd.h ft4, ft2, ft3"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 3:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 16(%0)\n\t"
                          "fsqrt.d ft2, ft0\n\tfsqrt.d ft3, ft1\n\t"
                          "fadd.d ft4, ft2, ft3"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 4:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 16(%0)\n\t"
                          "fsqrt.s ft2, ft0\n\tfsqrt.s ft3, ft1\n\t"
                          "fadd.s ft4, ft2, ft3"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    default:
        /* Back-to-back long-latency ops of different widths, so the unit is
         * re-entered before it has drained. */
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 8(%0)\n\t"
                          "fsqrt.h ft2, ft0\n\tfdiv.d ft3, ft0, ft1\n\t"
                          "fsqrt.d ft4, ft1\n\tfdiv.h ft5, ft1, ft0\n\t"
                          "fadd.d ft6, ft3, ft4"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    }
}

/* ==================================================================== *
 * Group 20: cvt
 *
 * Every fcvt form the core implements: the six FP-to-FP conversions across
 * s/d/h, the twelve FP-to-integer forms and the twelve integer-to-FP forms.
 * The FP-to-integer half is interesting to VIDU specifically because the
 * destination is a GPR, so the instruction is issued by VIDU but retires
 * through the integer scoreboard.
 * ==================================================================== */
#define VIDU_CVT(BODY) do {                                                   \
        u64 o_;                                                               \
        __asm__ volatile ("fld ft0, 0(%1)\n\tfld ft1, 8(%1)\n\t"              \
                          "mv %0, %2\n\t" BODY                                \
                          : "=&r"(o_) : "r"(p), "r"(v)                        \
                          : VIDU_FCLOB, "memory");                            \
        rand_sink += o_;                                                      \
    } while (0)

static void g_cvt(u64 r)
{
    const volatile u64 *p = vidu_operands(r);
    u64 v = r;

    switch ((unsigned)(r >> 5) % 10u) {
    case 0: VIDU_CVT("fcvt.s.d  ft2, ft0\n\t"
                     "fcvt.d.s  ft3, ft2\n\t"
                     "fcvt.h.s  ft4, ft2");                     break;
    case 1: VIDU_CVT("fcvt.s.h  ft2, ft0\n\t"
                     "fcvt.h.d  ft3, ft1\n\t"
                     "fcvt.d.h  ft4, ft3");                     break;
    case 2: VIDU_CVT("fcvt.w.s  %0, ft0\n\t"
                     "fcvt.wu.s %0, ft0\n\t"
                     "fcvt.l.s  %0, ft0");                      break;
    case 3: VIDU_CVT("fcvt.lu.s %0, ft0\n\t"
                     "fcvt.w.d  %0, ft1\n\t"
                     "fcvt.wu.d %0, ft1");                      break;
    case 4: VIDU_CVT("fcvt.l.d  %0, ft1\n\t"
                     "fcvt.lu.d %0, ft1\n\t"
                     "fcvt.w.h  %0, ft0");                      break;
    case 5: VIDU_CVT("fcvt.wu.h %0, ft0\n\t"
                     "fcvt.l.h  %0, ft0\n\t"
                     "fcvt.lu.h %0, ft0");                      break;
    case 6: VIDU_CVT("fcvt.s.w  ft2, %0\n\t"
                     "fcvt.s.wu ft3, %0\n\t"
                     "fcvt.s.l  ft4, %0");                      break;
    case 7: VIDU_CVT("fcvt.s.lu ft2, %0\n\t"
                     "fcvt.d.w  ft3, %0\n\t"
                     "fcvt.d.wu ft4, %0");                      break;
    case 8: VIDU_CVT("fcvt.d.l  ft2, %0\n\t"
                     "fcvt.d.lu ft3, %0\n\t"
                     "fcvt.h.w  ft4, %0");                      break;
    default:VIDU_CVT("fcvt.h.wu ft2, %0\n\t"
                     "fcvt.h.l  ft3, %0\n\t"
                     "fcvt.h.lu ft4, %0");                      break;
    }
}

/* ==================================================================== *
 * Group 21: cmp_class
 *
 * feq / flt / fle in all three widths, plus fclass. FP-unit instructions with
 * an INTEGER destination: they are dispatched through VIDU and read the FP
 * register file, but their result goes to a GPR, so they are the other half of
 * the FP-to-integer coupling that group 30 attacks from the dependency side.
 * ==================================================================== */
#define VIDU_CMP(BODY) do {                                                   \
        u64 o_;                                                               \
        __asm__ volatile ("fld ft0, 0(%1)\n\tfld ft1, 8(%1)\n\t" BODY         \
                          : "=&r"(o_) : "r"(p) : VIDU_FCLOB, "memory");       \
        rand_sink += o_;                                                      \
    } while (0)

static void g_cmp_class(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    switch ((unsigned)(r >> 5) % 12u) {
    case  0: VIDU_CMP("feq.d %0, ft0, ft1");     break;
    case  1: VIDU_CMP("flt.d %0, ft0, ft1");     break;
    case  2: VIDU_CMP("fle.d %0, ft0, ft1");     break;
    case  3: VIDU_CMP("feq.s %0, ft0, ft1");     break;
    case  4: VIDU_CMP("flt.s %0, ft0, ft1");     break;
    case  5: VIDU_CMP("fle.s %0, ft0, ft1");     break;
    case  6: VIDU_CMP("feq.h %0, ft0, ft1");     break;
    case  7: VIDU_CMP("flt.h %0, ft0, ft1");     break;
    case  8: VIDU_CMP("fle.h %0, ft0, ft1");     break;
    case  9: VIDU_CMP("fclass.d %0, ft0");       break;
    case 10: VIDU_CMP("fclass.s %0, ft0");       break;
    default: VIDU_CMP("fclass.h %0, ft0");       break;
    }
}

/* ==================================================================== *
 * Group 22: sgnj_minmax
 *
 * fsgnj / fsgnjn / fsgnjx and fmin / fmax in all three widths, over the whole
 * register file. C906_FPU_SMOKE.s has exactly one of each fsgnj* form and no
 * fsgnj.h at all, so almost everything here is new. Sign injection is the one
 * FP op family whose result depends only on the sign bits, which makes the pool
 * entries with signed zeros, negative NaNs and negative infinities the
 * interesting inputs.
 * ==================================================================== */
#define VIDU_SGNJ(F) __asm__ volatile (                                       \
        "fld " #F ", 0(%0)\n\t"                                               \
        "fld ft10, 8(%0)\n\t"                                                 \
        "fsgnj.d  ft0, " #F ", ft10\n\t"                                      \
        "fsgnjn.d ft1, " #F ", ft10\n\t"                                      \
        "fsgnjx.d ft2, " #F ", ft10\n\t"                                      \
        "fmin.d   ft3, " #F ", ft10\n\t"                                      \
        "fmax.d   ft4, " #F ", ft10\n\t"                                      \
        "fsgnj.s  ft5, " #F ", ft10\n\t"                                      \
        "fsgnjn.s ft6, " #F ", ft10\n\t"                                      \
        "fsgnjx.s ft7, " #F ", ft10\n\t"                                      \
        "fmin.s   ft8, " #F ", ft10\n\t"                                      \
        "fmax.s   ft9, " #F ", ft10\n\t"                                      \
        "fsgnj.h  ft0, " #F ", ft10\n\t"                                      \
        "fsgnjn.h ft1, " #F ", ft10\n\t"                                      \
        "fsgnjx.h ft2, " #F ", ft10\n\t"                                      \
        "fmin.h   ft3, " #F ", ft10\n\t"                                      \
        "fmax.h   ft4, " #F ", ft10"                                          \
        :: "r"(p) : VIDU_FCLOB, "memory")

static void g_sgnj_minmax(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    VIDU_FP_SWITCH(r >> 32, VIDU_SGNJ);
}

/* ==================================================================== *
 * Group 23: fmv
 *
 * fmv.x.d / fmv.d.x / fmv.x.w / fmv.w.x / fmv.x.h / fmv.h.x -- the only path
 * that couples the FP and the integer register files directly, with no
 * conversion in between. Every one of the six is issued against the register
 * the RNG picked, and the GPR side is left to the compiler's allocator, which
 * can only pick a caller-saved register.
 * ==================================================================== */
#define VIDU_FMV(F) do {                                                      \
        u64 o_;                                                               \
        __asm__ volatile ("fld " #F ", 0(%1)\n\t"                             \
                          "fmv.x.d %0, " #F "\n\t"                            \
                          "fmv.d.x " #F ", %0\n\t"                            \
                          "fmv.x.w %0, " #F "\n\t"                            \
                          "fmv.w.x " #F ", %0\n\t"                            \
                          "fmv.x.h %0, " #F "\n\t"                            \
                          "fmv.h.x " #F ", %0\n\t"                            \
                          "fmv.x.d %0, " #F                                   \
                          : "=&r"(o_) : "r"(p) : VIDU_FCLOB, "memory");       \
        rand_sink += o_;                                                      \
    } while (0)

static void g_fmv(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    VIDU_FP_SWITCH(r >> 32, VIDU_FMV);
}

/* ==================================================================== *
 * Group 24: frm_static
 *
 * Every FP op crossed with each of the five legal static rm encodings (000..100)
 * plus 111 (dynamic). rm is an instruction field, so the sweep is unrolled in
 * vidu_sweeps.S.
 * ==================================================================== */
static void g_frm_static(u64 r)
{
    volatile u64 *b = vidu_base(r);

    (void)vidu_operands(r);
    switch ((unsigned)(r >> 5) & 3u) {
    case 0:
        vidu_sweep_rm_static(&vidu_arena[0]);
        break;
    case 1:
        /* With frm parked somewhere legal but unusual, so that the dynamic arm
         * of the sweep resolves to something other than round-to-nearest. */
        CSR_W(CSR_FRM, (r >> 8) % 5u);
        vidu_sweep_rm_static(&vidu_arena[0]);
        CSR_W(CSR_FCSR, 0);
        break;
    case 2:
        vidu_sweep_rm_static(b);
        break;
    default:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfdiv.d ft1, ft0, ft0"
                          :: "r"(b) : VIDU_FCLOB, "memory");
        vidu_sweep_rm_static(b);
        break;
    }
}

/* ==================================================================== *
 * Group 25: frm_dynamic
 *
 * rm == 111 means "use fcsr.frm", and the decoder reads frm directly:
 * fp_dynamic_rounding_illegal (aq_idu_id_decd.v:947-951) makes any
 * dynamic-rounding FP op illegal when frm is 101, 110 or 111. So this group
 * drives frm through all eight values and issues dynamic-rm ops at each.
 *
 * THE FCSR RESTORE AT THE END IS NOT OPTIONAL. Leaving frm at 5, 6 or 7 makes
 * every subsequent dynamic-rounding op in the run illegal -- and since every FP
 * op GCC emits without an explicit rm is a dynamic-rounding op, that degenerates
 * into a trap storm that retires instructions on every trap. The testbench's
 * no-retire watchdog never fires on a livelock that retires; only the
 * simulation time limit catches it. rand_restore_sane_state() also writes
 * fcsr = 0, which covers the path where a nested trap unwinds out of here.
 *
 * frm comes from bits [7:5] and the op arm from [9:8]. frm MUST NOT be taken
 * from bits [4:0]: those are the group index, so frm would be pinned to one
 * value for the whole run and three of the eight cases -- including both of the
 * reserved ones this group exists to reach -- would never be tried.
 * ==================================================================== */
static void g_frm_dynamic(u64 r)
{
    const volatile u64 *p = vidu_operands(r);
    unsigned frm = (unsigned)(r >> 5) & 7u;

    CSR_W(CSR_FRM, frm);
    if (frm >= 5u)
        vidu_frm_illegal++;

    switch ((unsigned)(r >> 8) & 3u) {
    case 0:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 8(%0)\n\t"
                          "fadd.d ft2, ft0, ft1\n\t"
                          "fmul.d ft3, ft0, ft1"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 1:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 8(%0)\n\t"
                          "fdiv.s ft2, ft0, ft1\n\t"
                          "fsqrt.s ft3, ft0"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 2:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 8(%0)\n\t"
                          "fmadd.h ft2, ft0, ft1, ft0\n\t"
                          "fcvt.h.d ft3, ft0"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    default: {
        u64 o_;
        __asm__ volatile ("fld ft0, 0(%1)\n\t"
                          "fcvt.w.d %0, ft0\n\t"
                          "fcvt.lu.s %0, ft0"
                          : "=&r"(o_) : "r"(p) : VIDU_FCLOB, "memory");
        rand_sink += o_;
        break;
    }
    }

    vidu_flags_seen |= CSR_R(CSR_FFLAGS) & 0x1FUL;
    CSR_W(CSR_FCSR, 0);            /* mandatory: see the comment above */
}

/* ==================================================================== *
 * Group 26: rm_illegal
 *
 * fp_static_rounding_illegal (aq_idu_id_decd.v:945-946): rm == 101 and
 * rm == 110 are reserved and make the instruction illegal regardless of fcsr.
 * The assembler will not emit either -- there is no mnemonic for them -- so raw
 * .word encodings are mandatory here, built from VIDU_FP_OP() in vidu_defs.h.
 *
 * Each arm raises exactly one illegal-instruction exception (cause 2), which
 * the shared handler steps over.
 * ==================================================================== */
static void g_rm_illegal(u64 r)
{
    vidu_rm_illegal++;
    switch ((unsigned)(r >> 5) & 7u) {
    case 0:  RAW_OP(VIDU_FP_OP(VIDU_F7_FADD_D,  1, 0, 5,  2)); break;
    case 1:  RAW_OP(VIDU_FP_OP(VIDU_F7_FADD_D,  1, 0, 6,  2)); break;
    case 2:  RAW_OP(VIDU_FP_OP(VIDU_F7_FMUL_S,  3, 2, 5,  4)); break;
    case 3:  RAW_OP(VIDU_FP_OP(VIDU_F7_FMUL_S,  3, 2, 6,  4)); break;
    case 4:  RAW_OP(VIDU_FP_OP(VIDU_F7_FDIV_H,  5, 4, 5,  6)); break;
    case 5:  RAW_OP(VIDU_FP_OP(VIDU_F7_FSQRT_D, 0, 6, 6,  7)); break;
    case 6:  RAW_OP(VIDU_FP_OP(VIDU_F7_FCVT_WD, 0, 7, 5, 11)); break;
    default: RAW_OP(VIDU_FMA_OP(VIDU_OPC_FMADD, 3, VIDU_FMT_D, 2, 1, 6, 4));
             break;
    }
    /* fflags is unchanged by an instruction that never executed; reading it
     * here is the cheap way to prove the FP CSR path still works afterwards. */
    vidu_flags_seen |= CSR_R(CSR_FFLAGS) & 0x1FUL;
}

/* ==================================================================== *
 * Group 27: fflags
 *
 * All five accumulated exception flags, raised by construction rather than by
 * luck: NX from a division that cannot be represented, UF from scaling the
 * smallest denormal down, OF from doubling the largest normal, DZ from x/0 and
 * NV from 0/0 and from the square root of a negative number. Then the three
 * ways software can see them -- fflags, fcsr and the T-Head fxcr -- a clear,
 * and a second accumulation to show the sticky bits really were cleared.
 * ==================================================================== */
static void g_fflags(u64 r)
{
    u64 f;

    /* Operands chosen for the flag, not from the pool. */
    vidu_arena[0] = 0x3ff0000000000000UL;   /*  1.0                    */
    vidu_arena[1] = 0x4008000000000000UL;   /*  3.0  -> NX             */
    vidu_arena[2] = 0x0000000000000001UL;   /*  min denormal -> UF     */
    vidu_arena[3] = 0x7fefffffffffffffUL;   /*  max normal   -> OF     */
    vidu_arena[4] = 0x0000000000000000UL;   /*  0.0  -> DZ, NV         */
    vidu_arena[5] = 0xbff0000000000000UL;   /* -1.0  -> NV on sqrt     */

    CSR_W(CSR_FFLAGS, 0);
    switch ((unsigned)(r >> 5) & 3u) {
    case 0:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 8(%0)\n\t"
                          "fdiv.d ft2, ft0, ft1"            /* NX */
                          :: "r"(&vidu_arena[0]) : VIDU_FCLOB, "memory");
        break;
    case 1:
        __asm__ volatile ("fld ft0, 16(%0)\n\tfld ft1, 24(%0)\n\t"
                          "fmul.d ft2, ft0, ft0\n\t"        /* UF */
                          "fadd.d ft3, ft1, ft1"            /* OF */
                          :: "r"(&vidu_arena[0]) : VIDU_FCLOB, "memory");
        break;
    case 2:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 32(%0)\n\t"
                          "fdiv.d ft2, ft0, ft1\n\t"        /* DZ */
                          "fdiv.d ft3, ft1, ft1"            /* NV */
                          :: "r"(&vidu_arena[0]) : VIDU_FCLOB, "memory");
        break;
    default:
        __asm__ volatile ("fld ft0, 40(%0)\n\t"
                          "fsqrt.d ft1, ft0"                /* NV */
                          :: "r"(&vidu_arena[0]) : VIDU_FCLOB, "memory");
        break;
    }

    f = CSR_R(CSR_FFLAGS);
    vidu_flags_seen |= f & 0x1FUL;
    rand_sink += CSR_R(CSR_FCSR);
    rand_sink += CSR_R(CSR_FXCR);

    /* Clear, then re-accumulate, so the sticky bits are seen going both ways. */
    CSR_W(CSR_FFLAGS, 0);
    __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 8(%0)\n\t"
                      "fdiv.d ft2, ft0, ft1"
                      :: "r"(&vidu_arena[0]) : VIDU_FCLOB, "memory");
    vidu_flags_seen |= CSR_R(CSR_FFLAGS) & 0x1FUL;
    CSR_W(CSR_FCSR, 0);
}

/* ==================================================================== *
 * Group 28: fs_dirty
 *
 * vpu_rtu_ex1_fp_dirty (aq_vidu_vid_dp_fp.v:211-212) is asserted by any
 * instruction with an FP or an FP-extension destination, and it is what drives
 * mstatus.FS from Clean or Initial to Dirty. Park FS at each of the three
 * non-Off values, execute one FP-destination instruction, and read FS back.
 *
 * The arm with no FP destination is the control case: a compare or an fcvt to
 * an integer register must not dirty FS.
 * ==================================================================== */
static void g_fs_dirty(u64 r)
{
    const volatile u64 *p = vidu_operands(r);
    u64 fs;

    switch ((unsigned)(r >> 5) & 3u) {
    case 0:  CSR_C(CSR_MSTATUS, MSTATUS_FS); CSR_S(CSR_MSTATUS, VIDU_FS_CLEAN);
             break;
    case 1:  CSR_C(CSR_MSTATUS, MSTATUS_FS); CSR_S(CSR_MSTATUS, VIDU_FS_INIT);
             break;
    case 2:  CSR_C(CSR_MSTATUS, MSTATUS_FS); CSR_S(CSR_MSTATUS, VIDU_FS_DIRTY);
             break;
    default: CSR_C(CSR_MSTATUS, MSTATUS_FS); CSR_S(CSR_MSTATUS, VIDU_FS_CLEAN);
             break;
    }

    if (((unsigned)(r >> 8) & 1u) != 0u) {
        __asm__ volatile ("fld ft0, 0(%0)\n\tfadd.d ft1, ft0, ft0"
                          :: "r"(p) : VIDU_FCLOB, "memory");
    } else {
        /* Integer destination only: the control case. */
        u64 o_;
        __asm__ volatile ("fld ft0, 0(%1)\n\tfclass.d %0, ft0"
                          : "=&r"(o_) : "r"(p) : VIDU_FCLOB, "memory");
        rand_sink += o_;
    }

    fs = CSR_R(CSR_MSTATUS) & MSTATUS_FS;
    vidu_fs_seen |= fs;
    rand_sink += fs;

    /* Back to something every other group can rely on. */
    CSR_C(CSR_MSTATUS, MSTATUS_FS);
    CSR_S(CSR_MSTATUS, VIDU_FS_DIRTY);
}

/* ==================================================================== *
 * Group 29: flush_wbt
 *
 * The scoreboard's asynchronous flush: wb, inst_type and cnt are all reset by
 * rtu_vidu_flush_wbt or rtu_yy_xx_async_flush (aq_vidu_vid_wbt_entry.v:69-116),
 * the split FSM returns to NON_IDLE on the same signal
 * (aq_vidu_vid_split_fp.v:141-147), and fpr_wb_vld is cleared in the forwarding
 * bus (aq_vpu_fwd_wb_rbus.v:489-492). Getting there needs FP work in flight
 * when the pipeline is flushed, which means either a mispredicted branch or a
 * trap.
 *
 * The FP register file is NOT flushed -- aq_vidu_vid_gpr_reg_fp.v has no flush
 * input at all -- so whatever the wrong path wrote stays written. f28..f31 are
 * therefore reserved as the wrong-path destinations, and no other group depends
 * on their contents.
 * ==================================================================== */
static void g_flush_wbt(u64 r)
{
    const volatile u64 *p = vidu_operands(r);
    u64 cond = (r >> 7) & 1u;

    switch ((unsigned)(r >> 5) & 3u) {
    case 0:
        /* Data-dependent branch over FP work. The condition is bit 7 of the
         * random word -- deliberately not bit 0, which is part of the group
         * index and therefore the same value on every hit, i.e. a branch the BHT
         * learns perfectly and never mispredicts. From bit 7 it alternates, so
         * roughly half of these mispredict and flush the scoreboard. */
        __asm__ volatile ("fld ft0, 0(%0)\n\t"
                          "beqz %1, 1f\n\t"
                          "fdiv.d f28, ft0, ft0\n\t"
                          "fld    f29, 8(%0)\n\t"
                          "fadd.d f30, f28, f29\n\t"
                          "1:\n\t"
                          "fadd.d ft1, ft0, ft0"
                          :: "r"(p), "r"(cond) : VIDU_FCLOB, "memory");
        break;
    case 1:
        /* Long-latency op still outstanding when the trap flushes. ecall from M
         * is cause 11, which the shared handler steps over -- and unlike ebreak
         * it is not what the RAND_FORCE_BAIL validation build treats as fatal. */
        __asm__ volatile ("fld ft0, 0(%0)\n\t"
                          "fdiv.d f31, ft0, ft0\n\t"
                          "fld    f28, 8(%0)\n\t"
                          "ecall\n\t"
                          "fadd.d ft1, ft0, ft0"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 2:
        /* Same, flushed by an illegal instruction instead of an ecall. */
        __asm__ volatile ("fld ft0, 0(%0)\n\t"
                          "fsqrt.d f29, ft0\n\t"
                          "fld     f30, 8(%0)\n\t"
                          ".word " STR(INSN_RESERVED) "\n\t"
                          "fadd.d  ft1, ft0, ft0"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    default:
        /* Branch and trap together: FP work on the wrong path AND a trap after
         * the join, so the scoreboard is flushed twice in quick succession. */
        __asm__ volatile ("fld ft0, 0(%0)\n\t"
                          "bnez %1, 1f\n\t"
                          "fmadd.d f31, ft0, ft0, ft0\n\t"
                          "1:\n\t"
                          "fdiv.d f28, ft0, ft0\n\t"
                          "ecall\n\t"
                          "fadd.d ft1, ft0, ft0"
                          :: "r"(p), "r"(cond) : VIDU_FCLOB, "memory");
        break;
    }
}

/* ==================================================================== *
 * Group 30: int_fp_mix
 *
 * aq_idu_id_dp.v:562-580. dp_wb_inst_type_mask is
 *
 *     !(EU_VEC_SEL || EU_FP_SEL)
 *
 * and it masks dp_wbt_dst0_type to zero for anything issued to VIDU. So an
 * FP-to-integer producer -- fmv.x.d, fcvt.w.d, fle.d, fclass.d -- lands in the
 * integer scoreboard typed WB_INT_TYPE_OTHER, which matches none of the
 * ALU/BJU/MULT/LSU forwarding-exception arms. The integer consumer therefore
 * takes the FULL stall no matter how close it is, which is the opposite of what
 * an ALU producer at the same distance would do.
 *
 * Distances 1, 2 and 3 for each of the four producer kinds.
 * ==================================================================== */
#define VIDU_INTFP(PROD, N) do {                                              \
        u64 o_;                                                               \
        __asm__ volatile ("fld ft0, 0(%1)\n\tfld ft1, 8(%1)\n\t"              \
                          PROD VIDU_GAP(N) "add %0, %0, %0\n\t"               \
                          "slli %0, %0, 1"                                    \
                          : "=&r"(o_) : "r"(p) : VIDU_FCLOB, "memory");       \
        rand_sink += o_;                                                      \
    } while (0)

static void g_int_fp_mix(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    switch ((unsigned)(r >> 5) % 12u) {
    case  0: VIDU_INTFP("fmv.x.d  %0, ft0\n\t", 0); break;
    case  1: VIDU_INTFP("fmv.x.d  %0, ft0\n\t", 1); break;
    case  2: VIDU_INTFP("fmv.x.d  %0, ft0\n\t", 2); break;
    case  3: VIDU_INTFP("fcvt.w.d %0, ft0\n\t", 0); break;
    case  4: VIDU_INTFP("fcvt.w.d %0, ft0\n\t", 1); break;
    case  5: VIDU_INTFP("fcvt.w.d %0, ft0\n\t", 2); break;
    case  6: VIDU_INTFP("fle.d    %0, ft0, ft1\n\t", 0); break;
    case  7: VIDU_INTFP("fle.d    %0, ft0, ft1\n\t", 1); break;
    case  8: VIDU_INTFP("fle.d    %0, ft0, ft1\n\t", 2); break;
    case  9: VIDU_INTFP("fclass.d %0, ft0\n\t", 0); break;
    case 10: VIDU_INTFP("fclass.d %0, ft0\n\t", 1); break;
    default: VIDU_INTFP("fclass.d %0, ft0\n\t", 2); break;
    }
}

/* ==================================================================== *
 * Group 31: fld_burst
 *
 * Sixteen FP loads to sixteen distinct registers, then their consumers: the
 * scoreboard at maximum useful occupancy, all VLSU-typed, and the longest
 * window in which wbt_top_fp_gpr_no_wb (aq_vidu_top.v:413) is deasserted.
 * ==================================================================== */
static void g_fld_burst(u64 r)
{
    volatile u64 *b = vidu_base(r);

    (void)vidu_operands(r);
    switch ((unsigned)(r >> 5) & 3u) {
    case 0:
        rand_sink += vidu_sweep_fld_burst(b);
        break;
    case 1:
        /* Cold lines, so all sixteen loads are refills and the entries stay
         * outstanding for far longer. */
        DCACHE_SAFE_POINT();
        rand_sink += vidu_sweep_fld_burst(b);
        break;
    case 2:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfdiv.d ft1, ft0, ft0"
                          :: "r"(b) : VIDU_FCLOB, "memory");
        rand_sink += vidu_sweep_fld_burst(b);
        break;
    default:
        rand_sink += vidu_sweep_fld_burst(b);
        rand_sink += vidu_sweep_fld_burst(&vidu_arena[0]);
        break;
    }
}

/* ==================================================================== *
 * Group 32 (sparse): fs_off
 *
 * THE MOST DANGEROUS GROUP IN THE FILE. Clearing mstatus.FS makes
 *   - every FP arithmetic instruction illegal (fp_fs_illegal,
 *     aq_idu_id_decd.v:952),
 *   - every FP load and store illegal (the trailing `&& (cp0_idu_fs == 2'b00)`
 *     term of decd_flsu_illegal, :921), and
 *   - `csrr fcsr` illegal too.
 *
 * What keeps it recoverable is that the shared trap handler contains no FP
 * instruction of any kind, so it can run with FS off and step over the faulting
 * instruction as usual. The safety rules are therefore: save mstatus first,
 * execute one short probe arm (at most two instructions, so at most two traps),
 * restore FS unconditionally, and then re-baseline. Nothing between the clear
 * and the restore may be anything but inline asm -- in particular no call, since
 * a callee's prologue is free to spill an FP register.
 *
 * GCC's own f8/f9/f18..f27 save and restore for this function sit in the
 * prologue and the epilogue, i.e. outside the window, which is why naming the
 * whole FP file in VIDU_FCLOB is safe here rather than fatal.
 * ==================================================================== */
static void g_fs_off(u64 r)
{
    u64 ms = CSR_R(CSR_MSTATUS);

    vidu_fsoff_probes++;
    CSR_C(CSR_MSTATUS, MSTATUS_FS);         /* FS = Off */

    switch ((unsigned)(r >> 5) % 3u) {
    case 0:
        /* FP arithmetic: fp_fs_illegal. */
        __asm__ volatile ("fadd.d ft0, ft0, ft0" ::: VIDU_FCLOB);
        break;
    case 1:
        /* FP load, then FP store: the FLSU arm of the illegal decode. */
        __asm__ volatile ("fld ft0, 0(%0)\n\tfsd ft0, 8(%0)"
                          :: "r"(&vidu_arena[0]) : VIDU_FCLOB, "memory");
        break;
    default:
        /* The FP CSRs themselves: read and write are both illegal with FS off. */
        __asm__ volatile ("csrr t0, " STR(CSR_FCSR) "\n\t"
                          "csrw " STR(CSR_FFLAGS) ", zero"
                          ::: "t0");
        break;
    }

    /* Unconditional, in this order: FS back to Dirty first so the machine can
     * execute FP again, then the full baseline. */
    CSR_S(CSR_MSTATUS, MSTATUS_FS);
    CSR_W(CSR_MSTATUS, ms | VIDU_FS_DIRTY);
    rand_restore_sane_state();
    rand_pmp_open_everything();
}

/* ==================================================================== *
 * Group 33 (sparse): regfile_walk
 *
 * A distinct pattern into all 32 FP registers, read back through fsd (the srcf2
 * port) and through fmv.x.d (the srcf0 port and the integer scoreboard). This is
 * the whole register file written and read in one pass, which is the cheapest
 * way to move every bit of all 32 x 64 flops in aq_vidu_vid_gpr_reg_fp.v.
 * ==================================================================== */
static void g_regfile_walk(u64 r)
{
    unsigned i;

    /* Fill the low 32 slots with distinct pool values, so the pattern in every
     * register differs from the pattern in every other. */
    for (i = 0; i < 32u; i++)
        vidu_arena[i] = vidu_fp_pool[(i + (unsigned)(r >> 5)) & 31u]
                        ^ ((u64)i << 40);

    switch ((unsigned)(r >> 8) & 1u) {
    case 0:
        rand_sink += vidu_sweep_regfile_walk(&vidu_arena[0]);
        break;
    default:
        rand_sink += vidu_sweep_regfile_walk(&vidu_arena[0]);
        rand_sink += vidu_sweep_regfile_walk(&vidu_arena[0]);
        break;
    }
}

/* ==================================================================== *
 * Group 34 (sparse): denorm
 *
 * Denormals in and denormals out, across add, multiply, divide, square root and
 * conversion, in all three widths. The denormal path is the one place where the
 * FDSU and the FALU can disagree about how long an operation takes, so it is
 * also indirect stimulus for the vex1_stall and fp_full machinery.
 * ==================================================================== */
static void g_denorm(u64 r)
{
    volatile u64 *p = &vidu_arena[0];

    vidu_arena[0] = 0x0000000000000001UL;   /* smallest double denormal   */
    vidu_arena[1] = 0x000fffffffffffffUL;   /* largest double denormal    */
    vidu_arena[2] = 0x0000000100000001UL;   /* float denormals            */
    vidu_arena[3] = 0x0001000100010001UL;   /* half denormals             */
    vidu_arena[4] = 0x0010000000000000UL;   /* smallest double normal     */
    vidu_arena[5] = 0x3ff0000000000000UL;   /* 1.0                        */

    switch ((unsigned)(r >> 5) % 6u) {
    case 0:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 8(%0)\n\t"
                          "fadd.d ft2, ft0, ft1\n\tfsub.d ft3, ft1, ft0\n\t"
                          "fmul.d ft4, ft0, ft1"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 1:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 32(%0)\n\t"
                          "fdiv.d ft2, ft0, ft1\n\tfdiv.d ft3, ft1, ft0\n\t"
                          "fsqrt.d ft4, ft0"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 2:
        __asm__ volatile ("fld ft0, 16(%0)\n\tfld ft1, 40(%0)\n\t"
                          "fadd.s ft2, ft0, ft1\n\tfmul.s ft3, ft0, ft0\n\t"
                          "fdiv.s ft4, ft0, ft1\n\tfsqrt.s ft5, ft0"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 3:
        __asm__ volatile ("fld ft0, 24(%0)\n\tfld ft1, 40(%0)\n\t"
                          "fadd.h ft2, ft0, ft1\n\tfmul.h ft3, ft0, ft0\n\t"
                          "fdiv.h ft4, ft0, ft1\n\tfsqrt.h ft5, ft0"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 4:
        /* Denormal out: scaling the smallest normal down, and the narrowing
         * conversions that turn a normal double into a denormal float or half. */
        __asm__ volatile ("fld ft0, 32(%0)\n\tfld ft1, 40(%0)\n\t"
                          "fdiv.d ft2, ft0, ft1\n\t"
                          "fcvt.s.d ft3, ft0\n\tfcvt.h.d ft4, ft0\n\t"
                          "fcvt.h.s ft5, ft3"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    default: {
        u64 o_;
        __asm__ volatile ("fld ft0, 0(%1)\n\tfld ft1, 8(%1)\n\t"
                          "fcvt.w.d %0, ft0\n\tfcvt.l.d %0, ft1\n\t"
                          "fclass.d %0, ft0\n\tfclass.d %0, ft1"
                          : "=&r"(o_) : "r"(p) : VIDU_FCLOB, "memory");
        rand_sink += o_;
        break;
    }
    }
    vidu_flags_seen |= CSR_R(CSR_FFLAGS) & 0x1FUL;
    CSR_W(CSR_FCSR, 0);
}

/* ==================================================================== *
 * Group 35 (sparse): nan_prop
 *
 * Signalling and quiet NaN propagation, and the T-Head fxcr default-NaN
 * control. fxcr's dqnan bit is bit 23 (see the FXCR_WMASK derivation in
 * rand_csrs.h and the FPUQNANCH macro at C906_FPU_SMOKE.s:26-33, which builds
 * the same field by masking with 0xff7fffff and OR-ing imm << 23), and it
 * changes which NaN the FPU produces. Toggled here with both polarities and
 * restored.
 *
 * frm is deliberately masked out of every fxcr write: fxcr[26:24] IS frm, and
 * writing 5, 6 or 7 there has exactly the trap-storm consequence documented at
 * group 25.
 * ==================================================================== */
static void g_nan_prop(u64 r)
{
    u64 old_fxcr = CSR_R(CSR_FXCR);
    volatile u64 *p = &vidu_arena[0];

    vidu_arena[0] = 0x7ff8000000000000UL;   /* qNaN                       */
    vidu_arena[1] = 0x7ff4000000000000UL;   /* sNaN                       */
    vidu_arena[2] = 0xfff4000000000000UL;   /* -sNaN                      */
    vidu_arena[3] = 0x3ff0000000000000UL;   /* 1.0                        */
    vidu_arena[4] = 0x7fc000007fa00000UL;   /* float qNaN | float sNaN    */
    vidu_arena[5] = 0x7e007d007e007d00UL;   /* half qNaN | half sNaN      */

    /* dqnan only; never the frm field. */
    if (((unsigned)(r >> 5) & 1u) != 0u)
        CSR_S(CSR_FXCR, 1UL << 23);
    else
        CSR_C(CSR_FXCR, 1UL << 23);

    CSR_W(CSR_FFLAGS, 0);
    switch ((unsigned)(r >> 6) % 4u) {
    case 0:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfld ft1, 24(%0)\n\t"
                          "fadd.d ft2, ft0, ft1\n\tfmul.d ft3, ft0, ft1\n\t"
                          "fdiv.d ft4, ft0, ft1\n\tfsqrt.d ft5, ft0\n\t"
                          "fmadd.d ft6, ft0, ft1, ft0"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 1:
        /* sNaN: raises NV and must be quietened on the way out. */
        __asm__ volatile ("fld ft0, 8(%0)\n\tfld ft1, 24(%0)\n\t"
                          "fadd.d ft2, ft0, ft1\n\tfmul.d ft3, ft0, ft1\n\t"
                          "fmin.d ft4, ft0, ft1\n\tfmax.d ft5, ft0, ft1\n\t"
                          "fsgnj.d ft6, ft0, ft1"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 2:
        __asm__ volatile ("fld ft0, 32(%0)\n\tfld ft1, 40(%0)\n\t"
                          "fadd.s ft2, ft0, ft0\n\tfmul.s ft3, ft0, ft0\n\t"
                          "fadd.h ft4, ft1, ft1\n\tfmul.h ft5, ft1, ft1\n\t"
                          "fcvt.s.d ft6, ft0\n\tfcvt.h.s ft7, ft6"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    default: {
        u64 o_;
        /* Compares against NaN: feq must be quiet, flt and fle must signal. */
        __asm__ volatile ("fld ft0, 0(%1)\n\tfld ft1, 8(%1)\n\t"
                          "feq.d %0, ft0, ft1\n\tflt.d %0, ft0, ft1\n\t"
                          "fle.d %0, ft0, ft1\n\tfclass.d %0, ft1"
                          : "=&r"(o_) : "r"(p) : VIDU_FCLOB, "memory");
        rand_sink += o_;
        break;
    }
    }
    vidu_flags_seen |= CSR_R(CSR_FFLAGS) & 0x1FUL;

    CSR_W(CSR_FXCR, old_fxcr & FXCR_WMASK);
    CSR_W(CSR_FCSR, 0);
}

/* ==================================================================== *
 * Group 36 (sparse): h_precision
 *
 * Zfh at every rounding mode. Half is the least-covered width in
 * C906_FPU_SMOKE.s -- 4 fsqrt.h, no fsgnj.h, no fmv.x.h -- so the sweep in
 * vidu_sweeps.S crosses all six rm encodings with every Zfh op that has an rm
 * field, and follows it with the ones that do not.
 * ==================================================================== */
static void g_h_precision(u64 r)
{
    unsigned i;

    for (i = 0; i < 8u; i++)
        vidu_arena[i] = vidu_half_pool[(i + (unsigned)(r >> 5)) & 7u];

    switch ((unsigned)(r >> 8) & 3u) {
    case 0:
        vidu_sweep_h_all_rm(&vidu_arena[0]);
        break;
    case 1:
        CSR_W(CSR_FRM, (r >> 16) % 5u);
        vidu_sweep_h_all_rm(&vidu_arena[0]);
        CSR_W(CSR_FCSR, 0);
        break;
    case 2:
        CSR_W(CSR_FFLAGS, 0);
        vidu_sweep_h_all_rm(&vidu_arena[0]);
        vidu_flags_seen |= CSR_R(CSR_FFLAGS) & 0x1FUL;
        break;
    default:
        vidu_sweep_h_all_rm(&vidu_arena[4]);
        break;
    }
    CSR_W(CSR_FCSR, 0);
}

/* ==================================================================== *
 * Group 37 (sparse): fp_traps
 *
 * FP work immediately before and immediately after a synchronous trap, so that
 * in-flight FP instructions are killed by rtu_yy_xx_async_flush and the ones
 * after it start from a flushed scoreboard. Group 29 attacks the flush from the
 * scoreboard side; this one is about the boundary itself, and about the fact
 * that the trap handler runs with FP state live behind it.
 * ==================================================================== */
static void g_fp_traps(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    switch ((unsigned)(r >> 5) & 3u) {
    case 0:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfadd.d ft1, ft0, ft0\n\t"
                          "ecall\n\t"
                          "fmul.d ft2, ft1, ft1\n\tfsd ft2, 48(%0)"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 1:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfdiv.d ft1, ft0, ft0\n\t"
                          ".word " STR(INSN_RESERVED) "\n\t"
                          "fadd.d ft2, ft1, ft1"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 2:
        /* Two traps back to back with FP work sandwiched between them. */
        __asm__ volatile ("fld ft0, 0(%0)\n\t"
                          "ecall\n\t"
                          "fsqrt.d ft1, ft0\n\t"
                          ".word " STR(INSN_HFENCE_VVMA) "\n\t"
                          "fadd.d ft2, ft1, ft1"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    default:
        /* A trap taken while the skid buffer is occupied: long-latency op,
         * dependent op stalling dispatch, then a third FP op and the trap. */
        __asm__ volatile ("fld ft0, 0(%0)\n\t"
                          "fdiv.d ft1, ft0, ft0\n\t"
                          "fadd.d ft2, ft1, ft1\n\t"
                          "fmul.d ft3, ft0, ft0\n\t"
                          "ecall\n\t"
                          "fadd.d ft4, ft0, ft0"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    }
}

/* ==================================================================== *
 * Group 38 (sparse): fsd_data_dep
 *
 * Both polarities of dp_dis_fp_inst_srcf2_rdy (aq_vidu_vid_dp_fp.v:322-324):
 *
 *     srcv2_info[WB_VEC_VLD] || srcf2_fwd_vld || !DIS_VEC_SRCF2_VLD
 *
 * An FP store whose data register was just written by a long-latency op has
 * none of the three -- the scoreboard entry is not valid, the forward bus does
 * not have it yet, and the store certainly does have a srcf2 -- so it is the
 * only clean way to hold srcf2_rdy low. Giving the producer time to retire, or
 * using a store with a ready register, drives it high.
 * ==================================================================== */
static void g_fsd_data_dep(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    switch ((unsigned)(r >> 5) % 6u) {
    case 0:  /* not ready: fdiv immediately before the store */
        __asm__ volatile ("fld ft0, 0(%0)\n\tfdiv.d ft1, ft0, ft0\n\t"
                          "fsd ft1, 48(%0)"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 1:  /* not ready: fsqrt, and a .w store so the width differs */
        __asm__ volatile ("fld ft0, 0(%0)\n\tfsqrt.d ft1, ft0\n\t"
                          "fsw ft1, 48(%0)"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 2:  /* ready: 24 instructions of slack lets the producer retire */
        __asm__ volatile ("fld ft0, 0(%0)\n\tfdiv.d ft1, ft0, ft0\n\t"
                          VIDU_GAP(24)
                          "fsd ft1, 48(%0)"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 3:  /* ready by forwarding: short producer, distance 1 */
        __asm__ volatile ("fld ft0, 0(%0)\n\tfadd.d ft1, ft0, ft0\n\t"
                          "fsd ft1, 48(%0)"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 4:  /* ready trivially: the store data comes straight from a load */
        __asm__ volatile ("fld ft0, 0(%0)\n\tfsd ft0, 48(%0)\n\t"
                          "fld ft1, 8(%0)\n\tfsh ft1, 56(%0)"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    default: /* a run of dependent stores, alternating polarity */
        __asm__ volatile ("fld ft0, 0(%0)\n\t"
                          "fdiv.d ft1, ft0, ft0\n\tfsd ft1, 48(%0)\n\t"
                          "fadd.d ft2, ft0, ft0\n\tfsd ft2, 56(%0)\n\t"
                          "fsqrt.d ft3, ft0\n\tfsd ft3, 64(%0)\n\t"
                          "fmul.d ft4, ft0, ft0\n\tfsd ft4, 72(%0)"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    }
}

/* ==================================================================== *
 * Group 39 (sparse): fp_lowpower
 *
 * FP work across the low-power boundary: split_clk_en
 * (aq_vidu_vid_split_fp.v:263-266, which is warm_up || fp_gateclk_sel ||
 * FSM not idle) and fpr_wb_clk_en (aq_vpu_fwd_wb_rbus.v:468) both go away when
 * the core enters LPMD, so an FP op immediately before a WFI and another
 * immediately after it is the only way to see the gated clocks stop and restart
 * with state to preserve.
 *
 * WFI is only safe with a wake source armed: the LPMD wake condition is
 * |(mie & mip) and it is privilege- and delegation-blind, so a WFI with nothing
 * armed is unrecoverable short of reset. rand_arm_lpmd_wake() delegates STIP
 * with sstatus.SIE clear, which satisfies the wake condition without any
 * privilege level being willing to take the interrupt.
 * ==================================================================== */
static void g_fp_lowpower(u64 r)
{
    const volatile u64 *p = vidu_operands(r);

    vidu_wfi++;
    rand_arm_lpmd_wake();
    switch ((unsigned)(r >> 5) & 3u) {
    case 0:
        __asm__ volatile ("fld ft0, 0(%0)\n\tfadd.d ft1, ft0, ft0\n\t"
                          "wfi\n\t"
                          "fmul.d ft2, ft1, ft1"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 1:
        /* Long-latency op still in the vfdsu when the WFI arrives. */
        __asm__ volatile ("fld ft0, 0(%0)\n\tfdiv.d ft1, ft0, ft0\n\t"
                          "wfi\n\t"
                          "fadd.d ft2, ft1, ft1"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    case 2:
        /* Skid buffer occupied across the boundary. */
        __asm__ volatile ("fld ft0, 0(%0)\n\tfsqrt.d ft1, ft0\n\t"
                          "fadd.d ft2, ft1, ft1\n\tfmul.d ft3, ft0, ft0\n\t"
                          "wfi\n\t"
                          "fadd.d ft4, ft0, ft0"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    default:
        /* FP store in flight, so the FLSU rather than the FALU is what has to
         * survive the clock stopping. */
        __asm__ volatile ("fld ft0, 0(%0)\n\tfsd ft0, 48(%0)\n\t"
                          "wfi\n\t"
                          "fld ft1, 48(%0)\n\tfadd.d ft2, ft1, ft1"
                          :: "r"(p) : VIDU_FCLOB, "memory");
        break;
    }
    rand_disarm_lpmd_wake();
}

/* ==================================================================== *
 * Group 40 (sparse): fcsr_csr_forms
 *
 * All six CSR access forms -- csrrw / csrrs / csrrc and their immediate
 * variants -- on fflags, frm, fcsr and fxcr, with FP work in flight on either
 * side. cp0_random already covers these CSRs with an idle FPU; what is new here
 * is that the read-modify-write happens while VIDU still has instructions
 * outstanding, which is the only way the CSR read and the FPU's own flag update
 * can race.
 *
 * The random value is masked to the writable bits of each CSR. Every arm that
 * writes frm outright (cases 6, 9, 10 and the fxcr case) keeps it in 0..4; the
 * two immediate read-modify-write arms (7 and 8) cannot promise that, because
 * `csrrsi frm, 4` lands on 5..7 whenever frm arrives at 1..3. That is deliberate
 * and it is bounded, not the group-25 trap storm: frm is restored two statements
 * later, so the worst case is the four dynamic-rounding ops of the trailing
 * VIDU_FP_INFLIGHT() taking an illegal-instruction trap each. In practice frm is
 * 0 on entry -- every group restores fcsr -- so case 7 yields rmm.
 * ==================================================================== */
#define VIDU_FP_INFLIGHT(p)                                                   \
        __asm__ volatile ("fld ft0, 0(%0)\n\tfdiv.d ft1, ft0, ft0\n\t"        \
                          "fsqrt.d ft2, ft0\n\tfmadd.d ft3, ft0, ft0, ft0"    \
                          :: "r"(p) : VIDU_FCLOB, "memory")

static void g_fcsr_csr_forms(u64 r)
{
    const volatile u64 *p = vidu_operands(r);
    u64 old_fcsr = CSR_R(CSR_FCSR);
    u64 old_fxcr = CSR_R(CSR_FXCR);
    /* fcsr[7:5] is frm: keep it in 0..4. */
    u64 v = (r & 0x1FUL) | (((r >> 8) % 5u) << FCSR_FRM_SHIFT);

    VIDU_FP_INFLIGHT(p);
    switch ((unsigned)(r >> 5) % 12u) {
    case  0: rand_sink += CSR_RW(CSR_FFLAGS, r & 0x1FUL);            break;
    case  1: rand_sink += CSR_RS(CSR_FFLAGS, r & 0x1FUL);            break;
    case  2: rand_sink += CSR_RC(CSR_FFLAGS, r & 0x1FUL);            break;
    case  3: rand_sink += CSR_RWI(CSR_FFLAGS, 0x1f);                 break;
    case  4: rand_sink += CSR_RSI(CSR_FFLAGS, 0x0f);                 break;
    case  5: rand_sink += CSR_RCI(CSR_FFLAGS, 0x00);                 break;
    case  6: rand_sink += CSR_RW(CSR_FRM, (r >> 8) % 5u);            break;
    case  7: rand_sink += CSR_RSI(CSR_FRM, 0x04);                    break;
    case  8: rand_sink += CSR_RCI(CSR_FRM, 0x03);                    break;
    case  9: rand_sink += CSR_RW(CSR_FCSR, v);                       break;
    case 10: rand_sink += CSR_RC(CSR_FCSR, v);                       break;
    /* fxcr: dqnan (23), fe (5) and fflags (4:0) only. Bit 31 (bf16) and
     * bits 26:24 (frm) are deliberately excluded -- bf16 changes the FPU's
     * interpretation of every operand, and frm has the group-25 problem. */
    default: rand_sink += CSR_RW(CSR_FXCR, r & 0x0080003FUL);        break;
    }
    VIDU_FP_INFLIGHT(p);

    vidu_flags_seen |= CSR_R(CSR_FFLAGS) & 0x1FUL;
    CSR_W(CSR_FXCR, old_fxcr & FXCR_WMASK);
    CSR_W(CSR_FCSR, old_fcsr & 0xFFUL);
    CSR_W(CSR_FCSR, 0);
}

/* ==================================================================== *
 * Group 41 (sparse): report_probe
 *
 * Reads every FP-visible piece of architectural state and folds it into
 * rand_sink and the report counters. Not a coverage group in its own right --
 * its job is to make sure the end-of-run summary is reporting live values, and
 * to keep a read of every FP CSR on the randomised path rather than only in
 * report().
 * ==================================================================== */
static void g_report_probe(u64 r)
{
    const volatile u64 *p = vidu_operands(r);
    u64 o_;

    __asm__ volatile ("fld ft0, 0(%1)\n\t"
                      "fadd.d ft1, ft0, ft0\n\t"
                      "fmv.x.d %0, ft1"
                      : "=&r"(o_) : "r"(p) : VIDU_FCLOB, "memory");
    rand_sink += o_;

    switch ((unsigned)(r >> 5) & 3u) {
    case 0:  vidu_flags_seen |= CSR_R(CSR_FFLAGS) & 0x1FUL;   break;
    case 1:  rand_sink += CSR_R(CSR_FRM);                     break;
    case 2:  rand_sink += CSR_R(CSR_FCSR);                    break;
    default: rand_sink += CSR_R(CSR_FXCR);                    break;
    }
    vidu_fs_seen |= CSR_R(CSR_MSTATUS) & MSTATUS_FS;
    rand_sink += vidu_regs_touched + vidu_flags_seen;
}

/* ==================================================================== *
 * Dispatch
 * ==================================================================== */
static void dispatch(u64 r)
{
#ifdef VIDU_ONLY_GROUP
    /* Debug aid: build with -DVIDU_ONLY_GROUP=n to run just one group, which is
     * how a group that hangs or misbehaves gets isolated. Groups 0..31 are the
     * main rotation; 32..41 are the sparse second selector.
     * tests/cases/vidu_random/run_groups.sh drives this. */
    unsigned g = (VIDU_ONLY_GROUP);
#else
    unsigned g = (unsigned)(r % NGROUPS);
#endif

    if (g < NGROUPS_TOTAL) group_hits[g]++;

    switch (g) {
    case 0:  g_raw_src0(r);           break;
    case 1:  g_raw_src1(r);           break;
    case 2:  g_raw_src2(r);           break;
    case 3:  g_fwd_except(r);         break;
    case 4:  g_fwd_except_vlsu(r);    break;
    case 5:  g_store_src2_except(r);  break;
    case 6:  g_waw(r);                break;
    case 7:  g_waw_except_2fld(r);    break;
    case 8:  g_wbt_all_regs(r);       break;
    case 9:  g_split_skid(r);         break;
    case 10: g_fp_full(r);            break;
    case 11: g_fpload_dual_full(r);   break;
    case 12: g_vex1_stall(r);         break;
    case 13: g_wb_priority(r);        break;
    case 14: g_flsu_std(r);           break;
    case 15: g_flsu_c(r);             break;
    case 16: g_flsu_xtheadc(r);       break;
    case 17: g_arith_short(r);        break;
    case 18: g_arith_fma(r);          break;
    case 19: g_arith_long(r);         break;
    case 20: g_cvt(r);                break;
    case 21: g_cmp_class(r);          break;
    case 22: g_sgnj_minmax(r);        break;
    case 23: g_fmv(r);                break;
    case 24: g_frm_static(r);         break;
    case 25: g_frm_dynamic(r);        break;
    case 26: g_rm_illegal(r);         break;
    case 27: g_fflags(r);             break;
    case 28: g_fs_dirty(r);           break;
    case 29: g_flush_wbt(r);          break;
    case 30: g_int_fp_mix(r);         break;
    case 31: g_fld_burst(r);          break;
    /* 32..41 are only reachable through -DVIDU_ONLY_GROUP; in a normal run they
     * come from the sparse selector below. */
    case 32: g_fs_off(r);             break;
    case 33: g_regfile_walk(r);       break;
    case 34: g_denorm(r);             break;
    case 35: g_nan_prop(r);           break;
    case 36: g_h_precision(r);        break;
    case 37: g_fp_traps(r);           break;
    case 38: g_fsd_data_dep(r);       break;
    case 39: g_fp_lowpower(r);        break;
    case 40: g_fcsr_csr_forms(r);     break;
    case 41: g_report_probe(r);       break;
    default: break;
    }

#ifndef VIDU_ONLY_GROUP
    /* The remaining groups are rarer, more expensive or more fragile -- fs_off
     * guarantees a trap per probe, fp_lowpower stops the clock -- so they ride a
     * second, sparser selector rather than diluting the main rotation: 10 arms
     * out of 64, i.e. each fires on about 1 iteration in 410.
     *
     * The field is bits [53:48], NOT bits [37:32]. Sharing [36:32] with
     * VIDU_FP_SWITCH() would mean that on every iteration a sparse group fires,
     * the main group's FP register is forced into f0..f9 -- the register sweep
     * and the sparse selector would be the same six bits. */
    switch ((unsigned)((r >> 48) % 64u)) {
    case 0:  g_fs_off(r);           group_hits[32]++; break;
    case 1:  g_regfile_walk(r);     group_hits[33]++; break;
    case 2:  g_denorm(r);           group_hits[34]++; break;
    case 3:  g_nan_prop(r);         group_hits[35]++; break;
    case 4:  g_h_precision(r);      group_hits[36]++; break;
    case 5:  g_fp_traps(r);         group_hits[37]++; break;
    case 6:  g_fsd_data_dep(r);     group_hits[38]++; break;
    case 7:  g_fp_lowpower(r);      group_hits[39]++; break;
    case 8:  g_fcsr_csr_forms(r);   group_hits[40]++; break;
    case 9:  g_report_probe(r);     group_hits[41]++; break;
    default: break;
    }
#endif
}

/* ==================================================================== *
 * End-of-run summary over the UART.
 *
 * Diagnostics only: PASS/FAIL is the GPR magic value crt0.s materialises, and
 * the real evidence of VIDU stimulus is the port-toggle report. What this print
 * adds is the two things a toggle report cannot show -- which FP registers the
 * randomised path actually selected, and whether the trap causes are the ones
 * the groups asked for.
 * ==================================================================== */
static void report(void)
{
    unsigned i;

    rand_restore_sane_state();
    rand_report_begin();

    rand_puts("\n[vidu_random] iters=");
    rand_putu(rand_iter);
    rand_puts(" regs=0x");
    rand_putx(vidu_regs_touched & 0xFFFFFFFFUL);
    rand_puts(" fflags_seen=0x");
    rand_putx(vidu_flags_seen);
    rand_puts(" fs_seen=0x");
    rand_putx(vidu_fs_seen);

    rand_puts("\n[vidu_random] rm_illegal=");
    rand_putu(vidu_rm_illegal);
    rand_puts(" frm_illegal=");
    rand_putu(vidu_frm_illegal);
    rand_puts(" fsoff=");
    rand_putu(vidu_fsoff_probes);
    rand_puts(" wfi=");
    rand_putu(vidu_wfi);

    rand_puts("\n[vidu_random] groups:");
    for (i = 0; i < NGROUPS_TOTAL; i++) {
        rand_putc(' ');
        rand_putu(group_hits[i]);
    }

    rand_hist_dump("vidu_random");

    /* An informational fingerprint of every result the run produced. It is NOT
     * compared against anything -- there is no golden model in this test -- and
     * it exists so the compiler cannot delete the instructions that fed it. */
    rand_puts("[vidu_random] sink=0x");
    rand_putx(rand_sink);
    rand_putc('\n');

    rand_report_end();
}

/* ==================================================================== *
 * main
 * ==================================================================== */
int main(void)
{
    unsigned i;

    rand_srand((u64)VIDU_SEED);
    rand_trap_init();               /* FIRST: clears MIE, installs mtvec */
    rand_pmp_open_everything();
    rand_restore_sane_state();

    /* BEFORE ANYTHING ELSE TOUCHES FP. All 32 FP registers are X at entry:
     * crt0.s writes none of them and aq_vidu_vid_gpr_reg_fp.v:86-88 is an
     * unreset flop. Under Verilator's 2-state model this call is invisible;
     * under VCS it is the difference between a run that stimulates VIDU and a
     * run whose forwarding comparators and scoreboard reads are X-poisoned from
     * the first fadd onwards. */
    vidu_zero_all_fp();

    /* Fill the arena so no FP load reads a plain zero unless a group asked for
     * one. tb.v:98 wipes the SRAM, so the alternative is 2560 bytes of +0.0. */
    for (i = 0; i < VIDU_ARENA_N; i++)
        vidu_arena[i] = vidu_fp_pool[i & 31u] ^ ((u64)i << 32);

    for (rand_iter = 0; rand_iter < (u64)VIDU_ITERS; rand_iter++) {
        /* Landing pad for the trap handler's bail-out path. */
        if (rand_setjmp() != 0) {
            rand_recovered++;
            rand_restore_sane_state();
            rand_pmp_open_everything();
            continue;
        }

        dispatch(rand_rnd());

        if ((rand_iter & 0xFFFu) == 0u) {
            rand_restore_sane_state();
            rand_pmp_open_everything();
        }
    }

    rand_restore_sane_state();
    report();

    /* Returning lands in crt0.s __exit, which materialises the PASS magic the
     * testbench is watching the RTU writeback buses for. */
    return 0;
}
