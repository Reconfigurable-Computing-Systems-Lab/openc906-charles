/*
 * Shared runtime for the per-unit randomized stress tests: PRNG, baseline-state
 * restore, PMP helper, low-power wake arming, and the UART printer.
 *
 * This is the ONLY .c file in rand_common/. tests/lib/Makefile globs every .c
 * in work/ and links the result, so a second file here would be compiled into
 * all four cases whether they wanted it or not. Anything optional belongs in a
 * header as static inline, or in the per-case source.
 *
 * No newlib stdio: rand_putu formats digits by hand. Every symbol is rand_-
 * prefixed, so a collision with a case-local helper is a loud link error rather
 * than a silent override (LINKLIBS has no -z muldefs).
 */

#include "rand_common.h"

volatile u64 rand_sink;
volatile u64 rand_iter;
volatile u64 rand_recovered;

/* Somewhere safe to aim loads, stores and cache-maintenance addresses at:
 * inside our own .bss, i.e. inside the SRAM window the testbench loads and
 * tb.v:98 wipes. 128 * 8 = 1 KB, i.e. 16 D-cache lines. */
volatile u64 rand_scratch[128];

/* GPRs the stimulus may use freely. x1 (ra), x2 (sp), x3 (gp), x4 (tp, holds
 * &rand_ctx) and x8 (s0) are excluded; x0 is excluded because writing it is a
 * no-op that would silently drop a producer. */
const unsigned char rand_safe_regs[RAND_NSAFE_REGS] = {
    5,  6,  7,  9, 10, 11, 12, 13, 14, 15,
    16, 17, 18, 19, 20, 21, 22, 28, 29, 30
};

/* ==================================================================== *
 * PRNG. xorshift64: three shifts and three xors, no memory traffic, so it does
 * not perturb the D-cache state a group may be trying to set up.
 * ==================================================================== */
static volatile u64 rand_state;

void rand_srand(u64 seed)
{
    rand_state = seed | 1UL;      /* xorshift must not start at zero */
}

u64 rand_rnd(void)
{
    u64 x = rand_state;

    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    rand_state = x;
    return x;
}

/* ==================================================================== *
 * Baseline state. Called at start-up, after every longjmp recovery, and
 * periodically from the dispatch loop, so that no group can leave the machine
 * in a configuration that breaks the next one.
 * ==================================================================== */
void rand_restore_sane_state(void)
{
    /* Back to M mode with interrupts off before touching anything else. */
    CSR_C(CSR_MSTATUS, MSTATUS_MIE | MSTATUS_MPRV | MSTATUS_TSR |
                       MSTATUS_TW  | MSTATUS_TVM  | MSTATUS_SUM | MSTATUS_MXR);
    CSR_S(CSR_MSTATUS, MSTATUS_MPP | MSTATUS_FS_INIT);
    CSR_W(CSR_MIE, 0);
    CSR_C(CSR_MIP, MIP_SW_MASK);

    /* Translation off. Must precede any MPRV or S/U-mode work. */
    CSR_W(CSR_SATP, 0);

    /* Delegation off. */
    CSR_W(CSR_MEDELEG, 0);
    CSR_W(CSR_MIDELEG, 0);

    /* Our own handlers, direct mode. */
    CSR_W(CSR_MTVEC, (u64)(unsigned long)&rand_trap_m);
    CSR_W(CSR_STVEC, (u64)(unsigned long)&rand_trap_s);

    /* T-Head control plane back to the crt0.s baseline: caches, branch
     * prediction, RAS and prefetch all enabled, Xtheadc decode enabled. */
    CSR_W(CSR_MXSTATUS, MXSTATUS_RESET);
    CSR_W(CSR_MHCR,  MHCR_ALL_ON);
    CSR_W(CSR_MHINT, MHINT_BASE);
    CSR_W(CSR_MHINT2, 0);

    /* FP state clean and rounding mode round-to-nearest. fflags is sticky and
     * frm is persistent, and the decoder reads frm: leaving frm at 5..7 makes
     * every subsequent dynamic-rounding FP op illegal, which degenerates into a
     * trap storm that retires instructions -- a livelock the no-retire watchdog
     * never catches. */
    CSR_W(CSR_FCSR, 0);

    /* Counters unfrozen and readable, S-mode writes disallowed. */
    CSR_W(CSR_MCNTIHBT, 0);
    CSR_W(CSR_MCNTEN, ~0UL);
    CSR_W(CSR_SCNTEN, ~0UL);
    CSR_W(CSR_MCNTWEN, 0);
    CSR_W(CSR_MCNTINTEN, 0);
    CSR_W(CSR_MCNTOF, 0);

    /* Interrupt sources quiet: timer disarmed, software bit clear, PLIC masked. */
    *(volatile unsigned int *)CLINT_MTIMECMPH = 0xFFFFFFFFu;
    *(volatile unsigned int *)CLINT_MSIP0     = 0u;
    *(volatile unsigned int *)PLIC_MTH_H0     = 31u;
}

/* PMP entry 0 spanning everything, permissively. Without it, S and U mode are
 * denied every access (no matching PMP entry => deny for S/U), so the
 * privilege-mode groups cannot run at all. Entry 0 has the highest priority, so
 * whatever a group writes to entries 1..15 is harmless.
 *
 * Note the deliberate absence of pmpcfg.L: a locked entry is sticky until reset
 * and would poison the rest of the run. Where a test needs a fetch fault it
 * uses the sysmap strong-order window instead, which has no persistent state. */
