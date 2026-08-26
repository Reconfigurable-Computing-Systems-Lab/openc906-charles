/*
 * iu_random -- branch / jump trampolines.
 *
 * Every control-flow form the BJU has a dedicated comparator for needs a *real*
 * target: `jalr x1, 0(x1)` and `la x1, L; jalr x0, 0(x1)` both destroy the
 * return address, so they cannot be written as C inline asm without the risk of
 * landing in the weeds. Here each form is a self-contained leaf function that
 * parks the caller's ra in a7 (x17, caller-saved, in rand_safe_regs), performs
 * the jump to a local label, and restores ra before returning. A wrong landing
 * therefore costs one label, not the run.
 *
 * The BJU signals targeted, with the func-bit provenance from
 * gen_rtl/idu/rtl/aq_idu_cfig.h:402-410 (FUNC_JAL/JALR/C_J/C_JR/C_JALR/AUIPC):
 *
 *   bju_link_vld          aq_iu_bju.v:659-660  dst_preg == 1 && uncond && func[11]
 *   bju_ret_vld           :657-658             src0_reg == 1 && jalr && !src_dst_eq
 *   bju_src_dst_reg_equal :656                 src0_reg == dst_preg && func[11]
 *   bju_pc_cmp_fail       :648                 jalr from x1 whose target != the
 *                                              RAS prediction
 *   bju_pc_reg_mispred    :649                 jalr whose base is not x1
 *   bju_ras_mispred_vld   :669-677             set by pc_cmp_fail
 *   bju_auipc_sel         :470                 func[7]
 *   bju_ex1_use_pc        :589                 func[8]
 *   bju_inc_pc_ext_63_1   :581-582             16- vs 32-bit adder select, keyed
 *                                              on rtu_iu_ex1_inst_len -- so the
 *                                              16-bit arm needs a *compressed*
 *                                              BJU instruction, which is what
 *                                              iu_bju_rvc_jumps and
 *                                              iu_bju_c_branch supply. auipc is
 *                                              always 4 bytes and can only ever
 *                                              take the 32-bit arm; what it does
 *                                              vary is the PC alignment feeding
 *                                              bju_cur_pc_ext (:572).
 *
 * `.option norvc` brackets are deliberate wherever the 32-bit encoding is the
 * coverage target: GAS would otherwise compress `jalr x0, 0(x1)` to `c.jr x1`,
 * and FUNC_C_JR clears func[11] (aq_idu_cfig.h:450) so bju_src_dst_reg_equal
 * and bju_link_vld_raw become unreachable through it.
 *
 * Registers touched: a0 (return value / accumulator), a1, a2, a5, a7, t0, t1
 * and ra -- all caller-saved, none of x2/x3/x4/x8.
 */

	.section .text

/* ------------------------------------------------------------------ *
 * u64 iu_bju_jal_link(u64 acc)
 *   jal x1, L   -> bju_link_vld  == 1  (dst_preg == 1)
 *   jal x0, L   -> bju_link_vld  == 0, same uncond_sel path
 * ------------------------------------------------------------------ */
	.align 2
	.global iu_bju_jal_link
iu_bju_jal_link:
	mv	a7, ra
	.option push
	.option norvc
	jal	ra, 1f				/* link into x1 */
1:	xor	a0, a0, ra
	jal	x0, 2f				/* 32-bit JAL with rd == x0 */
2:	addi	a0, a0, 1
	jal	a5, 3f				/* link into a non-ra register */
3:	xor	a0, a0, a5
	.option pop
	mv	ra, a7
	ret

/* ------------------------------------------------------------------ *
 * u64 iu_bju_ret_forms(u64 acc)
 *   The return path with a *clobbered* link register: the RAS top still holds
 *   our caller's address, so bju_ag_tar_pc != ifu_iu_ex1_pc_pred and
 *   bju_pc_cmp_fail fires (aq_iu_bju.v:648), which in turn sets
 *   bju_ras_mispred_vld (:665, :669-677). bju_ret_vld is asserted at the same
 *   time because src0_reg == 1, dst_preg == 0.
 * ------------------------------------------------------------------ */
	.align 2
	.global iu_bju_ret_forms
iu_bju_ret_forms:
	mv	a7, ra
	la	ra, 1f
	.option push
	.option norvc
	jalr	x0, 0(ra)
	.option pop
1:	addi	a0, a0, 1
	/* And once more, but with the RAS now one entry short, so the second
	 * return in this function mispredicts for a different reason. */
	la	ra, 2f
	.option push
	.option norvc
	jalr	x0, 0(ra)
	.option pop
2:	addi	a0, a0, 1
	mv	ra, a7
	ret

