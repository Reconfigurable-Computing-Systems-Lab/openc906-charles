/*
 * iu_random -- randomized stress test for the OpenC906 integer unit
 * (C906_RTL_FACTORY/gen_rtl/iu/rtl/: aq_iu_alu.v, aq_iu_bju.v, aq_iu_mul.v,
 * aq_iu_div.v, aq_iu_div_shift2_kernel.v), plus the two structures outside the
 * IU that only the IU can exercise: the IDU's three forward comparators
 * (gen_rtl/idu/rtl/aq_idu_id_dp.v:639-727) and the RTU's EX1 forward priority
 * mux (gen_rtl/rtu/rtl/aq_rtu_rbus.v:290-311).
 *
 * Executes IU_ITERS (default 20000) dynamic iterations of a seeded xorshift64
 * dispatch loop. Each iteration picks one of 44 operation groups: 32 on the main
 * rotation, 12 on a sparser second selector for the expensive or deliberately
 * pipeline-perturbing ones.
 *
 * WHAT THIS TEST IS
 * -----------------
 * A *stimulus generator*. Every group aims a specific, RTL-read structure --
 * a mux arm, a casez arm, an FSM edge, a comparator, a forwarding path -- and
 * feeds it operands chosen so that arm is actually selected. Each group comment
 * names the structure and its file:line.
 *
 * WHAT THIS TEST IS NOT
 * ---------------------
 * There is deliberately NO golden model, NO self-check and NO expected-value
 * comparison. PASS means the program ran to completion (main returns ->
 * crt0.s __exit -> the magic value the testbench watches the RTU writeback
 * buses for). Results are folded into rand_sink purely so the compiler cannot
 * dead-code the instruction under test; the printed value of rand_sink is an
 * informational fingerprint and is NOT compared against anything, here or
 * anywhere else. Arithmetic correctness is somebody else's test. The evidence
 * that the IU was stimulated is work/iu_toggle.report, produced by the
 * port-toggle monitor bound into the testbench via tests/cases/iu_random/iu_mon.f.
 *
 * Robustness, not correctness, is therefore the design constraint:
 *   - the dispatch loop is wrapped in rand_setjmp(), so any unexpected or
 *     nested trap costs one iteration rather than the run;
 *   - rand_restore_sane_state() re-baselines the machine every 4096 iterations
 *     and after every recovery;
 *   - mstatus.MIE stays 0 throughout -- no group here arms an interrupt;
 *   - every raw instruction word is built from a whitelisted base in
 *     rand_common/rand_th_insn.h with pinned register fields (a0/a1/a2, all in
 *     rand_safe_regs). A rand_rnd() value is never executed as an instruction:
 *     a random word can be wfi, csrw mtvec, a wild store or an mret.
 *
 * KNOWN-UNREACHABLE IN THE IU -- do not re-litigate
 * -------------------------------------------------
 *  1. FUNC_MIN / MAX / MINU / MAXU / MINW / MAXW / MINUW / MAXUW
 *     (aq_idu_cfig.h:333-340) are never emitted by the decoder -- there is no
 *     casez arm for them in aq_idu_id_decd.v -- and the max/min datapath in
 *     aq_iu_alu.v is commented out (:246-247, :254-255, :258-264). So the
 *     *decode* arms are dead, and so is the alu_adder_sel_rst mux input.
 *     NOT a consequence: arm 5'b01000 ("unsign 32 op") of
 *     alu_adder_rs0_sel_onehot (:210) and alu_adder_rs1_sel_onehot (:231) is
 *     still reachable. alu_func[16] is that arm's one-hot bit in both
 *     (:198-199), and alu_func[16] is ALSO alu_shift_high_zero (:302) -- set by
 *     FUNC_SLL / SLLI / SLLW / SLLIW / C_SLLI (aq_idu_cfig.h:345-348, :440).
 *     A left shift therefore selects arm 5'b01000 in both adder one-hots (the
 *     adder result is discarded, but the mux arm is taken), which groups 3, 4
 *     and 31 already do on every dispatch. Do not chase MINUW/MAXUW to cover
 *     it, and do not report it as a hole.
 *  2. Every `default: {N{1'bx}}` arm. Those are X-traps for illegal one-hot
 *     encodings; reaching one would mean the decoder is broken, and the
 *     resulting X would poison the simulation rather than report anything.
 *  3. The ifu_iu_warm_up reset paths (e.g. aq_iu_bju.v:492, :542, :552;
 *     aq_iu_mul.v:568, :576; aq_iu_div.v:232, :353). Asserted only during the
 *     post-reset warm-up window, before main() exists.
 *  4. Anything gated on rtu_yy_xx_dbgon. Debug mode is entered over JTAG only;
 *     tests/cases/debug/ covers it with its own driver.
 *
 * RTL-READ CORRECTIONS to the original group plan, recorded so they are not
 * "fixed" back:
 *  a. The word-overflow near-miss cannot be reached with a register value of
 *     0x0000_0000_8000_0000 and a *word* opcode: div_dividend for divw/remw is
 *     sign-extended from bit 31 (aq_iu_div.v:209), so that register value
 *     becomes exactly 0xffff_ffff_8000_0000 -- the overflow constant (:334).
 *     The genuine near-miss is that value with a *64-bit* signed div, and for
 *     the word forms it is a divisor whose word value is not -1. Both are in
 *     g_div_special().
 *  b. th.addsl's src2 is an *immediate* (decd_perf_src2_imm_vld,
 *     aq_idu_id_decd.v:3193), and the operand mux gives the immediate priority
 *     over the forward bus (aq_idu_id_dp.v:784-789). So th.addsl is not a src2
 *     forwarding target; the real src2 consumers are th.mula/muls/mulaw/mulsw/
 *     mulah/mulsh, th.mveqz/mvnez (src2 == rd, aq_idu_id_decd.v:699-718) and
 *     store data (src2 == inst[24:20], :699-701).
 *  c. auipc is always 4 bytes, so it can only ever take the 32-bit arm of the
 *     inc-pc adder select (aq_iu_bju.v:581-582). The 16-bit arm needs a
 *     *compressed* BJU instruction; that is what iu_bju_rvc_jumps() and
 *     iu_bju_c_branch() are for. What auipc does vary is the PC alignment
 *     feeding bju_cur_pc_ext (:572).
 *
 * SIMULATION TIME. The testbench default is MAX_RUN_TIME 3e9 ns with
 * CLK_PERIOD 1.0, i.e. about 3 M cycles -- roughly 150 cycles per iteration at
 * IU_ITERS=20000. The unrolled sweeps are 64 instructions each and the divider
 * groups issue 8-24 divisions per call, so a full-length run needs
 * `+MAX_SIM_TIME=2e10` or a smaller IU_ITERS. Groups that would otherwise blow
 * the budget take a rand-selected *slice* of their sweep per call (IU_SLICE);
 * over the whole run the slices tile the range.
 */

#include "iu_defs.h"

/* ==================================================================== *
 * State
 * ==================================================================== */
static volatile u64 group_hits[IU_NGROUPS_TOTAL];

/* Unit-specific counters. Diagnostics only -- nothing is compared. */
static volatile u64 iu_sweep_calls;
static volatile u64 iu_div_ops;
static volatile u64 iu_mul_ops;
static volatile u64 iu_br_execs;

/* Load-dependent-branch and cache-miss playground. 32 KB with a 4 KB stride
 * gives eight addresses that all map to the same D-cache set, so after the
 * first pass every access in the stride walk misses -- which is what puts a
 * multi-cycle load in front of a conditional branch and forces the BJU's
 * one-entry replay path (aq_iu_bju.v:462-484). It lives in .bss, i.e. inside
 * the SRAM window tb.v:98 wipes, so it is never read as X. */
#define IU_ARENA_U64  4096u
#define IU_ARENA_STEP  512u             /* 512 * 8 B == 4 KB */
static volatile u64 iu_arena[IU_ARENA_U64];

#ifdef IU_ENABLE_JUMP8M
/* Runtime-assembled trampoline for the >8 MB jump group. In .bss so it is
 * inside the loaded/wiped window; 64-byte aligned so it occupies exactly one
 * I-cache line (ifu_biu_arlen == 2'b11, aq_ifu_icache.v:1363). Only compiled
 * when the group is enabled -- with the gate off none of this is referenced. */
static u32 iu_tramp[16] __attribute__((aligned(64)));

/* ==================================================================== *
 * Small instruction builders for the two runtime-assembled stubs. Only
 * lui/addi/jalr are needed, and only with a compile-time-known shape -- these
 * are not a code generator, they materialise one fixed three-instruction
 * sequence whose only variable is an address.
 * ==================================================================== */
#define IU_NOP_WORD  0x00000013u        /* addi x0, x0, 0 */

static u32 iu_hi20(u64 addr)
{
    return (u32)(((addr + 0x800UL) >> 12) & 0xFFFFFUL);
}

static long iu_lo12(u64 addr)
{
    u64 hi = (addr + 0x800UL) >> 12;
    return (long)(s64)(addr - (hi << 12));
}

static u32 iu_enc_lui(unsigned rd, u64 addr)
{
    return 0x37u | (rd << 7) | (iu_hi20(addr) << 12);
}

static u32 iu_enc_addi(unsigned rd, unsigned rs1, long imm)
{
    return 0x13u | (rd << 7) | (rs1 << 15) | (u32)(((u64)imm & 0xFFFUL) << 20);
}

static u32 iu_enc_jalr(unsigned rd, unsigned rs1)
{
    return 0x67u | (rd << 7) | (rs1 << 15);
}
#endif /* IU_ENABLE_JUMP8M */

/* ==================================================================== *
 * Group 0: add / sub -- the adder operand-preparation one-hots
 *
 * alu_adder_rs0_sel_onehot / alu_adder_rs1_sel_onehot (aq_iu_alu.v:198-199)
 * select four reachable arms each:
 *   rs0 5'b00001 zero        (li / lui / c.li / c.lui)      :207
 *       5'b00010 unsign 64   (sltu / sltiu only)            :208
 *       5'b00100 sign 32     (addw / addiw / subw)          :209
 *       5'b10000 sign 64     (add / addi / sub / ...)       :211
 *   rs1 5'b00001 imm << 12   (only adder producer is c.lui,  :228
 *                             see IU_C_LUI_A0; th.srriw also
 *                             sets func[13] and so takes the
 *                             arm, with its adder rst unused)
 *       5'b00010 unsign 64                                  :229
 *       5'b00100 sign 32                                    :230
 *       5'b10000 sign 64                                    :232
 * plus alu_adder_cin (:240), alu_adder_op_sub's ones-complement (:220) and the
 * three-arm result mux (:273-278). Sixteen ops x eight operand classes.
 * ==================================================================== */
static void g_add_sub(u64 r)
{
    u64 a, b, q = 0;

    iu_operands(r, (unsigned)(r >> 8), &a, &b);

    switch ((unsigned)(r >> 12) % 16u) {
    case 0:  IU_R2("add",  q, a, b);        break;
    case 1:  IU_RI("addi", q, a, 2047);     break;
    case 2:  IU_RI("addi", q, a, -2048);    break;
    case 3:  IU_R2("addw", q, a, b);        break;   /* rs0/rs1 arm 00100 */
    case 4:  IU_RI("addiw", q, a, 2047);    break;
    case 5:  IU_RI("addiw", q, a, -2048);   break;
    case 6:  IU_R2("sub",  q, a, b);        break;   /* op_sub -> cin (:220) */
    case 7:  IU_R2("subw", q, a, b);        break;
    case 8:  __asm__ volatile ("lui %0, 0x80000" : "=r"(q)); break; /* rs0 00001 */
    case 9:  IU_C_LUI_A0();                 break;   /* rs1 arm 00001, only route */
    case 10: q = a; __asm__ volatile ("add %0, %0, %1" : "+r"(q) : "r"(b)); break;
    case 11: q = a; __asm__ volatile ("addi %0, %0, 1" : "+r"(q)); break;
    case 12: __asm__ volatile ("mv %0, %1" : "=r"(q) : "r"(a)); break;
    case 13: __asm__ volatile ("li %0, 31" : "=r"(q)); break;  /* rs0 00001 */
    case 14: IU_R2("add", q, a, a);         break;   /* both operands identical */
    default: IU_R2("sub", q, a, a);         break;   /* exact zero, cin == 1   */
    }
    rand_sink += q;
}

