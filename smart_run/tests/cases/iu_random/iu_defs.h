/*
 * iu_random -- case-local definitions: knobs, group identity, operand pools,
 * the raw-encoding helpers the driver needs, and the prototypes of the
 * unrolled sweeps in iu_sweeps.S / iu_bju.S.
 *
 * Everything shared with the other three per-unit random tests lives in
 * tests/cases/rand_common/ and is NOT duplicated here.
 */

#ifndef IU_DEFS_H
#define IU_DEFS_H

#include "rand_common.h"

/* ==================================================================== *
 * Knobs (all overridable from the make command line -- see
 * setup/smart_cfg.mk, IU_ITERS / IU_SEED / IU_EXTRA).
 * ==================================================================== */
#ifndef IU_ITERS
#define IU_ITERS  20000
#endif
#ifndef IU_SEED
#define IU_SEED   0x2024C906
#endif
/* IU_ONLY_GROUP=<n> runs a single group; tests/cases/iu_random/run_groups.sh
 * uses it to bisect. IU_ENABLE_JUMP8M turns on the >8 MB jump group, which is
 * the only group that writes instructions outside the linked image. */

/* ==================================================================== *
 * Groups. 0..31 are the main rotation (r % IU_NGROUPS); 32..43 ride the sparse
 * second selector ((r >> 32) % 64, cases 0..11) because they are expensive,
 * perturb persistent state, or deliberately leave work in flight across a
 * pipeline flush.
 * ==================================================================== */
#define IU_NGROUPS        32
#define IU_NGROUPS_TOTAL  44

enum iu_group {
    IU_G_ADD_SUB = 0,   /* aq_iu_alu.v:206-213 / :227-240 / :273-278   */
    IU_G_CMP,           /* aq_iu_alu.v:248, :276 arm 3'b100            */
    IU_G_ADDSL,         /* aq_iu_alu.v:218                             */
    IU_G_SHIFT_REG,     /* aq_iu_alu.v:371 (incl. the *W 5-bit mask)   */
    IU_G_SHIFT_IMM,     /* aq_iu_alu.v:331-336 / :358-365              */
    IU_G_SRRI,          /* aq_iu_alu.v:333 arm 010, :361 arm 00100     */
    IU_G_EXT,           /* aq_iu_alu.v:399-465 + :484-550              */
    IU_G_EXTU,          /* ditto with alu_shift_op_sign == 0 (:555)    */
    IU_G_LOGIC,         /* aq_iu_alu.v:576-586                         */
    IU_G_FF,            /* aq_iu_alu.v:609-681 (65 arms, data-driven)  */
    IU_G_TST,           /* aq_iu_alu.v:715-781 (64 arms, imm-driven)   */
    IU_G_TSTNBZ,        /* aq_iu_alu.v:787-794 (8 byte comparators)    */
    IU_G_REV,           /* aq_iu_alu.v:686-700                         */
    IU_G_MOV,           /* aq_iu_alu.v:797-802                         */
    IU_G_BR_COND,       /* aq_iu_bju.v:604-612                         */
    IU_G_BR_MISPRED,    /* aq_iu_bju.v:637, :790                       */
    IU_G_BR_LDEP,       /* aq_iu_bju.v:424-484, :638                   */
    IU_G_JAL_JALR,      /* aq_iu_bju.v:646-677                         */
    IU_G_AUIPC,         /* aq_iu_bju.v:470, :572-583, :589             */
    IU_G_MUL_NOSPLIT,   /* aq_iu_mul.v:266-276, :286-308, :252         */
    IU_G_MUL_SPLIT,     /* aq_iu_mul.v:208-211, :317-341, :561, :597   */
    IU_G_MUL_ACC,       /* aq_iu_mul.v:239-256, :287/:303 arm 001      */
    IU_G_DIV_NORMAL,    /* aq_iu_div_shift2_kernel.v:100-126, :156-185 */
    IU_G_DIV_FF1,       /* aq_iu_div.v:430-497 and :505-633            */
    IU_G_DIV_SPECIAL,   /* aq_iu_div.v:331-349, :383-404               */
    IU_G_DIV_BUFFER,    /* aq_iu_div.v:771-787                         */
    IU_G_DIV_WB,        /* aq_iu_div.v:297-308, :745, :764             */
    IU_G_FWD_ALU,       /* aq_idu_id_dp.v:639-727, aq_rtu_rbus.v:290-311 */
    IU_G_FWD_LSU,
    IU_G_FWD_MUL,
    IU_G_FWD_BJU,
    IU_G_C_EXT,         /* RVC decode + inst_len == 0 into the BJU/ALU */
    /* --- sparse selector, cases 0..11 --------------------------------- */
    IU_G_MUL_FLUSH,     /* aq_iu_mul.v:355-356                         */
    IU_G_DIV_FLUSH,     /* aq_iu_div.v:249-254 (NO flush term)         */
    IU_G_MUL_DIV_MIX,
    IU_G_BR_DENSE,
    IU_G_RAS_DEEP,
    IU_G_WORD_BOUND,    /* aq_iu_alu.v:275, :393; aq_iu_mul.v:555      */
    IU_G_X0_FWD,        /* aq_idu_id_dp.v:663-664, :694-695, :725-726  */
    IU_G_HPCP,          /* aq_hpcp_top.v:663-664, :686, :697           */
    IU_G_JUMP8M,        /* aq_iu_bju.v:874-878, :896                   */
    IU_G_TRAPS,
    IU_G_STRESS_MIX,
    IU_G_REPORT_PROBE
};

