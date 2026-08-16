/*
 * Trap handling and privilege-mode plumbing for the cp0_random stress test.
 *
 * Deliberately does NOT use crt0.s's `vector_table`: its entries are .long
 * (4 bytes) while the dispatcher loads them with `ld` (8 bytes), which loops
 * forever on any trap (see CLAUDE.md "Known Bugs"). This file installs its own
 * mtvec/stvec instead.
 *
 * Register discipline: `tp` (x4) permanently holds &cp0_ctx. tp is a fixed
 * register in the RISC-V ABI -- GCC never allocates it -- and this is a
 * single-threaded bare-metal build with no TLS, so it is free. That gives the
 * handler a scratch base without having to steal mscratch/sscratch, both of
 * which the test writes randomly.
 *
 * Every handler is written so that a trap it did not expect cannot wedge the
 * run: nested traps unwind to the dispatch loop head via cp0_longjmp.
 */

#include "cp0_csrs.h"

	.section .bss
	.align 6
	.global cp0_ctx
cp0_ctx:
	.space CTX_SIZE

	.section .text

/* ------------------------------------------------------------------ *
 * void cp0_trap_init(void)
 *   Point tp at cp0_ctx, install mtvec (direct) and stvec, zero the
 *   context. Must run before anything else can trap.
 * ------------------------------------------------------------------ */
	.align 2
	.global cp0_trap_init
cp0_trap_init:
	la	tp, cp0_ctx
	li	t0, 0
	li	t1, CTX_SIZE
1:	add	t2, tp, t0
	sd	zero, 0(t2)
	addi	t0, t0, 8
	blt	t0, t1, 1b

	la	t0, cp0_trap_m
	csrw	CSR_MTVEC, t0		/* mode 0: direct */
	la	t0, cp0_trap_s
	csrw	CSR_STVEC, t0
	ret

/* ------------------------------------------------------------------ *
 * M-mode trap handler, direct mode.
 * ------------------------------------------------------------------ */
	.align 2
	.global cp0_trap_m
cp0_trap_m:
	sd	t0, CTX_S_T0(tp)
	sd	t1, CTX_S_T1(tp)
	sd	t2, CTX_S_T2(tp)
	sd	a0, CTX_S_A0(tp)

	/* trap bookkeeping: total, per-cause count */
	ld	t0, CTX_TOTAL(tp)
	addi	t0, t0, 1
	sd	t0, CTX_TOTAL(tp)

	csrr	t0, CSR_MCAUSE
	srli	t1, t0, 63		/* t1 = interrupt flag */
	andi	t2, t0, 0x1f		/* t2 = cause          */
	slli	t0, t1, 5
	add	t0, t0, t2		/* index = {intr, cause[4:0]} */
	slli	t0, t0, 3
	add	t0, t0, tp
	ld	a0, CTX_COUNT(t0)
	addi	a0, a0, 1
	sd	a0, CTX_COUNT(t0)

	/* nested trap? -> abandon this iteration */
	ld	t0, CTX_DEPTH(tp)
	addi	t0, t0, 1
	sd	t0, CTX_DEPTH(tp)
	li	a0, 1
	bgt	t0, a0, cp0_trap_bail

	bnez	t1, cp0_trap_m_int

/* ---- synchronous exception ---- */
#ifdef CP0_FORCE_BAIL
	/* Validation builds only (CP0_EXTRA=-DCP0_FORCE_BAIL): treat ebreak as
	 * an unrecoverable trap so the cp0_setjmp/cp0_longjmp recovery path
	 * actually runs. In a normal run `recovered` stays 0, which means that
	 * path is never exercised -- this is how it gets tested. */
	li	a0, 3
	beq	t2, a0, cp0_trap_bail
