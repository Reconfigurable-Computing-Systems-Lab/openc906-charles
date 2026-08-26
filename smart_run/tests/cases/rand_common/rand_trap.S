/*
 * Trap handling and privilege-mode plumbing shared by the per-unit randomized
 * stress tests.
 *
 * Deliberately does NOT use crt0.s's `vector_table`: its entries are .long
 * (4 bytes) while the dispatcher loads them with `ld` (8 bytes), which loops
 * forever on any trap (CLAUDE.md "Known Bugs"). This file installs its own
 * mtvec/stvec instead -- and clears mstatus.MIE on the way, because crt0.s sets
 * MIE=1 before `jal main` while that broken handler is still installed.
 *
 * Register discipline: `tp` (x4) permanently holds &rand_ctx. tp is a fixed
 * register in the RISC-V ABI -- GCC never allocates it -- and this is a
 * single-threaded bare-metal build with no TLS, so it is free. That gives the
 * handler a scratch base without having to steal mscratch/sscratch, which the
 * tests write randomly.
 *
 * Every handler is written so that a trap it did not expect cannot wedge the
 * run: nested traps unwind to the dispatch-loop head via rand_longjmp.
 *
 * Derived from cp0_random/cp0_trap.S. The two are deliberately separate files:
 * cp0_trap.S carries CP0-specific machinery (vectored dispatch tables, CLINT
 * and PLIC interrupt teardown, the ecall-back-to-M trampoline) and is covered
 * by a committed baseline, so it is not refactored onto this. If you fix a bug
 * in one, check the other.
 */

#include "rand_csrs.h"

	.section .bss
	.align 6
	.global rand_ctx
rand_ctx:
	.space RCTX_SIZE

	.section .text

/* ------------------------------------------------------------------ *
 * void rand_trap_init(void)
 *   Clear mstatus.MIE, point tp at rand_ctx, install mtvec (direct) and
 *   stvec, zero the context. Must run before anything else can trap.
 * ------------------------------------------------------------------ */
	.align 2
	.global rand_trap_init
rand_trap_init:
	li	t0, MSTATUS_MIE
	csrc	CSR_MSTATUS, t0		/* crt0.s left this set -- undo it first */
	csrw	CSR_MIE, zero

	la	tp, rand_ctx
	li	t0, 0
	li	t1, RCTX_SIZE
1:	add	t2, tp, t0
	sd	zero, 0(t2)
	addi	t0, t0, 8
	blt	t0, t1, 1b

	la	t0, rand_trap_m
	csrw	CSR_MTVEC, t0		/* mode 0: direct */
	la	t0, rand_trap_s
	csrw	CSR_STVEC, t0
	ret

/* ------------------------------------------------------------------ *
 * M-mode trap handler, direct mode.
 * ------------------------------------------------------------------ */
	.align 2
	.global rand_trap_m
rand_trap_m:
	sd	t0, RCTX_S_T0(tp)
	sd	t1, RCTX_S_T1(tp)
	sd	t2, RCTX_S_T2(tp)
	sd	a0, RCTX_S_A0(tp)

	/* trap bookkeeping: total, per-cause count */
	ld	t0, RCTX_TOTAL(tp)
	addi	t0, t0, 1
	sd	t0, RCTX_TOTAL(tp)

	csrr	t0, CSR_MCAUSE
	srli	t1, t0, 63		/* t1 = interrupt flag */
	andi	t2, t0, 0x1f		/* t2 = cause          */
	slli	t0, t1, 5
	add	t0, t0, t2		/* index = {intr, cause[4:0]} */
	slli	t0, t0, 3
	add	t0, t0, tp
	ld	a0, RCTX_COUNT(t0)
	addi	a0, a0, 1
	sd	a0, RCTX_COUNT(t0)

	/* nested trap? -> abandon this iteration */
	ld	t0, RCTX_DEPTH(tp)
	addi	t0, t0, 1
	sd	t0, RCTX_DEPTH(tp)
	li	a0, 1
	bgt	t0, a0, rand_trap_bail

	bnez	t1, rand_trap_m_int

/* ---- synchronous exception ---- */
#ifdef RAND_FORCE_BAIL
	/* Validation builds only (<U>_EXTRA=-DRAND_FORCE_BAIL): treat ebreak as
	 * an unrecoverable trap so the rand_setjmp/rand_longjmp recovery path
	 * actually runs. In a normal run `recovered` stays 0, which means that
	 * path is never exercised -- this is how it gets tested. */
	li	a0, 3
	beq	t2, a0, rand_trap_bail
