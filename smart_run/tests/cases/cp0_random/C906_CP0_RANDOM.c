/*
 * cp0_random -- randomized CP0 stress test for the OpenC906.
 *
 * Executes CP0_ITERS (default 100000) dynamic iterations of a seeded
 * xorshift64 dispatch loop. Each iteration picks one of ~32 operation groups
 * that together cover every CP0 function reachable from software: the CSR file
 * and its illegal/legal-hole decode, the T-Head extension registers and the
 * core-wide enable broadcast, the fence / cache-maintenance / invalidation
 * FSMs, WFI and the low-power clock enable, traps, delegation, all three
 * privilege modes, and the externally-implemented PMP / HPCP / MMU / DTU CSR
 * groups that CP0 decodes but does not own.
 *
 * There is deliberately NO golden-model self-check: the test passes by running
 * to completion (main returns -> crt0.s __exit -> the PASS magic the testbench
 * watches for). The evidence that CP0 was actually stimulated is
 * work/cp0_toggle.report, produced by the port-toggle monitor bound into the
 * testbench (cli_tools/gen_cp0_toggle_mon.py).
 *
 * Robustness, not correctness, is therefore the design constraint. Two
 * mechanisms carry it:
 *   - every group that perturbs persistent state saves and restores it, masked
 *     to that CSR's writable bits, and restore_sane_state() re-baselines
 *     everything every 4096 iterations;
 *   - the trap handler unwinds to the loop head via cp0_longjmp on any nested
 *     or unexpected trap, so a wild jump costs one iteration rather than the run.
 *
 * mstatus.MIE is held at 0 except inside the interrupt groups, so interrupts
 * only ever arrive where this file asks for them.
 *
 * Everything here was derived from the RTL; see cp0_csrs.h for the file:line
 * provenance of each address and mask.
 */

#include "cp0_csrs.h"
#include "cp0_th_insn.h"

#ifndef CP0_ITERS
#define CP0_ITERS 100000
#endif
#ifndef CP0_SEED
#define CP0_SEED 0x2024C906
#endif

/* ==================================================================== *
 * CSR access helpers. The CSR number is encoded in the instruction, so
 * it must be a compile-time constant -- hence macros with a stringified
 * numeric address rather than a runtime table.
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

/* Full six-form probe of one read/write CSR: read the old value, drive a
 * masked random value through csrrw/csrrs/csrrc, then put it back. */
#define PROBE_RW(csr, wmask, rnd) do {                                  \
        u64 old_ = CSR_R(csr);                                          \
        u64 v_   = (u64)(rnd) & (u64)(wmask);                           \
        (void)CSR_RW(csr, v_);                                          \
        (void)CSR_RS(csr, v_);                                          \
        (void)CSR_RC(csr, v_);                                          \
        CSR_W(csr, old_);                                               \
    } while (0)

/* Immediate forms. The 5-bit immediate has to be a literal, so the choice is
 * a small switch. csrrsi/csrrci with 0 perform no write at all
 * (aq_cp0_iui.v:455,463-465) -- that is itself a coverage point. */
#define PROBE_IMM(csr, sel) do {                                        \
        u64 old_ = CSR_R(csr);                                          \
        switch ((sel) & 3u) {                                           \
        case 0:  (void)CSR_RWI(csr, 0x01); break;                       \
        case 1:  (void)CSR_RSI(csr, 0x1f); break;                       \
        case 2:  (void)CSR_RCI(csr, 0x1f); break;                       \
        default: (void)CSR_RSI(csr, 0x00); break;                       \
        }                                                               \
        CSR_W(csr, old_);                                               \
    } while (0)

/* Read a CSR and discard -- used where only the read path matters. */
#define PROBE_RO(csr) do { u64 v_ = CSR_R(csr); sink += v_; } while (0)

/* Attempt a write to a read-only CSR. Expected to raise cause 2. */
#define PROBE_RO_WRITE(csr, rnd) \
        __asm__ volatile ("csrw " STR(csr) ", %0" :: "r"((u64)(rnd)))

/* ==================================================================== *
 * Raw-encoded instruction helpers
 * ==================================================================== */
#define TH_OP(word) \
        __asm__ volatile (".word " STR(word) ::: "memory")

/* rs1 forms: pin the operand in a0 (x10) and OR the register number into
 * inst[19:15] of the raw word. */
#define TH_OP_RS1(word, val) do {                                       \
        register u64 rs_ __asm__("a0") = (u64)(val);                    \
        __asm__ volatile (".word (" STR(word) ") + (10 << 15)"           \
                          :: "r"(rs_) : "memory");                      \
    } while (0)

/* A clean+invalidate of the whole D-cache. Issued before anything that
 * invalidates without writing back (th.dcache.iall / isw / iva / ipa, MCOR
 * bit 4) so that losing those lines cannot corrupt our own stack or globals. */
#define DCACHE_SAFE_POINT() TH_OP(TH_DCACHE_CIALL)

/* ==================================================================== *
 * State
 * ==================================================================== */
/* Groups 0..NGROUPS-1 are the main rotation; NGROUPS..NGROUPS_TOTAL-1 ride the
 * sparse second selector (and are individually reachable via CP0_ONLY_GROUP). */
#define NGROUPS       32
#define NGROUPS_TOTAL 42

static volatile u64 rng_state;
static volatile u64 iter;
static volatile u64 group_hits[NGROUPS_TOTAL];
static volatile u64 sink;          /* keeps CSR reads from being optimised away */
static volatile u64 recovered;     /* iterations abandoned via longjmp         */

/* Somewhere safe to aim loads, stores and cache-maintenance addresses at:
 * inside our own .bss, i.e. inside the SRAM window the testbench loads. */
static volatile u64 scratch_mem[64];

static u64 rnd(void)
{
    u64 x = rng_state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    rng_state = x;
    return x;
}

/* ==================================================================== *
 * Baseline state
 * ==================================================================== */
static void restore_sane_state(void)
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
    CSR_W(CSR_MTVEC, (u64)(unsigned long)&cp0_trap_m);
    CSR_W(CSR_STVEC, (u64)(unsigned long)&cp0_trap_s);

    /* T-Head control plane back to the crt0.s baseline. Note MXSTATUS resets
     * with THEADISAEE / MAEE / CLINTEE / UCME / MM all set. */
    CSR_W(CSR_MXSTATUS, MXSTATUS_RESET);
    CSR_W(CSR_MHCR,  MHCR_ALL_ON);
    CSR_W(CSR_MHINT, MHINT_BASE);
    CSR_W(CSR_MHINT2, 0);

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

/* PMP entry 0 spanning everything, permissive. Without it, S and U mode would
 * be denied every access (no matching PMP entry => deny for S/U), so the
 * privilege-mode groups could not run at all. Entry 0 has the highest
 * priority, so whatever the PMP group writes to entries 1..15 is harmless. */
static void pmp_open_everything(void)
{
    CSR_W(CSR_PMPADDR0, ~0UL);      /* NAPOT covering the whole space */
    CSR_W(CSR_PMPCFG0, 0x1FUL);     /* entry 0: A=NAPOT, X|W|R        */
}

/* ==================================================================== *
 * Group 1-9: CSR-file mechanics
 * ==================================================================== */
static void g_safe_rw(u64 r)
{
    switch ((r >> 8) % 18u) {
    case 0:  PROBE_RW(CSR_MSCRATCH, ~0UL, r);              break;
    case 1:  PROBE_RW(CSR_SSCRATCH, ~0UL, r);              break;
    case 2:  PROBE_RW(CSR_MTVAL,    ~0UL, r);              break;
    case 3:  PROBE_RW(CSR_STVAL,    ~0UL, r);              break;
    case 4:  PROBE_RW(CSR_MCAUSE,   ~0UL, r);              break;
    case 5:  PROBE_RW(CSR_SCAUSE,   ~0UL, r);              break;
    case 6:  PROBE_RW(CSR_MEPC,     ~1UL, r);              break;
    case 7:  PROBE_RW(CSR_SEPC,     ~1UL, r);              break;
    case 8:  PROBE_RW(CSR_MSTATUS,  MSTATUS_WMASK & ~MSTATUS_MIE, r); break;
    case 9:  PROBE_RW(CSR_SSTATUS,  SSTATUS_WMASK, r);     break;
    case 10: PROBE_RW(CSR_MIE,      MIE_WMASK, r);         break;
    case 11: PROBE_RW(CSR_SIE,      MIE_WMASK, r);         break;
    case 12: PROBE_RW(CSR_MEDELEG,  MEDELEG_SAFE, r);      break;
    case 13: PROBE_RW(CSR_MIDELEG,  MIDELEG_WMASK, r);     break;
    case 14: PROBE_RW(CSR_MCNTEN,   ~0UL, r);              break;
    case 15: PROBE_RW(CSR_SCNTEN,   ~0UL, r);              break;
    case 16: PROBE_RW(CSR_MCONTEXT, ~0UL, r);              break;
    default: PROBE_RW(CSR_SCONTEXT, ~0UL, r);              break;
    }
    /* Restore the two CSRs whose masks above cannot express "unchanged". */
    CSR_W(CSR_MEDELEG, 0);
    CSR_W(CSR_MIDELEG, 0);
}

