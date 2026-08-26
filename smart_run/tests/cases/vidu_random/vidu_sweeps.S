/*
 * vidu_random -- the exhaustive sweeps.
 *
 * Everything a C macro cannot express lives here: an assembler `.irp` can vary
 * a register number, a rounding-mode mnemonic or a load width across a
 * straight-line block, and none of these sweeps needs a random value to be
 * worth running. The randomness they do consume is the *base address* the
 * caller passes in a0, which moves every load and store to a different offset
 * inside the case-local arena on every hit.
 *
 * What each sweep is aimed at:
 *
 *   vidu_zero_all_fp        the 32 unreset flops in aq_vidu_vid_gpr_reg_fp.v:86-88
 *   vidu_sweep_wbt_all_regs all 32 scoreboard entries (aq_vidu_vid_wbt.v:202+),
 *                           all 3 x 32 read-port mux arms of the FP regfile
 *                           (aq_vidu_vid_gpr_fp.v:544-610, :620-686, :696-762)
 *                           and all 32 write decodes
 *   vidu_sweep_rm_static    every legal static rm plus dynamic, on 17 ops
 *   vidu_sweep_flsu_std     fld/fsd/flw/fsw/flh/fsh x all 32 registers
 *   vidu_sweep_flsu_c       c.fld/c.fsd/c.fldsp/c.fsdsp
 *   vidu_sweep_regfile_walk a distinct pattern in every register, read back two
 *                           ways
 *   vidu_sweep_fld_burst    16 LSU-typed scoreboard entries at once
 *   vidu_sweep_h_all_rm     Zfh at every rounding mode
 *
 * ABI: f8, f9 and f18..f27 are callee-saved in lp64d and every sweep below
 * writes all 32 FP registers, so each one brackets its body with VIDU_FSAVE /
 * VIDU_FRESTORE. (The C side gets the same guarantee for free by naming all 32
 * registers in its clobber lists, which makes GCC emit exactly this pair in the
 * group function's prologue and epilogue.) vidu_zero_all_fp is the one
 * exception, and deliberately so: it runs before anything has written an FP
 * register, so a save would spill X and the restore would hand it back.
 */

#include "vidu_defs.h"

/* The 32 FP register numbers as an `.irp` argument list. cpp runs over .S files
 * before GAS does, so this expands into the list literally. */
#define FP_ALL 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,\
               24,25,26,27,28,29,30,31

/* The eight low FP registers, i.e. the ones the compressed CL/CS encodings can
 * name (rd'/rs2' is 3 bits, so f8..f15 -> 0..7). */
#define FP_LOW8 0,1,2,3,4,5,6,7

	.text

	.macro	VIDU_FSAVE
	addi	sp, sp, -96
	fsd	f8,   0(sp)
	fsd	f9,   8(sp)
	fsd	f18, 16(sp)
	fsd	f19, 24(sp)
	fsd	f20, 32(sp)
	fsd	f21, 40(sp)
	fsd	f22, 48(sp)
	fsd	f23, 56(sp)
	fsd	f24, 64(sp)
	fsd	f25, 72(sp)
	fsd	f26, 80(sp)
	fsd	f27, 88(sp)
	.endm

	.macro	VIDU_FRESTORE
	fld	f8,   0(sp)
	fld	f9,   8(sp)
	fld	f18, 16(sp)
	fld	f19, 24(sp)
	fld	f20, 32(sp)
	fld	f21, 40(sp)
	fld	f22, 48(sp)
	fld	f23, 56(sp)
	fld	f24, 64(sp)
	fld	f25, 72(sp)
	fld	f26, 80(sp)
	fld	f27, 88(sp)
	addi	sp, sp, 96
	.endm

/* ------------------------------------------------------------------ *
 * void vidu_zero_all_fp(void)
 *
 * THE FIRST THING main() DOES, before anything else can touch an FP register.
 *
 * All 32 FP registers are X at entry: crt0.s writes none of them, and
 * aq_vidu_vid_gpr_reg_fp.v:86-88 is
 *
 *     always @(posedge reg_clk)
 *         reg_dout[63:0] <= write_data[63:0];
 *
 * with no reset arm at all. Under Verilator's 2-state model that is invisible;
 * under VCS it is the difference between a run that stimulates VIDU and a run
 * whose forwarding muxes, comparators and scoreboard reads are all X-poisoned
 * from the first fadd.
 *
 * fmv.d.x from x0 is the cheapest producer that has an FP destination and no FP
 * source, so nothing here reads an X it has not itself just written.
 * ------------------------------------------------------------------ */
	.align 2
	.globl vidu_zero_all_fp
