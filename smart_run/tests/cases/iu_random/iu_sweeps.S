/*
 * iu_random -- fully unrolled immediate sweeps for the ALU shifter and the
 * Xtheadc bit-manipulation ops.
 *
 * Why a .S file and not a C switch: the 64-arm masks in the ALU are indexed by
 * *instruction immediate* fields, not by data --
 *
 *   alu_shifter_extu_mask   64 arms on alu_shift_ext_count[5:0]
 *                           (aq_iu_alu.v:399-465), and
 *                           alu_shift_ext_count = src1[11:6] - src1[5:0] (:370)
 *   alu_shift_ext_sign      64 arms on alu_shift_src1[11:6]  (:484-550)
 *   alu_misc_tst_bit        64 arms on alu_misc_src1[5:0]    (:715-781)
 *   alu_shift_count         6-bit shift amount, plus the *W 5-bit mask (:371)
 *
 * -- so the amount cannot be a runtime variable. Lowering a 64-way sweep to a C
 * switch under -fno-jump-tables produces a compare/branch tree that floods the
 * BJU with hundreds of extra branches and contaminates the branch-prediction
 * groups (14-18). A straight-line `.set`/`.rept` sweep costs zero branches.
 *
 * KEY INSIGHT for th.ext/th.extu: with lsb = 0,
 *   alu_shift_ext_count = src1[11:6] - src1[5:0] = msb - 0 = msb   (:370)
 * and the sign probe indexes src1[11:6] = msb directly (:484). So a single
 * 64-instruction sweep of `th.ext rd, rs1, msb, 0` for msb = 0..63 walks BOTH
 * 64-arm cases end to end. iu_sweep_ext_pairs then adds msb < lsb so the 6-bit
 * subtract wraps, which is the only way to reach an ext_count that is not equal
 * to any msb the sign probe saw.
 *
 * Encodings are built from the bases in rand_common/rand_th_insn.h and were
 * re-verified against the decoder casez on {inst[31:25], inst[14:12]}
 * (gen_rtl/idu/rtl/aq_idu_id_decd.v:3187-3325):
 *   th.ext   0x0000200b  funct3 010, msb = inst[31:26], lsb = inst[25:20]
 *   th.extu  0x0000300b  funct3 011, same fields
 *   th.tst   0x8800100b  arm 100010?001, imm6 = inst[25:20]
 *   th.srri  0x1000100b  arm 000100?001, imm6 = inst[25:20]
 *   th.srriw 0x1400100b  arm 0001010001, imm5 = inst[24:20]
 *   th.addsl 0x0000100b  arm 00000??001, imm2 = inst[26:25]
 * For th.ext/tst/srri the immediate arrives as src1 via decd_src1_imm_sel[1],
 * i.e. sign_ext(inst[31:20]) (aq_idu_id_decd.v:470-475, 545), which is exactly
 * why src1[11:6] is the msb field and src1[5:0] the lsb / imm6 field.
 *
 * Register discipline: only a0 (x10), a1 (x11), a2 (x12) and a3 (x13) are
 * touched -- all in rand_safe_regs, all caller-saved, so no frame is needed and
 * x1/x2/x3/x4/x8 are never written.
 *
 * The fold after every swept instruction does double duty: it keeps the result
 * live (nothing is dead code) and it creates a back-to-back ALU -> ALU
 * distance-1 forward, which is itself a coverage target in
 * gen_rtl/idu/rtl/aq_idu_id_dp.v:639-727. The T-Head sweeps fold with
 * `xor a1, a1, a2` (a2 is rs2, i.e. the *src1* comparator bin) and the RISC-V
 * shift sweeps with `xor a1, a2, a1` (a2 is rs1, i.e. the *src0* bin), so both
 * operand positions are covered.
 *
 * Total .text here is about 4.5 KB against a 256 KB image budget.
 */

	.section .text

/* ==================================================================== *
 * th.ext / th.extu -- the 64-arm alu_shifter_extu_mask (aq_iu_alu.v:399-465)
 * and the 64-arm alu_shift_ext_sign (:484-550), both in one pass each.
 * ==================================================================== */

/* u64 iu_sweep_ext(u64 src0, u64 acc) -> folded accumulator */
	.align 2
	.global iu_sweep_ext
