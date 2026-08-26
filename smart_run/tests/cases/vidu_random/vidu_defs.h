/*
 * vidu_random -- FP operand pool, raw instruction encodings and the FP
 * register-sweep machinery.
 *
 * Three kinds of thing live here, all of them shared between
 * C906_VIDU_RANDOM.c and vidu_sweeps.S:
 *
 *   1. Instruction-word builders for the encodings binutils will not emit on
 *      request: FP ops with rm == 101 / 110 (illegal by construction,
 *      aq_idu_id_decd.v:945-946), the compressed FP loads and stores, and the
 *      eight Xtheadc indexed FP forms.
 *   2. The FP operand pool: every corner of the IEEE-754 encoding space, as
 *      64-bit patterns rather than C doubles, so that GCC never has to
 *      materialise a constant and never allocates an FP register of its own.
 *   3. VIDU_FP_SWITCH(), which turns a runtime register number into one of 32
 *      literal FP register names.
 *
 * Included from both C and assembly, so everything outside the __ASSEMBLER__
 * guard has to be a #define.
 */

#ifndef VIDU_DEFS_H
#define VIDU_DEFS_H

#include "rand_common.h"

/* ==================================================================== *
 * Instruction-word builders.
 *
 * These are all used inside a `.word` / `.2byte` -- either via rand_common.h's
 * TH_OP() / RAW_OP16(), which stringify their argument straight into an
 * inline-asm template, or directly from vidu_sweeps.S. That rules out the
 * builders in rand_th_insn.h: TH_IDX() casts its fields to `(unsigned)` and its
 * bases carry a `U` suffix, and GAS parses neither, so
 *
 *     .word TH_IDX(TH_FLRD_B, 5, 10, 11, 3)
 *
 * fails with "found '(', expected: ')'". Everything below is cast-free and
 * suffix-free, which is what makes one macro usable from C and from assembly.
 * Every encoding was verified byte-for-byte against the assembler's own output
 * for the corresponding mnemonic.
 * ==================================================================== */

/* fmt field of the FP opcodes: S, D, H. (Q is not implemented.) */
#define VIDU_FMT_S      0
#define VIDU_FMT_D      1
#define VIDU_FMT_H      2

/* OP-FP (opcode 1010011): funct7 rs2 rs1 rm rd. funct7 = {funct5, fmt}. */
#define VIDU_FP_OP(f7, rs2, rs1, rm, rd)                                     \
        ((((f7)  & 0x7f) << 25) | (((rs2) & 31) << 20) | (((rs1) & 31) << 15) \
       | (((rm)  &    7) << 12) | (((rd)  & 31) <<  7) | 0x53)

/* funct7 values for the arithmetic ops the rm-illegal group needs. */
#define VIDU_F7_FADD_S  0x00
#define VIDU_F7_FADD_D  0x01
#define VIDU_F7_FADD_H  0x02
#define VIDU_F7_FSUB_D  0x05
#define VIDU_F7_FMUL_S  0x08
#define VIDU_F7_FMUL_D  0x09
#define VIDU_F7_FDIV_D  0x0d
#define VIDU_F7_FDIV_H  0x0e
#define VIDU_F7_FSQRT_D 0x2d
#define VIDU_F7_FCVT_WD 0x61    /* fcvt.w.d / fcvt.wu.d, rs2 picks which */
#define VIDU_F7_FCVT_SD 0x20    /* fcvt.s.d, rs2 = 1                     */

/* Fused multiply-add family: rs3 fmt rs2 rs1 rm rd, opcode picks the sign
 * pattern. These are the only three-source FP instructions, hence the only
 * users of the srcf2 read port outside FP stores. */
