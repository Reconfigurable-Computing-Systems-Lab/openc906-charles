/*
 * CSR numbers, writable-bit masks, SoC MMIO addresses and the trap-context
 * layout shared by the per-unit randomized stress tests (iu_random,
 * vidu_random, idu_random, ifu_random).
 *
 * Derived from cp0_random/cp0_csrs.h, which carries the full RTL provenance for
 * every address and mask below:
 *   addresses            C906_RTL_FACTORY/gen_rtl/cp0/rtl/aq_cp0_regs.v:635-939
 *   trap CSR fields                                    aq_cp0_trap_csr.v
 *   T-Head extension fields                            aq_cp0_ext_csr.v
 *   float CSR fields                                   aq_cp0_float_csr.v
 *   counter policy                                     aq_cp0_hpcp_csr.v
 *   satp                                               aq_cp0_prtc_csr.v
 *   CLINT / PLIC map      gen_rtl/{clint,plic}/rtl/, gen_rtl/biu/rtl/aq_biu_apbif.v
 *
 * Included from both C and assembly, so everything here is a #define.
 */

#ifndef RAND_CSRS_H
#define RAND_CSRS_H

/* ==================================================================== *
 * Trap-context layout (rand_ctx, see rand_trap.S)
 *
 * Every offset must stay < 2048 so the handler can reach it with a plain
 * ld/sd immediate: RCTX_SCOUNT + 63*8 = 1224 is the largest one used.
 * ==================================================================== */
#define RCTX_S_T0        0
#define RCTX_S_T1        8
#define RCTX_S_T2        16
#define RCTX_S_A0        24
#define RCTX_S_ST0       32
#define RCTX_S_ST1       40
#define RCTX_S_ST2       48
#define RCTX_DEPTH       56
#define RCTX_MODE_RET    64
#define RCTX_JMP_SP      72
#define RCTX_JMP_RA      80
#define RCTX_JMP_S       88      /* s0..s11, 12 * 8 = 96 bytes */
#define RCTX_NESTED      184     /* times we had to longjmp out of a trap */
#define RCTX_TOTAL       192     /* all M-mode traps                     */
#define RCTX_STOTAL      200     /* all S-mode (delegated) traps          */
#define RCTX_COUNT       208     /* u64[64], index {intr, cause[4:0]}     */
#define RCTX_SCOUNT      720     /* u64[64], same index, S-mode           */
#define RCTX_MODE_RA     1232    /* caller's ra across a trip to S/U       */
#define RCTX_MODE_SP     1240    /* caller's sp across a trip to S/U       */
/* While non-zero, any synchronous exception resumes here instead of stepping
 * over the faulting instruction. This is what makes rand_run_at() safe: a
 * deliberate excursion to a faulting fetch address comes straight back to its
 * landing pad instead of trying to single-step through a page that faults on
 * every fetch. */
#define RCTX_FAULT_RET   1248
#define RCTX_FAULTS      1256    /* excursions that came back via FAULT_RET */
#define RCTX_SIZE        1264

/* ==================================================================== *
 * Standard machine CSRs
 * ==================================================================== */
#define CSR_MSTATUS     0x300
#define CSR_MISA        0x301
#define CSR_MEDELEG     0x302
#define CSR_MIDELEG     0x303
#define CSR_MIE         0x304
#define CSR_MTVEC       0x305
#define CSR_MCNTEN      0x306   /* mcounteren */
#define CSR_MCNTIHBT    0x320   /* T-Head name for mcountinhibit */
#define CSR_MSCRATCH    0x340
#define CSR_MEPC        0x341
#define CSR_MCAUSE      0x342
#define CSR_MTVAL       0x343
#define CSR_MIP         0x344
#define CSR_MVENDORID   0xF11
#define CSR_MARCHID     0xF12
#define CSR_MIMPID      0xF13
#define CSR_MHARTID     0xF14