static void g_imm_forms(u64 r)
{
    switch ((r >> 8) & 7u) {
    case 0: PROBE_IMM(CSR_MSCRATCH, r >> 3); break;
    case 1: PROBE_IMM(CSR_SSCRATCH, r >> 3); break;
    case 2: PROBE_IMM(CSR_MTVAL,    r >> 3); break;
    case 3: PROBE_IMM(CSR_STVAL,    r >> 3); break;
    case 4: PROBE_IMM(CSR_MCAUSE,   r >> 3); break;
    case 5: PROBE_IMM(CSR_SCAUSE,   r >> 3); break;
    case 6: PROBE_IMM(CSR_MCNTEN,   r >> 3); break;
    default:PROBE_IMM(CSR_SCNTEN,   r >> 3); break;
    }
}

/* csrrs/csrrc with rs1 == x0 write nothing, so they must not trap even on a
 * read-only CSR (aq_cp0_iui.v:455, 463-465). */
static void g_no_write_forms(u64 r)
{
    switch ((r >> 8) & 7u) {
    case 0: sink += CSR_RS(CSR_MVENDORID, 0); break;
    case 1: sink += CSR_RS(CSR_MISA, 0);      break;
    case 2: sink += CSR_RC(CSR_MHARTID, 0);   break;
    case 3: sink += CSR_RSI(CSR_MARCHID, 0);  break;
    case 4: sink += CSR_RCI(CSR_MIMPID, 0);   break;
    case 5: sink += CSR_RS(CSR_MRVBR, 0);     break;
    case 6: sink += CSR_RS(CSR_MAPBADDR, 0);  break;
    default:sink += CSR_RC(CSR_TINFO, 0);     break;
    }
}

/* Reads are legal; the writes must all raise cause 2 (imm[11:10]==2'b11, or
 * TINFO's regs_iui_trigger_mro). */
static void g_read_only(u64 r)
{
    switch ((r >> 8) % 10u) {
    case 0: PROBE_RO(CSR_MVENDORID); PROBE_RO_WRITE(CSR_MVENDORID, r); break;
    case 1: PROBE_RO(CSR_MARCHID);   PROBE_RO_WRITE(CSR_MARCHID, r);   break;
    case 2: PROBE_RO(CSR_MIMPID);    PROBE_RO_WRITE(CSR_MIMPID, r);    break;
    case 3: PROBE_RO(CSR_MHARTID);   PROBE_RO_WRITE(CSR_MHARTID, r);   break;
    case 4: PROBE_RO(CSR_MISA);      PROBE_RO_WRITE(CSR_MISA, r);      break;
    case 5: PROBE_RO(CSR_TINFO);     PROBE_RO_WRITE(CSR_TINFO, r);     break;
    case 6: PROBE_RO(CSR_MHALTCAUSE);PROBE_RO_WRITE(CSR_MHALTCAUSE, r);break;
    case 7: PROBE_RO(CSR_MDBGINFO);  PROBE_RO_WRITE(CSR_MDBGINFO, r);  break;
    case 8: PROBE_RO(CSR_MPCFIFO);   PROBE_RO_WRITE(CSR_MPCFIFO, r);   break;
    default:PROBE_RO(CSR_CYCLE);     PROBE_RO_WRITE(CSR_CYCLE, r);     break;
    }
}

/* Extension CSRs that decode legal but have no write enable at all: the write
 * is silently dropped and the read returns 0 (or a pin value). No trap. */
static void g_ro_zero(u64 r)
{
    switch ((r >> 8) % 14u) {
    case 0:  PROBE_RO(CSR_MCCR2);  CSR_W(CSR_MCCR2, r);  break;
    case 1:  PROBE_RO(CSR_MCER2);  CSR_W(CSR_MCER2, r);  break;
    case 2:  PROBE_RO(CSR_MCER);   CSR_W(CSR_MCER, r);   break;
    case 3:  PROBE_RO(CSR_MRMR);   CSR_W(CSR_MRMR, r);   break;
    case 4:  PROBE_RO(CSR_MRVBR);  CSR_W(CSR_MRVBR, r);  break;
    case 5:  PROBE_RO(CSR_MHINT3); CSR_W(CSR_MHINT3, r); break;
    case 6:  PROBE_RO(CSR_MHINT4); CSR_W(CSR_MHINT4, r); break;
    case 7:  PROBE_RO(CSR_MEICR);  CSR_W(CSR_MEICR, r);  break;
    case 8:  PROBE_RO(CSR_MEICR2); CSR_W(CSR_MEICR2, r); break;
    case 9:  PROBE_RO(CSR_SHCR);   CSR_W(CSR_SHCR, r);   break;
    case 10: PROBE_RO(CSR_SHINT);  CSR_W(CSR_SHINT, r);  break;
    case 11: PROBE_RO(CSR_SHINT2); CSR_W(CSR_SHINT2, r); break;
    case 12: PROBE_RO(CSR_SCER);   CSR_W(CSR_SCER, r);   break;
    default: PROBE_RO(CSR_SCER2);  CSR_W(CSR_SCER2, r);  break;
    }
}

/* Addresses that fall through to `default: regs_imm_inv = 1'b1`
 * (aq_cp0_regs.v:1189). Every one of these must raise cause 2. */
static void g_trap_illegal(u64 r)
{
    switch ((r >> 8) % 12u) {
    case 0:  sink += CSR_R(0x000); break;
    case 1:  sink += CSR_R(0x3A1); break;   /* pmpcfg1: not decoded */
    case 2:  sink += CSR_R(0x3A3); break;   /* pmpcfg3: not decoded */
    case 3:  sink += CSR_R(0xB01); break;   /* no mcycleh here      */
    case 4:  sink += CSR_R(0x5E1); break;   /* no stime             */
    case 5:  sink += CSR_R(0x7B4); break;
    case 6:  sink += CSR_R(0x101); break;
    case 7:  sink += CSR_R(0x181); break;
    case 8:  sink += CSR_R(0x321); break;
    case 9:  sink += CSR_R(0x7A6); break;
    case 10: sink += CSR_R(0x900); break;
    default: sink += CSR_R(0xF15); break;
    }
}

/* All six vector CSRs are in the parameter table and the read mux but in
 * neither illegal-decode case, so they always trap (audit §12). vsetvli is
 * likewise always illegal -- the whole vector path is gutted. */
static void g_vector_illegal(u64 r)
{
    switch ((r >> 8) % 7u) {
    case 0: sink += CSR_R(CSR_VSTART); break;
    case 1: sink += CSR_R(CSR_VXSAT);  break;
    case 2: sink += CSR_R(CSR_VXRM);   break;
    case 3: sink += CSR_R(CSR_VL);     break;
    case 4: sink += CSR_R(CSR_VTYPE);  break;
    case 5: sink += CSR_R(CSR_VLENB);  break;
    default: TH_OP(INSN_VSETVLI);      break;
    }
}

/* Unimplemented addresses inside the eight declared extension windows. The
 * stage-2 decode ends in `default: regs_ext_imm_inv = 1'b0` (:1308), so these
 * are LEGAL and read 0 -- they must not trap. The most easily mis-modelled
 * corner of the whole CSR map. */