/* ==================================================================== *
 * Group 1: compare -- the only users of the "unsign 64" adder arms
 *
 * FUNC_SLTU / FUNC_SLTIU (aq_idu_cfig.h:331-332) are the only functions with
 * alu_func[14] set and alu_func[17]/[18] clear, i.e. the only producers of
 * rs0/rs1 arm 5'b00010 (aq_iu_alu.v:208, :229). slt/slti stay on the sign-64
 * arms. All four set alu_adder_op_cmp (func[7]) and op_lt (func[11]), which
 * selects result-mux arm 3'b100 = {63'b0, alu_adder_cin} (:276).
 * Four ops x four sign quadrants, so signed and unsigned disagree in two.
 * ==================================================================== */
static void g_cmp(u64 r)
{
    u64 a, b, q = 0;

    iu_quadrant(r, (unsigned)(r >> 8) & 3u, &a, &b);

    switch ((unsigned)(r >> 10) & 3u) {
    case 0:  IU_R2("slt",   q, a, b); break;
    case 1:  IU_R2("sltu",  q, a, b); break;   /* arm 00010 */
    case 2:  IU_RI("slti",  q, a, -1); break;
    default: IU_RI("sltiu", q, a, -1); break;  /* arm 00010 */
    }
    rand_sink += q;
}

/* ==================================================================== *
 * Group 2: th.addsl -- alu_adder_src1_tmp's pre-shift
 *
 * alu_adder_src1_tmp = src1 << alu_adder_src2[6:5] (aq_iu_alu.v:218). src2 is
 * the sign-extended I-immediate (decd_src1/src2_imm_sel[1],
 * aq_idu_id_decd.v:618-620), so src2[6:5] == inst[26:25] == the imm2 field, an
 * instruction field: all four values need four separate encodings, which is
 * what iu_sweep_addsl provides.
 * ==================================================================== */
static void g_addsl(u64 r)
{
    u64 a, b;

    iu_operands(r, (unsigned)(r >> 8), &a, &b);
    rand_sink += iu_sweep_addsl(a, b);
    iu_sweep_calls++;
}

/* ==================================================================== *
 * Group 3: register-amount shifts -- alu_shift_count and the *W 5-bit mask
 *
 * alu_shift_count = op_word ? {1'b0, src1[4:0]} : src1[5:0]
 * (aq_iu_alu.v:371). Drawing the amount from rand_rnd() & 63 means the *W
 * forms see amounts >= 32 and so exercise the mask, and the 64-bit forms see
 * the full 0..63 range into the 128-bit funnel shifter (:372).
 * ==================================================================== */
static void g_shift_reg(u64 r)
{
    u64 a = r, q = 0;
    u64 sh = (rand_rnd() & 63UL);

    switch ((unsigned)(r >> 8) % 6u) {
    case 0:  IU_RSH("sll",  q, a, sh); break;
    case 1:  IU_RSH("srl",  q, a, sh); break;
    case 2:  IU_RSH("sra",  q, a, sh); break;
    case 3:  IU_RSH("sllw", q, a, sh); break;   /* amount masked to 5 bits */
    case 4:  IU_RSH("srlw", q, a, sh); break;
    default: IU_RSH("sraw", q, a, sh); break;
    }
    rand_sink += q;
}

/* ==================================================================== *
 * Group 4: immediate shifts -- the shifter input mux arms
 *
 * alu_shift_input_127_64 (aq_iu_alu.v:331-336): arm 3'b001 for sll/srl/ext,
 * arm 3'b100 for sra (the {64{src0[63]}} fill).
 * alu_shift_input_63_0 (:358-365): arm 5'b10000 for sll (the bit-reversed
 * operand, :304-319), 5'b00001 for srl, 5'b00010 for srlw, 5'b01000 for sraw.
 * All six sweeps are fully unrolled in iu_sweeps.S; one per dispatch.
 * ==================================================================== */
static void g_shift_imm(u64 r)
{
    u64 a = r ^ (r << 7);
    u64 q = 0;

    switch ((unsigned)(r >> 8) % 6u) {
    case 0:  q = iu_sweep_slli(a, r);  break;
    case 1:  q = iu_sweep_srli(a, r);  break;
    case 2:  q = iu_sweep_srai(a, r);  break;
    case 3:  q = iu_sweep_slliw(a, r); break;
    case 4:  q = iu_sweep_srliw(a, r); break;
    default: q = iu_sweep_sraiw(a, r); break;
    }
    rand_sink += q;
    iu_sweep_calls++;
}

/* ==================================================================== *
 * Group 5: th.srri / th.srriw -- the rotate arms nothing else reaches
 *
 * FUNC_SRRI is the only ALU function that sets alu_shift_op_circle
 * (alu_func[8], aq_idu_cfig.h:357), hence the only producer of
 * alu_shift_input_127_64 arm 3'b010 = src0 (aq_iu_alu.v:333). FUNC_SRRIW adds
 * alu_shift_word_circle (func[13], :358), the only producer of
 * alu_shift_input_63_0 arm 5'b00100 = {src0[31:0], src0[31:0]} (:361).
 * The imm6/imm5 is an instruction field -> the unrolled sweeps.
 * ==================================================================== */
static void g_srri(u64 r)
{
    u64 a = r | 1UL;

    if ((r >> 8) & 1u)
        rand_sink += iu_sweep_srri(a, r);
    else
        rand_sink += iu_sweep_srriw(a, r);
    iu_sweep_calls++;
}

/* ==================================================================== *
 * Group 6 / 7: th.ext and th.extu -- the two 64-arm bitfield cases
 *
 * alu_shifter_extu_mask: 64 arms on alu_shift_ext_count[5:0]
 *   (aq_iu_alu.v:399-465), where ext_count = src1[11:6] - src1[5:0] (:370).
 * alu_shift_ext_sign:    64 arms on alu_shift_src1[11:6] (:484-550).
 * With lsb == 0 the two indices coincide (ext_count == msb == src1[11:6]), so
 * one 64-instruction sweep walks both cases; iu_sweep_ext_pairs then adds
 * msb < lsb so the 6-bit subtract underflows and the two indices decorrelate.
 * The difference between the groups is alu_shift_op_sign (func[10],
 * aq_idu_cfig.h:359-360): th.ext takes the or-mask arm when the extracted top
 * bit is 1 (:556, :560), th.extu never does (:555).
 * ==================================================================== */
static void g_ext(u64 r)
{
    u64 a = r ^ 0xa5a5a5a5a5a5a5a5UL;

    rand_sink += iu_sweep_ext(a, r);
    if ((r >> 8) & 1u)
        rand_sink += iu_sweep_ext_pairs(a, r);
    iu_sweep_calls++;
}

static void g_extu(u64 r)
{
    u64 a = r ^ 0x5a5a5a5a5a5a5a5aUL;

    rand_sink += iu_sweep_extu(a, r);
    if ((r >> 8) & 1u)
        rand_sink += iu_sweep_ext_pairs(a, r);
    iu_sweep_calls++;
}

/* ==================================================================== *
 * Group 8: logic -- alu_logic_op_and / xor / or (aq_iu_alu.v:576-586)
 *
 * The three one-hot enables and the three-way OR merge. The compressed forms
 * (c.and / c.or / c.xor, aq_idu_cfig.h:433,439,445) decode to the same funcs
 * but arrive with inst_len == 0; they need their operands in x8..x15, so they
 * are issued through pinned register variables rather than "r" constraints.
 * ==================================================================== */
static void g_logic(u64 r)
{
    u64 a = r, b = r >> 19, q = 0;

    switch ((unsigned)(r >> 8) % 9u) {
    case 0:  IU_R2("and",  q, a, b);       break;
    case 1:  IU_RI("andi", q, a, -1);      break;
    case 2:  IU_R2("or",   q, a, b);       break;
    case 3:  IU_RI("ori",  q, a, 1365);    break;
    case 4:  IU_R2("xor",  q, a, b);       break;
    case 5:  IU_RI("xori", q, a, -1366);   break;
    default: {
        /* c.and / c.or / c.xor: rd == rs1, both in x8..x15. */
        register u64 x_ __asm__("a0") = a;
        register u64 y_ __asm__("a1") = b;

        switch ((unsigned)(r >> 8) % 9u) {
        case 6:  __asm__ volatile ("and a0, a0, a1" : "+r"(x_) : "r"(y_)); break;
        case 7:  __asm__ volatile ("or  a0, a0, a1" : "+r"(x_) : "r"(y_)); break;
        default: __asm__ volatile ("xor a0, a0, a1" : "+r"(x_) : "r"(y_)); break;
        }
        q = x_;
        break;
    }
    }
    rand_sink += q;
}

/* ==================================================================== *
 * Group 9: th.ff1 / th.ff0 -- the 65-arm find-first-one casez
 *
 * alu_misc_ff1_rst (aq_iu_alu.v:614-681) is 65 arms wide and is indexed by
 * DATA, not by an immediate: alu_misc_ff1_src = op_ff0 ? ~src0 : src0 (:609).
 * So the sweep is over operand values, and it costs no code size at all: for
 * each leading-one position k, {1<<k} covers the "rest all zero" shape and
 * {(1<<k) | junk} the "rest non-zero" shape, and the bitwise complement of
 * each drives the same arms through th.ff0's inverter. Zero selects arm 64
 * (:679).
 * ==================================================================== */
static void g_ff(u64 r)
{
    unsigned j;
    u64 acc = 0, t;

    for (j = 0; j < 8u; j++) {
        unsigned k   = IU_SLICE(r >> 8, j);
        u64      one = 1UL << k;
        u64      msk = (k == 0u) ? 0UL : (one - 1UL);
        u64      mix = one | ((r >> 11) & msk);

        IU_TH1(TH_FF1_B, t, one);  acc ^= t;
        IU_TH1(TH_FF1_B, t, mix);  acc ^= t;
        IU_TH1(TH_FF0_B, t, ~one); acc ^= t;      /* inverted -> same arms */
        IU_TH1(TH_FF0_B, t, ~mix); acc ^= t;
    }
    IU_TH1(TH_FF1_B, t, 0UL);  acc ^= t;          /* arm 64 */
    IU_TH1(TH_FF0_B, t, ~0UL); acc ^= t;          /* arm 64 via the inverter */
    rand_sink += acc;
}

/* ==================================================================== *
 * Group 10: th.tst -- the 64-arm bit-select case
 *
 * alu_misc_tst_bit selects on alu_misc_src1[5:0] (aq_iu_alu.v:715), and for
 * th.tst src1 is the immediate sign_ext(inst[31:20]) so src1[5:0] == the imm6
 * field == inst[25:20]. An instruction field, hence the unrolled sweep.
 * The operand alternates so each selected bit is seen as both 0 and 1.
 * ==================================================================== */
static void g_tst(u64 r)
{
    rand_sink += iu_sweep_tst(r, r >> 13);
    rand_sink += iu_sweep_tst(~r, r >> 29);
    iu_sweep_calls += 2;
}

/* ==================================================================== *
 * Group 11: th.tstnbz -- the eight byte-zero comparators
 *
 * alu_misc_tstnbz_rst is eight independent (byte == 8'b0) tests
 * (aq_iu_alu.v:787-794), i.e. 256 reachable output patterns. The operand is
 * masked with a byte-expanded random mask so entire bytes are forced to zero;
 * eight masks per dispatch means the 256 patterns fill in quickly.
 * ==================================================================== */
static void g_tstnbz(u64 r)
{
    unsigned i;
    u64 acc = 0, t;

    for (i = 0; i < 8u; i++) {
        u64      keep = 0;
        unsigned m    = (unsigned)((r >> (8u * i)) & 0xffUL);
        unsigned b;

        for (b = 0; b < 8u; b++)
            if ((m >> b) & 1u)
                keep |= 0xffUL << (8u * b);

        IU_TH1(TH_TSTNBZ_B, t, (r ^ (r >> 31)) & keep);
        acc ^= t;
    }
    rand_sink += acc;
}