#endif

	/* Inside a rand_run_at() excursion? Then resume at its landing pad
	 * rather than trying to step over the faulting instruction. The whole
	 * point of the excursion is to fetch from an address that faults on
	 * every fetch, so stepping forward would just trap again, forever. */
	ld	a0, RCTX_FAULT_RET(tp)
	beqz	a0, 3f
	csrw	CSR_MEPC, a0
	sd	zero, RCTX_FAULT_RET(tp)
	ld	a0, RCTX_FAULTS(tp)
	addi	a0, a0, 1
	sd	a0, RCTX_FAULTS(tp)
	li	a0, MSTATUS_MPP
	csrs	CSR_MSTATUS, a0		/* return to M mode */
	j	rand_trap_m_exit
3:
	/* ecall from S (9) or U (8): hand control back to the M-mode caller */
	li	a0, 8
	beq	t2, a0, rand_trap_m_toM
	li	a0, 9
	beq	t2, a0, rand_trap_m_toM

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
	j	rand_trap_m_exit

rand_trap_m_toM:
	/* resume in M mode at the label the mode-entry helper recorded */
	ld	t0, RCTX_MODE_RET(tp)
	csrw	CSR_MEPC, t0
	li	t0, MSTATUS_MPP		/* MPP = 3 (M) */
	csrs	CSR_MSTATUS, t0
	j	rand_trap_m_exit

/* ---- interrupt: silence the source, then return ---- *
 * These tests hold mstatus.MIE at 0, so an interrupt here is either the WFI
 * group's armed wake or something unexpected. Either way the source is
 * silenced at its real origin, idempotently: a CLINT-sourced S interrupt
 * cannot be cleared through mip (mip owns only ssip_reg/stip_reg/seip_reg,
 * aq_cp0_trap_csr.v:1216-1221), so the CLINT register itself must be written
 * back or the interrupt re-traps forever -- a livelock that retires, which the
 * testbench's no-retire watchdog would never catch. */
rand_trap_m_int:
	li	a0, 1			/* 1 = S software  */
	beq	t2, a0, rand_int_clr_sip
	li	a0, 5			/* 5 = S timer     */
	beq	t2, a0, rand_int_clr_sip
	li	a0, 9			/* 9 = S external  */
	beq	t2, a0, rand_int_clr_sip
	li	a0, 3			/* 3 = M software  */
	beq	t2, a0, rand_int_clr_msip
	li	a0, 7			/* 7 = M timer     */
	beq	t2, a0, rand_int_clr_mtip
	li	a0, 11			/* 11 = M external */
	beq	t2, a0, rand_int_clr_meip
	li	a0, 17			/* 17 = HPM overflow */
	beq	t2, a0, rand_int_clr_moip
	/* unknown interrupt: mask globally rather than spin */
	csrw	CSR_MIE, zero
	j	rand_trap_m_exit

rand_int_clr_sip:
	li	t0, 1
	sll	t0, t0, t2
	csrc	CSR_MIP, t0
	li	t0, CLINT_SSIP0
	sw	zero, 0(t0)
	li	t0, CLINT_STIMECMPH
	li	t1, -1
	sw	t1, 0(t0)
	j	rand_trap_m_exit

rand_int_clr_msip:
	li	t0, CLINT_MSIP0
	sw	zero, 0(t0)
	j	rand_trap_m_exit

rand_int_clr_mtip:
	/* mtip is a combinational mtimecmp <= mtime compare: push cmp up */
	li	t0, CLINT_MTIMECMPH
	li	t1, -1
	sw	t1, 0(t0)
	j	rand_trap_m_exit

rand_int_clr_meip:
	li	t0, PLIC_MCLAIM_H0
	lw	t1, 0(t0)		/* claim: clears pending, sets active */
	sw	t1, 0(t0)		/* complete: clears active           */
	j	rand_trap_m_exit

rand_int_clr_moip:
	csrw	CSR_MCNTINTEN, zero
	csrw	CSR_MCNTOF, zero
	j	rand_trap_m_exit

rand_trap_m_exit:
	ld	t0, RCTX_DEPTH(tp)
	addi	t0, t0, -1
	sd	t0, RCTX_DEPTH(tp)
	ld	t0, RCTX_S_T0(tp)
	ld	t1, RCTX_S_T1(tp)
	ld	t2, RCTX_S_T2(tp)
	ld	a0, RCTX_S_A0(tp)
	mret

/* A trap we could not make sense of, or a trap inside a trap. Drop the depth,
 * force M mode with interrupts off, and longjmp to the loop head. */