#define VIDU_OPC_FMADD   0x43
#define VIDU_OPC_FMSUB   0x47
#define VIDU_OPC_FNMSUB  0x4b
#define VIDU_OPC_FNMADD  0x4f
#define VIDU_FMA_OP(opc, rs3, fmt, rs2, rs1, rm, rd)                          \
        ((((rs3) & 31) << 27) | (((fmt) &  3) << 25) | (((rs2) & 31) << 20)    \
       | (((rs1) & 31) << 15) | (((rm)  &  7) << 12) | (((rd)  & 31) <<  7)    \
       | ((opc) & 0x7f))

/* Compressed FP loads and stores -- zero of these appear in
 * ISA/ISA_FP/C906_FPU_SMOKE.s, so every one is new coverage.
 *
 *   c.fld  / c.fsd    CL/CS format, rs1' and rd'/rs2' are 3-bit (x8-x15 /
 *                     f8-f15), uimm[7:3] scaled by 8
 *   c.fldsp/ c.fsdsp  CI/CSS format, full 5-bit FP register, uimm[8:3]
 *                     scaled by 8, base is always sp -- which is why the
 *                     sweep in vidu_sweeps.S allocates its own frame first. */
#define VIDU_C_FLD(rdp, rs1p, off)                                            \
        (0x2000 | ((((off) >> 3) & 7) << 10) | (((rs1p) & 7) << 7)             \
                | ((((off) >> 6) & 3) <<  5) | (((rdp)  & 7) << 2))
#define VIDU_C_FSD(rs2p, rs1p, off)                                           \
        (0xa000 | ((((off) >> 3) & 7) << 10) | (((rs1p) & 7) << 7)             \
                | ((((off) >> 6) & 3) <<  5) | (((rs2p) & 7) << 2))
#define VIDU_C_FLDSP(rd, off)                                                 \
        (0x2002 | ((((off) >> 5) & 1) << 12) | (((rd) & 31) << 7)              \
                | ((((off) >> 3) & 3) <<  5) | ((((off) >> 6) & 7) << 2))
#define VIDU_C_FSDSP(rs2, off)                                                \
        (0xa002 | ((((off) >> 3) & 7) << 10) | ((((off) >> 6) & 7) << 7)       \
                | (((rs2) & 31) << 2))

/* The eight Xtheadc indexed FP forms (aq_idu_id_decd.v:3671-3726). The decoder
 * selects on {inst[31:27], inst[14:12], inst[6:0]} and inst[26:25] is the 2-bit
 * shift applied to the index register, so each base below is the funct5 field
 * with the shift left at zero.
 *
 * Cast-free copies of TH_FLRW_B .. TH_FSURD_B from rand_th_insn.h, for the
 * reason given at the top of this section. */
#define VIDU_TH_FLRW    0x4000600b
#define VIDU_TH_FLRD    0x6000600b
#define VIDU_TH_FLURW   0x5000600b
#define VIDU_TH_FLURD   0x7000600b
#define VIDU_TH_FSRW    0x4000700b
#define VIDU_TH_FSRD    0x6000700b
#define VIDU_TH_FSURW   0x5000700b
#define VIDU_TH_FSURD   0x7000700b

/* Build one of the above with rs1 pinned to a0 (x10) and rs2 to a1 (x11), so
 * that VIDU_TH_FIDX_OP() below can hand the base address and the index in via
 * register-asm locals. `fd` is inst[11:7], and inst[11:7] really is the register
 * these forms use, on both the load and the store side:
 *
 *   loads   dstf  -- decd_inst_dstf_reg_32bit_low is (inst[1:0] == 2'b11) &&
 *                    !dstf_reg_32bit, so x_decd_dstf_reg = inst[11:7]
 *                    (aq_idu_id_decd.v:829, :835)
 *   stores  srcf2 -- decd_inst_vls is (inst[6:0] == 7'b0001011), which selects
 *                    arm 4'b1000 of the srcf2 mux: inst[11:7]
 *                    (aq_idu_id_decd.v:793, :811-812)
 *
 * The mux's `default` arm (inst[31:27]) belongs to the FMA family, whose opcodes
 * are 7'b100xx11 and therefore match none of the four qualifiers. Cross-checked
 * against the assembler: `th.fsrd f12, a0, a1, 0` is 0x60b5760b, and 12 sits in
 * inst[11:7], not in inst[31:27]. So sweeping `fd` sweeps the real register
 * field on all eight forms. */