#endif
	/* ecall from S (9) or U (8): hand control back to M-mode caller */
	li	a0, 8
	beq	t2, a0, cp0_trap_m_toM
	li	a0, 9
	beq	t2, a0, cp0_trap_m_toM

	/* everything else: step over the faulting instruction and resume.
	 * Length from the low 2 bits of the halfword at mepc (11 => 4 bytes).
	 * If mepc itself is unfetchable this load faults, which lands in the
	 * nested-trap path above -- by design. */
	csrr	t0, CSR_MEPC
	lhu	t1, 0(t0)
	andi	t1, t1, 3
	li	a0, 3
	beq	t1, a0, 1f
	addi	t0, t0, 2
	j	2f
1:	addi	t0, t0, 4
2:	csrw	CSR_MEPC, t0
	j	cp0_trap_m_exit

cp0_trap_m_toM:
	/* resume in M mode at the label the mode-entry helper recorded */
	ld	t0, CTX_MODE_RET(tp)
	csrw	CSR_MEPC, t0
	li	t0, MSTATUS_MPP		/* MPP = 3 (M) */
	csrs	CSR_MSTATUS, t0
	j	cp0_trap_m_exit

/* ---- interrupt: silence the source, then return ---- */
cp0_trap_m_int:
	li	a0, 1			/* 1 = S software  */
	beq	t2, a0, cp0_int_clr_sip
	li	a0, 5			/* 5 = S timer     */
	beq	t2, a0, cp0_int_clr_sip
	li	a0, 9			/* 9 = S external  */
	beq	t2, a0, cp0_int_clr_sip
	li	a0, 3			/* 3 = M software  */
	beq	t2, a0, cp0_int_clr_msip
	li	a0, 7			/* 7 = M timer     */
	beq	t2, a0, cp0_int_clr_mtip
	li	a0, 11			/* 11 = M external */
	beq	t2, a0, cp0_int_clr_meip
	li	a0, 17			/* 17 = HPM overflow */
	beq	t2, a0, cp0_int_clr_moip
	/* unknown interrupt: mask it globally rather than spin */
	csrw	CSR_MIE, zero
	j	cp0_trap_m_exit

cp0_int_clr_sip:
	/* Two possible sources for each of these: the software-written
	 * ssip_reg/stip_reg/seip_reg, which mip owns, and the CLINT's S-mode
	 * outputs, which mip does NOT own (stip = biu_cp0_st_int && clintee ||
	 * stip_reg, aq_cp0_trap_csr.v:1239-1240). Silence both, unconditionally
	 * and idempotently, or a CLINT-sourced S interrupt re-traps forever. */
	li	t0, 1
	sll	t0, t0, t2
	csrc	CSR_MIP, t0
	li	t0, CLINT_SSIP0
	sw	zero, 0(t0)
	li	t0, CLINT_STIMECMPH
	li	t1, -1
	sw	t1, 0(t0)
	j	cp0_trap_m_exit

cp0_int_clr_msip:
	li	t0, CLINT_MSIP0
	sw	zero, 0(t0)
	j	cp0_trap_m_exit

cp0_int_clr_mtip:
	/* mtip is a combinational mtimecmp <= mtime compare: push cmp up */
	li	t0, CLINT_MTIMECMPH
	li	t1, -1
	sw	t1, 0(t0)
	j	cp0_trap_m_exit

cp0_int_clr_meip:
	li	t0, PLIC_MCLAIM_H0
	lw	t1, 0(t0)		/* claim: clears pending, sets active */
	sw	t1, 0(t0)		/* complete: clears active           */
	j	cp0_trap_m_exit

cp0_int_clr_moip:
	li	t0, 0
	csrw	CSR_MCNTINTEN, t0
	csrw	CSR_MCNTOF, t0
	j	cp0_trap_m_exit

cp0_trap_m_exit:
	ld	t0, CTX_DEPTH(tp)
	addi	t0, t0, -1
	sd	t0, CTX_DEPTH(tp)
	ld	t0, CTX_S_T0(tp)
	ld	t1, CTX_S_T1(tp)
	ld	t2, CTX_S_T2(tp)
	ld	a0, CTX_S_A0(tp)
	mret

/* A trap we could not make sense of, or a trap inside a trap. Drop the
 * depth, force M mode with interrupts off, and longjmp to the loop head. */