/* ------------------------------------------------------------------ *
 * u64 iu_bju_jalr_same(u64 acc)
 *   jalr x1, 0(x1): src0_reg == dst_preg == 1 with FUNC_JALR's func[11] set,
 *   so bju_src_dst_reg_equal (aq_iu_bju.v:656) is the term that forces
 *   bju_pc_cmp_fail -- the one case where the RAS prediction is declared wrong
 *   without comparing any address, and the one case that suppresses
 *   bju_ret_vld_raw (:657) even though the base register is x1.
 * ------------------------------------------------------------------ */
	.align 2
	.global iu_bju_jalr_same
iu_bju_jalr_same:
	mv	a7, ra
	la	ra, 1f
	.option push
	.option norvc
	jalr	ra, 0(ra)
	.option pop
1:	xor	a0, a0, ra
	mv	ra, a7
	ret

/* ------------------------------------------------------------------ *
 * u64 iu_bju_jalr_reg(u64 acc)
 *   jalr through a base register that is not x1 -> bju_pc_reg_mispred
 *   (aq_iu_bju.v:649). Two flavours: discarding the link (rd == x0) and
 *   linking into t1, which also gives bju_link_vld_raw == 0 with func[11] set.
 * ------------------------------------------------------------------ */
	.align 2
	.global iu_bju_jalr_reg
iu_bju_jalr_reg:
	la	t0, 1f
	.option push
	.option norvc
	jalr	x0, 0(t0)
	.option pop
1:	la	t0, 2f
	.option push
	.option norvc
	jalr	t1, 0(t0)
	.option pop
2:	xor	a0, a0, t1
	ret

/* ------------------------------------------------------------------ *
 * u64 iu_bju_rvc_jumps(u64 acc)
 *   The compressed uncond forms. These are the only jumps with
 *   idu_iu_ex1_inst_len == 0, i.e. the only way into the 16-bit arm of the
 *   inc-pc adder select (aq_iu_bju.v:581-582, and iu_rtu_ex1_alu_inst_len at
 *   aq_iu_alu.v:857 for the ALU side).
 *     c.j    -> FUNC_C_J,    uncond, no link, func[11] == 0
 *     c.jr   -> FUNC_C_JR,   jalr with func[11] == 0 -> pc_reg_mispred only
 *     c.jalr -> FUNC_C_JALR, identical func to FUNC_JALR, writes x1
 * ------------------------------------------------------------------ */
	.align 2
	.global iu_bju_rvc_jumps
iu_bju_rvc_jumps:
	mv	a7, ra
	c.j	1f
1:	la	a5, 2f
	c.jr	a5
2:	la	a5, 3f
	c.jalr	a5
3:	xor	a0, a0, ra
	addi	a0, a0, 1
	mv	ra, a7
	ret

/* ------------------------------------------------------------------ *
 * u64 iu_bju_c_branch(u64 acc, u64 bits)
 *   Compressed conditional branches with data-driven directions: eight
 *   c.beqz / c.bnez pairs whose outcome comes from consecutive bits of `bits`.
 *   Compressed branches are BJU ops with inst_len == 0, so they are the second
 *   route into the 16-bit inc-pc adder (aq_iu_bju.v:581-582), and the
 *   alternating directions keep the 2-bit BHT counter desynchronised, driving
 *   bju_bht_mispred_no_entry (:637) and iu_ifu_bht_mispred (:790).
 *
 *   c.beqz / c.bnez require their source in x8..x15, hence a2.
 * ------------------------------------------------------------------ */
	.align 2
	.global iu_bju_c_branch
iu_bju_c_branch:
	.rept	8
	andi	a2, a1, 1
	srli	a1, a1, 1
	c.beqz	a2, 9f
	addi	a0, a0, 1
9:
	c.bnez	a2, 8f
	addi	a0, a0, 3
8:
	.endr
	ret

/* ------------------------------------------------------------------ *
 * u64 iu_bju_auipc(u64 acc)
 *   bju_auipc_sel (aq_iu_bju.v:470) and bju_ex1_use_pc (:589) with the auipc
 *   at both a 4-byte-aligned and a 2-byte-aligned PC, so bju_cur_pc_ext[1]
 *   (:572) and the low bit of both inc-pc adders (:576-577) see both values.
 *   The `.option norvc` blocks pin the instruction sizes; the bare c.nop
 *   between them is what shifts the alignment.
 * ------------------------------------------------------------------ */
	.align 2
	.global iu_bju_auipc
iu_bju_auipc:
	.option push
	.option norvc
	auipc	a5, 0				/* PC 4-byte aligned */
	xor	a0, a0, a5
	.option pop
	c.nop					/* -> next PC is 2-byte aligned */
	.option push
	.option norvc
	auipc	a5, 1
	xor	a0, a0, a5
	auipc	a5, 0xfffff			/* imm20 with bit 19 set */
	xor	a0, a0, a5
	.option pop
	ret
