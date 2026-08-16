/*
 * CSR numbers, writable-bit masks, SoC MMIO addresses and the trap-context
 * layout for the cp0_random stress test.
 *
 * Every CSR number and every mask below was read out of the RTL, not out of a
 * manual (the PDFs in doc/pdfs/ are not text-extractable):
 *   addresses            C906_RTL_FACTORY/gen_rtl/cp0/rtl/aq_cp0_regs.v:635-939
 *   trap CSR fields                                    aq_cp0_trap_csr.v
 *   T-Head extension fields                            aq_cp0_ext_csr.v
 *   float CSR fields                                   aq_cp0_float_csr.v
 *   counter policy                                     aq_cp0_hpcp_csr.v
 *   satp                                               aq_cp0_prtc_csr.v
 *   MMU/TLB CSR fields               gen_rtl/mmu/rtl/aq_mmu_regs.v
 *   CLINT / PLIC map      gen_rtl/{clint,plic}/rtl/, gen_rtl/biu/rtl/aq_biu_apbif.v
 *
 * Included from both C and assembly, so everything here is either a #define or
 * guarded by #ifndef __ASSEMBLER__.
 */

#ifndef CP0_CSRS_H
#define CP0_CSRS_H

/* ==================================================================== *
 * Trap-context layout (cp0_ctx, see cp0_trap.S)
 *
 * Every offset must stay < 2048 so the handler can reach it with a plain
 * ld/sd immediate: CTX_SCOUNT + 63*8 = 1224 is the largest one used.
 * ==================================================================== */
#define CTX_S_T0        0
#define CTX_S_T1        8
#define CTX_S_T2        16
#define CTX_S_A0        24
#define CTX_S_ST0       32
#define CTX_S_ST1       40
#define CTX_S_ST2       48
#define CTX_DEPTH       56
#define CTX_MODE_RET    64
#define CTX_JMP_SP      72
#define CTX_JMP_RA      80
#define CTX_JMP_S       88      /* s0..s11, 12 * 8 = 96 bytes */
#define CTX_NESTED      184     /* times we had to longjmp out of a trap */
#define CTX_TOTAL       192     /* all M-mode traps                     */
#define CTX_STOTAL      200     /* all S-mode (delegated) traps         */
#define CTX_COUNT       208     /* u64[64], index {intr, cause[4:0]}    */
#define CTX_SCOUNT      720     /* u64[64], same index, S-mode          */
#define CTX_MODE_RA     1232    /* caller's ra across a trip to S/U      */
#define CTX_MODE_SP     1240    /* caller's sp across a trip to S/U      */
#define CTX_SIZE        1248

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
#define CSR_MCCR2       0x7C3   /* RO 0 */
#define CSR_MCER2       0x7C4   /* RO 0 */
#define CSR_MHINT       0x7C5
#define CSR_MRMR        0x7C6   /* RO 0 */
#define CSR_MRVBR       0x7C7   /* RO, tied to biu_cp0_rvba */
#define CSR_MCER        0x7C8   /* RO 0 */
#define CSR_MCNTWEN     0x7C9
#define CSR_MCNTINTEN   0x7CA
#define CSR_MCNTOF      0x7CB
#define CSR_MHINT2      0x7CC
#define CSR_MHINT3      0x7CD   /* RO 0 */
#define CSR_MHINT4      0x7CE   /* RO 0 */
#define CSR_MCINS       0x7D2   /* write-only, reads 0 */
#define CSR_MCINDEX     0x7D3
#define CSR_MCDATA0     0x7D4   /* RO capture */
#define CSR_MCDATA1     0x7D5   /* RO capture */
#define CSR_MEICR       0x7D6   /* RO 0 */
#define CSR_MEICR2      0x7D7   /* RO 0 */
#define CSR_MHPMCR      0x7F0
#define CSR_MHPMSP      0x7F1
#define CSR_MHPMEP      0x7F2
#define CSR_MCPUID      0xFC0   /* RO, index self-increments on every read */
#define CSR_MAPBADDR    0xFC1   /* RO, = sysio_cp0_apb_base */