static void g_legal_hole(u64 r)
{
    switch ((r >> 8) % 10u) {
    case 0: sink += CSR_R(0x7CF); break;    /* 0x7C0-0x7FF window */
    case 1: sink += CSR_R(0x7D8); break;
    case 2: sink += CSR_R(0x7F5); break;
    case 3: sink += CSR_R(0xBC4); break;    /* whole 0xBCx window unimplemented */
    case 4: sink += CSR_R(0x5CE); break;    /* 0x5C0-0x5FF window */
    case 5: sink += CSR_R(0x5D4); break;
    case 6: sink += CSR_R(0x9C8); break;    /* 0x9C4-0x9FF        */
    case 7: sink += CSR_R(0x844); break;    /* 0x801-0x8FF, U-accessible */
    case 8: sink += CSR_R(0xCC4); break;    /* 0xCCx, read-only encoding */
    default:sink += CSR_R(0xDC4); break;    /* 0xDCx, read-only encoding */
    }
}

/* mcpuid_local_en is a bare address compare with no write qualifier, and the
 * 3-bit index advances on every read, so N reads return N different words
 * (aq_cp0_info_csr.v:167-172). An illegal *write* attempt must not advance it,
 * because iui_regs_csr_en is qualified by !iui_csr_expt_vld (:775). */
static void g_mcpuid_walk(u64 r)
{
    unsigned n = (unsigned)((r >> 8) & 7u) + 1u;
    while (n--)
        sink += CSR_R(CSR_MCPUID);
    PROBE_RO_WRITE(CSR_MCPUID, r);
    sink += CSR_R(CSR_MCPUID);
}

/* MIP/SIP read-modify-write reads sip_raw, not the value a plain read returns
 * (aq_cp0_regs.v:1840-1849) -- two distinct read buses. */
static void g_mip_rmw(u64 r)
{
    u64 keep = CSR_R(CSR_MIP);
    (void)CSR_RS(CSR_MIP, r & MIP_SW_MASK);
    (void)CSR_RC(CSR_MIP, r & MIP_SW_MASK);
    (void)CSR_RS(CSR_SIP, r & IRQ_SSIP);
    (void)CSR_RC(CSR_SIP, r & IRQ_SSIP);
    CSR_C(CSR_MIP, MIP_SW_MASK);
    sink += keep;
}

/* ==================================================================== *
 * Group 10-16: extension CSRs and the core-wide enable broadcast
 * ==================================================================== */
/* MHCR drives the I$/D$/BTB/BHT/RAS enables. Clearing DE with dirty lines
 * present would let us read stale globals afterwards, so clean first. */
static void g_mhcr(u64 r)
{
    u64 v = r & MHCR_WMASK;
    if (!(v & MHCR_DE))
        DCACHE_SAFE_POINT();
    CSR_W(CSR_MHCR, v);
    (void)CSR_RS(CSR_MHCR, MHCR_BTBE | MHCR_BPE | MHCR_RSE);
    (void)CSR_RC(CSR_MHCR, MHCR_BTBE);
    sink += CSR_R(CSR_SHCR);           /* read-only S-mode mirror */
    CSR_W(CSR_MHCR, MHCR_ALL_ON);
}

/* Prefetch enables and distance, I$ way predict, the LSU store-stream
 * threshold (amr), and the debug PC-FIFO freeze. */
static void g_mhint(u64 r)
{
    PROBE_RW(CSR_MHINT, MHINT_WMASK, r);
    CSR_W(CSR_MHINT, r & MHINT_WMASK);
    CSR_W(CSR_MHINT, MHINT_BASE);
}

/* MHINT2[22:14] is the nine-bit module_icg_en vector that becomes eleven
 * per-unit clock-gate enables. Bit 16 gates IU, HPCP *and* CP0's own
 * regs_clk / regs_flush_clk / special_clk, so this is the single most
 * disruptive legal write in the map. */
static void g_mhint2(u64 r)
{
    CSR_W(CSR_MHINT2, r & MHINT2_WMASK);
    (void)CSR_RS(CSR_MHINT2, MHINT2_ICG_EN);
    (void)CSR_RC(CSR_MHINT2, r & MHINT2_ICG_EN);
    CSR_W(CSR_MHINT2, MHINT2_FENCE_DBG);
    CSR_W(CSR_MHINT2, 0);
}

static void g_mxstatus(u64 r)
{
    u64 v = (r & MXSTATUS_WMASK) | MXSTATUS_THEADISAEE;
    /* MHRD disables the hardware page-table walker; only ever safe while
     * translation is off, which it is (satp is Bare outside g_satp). */
    CSR_W(CSR_MXSTATUS, v);
    sink += CSR_R(CSR_MXSTATUS);       /* bits 31:30 mirror the live mode */
    /* Misaligned support off, then a deliberately misaligned access. */
    CSR_C(CSR_MXSTATUS, MXSTATUS_MM);
    {
        volatile unsigned int *p =
            (volatile unsigned int *)((unsigned long)&scratch_mem[1] | 1UL);
        sink += *p;                    /* cause 4 with MM clear */
    }
    CSR_W(CSR_MXSTATUS, MXSTATUS_RESET);
}

/* Clearing THEADISAEE makes every th.* opcode illegal in the IDU
 * (aq_idu_id_decd.v:1005) -- a decode path nothing else in the repo covers. */
static void g_theadisaee_off(u64 r)
{
    CSR_C(CSR_MXSTATUS, MXSTATUS_THEADISAEE);
    switch ((r >> 8) & 3u) {
    case 0:  TH_OP(TH_SYNC);          break;
    case 1:  TH_OP(TH_DCACHE_CALL);   break;
    case 2:  TH_OP(TH_ICACHE_IALL);   break;
    default: TH_OP(TH_L2CACHE_IALL);  break;
    }
    CSR_S(CSR_MXSTATUS, MXSTATUS_THEADISAEE);
}

/* SXSTATUS writes reach only mm / pmds / pmdu; everything else must read back
 * unchanged (aq_cp0_ext_csr.v:564-569). */
static void g_sxstatus(u64 r)
{
    CSR_W(CSR_SXSTATUS, r);
    sink += CSR_R(CSR_SXSTATUS);
    CSR_W(CSR_MXSTATUS, MXSTATUS_RESET);
}

/* MCOR: cache/BTB/BHT maintenance. Bit 4 drives both icache_inv and
 * dcache_inv, and sel[1:0] is a persistent register, so the op and its sel go
 * in the same write. Invalidate-without-writeback needs a clean first. */
static void g_mcor(u64 r)
{
    u64 sel = (r >> 8) & 3u;
    switch ((r >> 10) & 3u) {
    case 0:
        CSR_W(CSR_MCOR, MCOR_BTB_INV | sel);   /* 1-cycle fire and forget */
        break;
    case 1:
        CSR_W(CSR_MCOR, MCOR_BHT_INV | sel);
        break;
    case 2:
        CSR_W(CSR_MCOR, MCOR_CLR | sel);       /* clean, waits on the LSU */
        break;
    default:
        DCACHE_SAFE_POINT();
        CSR_W(CSR_MCOR, MCOR_INV | sel);       /* invalidate, no writeback */
        break;
    }
    sink += CSR_R(CSR_MCOR);
}

/* The MCINS/MCINDEX/MCDATA RAM-inspection window. rid 0/1 read the I-cache
 * tag/data arrays, 2/3 the D-cache, and 4..15 complete immediately with no RAM
 * access at all. MCINS bit 0 is a one-shot that back-pressures EX1 until the
 * read returns; MCINS itself always reads 0. */
static void g_mcins(u64 r)
{
    u64 rid = (r >> 8) & 0xFu;
    u64 way = (r >> 12) & 0x3u;
    u64 idx = (r >> 16) & 0x1FFu;

    CSR_W(CSR_MCINDEX, MCINDEX_RID(rid) | MCINDEX_WAY(way) | MCINDEX_IDX(idx));
    sink += CSR_R(CSR_MCINDEX);
    CSR_W(CSR_MCINS, 1UL);
    sink += CSR_R(CSR_MCDATA0);
    sink += CSR_R(CSR_MCDATA1);
    sink += CSR_R(CSR_MCINS);          /* write-only: must read 0 */
}

/* ==================================================================== *
 * Group 17-20: system instructions, fences, cache maintenance, WFI
 * ==================================================================== */
/* The six cache ops CP0 executes itself, plus the three L2 forms that decode
 * to dst=2'b00 and are silent no-ops in this core. */