/* ==================================================================== *
 * Raw-encoding helpers.
 *
 * rand_common.h's TH_OP() stringifies its argument, which works for the plain
 * hex cache/sync constants but NOT for anything built from the rand_th_insn.h
 * arithmetic bases: those carry a `U` suffix that GAS rejects, and the field
 * builders are parenthesised expressions. So the word is handed to the
 * assembler as an "i" operand and printed by the compiler instead.
 *
 * Register fields are pinned so a raw word can name them while GCC still sees
 * the dataflow:  rd = a2 (x12), rs1 = a0 (x10), rs2 = a1 (x11).
 * a0/a1/a2 are all in rand_safe_regs and all caller-saved.
 * ==================================================================== */
#define IU_RD   12u
#define IU_RS1  10u
#define IU_RS2  11u

/* One-source form: rd = op(rs1). */
#define IU_TH1(base, dst, src) do {                                        \
        register u64 iu_s_ __asm__("a0") = (u64)(src);                     \
        register u64 iu_d_ __asm__("a2");                                  \
        __asm__ volatile (".word %[w]"                                     \
            : "=r"(iu_d_)                                                  \
            : [w] "i" ((unsigned long)((unsigned)(base)                    \
                       | (IU_RD << 7) | (IU_RS1 << 15))),                  \
              "r"(iu_s_));                                                 \
        (dst) = iu_d_;                                                     \
    } while (0)

/* Two-source form: rd = op(rs1, rs2). */
#define IU_TH2(base, dst, s0, s1) do {                                     \
        register u64 iu_a_ __asm__("a0") = (u64)(s0);                      \
        register u64 iu_b_ __asm__("a1") = (u64)(s1);                      \
        register u64 iu_d_ __asm__("a2");                                  \
        __asm__ volatile (".word %[w]"                                     \
            : "=r"(iu_d_)                                                  \
            : [w] "i" ((unsigned long)((unsigned)(base) | (IU_RD << 7)     \
                       | (IU_RS1 << 15) | (IU_RS2 << 20))),                \
              "r"(iu_a_), "r"(iu_b_));                                     \
        (dst) = iu_d_;                                                     \
    } while (0)

/* Immediate form: rd = op(rs1, imm), imm placed at inst[25:20]. Used for
 * th.tst / th.srri / th.srriw where the immediate has to be a literal. */
#define IU_THI(base, dst, src, imm) do {                                   \
        register u64 iu_s_ __asm__("a0") = (u64)(src);                     \
        register u64 iu_d_ __asm__("a2");                                  \
        __asm__ volatile (".word %[w]"                                     \
            : "=r"(iu_d_)                                                  \
            : [w] "i" ((unsigned long)((unsigned)(base)                    \
                       | ((unsigned)(imm) << 20)                           \
                       | (IU_RD << 7) | (IU_RS1 << 15))),                  \
              "r"(iu_s_));                                                 \
        (dst) = iu_d_;                                                     \
    } while (0)