/* ==================================================================== *
 * Group 12: th.rev / th.revw
 *
 * alu_misc_rev_rst is the full 8-byte swap (aq_iu_alu.v:686-693). revw swaps
 * the low four bytes and then replicates src0[7] into the top 32 bits
 * (:696-700) -- an odd but deliberate choice, so both polarities of bit 7 have
 * to be forced explicitly rather than left to chance.
 * ==================================================================== */
static void g_rev(u64 r)
{
    u64 acc = 0, t;
    u64 lo  = r & ~0x80UL;                  /* src0[7] == 0 */
    u64 hi  = r |  0x80UL;                  /* src0[7] == 1 */

    IU_TH1(TH_REV_B,  t, r);   acc ^= t;
    IU_TH1(TH_REV_B,  t, ~r);  acc ^= t;
    IU_TH1(TH_REVW_B, t, lo);  acc ^= t;
    IU_TH1(TH_REVW_B, t, hi);  acc ^= t;
    rand_sink += acc;
}

/* ==================================================================== *
 * Group 13: th.mveqz / th.mvnez -- both arms of alu_misc_sel_src2
 *
 * alu_misc_sel_src2 = mveqz && src_not_zero || mvnez && !src_not_zero
 * (aq_iu_alu.v:800-801), and the result mux picks src2 or src0 (:802). src2 is
 * rd (decd_src2_reg = inst[11:7], aq_idu_id_decd.v:699-718), which makes this
 * one of only three src2 consumers in the whole ISA and the reason the sequence
 * lives in iu_sweeps.S with pinned registers: the producer immediately before
 * each op writes rd, so every one is also a distance-1 src2 forward.
 * ==================================================================== */
static void g_mov(u64 r)
{
    rand_sink += iu_sweep_mov(r, r >> 21);          /* src1 non-zero, then zero */
    rand_sink += iu_sweep_mov(r >> 3, 0UL);         /* src1 zero from the start */
    iu_sweep_calls += 2;
}

/* ==================================================================== *
 * Group 14: conditional branches -- the compare terms
 *
 * bju_beq_taken (aq_iu_bju.v:604), bju_src0_lt_src1 (:605) and the three terms
 * of bju_src0_lt_src1_signed (:606-608), selected by bju_op_func[4]
 * (:609-610), then folded into bju_cond_br_taken_raw's two XOR/AND legs
 * (:611-612). Six conditions x taken and not-taken x four sign quadrants, so
 * the signed and unsigned legs disagree in half the cases.
 * ==================================================================== */
#define IU_BR(mn, acc, x, y)                                              \
        __asm__ volatile (mn " %[u], %[v], 7f\n\t"                        \
                          "addi %[o], %[o], 1\n\t"                        \
                          "7:\n\t"                                        \
                          : [o] "+r"(acc) : [u] "r"(x), [v] "r"(y))

static void g_br_cond(u64 r)
{
    u64 a, b, acc = 0;

    iu_quadrant(r, (unsigned)(r >> 8) & 3u, &a, &b);
    if ((r >> 10) & 1u)
        b = a;                          /* force the equal / not-less cases */

    switch ((unsigned)(r >> 11) % 6u) {
    case 0:  IU_BR("beq",  acc, a, b); break;
    case 1:  IU_BR("bne",  acc, a, b); break;
    case 2:  IU_BR("blt",  acc, a, b); break;
    case 3:  IU_BR("bge",  acc, a, b); break;
    case 4:  IU_BR("bltu", acc, a, b); break;
    default: IU_BR("bgeu", acc, a, b); break;
    }
    rand_sink += acc;
    iu_br_execs++;
}

/* ==================================================================== *
 * Group 15: BHT mispredict -- one static branch, random directions
 *
 * bju_bht_mispred_no_entry = cond_sel && (taken ^ bht_pred[1]) && no_depd
 * (aq_iu_bju.v:637) and iu_ifu_bht_mispred (:790). A branch that always goes
 * the same way trains the 2-bit counter and stops mispredicting after two
 * passes, so the direction is taken from consecutive bits of one rand value:
 * a single static branch site, executed 32 times, whose outcome the BHT cannot
 * learn. The loop is one asm block so GCC cannot turn it into a conditional
 * move or unroll it into 32 distinct branch sites.
 * ==================================================================== */
static void g_br_mispred(u64 r)
{
    u64 bits = r, acc = 0, n = 32, t;

    __asm__ volatile (
        "1:\n\t"
        "andi %[t], %[b], 1\n\t"
        "beqz %[t], 2f\n\t"                 /* THE branch under test */
        "addi %[a], %[a], 1\n\t"
        "2:\n\t"
        "srli %[b], %[b], 1\n\t"
        "addi %[n], %[n], -1\n\t"
        "bnez %[n], 1b\n\t"
        : [t] "=&r"(t), [a] "+r"(acc), [b] "+r"(bits), [n] "+r"(n));

    rand_sink += acc;
    iu_br_execs += 32;
}

/* ==================================================================== *
 * Group 16: load-dependent branches -- the BJU's one-entry replay path
 *
 * The single deepest piece of state in the BJU. A conditional branch whose
 * operand is still in flight in the LSU cannot resolve in EX1, so it is parked
 * in the one-deep entry (aq_iu_bju.v:490-538) and replayed when the data
 * arrives:
 *   bju_depend_lsu_src0 / _src1  :433-434   (qualified by bju_func[6], so ONLY
 *                                            conditional branches take the
 *                                            entry -- :424-425)
 *   DA-stage forward             :430-431, :446-447
 *   DC-stage forward             :453-456
 *   bju_entry_pop                :463
 *   iu_idu_bju_full              :477
 *   iu_idu_bju_global_full       :478
 *   bju_bht_mispred_entry        :638
 *   bju_ag_offset sign-extend    :474  (branch_imm_flop[11] from src2[12])
 * ==================================================================== */
static void g_br_ldep(u64 r)
{
    /* -2 because several sub-cases also load from 8(p). */
    volatile u64 *p = &iu_arena[(unsigned)(r >> 8) % (IU_ARENA_U64 - 2u)];
    u64 acc = 0, v = 0, w = 0;

    switch ((unsigned)(r >> 20) & 7u) {
    case 0:
        /* src0 dependent: the loaded value is rs1 of the branch. */
        __asm__ volatile ("ld  %[v], 0(%[p])\n\t"
                          "beq %[v], %[c], 3f\n\t"
                          "addi %[a], %[a], 1\n\t"
                          "3:\n\t"
                          : [v] "=&r"(v), [a] "+r"(acc)
                          : [p] "r"(p), [c] "r"(r) : "memory");
        break;
    case 1:
        /* src1 dependent: the loaded value is rs2 of the branch. */
        __asm__ volatile ("ld  %[v], 0(%[p])\n\t"
                          "bne %[c], %[v], 3f\n\t"
                          "addi %[a], %[a], 1\n\t"
                          "3:\n\t"
                          : [v] "=&r"(v), [a] "+r"(acc)
                          : [p] "r"(p), [c] "r"(r) : "memory");
        break;
    case 2:
        /* Both sources from loads. The first may still be satisfied by the
         * DA-stage forward (:430-431), which is itself the coverage target;
         * the second cannot be. */
        __asm__ volatile ("ld  %[v], 0(%[p])\n\t"
                          "ld  %[w], 8(%[p])\n\t"
                          "bltu %[v], %[w], 3f\n\t"
                          "addi %[a], %[a], 1\n\t"
                          "3:\n\t"
                          : [v] "=&r"(v), [w] "=&r"(w), [a] "+r"(acc)
                          : [p] "r"(p) : "memory");
        break;
    case 3:
        /* D-cache hit: touch the line first, so the load resolves in DA and
         * the entry is skipped -- bju_ex1_inst_no_depd (:461). */
        acc += *p;
        __asm__ volatile ("ld  %[v], 0(%[p])\n\t"
                          "blt %[v], %[c], 3f\n\t"
                          "addi %[a], %[a], 1\n\t"
                          "3:\n\t"
                          : [v] "=&r"(v), [a] "+r"(acc)
                          : [p] "r"(p), [c] "r"(r) : "memory");
        break;
    case 4: {
        /* D-cache miss: eight 4 KB-strided addresses all map to the same set,
         * so the load is long-latency and the branch definitely parks. */
        unsigned i;

        for (i = 0; i < 8u; i++) {
            volatile u64 *q = &iu_arena[(i * IU_ARENA_STEP) % IU_ARENA_U64];

            __asm__ volatile ("ld  %[v], 0(%[q])\n\t"
                              "bge %[v], %[c], 3f\n\t"
                              "addi %[a], %[a], 1\n\t"
                              "3:\n\t"
                              : [v] "=&r"(v), [a] "+r"(acc)
                              : [q] "r"(q), [c] "r"(r) : "memory");
        }
        break;
    }
    case 5:
        /* Two back-to-back ld+branch pairs: the second branch arrives while
         * the entry is still occupied -> iu_idu_bju_full / _global_full
         * (:477-478). */
        __asm__ volatile ("ld  %[v], 0(%[p])\n\t"
                          "beq %[v], %[c], 3f\n\t"
                          "ld  %[w], 8(%[p])\n\t"
                          "bne %[w], %[c], 4f\n\t"
                          "addi %[a], %[a], 1\n\t"
                          "3:\n\t"
                          "4:\n\t"
                          : [v] "=&r"(v), [w] "=&r"(w), [a] "+r"(acc)
                          : [p] "r"(p), [c] "r"(r) : "memory");
        break;
    case 6:
        /* An entry branch whose resolved direction contradicts the BHT ->
         * bju_bht_mispred_entry (:638), the entry-side mispredict term. One
         * static branch site whose direction is a rand bit *fetched through the
         * load*, so the 2-bit BHT counter can never settle and the mispredict
         * is resolved out of the entry rather than in EX1. */
        *p = r & 1UL;
        __asm__ volatile ("ld   %[v], 0(%[p])\n\t"
                          "beqz %[v], 3f\n\t"
                          "addi %[a], %[a], 1\n\t"
                          "3:\n\t"
                          : [v] "=&r"(v), [a] "+r"(acc)
                          : [p] "r"(p) : "memory");
        break;
    default: {
        /* An entry branch with a NEGATIVE 12-bit offset: bju_ag_offset is
         * sign-extended from bju_branch_imm_flop[11] (:474), which is src2[12],
         * the sign bit of the 13-bit branch immediate -- only a backward branch
         * sets it. The loop is bounded by construction: the memory operand is
         * set to zero and the counter walks down to zero, so it runs exactly
         * four times. (Comparing the loaded value against an unconstrained
         * counter would be an unbounded loop, and a livelock retires
         * instructions, so the testbench's no-retire watchdog would never catch
         * it -- only the simulation-time limit would.) */
        u64 n = 4;

        *p = 0;
        __asm__ volatile (
            "5:\n\t"
            "addi %[n], %[n], -1\n\t"
            "addi %[a], %[a], 1\n\t"
            "ld   %[v], 0(%[p])\n\t"
            "bne  %[v], %[n], 5b\n\t"       /* backward, load-dependent */
            : [v] "=&r"(v), [a] "+r"(acc), [n] "+r"(n)
            : [p] "r"(p) : "memory");
        break;
    }
    }
    rand_sink += acc + v + w;
    iu_br_execs++;
}

/* ==================================================================== *
 * Group 17: jal / jalr -- link, return, RAS and the PC comparators
 *
 * All in iu_bju.S, because each form destroys the link register and needs a
 * known landing label. See that file's header for the per-signal mapping:
 * bju_link_vld (:659-660), bju_ret_vld (:657-658), bju_src_dst_reg_equal
 * (:656), bju_pc_cmp_fail (:648), bju_pc_reg_mispred (:649),
 * bju_ras_mispred_vld (:669-677), and the compressed c.j/c.jr/c.jalr forms.
 * ==================================================================== */
