/*
 * idu_random: the WHITELISTED instruction-encoding table.
 *
 * ==================================================================== *
 * THE RULE THIS FILE EXISTS TO ENFORCE
 * ==================================================================== *
 * The obvious way to stress a decoder is to cast a random 64-bit word down to
 * 32 bits and execute it. Do not. A uniformly random word is, with useful
 * probability:
 *
 *   - `wfi`  -- retirement stops, the testbench's 50,000-cycle no-retire
 *               watchdog fires, and a WFI with nothing armed in (mie & mip) is
 *               unrecoverable short of reset (aq_cp0_lpmd.v:190);
 *   - `csrw mtvec, x0` -- the next trap vectors to address 0 and the harness
 *               loses its handler;
 *   - `mret` / `sret` -- a jump to whatever mepc/sepc happens to hold;
 *   - `ebreak` with a debug trigger armed;
 *   - an arbitrary store, i.e. our own stack, our own globals, or the UART;
 *   - `sfence.vma` with satp non-Bare, or a wild jump;
 *   - a write to x1 / x2 / x3 / x4 (ra / sp / gp / tp -- and tp holds
 *               &rand_ctx, which is how the trap handler finds its own state).
 *
 * So every stream in this test is built from the table below: a curated list of
 * *bases* whose register and immediate fields are filled in from a small set of
 * hardwired, safe operand slots. That is exactly what cp0_random's 42 groups
 * already do, and it turns the decode matrix into a sweep rather than a lottery.
 *
 * ==================================================================== *
 * WHY EVERY ENCODING IS A COMPILE-TIME CONSTANT
 * ==================================================================== *
 * Emitting an instruction whose fields were computed at run time would need
 * self-modifying code, which these tests deliberately avoid (a D-cache clean, a
 * fence.i and an I-cache invalidate per instruction, and a whole new class of
 * failure). The `"n"` (known-numeric-immediate) constraint gets the same effect
 * for free: the C preprocessor does the field arithmetic, GCC proves the result
 * is a constant, and the assembler emits it as a literal `.word`.
 *
 *     IDU_WORD(TH_R(TH_TSTNBZ_B, IDU_RD, IDU_RS1, 0));
 *
 * Consequently *field* diversity comes from a switch over compile-time
 * variants, not from a runtime value -- and the mechanically enumerable leaves
 * (the immediate-select cases and the 96 GPR read-port mux bins) are emitted
 * exhaustively by gen_idu_sweeps.py instead of being sampled here.
 *
 * ==================================================================== *
 * THE OPERAND SLOTS
 * ==================================================================== *
 * Fixed, so that every raw word in this test can be read next to the inline-asm
 * constraint list that tells GCC what it touches. All six are in
 * rand_safe_regs, all are caller-saved, and none of them is ra / sp / gp / tp /
 * s0.
 *
 *   IDU_RD    x10  a0   destination
 *   IDU_RS1   x11  a1   first source
 *   IDU_RS2   x12  a2   second source, or the index of an indexed memory op
 *   IDU_BASE  x13  a3   base address register -- always a pointer into
 *                       rand_scratch, never sp
 *   IDU_RD2   x14  a4   second destination (the LSD pair, dst1)
 *   IDU_ALT   x15  a5   spare
 *
 * FP operands are fa0 / fa1 / fa2 (f10 / f11 / f12), which is why the FP raw
 * words also use register number 10/11/12 in their fields.
 */

#ifndef IDU_ENCODINGS_H
#define IDU_ENCODINGS_H

#include "rand_common.h"

#define IDU_RD    10
#define IDU_RS1   11
#define IDU_RS2   12
#define IDU_BASE  13
#define IDU_RD2   14
#define IDU_ALT   15

/* ==================================================================== *
 * Raw emitters. No operand list at all, so these are ONLY for encodings that
 * are illegal by construction: an illegal instruction traps before it can write
 * anything, so GCC does not need to be told which register the encoding names.
 * Anything that actually executes must go through one of the operand-pinned
 * emitters below, or through IDU_HALF_A0 -- otherwise a live value in the
 * register the encoding writes is silently destroyed.
 * ==================================================================== */
#define IDU_WORD(w) \
        __asm__ volatile (".word %[w_]" :: [w_]"n"((unsigned)(w)) : "memory")