/* T-Head supervisor extension CSRs */
#define CSR_SXSTATUS    0x5C0
#define CSR_SHCR        0x5C1   /* RO mirror of MHCR */
#define CSR_SCER2       0x5C2   /* RO 0 */
#define CSR_SCER        0x5C3   /* RO 0 */
#define CSR_SCNTINTEN   0x5C4
#define CSR_SCNTOF      0x5C5
#define CSR_SHINT       0x5C6   /* RO 0 */
#define CSR_SHINT2      0x5C7   /* RO 0 */
#define CSR_SCNTIHBT    0x5C8
#define CSR_SHPMCR      0x5C9
#define CSR_SHPMSP      0x5CA
#define CSR_SHPMEP      0x5CB
#define CSR_SCYCLE      0x5E0
#define CSR_SINSTRET    0x5E2

/* MMU / jTLB access window (implemented in aq_mmu_regs.v) */
#define CSR_SMIR        0x9C0
#define CSR_SMEL        0x9C1
#define CSR_SMEH        0x9C2
#define CSR_SMCIR       0x9C3

/* Debug / trigger (implemented in the DTU) */
#define CSR_TSELECT     0x7A0
#define CSR_TDATA1      0x7A1
#define CSR_TDATA2      0x7A2
#define CSR_TDATA3      0x7A3
#define CSR_TINFO       0x7A4   /* writes forced illegal */
#define CSR_TCONTROL    0x7A5
#define CSR_MCONTEXT    0x7A8
#define CSR_SCONTEXT    0x7AA   /* the one 0x7xx CSR S mode may touch */
#define CSR_DCSR        0x7B0   /* illegal outside debug mode */
#define CSR_DPC         0x7B1
#define CSR_DSCRATCH0   0x7B2
#define CSR_DSCRATCH1   0x7B3
#define CSR_MHALTCAUSE  0xFE0
#define CSR_MDBGINFO    0xFE1
#define CSR_MPCFIFO     0xFE2   /* reading pops the DTU PC FIFO */

/* Counters (implemented in the HPCP) */
#define CSR_MCYCLE      0xB00
#define CSR_MINSTRET    0xB02
#define CSR_CYCLE       0xC00
#define CSR_TIME        0xC01   /* == CPU cycle count on this SoC */
#define CSR_INSTRET     0xC02

/* PMP */
#define CSR_PMPCFG0     0x3A0
#define CSR_PMPCFG2     0x3A2
#define CSR_PMPADDR0    0x3B0

/* Vector CSRs -- present in the parameter table and the read mux but in
 * neither illegal-decode case, so all six always trap (audit §12). */
#define CSR_VSTART      0x008
#define CSR_VXSAT       0x009
#define CSR_VXRM        0x00A
#define CSR_VL          0xC20
#define CSR_VTYPE       0xC21
#define CSR_VLENB       0xC22

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
#define MSTATUS_MPRV    0x00020000UL
#define MSTATUS_SUM     0x00040000UL
#define MSTATUS_MXR     0x00080000UL
#define MSTATUS_TVM     0x00100000UL
#define MSTATUS_TW      0x00200000UL
#define MSTATUS_TSR     0x00400000UL
#define MSTATUS_WMASK   0x007E61AAUL
/* sstatus writable subset (:742-745) */
#define SSTATUS_WMASK   0x000C6122UL

/* mie / mip: msie 3, stie 5, mtie 7, seie 9, meie 11, moie 17.
 * mhie(18)/mcie(16) are hardwired 0. */
#define MIE_WMASK       0x00020AAAUL
#define MIP_SW_MASK     0x00000222UL   /* only ssip(1) stip(5) seip(9) */
#define IRQ_SSIP        (1UL << 1)
#define IRQ_MSIP        (1UL << 3)
#define IRQ_STIP        (1UL << 5)
#define IRQ_MTIP        (1UL << 7)
#define IRQ_SEIP        (1UL << 9)
#define IRQ_MEIP        (1UL << 11)
#define IRQ_MOIP        (1UL << 17)

/* medeleg: bits 10, 11 and 14 are hardwired 0, so ecall-from-M can never be
 * delegated. We additionally keep 8 and 9 clear ourselves, because ecall from
 * U/S is how lower-mode code hands control back to the M-mode driver. */