static void g_cache_cp0(u64 r)
{
    u64 sw = (r >> 16) & 0x7FFUL;      /* a set/way operand */

    switch ((r >> 8) % 9u) {
    case 0:  TH_OP(TH_DCACHE_CALL);        break;
    case 1:  DCACHE_SAFE_POINT();
             TH_OP(TH_DCACHE_IALL);        break;
    case 2:  TH_OP(TH_DCACHE_CIALL);       break;
    case 3:  TH_OP_RS1(TH_DCACHE_CSW, sw); break;
    case 4:  DCACHE_SAFE_POINT();
             TH_OP_RS1(TH_DCACHE_ISW, sw); break;
    case 5:  TH_OP_RS1(TH_DCACHE_CISW, sw);break;
    case 6:  TH_OP(TH_L2CACHE_CALL);       break;
    case 7:  TH_OP(TH_L2CACHE_IALL);       break;
    default: TH_OP(TH_L2CACHE_CIALL);      break;
    }
}

/* The VA/PA forms. These dispatch to the LSU (or split into two uops) rather
 * than to CP0, but they complete the decode matrix and drive CP0's UCME gate.
 * Addresses stay inside our own .bss so nothing else can be disturbed. */
static void g_cache_va(u64 r)
{
    u64 addr = (u64)(unsigned long)&scratch_mem[(r >> 20) & 0x1Fu];

    switch ((r >> 8) % 10u) {
    case 0:  TH_OP_RS1(TH_DCACHE_CVA,   addr); break;
    case 1:  TH_OP_RS1(TH_DCACHE_CVAL1, addr); break;
    case 2:  TH_OP_RS1(TH_DCACHE_CIVA,  addr); break;
    case 3:  DCACHE_SAFE_POINT();
             TH_OP_RS1(TH_DCACHE_IVA,   addr); break;
    case 4:  TH_OP_RS1(TH_DCACHE_CPA,   addr); break;
    case 5:  TH_OP_RS1(TH_DCACHE_CPAL1, addr); break;
    case 6:  TH_OP_RS1(TH_DCACHE_CIPA,  addr); break;
    case 7:  DCACHE_SAFE_POINT();
             TH_OP_RS1(TH_DCACHE_IPA,   addr); break;
    case 8:  TH_OP_RS1(TH_ICACHE_IVA,   addr); break;
    default: TH_OP_RS1(TH_ICACHE_IPA,   addr); break;
    }
}

/* All six states of the fence FSM: FNC_IDLE / FENC / CDCA / CMMU / IICA /
 * CMPLT. Note plain `fence` never enters the FSM at all -- it is handled
 * purely by the iui_special_fence stall term (aq_cp0_fence_inst.v:111,198) --
 * and sfence.vma always chains CMMU -> IICA, so it invalidates the I-cache
 * too. th.icache.iall/ialls are re-encoded as fence.i. */
static void g_fence(u64 r)
{
    u64 va   = (u64)(unsigned long)&scratch_mem[0];
    u64 asid = (r >> 20) & 0xFFFFu;

    switch ((r >> 8) % 12u) {
    case 0: __asm__ volatile ("fence" ::: "memory");        break;
    case 1: __asm__ volatile ("fence.i" ::: "memory");      break;
    case 2: __asm__ volatile ("sfence.vma" ::: "memory");   break;
    case 3: __asm__ volatile ("sfence.vma %0, zero" :: "r"(va) : "memory"); break;
    case 4: __asm__ volatile ("sfence.vma zero, %0" :: "r"(asid) : "memory"); break;
    case 5: __asm__ volatile ("sfence.vma %0, %1" :: "r"(va), "r"(asid) : "memory"); break;
    case 6: TH_OP(TH_SYNC);          break;
    case 7: TH_OP(TH_SYNC_S);        break;
    case 8: TH_OP(TH_SYNC_I);        break;
    case 9: TH_OP(TH_SYNC_IS);       break;
    case 10:TH_OP(TH_ICACHE_IALL);   break;
    default:TH_OP(TH_ICACHE_IALLS);  break;
    }
}

/* Arm a WFI wake-up that is guaranteed NOT to be taken as a trap first.
 *
 * The wake condition is lpmd_ack_vld = |(mie & mip), which deliberately
 * ignores both privilege mode and delegation (aq_cp0_trap_csr.v:1340,
 * aq_cp0_lpmd.v:190). Delegating STIP while sstatus.SIE is clear therefore
 * leaves a source that wakes WFI but that neither M nor S mode will take:
 *   - stip_nodeleg_vld needs !mideleg[5]  -> false
 *   - stip_deleg_vld   needs (S && SIE) || U -> false in M, false in S with SIE=0
 * That matters because if the interrupt were taken *before* the WFI, the
 * handler would clear the source and the WFI would then never wake -- and a
 * WFI with nothing armed is unrecoverable short of reset, which shows up as
 * the testbench's 50,000-cycle retire watchdog firing.
 *
 * Also exercises exactly the privilege/delegation-blind wake path the CP0
 * audit calls out. */
static void arm_lpmd_wake(void)
{
    CSR_C(CSR_SSTATUS, MSTATUS_SIE);
    CSR_W(CSR_MIDELEG, IRQ_STIP);
    CSR_S(CSR_MIE, IRQ_STIP);
    CSR_S(CSR_MIP, IRQ_STIP);
}

static void disarm_lpmd_wake(void)
{
    CSR_C(CSR_MIP, MIP_SW_MASK);
    CSR_W(CSR_MIE, 0);
    CSR_W(CSR_MIDELEG, 0);
}

/* Two variants. Both wake through the FSM; the second then un-delegates the
 * still-pending source and enables MIE so it is taken as a real trap, giving
 * the interrupt path coverage without ever risking a WFI that cannot wake. */
static void g_wfi(u64 r)
{
    arm_lpmd_wake();
    __asm__ volatile ("wfi");          /* enters LPMD, wakes, falls through */

    if ((r >> 8) & 1u) {
        CSR_W(CSR_MIDELEG, 0);         /* now an M-level, takeable source */
        CSR_S(CSR_MIP, IRQ_STIP);
        CSR_S(CSR_MSTATUS, MSTATUS_MIE);
        CSR_C(CSR_MSTATUS, MSTATUS_MIE);
    }

    disarm_lpmd_wake();
}

/* ==================================================================== *
 * Group 21-25: traps
 * ==================================================================== */
static void g_ecall_ebreak(u64 r)
{
    if ((r >> 8) & 1u)
        __asm__ volatile ("ecall");        /* cause 11 from M mode */
    else
        __asm__ volatile ("ebreak");       /* cause 3              */
}

static void g_illegal(u64 r)
{
    switch ((r >> 8) & 3u) {
    case 0:  TH_OP(INSN_RESERVED);      break;
    case 1:  TH_OP(INSN_HFENCE_VVMA);   break;
    case 2:  TH_OP(INSN_DRET);          break;  /* debug mode only */
    default: sink += CSR_R(CSR_DCSR);   break;  /* illegal outside debug */
    }
}

/* Debug CSRs are illegal unless rtu_yy_xx_dbgon (aq_cp0_regs.v:1144-1147);
 * with no debugger attached that is always. */
static void g_debug_csrs(u64 r)
{
    switch ((r >> 8) % 8u) {
    case 0: sink += CSR_R(CSR_DCSR);      break;
    case 1: sink += CSR_R(CSR_DPC);       break;
    case 2: sink += CSR_R(CSR_DSCRATCH0); break;
    case 3: sink += CSR_R(CSR_DSCRATCH1); break;
    case 4: PROBE_RW(CSR_TSELECT, 0xFUL, r);  break;
    case 5: PROBE_RW(CSR_TDATA2,  ~0UL, r);   break;
    case 6: PROBE_RW(CSR_TDATA3,  ~0UL, r);   break;
    default:PROBE_RW(CSR_TCONTROL, 0x88UL, r);break;
    }
    /* TDATA1 is deliberately left alone: an mcontrol trigger with action != 0
     * enters debug mode, which wedges a bare-metal run with no debugger. */
}