cp0_trap_bail:
	sd	zero, CTX_DEPTH(tp)
	ld	t0, CTX_NESTED(tp)
	addi	t0, t0, 1
	sd	t0, CTX_NESTED(tp)
	la	t0, cp0_bail_land
	csrw	CSR_MEPC, t0
	li	t0, MSTATUS_MPP
	csrs	CSR_MSTATUS, t0		/* MPP = M */
	li	t0, MSTATUS_MIE
	csrc	CSR_MSTATUS, t0		/* return with interrupts off */
	csrw	CSR_MIE, zero
	mret
cp0_bail_land:
	j	cp0_longjmp

/* ------------------------------------------------------------------ *
 * M-mode trap handler, vectored mode. mtvec.mode=1 sends interrupt
 * cause N to base + 4*N, so this is a table of jumps; exceptions still
 * arrive at offset 0.
 * ------------------------------------------------------------------ */
	.align 6
	.global cp0_trap_m_vectored
cp0_trap_m_vectored:
	j	cp0_trap_m		/* 0: exceptions */
	.rept 19
	j	cp0_trap_m
	.endr

/* ------------------------------------------------------------------ *
 * S-mode trap handler, for delegated traps. Only touches S CSRs.
 * ------------------------------------------------------------------ */
	.align 2
	.global cp0_trap_s
cp0_trap_s:
	sd	t0, CTX_S_ST0(tp)
	sd	t1, CTX_S_ST1(tp)
	sd	t2, CTX_S_ST2(tp)

	ld	t0, CTX_STOTAL(tp)
	addi	t0, t0, 1
	sd	t0, CTX_STOTAL(tp)

	csrr	t0, CSR_SCAUSE
	srli	t1, t0, 63
	andi	t2, t0, 0x1f
	slli	t0, t1, 5
	add	t0, t0, t2
	slli	t0, t0, 3
	add	t0, t0, tp
	ld	t1, CTX_SCOUNT(t0)
	addi	t1, t1, 1
	sd	t1, CTX_SCOUNT(t0)

	csrr	t0, CSR_SCAUSE
	srli	t1, t0, 63
	bnez	t1, cp0_trap_s_int

	/* delegated exception: step over it */
	csrr	t0, CSR_SEPC
	lhu	t1, 0(t0)
	andi	t1, t1, 3
	li	t2, 3
	beq	t1, t2, 1f
	addi	t0, t0, 2
	j	2f
1:	addi	t0, t0, 4
2:	csrw	CSR_SEPC, t0
	j	cp0_trap_s_exit

cp0_trap_s_int:
	/* A delegated interrupt has to be silenced from S mode, but a write to
	 * the SIP address only ever updates ssip -- stip_reg and seip_reg are
	 * explicitly held (aq_cp0_trap_csr.v:1216-1221). So try sip first, then
	 * always mask the source in sie, which IS writable from S mode for any
	 * delegated bit. Without the sie fallback a delegated STIP re-traps
	 * forever: a livelock that retires instructions, so the testbench's
	 * retire watchdog never even fires. */
	andi	t2, t0, 0x1f
	li	t0, 1
	sll	t0, t0, t2
	csrc	CSR_SIP, t0
	csrc	CSR_SIE, t0

cp0_trap_s_exit:
	ld	t0, CTX_S_ST0(tp)
	ld	t1, CTX_S_ST1(tp)
	ld	t2, CTX_S_ST2(tp)
	sret

/* ------------------------------------------------------------------ *
 * void cp0_run_in_smode(void (*fn)(void))
 * void cp0_run_in_umode(void (*fn)(void))
 *   Drop to S / U, run fn, come back. fn signals completion with ECALL,
 *   which the M handler turns into a return to `mode_ret`.
 *   Callers keep medeleg[8]/[9] clear so that ecall is never delegated.
 *
 * ra and sp are parked in cp0_ctx rather than on the stack: the body is a C
 * function entered by mret, so its prologue may move sp and its epilogue never
 * runs (the ecall is intercepted first). Restoring both from the context makes
 * the round trip immune to whatever the body did to the stack.
 * ------------------------------------------------------------------ */
	.align 2
	.global cp0_run_in_smode