static void g_jal_jalr(u64 r)
{
    u64 acc = r;

    switch ((unsigned)(r >> 8) % 5u) {
    case 0:  acc = iu_bju_jal_link(acc);  break;
    case 1:  acc = iu_bju_ret_forms(acc); break;
    case 2:  acc = iu_bju_jalr_same(acc); break;
    case 3:  acc = iu_bju_jalr_reg(acc);  break;
    default: acc = iu_bju_rvc_jumps(acc); break;
    }
    rand_sink += acc;
    iu_br_execs++;
}

/* ==================================================================== *
 * Group 18: auipc -- bju_auipc_sel and the inc-pc adders
 *
 * bju_auipc_sel = bju_func[7] (aq_iu_bju.v:470) and bju_ex1_use_pc =
 * bju_func[8] (:589); FUNC_AUIPC sets both (aq_idu_cfig.h:410). The two inc-pc
 * adders (:576-577) and their select (:581-582) see both PC alignments, which
 * is what the c.nop between the .option norvc blocks in iu_bju_auipc() is for.
 * The 16-bit *select* arm itself belongs to the compressed BJU forms, not to
 * auipc -- see the RTL-read correction (c) in the file header.
 * ==================================================================== */
static void g_auipc(u64 r)
{
    u64 acc = iu_bju_auipc(r);
    u64 t;

    /* An auipc immediately before and immediately after a compressed
     * instruction, in the compiler's own instruction stream. */
    __asm__ volatile ("auipc %0, 0\n\t"
                      "c.nop\n\t"
                      "auipc %0, 0\n\t"
                      : "=r"(t));
    rand_sink += acc + t;
}

/* ==================================================================== *
 * Group 19: mul, no split -- the early-out and its sign asymmetry
 *
 * mul_ex1_inst64_nosplit = src0_high_judge && src1_high_judge
 * (aq_iu_mul.v:274), where each judge accepts a high half of 32'b0 always and
 * 32'hffffffff only if that operand is treated as signed (:269-272). The signs
 * are NOT symmetric:
 *   src0_sign64 = !usign            (:266)
 *   src1_sign64 = sign && !su       (:267)
 * With FUNC_MUL both are 1, with FUNC_MULHU both are 0, and with FUNC_MULHSU
 * src0 is signed while src1 is not (aq_idu_cfig.h:387-391). So operands whose
 * high half is 0xffffffff take the one-pass path for `mul` and `mulh`, the
 * iterating path for `mulhu`, and the mixed answer for `mulhsu` -- the single
 * highest-value asymmetry in the multiplier. Also covered: the three-arm
 * nosplit source selects (:286-291, :302-308) and the src2-zero arm (:252).
 * ==================================================================== */
static void g_mul_nosplit(u64 r)
{
    u64 lo = r & 0xffffffffUL;
    u64 hi = 0xffffffff00000000UL | lo;    /* high half all ones */
    u64 a, b, q = 0;

    switch ((unsigned)(r >> 8) & 3u) {
    case 0:  a = lo; b = lo; break;        /* both judges via the ==0 leg    */
    case 1:  a = hi; b = lo; break;        /* src0 needs src0_sign64         */
    case 2:  a = lo; b = hi; break;        /* src1 needs sign && !su         */
    default: a = hi; b = hi; break;        /* both need their sign bit       */
    }

    switch ((unsigned)(r >> 10) % 6u) {
    case 0:  IU_R2("mul",    q, a, b); break;   /* src2_zero arm (:252)  */
    case 1:  IU_R2("mulh",   q, a, b); break;
    case 2:  IU_R2("mulhu",  q, a, b); break;   /* both signs 0 -> splits */
    case 3:  IU_R2("mulhsu", q, a, b); break;   /* mixed                  */
    case 4:  IU_R2("mulw",   q, a, b); break;   /* nosplit arm 3'b010     */
    default: IU_R2("mul",    q, b, a); break;   /* operands swapped       */
    }
    rand_sink += q;
    iu_mul_ops++;
}

/* ==================================================================== *
 * Group 20: mul, split -- the iteration FSM and the writeback backpressure
 *
 * mul_ex1_iter_start (aq_iu_mul.v:275) enters the split FSM
 * IDLE -> SPLIT0 -> SPLIT1 -> CMPLT (parameters at :208-211), which walks all
 * four arms of mul_ex1_split_src0 (:317-323) and mul_ex1_split_src1
 * (:333-339) -- note src0 and src1 are NOT indexed the same way, so both
 * tables have to be walked. Then:
 *   mul_ex3_stall             :561   the grant is withheld
 *   iu_idu_mult_issue_stall   :597   a second multiply arrives mid-iteration
 *   iu_idu_mult_full          :598   EX3 full and no grant
 * The grant is rbus_div/mul arbitration against EX1 writebacks
 * (aq_rtu_rbus.v:467), so a burst of ALU ops behind the multiply is what
 * actually withholds it.
 * ==================================================================== */
static void g_mul_split(u64 r)
{
    /* Both high halves significant and not all-ones -> never nosplit. */
    u64 a = (r | 0x0000000100000000UL) & 0x7fffffffffffffffUL;
    u64 b = ((r >> 17) | 0x0000000100000000UL) & 0x7fffffffffffffffUL;
    u64 q = 0, p = 0, fill = r;

    switch ((unsigned)(r >> 8) & 3u) {
    case 0:
        IU_R2("mulh", q, a, b);
        break;
    case 1:
        /* ALU burst behind the multiply -> mul_ex3_stall (:561) and
         * iu_idu_mult_full (:598). */
        __asm__ volatile ("mulh %[q], %[a], %[b]\n\t"
                          ".rept 12\n\t"
                          "addi %[f], %[f], 1\n\t"
                          ".endr\n\t"
                          : [q] "=&r"(q), [f] "+r"(fill)
                          : [a] "r"(a), [b] "r"(b));
        break;
    case 2:
        /* Back-to-back split multiplies -> iu_idu_mult_issue_stall (:597). */
        __asm__ volatile ("mulh %[q], %[a], %[b]\n\t"
                          "mulhu %[p], %[a], %[b]\n\t"
                          "mulhsu %[q], %[b], %[a]\n\t"
                          : [q] "=&r"(q), [p] "=&r"(p)
                          : [a] "r"(a), [b] "r"(b));
        break;
    default:
        /* Chained: the second multiply's source is the first one's result, so
         * the FSM restarts immediately after CMPLT. */
        __asm__ volatile ("mulh %[q], %[a], %[b]\n\t"
                          "mulh %[q], %[q], %[b]\n\t"
                          : [q] "=&r"(q)
                          : [a] "r"(a), [b] "r"(b));
        break;
    }
    rand_sink += q + p + fill;
    iu_mul_ops += 3;
}

/* ==================================================================== *
 * Group 21: th.mul* accumulate -- the src2 mux and the 16-bit source arm
 *
 * mul_ex1_src2 is a three-arm case (aq_iu_mul.v:251-256) driven by
 * mul_src2_zero / _low_32 / _high_32 (:240-242):
 *   th.mula / th.muls               inst64 && sub_add  -> high_32, arm 3'b100
 *   th.mulaw / th.mulsw             inst32 && sub_add  -> low_32,  arm 3'b010
 *   th.mulah / th.mulsh             inst16             -> low_32,  arm 3'b010
 * and th.mulah / th.mulsh are the ONLY instructions that set mul_ex1_inst16
 * (aq_idu_cfig.h:393,397), hence the only route to the 16-bit nosplit source
 * arms 3'b001 (:287, :303). src2 is rd, so every one of these is also a src2
 * forward from the instruction immediately before it -- see iu_sweeps.S.
 * ==================================================================== */
static void g_mul_acc(u64 r)
{
    rand_sink += iu_sweep_mul_acc(r, r >> 23);
    rand_sink += iu_sweep_mul_acc(r | 0x8000800080008000UL, ~r);
    iu_mul_ops += 12;
    iu_sweep_calls += 2;
}

/* ==================================================================== *
 * Group 22: div, normal path -- the shift-2 kernel
 *
 * The iteration count is DATA dependent: div_iter_count is loaded with
 * div_ff1_res, then decremented by 2 per ITER cycle
 * (aq_iu_div_shift2_kernel.v:100-126). Sweeping the leading-one position of
 * the dividend and of the divisor independently gives:
 *   - every iteration count from 0 to 31;
 *   - div_iter_count_updt_0, the clamp for a divisor bigger than the dividend
 *     (:104-106) -> zero iterations;
 *   - all four quotient digits of the casez at :156-163 and all four remainder
 *     arms at :177-185, because the low bits are filled from rand so the
 *     remainder/divisor comparison lands on each of x1, x2, x3 and none.
 * All eight opcodes per dispatch (div/divu/rem/remu and the four *W forms,
 * aq_idu_cfig.h:415-422).
 * ==================================================================== */
static void g_div_normal(u64 r)
{
    unsigned j;
    u64 acc = 0, q;

    for (j = 0; j < 8u; j++) {
        unsigned kd = IU_SLICE(r >> 8, j);
        unsigned kv = IU_SLICE(r >> 14, j);
        u64      od = 1UL << kd;
        u64      ov = 1UL << kv;
        u64      d  = od | ((r >> 21) & (kd ? (od - 1UL) : 0UL));
        u64      v  = ov | ((r >> 37) & (kv ? (ov - 1UL) : 0UL));

        switch (j) {
        case 0:  IU_R2("div",   q, d, v); break;
        case 1:  IU_R2("divu",  q, d, v); break;
        case 2:  IU_R2("rem",   q, d, v); break;
        case 3:  IU_R2("remu",  q, d, v); break;
        case 4:  IU_R2("divw",  q, d, v); break;
        case 5:  IU_R2("divuw", q, d, v); break;
        case 6:  IU_R2("remw",  q, d, v); break;
        default: IU_R2("remuw", q, d, v); break;
        }
        acc ^= q;
    }
    rand_sink += acc;
    iu_div_ops += 8;
}

/* ==================================================================== *
 * Group 23: div FF1 -- the 65-arm positive casez and the negative OR-tree
 *
 * div_ff1_res_pos is a 65-arm casez on div_ff1_src (aq_iu_div.v:430-497) and
 * div_ff1_res_neg is a flat OR-tree (:505-633) selected when
 * div_src_is_neg (:420-421, :635). The tree is not a mirror of the casez: for
 * each leading-sign position it has TWO terms -- "the rest is all zero" and
 * "the rest is non-zero" -- so a negative dividend of exactly -(1<<k) and one
 * of -((1<<k)|junk) hit different products. Pure data sweep, no immediates.
 *
 * div_abs_src is muxed by div_prepare_src1 (:414-415): the DIVIDEND is
 * measured at IDLE and the DIVISOR at WFI2 (:320), so the same sweep has to be
 * applied to both operands.
 *
 * The two shapes the tree treats specially: &div_ff1_src == all ones -> 6'd0
 * (:633) and src[63] && !src[62] -> 6'd63 (:508), i.e. -1 and INT64_MIN.
 * ==================================================================== */
static void g_div_ff1(u64 r)
{
    unsigned j;
    u64 acc = 0, q;

    for (j = 0; j < 4u; j++) {
        unsigned k    = IU_SLICE(r >> 8, j);
        u64      one  = 1UL << k;
        u64      msk  = k ? (one - 1UL) : 0UL;
        u64      junk = one | ((r >> 13) & msk) | 1UL;

        /* Unsigned: div_src_is_neg == 0 -> the positive casez, both shapes. */
        IU_R2("divu", q, one,  3UL);  acc ^= q;
        IU_R2("divu", q, junk, 3UL);  acc ^= q;
        /* Signed negative dividend -> the OR-tree, both terms per position. */
        IU_R2("div",  q, 0UL - one,  3UL); acc ^= q;
        IU_R2("div",  q, 0UL - junk, 3UL); acc ^= q;
        /* Same sweep on the divisor, measured one state later at WFI2. */
        IU_R2("divu", q, ~0UL, junk);       acc ^= q;
        IU_R2("div",  q, ~0UL, 0UL - junk); acc ^= q;
    }
    IU_R2("div", q, 0x8000000000000000UL, 3UL); acc ^= q;   /* tree term :508 */
    IU_R2("div", q, ~0UL, 3UL);                 acc ^= q;   /* tree term :633 */
    rand_sink += acc;
    iu_div_ops += 26;
}