iu_sweep_ext:
	.set	_iu_m, 0
	.rept	64
	.word	0x0000200b + (_iu_m << 26) + (10 << 15) + (12 << 7)
	xor	a1, a1, a2
	.set	_iu_m, _iu_m + 1
	.endr
	mv	a0, a1
	ret

/* u64 iu_sweep_extu(u64 src0, u64 acc) -> folded accumulator.
 * Same sweep with alu_shift_op_sign == 0 (FUNC_EXTU, aq_idu_cfig.h:360), so
 * alu_shift_ext_and_sel_mask is forced high and the or-mask arm is never taken
 * (:555-560) -- the complement of what iu_sweep_ext exercises. */
	.align 2
	.global iu_sweep_extu
iu_sweep_extu:
	.set	_iu_m, 0
	.rept	64
	.word	0x0000300b + (_iu_m << 26) + (10 << 15) + (12 << 7)
	xor	a1, a1, a2
	.set	_iu_m, _iu_m + 1
	.endr
	mv	a0, a1
	ret

/* msb < lsb: alu_shift_ext_count = msb - lsb underflows the 6-bit subtract
 * (aq_iu_alu.v:370), so the mask arm selected is (msb - lsb) mod 64 while the
 * sign probe still indexes msb. That decorrelation is unreachable from the
 * lsb == 0 sweeps above. */
	.macro	IU_EXT_PAIR base, msb, lsb
	.word	\base + (\msb << 26) + (\lsb << 20) + (10 << 15) + (12 << 7)
	xor	a1, a1, a2
	.endm

/* u64 iu_sweep_ext_pairs(u64 src0, u64 acc) -> folded accumulator */
	.align 2
	.global iu_sweep_ext_pairs
iu_sweep_ext_pairs:
	IU_EXT_PAIR 0x0000200b,  0,  1
	IU_EXT_PAIR 0x0000200b,  0, 32
	IU_EXT_PAIR 0x0000200b,  0, 63
	IU_EXT_PAIR 0x0000200b,  1,  2
	IU_EXT_PAIR 0x0000200b,  1, 63
	IU_EXT_PAIR 0x0000200b,  5, 10
	IU_EXT_PAIR 0x0000200b,  7,  8
	IU_EXT_PAIR 0x0000200b, 10, 40
	IU_EXT_PAIR 0x0000200b, 15, 16
	IU_EXT_PAIR 0x0000200b, 20, 21
	IU_EXT_PAIR 0x0000200b, 31, 63
	IU_EXT_PAIR 0x0000200b, 32, 33
	IU_EXT_PAIR 0x0000200b, 40, 41
	IU_EXT_PAIR 0x0000200b, 50, 63
	IU_EXT_PAIR 0x0000200b, 60, 61
	IU_EXT_PAIR 0x0000200b, 62, 63
	IU_EXT_PAIR 0x0000300b,  0,  1
	IU_EXT_PAIR 0x0000300b,  0, 32
	IU_EXT_PAIR 0x0000300b,  0, 63
	IU_EXT_PAIR 0x0000300b,  1,  2
	IU_EXT_PAIR 0x0000300b,  1, 63
	IU_EXT_PAIR 0x0000300b,  5, 10
	IU_EXT_PAIR 0x0000300b,  7,  8
	IU_EXT_PAIR 0x0000300b, 10, 40
	IU_EXT_PAIR 0x0000300b, 15, 16
	IU_EXT_PAIR 0x0000300b, 20, 21
	IU_EXT_PAIR 0x0000300b, 31, 63
	IU_EXT_PAIR 0x0000300b, 32, 33
	IU_EXT_PAIR 0x0000300b, 40, 41
	IU_EXT_PAIR 0x0000300b, 50, 63
	IU_EXT_PAIR 0x0000300b, 60, 61
	IU_EXT_PAIR 0x0000300b, 62, 63
	mv	a0, a1
	ret

/* ==================================================================== *
 * th.tst -- the 64-arm alu_misc_tst_bit (aq_iu_alu.v:715-781). imm6 is an
 * instruction field, so this is the only way to reach all 64 arms.
 * ==================================================================== */
/* u64 iu_sweep_tst(u64 src0, u64 acc) -> folded accumulator */
	.align 2
	.global iu_sweep_tst