#define VIDU_TH_FIDX(base, fd, sh)                                            \
        ((base) | (((sh) & 3) << 25) | (11 << 20) | (10 << 15)                 \
                | (((fd) & 31) << 7))

#ifndef __ASSEMBLER__

/* ==================================================================== *
 * Clobber list.
 *
 * Every FP asm block in this test lists all 32 FP registers. That is not
 * laziness: the register sweeps pick their target with a runtime index, so any
 * block may write any register, including the twelve that lp64d makes
 * callee-saved (f8, f9, f18..f27). Naming them all lets GCC do the right thing
 * -- it hoists one save/restore pair into the group function's prologue and
 * epilogue rather than one per asm block -- and it removes the need to reason
 * about which registers GCC might have thought were live. The save/restore is
 * itself fld/fsd traffic through VIDU, so it is not even wasted.
 * ==================================================================== */
#define VIDU_FCLOB                                                            \
    "f0",  "f1",  "f2",  "f3",  "f4",  "f5",  "f6",  "f7",                    \
    "f8",  "f9",  "f10", "f11", "f12", "f13", "f14", "f15",                   \
    "f16", "f17", "f18", "f19", "f20", "f21", "f22", "f23",                   \
    "f24", "f25", "f26", "f27", "f28", "f29", "f30", "f31"

/* n instructions of separation between a producer and its consumer, expanded by
 * the assembler rather than by the preprocessor: `.rept` inside an asm template
 * means a distance sweep is one macro with one argument instead of twenty-four
 * hand-written nop strings. n == 0 is legal and emits nothing. */
#define VIDU_GAP(n) ".rept " #n "\n\tnop\n\t.endr\n\t"

/* Emit one Xtheadc indexed FP op with `b` in a0 and `i` in a1. The word has to
 * be a compile-time constant: a *runtime* instruction word would need
 * self-modifying code, which these tests deliberately avoid. */
#define VIDU_TH_FIDX_OP(word, b, i) do {                                      \
        register u64 b_ __asm__("a0") = (u64)(unsigned long)(b);               \
        register u64 i_ __asm__("a1") = (u64)(i);                              \
        __asm__ volatile (".word " STR(word)                                   \
                          :: "r"(b_), "r"(i_) : VIDU_FCLOB, "memory");         \
    } while (0)

/* ==================================================================== *
 * Runtime FP register selection.
 *
 * An FP register number cannot be a runtime value in an instruction, and a
 * table of 32 code blocks reached through a computed jump is out of the
 * question here -- the build uses -fno-jump-tables, and CLAUDE.md "Known Bugs"
 * records that an indirect jump used as a tail call stalls retirement on this
 * RTL. So the only way to spend a random number on "which FP register" is a
 * compare/branch tree over 32 literal arms, which is what this expands to.
 *
 * MAC receives the register *name token* (f0 .. f31) because that is what an
 * asm template needs. Each arm also records the register in vidu_regs_touched:
 * with no golden model, that bitmask is the only evidence at the end of a run
 * that the sweep reached the whole file rather than the low eight registers.
 * ==================================================================== */
#define VIDU_FP_ARM(n, F, MAC) \
        case n: vidu_regs_touched |= 1UL << (n); MAC(F); break