vidu_zero_all_fp:
	.irp fr, FP_ALL
	fmv.d.x	f\fr, x0
	.endr
	ret

/* ------------------------------------------------------------------ *
 * u64 vidu_sweep_wbt_all_regs(volatile u64 *base)
 *
 * The single biggest measurable delta over C906_FPU_SMOKE.s, which uses only 17
 * of the 32 FP registers (f13, f16-f19 and f22-f31 never appear in its 3886
 * lines). Every register in turn plays all four roles:
 *
 *   dst   -> the entry's create_en decode (aq_vidu_vid_wbt.v create_en[31:0])
 *            and the regfile write decode, once VLSU-typed via fld and once
 *            falu-typed via fadd.d, which is both arms of
 *            dp_wbt_fp_dstv_type (aq_vidu_vid_dp_fp.v:295-296)
 *   src0  -> arm N of the gpr_fp_dp_src0_data mux (:544-610)
 *   src1  -> arm N of the gpr_fp_dp_src1_data mux (:620-686)
 *   src2  -> arm N of the gpr_fp_dp_src2_data mux (:696-762), reachable only
 *            from an FMA's rs3 or an FP store's data register, so both are used
 *
 * Returns an xor fold of every register's final contents, purely so that the
 * caller can add it to rand_sink and the compiler cannot decide the sweep is
 * dead. Nothing compares it against anything.
 * ------------------------------------------------------------------ */
	.align 2
	.globl vidu_sweep_wbt_all_regs
vidu_sweep_wbt_all_regs:
	VIDU_FSAVE
	li	t1, 0
	.irp fr, FP_ALL
	fld	f\fr, (\fr*8)(a0)		/* dst, WB_VEC_TYPE_VLSU     */
	fadd.d	ft0, f\fr, ft1			/* src0                      */
	fadd.d	ft2, ft1, f\fr			/* src1                      */
	fmadd.d	ft3, ft1, ft2, f\fr		/* src2 via rs3              */
	fadd.d	f\fr, ft0, ft2			/* dst, falu-typed           */
	fsd	f\fr, (256 + \fr*8)(a0)		/* src2 via store data       */
	fmv.x.d	t0, f\fr
	xor	t1, t1, t0
	.endr
	mv	a0, t1
	VIDU_FRESTORE
	ret

/* ------------------------------------------------------------------ *
 * void vidu_sweep_rm_static(volatile u64 *base)
 *
 * The rounding mode is an instruction field, so the only way to sweep it is to
 * unroll. C906_FPU_SMOKE.s does cover the five legal static modes, but only on
 * the ops it happens to use and never on the .h converts; this crosses all six
 * encodings (rne rtz rdn rup rmm dyn) with all four execution units -- vfalu,
 * vfmau, vfdsu and vfcvt -- so every rm value reaches every writeback source.
 * ------------------------------------------------------------------ */
	.align 2
	.globl vidu_sweep_rm_static
vidu_sweep_rm_static:
	VIDU_FSAVE
	fld	ft0,  0(a0)
	fld	ft1,  8(a0)
	fld	ft2, 16(a0)
	.irp rm, rne, rtz, rdn, rup, rmm, dyn
	fadd.d	 ft3,  ft0, ft1, \rm
	fsub.s	 ft4,  ft0, ft1, \rm
	fmul.h	 ft5,  ft0, ft1, \rm
	fdiv.d	 ft6,  ft0, ft1, \rm		/* vfdsu, long latency       */
	fsqrt.s	 ft7,  ft0, \rm
	fmadd.d	 f8,   ft0, ft1, ft2, \rm	/* vfmau, viq0_ex5 writeback */
	fmsub.s	 f9,   ft0, ft1, ft2, \rm
	fnmadd.h f18,  ft0, ft1, ft2, \rm
	fnmsub.d f19,  ft0, ft1, ft2, \rm
	fcvt.w.d  a1,  ft0, \rm			/* vfcvt, integer dest       */
	fcvt.wu.s a2,  ft0, \rm
	fcvt.l.h  a3,  ft0, \rm
	fcvt.lu.d a4,  ft0, \rm
	fcvt.s.d ft8,  ft0, \rm			/* narrowing FP->FP          */
	fcvt.h.d ft9,  ft0, \rm
	fcvt.s.l ft10, a1, \rm			/* integer source            */
	fcvt.d.lu ft11, a2, \rm
	.endr
	VIDU_FRESTORE
	ret