iu_sweep_tst:
	.set	_iu_i, 0
	.rept	64
	.word	0x8800100b + (_iu_i << 20) + (10 << 15) + (12 << 7)
	xor	a1, a1, a2
	.set	_iu_i, _iu_i + 1
	.endr
	mv	a0, a1
	ret

/* ==================================================================== *
 * th.srri / th.srriw -- the ONLY producers of alu_shift_input_127_64 arm
 * 3'b010 (aq_iu_alu.v:333) and, for srriw, of alu_shift_input_63_0 arm
 * 5'b00100 (:361). FUNC_SRRI sets alu_shift_op_circle = func[8]
 * (aq_idu_cfig.h:357), which no other ALU function does.
 * ==================================================================== */
/* u64 iu_sweep_srri(u64 src0, u64 acc) -> folded accumulator */
	.align 2
	.global iu_sweep_srri
iu_sweep_srri:
	.set	_iu_i, 0
	.rept	64
	.word	0x1000100b + (_iu_i << 20) + (10 << 15) + (12 << 7)
	xor	a1, a1, a2
	.set	_iu_i, _iu_i + 1
	.endr
	mv	a0, a1
	ret

/* u64 iu_sweep_srriw(u64 src0, u64 acc) -> folded accumulator.
 * imm5 only: alu_shift_count masks to src1[4:0] for word ops (:371). */
	.align 2
	.global iu_sweep_srriw
iu_sweep_srriw:
	.set	_iu_i, 0
	.rept	32
	.word	0x1400100b + (_iu_i << 20) + (10 << 15) + (12 << 7)
	xor	a1, a1, a2
	.set	_iu_i, _iu_i + 1
	.endr
	mv	a0, a1
	ret

/* ==================================================================== *
 * RISC-V immediate shifts. slli/srli reach alu_shift_input_127_64 arm 3'b001
 * and input_63_0 arms 5'b10000 / 5'b00001; srai reaches arm 3'b100; the *W
 * forms reach input_63_0 arms 5'b00010 (srliw) and 5'b01000 (sraiw), and
 * exercise the 5-bit mask on alu_shift_count (aq_iu_alu.v:371).
 * Fold is `xor a1, a2, a1` here so a2 lands in the *src0* comparator bin.
 * ==================================================================== */
/* u64 iu_sweep_slli(u64 src0, u64 acc) -> folded accumulator */
	.align 2
	.global iu_sweep_slli
iu_sweep_slli:
	.set	_iu_i, 0
	.rept	64
	slli	a2, a0, _iu_i
	xor	a1, a2, a1
	.set	_iu_i, _iu_i + 1
	.endr
	mv	a0, a1
	ret

/* u64 iu_sweep_srli(u64 src0, u64 acc) -> folded accumulator */
	.align 2
	.global iu_sweep_srli
iu_sweep_srli:
	.set	_iu_i, 0
	.rept	64
	srli	a2, a0, _iu_i
	xor	a1, a2, a1
	.set	_iu_i, _iu_i + 1
	.endr
	mv	a0, a1
	ret

/* u64 iu_sweep_srai(u64 src0, u64 acc) -> folded accumulator */
	.align 2
	.global iu_sweep_srai
iu_sweep_srai:
	.set	_iu_i, 0
	.rept	64
	srai	a2, a0, _iu_i
	xor	a1, a2, a1
	.set	_iu_i, _iu_i + 1
	.endr
	mv	a0, a1
	ret

/* u64 iu_sweep_slliw(u64 src0, u64 acc) -> folded accumulator */
	.align 2
	.global iu_sweep_slliw
iu_sweep_slliw:
	.set	_iu_i, 0
	.rept	32
	slliw	a2, a0, _iu_i
	xor	a1, a2, a1
	.set	_iu_i, _iu_i + 1
	.endr
	mv	a0, a1
	ret

/* u64 iu_sweep_srliw(u64 src0, u64 acc) -> folded accumulator */
	.align 2
	.global iu_sweep_srliw
iu_sweep_srliw:
	.set	_iu_i, 0
	.rept	32
	srliw	a2, a0, _iu_i
	xor	a1, a2, a1
	.set	_iu_i, _iu_i + 1
	.endr
	mv	a0, a1
	ret

/* u64 iu_sweep_sraiw(u64 src0, u64 acc) -> folded accumulator */
	.align 2
	.global iu_sweep_sraiw