/* Access faults from outside the SRAM window, and misaligned accesses. */
static void g_fault(u64 r)
{
    volatile unsigned long *bad = (volatile unsigned long *)0x30000000UL;

    switch ((r >> 8) & 3u) {
    case 0: sink += *bad;    break;            /* load access fault: precise */
    case 1: /* Store access fault. A store error is reported when the store
             * buffer drains, so it can surface an instruction or two late;
             * the fence pins it inside this group instead of letting it
             * arrive somewhere surprising. */
            *bad = r;
            __asm__ volatile ("fence" ::: "memory");
            break;
    case 2: CSR_C(CSR_MXSTATUS, MXSTATUS_MM);
            sink += *(volatile unsigned long *)
                    ((unsigned long)&scratch_mem[2] | 3UL);
            CSR_S(CSR_MXSTATUS, MXSTATUS_MM);
            break;
    default:CSR_C(CSR_MXSTATUS, MXSTATUS_MM);
            *(volatile unsigned long *)
                ((unsigned long)&scratch_mem[3] | 5UL) = r;
            CSR_S(CSR_MXSTATUS, MXSTATUS_MM);
            break;
    }
}

/* mtvec/stvec: random base and mode, restored immediately with no trapping
 * instruction in between (interrupts are off outside the interrupt groups).
 * The read-back is where mtvec[1] always reading 0 shows up. */
static void g_tvec(u64 r)
{
    u64 base = (r & 0x3FFFFFFCUL);

    CSR_W(CSR_MTVEC, base);
    sink += CSR_R(CSR_MTVEC);
    CSR_W(CSR_MTVEC, base | 3UL);      /* mode 3: reads back as mode 1 */
    sink += CSR_R(CSR_MTVEC);
    CSR_W(CSR_MTVEC, (u64)(unsigned long)&cp0_trap_m);

    CSR_W(CSR_STVEC, base | 2UL);      /* mode 2: reads back as mode 0 */
    sink += CSR_R(CSR_STVEC);
    CSR_W(CSR_STVEC, (u64)(unsigned long)&cp0_trap_s);
}

/* Vectored trap mode: cause N is dispatched to base + 4*N, so mtvec points at
 * a table of jumps. Take a real interrupt through it. */
static void g_vectored(u64 r)
{
    (void)r;
    CSR_W(CSR_MTVEC, (u64)(unsigned long)&cp0_trap_m_vectored | TVEC_MODE_VECTORED);
    CSR_S(CSR_MIE, IRQ_STIP);
    CSR_S(CSR_MSTATUS, MSTATUS_MIE);
    CSR_S(CSR_MIP, IRQ_STIP);          /* taken here */
    CSR_C(CSR_MSTATUS, MSTATUS_MIE);
    CSR_C(CSR_MIP, IRQ_STIP);
    CSR_W(CSR_MIE, 0);
    CSR_W(CSR_MTVEC, (u64)(unsigned long)&cp0_trap_m);
}

/* ==================================================================== *
 * Group 26-28: privilege modes and delegation
 * ==================================================================== */
/* Bodies run in S or U mode. Each ends with ECALL, which the M handler turns
 * into a return to the caller of cp0_run_in_*mode. medeleg[8]/[9] are kept
 * clear so that ecall is never delegated away from M. */
static volatile u64 lower_sel;

static void smode_body(void)
{
    switch (lower_sel % 8u) {
    case 0: sink += CSR_R(CSR_SSTATUS);  break;  /* legal in S               */
    case 1: sink += CSR_R(CSR_MSTATUS);  break;  /* M window: illegal from S */
    case 2: sink += CSR_R(CSR_SCONTEXT); break;  /* exempted, legal in S     */
    case 3: sink += CSR_R(CSR_SATP);     break;  /* illegal iff TVM          */
    case 4: __asm__ volatile ("sret");                    break; /* illegal iff TSR */
    case 5: __asm__ volatile ("wfi");                     break; /* illegal iff TW  */
    case 6: __asm__ volatile ("sfence.vma" ::: "memory"); break; /* illegal iff TVM */
    default:__asm__ volatile ("mret");                    break; /* always illegal from S */
    }
    __asm__ volatile ("ecall");
}

static void umode_body(void)
{
    switch (lower_sel % 8u) {
    case 0: sink += CSR_R(CSR_CYCLE);   break;  /* gated by mcounteren      */
    case 1: sink += CSR_R(CSR_TIME);    break;  /* gated by mcounteren      */
    case 2: sink += CSR_R(CSR_FXCR);    break;  /* U-mode extension window  */
    case 3: sink += CSR_R(CSR_MSTATUS); break;  /* illegal from U           */
    case 4: sink += CSR_R(CSR_SSTATUS); break;  /* illegal from U           */
    case 5: __asm__ volatile ("wfi");                     break; /* always illegal from U */
    case 6: __asm__ volatile ("sfence.vma" ::: "memory"); break; /* always illegal from U */
    default: TH_OP_RS1(TH_DCACHE_CVA, &scratch_mem[0]);   break; /* legal iff UCME  */
    }
    __asm__ volatile ("ecall");
}

static void g_smode(u64 r)
{
    lower_sel = (r >> 8) & 7u;

    /* Two of the eight bodies are legal in S mode when their gate bit is
     * clear, and both need preparation the S-mode code cannot do itself:
     *   case 4, sret -- jumps to sepc, so sepc must point somewhere real;
     *                   SPP=1 keeps us in S so the landing pad's ecall works.
     *   case 5, wfi  -- needs a wake armed, and mie/mideleg are M-only. */
    CSR_W(CSR_SEPC, (u64)(unsigned long)&cp0_sret_land);
    CSR_S(CSR_SSTATUS, MSTATUS_SPP);
    /* SPIE clear, so the sret in case 4 does not pop SIE back to 1 and expose
     * the WFI wake source (a delegated STIP) as a takeable S-mode interrupt. */
    CSR_C(CSR_SSTATUS, MSTATUS_SPIE);
    arm_lpmd_wake();

    /* Randomise the trap-and-emulate gates so the same body sometimes traps
     * and sometimes does not (aq_cp0_iui.v:574-585). */
    CSR_C(CSR_MSTATUS, MSTATUS_TSR | MSTATUS_TW | MSTATUS_TVM);
    CSR_S(CSR_MSTATUS, r & (MSTATUS_TSR | MSTATUS_TW | MSTATUS_TVM));

    cp0_run_in_smode(smode_body);

    CSR_C(CSR_MSTATUS, MSTATUS_TSR | MSTATUS_TW | MSTATUS_TVM);
    disarm_lpmd_wake();
}

static void g_umode(u64 r)
{
    lower_sel = (r >> 8) & 7u;
    /* UCME gates U-mode cache maintenance; mcounteren gates the counters. */
    if ((r >> 12) & 1u) CSR_C(CSR_MXSTATUS, MXSTATUS_UCME);
    else                CSR_S(CSR_MXSTATUS, MXSTATUS_UCME);
    if ((r >> 13) & 1u) CSR_W(CSR_MCNTEN, 0);
    else                CSR_W(CSR_MCNTEN, ~0UL);
    cp0_run_in_umode(umode_body);
    CSR_S(CSR_MXSTATUS, MXSTATUS_UCME);
    CSR_W(CSR_MCNTEN, ~0UL);
}

/* Delegate a batch of exception causes to S mode, then trap from S so the
 * trap lands in cp0_trap_s instead of cp0_trap_m. Causes 8/9 stay
 * undelegated: they are the way back to M. */
static void g_delegate(u64 r)
{
    CSR_W(CSR_MEDELEG, r & MEDELEG_SAFE);
    CSR_W(CSR_MIDELEG, r & MIDELEG_WMASK);
    lower_sel = 7u;                    /* mret from S: always illegal, cause 2 */
    cp0_run_in_smode(smode_body);
    CSR_W(CSR_MEDELEG, 0);
    CSR_W(CSR_MIDELEG, 0);
}

/* ==================================================================== *
 * Group 29-31: interrupts
 * ==================================================================== */
/* The three software-writable pending bits, taken in M mode. */
static void g_int_soft(u64 r)
{
    u64 bit = ((r >> 8) & 1u) ? IRQ_STIP : (((r >> 9) & 1u) ? IRQ_SSIP : IRQ_SEIP);

    /* CLINTEE gates the CLINT-sourced S timer and S software inputs; the
     * software-written mip bits come through regardless. */
    if ((r >> 10) & 1u) CSR_C(CSR_MXSTATUS, MXSTATUS_CLINTEE);

    CSR_S(CSR_MIE, bit);
    CSR_S(CSR_MSTATUS, MSTATUS_MIE);
    CSR_S(CSR_MIP, bit);               /* taken here; handler clears it */
    CSR_C(CSR_MSTATUS, MSTATUS_MIE);
    CSR_C(CSR_MIP, MIP_SW_MASK);
    CSR_W(CSR_MIE, 0);
    CSR_S(CSR_MXSTATUS, MXSTATUS_CLINTEE);
}