cp0_run_in_smode:
	sd	ra, CTX_MODE_RA(tp)
	sd	sp, CTX_MODE_SP(tp)
	la	t0, cp0_mode_ret
	sd	t0, CTX_MODE_RET(tp)
	li	t0, MSTATUS_MPP
	csrc	CSR_MSTATUS, t0		/* clear MPP */
	li	t0, MSTATUS_MPP_S
	csrs	CSR_MSTATUS, t0		/* MPP = 1 (S) */
	csrw	CSR_MEPC, a0
	mret

	.align 2
	.global cp0_run_in_umode
cp0_run_in_umode:
	sd	ra, CTX_MODE_RA(tp)
	sd	sp, CTX_MODE_SP(tp)
	la	t0, cp0_mode_ret
	sd	t0, CTX_MODE_RET(tp)
	li	t0, MSTATUS_MPP
	csrc	CSR_MSTATUS, t0		/* MPP = 0 (U) */
	csrw	CSR_MEPC, a0
	mret

	.align 2
cp0_mode_ret:
	ld	ra, CTX_MODE_RA(tp)
	ld	sp, CTX_MODE_SP(tp)
	ret

/* ------------------------------------------------------------------ *
 * Landing pad for a *successful* SRET executed by the S-mode body.
 * With mstatus.TSR clear, `sret` in S mode is legal and jumps to sepc --
 * so sepc must point somewhere real. g_smode aims it here (with
 * sstatus.SPP = 1, so we stay in S mode) and this hands control back to
 * M the same way every other lower-mode body does.
 * ------------------------------------------------------------------ */
	.align 2
	.global cp0_sret_land
cp0_sret_land:
	ecall

/* ------------------------------------------------------------------ *
 * int  cp0_setjmp(void)   -- 0 on the direct path
 * void cp0_longjmp(void)  -- resume the last cp0_setjmp, returning 1
 *
 * Deliberately hand-rolled rather than newlib's setjmp: it must be
 * callable from the trap path with only tp known good.
 * ------------------------------------------------------------------ */
	.align 2
	.global cp0_setjmp
cp0_setjmp:
	sd	sp, CTX_JMP_SP(tp)
	sd	ra, CTX_JMP_RA(tp)
	sd	s0, CTX_JMP_S(tp)
	sd	s1, CTX_JMP_S+8(tp)
	sd	s2, CTX_JMP_S+16(tp)
	sd	s3, CTX_JMP_S+24(tp)
	sd	s4, CTX_JMP_S+32(tp)
	sd	s5, CTX_JMP_S+40(tp)
	sd	s6, CTX_JMP_S+48(tp)
	sd	s7, CTX_JMP_S+56(tp)
	sd	s8, CTX_JMP_S+64(tp)
	sd	s9, CTX_JMP_S+72(tp)
	sd	s10, CTX_JMP_S+80(tp)
	sd	s11, CTX_JMP_S+88(tp)
	li	a0, 0
	ret

	.align 2
	.global cp0_longjmp
cp0_longjmp:
	la	tp, cp0_ctx		/* in case tp was the casualty */
	ld	sp, CTX_JMP_SP(tp)
	ld	ra, CTX_JMP_RA(tp)
	ld	s0, CTX_JMP_S(tp)
	ld	s1, CTX_JMP_S+8(tp)
	ld	s2, CTX_JMP_S+16(tp)
	ld	s3, CTX_JMP_S+24(tp)
	ld	s4, CTX_JMP_S+32(tp)
	ld	s5, CTX_JMP_S+40(tp)
	ld	s6, CTX_JMP_S+48(tp)
	ld	s7, CTX_JMP_S+56(tp)
	ld	s8, CTX_JMP_S+64(tp)
	ld	s9, CTX_JMP_S+72(tp)
	ld	s10, CTX_JMP_S+80(tp)
	ld	s11, CTX_JMP_S+88(tp)
	li	a0, 1
	ret