#define IDU_HALF(h) \
        __asm__ volatile (".2byte %[h_]" :: [h_]"n"((unsigned)(h)) : "memory")

/* A raw halfword that DOES execute and whose destination is a0. Needed for
 * C_LUI_A0_1: c.lui is the only producer of the ALU adder's rs1 one-hot arm
 * 5'b00001, GCC will not emit it on request, and the register number is baked
 * into the 16-bit encoding -- so a0 has to be declared as an output. */
#define IDU_HALF_A0(h) do {                                                 \
        register u64 d_ __asm__("a0");                                      \
        __asm__ volatile (".2byte %[h_]"                                    \
            : "=r"(d_) : [h_]"n"((unsigned)(h)) : "memory");                \
        rand_sink += d_;                                                    \
    } while (0)

/* ==================================================================== *
 * Operand-pinned emitters.
 *
 * Each one declares the exact registers its raw word reads and writes, so GCC
 * neither keeps a live value in them nor assumes they survived. `volatile` plus
 * the "memory" clobber keeps the instruction where it was written, which the
 * back-to-back interlock groups depend on.
 * ==================================================================== */

/* R-form: a0 = f(a1, a2). */
#define IDU_R(base, v1, v2) do {                                            \
        register u64 d_  __asm__("a0");                                     \
        register u64 x_  __asm__("a1") = (u64)(v1);                         \
        register u64 y_  __asm__("a2") = (u64)(v2);                         \
        __asm__ volatile (".word %[w_]"                                     \
            : "=r"(d_)                                                      \
            : [w_]"n"(TH_R((base), IDU_RD, IDU_RS1, IDU_RS2)),              \
              "r"(x_), "r"(y_) : "memory");                                 \
        rand_sink += d_;                                                    \
    } while (0)

/* R-form with rs2 hardwired to x0: th.tstnbz / rev / ff0 / ff1 / revw. Any
 * other rs2 makes them illegal (aq_idu_id_decd.v:875-878), which is group 27. */
#define IDU_R0(base, v1) do {                                               \
        register u64 d_  __asm__("a0");                                     \
        register u64 x_  __asm__("a1") = (u64)(v1);                         \
        __asm__ volatile (".word %[w_]"                                     \
            : "=r"(d_)                                                      \
            : [w_]"n"(TH_R((base), IDU_RD, IDU_RS1, 0)), "r"(x_)            \
            : "memory");                                                    \
        rand_sink += d_;                                                    \
    } while (0)

/* I-form with a literal immediate in inst[25:20] or inst[24:20]:
 * th.srri / srriw / tst. */
#define IDU_I(base, imm, v1) do {                                           \
        register u64 d_  __asm__("a0");                                     \
        register u64 x_  __asm__("a1") = (u64)(v1);                         \
        __asm__ volatile (".word %[w_]"                                     \
            : "=r"(d_)                                                      \
            : [w_]"n"(TH_I((base), IDU_RD, IDU_RS1, (imm))), "r"(x_)        \
            : "memory");                                                    \
        rand_sink += d_;                                                    \
    } while (0)

/* th.ext / th.extu: msb = inst[31:26], lsb = inst[25:20]. */
#define IDU_EXT(base, msb, lsb, v1) do {                                    \
        register u64 d_  __asm__("a0");                                     \
        register u64 x_  __asm__("a1") = (u64)(v1);                         \
        __asm__ volatile (".word %[w_]"                                     \
            : "=r"(d_)                                                      \
            : [w_]"n"(TH_EXT((base), IDU_RD, IDU_RS1, (msb), (lsb))),       \
              "r"(x_) : "memory");                                          \
        rand_sink += d_;                                                    \
    } while (0)

/* th.addsl: rd = rs2 + (rs1 << imm2), imm2 = inst[26:25]. */
#define IDU_ADDSL(sh, v1, v2) do {                                          \
        register u64 d_  __asm__("a0");                                     \
        register u64 x_  __asm__("a1") = (u64)(v1);                         \
        register u64 y_  __asm__("a2") = (u64)(v2);                         \
        __asm__ volatile (".word %[w_]"                                     \
            : "=r"(d_)                                                      \
            : [w_]"n"(TH_ADDSL(IDU_RD, IDU_RS1, IDU_RS2, (sh))),            \
              "r"(x_), "r"(y_) : "memory");                                 \
        rand_sink += d_;                                                    \
    } while (0)