#define MEDELEG_WMASK   0x0000B3FFUL
#define MEDELEG_SAFE    (MEDELEG_WMASK & ~0x300UL)
#define MIDELEG_WMASK   0x00020222UL

/* mtvec / stvec: base[63:2] plus mode, but the read path re-assembles as
 * {base, 1'b0, mode[0]}, so bit 1 always reads 0 (:956). */
#define TVEC_MODE_VECTORED 0x1UL

/* mxstatus (aq_cp0_ext_csr.v:643-647). Reset value has cskyisaee, maee,
 * clintee, ucme and mm all set. */
#define MXSTATUS_PMDU      (1UL << 10)
#define MXSTATUS_PMDS      (1UL << 11)
#define MXSTATUS_PMDM      (1UL << 13)
#define MXSTATUS_MM        (1UL << 15)  /* hardware misaligned support */
#define MXSTATUS_UCME      (1UL << 16)  /* U-mode cache maintenance    */
#define MXSTATUS_CLINTEE   (1UL << 17)  /* gates CLINT S timer/soft    */
#define MXSTATUS_MHRD      (1UL << 18)  /* 1 => hardware PTW DISABLED  */
#define MXSTATUS_INSDE     (1UL << 19)
#define MXSTATUS_MAEE      (1UL << 21)
#define MXSTATUS_THEADISAEE (1UL << 22) /* 0 => every th.* op illegal  */
#define MXSTATUS_WMASK     0x00CEB800UL
#define MXSTATUS_RESET     0xC06B8000UL

/* mhcr (:724-725). wb(3) and wbr(8) always read 1. */
#define MHCR_IE         (1UL << 0)
#define MHCR_DE         (1UL << 1)
#define MHCR_WA         (1UL << 2)
#define MHCR_RSE        (1UL << 4)
#define MHCR_BPE        (1UL << 5)   /* drives the BHT enable */
#define MHCR_BTBE       (1UL << 6)
#define MHCR_WMASK      0x77UL
#define MHCR_ALL_ON     0x7FUL       /* what crt0.s leaves behind */

/* mhint (:909-915) */
#define MHINT_DPREF_EN  (1UL << 2)
#define MHINT_AMR       (3UL << 3)
#define MHINT_IPREF_EN  (1UL << 8)
#define MHINT_IWPE      (1UL << 10)
#define MHINT_DPREF_DST (3UL << 13)
#define MHINT_PCFIFO_FRZ (1UL << 24)
#define MHINT_WMASK     0x0100651CUL
#define MHINT_BASE      0x610CUL     /* what crt0.s leaves behind */

/* mhint2 (:933-934): module_icg_en[8:0] = bits 22:14, fence_in_dbg_dis = 23 */
#define MHINT2_ICG_EN   0x007FC000UL
#define MHINT2_FENCE_DBG (1UL << 23)
#define MHINT2_WMASK    0x00FFC000UL

/* mcor (:836-837): btb_inv 17, bht_inv 16, clr 5, inv 4, sel[1:0] 1:0.
 * Bit 4 drives BOTH icache_inv and dcache_inv; sel is a persistent register,
 * so an op and its sel must be written by the same instruction. */
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

/* satp (aq_cp0_prtc_csr.v:133-158): the mode write is gated on
 * wdata[62:60]==0 and forced to {wdata[63],3'b0}, so only Bare (0) and
 * Sv39 (8) are reachable. */
#define SATP_SV39       (8UL << 60)
#define SATP_ASID(x)    (((unsigned long)(x) & 0xFFFFUL) << 44)
#define SATP_PPN(x)     ((unsigned long)(x) & 0x0FFFFFFFUL)

/* smcir (aq_mmu_regs.v:499-517), priority invall > invasid > tlbp > tlbwi >
 * tlbwr > tlbr. A write with none of 31:26 set completes immediately. */
#define SMCIR_TLBP      (1UL << 31)
#define SMCIR_TLBR      (1UL << 30)
#define SMCIR_TLBWI     (1UL << 29)
#define SMCIR_TLBWR     (1UL << 28)
#define SMCIR_INVASID   (1UL << 27)
#define SMCIR_INVALL    (1UL << 26)