/* Accumulate form: src2 == rd, so the destination is read as well as written.
 * This is the shape of th.mula/muls/mulaw/mulsw/mulah/mulsh and
 * th.mveqz/mvnez (decd_src2_reg = inst[11:7], aq_idu_id_decd.v:699-718). */
#define IU_THACC(base, acc, s0, s1) do {                                   \
        register u64 iu_a_ __asm__("a0") = (u64)(s0);                      \
        register u64 iu_b_ __asm__("a1") = (u64)(s1);                      \
        register u64 iu_c_ __asm__("a2") = (u64)(acc);                     \
        __asm__ volatile (".word %[w]"                                     \
            : "+r"(iu_c_)                                                  \
            : [w] "i" ((unsigned long)((unsigned)(base) | (IU_RD << 7)     \
                       | (IU_RS1 << 15) | (IU_RS2 << 20))),                \
              "r"(iu_a_), "r"(iu_b_));                                     \
        (acc) = iu_c_;                                                     \
    } while (0)

/* c.lui is the only ADDER producer of alu_adder_rs1_sel_onehot arm 5'b00001
 * (aq_iu_alu.v:228): FUNC_C_LUI is the one adder function with func[13] set and
 * func[18] clear (aq_idu_cfig.h:436). (th.srriw also sets func[13], so it takes
 * the same mux arm, but its adder result is discarded -- see the ALU-shift
 * sweeps in iu_sweeps.S.) GCC emits c.lui only when it happens to need a
 * constant in that shape, so it is issued here as a raw halfword -- with the a0
 * clobber rand_common.h's RAW_OP16 does not declare. */
#define IU_C_LUI_A0() \
        __asm__ volatile (".2byte " STR(C_LUI_A0_1) ::: "a0", "memory")

/* Register-to-register and register-immediate ALU/MUL/DIV forms. The opcode is
 * spelled out so GCC cannot substitute a cheaper instruction (or fold the
 * operation away entirely, which is what happens with plain C operators once
 * one operand is a compile-time constant). */
#define IU_R2(op, d, s0, s1) \
        __asm__ volatile (op " %0, %1, %2" : "=r"(d) : "r"(s0), "r"(s1))