rand_trap_bail:
	sd	zero, RCTX_DEPTH(tp)
	sd	zero, RCTX_FAULT_RET(tp)
	ld	t0, RCTX_NESTED(tp)
	addi	t0, t0, 1
	sd	t0, RCTX_NESTED(tp)
	la	t0, rand_bail_land
	csrw	CSR_MEPC, t0
	li	t0, MSTATUS_MPP
	csrs	CSR_MSTATUS, t0		/* MPP = M */
	li	t0, MSTATUS_MIE
	csrc	CSR_MSTATUS, t0		/* return with interrupts off */
	csrw	CSR_MIE, zero
	mret
rand_bail_land:
	j	rand_longjmp

/* ------------------------------------------------------------------ *
 * M-mode trap handler, vectored mode. mtvec.mode=1 sends interrupt cause
 * N to base + 4*N; exceptions still arrive at offset 0.
 * ------------------------------------------------------------------ */
	.align 6
	.global rand_trap_m_vectored
rand_trap_m_vectored:
	j	rand_trap_m		/* 0: exceptions */
	.rept 19
	j	rand_trap_m
	.endr

/* ------------------------------------------------------------------ *
 * S-mode trap handler, for delegated traps. Only touches S CSRs.
 * ------------------------------------------------------------------ */
	.align 2
	.global rand_trap_s
rand_trap_s:
	sd	t0, RCTX_S_ST0(tp)
	sd	t1, RCTX_S_ST1(tp)
	sd	t2, RCTX_S_ST2(tp)

	ld	t0, RCTX_STOTAL(tp)
	addi	t0, t0, 1
	sd	t0, RCTX_STOTAL(tp)

	csrr	t0, CSR_SCAUSE
	srli	t1, t0, 63
	andi	t2, t0, 0x1f
	slli	t0, t1, 5
	add	t0, t0, t2
	slli	t0, t0, 3
	add	t0, t0, tp
	ld	t1, RCTX_SCOUNT(t0)
	addi	t1, t1, 1
	sd	t1, RCTX_SCOUNT(t0)

	csrr	t0, CSR_SCAUSE
	srli	t1, t0, 63
	bnez	t1, rand_trap_s_int

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
	j	rand_trap_s_exit

rand_trap_s_int:
	/* A write to SIP only ever updates ssip -- stip_reg and seip_reg are
	 * explicitly held -- so try sip first, then always mask the source in
	 * sie, which IS writable from S mode for any delegated bit. Without the
	 * sie fallback a delegated STIP re-traps forever. */
	andi	t2, t0, 0x1f
	li	t0, 1
	sll	t0, t0, t2
	csrc	CSR_SIP, t0
	csrc	CSR_SIE, t0

rand_trap_s_exit:
	ld	t0, RCTX_S_ST0(tp)
	ld	t1, RCTX_S_ST1(tp)
	ld	t2, RCTX_S_ST2(tp)
	sret

/* ------------------------------------------------------------------ *
 * void rand_run_in_smode(void (*fn)(void))
 * void rand_run_in_umode(void (*fn)(void))
 *   Drop to S / U, run fn, come back. fn signals completion with ECALL,
 *   which the M handler turns into a return to `rand_mode_ret`. Callers
 *   keep medeleg[8]/[9] clear so ecall is never delegated.
 *
 * ra and sp are parked in rand_ctx rather than on the stack: the body is a C
 * function entered by mret, so its prologue may move sp and its epilogue never
 * runs (the ecall is intercepted first). Restoring both from the context makes
 * the round trip immune to whatever the body did to the stack.
 * ------------------------------------------------------------------ */
	.align 2
	.global rand_run_in_smode
rand_run_in_smode:
	sd	ra, RCTX_MODE_RA(tp)
	sd	sp, RCTX_MODE_SP(tp)
	la	t0, rand_mode_ret
	sd	t0, RCTX_MODE_RET(tp)
	li	t0, MSTATUS_MPP
	csrc	CSR_MSTATUS, t0		/* clear MPP */
	li	t0, MSTATUS_MPP_S
	csrs	CSR_MSTATUS, t0		/* MPP = 1 (S) */
	csrw	CSR_MEPC, a0
	mret

	.align 2
	.global rand_run_in_umode
rand_run_in_umode:
	sd	ra, RCTX_MODE_RA(tp)
	sd	sp, RCTX_MODE_SP(tp)
	la	t0, rand_mode_ret
	sd	t0, RCTX_MODE_RET(tp)
	li	t0, MSTATUS_MPP
	csrc	CSR_MSTATUS, t0		/* MPP = 0 (U) */
	csrw	CSR_MEPC, a0
	mret

	.align 2