/* Delegated to S mode, so it arrives through sie/sip and cp0_trap_s.
 * sie[5] reads mie[5] masked by mideleg[5], so mideleg must be set first, and
 * sstatus.SIE has to be on for S mode to actually take it -- mret does not
 * set SIE, it only pops MIE. */
static void g_int_deleg(u64 r)
{
    (void)r;
    CSR_W(CSR_MEDELEG, 0);
    CSR_W(CSR_MIDELEG, IRQ_STIP);
    CSR_S(CSR_MIE, IRQ_STIP);
    CSR_S(CSR_SSTATUS, MSTATUS_SIE);
    CSR_S(CSR_MIP, IRQ_STIP);
    lower_sel = 0u;
    cp0_run_in_smode(smode_body);      /* taken to stvec on entry to S */
    CSR_C(CSR_SSTATUS, MSTATUS_SIE);
    CSR_C(CSR_MIP, MIP_SW_MASK);
    CSR_W(CSR_MIE, 0);
    CSR_W(CSR_MIDELEG, 0);
}

/* The external sources, which have no software-writable mip bit at all
 * (aq_cp0_trap_csr.v:1234-1236) -- they can only be driven from the CLINT and
 * the PLIC. All of these registers need 32-bit accesses and M mode. */
/* Wait (bounded) for an externally-sourced interrupt to appear in mip.
 * A CLINT or PLIC write has to reach the peripheral and come back through two
 * synchroniser flops, so enabling and immediately disabling mstatus.MIE around
 * the store never takes the interrupt -- the source arrives after MIE is
 * already clear again. Polling mip first makes it deterministic. */
static void wait_mip(u64 bit)
{
    unsigned i;

    for (i = 0; i < 500u; i++)
        if (CSR_R(CSR_MIP) & bit)
            return;
}

/* The PLIC's S-mode context, which drives biu_cp0_se_int. Deliberately run with
 * mstatus.MIE clear so the interrupt is observed via mip but never taken: the M
 * handler can clear seip_reg but has no way to retract a PLIC-sourced seip, so
 * taking it would re-trap forever. Accessing the S context from M mode is
 * allowed because the PLIC's permission check passes on pprot[1]. */
static void plic_s_source_pulse(void)
{
    const unsigned id = PLIC_SW_SOURCE;

    *(volatile unsigned int *)PLIC_STH_H0 = 31u;             /* masked */
    *(volatile unsigned int *)(PLIC_PRIO + 4u * id) = 9u;
    *(volatile unsigned int *)PLIC_SIE_H0 = 1u << id;
    *(volatile unsigned int *)PLIC_PENDING = 1u << id;
    *(volatile unsigned int *)PLIC_STH_H0 = 0u;              /* seip asserts */

    sink += CSR_R(CSR_MIP);                                  /* observe it */

    *(volatile unsigned int *)PLIC_STH_H0 = 31u;
    *(volatile unsigned int *)PLIC_SIE_H0 = 0u;
    *(volatile unsigned int *)PLIC_PENDING = 0u;             /* 0 clears */
    *(volatile unsigned int *)(PLIC_PRIO + 4u * id) = 0u;
}

static void g_int_external(u64 r)
{
    switch ((r >> 8) % 6u) {
    case 0:     /* machine software interrupt via CLINT MSIP */
        CSR_S(CSR_MIE, IRQ_MSIP);
        *(volatile unsigned int *)CLINT_MSIP0 = 1u;
        wait_mip(IRQ_MSIP);
        CSR_S(CSR_MSTATUS, MSTATUS_MIE);   /* taken here; handler clears MSIP */
        CSR_C(CSR_MSTATUS, MSTATUS_MIE);
        *(volatile unsigned int *)CLINT_MSIP0 = 0u;
        break;

    case 1: {   /* machine timer interrupt: mtip asserts when cmp <= mtime */
        unsigned int now = (unsigned int)CSR_R(CSR_TIME);
        *(volatile unsigned int *)CLINT_MTIMECMPH = 0u;
        *(volatile unsigned int *)CLINT_MTIMECMPL = now + 400u;
        CSR_S(CSR_MIE, IRQ_MTIP);
        CSR_S(CSR_MSTATUS, MSTATUS_MIE);
        /* Spin well inside the testbench's 50,000-cycle retire watchdog. */
        while (CSR_R(CSR_TIME) < (u64)(now + 500u))
            ;
        CSR_C(CSR_MSTATUS, MSTATUS_MIE);
        *(volatile unsigned int *)CLINT_MTIMECMPH = 0xFFFFFFFFu;
        break;
    }

    case 2: {   /* machine external interrupt via the PLIC */
        const unsigned id = PLIC_SW_SOURCE;
        *(volatile unsigned int *)PLIC_MTH_H0 = 31u;          /* mask first  */
        *(volatile unsigned int *)(PLIC_PRIO + 4u * id) = 10u;/* prio != 0   */
        *(volatile unsigned int *)PLIC_PENDING = 1u << id;    /* set pending */
        *(volatile unsigned int *)PLIC_MIE_H0  = 1u << id;
        CSR_S(CSR_MIE, IRQ_MEIP);
        *(volatile unsigned int *)PLIC_MTH_H0 = 0u;           /* unmask      */
        wait_mip(IRQ_MEIP);
        CSR_S(CSR_MSTATUS, MSTATUS_MIE);   /* taken; handler claims+completes */
        CSR_C(CSR_MSTATUS, MSTATUS_MIE);
        *(volatile unsigned int *)PLIC_MTH_H0 = 31u;
        *(volatile unsigned int *)PLIC_MIE_H0 = 0u;
        break;
    }

    case 3:     /* S-mode software interrupt from the CLINT, i.e. via
                 * biu_cp0_ss_int rather than the mip-owned ssip_reg. Only
                 * reaches mip when MXSTATUS.CLINTEE is set. */
        CSR_S(CSR_MXSTATUS, MXSTATUS_CLINTEE);
        CSR_S(CSR_MIE, IRQ_SSIP);
        CSR_S(CSR_MSTATUS, MSTATUS_MIE);
        *(volatile unsigned int *)CLINT_SSIP0 = 1u;
        CSR_C(CSR_MSTATUS, MSTATUS_MIE);
        *(volatile unsigned int *)CLINT_SSIP0 = 0u;
        break;

    case 4: {   /* S-mode timer interrupt from the CLINT (biu_cp0_st_int) */
        unsigned int now = (unsigned int)CSR_R(CSR_TIME);
        CSR_S(CSR_MXSTATUS, MXSTATUS_CLINTEE);
        *(volatile unsigned int *)CLINT_STIMECMPH = 0u;
        *(volatile unsigned int *)CLINT_STIMECMPL = now + 400u;
        CSR_S(CSR_MIE, IRQ_STIP);
        CSR_S(CSR_MSTATUS, MSTATUS_MIE);
        while (CSR_R(CSR_TIME) < (u64)(now + 500u))
            ;
        CSR_C(CSR_MSTATUS, MSTATUS_MIE);
        *(volatile unsigned int *)CLINT_STIMECMPH = 0xFFFFFFFFu;
        break;
    }

    default:    /* PLIC S context -> biu_cp0_se_int, observed but not taken */
        plic_s_source_pulse();
        break;
    }
    CSR_W(CSR_MIE, 0);
    CSR_C(CSR_MIP, MIP_SW_MASK);
}

/* Cause 17, MOIP: the one live T-Head local interrupt, fed from
 * hpcp_cp0_int_vld = |(mcntinten & mcntof). Causes 16 and 18 are tied off. */
static void g_int_hpm(u64 r)
{
    u64 sel = 1UL << (3u + ((r >> 8) % 5u));   /* one of the HPM counters */

    CSR_W(CSR_MCNTOF, sel);
    CSR_W(CSR_MCNTINTEN, sel);
    CSR_S(CSR_MIE, IRQ_MOIP);
    CSR_S(CSR_MSTATUS, MSTATUS_MIE);           /* taken here */
    CSR_C(CSR_MSTATUS, MSTATUS_MIE);
    CSR_W(CSR_MCNTINTEN, 0);
    CSR_W(CSR_MCNTOF, 0);
    CSR_W(CSR_MIE, 0);
}