/* fxcr (aq_cp0_float_csr.v:307-309): bf16 31, frm 26:24, dqnan 23, fe 5,
 * fflags 4:0. dqnan drives cp0_vpu_xx_dqnan, so bit 23 must be in the mask. */
#define FXCR_WMASK      0x8780003FUL

/* ==================================================================== *
 * SoC MMIO. apb_base is tied to 40'h4000000000 in
 * smart_run/logical/common/tr_axi_interconnect.v:963; the BIU decodes the
 * CLINT at +0x04000000 and the PLIC at +0 (aq_biu_apbif.v:283-292).
 *
 * All of these need 32-bit accesses: aq_biu_apbif.v:277-288 selects a single
 * 32-bit lane out of the 128-bit write data, so a 64-bit store would only
 * land half of itself. All are M-mode only (pprot checks).
 * ==================================================================== */
#define CLINT_MSIP0       0x4004000000UL
#define CLINT_MTIMECMPL   0x4004004000UL
#define CLINT_MTIMECMPH   0x4004004004UL
/* The S-mode side of the CLINT. These drive biu_cp0_ss_int / biu_cp0_st_int,
 * which reach mip only when MXSTATUS.CLINTEE is set, and which CANNOT be
 * cleared through mip (mip only owns ssip_reg/stip_reg) -- the CLINT register
 * itself has to be written back. */
#define CLINT_SSIP0       0x400400C000UL
#define CLINT_STIMECMPL   0x400400D000UL
#define CLINT_STIMECMPH   0x400400D004UL

#define PLIC_PRIO         0x4000000000UL   /* + 4*id            */
#define PLIC_PENDING      0x4000001000UL   /* + 4*(id/32)       */
#define PLIC_MIE_H0       0x4000002000UL   /* + 4*(id/32)       */
#define PLIC_SIE_H0       0x4000002080UL
#define PLIC_MTH_H0       0x4000200000UL
#define PLIC_MCLAIM_H0    0x4000200004UL
#define PLIC_STH_H0       0x4000201000UL   /* S context: +0x2000 stride */
#define PLIC_SCLAIM_H0    0x4000201004UL
/* Source 1 has no hardware wire (openC906.v:951 ties plic_int_vld[1] to 0),
 * so it can only ever be raised by writing PENDING -- exactly what
 * tests/cases/interrupt/C906_plic_int_smoke.s does. */
#define PLIC_SW_SOURCE    1

/* UART0 THR. The real base on this SoC is 0x1001_5000 (apb_bridge.v:34,
 * logical/apb/apb.v:232), which is also the address the testbench snoops on the
 * CPU's AXI port to echo bytes into work/run_case.report (tb.v:345-370).
 *
 * Note tests/lib/clib/uart.h says 0x4001_5000 -- that is stale for this SoC,
 * exactly like timer.h's SMART_TIMER_BASE. nn_model_common/bare_main.c uses
 * 0x1001_5000, which is correct.
 *
 * This region is cacheable (mmu/rtl/sysmap.h region 0), so a store only reaches
 * the bus with the D-cache disabled -- see report() in C906_CP0_RANDOM.c. */
#define UART_THR          0x10015000UL

#ifndef __ASSEMBLER__

typedef unsigned long u64;

extern void cp0_trap_init(void);
extern void cp0_trap_m(void);
extern void cp0_trap_m_vectored(void);
extern void cp0_trap_s(void);
extern void cp0_run_in_smode(void (*fn)(void));
extern void cp0_run_in_umode(void (*fn)(void));
extern void cp0_sret_land(void);   /* where a legal S-mode SRET lands */
extern int  cp0_setjmp(void);
extern void cp0_longjmp(void);
extern unsigned char cp0_ctx[CTX_SIZE];

/* Accessors for the fields the C side reports on. */
#define CTX_U64(off)  (*(volatile u64 *)((unsigned char *)cp0_ctx + (off)))

#endif /* !__ASSEMBLER__ */

#endif /* CP0_CSRS_H */