/* ------------------------------------------------------------------ *
 * u64 vidu_sweep_flsu_std(volatile u64 *base)
 *
 * C906_FPU_SMOKE.s contains 4 fld, 2 fsd, 1 flh, 1 fsh and *zero* flw/fsw. All
 * six widths here, over all 32 registers.
 *
 * These take a different completion path from FP arithmetic: vpu_rtu_ex1_cmplt
 * is explicitly suppressed for the FLSU (aq_vidu_vid_ctrl_fp.v:174-178, the
 * `&& !idu_vidu_ex1_inst_data[... EU_FLSU_SEL]` term), and they are the only
 * source of WB_VEC_TYPE_VLSU scoreboard entries -- which is what makes the
 * type-and-count qualifiers of the RAW and WAW exceptions reachable at all.
 * ------------------------------------------------------------------ */
	.align 2
	.globl vidu_sweep_flsu_std
vidu_sweep_flsu_std:
	VIDU_FSAVE
	li	t1, 0
	.irp fr, FP_ALL
	fld	f\fr, (\fr*8)(a0)
	fsd	f\fr, (256 + \fr*8)(a0)
	flw	f\fr, (\fr*4)(a0)
	fsw	f\fr, (512 + \fr*4)(a0)
	flh	f\fr, (\fr*2)(a0)
	fsh	f\fr, (640 + \fr*2)(a0)
	fmv.x.d	t0, f\fr
	xor	t1, t1, t0
	.endr
	mv	a0, t1
	VIDU_FRESTORE
	ret

/* ------------------------------------------------------------------ *
 * void vidu_sweep_flsu_c(volatile u64 *base)
 *
 * The compressed FP loads and stores, of which C906_FPU_SMOKE.s has none. Raw
 * .2byte rather than mnemonics so the encoding is pinned regardless of what the
 * assembler would have chosen; every word below was checked against the
 * assembler's own output for the equivalent mnemonic.
 *
 * c.fld / c.fsd take rs1' from x8..x15, so a0 (x10) is rs1' = 2, and rd'/rs2'
 * from f8..f15. c.fldsp / c.fsdsp are sp-relative with a full 5-bit FP
 * register, which is why this sweep allocates a private 256-byte frame first:
 * a c.fsdsp aimed anywhere else on the stack would be writing over our own
 * saved registers and return address. The stores run before the loads so that
 * the loads read something this function wrote.
 * ------------------------------------------------------------------ */
	.align 2
	.globl vidu_sweep_flsu_c
vidu_sweep_flsu_c:
	VIDU_FSAVE
	addi	sp, sp, -256			/* private frame for c.f*sp  */
	.irp fr, FP_LOW8
	.2byte	VIDU_C_FSD(\fr, 2, (\fr*8))
	.2byte	VIDU_C_FLD(\fr, 2, (128 + \fr*8))
	.endr
	.irp fr, FP_ALL
	.2byte	VIDU_C_FSDSP(\fr, (\fr*8))
	.endr
	.irp fr, FP_ALL
	.2byte	VIDU_C_FLDSP(\fr, (\fr*8))
	.endr
	addi	sp, sp, 256
	VIDU_FRESTORE
	ret

/* ------------------------------------------------------------------ *
 * u64 vidu_sweep_regfile_walk(volatile u64 *base)
 *
 * Load a distinct pattern into every register from the arena (which the caller
 * has just filled from the operand pool), then read all 32 back twice: once
 * through fsd, which reads the srcf2 port, and once through fmv.x.d, which
 * reads srcf0 and lands in the integer scoreboard.
 * ------------------------------------------------------------------ */
	.align 2
	.globl vidu_sweep_regfile_walk
vidu_sweep_regfile_walk:
	VIDU_FSAVE
	li	t1, 0
	.irp fr, FP_ALL
	ld	t0, (\fr*8)(a0)
	fmv.d.x	f\fr, t0
	.endr
	.irp fr, FP_ALL
	fsd	f\fr, (256 + \fr*8)(a0)
	fmv.x.d	t0, f\fr
	xor	t1, t1, t0
	.endr
	mv	a0, t1
	VIDU_FRESTORE
	ret