/* ==================================================================== *
 * Group 24: div special results -- the four-way one-hot and its near-misses
 *
 * div_ex1_res_onehot = {buffer_hit, dividend==0 && divisor!=0, divisor==0,
 * overflow} (aq_iu_div.v:349), feeding two four-arm casez blocks, one for the
 * quotient (:383-389) and one for the remainder (:398-404). The overflow test
 * (:335-337) needs a signed op, dividend == div_ex1_dividend_overflow (:334)
 * and divisor == all ones.
 *
 * The near-misses matter more than the hits, because they are what proves the
 * comparators are not too wide:
 *   - `div` (64-bit signed) with 0x0000_0000_8000_0000 and -1 must ITERATE:
 *     the 64-bit overflow constant is 0x8000_0000_0000_0000.
 *   - `divw` with the same register value must NOT iterate: for a signed word
 *     op the dividend is sign-extended from bit 31 (:209), so it becomes
 *     exactly 0xffff_ffff_8000_0000, the word overflow constant. (This is the
 *     opposite of what the original plan assumed -- see correction (a).)
 *   - `divw` with the word overflow dividend but a divisor whose word value is
 *     -2 must iterate.
 *   - `divu` with INT64_MIN and -1 must NOT be overflow: div_res_overflow is
 *     qualified by div_oper_is_signed (:335).
 * Each special is crossed with quotient/remainder, word/64 and signed/unsigned.
 * ==================================================================== */
static void g_div_special(u64 r)
{
    u64 acc = 0, q;
    const u64 min64 = 0x8000000000000000UL;
    const u64 minw  = 0x0000000080000000UL;   /* becomes 0xffffffff80000000 */

    switch ((unsigned)(r >> 8) % 10u) {
    case 0:  /* 64-bit signed overflow, quotient and remainder */
        IU_R2("div", q, min64, ~0UL); acc ^= q;
        IU_R2("rem", q, min64, ~0UL); acc ^= q;
        break;
    case 1:  /* word signed overflow, quotient and remainder */
        IU_R2("divw", q, minw, ~0UL); acc ^= q;
        IU_R2("remw", q, minw, ~0UL); acc ^= q;
        break;
    case 2:  /* divisor == 0: quotient all ones, remainder = the dividend */
        IU_R2("div",   q, r,    0UL); acc ^= q;
        IU_R2("rem",   q, r,    0UL); acc ^= q;
        IU_R2("divu",  q, r,    0UL); acc ^= q;
        IU_R2("remu",  q, r,    0UL); acc ^= q;
        break;
    case 3:  /* divisor == 0, word forms: the remainder is sign/zero extended
              * from bit 31 by div_divisor_eq0_remainder (:375) */
        IU_R2("divw",  q, r, 0UL); acc ^= q;
        IU_R2("remw",  q, r, 0UL); acc ^= q;
        IU_R2("divuw", q, r, 0UL); acc ^= q;
        IU_R2("remuw", q, r, 0UL); acc ^= q;
        break;
    case 4:  /* dividend == 0 && divisor != 0 -> arm 4'b0100 */
        IU_R2("div",   q, 0UL, r | 1UL); acc ^= q;
        IU_R2("rem",   q, 0UL, r | 1UL); acc ^= q;
        IU_R2("divuw", q, 0UL, r | 1UL); acc ^= q;
        IU_R2("remw",  q, 0UL, r | 1UL); acc ^= q;
        break;
    case 5:  /* both zero: divisor_eq0 wins the one-hot (:349) */
        IU_R2("divu", q, 0UL, 0UL); acc ^= q;
        IU_R2("remu", q, 0UL, 0UL); acc ^= q;
        break;
    case 6:  /* near-miss: 64-bit signed, dividend is the WORD constant */
        IU_R2("div", q, minw, ~0UL); acc ^= q;
        IU_R2("rem", q, minw, ~0UL); acc ^= q;
        break;
    case 7:  /* near-miss: word overflow dividend, divisor word value -2 */
        IU_R2("divw", q, minw, 0xfffffffffffffffeUL); acc ^= q;
        IU_R2("remw", q, minw, 0xfffffffffffffffeUL); acc ^= q;
        break;
    case 8:  /* near-miss: unsigned is never overflow (:335) */
        IU_R2("divu",  q, min64, ~0UL); acc ^= q;
        IU_R2("remu",  q, min64, ~0UL); acc ^= q;
        IU_R2("divuw", q, minw,  ~0UL); acc ^= q;
        IU_R2("remuw", q, minw,  ~0UL); acc ^= q;
        break;
    default: /* buffer hit, the fourth one-hot arm: the same pair twice */
        IU_R2("div", q, r | 1UL, (r >> 7) | 1UL); acc ^= q;
        IU_R2("rem", q, r | 1UL, (r >> 7) | 1UL); acc ^= q;
        break;
    }
    rand_sink += acc;
    iu_div_ops += 4;
}

/* ==================================================================== *
 * Group 25: div result-reuse buffer -- each mismatch arm on its own
 *
 * div_hit_buffer is the AND of four comparators (aq_iu_div.v:779-784):
 *   div_dividend_hit_buffer  dividend == the previous dividend
 *   div_divisor_hit_buffer   divisor  == the previous divisor
 *   div_signed_hit_buffer    same signedness
 *   div_word_hit_buffer      same width
 * A hit turns the second division into a two-cycle special result
 * (div_hit_buffer_res_vld, :343 -> div_ex1_res_vld, :346), so the quotient and
 * remainder of one operand pair cost one full division rather than two. Each
 * mismatch arm has to be defeated individually or a stuck comparator hides
 * behind the other three.
 * ==================================================================== */
static void g_div_buffer(u64 r)
{
    u64 a = r | 1UL;
    u64 b = (r >> 11) | 1UL;
    u64 acc = 0, q;

    IU_R2("div", q, a, b); acc ^= q;            /* prime the buffer */

    switch ((unsigned)(r >> 8) % 6u) {
    case 0:  IU_R2("rem",   q, a,        b);        break;  /* HIT           */
    case 1:  IU_R2("rem",   q, a,        b ^ 2UL);  break;  /* divisor miss  */
    case 2:  IU_R2("rem",   q, a ^ 2UL,  b);        break;  /* dividend miss */
    case 3:  IU_R2("remu",  q, a,        b);        break;  /* signed miss   */
    case 4:  IU_R2("remw",  q, a,        b);        break;  /* word miss     */
    default:
        /* divw then remw on the same operands: a hit across the word forms,
         * i.e. div_word_hit_buffer true on both sides rather than by default. */
        IU_R2("divw", q, a, b); acc ^= q;
        IU_R2("remw", q, a, b);
        break;
    }
    rand_sink += acc + q;
    iu_div_ops += 3;
}

/* ==================================================================== *
 * Group 26: div writeback -- the WFWB state
 *
 * div_ex2_enable_wb is literally rtu_iu_div_wb_grant (aq_iu_div.v:745), and
 * the grant is rbus_div_wb_grant = !rbus_ex1_wb_dp (aq_rtu_rbus.v:467) -- pure
 * arbitration against EX1 writebacks. So CMPLT falls through to WFWB
 * (:285-308) whenever the cycle the division finishes coincides with an
 * ALU/BJU/LSU writeback, and iu_idu_div_full (:764) then backpressures the
 * IDU. A long division followed by a dense burst of independent work is the
 * shortest way to hold the grant low for several cycles.
 * ==================================================================== */
static void g_div_wb(u64 r)
{
    u64 a = 0x7fffffffffffffffUL & (r | 0x4000000000000000UL);   /* long div */
    u64 b = 3UL;
    u64 q = 0, p = 0, fill = r;
    volatile u64 *m = &iu_arena[(unsigned)(r >> 8) % IU_ARENA_U64];

    switch ((unsigned)(r >> 12) & 3u) {
    case 0:
        /* ALU writebacks every cycle behind the division. */
        __asm__ volatile ("div %[q], %[a], %[b]\n\t"
                          ".rept 16\n\t"
                          "addi %[f], %[f], 1\n\t"
                          ".endr\n\t"
                          : [q] "=&r"(q), [f] "+r"(fill)
                          : [a] "r"(a), [b] "r"(b));
        break;
    case 1:
        /* LSU writebacks competing for the same EX1 bus. */
        __asm__ volatile ("div %[q], %[a], %[b]\n\t"
                          ".rept 8\n\t"
                          "ld %[p], 0(%[m])\n\t"
                          ".endr\n\t"
                          : [q] "=&r"(q), [p] "=&r"(p)
                          : [a] "r"(a), [b] "r"(b), [m] "r"(m) : "memory");
        break;
    case 2:
        /* A multiply reaching EX3 while the division wants the bus. */
        __asm__ volatile ("div %[q], %[a], %[b]\n\t"
                          "mulh %[p], %[a], %[a]\n\t"
                          "mulh %[p], %[p], %[a]\n\t"
                          : [q] "=&r"(q), [p] "=&r"(p)
                          : [a] "r"(a), [b] "r"(b));
        break;
    default:
        /* A second division issued while the first is still iterating ->
         * iu_idu_div_full (:764) with div_iterating set. */
        __asm__ volatile ("div %[q], %[a], %[b]\n\t"
                          "div %[p], %[a], %[q]\n\t"
                          : [q] "=&r"(q), [p] "=&r"(p)
                          : [a] "r"(a), [b] "r"(b));
        break;
    }
    rand_sink += q + p + fill;
    iu_div_ops += 2;
}

/* ==================================================================== *
 * Groups 27-30: forwarding -- nine comparator bins and a three-way priority mux
 *
 * The IDU has one forward comparator per (source, bus) pair: src0 against
 * fwd0/1/2 (aq_idu_id_dp.v:639-647), src1 (:670-678) and src2 (:701-709),
 * each feeding a three-arm data mux (:654-659, :685-690, :716-721) and a
 * validity term gated on "the source register is not x0" (:663-664, :694-695,
 * :725-726).
 *
 * Bus 0 of those three is the EX1 bus, which is itself a three-way priority
 * mux over LSU, BJU and ALU (aq_rtu_rbus.v:277-311) -- so which producer sits
 * in front of the consumer decides which arm of that mux is taken. Hence one
 * group per producer:
 *   fwd_alu  add        -> rbus arm 3'b100
 *   fwd_lsu  ld         -> rbus arm 3'b001
 *   fwd_mul  mul        -> the separate MUL forward bus (:323+)
 *   fwd_bju  auipc/jal  -> rbus arm 3'b010
 * crossed with the consumer operand slot (src0, src1, src2 = store data) and
 * the producer-consumer distance 1, 2, 3 (zero, one or two nops between).
 *
 * The src2 consumers that are *registers* are store data (inst[24:20]) and
 * th.mula/mveqz's rd; th.addsl's src2 is an immediate and the immediate wins
 * the operand mux, so it is not a forwarding target -- see correction (b).
 * The th.mula/mveqz src2 forwards live in iu_sweeps.S.
 * ==================================================================== */
#define IU_FWD(PROD, GAP, CONS)                                           \
        __asm__ volatile (PROD GAP CONS                                   \
                          : [p] "=&r"(p_), [c] "+r"(c_)                   \
                          : [x] "r"(x_), [y] "r"(y_), [m] "r"(m_)         \
                          : "memory")

/* Distance 1 / 2 / 3 == 0 / 1 / 2 instructions of separation. */
#define IU_FWD_DIST(PROD, CONS, sel)                                      \
        do {                                                              \
            switch ((sel) % 3u) {                                         \
            case 0:  IU_FWD(PROD, "",                    CONS); break;    \
            case 1:  IU_FWD(PROD, "nop\n\t",             CONS); break;    \
            default: IU_FWD(PROD, "nop\n\tnop\n\t",      CONS); break;    \
            }                                                             \
        } while (0)

#define IU_CONS_SRC0  "add  %[c], %[p], %[x]\n\t"
#define IU_CONS_SRC1  "add  %[c], %[x], %[p]\n\t"
#define IU_CONS_SRC2  "sd   %[p], 0(%[m])\n\t"

/* The producer's destination register `p_` is declared by the caller, so the
 * jal form can pin it (see g_fwd_bju). */