/* The th.mula / muls / mulaw / mulsw / mulah / mulsh family: rd is read as the
 * accumulator and written as the result, i.e. the only Xtheadc arithmetic form
 * with a src2 that is not an immediate. */
#define IDU_ACC(base, acc, v1, v2) do {                                     \
        register u64 d_  __asm__("a0") = (u64)(acc);                        \
        register u64 x_  __asm__("a1") = (u64)(v1);                         \
        register u64 y_  __asm__("a2") = (u64)(v2);                         \
        __asm__ volatile (".word %[w_]"                                     \
            : "+r"(d_)                                                      \
            : [w_]"n"(TH_R((base), IDU_RD, IDU_RS1, IDU_RS2)),              \
              "r"(x_), "r"(y_) : "memory");                                 \
        rand_sink += d_;                                                    \
    } while (0)

/* ==================================================================== *
 * Indexed memory forms. `ptr` is always IDU_PTR()/IDU_PTR_LINE(), i.e. inside
 * rand_scratch, and the index and immediate are always small enough that the
 * effective address cannot leave the array (see idu_defs.h).
 * ==================================================================== */

/* th.lr{b,h,w,d,bu,hu,wu} / th.lur*: a0 = mem[a3 + (a2 << sh)]. */
#define IDU_IDXLD(base, sh, ptr, idx) do {                                  \
        register u64 d_  __asm__("a0");                                     \
        register u64 p_  __asm__("a3") = (u64)(ptr);                        \
        register u64 i_  __asm__("a2") = (u64)(idx);                        \
        __asm__ volatile (".word %[w_]"                                     \
            : "=r"(d_)                                                      \
            : [w_]"n"(TH_IDX((base), IDU_RD, IDU_BASE, IDU_RS2, (sh))),     \
              "r"(p_), "r"(i_) : "memory");                                 \
        rand_sink += d_;                                                    \
    } while (0)

/* th.l{b,h,w,d,bu,hu,wu}{ib,ia}: a0 = mem[...] and a3 is updated. a3 is
 * dst1 = inst[19:15] (aq_idu_id_decd.v:764) -- the only encodings in the ISA
 * that use dst1, hence the only route to ctrl_dis_dst1_waw. */
#define IDU_IDXUPD(base, sh, imm5, ptr) do {                                \
        register u64 d_  __asm__("a0");                                     \
        register u64 p_  __asm__("a3") = (u64)(ptr);                        \
        __asm__ volatile (".word %[w_]"                                     \
            : "=r"(d_), "+r"(p_)                                            \
            : [w_]"n"(TH_IDX((base), IDU_RD, IDU_BASE, (imm5), (sh)))       \
            : "memory");                                                    \
        rand_sink += d_ + p_;                                               \
    } while (0)

/* Same shape, but rd and the base are the SAME register: both writeback ports
 * land on one GPR (aq_idu_id_dp.v:593-617). Group 36. */
#define IDU_IDXUPD_SAME(base, sh, imm5, ptr) do {                           \
        register u64 p_  __asm__("a3") = (u64)(ptr);                        \
        __asm__ volatile (".word %[w_]"                                     \
            : "+r"(p_)                                                      \
            : [w_]"n"(TH_IDX((base), IDU_BASE, IDU_BASE, (imm5), (sh)))     \
            : "memory");                                                    \
        rand_sink += p_;                                                    \
    } while (0)

/* th.sr{b,h,w,d} / th.sur*: mem[a3 + (a2 << sh)] = a0. For opcode 0001011 the
 * store data is src2 = inst[11:7], because decd_inst_src2_reg_32bit_24_20 only
 * matches opcodes 0100011/0100111 (aq_idu_id_decd.v:698-701). */
#define IDU_IDXST(base, sh, data, ptr, idx) do {                            \
        register u64 v_  __asm__("a0") = (u64)(data);                       \
        register u64 p_  __asm__("a3") = (u64)(ptr);                        \
        register u64 i_  __asm__("a2") = (u64)(idx);                        \
        __asm__ volatile (".word %[w_]"                                     \
            :: [w_]"n"(TH_IDX((base), IDU_RD, IDU_BASE, IDU_RS2, (sh))),    \
               "r"(v_), "r"(p_), "r"(i_) : "memory");                       \
    } while (0)