/* Supervisor */
#define CSR_SSTATUS     0x100
#define CSR_SIE         0x104
#define CSR_STVEC       0x105
#define CSR_SCNTEN      0x106
#define CSR_SSCRATCH    0x140
#define CSR_SEPC        0x141
#define CSR_SCAUSE      0x142
#define CSR_STVAL       0x143
#define CSR_SIP         0x144
#define CSR_SATP        0x180

/* Float (aq_cp0_float_csr.v) */
#define CSR_FFLAGS      0x001
#define CSR_FRM         0x002
#define CSR_FCSR        0x003
#define CSR_FXCR        0x800   /* T-Head, U-mode window */

/* T-Head machine extension CSRs (aq_cp0_ext_csr.v) */
#define CSR_MXSTATUS    0x7C0
#define CSR_MHCR        0x7C1
#define CSR_MCOR        0x7C2
#define CSR_MHINT       0x7C5
#define CSR_MCNTWEN     0x7C9
#define CSR_MCNTINTEN   0x7CA
#define CSR_MCNTOF      0x7CB
#define CSR_MHINT2      0x7CC
#define CSR_MCINS       0x7D2   /* write-only, reads 0 */
#define CSR_MCINDEX     0x7D3
#define CSR_MCDATA0     0x7D4   /* RO capture */
#define CSR_MCDATA1     0x7D5   /* RO capture */
#define CSR_MHPMCR      0x7F0
#define CSR_MCPUID      0xFC0   /* RO, index self-increments on every read */
#define CSR_MAPBADDR    0xFC1

/* Counters (implemented in the HPCP, aq_hpcp_top.v) */
#define CSR_MCYCLE      0xB00
#define CSR_MINSTRET    0xB02
#define CSR_MHPMCNT3    0xB03
#define CSR_MHPMCNT4    0xB04
#define CSR_MHPMCNT5    0xB05
#define CSR_MHPMCNT6    0xB06
#define CSR_MHPMEVT3    0x323
#define CSR_MHPMEVT4    0x324
#define CSR_MHPMEVT5    0x325
#define CSR_MHPMEVT6    0x326
#define CSR_CYCLE       0xC00
#define CSR_TIME        0xC01   /* == CPU cycle count on this SoC */
#define CSR_INSTRET     0xC02

/* PMP */
#define CSR_PMPCFG0     0x3A0
#define CSR_PMPADDR0    0x3B0

/* ==================================================================== *
 * Field masks / bit positions
 * ==================================================================== */
/* mstatus (aq_cp0_trap_csr.v:729-733). Writable bits only. */
#define MSTATUS_SIE     0x00000002UL
#define MSTATUS_MIE     0x00000008UL
#define MSTATUS_SPIE    0x00000020UL
#define MSTATUS_MPIE    0x00000080UL
#define MSTATUS_SPP     0x00000100UL
#define MSTATUS_MPP     0x00001800UL
#define MSTATUS_MPP_S   0x00000800UL   /* MPP = 01 */
#define MSTATUS_FS      0x00006000UL
#define MSTATUS_FS_INIT 0x00002000UL
#define MSTATUS_FS_CLEAN 0x00002000UL
#define MSTATUS_FS_DIRTY 0x00006000UL
#define MSTATUS_MPRV    0x00020000UL
#define MSTATUS_SUM     0x00040000UL
#define MSTATUS_MXR     0x00080000UL
#define MSTATUS_TVM     0x00100000UL
#define MSTATUS_TW      0x00200000UL
#define MSTATUS_TSR     0x00400000UL
#define MSTATUS_WMASK   0x007E61AAUL
#define SSTATUS_WMASK   0x000C6122UL

/* mie / mip: msie 3, stie 5, mtie 7, seie 9, meie 11, moie 17. */
#define MIE_WMASK       0x00020AAAUL
#define MIP_SW_MASK     0x00000222UL   /* only ssip(1) stip(5) seip(9) */
#define IRQ_SSIP        (1UL << 1)
#define IRQ_MSIP        (1UL << 3)
#define IRQ_STIP        (1UL << 5)
#define IRQ_MTIP        (1UL << 7)
#define IRQ_SEIP        (1UL << 9)
#define IRQ_MEIP        (1UL << 11)
#define IRQ_MOIP        (1UL << 17)