#define IU_FWD_SWEEP(PROD, r)                                             \
        do {                                                              \
            u64 c_ = 0;                                                   \
            u64 x_ = (r), y_ = (r) >> 19;                                 \
            u64 m_ = (u64)(unsigned long)                                 \
                     &iu_arena[(unsigned)((r) >> 8) % IU_ARENA_U64];      \
            unsigned d_ = (unsigned)((r) >> 30);                          \
                                                                          \
            switch ((unsigned)((r) >> 28) % 3u) {                         \
            case 0:  IU_FWD_DIST(PROD, IU_CONS_SRC0, d_); break;          \
            case 1:  IU_FWD_DIST(PROD, IU_CONS_SRC1, d_); break;          \
            default: IU_FWD_DIST(PROD, IU_CONS_SRC2, d_); break;          \
            }                                                             \
            rand_sink += p_ + c_;                                         \
        } while (0)

static void g_fwd_alu(u64 r)
{
    u64 p_ = 0;

    IU_FWD_SWEEP("add  %[p], %[x], %[y]\n\t", r);
}

static void g_fwd_lsu(u64 r)
{
    u64 p_ = 0;

    IU_FWD_SWEEP("ld   %[p], 0(%[m])\n\t", r);
}

static void g_fwd_mul(u64 r)
{
    u64 p_ = 0;

    IU_FWD_SWEEP("mul  %[p], %[x], %[y]\n\t", r);
    iu_mul_ops++;
}

static void g_fwd_bju(u64 r)
{
    if ((r >> 26) & 1u) {
        u64 p_ = 0;

        IU_FWD_SWEEP("auipc %[p], 0\n\t", r);
    } else {
        /* The jal producer pins its link register to a5 instead of letting the
         * allocator choose. "r" on RV64 nominally includes x1, and constraint 3
         * of this test forbids emitting any encoding that writes ra. GCC has
         * not in fact picked x1 here at -O0/-O1/-O2/-Os/-O3, but pinning makes
         * that a property of the source rather than of the allocator. a5 (x15)
         * is in rand_safe_regs. */
        register u64 p_ __asm__("a5") = 0;

        IU_FWD_SWEEP("jal  %[p], 6f\n\t6:\n\t", r);
    }
    iu_br_execs++;
}

/* ==================================================================== *
 * Group 31: the RVC path
 *
 * Every compressed instruction arrives with idu_iu_ex1_inst_len == 0, which
 * reaches iu_rtu_ex1_alu_inst_len (aq_iu_alu.v:857) and, for the BJU forms,
 * the 16-bit arm of the inc-pc adder select (aq_iu_bju.v:581-582). The
 * arithmetic forms below are written as *plain* mnemonics with operands the
 * assembler is guaranteed to compress (rd == rs1, registers in x8..x15) rather
 * than as hand-computed halfwords: the encoding is then the assembler's, not
 * mine, and it still cannot be anything but the compressed form.
 *
 * Deliberately absent: c.addi16sp, which writes sp. Constraint 3 of this test
 * forbids any encoding that writes x1/x2/x3/x4/x8, and the arm needs no help --
 * GCC emits c.addi16sp in the prologue and epilogue of every non-leaf function
 * in this file, so the decoder arm (aq_idu_id_decd.v:1340-1347) is covered
 * hundreds of thousands of times by the test's own frame setup. c.addi4spn is
 * present because it only *reads* sp.
 *
 * The compressed branches and jumps are in iu_bju.S (iu_bju_c_branch,
 * iu_bju_rvc_jumps): they need real targets.
 * ==================================================================== */
static void g_c_ext(u64 r)
{
    register u64 x_ __asm__("a0") = r;
    register u64 y_ __asm__("a1") = r >> 13;
    register u64 z_ __asm__("a2") = r >> 27;
    register u64 w_ __asm__("a3") = 0;

    __asm__ volatile (
        "li    a3, 5\n\t"               /* c.li            */
        "mv    a2, a0\n\t"              /* c.mv            */
        "add   a2, a2, a1\n\t"          /* c.add           */
        "sub   a2, a2, a1\n\t"          /* c.sub           */
        "subw  a2, a2, a1\n\t"          /* c.subw          */
        "addw  a2, a2, a1\n\t"          /* c.addw          */
        "and   a2, a2, a1\n\t"          /* c.and           */
        "or    a2, a2, a1\n\t"          /* c.or            */
        "xor   a2, a2, a1\n\t"          /* c.xor           */
        "andi  a2, a2, 31\n\t"          /* c.andi          */
        "slli  a2, a2, 3\n\t"           /* c.slli          */
        "srli  a2, a2, 5\n\t"           /* c.srli          */
        "srai  a2, a2, 7\n\t"           /* c.srai          */
        "addi  a2, a2, -1\n\t"          /* c.addi          */
        "addi  a2, a2, 1\n\t"
        "addi  a3, sp, 16\n\t"          /* c.addi4spn (reads sp only) */
        "nop\n\t"                       /* c.nop           */
        : "+r"(z_), "+r"(w_)
        : "r"(x_), "r"(y_));

    /* c.lui: the only producer of alu_adder_rs1_sel_onehot arm 5'b00001. */
    IU_C_LUI_A0();

    rand_sink += z_ + w_;
    rand_sink += iu_bju_c_branch(r, r >> 7);
    rand_sink += iu_bju_rvc_jumps(r);
    iu_br_execs += 17;
}

/* ==================================================================== *
 * SPARSE GROUPS (32..43)
 * ==================================================================== */

/* Group 32: a SPLIT multiply in the shadow of a mispredicted branch.
 *
 * The multiply FSM does have a flush term: mul_cur_state returns to IDLE on
 * rtu_yy_xx_flush_fe (aq_iu_mul.v:355-356), which is only reachable if a
 * multiply is actually mid-iteration when the flush lands -- hence the operands
 * are chosen so mul_ex1_inst64_nosplit (:274) is false. The destination is x0
 * so nothing architectural depends on whether the writeback survives. */
static void g_mul_flush(u64 r)
{
    u64 a = (r | 0x0000000100000000UL) & 0x7fffffffffffffffUL;
    u64 b = ((r >> 17) | 0x0000000100000000UL) & 0x7fffffffffffffffUL;
    u64 c = r & 1UL;
    u64 d = (r >> 5) & 1UL;

    __asm__ volatile ("beq  %[c], %[d], 6f\n\t"     /* direction from rand */
                      "mulh x0, %[a], %[b]\n\t"     /* wrong-path split mul */
                      "6:\n\t"
                      :: [c] "r"(c), [d] "r"(d), [a] "r"(a), [b] "r"(b));
    iu_mul_ops++;
    iu_br_execs++;
}

/* Group 33: a division on the wrong path of a mispredicted branch.
 *
 * The DIV FSM has NO flush term: div_cur_state is reset only by !cpurst_b
 * (aq_iu_div.v:249-254). A division that was issued speculatively therefore
 * runs to completion and asserts iu_rtu_div_wb_vld (:759) *after* the flush,
 * and rbus_div_wb_grant is pure arbitration with no flush qualifier
 * (aq_rtu_rbus.v:467), so the grant does arrive and the result is written.
 *
 * SAFETY RAILS, all three of them:
 *   1. sparse selector only, so this happens roughly once per 64 iterations;
 *   2. the destination is x0, so the late writeback has nowhere to land -- the
 *      correct path can never read it and no live value can be lost. A real
 *      register would be reused by GCC at an unpredictable point after the asm
 *      block ends, which is exactly the hazard this group is probing and
 *      exactly what must not be allowed to corrupt the test itself;
 *   3. nothing here touches sp, ra or tp.
 * The correct path re-materialises everything it needs: the only live values
 * are the asm inputs, which GCC keeps in its own registers. */
static void g_div_flush(u64 r)
{
    u64 a = 0x7fffffffffffffffUL & (r | 0x4000000000000000UL);   /* long div */
    u64 c = r & 1UL;
    u64 d = (r >> 5) & 1UL;

    __asm__ volatile ("beq  %[c], %[d], 6f\n\t"
                      "div  x0, %[a], %[b]\n\t"     /* wrong-path division */
                      "6:\n\t"
                      :: [c] "r"(c), [d] "r"(d), [a] "r"(a), [b] "r"(3UL));
    iu_div_ops++;
    iu_br_execs++;
}

/* Group 34: a multiply EX3 writeback colliding with a division CMPLT.
 *
 * Both units want the same writeback bus (aq_rtu_rbus.v:423, :467), and both
 * have their own "grant withheld" state -- mul CMPLT (aq_iu_mul.v:211) and div
 * WFWB (aq_iu_div.v:247). Lining them up needs a short division and a split
 * multiply started a few cycles apart; the nop padding is varied so the
 * alignment lands somewhere in the window over many dispatches. */
static void g_mul_div_mix(u64 r)
{
    u64 a = (r | 0x0000000100000000UL) & 0x7fffffffffffffffUL;
    u64 q = 0, p = 0;

    switch ((unsigned)(r >> 8) & 3u) {
    case 0:
        __asm__ volatile ("div  %[q], %[a], %[b]\n\t"
                          "mulh %[p], %[a], %[a]\n\t"
                          : [q] "=&r"(q), [p] "=&r"(p)
                          : [a] "r"(a), [b] "r"(7UL));
        break;
    case 1:
        __asm__ volatile ("div  %[q], %[a], %[b]\n\t"
                          "nop\n\t"
                          "mulh %[p], %[a], %[a]\n\t"
                          : [q] "=&r"(q), [p] "=&r"(p)
                          : [a] "r"(a), [b] "r"(7UL));
        break;
    case 2:
        __asm__ volatile ("mulh %[p], %[a], %[a]\n\t"
                          "div  %[q], %[a], %[b]\n\t"
                          : [q] "=&r"(q), [p] "=&r"(p)
                          : [a] "r"(a), [b] "r"(7UL));
        break;
    default:
        __asm__ volatile ("div  %[q], %[a], %[b]\n\t"
                          ".rept 3\n\t nop\n\t .endr\n\t"
                          "mulh %[p], %[a], %[a]\n\t"
                          : [q] "=&r"(q), [p] "=&r"(p)
                          : [a] "r"(a), [b] "r"(7UL));
        break;
    }
    rand_sink += q + p;
    iu_div_ops++;
    iu_mul_ops++;
}

/* Group 35: 64 back-to-back branches with random directions. Keeps the BHT,
 * the BTB and the BJU's non-entry path saturated rather than sampled, so the
 * bju_bht_mispred_no_entry / iu_ifu_bht_mispred pair (aq_iu_bju.v:637, :790)
 * toggles many times inside one dispatch. */
static void g_br_dense(u64 r)
{
    u64 bits = r, acc = 0, t;

    __asm__ volatile (
        ".rept 8\n\t"
        "andi %[t], %[b], 1\n\t"
        "srli %[b], %[b], 1\n\t"
        "beqz %[t], 8f\n\t"
        "addi %[a], %[a], 1\n\t"
        "8:\n\t"
        "bnez %[t], 9f\n\t"
        "addi %[a], %[a], 3\n\t"
        "9:\n\t"
        ".endr\n\t"
        : [t] "=&r"(t), [a] "+r"(acc), [b] "+r"(bits));

    rand_sink += acc;
    rand_sink += iu_bju_c_branch(r, r >> 32);
    iu_br_execs += 32;
}

/* Group 36: RAS overflow.
 *
 * The return-address stack is four deep. A call chain deeper than that loses
 * its bottom entries, so the returns unwinding past depth 4 legitimately
 * mispredict and bju_pc_cmp_fail (aq_iu_bju.v:648) fires on a *correct*
 * return rather than on a doctored one -- a different route into the same
 * comparator and into bju_ras_mispred_vld (:669-677).
 *
 * noinline plus the store after the recursive call keep GCC's tail-recursion
 * pass away from it; -fno-optimize-sibling-calls already disables that pass,
 * and this is belt and braces. */
static u64 __attribute__((noinline)) iu_ras_rec(unsigned d)
{
    u64 v;

    if (d == 0u)
        return rand_sink | 1UL;
    v = iu_ras_rec(d - 1u);
    rand_sink = v ^ (u64)d;
    return v + 1UL;
}