rand_mode_ret:
	ld	ra, RCTX_MODE_RA(tp)
	ld	sp, RCTX_MODE_SP(tp)
	ret

/* ------------------------------------------------------------------ *
 * void rand_run_at(u64 addr)
 *   Jump to `addr` in M mode with a fault net underneath: RCTX_FAULT_RET is
 *   armed, so ANY synchronous exception taken while the excursion is live
 *   resumes at rand_run_at_land instead of stepping over the faulting
 *   instruction. That is what makes a deliberate jump into the sysmap
 *   strong-order window (instruction access fault on every fetch, with no
 *   M-mode escape -- aq_mmu_utlb.v:788-790) recoverable.
 *
 *   The target may also simply `ret`, which is how the far-stub and arena
 *   entries come back normally.
 * ------------------------------------------------------------------ */
	.align 2
	.global rand_run_at
rand_run_at:
	sd	ra, RCTX_MODE_RA(tp)
	sd	sp, RCTX_MODE_SP(tp)
	la	t0, rand_run_at_land
	sd	t0, RCTX_FAULT_RET(tp)
	li	t0, MSTATUS_MPP
	csrs	CSR_MSTATUS, t0		/* MPP = 3 (M): come back to M mode */
	csrw	CSR_MEPC, a0
	la	ra, rand_run_at_land	/* so a plain `ret` also lands here */
	mret

	.align 2
	.global rand_run_at_land
rand_run_at_land:
	la	tp, rand_ctx		/* in case the excursion clobbered tp */
	sd	zero, RCTX_FAULT_RET(tp)
	ld	ra, RCTX_MODE_RA(tp)
	ld	sp, RCTX_MODE_SP(tp)
	ret

/* ------------------------------------------------------------------ *
 * Landing pad for a *successful* SRET executed by an S-mode body. With
 * mstatus.TSR clear, `sret` in S mode is legal and jumps to sepc -- so
 * sepc must point somewhere real.
 * ------------------------------------------------------------------ */
	.align 2
	.global rand_sret_land
rand_sret_land:
	ecall

/* ------------------------------------------------------------------ *
 * int  rand_setjmp(void)   -- 0 on the direct path
 * void rand_longjmp(void)  -- resume the last rand_setjmp, returning 1
 *
 * Deliberately hand-rolled rather than newlib's setjmp: it must be callable
 * from the trap path with only tp known good.
 * ------------------------------------------------------------------ */
	.align 2
	.global rand_setjmp
rand_setjmp:
	sd	sp, RCTX_JMP_SP(tp)
	sd	ra, RCTX_JMP_RA(tp)
	sd	s0, RCTX_JMP_S(tp)
	sd	s1, RCTX_JMP_S+8(tp)
	sd	s2, RCTX_JMP_S+16(tp)
	sd	s3, RCTX_JMP_S+24(tp)
	sd	s4, RCTX_JMP_S+32(tp)
	sd	s5, RCTX_JMP_S+40(tp)
	sd	s6, RCTX_JMP_S+48(tp)
	sd	s7, RCTX_JMP_S+56(tp)
	sd	s8, RCTX_JMP_S+64(tp)
	sd	s9, RCTX_JMP_S+72(tp)
	sd	s10, RCTX_JMP_S+80(tp)
	sd	s11, RCTX_JMP_S+88(tp)
	li	a0, 0
	ret

	.align 2
	.global rand_longjmp
rand_longjmp:
	la	tp, rand_ctx		/* in case tp was the casualty */
	ld	sp, RCTX_JMP_SP(tp)
	ld	ra, RCTX_JMP_RA(tp)
	ld	s0, RCTX_JMP_S(tp)
	ld	s1, RCTX_JMP_S+8(tp)
	ld	s2, RCTX_JMP_S+16(tp)
	ld	s3, RCTX_JMP_S+24(tp)
	ld	s4, RCTX_JMP_S+32(tp)
	ld	s5, RCTX_JMP_S+40(tp)
	ld	s6, RCTX_JMP_S+48(tp)
	ld	s7, RCTX_JMP_S+56(tp)
	ld	s8, RCTX_JMP_S+64(tp)
	ld	s9, RCTX_JMP_S+72(tp)
	ld	s10, RCTX_JMP_S+80(tp)
	ld	s11, RCTX_JMP_S+88(tp)
	li	a0, 1
	ret
