/*
 * Shared harness for the per-unit randomized stress tests: iu_random,
 * vidu_random, idu_random, ifu_random.
 *
 * These four cases all need the same scaffolding -- a seeded PRNG, a working
 * trap handler with a cause histogram and an unwind path, a permissive PMP
 * entry, a baseline-state restore, and a UART printer that works with the
 * D-cache off. cp0_random has all of it, but embedded in a file whose trap
 * handler carries CP0-specific machinery (vectored dispatch, CLINT/PLIC
 * teardown, an ecall-back-to-M trampoline). Rather than generalise a working,
 * baselined test, the common 700 lines live here and cp0_random is left alone.
 *
 * See tests/cases/rand_common/README.md for the rules that keep this directory
 * safe to share, and doc/specs/unit-random-tests.md for the methodology.
 *
 * ORDERING RULE, non-negotiable: the first two things every main() does are
 *     rand_trap_init();        -- clears mstatus.MIE, installs mtvec/stvec
 *     rand_pmp_open_everything();
 * crt0.s sets mstatus.MIE=1 while mtvec still points at its own vector_table,
 * whose entries are .long (4 bytes) but are loaded with ld (8 bytes) -- so any
 * trap before rand_trap_init() is an infinite exception loop. rand_trap_init()
 * clears MIE itself as belt-and-braces, so the discipline cannot be forgotten.
 */

#ifndef RAND_COMMON_H
#define RAND_COMMON_H

#include "rand_csrs.h"
#include "rand_th_insn.h"

#ifndef __ASSEMBLER__

typedef unsigned long      u64;
typedef unsigned int       u32;
typedef unsigned short     u16;
typedef unsigned char      u8;
typedef long               s64;
typedef int                s32;

/* ==================================================================== *
 * CSR access. The CSR number is encoded in the instruction, so it has to be a
 * compile-time constant -- hence macros with a stringified numeric address
 * rather than a runtime table.
 * ==================================================================== */
#define STR_(x) #x
#define STR(x)  STR_(x)

#define CSR_R(csr) ({ u64 v_; \
    __asm__ volatile ("csrr %0, " STR(csr) : "=r"(v_)); v_; })
#define CSR_W(csr, val) \
    __asm__ volatile ("csrw " STR(csr) ", %0" :: "r"((u64)(val)))
#define CSR_S(csr, val) \
    __asm__ volatile ("csrs " STR(csr) ", %0" :: "r"((u64)(val)))
#define CSR_C(csr, val) \
    __asm__ volatile ("csrc " STR(csr) ", %0" :: "r"((u64)(val)))
#define CSR_RW(csr, val) ({ u64 o_; \
    __asm__ volatile ("csrrw %0, " STR(csr) ", %1" : "=r"(o_) : "r"((u64)(val))); o_; })
#define CSR_RS(csr, val) ({ u64 o_; \
    __asm__ volatile ("csrrs %0, " STR(csr) ", %1" : "=r"(o_) : "r"((u64)(val))); o_; })
#define CSR_RC(csr, val) ({ u64 o_; \
    __asm__ volatile ("csrrc %0, " STR(csr) ", %1" : "=r"(o_) : "r"((u64)(val))); o_; })
#define CSR_RWI(csr, imm) ({ u64 o_; \
    __asm__ volatile ("csrrwi %0, " STR(csr) ", " STR(imm) : "=r"(o_)); o_; })
#define CSR_RSI(csr, imm) ({ u64 o_; \
    __asm__ volatile ("csrrsi %0, " STR(csr) ", " STR(imm) : "=r"(o_)); o_; })
#define CSR_RCI(csr, imm) ({ u64 o_; \
    __asm__ volatile ("csrrci %0, " STR(csr) ", " STR(imm) : "=r"(o_)); o_; })

/* ==================================================================== *
 * Raw-encoded instruction helpers. Needed because THEAD_GCC=0 builds have no
 * xtheadc, and because several coverage points (FP rm=101/110, c.lui) are
 * encodings the assembler will not emit on request.
 * ==================================================================== */
#define TH_OP(word) \
        __asm__ volatile (".word " STR(word) ::: "memory")

/* rs1 forms: pin the operand in a0 (x10) and OR the register number into
 * inst[19:15] of the raw word. */