#define VIDU_FP_SWITCH(sel, MAC)                                              \
    switch ((unsigned)(sel) & 31u) {                                          \
    VIDU_FP_ARM( 0, f0,  MAC);  VIDU_FP_ARM( 1, f1,  MAC);                    \
    VIDU_FP_ARM( 2, f2,  MAC);  VIDU_FP_ARM( 3, f3,  MAC);                    \
    VIDU_FP_ARM( 4, f4,  MAC);  VIDU_FP_ARM( 5, f5,  MAC);                    \
    VIDU_FP_ARM( 6, f6,  MAC);  VIDU_FP_ARM( 7, f7,  MAC);                    \
    VIDU_FP_ARM( 8, f8,  MAC);  VIDU_FP_ARM( 9, f9,  MAC);                    \
    VIDU_FP_ARM(10, f10, MAC);  VIDU_FP_ARM(11, f11, MAC);                    \
    VIDU_FP_ARM(12, f12, MAC);  VIDU_FP_ARM(13, f13, MAC);                    \
    VIDU_FP_ARM(14, f14, MAC);  VIDU_FP_ARM(15, f15, MAC);                    \
    VIDU_FP_ARM(16, f16, MAC);  VIDU_FP_ARM(17, f17, MAC);                    \
    VIDU_FP_ARM(18, f18, MAC);  VIDU_FP_ARM(19, f19, MAC);                    \
    VIDU_FP_ARM(20, f20, MAC);  VIDU_FP_ARM(21, f21, MAC);                    \
    VIDU_FP_ARM(22, f22, MAC);  VIDU_FP_ARM(23, f23, MAC);                    \
    VIDU_FP_ARM(24, f24, MAC);  VIDU_FP_ARM(25, f25, MAC);                    \
    VIDU_FP_ARM(26, f26, MAC);  VIDU_FP_ARM(27, f27, MAC);                    \
    VIDU_FP_ARM(28, f28, MAC);  VIDU_FP_ARM(29, f29, MAC);                    \
    VIDU_FP_ARM(30, f30, MAC);  default: vidu_regs_touched |= 1UL << 31;       \
                                MAC(f31); break;                              \
    }

/* ==================================================================== *
 * FP operand pool.
 *
 * 64-bit patterns, not C doubles: a `double` constant would make GCC allocate
 * an FP register and emit its own fld, which is stimulus this file did not
 * choose. Each entry is interesting in at least one of the three widths -- the
 * low 32 bits of most of them are a meaningful float and the low 16 a
 * meaningful half, which is how the .s and .h ops get corner-case inputs from
 * the same table.
 * ==================================================================== */
#define VIDU_NPOOL 32
static const u64 vidu_fp_pool[VIDU_NPOOL] = {
    0x0000000000000000UL,   /*  +0.0                                        */
    0x8000000000000000UL,   /*  -0.0                                        */
    0x0000000000000001UL,   /*  + smallest denormal (also a float/half one) */
    0x8000000000000001UL,   /*  - smallest denormal                         */
    0x000fffffffffffffUL,   /*  + largest denormal                          */
    0x0010000000000000UL,   /*  + smallest normal                           */
    0x7fefffffffffffffUL,   /*  + largest normal                            */
    0xffefffffffffffffUL,   /*  - largest normal                            */
    0x7ff0000000000000UL,   /*  +inf                                        */
    0xfff0000000000000UL,   /*  -inf                                        */
    0x7ff8000000000000UL,   /*  qNaN                                        */
    0x7ff4000000000000UL,   /*  sNaN                                        */
    0xfff4000000000000UL,   /*  -sNaN                                       */
    0x3ff0000000000000UL,   /*  1.0                                         */
    0xbff0000000000000UL,   /* -1.0                                         */
    0x4000000000000000UL,   /*  2.0     -- exact power of two, FDSU fast    */
    0x3fe0000000000000UL,   /*  0.5                                         */
    0x400921fb54442d18UL,   /*  pi      -- guarantees an inexact result     */
    0x4340000000000000UL,   /*  2^53    -- integer-boundary rounding        */
    0x3cb0000000000000UL,   /*  2^-52                                       */
    0x7f8000007f800000UL,   /*  two +inf floats                             */
    0x7fc000007fa00000UL,   /*  qNaN float | sNaN float                     */
    0x0000000100000001UL,   /*  two float denormals                         */
    0x7c007e007bff0001UL,   /*  half +inf, qNaN, max normal, denormal       */
    0x7bff7bff7bff7bffUL,   /*  four half max normals                       */
    0x0001000100010001UL,   /*  four half denormals                         */
    0x8000800080008000UL,   /*  four half -0.0                              */
    0x3c003c003c003c00UL,   /*  four half 1.0                               */
    0xffffffffffffffffUL,   /*  -NaN, all ones                              */
    0x5555555555555555UL,   /*  random-ish mantissa, small exponent         */
    0xaaaaaaaaaaaaaaaaUL,   /*  ditto, negative                             */
    0x0123456789abcdefUL    /*  ditto, denormal exponent                    */
};