static void g_ras_deep(u64 r)
{
    rand_sink += iu_ras_rec((unsigned)((r >> 5) % 24u));
    iu_br_execs += 24;
}

/* Group 37: the 32-bit boundary.
 *
 * Every *W path sign-extends bit 31 of the 32-bit result:
 *   alu_adder_rst arm 3'b010                aq_iu_alu.v:275
 *   alu_shift_rst_raw1                      aq_iu_alu.v:393
 *   mul_ex3_rst_inst32                      aq_iu_mul.v:555
 *   div_normal_quotient / _remainder        aq_iu_div.v:735-738
 * and each needs bit 31 to be seen as both 0 and 1 or half of the sign-extend
 * fan-out never toggles. th.revw's {32{src0[7]}} replication (:700) is the odd
 * one out and is covered in g_rev(). */
static void g_word_bound(u64 r)
{
    u64 lo = (r & 0x7fffffffUL) | 1UL;              /* bit 31 == 0 */
    u64 hi = (r | 0x80000000UL) & 0xffffffffUL;     /* bit 31 == 1 */
    u64 a  = ((r >> 8) & 1u) ? hi : lo;
    u64 b  = ((r >> 9) & 1u) ? hi : lo;
    u64 q  = 0;

    switch ((unsigned)(r >> 10) % 10u) {
    case 0:  IU_R2("addw",  q, a, b); break;
    case 1:  IU_R2("subw",  q, a, b); break;
    case 2:  IU_RI("addiw", q, a, 1); break;
    case 3:  IU_R2("sllw",  q, a, b); break;
    case 4:  IU_R2("srlw",  q, a, b); break;
    case 5:  IU_R2("sraw",  q, a, b); break;
    case 6:  IU_R2("mulw",  q, a, b); break;
    case 7:  IU_R2("divw",  q, a, b); break;
    case 8:  IU_R2("remw",  q, a, b); break;
    default: IU_R2("divuw", q, a, b); break;
    }
    rand_sink += q;
    iu_div_ops++;
}

/* Group 38: writes to x0 must not forward.
 *
 * All three forward-valid terms are gated on "the source register is not x0"
 * (aq_idu_id_dp.v:663-664, :694-695, :725-726). Without that guard an
 * instruction whose destination is x0 would appear on the forward bus and a
 * subsequent reader of x0 would get its result instead of zero. So: a producer
 * with dst_preg == 0 immediately followed by a reader of x0, in each of the
 * three operand slots. */
static void g_x0_fwd(u64 r)
{
    u64 t = 0, u = 0;
    volatile u64 *m = &iu_arena[(unsigned)(r >> 8) % IU_ARENA_U64];

    __asm__ volatile ("add  x0, %[x], %[y]\n\t"     /* dst_preg == 0 */
                      "addi %[t], x0, 7\n\t"        /* src0 == x0    */
                      "add  %[u], %[x], x0\n\t"     /* src1 == x0    */
                      "sd   x0, 0(%[m])\n\t"        /* src2 == x0    */
                      : [t] "=&r"(t), [u] "=&r"(u)
                      : [x] "r"(r), [y] "r"(r >> 11), [m] "r"(m)
                      : "memory");
    rand_sink += t + u;
}

/* Group 39: the IU's four HPCP event counters.
 *
 * Verified against gen_rtl/pmu/rtl/aq_hpcp_top.v -- mhpmeventN[5:0] selects the
 * event directly (aq_hpcp_adder_sel.v:207):
 *    6 = hpcp_retire_bht_mispred  <- iu_hpcp_inst_bht_mispred   (:663, :550)
 *    7 = hpcp_retire_inst_condbr  <- iu_hpcp_inst_condbr        (:664, :549)
 *   29 = hpcp_idu_inst_type[0]    <- alu_sel|mult_sel|div_sel   (:686, and
 *                                    aq_idu_id_ctrl.v:699)
 *   40 = hpcp_backend_stall                                     (:697)
 * (38 = hpcp_inst_jmp_over_8m is programmed too, since group 40 is the only
 * thing that can move it.) The counters are read again in report(); nothing is
 * compared, they are a witness that the events fired at all.
 *
 * mhpmevent is persistent state that this group deliberately leaves
 * programmed -- that is the point of it, and rand_restore_sane_state() does not
 * touch those CSRs. It does restore MXSTATUS, which is what keeps PMDM clear so
 * the counters run in M mode. */
static void g_hpcp(u64 r)
{
    CSR_W(CSR_MHPMEVT3, 7);
    CSR_W(CSR_MHPMEVT4, 6);
    CSR_W(CSR_MHPMEVT5, 29);
    CSR_W(CSR_MHPMEVT6, ((r >> 8) & 1u) ? 40 : 38);
    CSR_W(CSR_MCNTIHBT, 0);

    rand_sink += CSR_R(CSR_MHPMCNT3) + CSR_R(CSR_MHPMCNT4)
               + CSR_R(CSR_MHPMCNT5) + CSR_R(CSR_MHPMCNT6);
}

/* Group 40: a jump farther than +-8 MB.
 *
 * bju_j_8m_pos_judge / _neg_judge compare the retired jump's displacement
 * against 41'h7fffff and 41'h1ffff800001 (aq_iu_bju.v:874-878), and the result
 * is latched into bju_j_8m -> iu_hpcp_jump_8m (:888-896). The linked image tops
 * out at 1 MB, so the only way to move that flag is to fetch from outside it.
 *
 * Two subtleties, both from the RTL:
 *  - bju_inst_j_set excludes returns (:872: `&& !bju_ret_vld_raw`), so the jump
 *    must NOT be `jalr x0, 0(x1)`. Both jumps here go through t0, whose
 *    register number is not 1, so bju_ret_vld_raw is 0 and the displacement is
 *    actually measured.
 *  - rand_run_at() reaches the excursion with an mret, which is a CP0 change of
 *    flow and is not counted. So the forward >8 MB jump has to be a real jalr,
 *    which is why there is a trampoline in .bss as well as a stub at the far
 *    address: the trampoline supplies pos_judge, the far stub's jump back
 *    supplies neg_judge.
 *
 * Address hygiene. IU_FAR_STUB sits in the window rand_csrs.h marks "never
 * touch": tb.v:98 does not wipe it, so under VCS it reads X until written. No
 * other address will do -- the linked image spans 1.5 MB, so nothing inside the
 * wiped window is more than 8 MB from the trampoline. The containment is that
 * every byte of the FOUR 64-byte lines the front end can reach is written in
 * full before the jump (see IU_FAR_WORDS in iu_defs.h): the stub's own line,
 * the sequential run-ahead past the jalr, and two more for both levels of
 * next-line prefetch (MHINT.IPREF_EN, left on by the baseline). Each refill is
 * a 4-beat 128-bit WRAP burst (ifu_biu_arlen == 2'b11, aq_ifu_icache.v:1363).
 * The stores are made with the D-cache OFF so a write-allocate refill never
 * reads the undefined line into the cache in the first place; the SRAM model
 * honours byte strobes (axi_slave128.v:500).
 *
 * Gated behind IU_ENABLE_JUMP8M, default OFF: it is the only group in this test
 * that writes instructions outside the linked image. */
static void g_jump8m(u64 r)
{
#ifdef IU_ENABLE_JUMP8M
    volatile u64 *far = (volatile u64 *)IU_FAR_STUB;
    u64 land = (u64)(unsigned long)&rand_run_at_land;
    u32 w[IU_FAR_WORDS];
    unsigned i;

    (void)r;

    /* The far stub: get back to the harness landing pad through t0 (x5). */
    for (i = 0; i < IU_FAR_WORDS; i++)
        w[i] = IU_NOP_WORD;
    w[0] = iu_enc_lui(5u, land);
    w[1] = iu_enc_addi(5u, 5u, iu_lo12(land));
    w[2] = iu_enc_jalr(0u, 5u);                 /* jalr x0, 0(t0) */

    /* D-cache off for the stores: a cached store to an undefined line would
     * refill X into the cache before merging. Every byte of all four lines is
     * written, so nothing X is ever fetched. */
    DCACHE_SAFE_POINT();
    CSR_C(CSR_MHCR, MHCR_DE);
    for (i = 0; i < IU_FAR_WORDS / 2u; i++)
        far[i] = (u64)w[2u * i] | ((u64)w[2u * i + 1u] << 32);
    for (i = IU_FAR_WORDS / 2u; i < IU_FAR_WORDS; i++)
        far[i] = (u64)IU_NOP_WORD | ((u64)IU_NOP_WORD << 32);
    TH_OP(TH_SYNC);
    CSR_S(CSR_MHCR, MHCR_DE);

    /* The trampoline, in .bss: a real jalr with a >8 MB forward displacement. */
    iu_tramp[0] = iu_enc_lui(5u, IU_FAR_STUB);
    iu_tramp[1] = iu_enc_addi(5u, 5u, iu_lo12(IU_FAR_STUB));
    iu_tramp[2] = iu_enc_jalr(0u, 5u);
    for (i = 3; i < 16u; i++)
        iu_tramp[i] = IU_NOP_WORD;

    RAND_ICACHE_SYNC();
    rand_run_at((u64)(unsigned long)&iu_tramp[0]);
    iu_br_execs += 2;
#else
    /* Not built. The group still counts so the indices in run_groups.sh and in
     * the report line up with the enum whether or not the gate is on. */
    (void)r;
#endif
}

/* Group 41: a trap in the middle of in-flight IU work.
 *
 * An illegal instruction or an ecall retires as an exception, which flushes the
 * front end (rtu_yy_xx_flush_fe) while a division and a multiply are still
 * iterating. Destinations are x0 throughout, for the same reason as group 33:
 * the DIV FSM has no flush term, so its writeback lands after the flush.
 * The harness's M handler steps over the faulting instruction (rand_trap.S) and
 * counts the cause, so an unexpected cause shows up in rand_hist_dump(). */
static void g_traps(u64 r)
{
    u64 a = 0x7fffffffffffffffUL & (r | 0x4000000000000000UL);

    switch ((unsigned)(r >> 8) & 3u) {
    case 0:
        __asm__ volatile ("div x0, %[a], %[b]\n\t" :: [a] "r"(a), [b] "r"(3UL));
        RAW_OP(INSN_RESERVED);                  /* undecodable custom-3 */
        break;
    case 1:
        __asm__ volatile ("mulh x0, %[a], %[a]\n\t" :: [a] "r"(a));
        RAW_OP(INSN_HFENCE_VVMA);               /* unconditionally illegal */
        break;
    case 2:
        __asm__ volatile ("div x0, %[a], %[b]\n\t" :: [a] "r"(a), [b] "r"(3UL));
        __asm__ volatile ("ecall" ::: "memory");
        break;
    default:
        __asm__ volatile ("add x0, %[a], %[a]\n\t" :: [a] "r"(a));
        RAW_OP(INSN_VADD_VV);                   /* vector removed -> illegal */
        break;
    }
    iu_div_ops++;
}

/* Group 42: a dense straight-line mix across all four sub-units.
 *
 * 64 instructions per dispatch, chained so that every one depends on the
 * previous result and the forward buses are never idle. The per-slot opcode
 * comes from rand by selecting one of four eight-instruction patterns and
 * repeating it eight times: a literal 64-way per-slot selection would need a
 * 64-deep switch nest, whose compare/branch tree would swamp the BJU and
 * contaminate groups 14-18 -- the same reason the immediate sweeps are in a
 * .S file. */