#define TH_OP_RS1(word, val) do {                                       \
        register u64 rs_ __asm__("a0") = (u64)(val);                    \
        __asm__ volatile (".word (" STR(word) ") + (10 << 15)"          \
                          :: "r"(rs_) : "memory");                      \
    } while (0)

/* Emit a runtime-computed 32-bit instruction word. Only usable where the word
 * is a compile-time constant -- a *runtime* word would need self-modifying
 * code, which these tests deliberately avoid. */
#define RAW_OP(word) TH_OP(word)

/* 16-bit (RVC) raw halfword. */
#define RAW_OP16(half) \
        __asm__ volatile (".2byte " STR(half) ::: "memory")

/* A clean+invalidate of the whole D-cache. Issued before anything that
 * invalidates without writing back (th.dcache.iall / isw / iva / ipa, MCOR
 * bit 4) so that losing those lines cannot corrupt our own stack or globals. */
#define DCACHE_SAFE_POINT() TH_OP(TH_DCACHE_CIALL)

/* Store code, then make it fetchable. Getting this order backwards -- D-cache
 * invalidate before the clean -- throws the freshly written code away, so it
 * exists once, here. */
#define RAND_ICACHE_SYNC() do {                                         \
        TH_OP(TH_DCACHE_CIALL);                                         \
        TH_OP(TH_SYNC);                                                 \
        __asm__ volatile ("fence.i" ::: "memory");                      \
    } while (0)

/* ==================================================================== *
 * Registers the stimulus must never allocate or clobber:
 *   x1  ra   return address
 *   x2  sp   stack pointer
 *   x3  gp   global pointer
 *   x4  tp   holds &rand_ctx for the trap handler
 *   x8  s0   frame pointer
 * Any group that builds instruction encodings at runtime must draw its register
 * fields from RAND_SAFE_REGS.
 * ==================================================================== */
#define RAND_NSAFE_REGS 20
extern const unsigned char rand_safe_regs[RAND_NSAFE_REGS];

/* ==================================================================== *
 * rand_lib.c
 * ==================================================================== */
extern volatile u64 rand_sink;          /* keeps results from being optimised away */
extern volatile u64 rand_iter;
extern volatile u64 rand_recovered;     /* iterations abandoned via longjmp */
extern volatile u64 rand_scratch[128];  /* safe .bss target for loads/stores */

void rand_srand(u64 seed);
u64  rand_rnd(void);

void rand_restore_sane_state(void);
void rand_pmp_open_everything(void);

/* WFI needs a wake source that neither M nor S will take but that still
 * satisfies the LPMD wake condition |(mie & mip) (aq_cp0_lpmd.v:190, which is
 * privilege- and delegation-blind). Delegating STIP with sstatus.SIE clear is
 * that source. A WFI with nothing armed is unrecoverable short of reset. */
void rand_arm_lpmd_wake(void);
void rand_disarm_lpmd_wake(void);

/* UART. The D-cache must be off around any print: UART0 sits in a cacheable
 * sysmap region, and a cached store's line writeback carries wstrb=16'hffff,
 * which tb.v's console decoder does not match. */
void rand_report_begin(void);
void rand_report_end(void);
void rand_putc(char c);
void rand_puts(const char *s);
void rand_putu(u64 v);
void rand_putx(u64 v);
/* Print the trap-cause histogram and the trap totals. */
void rand_hist_dump(const char *tag);

/* ==================================================================== *
 * rand_trap.S
 * ==================================================================== */
void rand_trap_init(void);
void rand_trap_m(void);
void rand_trap_m_vectored(void);
void rand_trap_s(void);
void rand_run_in_smode(void (*fn)(void));
void rand_run_in_umode(void (*fn)(void));
void rand_sret_land(void);
/* Jump to an arbitrary address in M mode and come back. While the excursion is
 * live, ANY synchronous exception resumes at the landing pad instead of
 * stepping over the faulting instruction -- which is what makes a deliberate
 * jump into a fetch-faulting page recoverable. */
void rand_run_at(u64 addr);
int  rand_setjmp(void);
void rand_longjmp(void);
extern unsigned char rand_ctx[RCTX_SIZE];

#define RCTX_U64(off)  (*(volatile u64 *)((unsigned char *)rand_ctx + (off)))

#endif /* !__ASSEMBLER__ */

#endif /* RAND_COMMON_H */