#define IU_RI(op, d, s0, im) \
        __asm__ volatile (op " %0, %1, " #im : "=r"(d) : "r"(s0))
#define IU_RSH(op, d, s0, sh) \
        __asm__ volatile (op " %0, %1, %2" : "=r"(d) : "r"(s0), "r"(sh))

/* ==================================================================== *
 * Operand pools.
 *
 * The eight adder classes are the carry/borrow boundaries where
 * alu_adder_cin (aq_iu_alu.v:240) flips and where the 33rd bit of the four
 * sign/zero extensions (:207-213, :227-234) changes the result.
 * ==================================================================== */
#define IU_NOPCLASS 8

static inline void iu_operands(u64 r, unsigned cls, u64 *a, u64 *b)
{
    switch (cls % IU_NOPCLASS) {
    case 0: *a = 0x7fffffffUL;         *b = 1UL;      break; /* word carry out */
    case 1: *a = 0xffffffffUL;         *b = 1UL;      break; /* word wrap      */
    case 2: *a = 0x7fffffffffffffffUL; *b = 1UL;      break; /* INT64_MAX + 1  */
    case 3: *a = 0UL;                  *b = ~0UL;     break; /* 0 + (-1)       */
    case 4: *a = 0x8000000000000000UL; *b = ~0UL;     break; /* INT64_MIN - 1  */
    case 5: *a = r;                    *b = r;        break; /* equal operands */
    case 6: *a = ~0UL;                 *b = ~0UL;     break; /* all ones       */
    default:*a = r;                    *b = r >> 17;  break; /* random         */
    }
}

/* The four sign quadrants, so that a signed and an unsigned comparison of the
 * same pair disagree in two of them (bju_src0_lt_src1 vs
 * bju_src0_lt_src1_signed, aq_iu_bju.v:605-608; the slt/sltu split at
 * aq_iu_alu.v:208 vs :211). */
static inline void iu_quadrant(u64 r, unsigned q, u64 *a, u64 *b)
{
    u64 x = r | 1UL;
    u64 y = (r >> 23) | 1UL;

    *a = (q & 1u) ? (x | 0x8000000000000000UL) : (x & 0x7fffffffffffffffUL);
    *b = (q & 2u) ? (y | 0x8000000000000000UL) : (y & 0x7fffffffffffffffUL);
}

/* A slice of eight values spread across the whole 0..63 range with stride 8.
 * As `base` walks 0..63 the eight slices tile the range exactly, so a
 * data-driven 64-arm case gets uniform coverage without 64 operations per
 * dispatch -- which matters because the default 3 ms testbench timeout
 * (tb.v MAX_RUN_TIME) is only about 3 M cycles for 20000 iterations. */
#define IU_SLICE(base, j)  (((unsigned)(base) + 8u * (unsigned)(j)) & 63u)

/* ==================================================================== *
 * Address windows used by this case. rand_csrs.h has the full rules.
 * ==================================================================== */
/* The >8 MB jump target. This address is deliberately in the window
 * rand_csrs.h marks "never touch" (0x0016_3840..0x0FFF_FFFF, not wiped by
 * tb.v:98, reads X under VCS) -- there is no alternative, because the linked
 * image spans only the first 1.5 MB, so no target inside the wiped window can
 * be more than 8 MB away. The deviation is contained two ways: the group is
 * gated behind IU_ENABLE_JUMP8M (default OFF), and g_jump8m() writes every byte
 * of every line the front end can plausibly fetch before jumping there.
 *
 * IU_FAR_WORDS is a u64 count and covers FOUR 64-byte I-cache lines, where the
 * stub itself needs only the first twelve bytes: one line for the stub, one for
 * the run-ahead of the sequential fetch past the jalr while it is resolving,
 * and two more so that both levels of next-line prefetch (MHINT.IPREF_EN, left
 * on by the baseline) also land on written memory. An X instruction word here
 * would be undebuggable, and the extra stores cost nothing in a group that runs
 * once per ~64 iterations. */
#define IU_FAR_STUB   0x00900000UL
#define IU_FAR_WORDS  32              /* 32 u64 == 4 I-cache lines (arlen=3) */

/* rand_trap.S exports this landing pad (`.global rand_run_at_land`) but
 * rand_common.h does not declare it -- only rand_run_at() and rand_sret_land
 * are in the header. g_jump8m() needs its address to build the far stub's
 * return jump, so the declaration is here rather than in the shared header,
 * which is baselined and must not be touched. */
void rand_run_at_land(void);

/* ==================================================================== *
 * iu_sweeps.S
 * ==================================================================== */
u64 iu_sweep_ext(u64 src0, u64 acc);
u64 iu_sweep_extu(u64 src0, u64 acc);
u64 iu_sweep_ext_pairs(u64 src0, u64 acc);
u64 iu_sweep_tst(u64 src0, u64 acc);
u64 iu_sweep_srri(u64 src0, u64 acc);
u64 iu_sweep_srriw(u64 src0, u64 acc);
u64 iu_sweep_slli(u64 src0, u64 acc);
u64 iu_sweep_srli(u64 src0, u64 acc);
u64 iu_sweep_srai(u64 src0, u64 acc);
u64 iu_sweep_slliw(u64 src0, u64 acc);
u64 iu_sweep_srliw(u64 src0, u64 acc);
u64 iu_sweep_sraiw(u64 src0, u64 acc);
u64 iu_sweep_addsl(u64 src0, u64 src1);
u64 iu_sweep_mul_acc(u64 src0, u64 src1);
u64 iu_sweep_mov(u64 src0, u64 src1);

/* ==================================================================== *
 * iu_bju.S
 * ==================================================================== */
u64 iu_bju_jal_link(u64 acc);
u64 iu_bju_ret_forms(u64 acc);
u64 iu_bju_jalr_same(u64 acc);
u64 iu_bju_jalr_reg(u64 acc);
u64 iu_bju_rvc_jumps(u64 acc);
u64 iu_bju_c_branch(u64 acc, u64 bits);
u64 iu_bju_auipc(u64 acc);

#endif /* IU_DEFS_H */