#define MEDELEG_WMASK   0x0000B3FFUL
#define MEDELEG_SAFE    (MEDELEG_WMASK & ~0x300UL)
#define MIDELEG_WMASK   0x00020222UL

#define TVEC_MODE_VECTORED 0x1UL

/* mxstatus (aq_cp0_ext_csr.v:643-647). */
#define MXSTATUS_PMDU      (1UL << 10)
#define MXSTATUS_PMDS      (1UL << 11)
#define MXSTATUS_PMDM      (1UL << 13)
#define MXSTATUS_MM        (1UL << 15)  /* hardware misaligned support */
#define MXSTATUS_UCME      (1UL << 16)  /* U-mode cache maintenance    */
#define MXSTATUS_CLINTEE   (1UL << 17)
#define MXSTATUS_MHRD      (1UL << 18)
#define MXSTATUS_MAEE      (1UL << 21)
#define MXSTATUS_THEADISAEE (1UL << 22) /* 0 => every th.* op illegal  */
#define MXSTATUS_WMASK     0x00CEB800UL
#define MXSTATUS_RESET     0xC06B8000UL

/* mhcr (:724-725). wb(3) and wbr(8) always read 1. */
#define MHCR_IE         (1UL << 0)
#define MHCR_DE         (1UL << 1)
#define MHCR_WA         (1UL << 2)
#define MHCR_RSE        (1UL << 4)      /* RAS enable  */
#define MHCR_BPE        (1UL << 5)      /* BHT enable  */
#define MHCR_BTBE       (1UL << 6)      /* BTB enable  */
#define MHCR_WMASK      0x77UL
#define MHCR_ALL_ON     0x7FUL          /* what crt0.s leaves behind */

/* mhint (:909-915) */
#define MHINT_DPREF_EN  (1UL << 2)
#define MHINT_AMR       (3UL << 3)
#define MHINT_IPREF_EN  (1UL << 8)      /* I-cache next-line prefetch */
#define MHINT_IWPE      (1UL << 10)     /* I-cache way prediction     */
#define MHINT_DPREF_DST (3UL << 13)
#define MHINT_WMASK     0x0100651CUL
#define MHINT_BASE      0x610CUL        /* what crt0.s leaves behind */

/* mhint2 (:933-934): module_icg_en[8:0] = bits 22:14 */
#define MHINT2_ICG_EN   0x007FC000UL
#define MHINT2_WMASK    0x00FFC000UL

/* mcor (:836-837). Bit 4 drives BOTH icache_inv and dcache_inv; sel is a
 * persistent register, so an op and its sel must be written together. */
#define MCOR_SEL_I      0x1UL
#define MCOR_SEL_D      0x2UL
#define MCOR_INV        (1UL << 4)
#define MCOR_CLR        (1UL << 5)
#define MCOR_BHT_INV    (1UL << 16)
#define MCOR_BTB_INV    (1UL << 17)
#define MCOR_WMASK      0x00030033UL

/* mcindex (:1057): rid[31:28], way[24:21], index[20:0] */
#define MCINDEX_RID(x)   (((unsigned long)(x) & 0xFUL) << 28)
#define MCINDEX_WAY(x)   (((unsigned long)(x) & 0xFUL) << 21)
#define MCINDEX_IDX(x)   ((unsigned long)(x) & 0x1FFFFFUL)

/* satp: only Bare (0) and Sv39 (8) are reachable. */
#define SATP_SV39       (8UL << 60)

/* fxcr (aq_cp0_float_csr.v:307-309): bf16 31, frm 26:24, dqnan 23, fe 5,
 * fflags 4:0. */
#define FXCR_WMASK      0x8780003FUL