/* th.s{b,h,w,d}{ib,ia}: mem[...] = a0 and a3 is updated. */
#define IDU_IDXSTUPD(base, sh, imm5, data, ptr) do {                        \
        register u64 v_  __asm__("a0") = (u64)(data);                       \
        register u64 p_  __asm__("a3") = (u64)(ptr);                        \
        __asm__ volatile (".word %[w_]"                                     \
            : "+r"(p_)                                                      \
            : [w_]"n"(TH_IDX((base), IDU_RD, IDU_BASE, (imm5), (sh))),      \
              "r"(v_) : "memory");                                          \
        rand_sink += p_;                                                    \
    } while (0)

/* th.flr{w,d} / th.flur*: fa0 = mem[a3 + (a2 << sh)], folded through fmv.x.d so
 * the result reaches rand_sink without an FP compare or an FP store. */
#define IDU_FIDXLD(base, sh, ptr, idx) do {                                 \
        u64 o_;                                                             \
        register u64 p_  __asm__("a3") = (u64)(ptr);                        \
        register u64 i_  __asm__("a2") = (u64)(idx);                        \
        __asm__ volatile (".word %[w_]\n\t"                                 \
                          "fmv.x.d %[o_], fa0"                              \
            : [o_]"=r"(o_)                                                  \
            : [w_]"n"(TH_IDX((base), IDU_RD, IDU_BASE, IDU_RS2, (sh))),     \
              "r"(p_), "r"(i_) : "memory", "fa0");                          \
        rand_sink += o_;                                                    \
    } while (0)

/* th.fsr{w,d} / th.fsur*: mem[a3 + (a2 << sh)] = fa0, whose value is planted
 * with fmv.d.x from the FP bit pool. */
#define IDU_FIDXST(base, sh, bits, ptr, idx) do {                           \
        register u64 b_  __asm__("a1") = (u64)(bits);                       \
        register u64 p_  __asm__("a3") = (u64)(ptr);                        \
        register u64 i_  __asm__("a2") = (u64)(idx);                        \
        __asm__ volatile ("fmv.d.x fa0, %[b_]\n\t"                          \
                          ".word %[w_]"                                     \
            :: [w_]"n"(TH_IDX((base), IDU_RD, IDU_BASE, IDU_RS2, (sh))),    \
               [b_]"r"(b_), "r"(p_), "r"(i_) : "memory", "fa0");            \
    } while (0)

/* th.lwd / lwud / ldd: cracked into two uops by aq_idu_id_split.v:153-295. The
 * pair destinations are inst[11:7] (a0) and inst[24:20] (a4); the base is
 * inst[19:15] (a3) and the offset scale is imm2 = inst[26:25]. */
#define IDU_LSDLD(base, sh, ptr) do {                                       \
        register u64 d0_ __asm__("a0");                                     \
        register u64 d1_ __asm__("a4");                                     \
        register u64 p_  __asm__("a3") = (u64)(ptr);                        \
        __asm__ volatile (".word %[w_]"                                     \
            : "=r"(d0_), "=r"(d1_)                                          \
            : [w_]"n"(TH_IDX((base), IDU_RD, IDU_BASE, IDU_RD2, (sh))),     \
              "r"(p_) : "memory");                                          \
        rand_sink += d0_ + d1_;                                             \
    } while (0)

/* th.swd / sdd: the same crack, with the pair as sources instead. */
#define IDU_LSDST(base, sh, v0, v1, ptr) do {                               \
        register u64 d0_ __asm__("a0") = (u64)(v0);                         \
        register u64 d1_ __asm__("a4") = (u64)(v1);                         \
        register u64 p_  __asm__("a3") = (u64)(ptr);                        \
        __asm__ volatile (".word %[w_]"                                     \
            :: [w_]"n"(TH_IDX((base), IDU_RD, IDU_BASE, IDU_RD2, (sh))),    \
               "r"(d0_), "r"(d1_), "r"(p_) : "memory");                     \
    } while (0)

