/*
 * ifu_random -- randomized stress test for the OpenC906 instruction fetch unit
 * (C906_RTL_FACTORY/gen_rtl/ifu/rtl/): PC generation and the redirect priority
 * network, the 32 KB 2-way I-cache with its refill / prefetch / invalidate
 * FSMs, the 16-entry BTB, the 1024x8 BHT, the 4-entry RAS, the RVC packer and
 * the six-entry instruction buffer.
 *
 * Executes IFU_ITERS (default 10000) dynamic iterations of a seeded xorshift64
 * dispatch loop over 42 operation groups. Each group names, in its comment, the
 * RTL structure it aims at and the file:line where that structure lives.
 *
 * WHAT THIS TEST IS
 * -----------------
 * Stimulus. There is deliberately NO golden model, no self-check and no
 * expected-value comparison. The test passes by running to completion: main
 * returns, crt0.s __exit materialises the magic value the testbench watches the
 * RTU writeback buses for, and PASS is printed. Results are folded into
 * rand_sink only so the compiler cannot delete the instruction under test;
 * rand_sink is printed at the end as an informational fingerprint and is NOT
 * compared against anything. The evidence that the IFU was actually stimulated
 * is the port-toggle report, not this file.
 *
 * WHY THERE IS A GENERATOR
 * ------------------------
 * IFU coverage is coverage of an address *layout*, which C cannot express: the
 * BTB tags and stores targets with PC[15:0] only (aq_ifu_btb.v:154), the
 * I-cache index is VA[13:6] (aq_ifu_icache.v:534-535), the I-uTLB has ten
 * entries (aq_mmu_utlb.v:310), `ipack_pred_unalign` needs 32-bit instructions
 * at 2 mod 4 (aq_ifu_ipack.v:472), and the RAS keeps PC[23:0] only
 * (aq_ifu_ras.v:53-58). gen_ifu_arena.py therefore emits ~130 blocks of raw
 * .short/.word encodings at generator-computed addresses into .text.arena,
 * pinned by linker_ifu.lcf, plus the ifu_arena.h declarations used below and
 * the far stub the testbench loads at exactly 16 MB. Its --check pass asserts
 * every layout invariant at build time.
 *
 * ROBUSTNESS, NOT CORRECTNESS, IS THE DESIGN CONSTRAINT
 * ----------------------------------------------------
 *   - every group that perturbs persistent state saves it and puts it back,
 *     masked to that CSR's writable bits, and rand_restore_sane_state()
 *     re-baselines everything every 4096 iterations;
 *   - the shared trap handler unwinds to the loop head via rand_longjmp on any
 *     nested or unexpected trap, so a wild fetch costs one iteration;
 *   - deliberate excursions into unfetchable memory go through rand_run_at(),
 *     whose fault net resumes at a landing pad instead of trying to step over
 *     an instruction it cannot read;
 *   - mstatus.MIE stays 0 outside group 4, which is the only group that touches
 *     interrupt state and does so through rand_arm_lpmd_wake();
 *   - every loop trip count that reaches arena code from here is masked and
 *     incremented *inside* the arena block, so no value this file can produce
 *     makes an arena loop unbounded.
 *
 * WHAT IS OUT OF SCOPE BECAUSE IT IS UNREACHABLE ON THIS SoC
 * ---------------------------------------------------------
 *   - refill_error (aq_ifu_icache.v:963-967), pf_err_ff (:1141-1145),
 *     biu_icache_ref_err (:863) and the AXI-error leg of icache_ipack_acc_err
 *     (:1329). logical/axi/axi_err128.v:208,211 answers every unmapped read
 *     with rdata = 0 and rresp = 2'b00 (OKAY), so no AXI error response exists
 *     anywhere on this SoC. Nothing software does can reach these.
 *   - rtu_ifu_dbg_mask (aq_ifu_ctrl.v:95), the aq_ifu_vec.v HALT state and the
 *     debug-mode instruction injected into the IBUF: all JTAG-only. The
 *     `debug` case drives them.
 *   - the aq_ifu_vec.v RESET / WARM_UP states: entered once, before software
 *     runs.
 *   - indirect branch prediction (mhcr[7] IBPE) and the loop buffer (mhcr[12]
 *     L0BTBE): both hardwired 0 in this configuration.
 *   - cjltype_vld0/1 (aq_ifu_pre_decd.v:160): C.JAL does not exist in RV64.
 *   - there is no misaligned-fetch exception in this core.
 *
 * And one that is unreachable only in the DEFAULT configuration:
 *   - ipack_expt_high (aq_ifu_ibuf.v:1312-1313), pop_entry_expt_high
 *     (:1330-1331) and ifu_idu_id_expt_high (:1365-1366) all require
 *     ipack_inst_32 -- a fault on the HIGH half of a genuine 32-bit
 *     instruction. The only fetch-permission boundary in this address map
 *     without Sv39 is the sysmap region 0/1 edge at 0x8FFF_F000, whose low side
 *     is the error slave and therefore always reads as zeros, i.e. never as a
 *     32-bit opcode. Group 18 covers everything around it and its comment says
 *     exactly what it does not reach; the missing term needs -DIFU_MMU.
 *
 * The whole taxonomy and the per-group RTL references were derived from the
 * RTL; rand_csrs.h carries the provenance of every CSR address, mask and
 * address-window rule used here.
 */

#include "rand_common.h"
#include "ifu_defs.h"
#include "ifu_arena.h"

/* ==================================================================== *
 * State
 * ==================================================================== */
static volatile u64 group_hits[NGROUPS_TOTAL];

/* Load/store target for the arena blocks that need one. In our own .bss, i.e.
 * inside the SRAM window tb.v:98 wipes and loads. 512 * 8 = 4 KB, so the
 * largest offset an arena block adds (+0x100) still lands inside it. */
static volatile u64 ifu_data[512];

/* Per-group counters for the groups whose *selection* rate and *firing* rate
 * differ, so the report distinguishes the two. */
static volatile u64 stat_highpc;        /* group 2 excursions actually taken */
static volatile u64 stat_walk;          /* group 8 sleds actually walked     */
static volatile u64 stat_far;           /* group 32 calls across 16 MB       */
static volatile u64 stat_jit;           /* group 41, only with -DIFU_JIT     */
static volatile u64 stat_en_full;       /* group 39 iterations, all enabled  */
static volatile u64 stat_en_degraded;   /* group 39 iterations, something off */

/* ==================================================================== *
 * Helpers
 * ==================================================================== */

/* A jalr *call* to an absolute address, written longhand rather than through a
 * C function pointer. Two reasons: it is then unambiguous that the target came
 * from an immediate and never from memory (a jr-based tail call through a
 * pointer table stalls retirement on this RTL -- CLAUDE.md "Known Bugs"), and
 * ra is saved explicitly. This function is a leaf, so GCC would not save ra for
 * us, and pinning the target in t0 stops GCC from ever handing us ra as the
 * operand register -- which would make the `sd ra` below store the target
 * instead of the return address. Everything the callee may clobber is listed.
 *
 * Used for group 32 (the 16 MB-distant far stub, unreachable by jal, whose
 * ±1 MB range stops 0x40 short of nothing useful here) and, under -DIFU_JIT,
 * for entering the runtime-generated buffer.
 */