void rand_pmp_open_everything(void)
{
    CSR_W(CSR_PMPADDR0, ~0UL);      /* NAPOT covering the whole space */
    CSR_W(CSR_PMPCFG0, 0x1FUL);     /* entry 0: A=NAPOT, X|W|R        */
}

/* ==================================================================== *
 * WFI / low power.
 *
 * The LPMD wake condition is |(mie & mip) (aq_cp0_trap_csr.v:1340,
 * aq_cp0_lpmd.v:190) and it is privilege- and delegation-blind. The naive
 * "arm an interrupt then wfi" sequence hangs: the interrupt is taken *before*
 * the WFI, the handler clears the source, and then nothing can wake the FSM.
 * Delegating STIP with sstatus.SIE clear leaves a source that neither M nor S
 * will take but that still satisfies the wake condition.
 * ==================================================================== */
void rand_arm_lpmd_wake(void)
{
    CSR_C(CSR_SSTATUS, MSTATUS_SIE);
    CSR_W(CSR_MIDELEG, IRQ_STIP);
    CSR_S(CSR_MIE, IRQ_STIP);
    CSR_S(CSR_MIP, IRQ_STIP);
}

void rand_disarm_lpmd_wake(void)
{
    CSR_C(CSR_MIP, MIP_SW_MASK);
    CSR_W(CSR_MIE, 0);
    CSR_W(CSR_MIDELEG, 0);
}

/* ==================================================================== *
 * UART.
 *
 * UART0 at 0x1001_5000 is in a cacheable sysmap region, so a plain store lands
 * in the D-cache and its eventual line writeback carries wstrb=16'hffff, which
 * tb.v's console decoder (awlen==0 and wstrb in {f,f0,f00,f000}) does not
 * match. Hence the D-cache-off bracket.
 *
 * One 32-bit store per character. Even with the D-cache off the store goes
 * through the store buffer, where consecutive writes to the same address
 * coalesce, and the testbench snoops the AXI port for exactly one cycle per
 * write -- so characters need real separation, not just ordering. th.sync
 * drains the bus interface (not only the LSU buffers, which is all `fence`
 * does), and the spin gives the snooper an unambiguous cycle to sample.
 * ==================================================================== */
void rand_report_begin(void)
{
    DCACHE_SAFE_POINT();
    CSR_C(CSR_MHCR, MHCR_DE);
}

void rand_report_end(void)
{
    CSR_S(CSR_MHCR, MHCR_DE);
}

void rand_putc(char c)
{
    unsigned i;

    *(volatile unsigned int *)UART_THR = (unsigned int)(unsigned char)c;
    TH_OP(TH_SYNC);
    for (i = 0; i < 24u; i++)
        __asm__ volatile ("" ::: "memory");
}

void rand_puts(const char *s)
{
    while (*s)
        rand_putc(*s++);
}

void rand_putu(u64 v)
{
    char buf[24];
    int n = 0;

    if (!v) { rand_putc('0'); return; }
    while (v) { buf[n++] = (char)('0' + (v % 10u)); v /= 10u; }
    while (n--) rand_putc(buf[n]);
}

void rand_putx(u64 v)
{
    static const char hex[] = "0123456789abcdef";
    char buf[16];
    int n = 0;

    if (!v) { rand_putc('0'); return; }
    while (v) { buf[n++] = hex[v & 15u]; v >>= 4; }
    while (n--) rand_putc(buf[n]);
}

/* The trap-cause histogram. Printing it is how a run proves that the traps it
 * took were the traps it meant to take -- with no golden model, an unexpected
 * cause distribution is the main signal that a group is not doing what its
 * comment says. */
void rand_hist_dump(const char *tag)
{
    unsigned i;

    rand_puts("\n[");
    rand_puts(tag);
    rand_puts("] mtraps=");
    rand_putu(RCTX_U64(RCTX_TOTAL));
    rand_puts(" straps=");
    rand_putu(RCTX_U64(RCTX_STOTAL));
    rand_puts(" nested=");
    rand_putu(RCTX_U64(RCTX_NESTED));
    rand_puts(" faultret=");
    rand_putu(RCTX_U64(RCTX_FAULTS));
    rand_puts(" recovered=");
    rand_putu(rand_recovered);

    rand_puts("\n[");
    rand_puts(tag);
    rand_puts("] M causes:");
    for (i = 0; i < 32; i++) {
        u64 n = RCTX_U64(RCTX_COUNT + 8u * i);
        if (n) { rand_putc(' '); rand_putu(i); rand_putc('='); rand_putu(n); }
    }
    rand_puts("\n[");
    rand_puts(tag);
    rand_puts("] M ints:");
    for (i = 32; i < 64; i++) {
        u64 n = RCTX_U64(RCTX_COUNT + 8u * i);
        if (n) { rand_putc(' '); rand_putu(i - 32u); rand_putc('='); rand_putu(n); }
    }
    rand_puts("\n[");
    rand_puts(tag);
    rand_puts("] S causes:");
    for (i = 0; i < 64; i++) {
        u64 n = RCTX_U64(RCTX_SCOUNT + 8u * i);
        if (n) {
            rand_putc(' ');
            if (i >= 32) rand_putc('i');
            rand_putu(i & 31u);
            rand_putc('=');
            rand_putu(n);
        }
    }
    rand_putc('\n');
}