/* ------------------------------------------------------------------ *
 * u64 vidu_sweep_fld_burst(volatile u64 *base)
 *
 * Sixteen back-to-back FP loads to sixteen distinct registers, then their
 * consumers. This is the scoreboard at maximum useful occupancy: sixteen
 * VLSU-typed entries outstanding at once, which is also the widest window in
 * which wbt_top_fp_gpr_no_wb (aq_vidu_top.v:413) is deasserted.
 *
 * Two bursts of eight rather than one of sixteen so that the second burst's
 * loads issue while the first burst's consumers are still stalling dispatch.
 * ------------------------------------------------------------------ */
	.align 2
	.globl vidu_sweep_fld_burst
vidu_sweep_fld_burst:
	VIDU_FSAVE
	.irp fr, 16,17,18,19,20,21,22,23
	fld	f\fr, (\fr*8)(a0)
	.endr
	fadd.d	ft0, f16, f17
	fadd.d	ft1, f18, f19
	fadd.d	ft2, f20, f21
	fadd.d	ft3, f22, f23
	.irp fr, 24,25,26,27,28,29,30,31
	fld	f\fr, (\fr*8)(a0)
	.endr
	fadd.d	ft4, f24, f25
	fadd.d	ft5, f26, f27
	fadd.d	ft6, f28, f29
	fadd.d	ft7, f30, f31
	fadd.d	ft0, ft0, ft1
	fadd.d	ft2, ft2, ft3
	fadd.d	ft4, ft4, ft5
	fadd.d	ft6, ft6, ft7
	fadd.d	ft0, ft0, ft2
	fadd.d	ft4, ft4, ft6
	fadd.d	ft0, ft0, ft4
	fmv.x.d	a0, ft0
	VIDU_FRESTORE
	ret

/* ------------------------------------------------------------------ *
 * void vidu_sweep_h_all_rm(volatile u64 *base)
 *
 * Half precision is the thinnest part of C906_FPU_SMOKE.s -- 4 fsqrt.h, no
 * fsgnj.h, no fmax.h at more than one rounding mode -- so every Zfh op that has
 * an rm field gets all six encodings here, and the ones that do not (sign
 * injection, min/max, compares, fclass, fmv) get a block of their own.
 * ------------------------------------------------------------------ */
	.align 2
	.globl vidu_sweep_h_all_rm
vidu_sweep_h_all_rm:
	VIDU_FSAVE
	fld	ft0,  0(a0)
	fld	ft1,  8(a0)
	fld	ft2, 16(a0)
	.irp rm, rne, rtz, rdn, rup, rmm, dyn
	fadd.h	 ft3, ft0, ft1, \rm
	fsub.h	 ft4, ft0, ft1, \rm
	fmul.h	 ft5, ft0, ft1, \rm
	fdiv.h	 ft6, ft0, ft1, \rm
	fsqrt.h	 ft7, ft0, \rm
	fmadd.h	 f8,  ft0, ft1, ft2, \rm
	fmsub.h	 f9,  ft0, ft1, ft2, \rm
	fnmadd.h f18, ft0, ft1, ft2, \rm
	fnmsub.h f19, ft0, ft1, ft2, \rm
	fcvt.h.s ft8, ft0, \rm
	fcvt.h.d ft9, ft0, \rm
	fcvt.w.h  a1, ft0, \rm
	fcvt.wu.h a2, ft0, \rm
	fcvt.l.h  a3, ft0, \rm
	fcvt.lu.h a4, ft0, \rm
	fcvt.h.w ft10, a1, \rm
	fcvt.h.lu ft11, a2, \rm
	.endr
	/* No rm field on any of these. */
	fsgnj.h	 f20, ft0, ft1
	fsgnjn.h f21, ft0, ft1
	fsgnjx.h f22, ft0, ft1
	fmin.h	 f23, ft0, ft1
	fmax.h	 f24, ft0, ft1
	fcvt.s.h f25, ft0
	fcvt.d.h f26, ft0
	feq.h	 a1, ft0, ft1
	flt.h	 a2, ft0, ft1
	fle.h	 a3, ft0, ft1
	fclass.h a4, ft0
	fmv.x.h	 a5, ft0
	fmv.h.x	 f27, a5
	VIDU_FRESTORE
	ret