/* ==================================================================== *
 * Group 32-37: externally-implemented CSR groups
 * ==================================================================== */
/* Counters and event selectors live in the HPCP; CP0 broadcasts the write and
 * muxes hpcp_cp0_data back into its read path. */
static void g_hpcp(u64 r)
{
    switch ((r >> 8) % 12u) {
    case 0:  PROBE_RW(CSR_MCYCLE,   ~0UL, r); break;
    case 1:  PROBE_RW(CSR_MINSTRET, ~0UL, r); break;
    case 2:  PROBE_RW(0xB03, ~0UL, r);        break;  /* mhpmcnt3  */
    case 3:  PROBE_RW(0xB1F, ~0UL, r);        break;  /* mhpmcnt31 */
    case 4:  PROBE_RW(0x323, ~0UL, r);        break;  /* mhpmevt3  */
    case 5:  PROBE_RW(0x33F, ~0UL, r);        break;  /* mhpmevt31 */
    case 6:  PROBE_RW(CSR_MCNTIHBT, ~0UL, r); break;
    case 7:  PROBE_RW(CSR_MHPMCR, ~0UL, r);   break;
    case 8:  PROBE_RW(CSR_MHPMSP, ~0UL, r);   break;
    case 9:  PROBE_RW(CSR_MHPMEP, ~0UL, r);   break;
    case 10: PROBE_RO(CSR_CYCLE); PROBE_RO(CSR_TIME); PROBE_RO(CSR_INSTRET);
             sink += CSR_R(0xC03);            break;  /* hpmcnt3   */
    default: PROBE_RW(CSR_SCYCLE, ~0UL, r);
             PROBE_RW(CSR_SINSTRET, ~0UL, r); break;
    }
    /* MHPMCR aliases into MXSTATUS pmdm/pmds/pmdu, so re-baseline. */
    CSR_W(CSR_MXSTATUS, MXSTATUS_RESET);
    CSR_W(CSR_MCNTIHBT, 0);
}

/* The counter *access policy* is what CP0 keeps for the HPCP group:
 * mcounteren / scounteren / mcountwen feed regs_ucnt_inv / regs_scnt_inv.
 * mcountwen bit 1 (the time slot) is forced to zero in the RTL, so S mode can
 * never be granted write permission to the time counter. */
static void g_cnt_policy(u64 r)
{
    CSR_W(CSR_MCNTEN, r);
    CSR_W(CSR_SCNTEN, r >> 8);
    CSR_W(CSR_MCNTWEN, r >> 16);
    sink += CSR_R(CSR_MCNTWEN);        /* bit 1 must read back 0 */
    lower_sel = (r >> 24) & 1u;        /* a U-mode counter read  */
    cp0_run_in_umode(umode_body);
    CSR_W(CSR_MCNTEN, ~0UL);
    CSR_W(CSR_SCNTEN, ~0UL);
    CSR_W(CSR_MCNTWEN, 0);
}

/* PMP. Entry 0 is left alone -- it is the permissive entry that lets S and U
 * mode run at all, and being highest priority it makes entries 1..15
 * harmless whatever we write. PMPCFG1/3 are not decoded and must trap. */
static void g_pmp(u64 r)
{
    switch ((r >> 8) % 6u) {
    case 0: PROBE_RW(0x3B1, ~0UL, r); break;   /* pmpaddr1  */
    case 1: PROBE_RW(0x3B7, ~0UL, r); break;   /* pmpaddr7  */
    case 2: PROBE_RW(0x3BF, ~0UL, r); break;   /* pmpaddr15 */
    case 3: PROBE_RW(CSR_PMPCFG2, ~0UL, r); break;
    case 4: sink += CSR_R(0x3A1);     break;   /* not decoded -> cause 2 */
    default:sink += CSR_R(0x3A3);     break;   /* not decoded -> cause 2 */
    }
    /* Never leave a restrictive cfg behind. */
    pmp_open_everything();
}

/* The jTLB access window, implemented in the MMU. SMCIR's op field is
 * decoded invall > invasid > tlbp > tlbwi > tlbwr > tlbr, and the write
 * stalls the CSR pipe until mmu_cp0_cmplt returns; a write with none of bits
 * 31:26 set completes immediately through mcir_no_op. Safe to do at all
 * because satp stays Bare, so no jTLB entry we clobber is in use. */
static void g_mmu_tlb(u64 r)
{
    CSR_W(CSR_SMEH, r & 0x3FFFFFFFFFFFFUL);
    CSR_W(CSR_SMEL, r >> 3);
    sink += CSR_R(CSR_SMEH);
    sink += CSR_R(CSR_SMEL);
    CSR_W(CSR_SMIR, (r >> 8) & 0x1FFUL);
    sink += CSR_R(CSR_SMIR);

    switch ((r >> 12) % 7u) {
    case 0: CSR_W(CSR_SMCIR, SMCIR_INVALL);               break;
    case 1: CSR_W(CSR_SMCIR, SMCIR_INVASID | (r & 0xFFFFUL)); break;
    case 2: CSR_W(CSR_SMCIR, SMCIR_TLBP);                 break;
    case 3: CSR_W(CSR_SMCIR, SMCIR_TLBWI);                break;
    case 4: CSR_W(CSR_SMCIR, SMCIR_TLBWR);                break;
    case 5: CSR_W(CSR_SMCIR, SMCIR_TLBR);                 break;
    default:CSR_W(CSR_SMCIR, 0);                          break; /* no-op leg */
    }
    sink += CSR_R(CSR_SMCIR);
}

/* satp. Written only from M mode, where translation does not apply, and
 * always restored to Bare before anything drops to S or U. MPRV is cleared
 * first: MPRV=1 with MPP=S/U and satp=Sv39 would translate our own M-mode
 * loads and stores. */
static void g_satp(u64 r)
{
    CSR_C(CSR_MSTATUS, MSTATUS_MPRV);
    CSR_W(CSR_SATP, SATP_SV39 | SATP_ASID(r >> 8) | SATP_PPN(r >> 24));
    sink += CSR_R(CSR_SATP);
    CSR_W(CSR_SATP, SATP_ASID(r) | SATP_PPN(r >> 16));   /* mode Bare */
    sink += CSR_R(CSR_SATP);
    CSR_W(CSR_SATP, 0);

    /* satp access from S mode under TVM must trap. */
    CSR_S(CSR_MSTATUS, MSTATUS_TVM);
    lower_sel = 3u;
    cp0_run_in_smode(smode_body);
    CSR_C(CSR_MSTATUS, MSTATUS_TVM);
}

/* MPRV makes loads and stores use MPP's privilege. Only ever exercised with
 * satp Bare and the permissive PMP entry in place, so it changes which checks
 * run without being able to fault our own data. */
static void g_mprv(u64 r)
{
    CSR_W(CSR_SATP, 0);
    CSR_C(CSR_MSTATUS, MSTATUS_MPP);
    if ((r >> 8) & 1u) CSR_S(CSR_MSTATUS, MSTATUS_MPP_S);
    CSR_S(CSR_MSTATUS, MSTATUS_MPRV | MSTATUS_SUM | MSTATUS_MXR);
    sink += scratch_mem[4];
    scratch_mem[5] = r;
    CSR_C(CSR_MSTATUS, MSTATUS_MPRV | MSTATUS_SUM | MSTATUS_MXR);
    CSR_S(CSR_MSTATUS, MSTATUS_MPP);
}

/* Floating-point state. With FS=0 the four float CSRs *and* every F/D
 * instruction are illegal (aq_cp0_regs.v:1104,1307; aq_idu_id_decd.v:949). */