/* The operands that make the FDSU take a short path: zero, infinity, NaN and
 * exact powers of two never enter the iterative datapath. Group 19 draws from
 * here so that the long-latency unit is exercised on both its fast and its slow
 * route rather than only the slow one. */
#define VIDU_NFDSU 8
static const u64 vidu_fdsu_pool[VIDU_NFDSU] = {
    0x0000000000000000UL,   /*  +0.0   -> DZ on divide, exact on sqrt       */
    0x8000000000000000UL,   /*  -0.0                                        */
    0x7ff0000000000000UL,   /*  +inf                                        */
    0x7ff8000000000000UL,   /*  qNaN                                        */
    0x3ff0000000000000UL,   /*  1.0    -- exact                             */
    0x4010000000000000UL,   /*  4.0    -- exact sqrt                        */
    0xc000000000000000UL,   /* -2.0    -- NV on sqrt                        */
    0x400921fb54442d18UL    /*  pi     -- the slow path                     */
};

/* Half precision is the least-covered width in C906_FPU_SMOKE.s (4 fsqrt.h and
 * no fsgnj.h at all), so group 36 gets its own pool of 16-bit corners,
 * replicated across the 64-bit register so that whichever lane the RTL reads is
 * still meaningful. */
#define VIDU_NHALF 8
static const u64 vidu_half_pool[VIDU_NHALF] = {
    0x0000000000000000UL,   /*  +0.0                                        */
    0x8000800080008000UL,   /*  -0.0                                        */
    0x0001000100010001UL,   /*  smallest denormal                           */
    0x03ff03ff03ff03ffUL,   /*  largest denormal                            */
    0x0400040004000400UL,   /*  smallest normal                             */
    0x7bff7bff7bff7bffUL,   /*  largest normal                              */
    0x7c007c007c007c00UL,   /*  +inf                                        */
    0x7e007d007e007d00UL    /*  qNaN | sNaN                                 */
};

/* ==================================================================== *
 * vidu_sweeps.S
 *
 * Everything that has to touch all 32 FP registers, all six FP load/store
 * widths or all six rounding modes lives there as a `.irp`-generated straight
 * line: an assembler loop can vary a register number, a C macro cannot, and
 * these sweeps have no need of a random value.
 *
 * Each one takes a base pointer into the case-local arena and is ABI-clean --
 * it saves and restores f8/f9/f18..f27 itself. `vidu_zero_all_fp` deliberately
 * does not, because at the point it runs those registers hold X.
 * ==================================================================== */
void vidu_zero_all_fp(void);
u64  vidu_sweep_wbt_all_regs(volatile u64 *base);
void vidu_sweep_rm_static(volatile u64 *base);
u64  vidu_sweep_flsu_std(volatile u64 *base);
void vidu_sweep_flsu_c(volatile u64 *base);
u64  vidu_sweep_regfile_walk(volatile u64 *base);
u64  vidu_sweep_fld_burst(volatile u64 *base);
void vidu_sweep_h_all_rm(volatile u64 *base);

#endif /* !__ASSEMBLER__ */

#endif /* VIDU_DEFS_H */