/* A form whose only operand is the address in inst[19:15]. Distinct from the
 * harness's TH_OP_RS1 only in that the register number is the table's own
 * IDU_BASE rather than a0.
 *
 * Note the asymmetry: no destination is declared. That makes this usable ONLY
 * for encodings whose rd is irrelevant because the instruction cannot retire --
 * the FS==0 and THEADISAEE==0 groups, where the whole opcode is illegal.
 * Anything that executes needs IDU_IDXLD or one of its siblings.
 *
 * a2 IS declared, and pinned to zero. Every caller passes an indexed form whose
 * inst[24:20] names a2, so if the illegality argument were ever wrong the
 * effective address would be a3 + (a2 << sh) with a2 holding whatever the
 * compiler happened to leave there -- a wild store for the fsr/fsur arms. With
 * a2 == 0 the worst case is an access to `ptr` itself, i.e. inside
 * rand_scratch. The zero costs one `li` and removes the whole class. */
#define IDU_ADDR_OP(word, ptr) do {                                         \
        register u64 p_  __asm__("a3") = (u64)(ptr);                        \
        register u64 z_  __asm__("a2") = 0;                                 \
        __asm__ volatile (".word %[w_]"                                     \
            :: [w_]"n"((unsigned)(word) | (IDU_BASE << 15)),                \
               "r"(p_), "r"(z_) : "memory");                                \
    } while (0)

/* ==================================================================== *
 * Mnemonic-based emitters.
 *
 * For everything the assembler will emit for us -- the whole RV64GC base, the
 * F/D/Zfh tables, the AMO matrix -- a mnemonic IS a whitelist entry, and it is
 * both shorter and far less likely to be mis-encoded than a hand-built word.
 * The decoder cannot tell the difference. Raw words are reserved for what
 * binutils will not assemble on request: the Xtheadc family (THEAD_GCC=0 builds
 * have no xtheadc), the illegal reserved-field forms, and the dead vector
 * encodings.
 * ==================================================================== */
#define IDU_M_RR(op, v1, v2) do {                                           \
        u64 d_; u64 x_ = (u64)(v1), y_ = (u64)(v2);                         \
        __asm__ volatile (op " %0, %1, %2" : "=r"(d_) : "r"(x_), "r"(y_));  \
        rand_sink += d_;                                                    \
    } while (0)

#define IDU_M_RI(op, v1, imm) do {                                          \
        u64 d_; u64 x_ = (u64)(v1);                                         \
        __asm__ volatile (op " %0, %1, %2" : "=r"(d_) : "r"(x_), "i"(imm)); \
        rand_sink += d_;                                                    \
    } while (0)

#define IDU_M_LOAD(op, ptr, off) do {                                       \
        u64 d_;                                                             \
        __asm__ volatile (op " %0, " STR(off) "(%1)"                        \
                          : "=r"(d_) : "r"(ptr) : "memory");                \
        rand_sink += d_;                                                    \
    } while (0)

#define IDU_M_STORE(op, ptr, off, v) \
        __asm__ volatile (op " %0, " STR(off) "(%1)"                        \
                          :: "r"((u64)(v)), "r"(ptr) : "memory")

/* FP: operands are planted with fmv.d.x and the result folded with fmv.x.d, so
 * no FP value ever crosses an inline-asm boundary as a C `double` and no
 * .rodata constant pool is needed. */
#define IDU_M_FP2(op, b1, b2) do {                                          \
        u64 o_; u64 x_ = (u64)(b1), y_ = (u64)(b2);                         \
        __asm__ volatile ("fmv.d.x fa1, %1\n\t"                             \
                          "fmv.d.x fa2, %2\n\t"                             \
                          op " fa0, fa1, fa2\n\t"                           \
                          "fmv.x.d %0, fa0"                                 \
                          : "=r"(o_) : "r"(x_), "r"(y_)                     \
                          : "fa0", "fa1", "fa2");                           \
        rand_sink += o_;                                                    \
    } while (0)

/* Same, with an explicit static rounding mode in inst[14:12]. Separate from
 * IDU_M_FP2 because the rm suffix has to land after the register list. */
#define IDU_M_FP2_RM(op, rm, b1, b2) do {                                   \
        u64 o_; u64 x_ = (u64)(b1), y_ = (u64)(b2);                         \
        __asm__ volatile ("fmv.d.x fa1, %1\n\t"                             \
                          "fmv.d.x fa2, %2\n\t"                             \
                          op " fa0, fa1, fa2, " rm "\n\t"                   \
                          "fmv.x.d %0, fa0"                                 \
                          : "=r"(o_) : "r"(x_), "r"(y_)                     \
                          : "fa0", "fa1", "fa2");                           \
        rand_sink += o_;                                                    \
    } while (0)