iu_sweep_sraiw:
	.set	_iu_i, 0
	.rept	32
	sraiw	a2, a0, _iu_i
	xor	a1, a2, a1
	.set	_iu_i, _iu_i + 1
	.endr
	mv	a0, a1
	ret

/* ==================================================================== *
 * th.addsl -- all four values of alu_adder_src2[6:5] (aq_iu_alu.v:218). imm2
 * is inst[26:25], an instruction field, hence four unrolled words. The
 * accumulator lives in a3 so that a1 stays constant as the shifted operand.
 * ==================================================================== */
/* u64 iu_sweep_addsl(u64 src0, u64 src1) -> folded accumulator */
	.align 2
	.global iu_sweep_addsl
iu_sweep_addsl:
	mv	a3, a1
	.set	_iu_i, 0
	.rept	4
	.word	0x0000100b + (_iu_i << 25) + (11 << 20) + (10 << 15) + (12 << 7)
	xor	a3, a3, a2
	.set	_iu_i, _iu_i + 1
	.endr
	mv	a0, a3
	ret

/* ==================================================================== *
 * src2 forwarding into the Xtheadc accumulate ops.
 *
 * th.mula/muls/mulaw/mulsw/mulah/mulsh and th.mveqz/mvnez take src2 from
 * inst[11:7], i.e. from rd itself (decd_src2_reg, aq_idu_id_decd.v:699-718),
 * so they are three of the only consumers of the src2 forward comparator
 * (aq_idu_id_dp.v:701-709) and of the src2 arm of the mul src2 mux
 * (aq_iu_mul.v:251-256). Building those encodings needs fixed register fields,
 * which is why the sequences live here rather than in C inline asm: the
 * producer immediately before each op writes a2, which is the op's rd == src2,
 * giving a distance-1 forward on src2 every time.
 *
 *   rd = a2 (x12) = src2, rs1 = a0 (x10) = src0, rs2 = a1 (x11) = src1
 * ==================================================================== */
	.macro	IU_ACC base
	add	a2, a0, a1			/* ALU producer -> a2 == rd == src2 */
	.word	\base + (11 << 20) + (10 << 15) + (12 << 7)
	xor	a3, a3, a2
	.endm

/* u64 iu_sweep_mul_acc(u64 src0, u64 src1) -> folded accumulator.
 * All six th.mul* forms. th.mula/muls take the src2 high_32 arm
 * (mul_src2_high_32, aq_iu_mul.v:242 -> arm 3'b100 at :254); th.mulaw/mulsw and
 * th.mulah/mulsh take the low_32 arm (:241 -> arm 3'b010 at :253); and
 * th.mulah/mulsh are the ONLY ops that set mul_ex1_inst16, i.e. the only route
 * to the 16-bit nosplit source arm 3'b001 (:287, :303). */
	.align 2
	.global iu_sweep_mul_acc
iu_sweep_mul_acc:
	li	a3, 0
	IU_ACC	0x2000100b			/* th.mula  a2, a0, a1 */
	IU_ACC	0x2200100b			/* th.muls  a2, a0, a1 */
	IU_ACC	0x2400100b			/* th.mulaw a2, a0, a1 */
	IU_ACC	0x2600100b			/* th.mulsw a2, a0, a1 */
	IU_ACC	0x2800100b			/* th.mulah a2, a0, a1 */
	IU_ACC	0x2A00100b			/* th.mulsh a2, a0, a1 */
	mv	a0, a3
	ret

/* u64 iu_sweep_mov(u64 src0, u64 src1) -> folded accumulator.
 * Both arms of alu_misc_sel_src2 (aq_iu_alu.v:800-801) for both th.mveqz and
 * th.mvnez: src1 (the condition operand) is taken non-zero from a1 and then
 * forced to zero, so each op sees both polarities of alu_misc_src_not_zero. */
	.align 2
	.global iu_sweep_mov
iu_sweep_mov:
	li	a3, 0
	IU_ACC	0x4000100b			/* th.mveqz a2, a0, a1  (a1 != 0 likely) */
	IU_ACC	0x4200100b			/* th.mvnez a2, a0, a1 */
	li	a1, 0				/* condition operand == 0 */
	IU_ACC	0x4000100b			/* th.mveqz a2, a0, x0-valued a1 */
	IU_ACC	0x4200100b			/* th.mvnez a2, a0, x0-valued a1 */
	mv	a0, a3
	ret