static void g_float(u64 r)
{
    if ((r >> 8) & 1u) {
        CSR_C(CSR_MSTATUS, MSTATUS_FS);
        sink += CSR_R(CSR_FFLAGS);              /* illegal with FS==0 */
        __asm__ volatile ("fadd.d fa0, fa0, fa0" ::: "fa0");  /* also illegal */
        CSR_S(CSR_MSTATUS, MSTATUS_FS_INIT);
    } else {
        CSR_S(CSR_MSTATUS, MSTATUS_FS_INIT);
        PROBE_RW(CSR_FFLAGS, 0x1FUL, r);
        PROBE_RW(CSR_FRM,    0x07UL, r);
        PROBE_RW(CSR_FCSR,   0xFFUL, r);
        PROBE_RW(CSR_FXCR,   FXCR_WMASK, r);
        /* A real FP op, to dirty mstatus.FS and light up SD. */
        __asm__ volatile ("fcvt.d.l fa0, %0\n\t"
                          "fadd.d fa0, fa0, fa0"
                          :: "r"(r) : "fa0");
        sink += CSR_R(CSR_MSTATUS);
    }
}

/* ==================================================================== *
 * Dispatch
 * ==================================================================== */
static void dispatch(u64 r)
{
#ifdef CP0_ONLY_GROUP
    /* Debug aid: build with -DCP0_ONLY_GROUP=n to run just one group, which is
     * how a group that hangs or misbehaves gets isolated. Groups 0..31 are the
     * main rotation; 32..41 are the sparse second selector. */
    unsigned g = (CP0_ONLY_GROUP);
#else
    unsigned g = (unsigned)(r % NGROUPS);
#endif

    if (g < NGROUPS_TOTAL) group_hits[g]++;

    switch (g) {
    case 0:  g_safe_rw(r);        break;
    case 1:  g_imm_forms(r);      break;
    case 2:  g_no_write_forms(r); break;
    case 3:  g_read_only(r);      break;
    case 4:  g_ro_zero(r);        break;
    case 5:  g_trap_illegal(r);   break;
    case 6:  g_vector_illegal(r); break;
    case 7:  g_legal_hole(r);     break;
    case 8:  g_mcpuid_walk(r);    break;
    case 9:  g_mip_rmw(r);        break;
    case 10: g_mhcr(r);           break;
    case 11: g_mhint(r);          break;
    case 12: g_mhint2(r);         break;
    case 13: g_mxstatus(r);       break;
    case 14: g_theadisaee_off(r); break;
    case 15: g_sxstatus(r);       break;
    case 16: g_mcor(r);           break;
    case 17: g_mcins(r);          break;
    case 18: g_cache_cp0(r);      break;
    case 19: g_cache_va(r);       break;
    case 20: g_fence(r);          break;
    case 21: g_wfi(r);            break;
    case 22: g_ecall_ebreak(r);   break;
    case 23: g_illegal(r);        break;
    case 24: g_debug_csrs(r);     break;
    case 25: g_fault(r);          break;
    case 26: g_tvec(r);           break;
    case 27: g_vectored(r);       break;
    case 28: g_smode(r);          break;
    case 29: g_umode(r);          break;
    case 30: g_delegate(r);       break;
    case 31: g_int_soft(r);       break;
    /* 32..41 are only reachable through -DCP0_ONLY_GROUP; in a normal run they
     * come from the sparse selector below. */
    case 32: g_int_deleg(r);      break;
    case 33: g_int_external(r);   break;
    case 34: g_int_hpm(r);        break;
    case 35: g_hpcp(r);           break;
    case 36: g_cnt_policy(r);     break;
    case 37: g_pmp(r);            break;
    case 38: g_mmu_tlb(r);        break;
    case 39: g_satp(r);           break;
    case 40: g_mprv(r);           break;
    case 41: g_float(r);          break;
    default: break;
    }

#ifndef CP0_ONLY_GROUP
    /* The remaining groups are rarer and more expensive, so they ride along on
     * a second, sparser selector rather than diluting the main rotation. */
    switch ((unsigned)((r >> 32) % 64u)) {
    case 0:  g_int_deleg(r);      group_hits[32]++; break;
    case 1:  g_int_external(r);   group_hits[33]++; break;
    case 2:  g_int_hpm(r);        group_hits[34]++; break;
    case 3:  g_hpcp(r);           group_hits[35]++; break;
    case 4:  g_cnt_policy(r);     group_hits[36]++; break;
    case 5:  g_pmp(r);            group_hits[37]++; break;
    case 6:  g_mmu_tlb(r);        group_hits[38]++; break;
    case 7:  g_satp(r);           group_hits[39]++; break;
    case 8:  g_mprv(r);           group_hits[40]++; break;
    case 9:  g_float(r);          group_hits[41]++; break;
    default: break;
    }
#endif
}

/* ==================================================================== *
 * End-of-run summary over the UART.
 *
 * crt0.s leaves the console region cacheable, so a plain store never reaches
 * the bus and nothing prints. Clean+invalidate, run with the D-cache off so
 * the stores go out as single 32-bit writes with awlen==0 and wstrb==0xf --
 * which is what tb.v:345-370 decodes -- then put the cache back.
 *
 * This is diagnostics only: PASS/FAIL is the GPR magic value, and the real
 * evidence of CP0 stimulus is work/cp0_toggle.report.
 * ==================================================================== */
/* One 32-bit store per character. With the D-cache off the store still goes
 * through the store buffer, where consecutive writes to the same address
 * coalesce, and the testbench snoops the AXI port for exactly one cycle per
 * write -- so characters need real separation, not just ordering. th.sync
 * drains the bus interface (not only the LSU buffers, which is all `fence`
 * does), and the spin gives the snooper an unambiguous cycle to sample. */
static void uputc(char c)
{
    unsigned i;

    *(volatile unsigned int *)UART_THR = (unsigned int)(unsigned char)c;
    TH_OP(TH_SYNC);
    for (i = 0; i < 24u; i++)
        __asm__ volatile ("" ::: "memory");
}

static void uputs(const char *s)
{
    while (*s)
        uputc(*s++);
}

static void uputu(u64 v)
{
    char buf[24];
    int n = 0;

    if (!v) { uputc('0'); return; }
    while (v) { buf[n++] = (char)('0' + (v % 10u)); v /= 10u; }
    while (n--) uputc(buf[n]);
}

static void report(void)
{
    unsigned i;

    DCACHE_SAFE_POINT();
    CSR_C(CSR_MHCR, MHCR_DE);

    uputs("\n[cp0_random] iters=");
    uputu(iter);
    uputs(" mtraps=");
    uputu(CTX_U64(CTX_TOTAL));
    uputs(" straps=");
    uputu(CTX_U64(CTX_STOTAL));
    uputs(" recovered=");
    uputu(recovered);
    uputs("\n[cp0_random] M causes:");
    for (i = 0; i < 32; i++) {
        u64 n = CTX_U64(CTX_COUNT + 8u * i);
        if (n) { uputc(' '); uputu(i); uputc('='); uputu(n); }
    }
    uputs("\n[cp0_random] M ints:");
    for (i = 32; i < 64; i++) {
        u64 n = CTX_U64(CTX_COUNT + 8u * i);
        if (n) { uputc(' '); uputu(i - 32u); uputc('='); uputu(n); }
    }
    uputs("\n[cp0_random] S causes:");
    for (i = 0; i < 64; i++) {
        u64 n = CTX_U64(CTX_SCOUNT + 8u * i);
        if (n) {
            uputc(' ');
            if (i >= 32) uputc('i');
            uputu(i & 31u);
            uputc('=');
            uputu(n);
        }
    }
    uputs("\n[cp0_random] groups:");
    for (i = 0; i < NGROUPS_TOTAL; i++) {
        uputc(' ');
        uputu(group_hits[i]);
    }
    uputc('\n');

    CSR_S(CSR_MHCR, MHCR_DE);
}

/* ==================================================================== *
 * main
 * ==================================================================== */
int main(void)
{
    rng_state = (u64)CP0_SEED | 1UL;   /* xorshift must not start at zero */

    cp0_trap_init();
    pmp_open_everything();
    restore_sane_state();

    for (iter = 0; iter < (u64)CP0_ITERS; iter++) {
        /* Landing pad for the trap handler's bail-out path. iter and rng_state
         * are volatile so they survive the longjmp. */
        if (cp0_setjmp() != 0) {
            recovered++;
            restore_sane_state();
            pmp_open_everything();
            continue;
        }

        dispatch(rnd());

        if ((iter & 0xFFFu) == 0u) {
            restore_sane_state();
            pmp_open_everything();
        }
    }

    restore_sane_state();
    report();

    /* Returning lands in crt0.s __exit, which materialises the PASS magic the
     * testbench is watching the RTU writeback buses for. */
    return 0;
}