static void g_stress_mix(u64 r)
{
    u64 v = r | 1UL, w = (r >> 21) | 1UL;

    switch ((unsigned)(r >> 8) & 3u) {
    case 0:
        __asm__ volatile (".rept 8\n\t"
                          "add  %[v], %[v], %[w]\n\t"
                          "xor  %[v], %[v], %[w]\n\t"
                          "slli %[v], %[v], 3\n\t"
                          "ori  %[v], %[v], 1\n\t"
                          "mul  %[v], %[v], %[w]\n\t"
                          "srli %[v], %[v], 5\n\t"
                          "ori  %[v], %[v], 1\n\t"
                          "sub  %[v], %[v], %[w]\n\t"
                          ".endr\n\t"
                          : [v] "+r"(v) : [w] "r"(w));
        break;
    case 1:
        __asm__ volatile (".rept 8\n\t"
                          "or   %[v], %[v], %[w]\n\t"
                          "sllw %[v], %[v], %[w]\n\t"
                          "addw %[v], %[v], %[w]\n\t"
                          "ori  %[v], %[v], 3\n\t"
                          "divu %[v], %[v], %[w]\n\t"
                          "ori  %[v], %[v], 3\n\t"
                          "sraw %[v], %[v], %[w]\n\t"
                          "andi %[v], %[v], -3\n\t"
                          ".endr\n\t"
                          : [v] "+r"(v) : [w] "r"(w));
        break;
    case 2:
        __asm__ volatile (".rept 8\n\t"
                          "slt  %[v], %[v], %[w]\n\t"
                          "addi %[v], %[v], 1234\n\t"
                          "mulh %[v], %[v], %[w]\n\t"
                          "ori  %[v], %[v], 1\n\t"
                          "remu %[v], %[v], %[w]\n\t"
                          "ori  %[v], %[v], 1\n\t"
                          "sub  %[v], %[w], %[v]\n\t"
                          "xori %[v], %[v], -1\n\t"
                          ".endr\n\t"
                          : [v] "+r"(v) : [w] "r"(w));
        break;
    default:
        __asm__ volatile (".rept 8\n\t"
                          "sltu %[v], %[w], %[v]\n\t"
                          "ori  %[v], %[v], 7\n\t"
                          "mulw %[v], %[v], %[w]\n\t"
                          "ori  %[v], %[v], 7\n\t"
                          "rem  %[v], %[v], %[w]\n\t"
                          "sra  %[v], %[v], %[w]\n\t"
                          "ori  %[v], %[v], 7\n\t"
                          "add  %[v], %[v], %[w]\n\t"
                          ".endr\n\t"
                          : [v] "+r"(v) : [w] "r"(w));
        break;
    }
    rand_sink += v;
    iu_div_ops += 8;
    iu_mul_ops += 8;
}

/* Group 43: re-read the HPCP counters mid-run.
 *
 * Cheap, and it keeps the counter read path (a CP0 read of an HPCP-owned
 * register) exercised between the two ends of the run rather than only at the
 * report. */
static void g_report_probe(u64 r)
{
    (void)r;
    rand_sink += CSR_R(CSR_MHPMCNT3) + CSR_R(CSR_MHPMCNT4)
               + CSR_R(CSR_MHPMCNT5) + CSR_R(CSR_MHPMCNT6)
               + CSR_R(CSR_MCYCLE)   + CSR_R(CSR_MINSTRET);
}

/* ==================================================================== *
 * Dispatch
 * ==================================================================== */
static void dispatch(u64 r)
{
#ifdef IU_ONLY_GROUP
    /* Debug aid: build with -DIU_ONLY_GROUP=n to run just one group, which is
     * how a group that hangs or misbehaves gets isolated. Groups 0..31 are the
     * main rotation; 32..43 are the sparse second selector. */
    unsigned g = (IU_ONLY_GROUP);
#else
    unsigned g = (unsigned)(r % IU_NGROUPS);
#endif

    if (g < IU_NGROUPS_TOTAL) group_hits[g]++;

    switch (g) {
    case IU_G_ADD_SUB:      g_add_sub(r);      break;
    case IU_G_CMP:          g_cmp(r);          break;
    case IU_G_ADDSL:        g_addsl(r);        break;
    case IU_G_SHIFT_REG:    g_shift_reg(r);    break;
    case IU_G_SHIFT_IMM:    g_shift_imm(r);    break;
    case IU_G_SRRI:         g_srri(r);         break;
    case IU_G_EXT:          g_ext(r);          break;
    case IU_G_EXTU:         g_extu(r);         break;
    case IU_G_LOGIC:        g_logic(r);        break;
    case IU_G_FF:           g_ff(r);           break;
    case IU_G_TST:          g_tst(r);          break;
    case IU_G_TSTNBZ:       g_tstnbz(r);       break;
    case IU_G_REV:          g_rev(r);          break;
    case IU_G_MOV:          g_mov(r);          break;
    case IU_G_BR_COND:      g_br_cond(r);      break;
    case IU_G_BR_MISPRED:   g_br_mispred(r);   break;
    case IU_G_BR_LDEP:      g_br_ldep(r);      break;
    case IU_G_JAL_JALR:     g_jal_jalr(r);     break;
    case IU_G_AUIPC:        g_auipc(r);        break;
    case IU_G_MUL_NOSPLIT:  g_mul_nosplit(r);  break;
    case IU_G_MUL_SPLIT:    g_mul_split(r);    break;
    case IU_G_MUL_ACC:      g_mul_acc(r);      break;
    case IU_G_DIV_NORMAL:   g_div_normal(r);   break;
    case IU_G_DIV_FF1:      g_div_ff1(r);      break;
    case IU_G_DIV_SPECIAL:  g_div_special(r);  break;
    case IU_G_DIV_BUFFER:   g_div_buffer(r);   break;
    case IU_G_DIV_WB:       g_div_wb(r);       break;
    case IU_G_FWD_ALU:      g_fwd_alu(r);      break;
    case IU_G_FWD_LSU:      g_fwd_lsu(r);      break;
    case IU_G_FWD_MUL:      g_fwd_mul(r);      break;
    case IU_G_FWD_BJU:      g_fwd_bju(r);      break;
    case IU_G_C_EXT:        g_c_ext(r);        break;
    /* 32..43 are only reachable through -DIU_ONLY_GROUP; in a normal run they
     * come from the sparse selector below. */
    case IU_G_MUL_FLUSH:    g_mul_flush(r);    break;
    case IU_G_DIV_FLUSH:    g_div_flush(r);    break;
    case IU_G_MUL_DIV_MIX:  g_mul_div_mix(r);  break;
    case IU_G_BR_DENSE:     g_br_dense(r);     break;
    case IU_G_RAS_DEEP:     g_ras_deep(r);     break;
    case IU_G_WORD_BOUND:   g_word_bound(r);   break;
    case IU_G_X0_FWD:       g_x0_fwd(r);       break;
    case IU_G_HPCP:         g_hpcp(r);         break;
    case IU_G_JUMP8M:       g_jump8m(r);       break;
    case IU_G_TRAPS:        g_traps(r);        break;
    case IU_G_STRESS_MIX:   g_stress_mix(r);   break;
    case IU_G_REPORT_PROBE: g_report_probe(r); break;
    default: break;
    }

#ifndef IU_ONLY_GROUP
    /* The remaining groups are rarer, more expensive, or deliberately leave
     * work in flight across a pipeline flush, so they ride a second and much
     * sparser selector rather than diluting the main rotation. */
    switch ((unsigned)((r >> 32) % 64u)) {
    case 0:  g_mul_flush(r);    group_hits[IU_G_MUL_FLUSH]++;    break;
    case 1:  g_div_flush(r);    group_hits[IU_G_DIV_FLUSH]++;    break;
    case 2:  g_mul_div_mix(r);  group_hits[IU_G_MUL_DIV_MIX]++;  break;
    case 3:  g_br_dense(r);     group_hits[IU_G_BR_DENSE]++;     break;
    case 4:  g_ras_deep(r);     group_hits[IU_G_RAS_DEEP]++;     break;
    case 5:  g_word_bound(r);   group_hits[IU_G_WORD_BOUND]++;   break;
    case 6:  g_x0_fwd(r);       group_hits[IU_G_X0_FWD]++;       break;
    case 7:  g_hpcp(r);         group_hits[IU_G_HPCP]++;         break;
    case 8:  g_jump8m(r);       group_hits[IU_G_JUMP8M]++;       break;
    case 9:  g_traps(r);        group_hits[IU_G_TRAPS]++;        break;
    case 10: g_stress_mix(r);   group_hits[IU_G_STRESS_MIX]++;   break;
    case 11: g_report_probe(r); group_hits[IU_G_REPORT_PROBE]++; break;
    default: break;
    }
#endif
}

/* ==================================================================== *
 * End-of-run summary over the UART.
 *
 * Diagnostics only. PASS/FAIL is the GPR magic value the testbench watches for;
 * the real evidence of IU stimulus is work/iu_toggle.report.
 * ==================================================================== */
static void report(void)
{
    unsigned i;
    u64 c3, c4, c5, c6, e6;

    rand_restore_sane_state();

    /* Read the counters before turning the D-cache off for printing, so the
     * printer's own stores do not dominate them. mhpmevent6 is read back as
     * well: g_hpcp() reprograms counter 6 between event 40 (backend stall) and
     * event 38 (jump over 8M) as the run goes, so the count alone says nothing
     * about what was counted. */
    c3 = CSR_R(CSR_MHPMCNT3);
    c4 = CSR_R(CSR_MHPMCNT4);
    c5 = CSR_R(CSR_MHPMCNT5);
    c6 = CSR_R(CSR_MHPMCNT6);
    e6 = CSR_R(CSR_MHPMEVT6) & 63UL;

    rand_report_begin();

    rand_puts("\n[iu_random] iters=");
    rand_putu(rand_iter);
    rand_puts(" sweeps=");
    rand_putu(iu_sweep_calls);
    rand_puts(" mulops=");
    rand_putu(iu_mul_ops);
    rand_puts(" divops=");
    rand_putu(iu_div_ops);
    rand_puts(" brexecs=");
    rand_putu(iu_br_execs);

    /* HPCP: event 7 condbr, 6 bht_mispred, 29 IU issue, 40 backend stall or
     * 38 jump-over-8M -- see g_hpcp(). Witnesses, not assertions. */
    rand_puts("\n[iu_random] hpm3(condbr)=");
    rand_putu(c3);
    rand_puts(" hpm4(mispred)=");
    rand_putu(c4);
    rand_puts(" hpm5(iu_issue)=");
    rand_putu(c5);
    rand_puts(" hpm6(evt");
    rand_putu(e6);
    rand_puts(")=");
    rand_putu(c6);

    rand_puts("\n[iu_random] groups:");
    for (i = 0; i < IU_NGROUPS_TOTAL; i++) {
        rand_putc(' ');
        rand_putu(group_hits[i]);
    }

    /* Informational fingerprint of the whole data stream. It is NOT compared
     * against anything -- there is no golden model in this test. Two runs with
     * the same seed and the same -O level should print the same value, which is
     * the only thing it is good for. */
    rand_puts("\n[iu_random] sink=0x");
    rand_putx(rand_sink);
    rand_putc('\n');

    rand_hist_dump("iu_random");

    rand_report_end();
}

/* ==================================================================== *
 * main
 * ==================================================================== */
int main(void)
{
    unsigned i;

    rand_srand((u64)IU_SEED);
    rand_trap_init();               /* FIRST: clears MIE, installs mtvec */
    rand_pmp_open_everything();
    rand_restore_sane_state();

    /* One-time init.
     *  - Touch every 4 KB-strided slot of the arena once, so the first pass of
     *    g_br_ldep()'s miss walk is not measuring page-zero behaviour.
     *  - Program the IU's HPCP events up front rather than waiting for
     *    g_hpcp() to be selected, so the counters printed by report() cover the
     *    whole run instead of its tail. */
    for (i = 0; i < IU_ARENA_U64; i += IU_ARENA_STEP)
        iu_arena[i] = (u64)i * 0x0101010101010101UL;

    CSR_W(CSR_MHPMEVT3, 7);         /* retire_inst_condbr    */
    CSR_W(CSR_MHPMEVT4, 6);         /* retire_bht_mispred    */
    CSR_W(CSR_MHPMEVT5, 29);        /* ALU|MULT|DIV issued   */
    CSR_W(CSR_MHPMEVT6, 40);        /* backend stall         */
    CSR_W(CSR_MCNTIHBT, 0);

    for (rand_iter = 0; rand_iter < (u64)IU_ITERS; rand_iter++) {
        /* Landing pad for the trap handler's bail-out path. rand_iter and the
         * PRNG state are volatile, so they survive the longjmp. */
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