#define IDU_M_FP1(op, b1) do {                                              \
        u64 o_; u64 x_ = (u64)(b1);                                         \
        __asm__ volatile ("fmv.d.x fa1, %1\n\t"                             \
                          op " fa0, fa1\n\t"                               \
                          "fmv.x.d %0, fa0"                                 \
                          : "=r"(o_) : "r"(x_) : "fa0", "fa1");             \
        rand_sink += o_;                                                    \
    } while (0)

/* FP -> integer (fcvt.w.s, fmv.x.w, feq, fclass, ...). */
#define IDU_M_FP2X(op, b1, b2) do {                                         \
        u64 o_; u64 x_ = (u64)(b1), y_ = (u64)(b2);                         \
        __asm__ volatile ("fmv.d.x fa1, %1\n\t"                             \
                          "fmv.d.x fa2, %2\n\t"                             \
                          op " %0, fa1, fa2"                                \
                          : "=r"(o_) : "r"(x_), "r"(y_) : "fa1", "fa2");    \
        rand_sink += o_;                                                    \
    } while (0)

#define IDU_M_FP1X(op, b1) do {                                             \
        u64 o_; u64 x_ = (u64)(b1);                                         \
        __asm__ volatile ("fmv.d.x fa1, %1\n\t"                             \
                          op " %0, fa1"                                     \
                          : "=r"(o_) : "r"(x_) : "fa1");                    \
        rand_sink += o_;                                                    \
    } while (0)

/* integer -> FP (fcvt.s.w, fmv.w.x, ...). */
#define IDU_M_XFP(op, v1) do {                                              \
        u64 o_; u64 x_ = (u64)(v1);                                         \
        __asm__ volatile (op " fa0, %1\n\t"                                 \
                          "fmv.x.d %0, fa0"                                 \
                          : "=r"(o_) : "r"(x_) : "fa0");                    \
        rand_sink += o_;                                                    \
    } while (0)

/* Fused multiply-add: four FP registers. */
#define IDU_M_FMA(op, b1, b2, b3) do {                                      \
        u64 o_; u64 x_ = (u64)(b1), y_ = (u64)(b2), z_ = (u64)(b3);         \
        __asm__ volatile ("fmv.d.x fa1, %1\n\t"                             \
                          "fmv.d.x fa2, %2\n\t"                             \
                          "fmv.d.x fa3, %3\n\t"                             \
                          op " fa0, fa1, fa2, fa3\n\t"                      \
                          "fmv.x.d %0, fa0"                                 \
                          : "=r"(o_) : "r"(x_), "r"(y_), "r"(z_)            \
                          : "fa0", "fa1", "fa2", "fa3");                    \
        rand_sink += o_;                                                    \
    } while (0)

/* AMO / LR / SC. The address is always an 8-byte-aligned slot in rand_scratch,
 * i.e. normal cacheable SRAM; the strong-order and APB windows are never
 * touched (an AMO to either has nothing to do with the IDU and everything to
 * do with hanging the bus). */
#define IDU_M_AMO(op, ptr, v) do {                                          \
        u64 d_; u64 x_ = (u64)(v);                                          \
        __asm__ volatile (op " %0, %2, (%1)"                                \
                          : "=r"(d_) : "r"(ptr), "r"(x_) : "memory");       \
        rand_sink += d_;                                                    \
    } while (0)

#define IDU_M_LR(op, ptr) do {                                              \
        u64 d_;                                                             \
        __asm__ volatile (op " %0, (%1)" : "=r"(d_) : "r"(ptr) : "memory"); \
        rand_sink += d_;                                                    \
    } while (0)

/* ==================================================================== *
 * Illegal encodings binutils will not emit on request.
 *
 * Every one of these is a reserved-field violation on an instruction whose
 * legal form would be dangerous, which is the entire point: `wfi` must never be
 * executed, but the decoder's `wfi` arm still has to be told that inst[11:7]
 * != 0 is illegal (aq_idu_id_decd.v:860-862). Setting a reserved bit gets the
 * decode path without the behaviour.
 * ==================================================================== */