static void ifu_far_call(u64 addr)
{
    register u64 tgt __asm__("t0") = addr;

    __asm__ volatile (
        "addi   sp, sp, -16\n\t"
        "sd     ra, 8(sp)\n\t"
        "jalr   ra, t0, 0\n\t"
        "ld     ra, 8(sp)\n\t"
        "addi   sp, sp, 16"
        : "+r"(tgt)
        :
        : "t1", "t2", "t3", "t4", "t5", "t6",
          "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "memory");
}

/* Throw the I-cache away so the next fetch of an arena block is a real refill.
 * th.icache.iall re-decodes to FUNC_FENCEI (rand_th_insn.h), which is what
 * drives the 256-set IOP_IDLE->IOP_WRTE invalidate loop
 * (aq_ifu_icache.v:1288-1299). */
static void ifu_cold(void)
{
    RAND_ICACHE_SYNC();
}

/* ==================================================================== *
 * Group 0-5: PC generation and fetch control
 *            aq_ifu_pcgen.v, aq_ifu_ctrl.v, aq_ifu_ibuf.v
 * ==================================================================== */

/* One redirect from a chosen source. The three software-reachable arms of the
 * 8-arm redirect priority (aq_ifu_pcgen.v:206-222) are:
 *   rtu_ifu_chgflw_vld     -- highest: any flush, i.e. any trap or mret
 *   iu_ifu_tar_pc_vld      -- a resolved mispredicted jalr
 *   pred_pcgen_chgflw_vld  -- an ID-stage prediction
 * They are also the three feeders of the 6-arm pcgen_ifpc update chain
 * (:236-252). */
static void ifu_redirect(unsigned which, u64 r)
{
    switch (which & 3u) {
    case 0:  __asm__ volatile ("ecall");    break;   /* RTU flush, cause 11 */
    case 1:  __asm__ volatile ("ebreak");   break;   /* RTU flush, cause 3  */
    case 2:  ifu_blk_ras_unpred();          break;   /* iu_ifu_tar_pc_vld   */
    default: IFU_CALL_B2B(r >> 40);         break;   /* pred_pcgen_chgflw   */
    }
}

/* Group 0: drive two redirect sources back to back with 0..3 instructions of
 * spacing, so each arm gets to win the priority in turn and the loser is
 * sometimes still in the shadow of the winner. */
static void g_redirect_prio(u64 r)
{
    unsigned n = IFU_SEL(r, 8, 4);
    unsigned i;

    ifu_redirect(IFU_SEL(r, 12, 4), r);
    for (i = 0; i < n; i++)
        RAW_OP16(C_NOP);
    ifu_redirect(IFU_SEL(r, 16, 4), r >> 3);
}

/* Group 1: the one-cycle pcgen_buf_chgflw shadow (aq_ifu_pcgen.v:221-229) and
 * its consumers, pcgen_chgflw_btb / pcgen_chgflw_cur (:277-278) and
 * pcgen_ctrl_chgflw_vld / pcgen_icache_chgflw_vld (:301-303). Seeing it needs
 * *back-to-back* redirects, which is what the b2b arena blocks are: every
 * branch target's first instruction is itself a taken transfer. */
static void g_buf_chgflw(u64 r)
{
    IFU_CALL_B2B(r >> 8);
    IFU_CALL_B2B(r >> 12);
    if (IFU_BIT(r, 16))
        IFU_CALL_B2B(r >> 20);
}

/* Group 2: pcgen_ifpc[63:40] (aq_ifu_pcgen.v:257-275) is written from
 * iu_ifu_tar_pc[63:40] and nothing else, so the only way in is a *resolved*
 * jalr to an address with VA bit 39 set. That fetch always faults -- the
 * address is non-canonical and mepc may come back truncated -- which is why
 * this is wrapped in rand_run_at(): the excursion's fault net resumes at its
 * landing pad instead of trying to step over an unfetchable instruction.
 * Deliberately sparse (1 in IFU_HIGHPC_1_IN visits) with its own counter,
 * because every firing costs a trap and an unwind. */
static void g_high_pc(u64 r)
{
    if (IFU_SEL(r, 40, IFU_HIGHPC_1_IN) != 0u) {
        rand_sink += (u64)(unsigned long)&ifu_blk_highpc;
        return;
    }
    stat_highpc++;
    rand_run_at((u64)(unsigned long)&ifu_blk_highpc);
}

/* Group 3: ipack_pcgen_reissue && icache_pcgen_inst_vld (aq_ifu_pcgen.v:245-246
 * and the matching high-PC arm :268-269), fed by pred_delay_reissue
 * (aq_ifu_pred.v:551-555 = a not-taken-predicted branch in slot0 with another
 * branch in slot1 of the same fetch group). The delaybr blocks are built with
 * exactly that shape; a non-zero argument keeps slot0 training not-taken. */
static void g_reissue(u64 r)
{
    unsigned i;

    for (i = 0; i < 4u; i++)
        IFU_CALL_DELAYBR(r >> (8 + 2 * i), 1UL);     /* slot0 not taken */
}

/* Group 4: the !(cp0_ifu_in_lpmd || cp0_ifu_lpmd_req) kill term on
 * ctrl_inst_fetch (aq_ifu_ctrl.v:93-94), ifu_mmu_abort's lpmd_req arm
 * (aq_ifu_icache.v:725) and the WFPA->IDLE exit on cp0_ifu_lpmd_req
 * (:891). Whether a refill is in flight when LPMD is requested is randomised.
 * The wake source is rand_arm_lpmd_wake(): a delegated STIP with sstatus.SIE
 * clear, which neither M nor S will take but which still satisfies the
 * privilege-blind |(mie & mip) wake condition. A WFI with nothing armed is
 * unrecoverable short of reset. */
static void g_lpmd_kill(u64 r)
{
    switch (IFU_SEL(r, 8, 4)) {
    case 0:  break;                                       /* nothing pending */
    case 1:  ifu_cold();                       break;     /* next fetch cold */
    case 2:  IFU_CALL_PAGE(r >> 16);           break;     /* warm            */
    default: ifu_cold(); IFU_CALL_CONF(r >> 16); break;   /* refill in flight */
    }

    rand_arm_lpmd_wake();
    __asm__ volatile ("wfi" ::: "memory");
    rand_disarm_lpmd_wake();
}

/* Group 5: ibuf_stall -> ibuf_ctrl_inst_fetch = 0 (aq_ifu_ibuf.v:1194, :1337)
 * and the three ibuf_entry_stall arms (:1190-1193: full, one-available with a
 * 32-bit push, two-available with a three-halfword push). The stall blocks put
 * a divide or a D-cache-missing load in front of a long straight-line RVC run,
 * so the six-entry buffer fills behind a stalled IDU. */
static void g_ibuf_full_kill(u64 r)
{
    volatile u64 *p = &ifu_data[IFU_SEL(r, 16, 256)];

    IFU_CALL_STALL(r >> 8, p);
    IFU_CALL_STALL(r >> 12, &ifu_data[IFU_SEL(r, 28, 256)]);
}

/* ==================================================================== *
 * Group 6-19: the I-cache -- 32 KB, 2-way, 64 B lines, 256 sets,
 *             index VA[13:6] (so a 16 KB alias stride), tag PA[39:12],
 *             1-bit FIFO replacement.            aq_ifu_icache.v
 * ==================================================================== */

/* Group 6: the way-prediction / tag-hit buffer (aq_ifu_icache.v:588-662, gated
 * by mhint[10] IWPE): buf_upd_en (:596), the four buf_clr_en arms (:599-602),
 * addr_equal (:659), cen_mask_vld (:662) and direct_sel (:638-654). The line
 * blocks are loops living entirely inside ONE 64 B line, so the buffer supplies
 * every fetch, and their exit deliberately crosses into the next line. Run with
 * IWPE both on and off. */
static void g_iway_pred(u64 r)
{
    u64 old = CSR_R(CSR_MHINT);

    if (IFU_BIT(r, 8))
        CSR_C(CSR_MHINT, MHINT_IWPE);
    else
        CSR_S(CSR_MHINT, MHINT_IWPE);

    if (IFU_BIT(r, 9))
        ifu_cold();
    IFU_CALL_LINE(r >> 12);
    IFU_CALL_LINE(r >> 16);

    CSR_W(CSR_MHINT, old & MHINT_WMASK);
}

/* Group 7: the 2-way array with 1-bit FIFO replacement (aq_ifu_icache.v:604,
 * :1257), req_cnt = icache_miss_addr[5:4] driving critical-word-first refill
 * over four bins (:974-980) and the four bypass-word bins
 * (refill_bank0..3_sel, :1004-1007). The conf blocks are pinned at a 16 KB
 * stride -- identical VA[13:6], so the same set -- with a per-block 16 B and
 * 4 B entry offset chosen so the eight of them cover all four values of BOTH
 * fields (gen_ifu_arena.py CONF_BANK, asserted by --check), and are called in a
 * random order so the FIFO bit thrashes.
 */
static void g_set_conflict(u64 r)
{
    unsigned n = 3u + IFU_SEL(r, 8, 6);         /* 3..8 of the 8 aliases */
    unsigned i;

    if (IFU_BIT(r, 11))
        ifu_cold();
    for (i = 0; i < n; i++)
        IFU_CALL_CONF((r >> (16 + 3 * i)) ^ i);
}

/* Group 8: capacity eviction. A 48 KB straight-line RVC sled walked once
 * touches every one of the 256 sets one and a half times over, so both ways of
 * every set are replaced. Sparse (1 in IFU_WALK_1_IN) with its own counter:
 * ~25k retired instructions and 768 line refills per firing is two orders of
 * magnitude more simulated time than any other group. */
static void g_walk(u64 r)
{
    if (IFU_SEL(r, 40, IFU_WALK_1_IN) != 0u)
        return;
    stat_walk++;
    if (IFU_BIT(r, 46))
        ifu_cold();
    ifu_blk_walk();
}

/* Group 9: the refill FSM's WFPA state and its four distinct exits
 * (aq_ifu_icache.v:886-895) plus icache_stall (:938). The I-uTLB is ten entries
 * (aq_mmu_utlb.v:310) and the jTLB fills it even with translation off, so
 * touching more than ten distinct 4 KB code pages forces multi-cycle
 * translations -- which is the only way a fetch sits in WFPA at all.
 *
 * This group is also the engine for group 20: those long fetch stalls are what
 * drain the IBUF and make ibuf_pred_hungry true, and BTB allocation happens
 * nowhere else (aq_ifu_pred.v:795-796). */
static void g_utlb_wfpa(u64 r)
{
    unsigned n = 6u + IFU_SEL(r, 8, 15);        /* 6..20 distinct pages */
    unsigned i;

    if (IFU_BIT(r, 13))
        ifu_cold();
    for (i = 0; i < n; i++)
        IFU_CALL_PAGE((r >> (24 + i)) + 7u * i);

    /* One instruction, two pages: a 32-bit branch at page_off 0xFFE needs a
     * uTLB lookup for each of its halves. */
    ifu_blk_pgstraddle();
}

/* Group 10: refill_data_abort (aq_ifu_icache.v:949-956) and icache_bypass_vld
 * (:1324). Inside each abort block a short forward branch is trained not-taken
 * and resolved taken on its last trip, while the unconditional jump it guards
 * is fetching a cold block 16 KB away -- so ctrl_icache_abort arrives during
 * INIT or WFC of that refill. */
static void g_refill_abort(u64 r)
{
    unsigned i;

    for (i = 0; i < 3u; i++) {
        if (IFU_BIT(r, 8 + i))
            ifu_cold();
        IFU_CALL_ABORT(r >> (16 + 2 * i));
    }
}

/* Group 11: the 8-state prefetch FSM (aq_ifu_icache.v:1030-1121, gated by
 * mhint[8]), pf_chk_vld (:1042) and the pf_chk_pass FAIL arm (:1046, :1071) --
 * reached by entering a block one line earlier the second time, so line k+1 is
 * already resident when line k misses. Also the page-bounded +1 on VA[11:6]
 * only (:1131-1135), which is why a miss on the LAST line of a page prefetches
 * the FIRST line of the same page, and both AXI stream IDs in flight at once
 * (ifu_biu_arid = !icache_req, :1362). */
static void g_prefetch(u64 r)
{
    u64 old = CSR_R(CSR_MHINT);
    unsigned k = IFU_SEL(r, 8, 3);

    switch (IFU_SEL(r, 12, 4)) {
    case 0:
        CSR_S(CSR_MHINT, MHINT_IPREF_EN);
        ifu_cold();
        IFU_CALL_PFA(k);                /* refills line k+1 */
        IFU_CALL_PFB(k);                /* misses line k -> pf_chk_pass fails */
        break;
    case 1:
        CSR_S(CSR_MHINT, MHINT_IPREF_EN);
        ifu_cold();
        ifu_blk_pflast();               /* miss on the last line of a page */
        break;
    case 2:
        CSR_S(CSR_MHINT, MHINT_IPREF_EN);
        ifu_cold();
        IFU_CALL_CONF(r >> 16);         /* demand refill + prefetch, then     */
        IFU_CALL_CONF((r >> 20) + 1u);  /* another: both arid streams in play */
        break;
    default:
        CSR_C(CSR_MHINT, MHINT_IPREF_EN);
        ifu_cold();
        IFU_CALL_PAGE(r >> 16);
        break;
    }

    CSR_W(CSR_MHINT, old & MHINT_WMASK);
}

/* Group 12: icache_refill_ca (aq_ifu_icache.v:840) selecting arlen = 0 with a
 * FIXED-ish single-beat burst instead of the 4-beat WRAP (:1363-1365) and the
 * bypass-word select (:1004-1007). Two levers:
 *   (a) clear MHCR[0] and run whole arena blocks with the I-cache off, so every
 *       fetch is a single-beat non-cacheable read of *real* instructions;
 *   (b) fetch from sysmap region 2 (RAND_NC_BASE, flags 5'b00011: non-cacheable
 *       and executable, gen_rtl/mmu/rtl/sysmap.h:25-26). The error slave answers
 *       with zeros and rresp = OKAY, so that is one legal non-cacheable fetch
 *       followed by an illegal-instruction trap -- which the excursion's fault
 *       net catches.
 */
static void g_noncacheable(u64 r)
{
    if (IFU_BIT(r, 8)) {
        u64 old = CSR_R(CSR_MHCR);

        CSR_C(CSR_MHCR, MHCR_IE);
        IFU_CALL_PAGE(r >> 16);
        IFU_CALL_CONF(r >> 20);
        IFU_CALL_LINE(r >> 24);
        CSR_W(CSR_MHCR, old & MHCR_WMASK);
        ifu_cold();
    } else {
        /* 2-byte aligned, and well inside region 2. */
        rand_run_at(RAND_NC_BASE + (u64)((r >> 12) & 0x1FEu));
    }
}

/* Group 13: the IOP_IDLE->IOP_WRTE loop over inv_cnt 0..0xFF, i.e. all 256 sets
 * (aq_ifu_icache.v:1276-1299), reached four different ways. Whether the block
 * fetched afterwards is hot or cold is randomised so both the miss and the hit
 * path follow an invalidate.
 *
 * MCOR bit 4 drives BOTH icache_inv and dcache_inv and invalidates without
 * writing back, hence DCACHE_SAFE_POINT() first. */
static void g_inv_all(u64 r)
{
    switch (IFU_SEL(r, 8, 4)) {
    case 0:
        __asm__ volatile ("fence.i" ::: "memory");
        break;
    case 1:
        TH_OP(TH_ICACHE_IALL);
        break;
    case 2:
        TH_OP(TH_ICACHE_IALLS);
        break;
    default:
        DCACHE_SAFE_POINT();
        CSR_W(CSR_MCOR, MCOR_INV | MCOR_SEL_I);
        break;
    }

    if (IFU_BIT(r, 12))
        IFU_CALL_CONF(r >> 16);
    else
        IFU_CALL_PAGE(r >> 16);
}

/* Group 14: the IOP_WRTE->READ->FLOP->WRTE walk over the four index aliases
 * (aq_ifu_icache.v:1276-1283, als_cnt_max = 3 -- the index is VA[13:6] but a
 * page only pins VA[11:6], so VA[13:12] aliases four ways) and the three
 * iaq_way_sel bins (:1252-1261: way 0 hit, way 1 hit, neither).
 *
 * The address is always inside .text.arena, which linker_ifu.lcf pins at
 * IFU_ARENA_BASE -- far below 0x1000_0000, so it can never be the APB window
 * where an I-cache refill would become a 4-beat WRAP burst axi2ahb cannot
 * service. */
static void g_inv_pa(u64 r)
{
    u64 lines = (IFU_ARENA_END - IFU_ARENA_BASE) / IFU_LINE_SIZE;
    u64 pa = IFU_ARENA_BASE + ((r >> 16) % lines) * IFU_LINE_SIZE;

    switch (IFU_SEL(r, 8, 3)) {
    case 0:  IFU_CALL_CONF(r >> 40); break;   /* resident: way 0 or way 1 */
    case 1:  ifu_cold();             break;   /* absent                   */
    default: break;                           /* whatever is there        */
    }

    TH_OP_RS1(TH_ICACHE_IPA, pa);
    rand_sink += pa;
}

/* Group 15: icache_inv_err (aq_ifu_icache.v:1301) and the IOP_FLOP early exit
 * (:1233-1237). th.icache.iva with rs1 in the sysmap strong-order window:
 * ifu_mmu_va_vld includes inv_fsm_flop && inv_type_va (:724) with
 * ifu_mmu_exec set, so utlb_deny's strong-order-exec term fires.
 *
 * This raises NO pipeline exception -- ifu_cp0_icache_inv_done is asserted on
 * the error path too (:1372), so the operation self-completes. Safe. */
static void g_inv_va_err(u64 r)
{
    TH_OP_RS1(TH_ICACHE_IVA, RAND_SO_BASE + (u64)((r >> 12) & 0xFC0u));
    if (IFU_BIT(r, 8))
        TH_OP_RS1(TH_ICACHE_IVA,
                  IFU_ARENA_BASE + (u64)((r >> 24) & 0x3FC0u));
}

/* Group 16: the cache-line read-out path (aq_ifu_icache.v:1304-1318). MCINS
 * rid 0 reads the I-cache tag array (:1310-1312: valid bit and tag[27:0]), rid 1
 * the data array; way selects between the two ways and the low two bits of
 * MCINDEX walk the four 32-bit word positions of a 16 B bank. MCINS bit 0 is a
 * one-shot that back-pressures EX1 until the read returns, and MCINS itself
 * always reads 0 -- the same handshake cp0_random's g_mcins uses. */
static void g_mcins_readout(u64 r)
{
    u64 rid = (r >> 8) & 1u;                    /* 0 = I$ tag, 1 = I$ data  */
    u64 way = (r >> 9) & 1u;
    u64 idx = (r >> 16) & 0x1FFFu;

    if (rid)
        idx = (idx & ~3UL) | ((r >> 40) & 3u);  /* the four word positions */

    CSR_W(CSR_MCINDEX, MCINDEX_RID(rid) | MCINDEX_WAY(way) | MCINDEX_IDX(idx));
    rand_sink += CSR_R(CSR_MCINDEX);
    CSR_W(CSR_MCINS, 1UL);
    rand_sink += CSR_R(CSR_MCDATA0);
    rand_sink += CSR_R(CSR_MCDATA1);
    rand_sink += CSR_R(CSR_MCINS);              /* write-only: must read 0 */
}

/* Group 17: mmu_ifu_access_fault -> icache_deny (aq_ifu_icache.v:731) ->
 * icache_ipack_acc_err (:1329-1330) -> ifu_idu_id_expt_acc_error
 * (aq_ifu_ibuf.v:1362), cause 1. Fetching in sysmap region 1 (strong order,
 * flags 5'b10011) is denied with no M-mode escape (aq_mmu_utlb.v:788-790), so
 * this needs no MMU set-up at all -- only rand_run_at() to make the excursion
 * recoverable. Three ports cp0_random explicitly declared out of scope. */
static void g_ifetch_accfault(u64 r)
{
    rand_run_at(RAND_SO_BASE + (u64)((r >> 8) & 0xFFEu));
}

/* Group 18: the per-halfword exception plumbing -- ipack_acc_err1 and
 * ipack_acc_err2 (aq_ifu_ipack.v:430-441), ipack_pred_inst0_expt / _inst1_expt
 * (:457-468), pop_entry0/1_create_acc_err (aq_ifu_ibuf.v:1300-1304) and
 * ifu_idu_id_expt_acc_error (:1362).
 *
 * Fetch PCs advance in aligned 4-byte steps (aq_ifu_pcgen.v:275), so entering
 * at RAND_SO_LAST_OK (0x8FFF_EFFE, the last two bytes of sysmap region 0) makes
 * the packer take halfword 1 of the group at 0x8FFF_EFFC -- region 0, the fetch
 * succeeds -- while the group at 0x8FFF_F000 is region 1, where exec is denied.
 * So entry1 is clean and entry2 carries acc_err, which is ipack_acc_err1's
 * second arm; it also drives the unaligned-entry path, icache_pa[1] being set.
 * Entering at the region-1 base instead faults on the very first halfword,
 * which is ipack_acc_err0.
 *
 * HONEST LIMIT: `ipack_expt_high` itself (:1312-1313), `pop_entry_expt_high`
 * (:1330-1331) and therefore `ifu_idu_id_expt_high` (:1365-1366) additionally
 * require ipack_inst_32, i.e. inst[1:0] == 2'b11 in the CLEAN low halfword. The
 * low side of the only region boundary in this address map is the error slave,
 * which answers with zeros (axi_err128.v:208), so the low halfword is always
 * 16-bit-illegal and inst_32 is never set on this path. Reaching expt_high needs
 * a 32-bit instruction straddling a page boundary in real SRAM with the next
 * page non-executable -- which is the Sv39 apparatus of group 19, gated behind
 * -DIFU_MMU. Those three ports are expected to stay untoggled by default. */
static void g_expt_high(u64 r)
{
    if (IFU_BIT(r, 8))
        rand_run_at((u64)RAND_SO_LAST_OK);      /* clean low, denied high */
    else
        rand_run_at((u64)RAND_SO_BASE);         /* denied first halfword  */
}

/* Group 19: an instruction PAGE fault (cause 12) needs regs_mmu_en &&
 * !mach_mode (aq_mmu_utlb.v:151), i.e. the full Sv39 + S-mode apparatus
 * modelled on tests/cases/MMU/. Gated behind -DIFU_MMU and OFF by default,
 * because it is the one group here that can cost the whole run: with satp
 * loaded, every subsequent fetch depends on a page table this test also
 * randomises around.
 *
 * Even with IFU_MMU on, the default sub-case only enables Sv39 with an
 * identity map and runs arena code in S mode -- which is the real coverage
 * (jTLB walks and uTLB fills with regs_mmu_en = 1 on the instruction side).
 * The sub-case that actually provokes cause 12 additionally needs
 * -DIFU_MMU_FAULT, because the S handler's step-over walks the faulting page
 * two bytes at a time and there is no clean way back. */
#ifdef IFU_MMU
#define PTE_V (1UL << 0)
#define PTE_R (1UL << 1)
#define PTE_W (1UL << 2)
#define PTE_X (1UL << 3)
#define PTE_A (1UL << 6)
#define PTE_D (1UL << 7)

static u64 ifu_pt_l2[512] __attribute__((aligned(4096)));
static u64 ifu_pt_l1[512] __attribute__((aligned(4096)));

static void ifu_smode_body(void)
{
    ifu_blk_page00();
    ifu_blk_page01();
#ifdef IFU_MMU_FAULT
    /* VA 0x200000 is mapped without X, so this fetch is an instruction page
     * fault. Undelegated, so it arrives in M mode -- where the handler's
     * step-over will grind through the page. Diagnostic use only. */
    __asm__ volatile ("li t0, 0x200000\n\t"
                      "jalr t2, t0, 0" ::: "t0", "t2", "memory");
#endif
    __asm__ volatile ("ecall");         /* hand control back to M */
}

static void g_sv39_ifetch(u64 r)
{
    unsigned i;
    u64 leaf = PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D;

    for (i = 0; i < 512u; i++)
        ifu_pt_l1[i] = ((u64)i << 19) | leaf;            /* 2 MB identity */
#ifdef IFU_MMU_FAULT
    if (IFU_BIT(r, 8))
        ifu_pt_l1[1] &= ~PTE_X;                          /* exec denied */
#endif
    for (i = 0; i < 512u; i++)
        ifu_pt_l2[i] = 0;
    ifu_pt_l2[0] = (((u64)(unsigned long)ifu_pt_l1) >> 2) | PTE_V;

    CSR_W(CSR_SATP, SATP_SV39 | (((u64)(unsigned long)ifu_pt_l2) >> 12));
    __asm__ volatile ("sfence.vma" ::: "memory");
    if (IFU_BIT(r, 12))
        ifu_cold();

    rand_run_in_smode(&ifu_smode_body);

    CSR_W(CSR_SATP, 0);
    __asm__ volatile ("sfence.vma" ::: "memory");
    rand_sink += r;
}
#endif /* IFU_MMU */

/* ==================================================================== *
 * Group 20-23: the BTB -- 16 entries, fully associative, tag AND target are
 *              PC[15:0] only, rotating-FIFO replacement.  aq_ifu_btb.v
 * ==================================================================== */

/* Group 20: the 16-arm one-hot read case (aq_ifu_btb.v:674-692) and the
 * rotating FIFO (:604-614). Allocation only happens when ibuf_pred_hungry
 * (aq_ifu_pred.v:795-796; aq_ifu_ibuf.v:1346 = at most two valid halfwords), so
 * every btb block is a "starved branch": a divide the branch depends on stalls
 * the IDU, the IBUF drains, and the taken branch arrives hungry. All 20 blocks
 * are called every visit -- a partial sweep would keep re-training the same few
 * entries instead of walking btb_fifo right round -- at 20 distinct PC[15:0],
 * which gen_ifu_arena.py --check asserts. */
static void g_btb_fill16(u64 r)
{
    unsigned base = (unsigned)(r >> 8);
    unsigned i;

    for (i = 0; i < IFU_N_BTB; i++)
        IFU_CALL_BTB(base + i);
    if (IFU_BIT(r, 40))
        for (i = 0; i < IFU_N_BTB; i++)
            IFU_CALL_BTB(base + IFU_N_BTB - 1u - i);     /* reverse order */
}

/* Group 21: btb_clr_one (aq_ifu_btb.v:593-598), the FIFO steering that reuses
 * the cleared slot (:610-611), and the two independent btb_mis_pred causes
 * (aq_ifu_pred.v:718-721: a wrong target, and !pred_br_taken with a valid BTB
 * target). Each mis block branches on a caller-supplied random bit at a trained
 * PC, so the two causes alternate. */
static void g_btb_mispred_clr(u64 r)
{
    unsigned i;

    for (i = 0; i < 6u; i++)
        IFU_CALL_MIS(r >> (8 + 2 * i), rand_rnd());
}

/* Group 22: tag and target are PC[15:0] only (aq_ifu_btb.v:628-630) with the
 * upper bits re-attached from pcgen_ifpc[39:16] (aq_ifu_pcgen.v:307).
 *   (a) x64k: a taken branch just below a 64 KB boundary whose target is just
 *       above it, so the prediction always lands 64 KB low;
 *   (b) alias_lo / alias_hi: two branches whose PCs differ only above bit 15,
 *       so the second hits the first's entry and gets the wrong target. */
static void g_btb_alias_64k(u64 r)
{
    unsigned i;

    for (i = 0; i < 3u; i++) {
        if (IFU_BIT(r, 8 + i)) {
            ifu_blk_alias_lo();
            ifu_blk_alias_hi();
        } else {
            ifu_blk_alias_hi();
            ifu_blk_alias_lo();
        }
    }
    ifu_blk_x64k();
    ifu_blk_x64k();                     /* second visit: now trained wrong */
}

/* Group 23: cp0_ifu_btb_clr clearing all 16 entries at once
 * (aq_ifu_btb.v:595-598) and cp0_ifu_btb_en gating update, clear and predict
 * (:593, :601-602, :700-702) -- mcor[17] and mhcr[6] toggled around a trained
 * loop. mhcr is put back masked to its writable bits; DE is never cleared here,
 * so no DCACHE_SAFE_POINT is owed. */
static void g_btb_inv_en(u64 r)
{
    u64 old = CSR_R(CSR_MHCR);

    IFU_CALL_LOOP(r >> 8, (r >> 10) & 63u);         /* train */

    switch (IFU_SEL(r, 20, 4)) {
    case 0:  CSR_W(CSR_MCOR, MCOR_BTB_INV);                    break;
    case 1:  CSR_C(CSR_MHCR, MHCR_BTBE);                       break;
    case 2:  CSR_C(CSR_MHCR, MHCR_BTBE);
             CSR_W(CSR_MCOR, MCOR_BTB_INV);                    break;
    default: CSR_W(CSR_MCOR, MCOR_BTB_INV | MCOR_SEL_I);       break;
    }

    IFU_CALL_LOOP(r >> 24, (r >> 26) & 63u);
    IFU_CALL_BTB(r >> 32);

    CSR_W(CSR_MHCR, old & MHCR_WMASK);
}

/* ==================================================================== *
 * Group 24-28: the BHT -- 1024 rows x 8 ways x 2-bit counter, indexed by the
 *              14-bit global history ONLY (pred_bht_pc is a forced, unused
 *              input, aq_ifu_bht.v:134-135).      aq_ifu_bht.v
 * ==================================================================== */

/* Group 24: all eight counter-update arms (aq_ifu_bht.v:457-505), including the
 * two saturated arms that write nothing (3'b000 and 3'b111). ONE branch whose
 * direction is a random bit random-walks the whole (index, way) space -- read
 * index = vghr[11:2] and way = 1 << vghr[2:0] (:253-257, :305-312). Many
 * distinct branches would be strictly worse: they all share the same history,
 * so they would collide on the same rows. 128..3904 iterations per visit. */
static void g_bht_lfsr_history(u64 r)
{
    unsigned n = 2u + IFU_SEL(r, 8, 60);            /* 2..61 calls of 64 */
    unsigned i;

    for (i = 0; i < n; i++)
        ifu_blk_bhtwalk(rand_rnd(), 63UL);
}

/* Group 25: the BHT repair FSM, BHT_REF_IDLE/READ1/READ2/WRTE/UPD
 * (aq_ifu_bht.v:389-448). READ1 and READ2 need iu_ifu_bht_mispred, and WRTE and
 * UPD both stall while pred_bht_br_vld is set (:427-441) -- so the FSM is only
 * observable with a SECOND branch immediately behind a mispredicting one. The
 * bhtrep blocks are exactly that: two RVC branches two bytes apart at a 4-byte
 * boundary, the first mispredicting on a random bit. */
static void g_bht_repair_fsm(u64 r)
{
    unsigned i;

    for (i = 0; i < 4u; i++)
        IFU_CALL_BHTREP(r >> (8 + i), rand_rnd(), 31UL + i);
}

/* Group 26: the write-forward network (aq_ifu_bht.v:275-295: bht_bypass_sel,
 * bht_dout_bypass, bht_dout_rslt). A two-instruction always-taken self-loop
 * keeps vghr[11:2] constant, so back-to-back branches hit the SAME row and the
 * bypass is the only source of an up-to-date counter. */
static void g_bht_bypass(u64 r)
{
    unsigned i;

    for (i = 0; i < 3u; i++)
        ifu_blk_bhtbyp((r >> (8 + 6 * i)) & 63u);
}

/* Group 27: the VGHR reload from GHR on mispredict (aq_ifu_bht.v:215) and the
 * read/write index skew -- writes use bht_ref_vghr[13:4], reads use vghr[11:2]
 * (:253-257). The vghr block plants a deliberately mispredicting branch after a
 * long random-history stream of caller-chosen depth. */
static void g_bht_vghr_restore(u64 r)
{
    unsigned i;

    for (i = 0; i < 3u; i++)
        ifu_blk_vghr(rand_rnd(), (r >> (8 + 5 * i)) & 31u);
}

/* Group 28: the 1024-iteration invalidate FSM (aq_ifu_bht.v:327-382), the
 * GHR/VGHR zeroing it also does (:200-201, :212-213), and cp0_ifu_bht_en gating
 * bht_cen (:233-244) -- mcor[16] and mhcr[5]. */
static void g_bht_inv_en(u64 r)
{
    u64 old = CSR_R(CSR_MHCR);

    ifu_blk_bhtwalk(rand_rnd(), 31UL);              /* train */

    switch (IFU_SEL(r, 8, 4)) {
    case 0:  CSR_W(CSR_MCOR, MCOR_BHT_INV);                    break;
    case 1:  CSR_C(CSR_MHCR, MHCR_BPE);                        break;
    case 2:  CSR_C(CSR_MHCR, MHCR_BPE);
             CSR_W(CSR_MCOR, MCOR_BHT_INV);                    break;
    default: CSR_W(CSR_MCOR, MCOR_BHT_INV | MCOR_BTB_INV);     break;
    }

    ifu_blk_bhtwalk(rand_rnd(), 31UL);
    IFU_CALL_LOOP(r >> 16, (r >> 18) & 63u);

    CSR_W(CSR_MHCR, old & MHCR_WMASK);
}

/* ==================================================================== *
 * Group 29-31: the RAS -- 4 entries, stores PC[23:0] only, pointer wraps
 *              silently.                aq_ifu_ras.v, aq_ifu_pred.v
 * ==================================================================== */

/* Group 29: the 4-arm read case (aq_ifu_ras.v:238-243) and the four skewed
 * write arms (:251-254), plus the silent pointer wrap (:206-214). Entering the
 * chain at level k gives a nested call depth of 6-k, so depths 1..6 all occur
 * and the pointer wraps past its four entries. */
static void g_ras_depth(u64 r)
{
    unsigned i;

    for (i = 0; i < 4u; i++)
        IFU_CALL_RAS_D(r >> (8 + 3 * i));
}

/* Group 30: pred_link_vld is any jalr with rd == x1 and pred_ret_vld is any
 * jalr with rs1 == x1 && rd != x1 (aq_ifu_pre_decd.v:127-133, :206-213), so:
 *   - `jalr ra, ra, 0` is a call and never a return: a push with no pop;
 *   - `jalr rd!=x1, rs1!=x1` is neither, so nothing predicts it at all;
 *   - ras_link_offset is 4 for a 32-bit link and 2 for a 16-bit one
 *     (aq_ifu_pred.v:625-626), i.e. jal versus c.jalr.
 * Case 4 issues five link-only blocks, ten pushes against a four-deep RAS, so
 * the pointer wraps two and a half times and later returns pop stale entries. */
static void g_ras_unbalanced(u64 r)
{
    switch (IFU_SEL(r, 8, 6)) {
    case 0:  ifu_blk_ras_linkonly(); break;      /* link, never a return  */
    case 1:  ifu_blk_ras_unpred();   break;      /* predicted by nothing  */
    case 2:  ifu_blk_ras_cjalr();    break;      /* ras_link_offset = 2   */
    case 3:  ifu_blk_ras_jal();      break;      /* ras_link_offset = 4   */
    case 4:  ifu_blk_ras_linkonly();
             ifu_blk_ras_linkonly();
             ifu_blk_ras_linkonly();
             ifu_blk_ras_linkonly();
             ifu_blk_ras_linkonly();  break;     /* wrap the 4-entry RAS  */
    /* Level 0, not level IFU_N_RAS_D-1: b_ras_chain builds level k as a call
     * to level k+1, so entering at 0 is the six-deep chain and entering at the
     * last level is a bare `c.jr ra` -- one return, which is not what this arm
     * is for. */
    default: IFU_CALL_RAS_D(0);                  /* deep chain, then      */
             ifu_blk_ras_linkonly(); break;      /* an unmatched push     */
    }
}

/* Group 31: the RAS_IDLE/RAS_WAIT FSM and pred_ret_stall (aq_ifu_pred.v:659-697)
 * feeding the 3-bin pred_id_stall (:741). Two returns adjacent in one fetch
 * group put a second pred_ras_ret_vld behind the first; the retret blocks give
 * both `c.jr ra; c.jr ra` (2 bytes apart, one fetch group) and `ret; ret`
 * (4 bytes apart, two groups). */
static void g_ras_ret_stall(u64 r)
{
    unsigned i;

    for (i = 0; i < 4u; i++)
        IFU_CALL_RAS_RETRET(r >> (8 + i));
}

/* ==================================================================== *
 * Group 32-41: the sparse selector -- expensive, fragile or wrapper groups
 * ==================================================================== */

/* Group 32: the RAS stores PC[23:0] only and the predicted return target is
 * {pred_idpc[39:24], ras_pred_tar_pc[23:0]} (aq_ifu_pred.v:656-657), so a
 * call/return pair crossing a 16 MB boundary can never both be predicted right.
 * The caller is in .text (bits [39:24] = 0) and the callee is the generated far
 * stub at exactly 16 MB (bits [39:24] = 1), which the testbench loads from
 * input.pat. 16 MB is far outside jal's +/-1 MB reach, so this is the one place
 * an absolute jalr call is required. */
static void g_ras_16m(u64 r)
{
    stat_far++;
    switch (IFU_SEL(r, 8, 4)) {
    case 0:  ifu_far_call(IFU_FAR_ENTRY0); break;
    case 1:  ifu_far_call(IFU_FAR_ENTRY1); break;   /* nested far call */
    case 2:  ifu_far_call(IFU_FAR_ENTRY2); break;
    default: rand_run_at(IFU_FAR_ENTRY0);  break;   /* return with no push */
    }
}

/* Group 33: with cp0_ifu_ras_en clear, pred_ras_tar collapses to pred_idpc and
 * pred_ras_link_vld is gated off entirely (aq_ifu_pred.v:613-615, :656-657) --
 * mhcr[4] toggled around a call-heavy block. */
static void g_ras_en_off(u64 r)
{
    u64 old = CSR_R(CSR_MHCR);

    CSR_C(CSR_MHCR, MHCR_RSE);
    IFU_CALL_RAS_D(r >> 8);
    ifu_blk_ras_cjalr();
    IFU_CALL_RAS_RETRET(r >> 12);
    CSR_W(CSR_MHCR, old & MHCR_WMASK);

    IFU_CALL_RAS_D(r >> 16);                        /* again, re-enabled */
}

/* Group 34: the delayed-branch mechanism (aq_ifu_pred.v:546-591).
 * pred_delay_br_raw needs a NOT-taken-predicted branch in slot0 and another
 * branch in slot1 of the same 4-byte fetch group; pred_delay_br1_taken and
 * delay_chgflw then carry the slot1 outcome a cycle late. Calling with a
 * non-zero argument most of the time pre-warms slot0 not-taken, which is the
 * precondition; the occasional zero flips it. */
static void g_delay_branch(u64 r)
{
    unsigned i;

    for (i = 0; i < 6u; i++)
        IFU_CALL_DELAYBR(r >> (8 + 2 * i),
                         (IFU_SEL(r, 24 + i, 8) == 0u) ? 0UL : 1UL);
}

/* Group 35: pred_inst1_taken (aq_ifu_pred.v:589-591) and pred_ras_link_vld1 /
 * pred_ras_ret_vld1 (:612, :618) -- two transfers in one 4-byte group. The
 * twobr blocks give `c.beqz; c.j`, `c.beqz; c.jr ra` and `c.beqz; c.jalr ra`. */
static void g_two_branch_group(u64 r)
{
    unsigned i;

    for (i = 0; i < 4u; i++)
        IFU_CALL_TWOBR(r >> (8 + 2 * i), rand_rnd());
}

/* Group 36: ipack_pred_unalign steering pred_btb_cur_pc to pcgen_pred_ifpc
 * instead of pred_idpc (aq_ifu_pred.v:804) and icache_ipack_unalign =
 * icache_pa[1] (aq_ifu_icache.v:1331). The strad blocks put 32-bit branches at
 * 2 mod 4 and randomise the parity of the branch TARGET, so the fetch that
 * lands on it also starts unaligned. The pgstraddle block is the extreme case:
 * a 32-bit branch at page_off 0xFFE, so the instruction straddles the fetch
 * word AND a 4 KB page at once. */
static void g_straddle_2mod4(u64 r)
{
    unsigned i;

    for (i = 0; i < 4u; i++)
        IFU_CALL_STRAD(r >> (8 + 2 * i), rand_rnd());
    if (IFU_BIT(r, 20))
        ifu_cold();
    ifu_blk_pgstraddle();
}

/* Group 37: the five retire shapes of aq_ifu_ipack.v:373-380 (h0_vld,
 * h1_16bit, h1_32bit, h2_16bit, h2_32bit), the two ipack_one_16bit_vld
 * sub-arms (:399-403), the three-halfword ipack_all_vld (:412-415) and the
 * 3-way ipack_first_inst mux (:390-392). Block k starts its 32-bit instruction
 * at halfword position k, so across the family a 32-bit instruction straddles
 * the fetch word at every position. */
static void g_ipack_shapes(u64 r)
{
    unsigned i;

    for (i = 0; i < IFU_N_SHAPE; i++)
        IFU_CALL_SHAPE(i + (unsigned)(r >> 8));
}

/* Group 38: the group that most needs the generator. Three push-rotate amounts
 * over six pointer positions (aq_ifu_ibuf.v:974-998 plus the push1/push2
 * fan-out :1032-1078), two pop muxes over six arms (:659-704, :754-816), the
 * empty-buffer bypass with its three sub-arms (:938-971, :1275-1311) and the
 * flush pointer collapse push0 <= pop0 (:980) at each position. Each rot block
 * is a random (length mix, stall index, flush index) triple: a divide at a
 * random instruction index creates the IDU stall, a random-direction branch at
 * another creates the flush. */
static void g_ibuf_rotate(u64 r)
{
    unsigned i;

    for (i = 0; i < 4u; i++)
        IFU_CALL_ROT(r >> (8 + 3 * i), rand_rnd(),
                     &ifu_data[IFU_SEL(r, 24 + i, 256)]);
}

/* Forward declaration: group 39 is a wrapper around any other group's body. */
static void ifu_body(unsigned g, u64 r);

/* Group 39: a wrapper, not a body. Randomise mhcr[0,4,5,6], mhint[8,10] and
 * mcor[16,17], run some other group's body, then put everything back. Biased
 * 7:1 toward enabled, and the report prints how many wrapped iterations ran
 * degraded -- so a run that spent half its time with the BTB switched off is
 * visible in the log rather than silently losing coverage.
 *
 * The sub-selector is `% 39`, so it can never pick group 39 itself and cannot
 * recurse. MHCR.DE is preserved by the write mask, so no DCACHE_SAFE_POINT is
 * owed here; the one MCOR invalidate that clears without writing back is
 * bracketed below. */
static void g_enable_mix(u64 r)
{
    u64 hcr = CSR_R(CSR_MHCR);
    u64 hint = CSR_R(CSR_MHINT);
    u64 nhcr = hcr;
    u64 nhint = hint;
    unsigned off = 0;

    if (IFU_SEL(r, 8, 8)  == 0u) { nhcr  &= ~MHCR_IE;         off++; }
    if (IFU_SEL(r, 11, 8) == 0u) { nhcr  &= ~MHCR_RSE;        off++; }
    if (IFU_SEL(r, 14, 8) == 0u) { nhcr  &= ~MHCR_BPE;        off++; }
    if (IFU_SEL(r, 17, 8) == 0u) { nhcr  &= ~MHCR_BTBE;       off++; }
    if (IFU_SEL(r, 20, 8) == 0u) { nhint &= ~MHINT_IPREF_EN;  off++; }
    if (IFU_SEL(r, 23, 8) == 0u) { nhint &= ~MHINT_IWPE;      off++; }

    CSR_W(CSR_MHCR, nhcr & MHCR_WMASK);
    CSR_W(CSR_MHINT, nhint & MHINT_WMASK);
    if (IFU_BIT(r, 26))
        CSR_W(CSR_MCOR, MCOR_BHT_INV);
    if (IFU_BIT(r, 27))
        CSR_W(CSR_MCOR, MCOR_BTB_INV);

    if (off)
        stat_en_degraded++;
    else
        stat_en_full++;

    ifu_body(IFU_SEL(r, 30, 39), r);

    CSR_W(CSR_MHCR, hcr & MHCR_WMASK);
    CSR_W(CSR_MHINT, hint & MHINT_WMASK);
}

/* Group 40: ifu_yy_xx_no_op = ref_fsm_idle && pf_fsm_idle
 * (aq_ifu_icache.v:1384), i.e. the IFU only reports itself quiet when neither
 * the demand-refill nor the prefetch FSM is busy. The noop blocks put a fence.i
 * at the head of a cold block 16 KB away, so it executes with the refill that
 * fetched it and the prefetch of the following line both outstanding; the
 * trailing ordering op then repeats that from the C side. */
static void g_no_op_fence(u64 r)
{
    u64 old = CSR_R(CSR_MHINT);

    CSR_S(CSR_MHINT, MHINT_IPREF_EN);
    ifu_cold();
    IFU_CALL_NOOP(r >> 8);

    switch (IFU_SEL(r, 12, 4)) {
    case 0:  __asm__ volatile ("fence.i" ::: "memory");    break;
    case 1:  __asm__ volatile ("sfence.vma" ::: "memory"); break;
    case 2:  TH_OP(TH_SYNC_I);                             break;
    default: TH_OP(TH_SYNC);                               break;
    }

    CSR_W(CSR_MHINT, old & MHINT_WMASK);
}

/* Group 41: strategy-(C) runtime code generation. Write raw RVC encodings into
 * the 4 KB .text.jit buffer, make them fetchable, enter by a jalr call and
 * leave by ret. Gated behind -DIFU_JIT and OFF by default: the same I-cache
 * refill and invalidate coverage is available more safely by re-running
 * generated arena code after th.icache.iall, and self-modifying code makes
 * every other failure in the run harder to read.
 *
 * The bytes written are a fixed whitelist (c.nop and c.jr ra), never a
 * rand_rnd() word cast to an instruction: a random word can be wfi, csrw
 * mtvec,x0, an arbitrary store or a wild jump. */
#ifdef IFU_JIT
static void g_jit(u64 r)
{
    volatile u16 *p = (volatile u16 *)(void *)ifu_jit_buf;
    unsigned n = 4u + IFU_SEL(r, 8, 24);
    unsigned i;

    for (i = 0; i < n; i++)
        p[i] = 0x0001;                          /* c.nop   */
    p[n] = 0x8082;                              /* c.jr ra */

    RAND_ICACHE_SYNC();
    ifu_far_call((u64)(unsigned long)ifu_jit_buf);
    stat_jit++;
}
#endif

/* ==================================================================== *
 * Dispatch
 * ==================================================================== */

/* The 42-arm body switch, with no hit counting: dispatch() counts, and group 39
 * calls this directly so that a wrapped body is not double-counted. */
static void ifu_body(unsigned g, u64 r)
{
    switch (g) {
    case 0:  g_redirect_prio(r);    break;
    case 1:  g_buf_chgflw(r);       break;
    case 2:  g_high_pc(r);          break;
    case 3:  g_reissue(r);          break;
    case 4:  g_lpmd_kill(r);        break;
    case 5:  g_ibuf_full_kill(r);   break;
    case 6:  g_iway_pred(r);        break;
    case 7:  g_set_conflict(r);     break;
    case 8:  g_walk(r);             break;
    case 9:  g_utlb_wfpa(r);        break;
    case 10: g_refill_abort(r);     break;
    case 11: g_prefetch(r);         break;
    case 12: g_noncacheable(r);     break;
    case 13: g_inv_all(r);          break;
    case 14: g_inv_pa(r);           break;
    case 15: g_inv_va_err(r);       break;
    case 16: g_mcins_readout(r);    break;
    case 17: g_ifetch_accfault(r);  break;
    case 18: g_expt_high(r);        break;
#ifdef IFU_MMU
    case 19: g_sv39_ifetch(r);      break;
#endif
    case 20: g_btb_fill16(r);       break;
    case 21: g_btb_mispred_clr(r);  break;
    case 22: g_btb_alias_64k(r);    break;
    case 23: g_btb_inv_en(r);       break;
    case 24: g_bht_lfsr_history(r); break;
    case 25: g_bht_repair_fsm(r);   break;
    case 26: g_bht_bypass(r);       break;
    case 27: g_bht_vghr_restore(r); break;
    case 28: g_bht_inv_en(r);       break;
    case 29: g_ras_depth(r);        break;
    case 30: g_ras_unbalanced(r);   break;
    case 31: g_ras_ret_stall(r);    break;
    /* 32..41 come from the sparse selector in dispatch(), or from
     * -DIFU_ONLY_GROUP */
    case 32: g_ras_16m(r);          break;
    case 33: g_ras_en_off(r);       break;
    case 34: g_delay_branch(r);     break;
    case 35: g_two_branch_group(r); break;
    case 36: g_straddle_2mod4(r);   break;
    case 37: g_ipack_shapes(r);     break;
    case 38: g_ibuf_rotate(r);      break;
    case 39: g_enable_mix(r);       break;
    case 40: g_no_op_fence(r);      break;
#ifdef IFU_JIT
    case 41: g_jit(r);              break;
#endif
    default: break;
    }
}

static void dispatch(u64 r)
{
#ifdef IFU_ONLY_GROUP
    /* Debug aid: build with -DIFU_ONLY_GROUP=n to run just one group, which is
     * how a group that hangs or misbehaves gets isolated. Groups 0..31 are the
     * main rotation; 32..41 are the sparse second selector.
     * tests/cases/ifu_random/run_groups.sh sweeps this. */
    unsigned g = (IFU_ONLY_GROUP);
#else
    unsigned g = (unsigned)(r % NGROUPS);
#endif

    /* Count a SELECTION as a hit only if ifu_body actually has a body for it.
     * Group 19 is compiled out unless -DIFU_MMU, and counting it anyway would
     * make the report show a group that never ran as having run -- exactly the
     * "a group that never fired" signal the report exists to give. Group 41 is
     * already excluded because its counter sits inside its own #ifdef below. */
    if (g < NGROUPS_TOTAL
#ifndef IFU_MMU
        && g != 19u
#endif
#ifndef IFU_JIT
        && g != 41u
#endif
       )
        group_hits[g]++;
    ifu_body(g, r);

#ifndef IFU_ONLY_GROUP
    /* The remaining groups are rarer, more expensive or wrappers, so they ride
     * a second and much sparser selector rather than diluting the main
     * rotation. */
    switch ((unsigned)((r >> 32) % 64u)) {
    case 0:  g_ras_16m(r);          group_hits[32]++; break;
    case 1:  g_ras_en_off(r);       group_hits[33]++; break;
    case 2:  g_delay_branch(r);     group_hits[34]++; break;
    case 3:  g_two_branch_group(r); group_hits[35]++; break;
    case 4:  g_straddle_2mod4(r);   group_hits[36]++; break;
    case 5:  g_ipack_shapes(r);     group_hits[37]++; break;
    case 6:  g_ibuf_rotate(r);      group_hits[38]++; break;
    case 7:  g_enable_mix(r);       group_hits[39]++; break;
    case 8:  g_no_op_fence(r);      group_hits[40]++; break;
    case 9:
#ifdef IFU_JIT
        g_jit(r);                   group_hits[41]++;
#endif
        break;
    default: break;
    }
#endif
}

/* ==================================================================== *
 * End-of-run summary over the UART.
 *
 * Diagnostics only: PASS/FAIL is the GPR magic value crt0.s __exit writes, and
 * the real evidence of IFU stimulus is the port-toggle report. What this print
 * is for is spotting a run that did not do what it thought it was doing -- a
 * group that never fired, a trap-cause distribution that does not match the
 * groups that ran, or an enable_mix that spent most of its time with the
 * predictors switched off.
 * ==================================================================== */
static void report(void)
{
    unsigned i;

    rand_restore_sane_state();
    rand_report_begin();

    rand_puts("\n[ifu_random] iters=");
    rand_putu(rand_iter);
    rand_puts(" arena=0x");
    rand_putx(IFU_ARENA_BASE);
    rand_putc('-');
    rand_putx(IFU_ARENA_END);
    rand_puts(" layout_seed=0x");
    rand_putx(IFU_ARENA_SEED);

    rand_puts("\n[ifu_random] groups:");
    for (i = 0; i < NGROUPS_TOTAL; i++) {
        rand_putc(' ');
        rand_putu(group_hits[i]);
    }

    /* The sparsified groups fired far less often than they were selected, so
     * their own counters are what say whether they ran at all. */
    rand_puts("\n[ifu_random] highpc=");
    rand_putu(stat_highpc);
    rand_puts(" walk=");
    rand_putu(stat_walk);
    rand_puts(" far16m=");
    rand_putu(stat_far);
    rand_puts(" jit=");
    rand_putu(stat_jit);
    rand_puts(" enmix_full=");
    rand_putu(stat_en_full);
    rand_puts(" enmix_degraded=");
    rand_putu(stat_en_degraded);

    rand_hist_dump("ifu_random");

    /* Informational fingerprint. rand_sink is NOT compared against anything --
     * it exists so the compiler cannot dead-code the instruction under test. */
    rand_puts("[ifu_random] sink=0x");
    rand_putx(rand_sink);
    rand_putc('\n');

    rand_report_end();
}

/* ==================================================================== *
 * main
 * ==================================================================== */
int main(void)
{
    rand_srand((u64)IFU_SEED);
    rand_trap_init();                  /* FIRST: clears MIE, installs mtvec */
    rand_pmp_open_everything();
    rand_restore_sane_state();

    /* Give the arena's load targets a non-zero, non-uniform starting value so
     * the D-cache-missing loads in the stall and rot blocks are not all reading
     * the same line-worth of zeros. */
    {
        unsigned i;
        for (i = 0; i < 512u; i++)
            ifu_data[i] = 0x0F0F0F0F00000000UL + (u64)i * 0x9E3779B97F4A7C15UL;
    }

    for (rand_iter = 0; rand_iter < (u64)IFU_ITERS; rand_iter++) {
        if (rand_setjmp() != 0) {      /* trap-handler bail-out landing pad */
            rand_recovered++;
            rand_restore_sane_state();
            rand_pmp_open_everything();
            continue;
        }

        dispatch(rand_rnd());

        if ((rand_iter & 0xFFFu) == 0u) {
            rand_restore_sane_state();
            rand_pmp_open_everything();
        }
    }

    rand_restore_sane_state();
    report();

    /* Returning lands in crt0.s __exit, which materialises the PASS magic the
     * testbench is watching the RTU writeback buses for. */
    return 0;
}