/* fcsr / fflags */
#define FFLAGS_NX       (1UL << 0)
#define FFLAGS_UF       (1UL << 1)
#define FFLAGS_OF       (1UL << 2)
#define FFLAGS_DZ       (1UL << 3)
#define FFLAGS_NV       (1UL << 4)
#define FCSR_FRM_SHIFT  5

/* ==================================================================== *
 * SoC MMIO. apb_base is tied to 40'h4000000000; the BIU decodes the CLINT at
 * +0x04000000 and the PLIC at +0 (aq_biu_apbif.v:283-292).
 *
 * All of these need 32-bit accesses: aq_biu_apbif.v:277-288 selects a single
 * 32-bit lane out of the 128-bit write data, so a 64-bit store would only land
 * half of itself. All are M-mode only.
 * ==================================================================== */
#define CLINT_MSIP0       0x4004000000UL
#define CLINT_MTIMECMPL   0x4004004000UL
#define CLINT_MTIMECMPH   0x4004004004UL
#define CLINT_SSIP0       0x400400C000UL
#define CLINT_STIMECMPL   0x400400D000UL
#define CLINT_STIMECMPH   0x400400D004UL

#define PLIC_MTH_H0       0x4000200000UL
#define PLIC_MCLAIM_H0    0x4000200004UL

/* UART0 THR. This region is cacheable (mmu/rtl/sysmap.h region 0), so a store
 * only reaches the bus -- and the testbench's console snooper -- with the
 * D-cache disabled. See rand_report_begin() in rand_lib.c. */
#define UART_THR          0x10015000UL

/* ==================================================================== *
 * Address-window rules for these tests. Violating them breaks the test, not
 * the DUT, so they are written down here rather than in a comment somewhere.
 *
 *   0x0000_0000 .. 0x0016_3830  wiped and loadable by tb.v:98  -- SAFE
 *   0x0100_0000 .. + input.pat  loaded by tb.v (the NN input window) -- SAFE
 *                               for exactly as many bytes as input.pat supplies
 *   0x0016_3840 .. 0x0FFF_FFFF  NOT wiped: reads X under VCS (0 under
 *                               Verilator). Never fetch, never load.
 *   0x1000_0000 .. 0x1FFF_FFFF  AXI -> AHB -> APB. An I-cache refill here is a
 *                               4-beat 16-byte WRAP burst that axi2ahb.v cannot
 *                               service. NEVER fetch, never th.icache.ipa.
 *   0x2000_0000 and above       error slave: returns zeros with rresp=OKAY
 *                               (axi_err128.v:208,211), i.e. a clean
 *                               illegal-instruction trap. SAFE but pointless
 *                               for data.
 *
 * Fault levers, from gen_rtl/mmu/rtl/sysmap.h (verified):
 *   region 0  PA < 0x8FFF_F000   FLG 5'b01111  cacheable, executable
 *   region 1  PA < 0xBFFF_F000   FLG 5'b10011  STRONG ORDER -> exec denied with
 *                                no M-mode escape (aq_mmu_utlb.v:788-790), so
 *                                fetching here is an instruction ACCESS FAULT
 *   region 2  PA < 0xCFFF_F000   FLG 5'b00011  non-cacheable, executable
 * ==================================================================== */
#define RAND_SAFE_LO        0x00000000UL
#define RAND_SAFE_HI        0x00163830UL
#define RAND_FAR_BASE       0x01000000UL   /* input.pat window (16 MB)      */
#define RAND_APB_LO         0x10000000UL   /* do not touch as instructions  */
#define RAND_APB_HI         0x1FFFFFFFUL
#define RAND_SO_BASE        0x8FFFF000UL   /* sysmap region 1: exec denied  */
#define RAND_SO_LAST_OK     0x8FFFEFFEUL   /* last 2 bytes of region 0      */
#define RAND_NC_BASE        0xBFFFF000UL   /* sysmap region 2: non-cacheable*/
#define RAND_ERR_BASE       0x20000000UL   /* error slave: reads as zeros   */

#endif /* RAND_CSRS_H */