#define IDU_ILL_ECALL     0x00000173u   /* ecall,  rd = x2        */
#define IDU_ILL_EBREAK    0x00108073u   /* ebreak, rs1 = x1       */
#define IDU_ILL_DRET      INSN_DRET     /* always illegal outside debug mode */
#define IDU_ILL_SRET      0x10208073u   /* sret,   rs1 = x1       */
#define IDU_ILL_WFI       0x105000f3u   /* wfi,    rd  = x1  -- NOT a wfi */
#define IDU_ILL_MRET      0x302000f3u   /* mret,   rd  = x1       */
#define IDU_ILL_SFENCE    0x120000f3u   /* sfence.vma, rd = x1    */
#define IDU_ILL_LR_W      0x1010202fu   /* lr.w,   rs2 = x1       */
#define IDU_ILL_LR_D      0x1010302fu   /* lr.d,   rs2 = x1       */
#define IDU_ILL_HFENCE    INSN_HFENCE_VVMA

/* Xtheadc forms that require rs2 == 0 (aq_idu_id_decd.v:875-878). */
#define IDU_ILL_TSTNBZ    TH_R(TH_TSTNBZ_B, IDU_RD, IDU_RS1, 1)
#define IDU_ILL_REV       TH_R(TH_REV_B,    IDU_RD, IDU_RS1, 1)
#define IDU_ILL_FF0       TH_R(TH_FF0_B,    IDU_RD, IDU_RS1, 1)
#define IDU_ILL_FF1       TH_R(TH_FF1_B,    IDU_RD, IDU_RS1, 1)
#define IDU_ILL_REVW      TH_R(TH_REVW_B,   IDU_RD, IDU_RS1, 1)

/* The six decd_c_illegal terms (aq_idu_id_decd.v:883-897), as raw halfwords.
 * c.addi16sp with imm == 0 and c.lui with imm == 0 share one RTL term but are
 * distinguished by inst[11:7], so both are listed. */
#define IDU_CILL_ADDI4SPN 0x0000u  /* c.addi4spn, imm == 0            */
#define IDU_CILL_ADDIW    0x2001u  /* c.addiw,    rd  == 0            */
#define IDU_CILL_ADDI16SP 0x6101u  /* c.addi16sp, imm == 0            */
#define IDU_CILL_LUI      0x6501u  /* c.lui a0,   imm == 0            */
#define IDU_CILL_LWSP     0x4002u  /* c.lwsp,     rd  == 0            */
#define IDU_CILL_LDSP     0x6002u  /* c.ldsp,     rd  == 0            */
#define IDU_CILL_JR       0x8002u  /* c.jr,       rs1 == 0            */

/* The vector decoder is tied off (decd_sel[5] = 1'b0, aq_idu_id_decd.v:1011),
 * so every RVV encoding must fall through to an illegal instruction. Opcode
 * 1010111 with each of the seven funct3 values covers every OPIVV / OPFVF /
 * OPMVX / OPCFG arm of the dead decoder at once. */
#define IDU_VEC_OPIVV     0x02000057u   /* vadd.vv    v0, v0, v0 */
#define IDU_VEC_OPFVV     0x02001057u
#define IDU_VEC_OPMVV     0x02002057u
#define IDU_VEC_OPIVI     0x02003057u
#define IDU_VEC_OPIVX     0x02004057u
#define IDU_VEC_OPFVF     0x02005057u
#define IDU_VEC_OPMVX     0x02006057u
#define IDU_VEC_OPCFG     INSN_VSETVLI
#define IDU_VEC_LOAD      0x02000007u   /* vle.v  -- LOAD-FP, funct3 = 000 */
#define IDU_VEC_STORE     0x02000027u   /* vse.v  -- STORE-FP              */

/* zvamo: aq_idu_id_split.v:355 keys on inst[14:13] == 2'b11, so funct3 110/111
 * on the AMO opcode sets zvamo_inst in the AMO FSM, whose uop would dispatch to
 * EU_VEC, which does not exist. In practice the 32-bit table rejects funct3
 * 110/111 on opcode 0101111 first (only 010 and 011 have arms,
 * aq_idu_id_decd.v:2017-2094), so this is a plain illegal instruction -- see
 * group 45 in C906_IDU_RANDOM.c for the measurement. */
#define IDU_ZVAMO_ADD_W   0x0000612fu
#define IDU_ZVAMO_ADD_D   0x0000712fu

#endif /* IDU_ENCODINGS_H */
