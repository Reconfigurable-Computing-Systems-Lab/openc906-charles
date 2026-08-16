/*
 * T-Head (Xtheadc) cache / sync instruction encodings for the OpenC906, plus
 * the other raw encodings this test needs.
 *
 * Emitted as raw .word rather than mnemonics on purpose: on this Mac the
 * toolchain runs with THEAD_GCC=0 (setup/mac_setup.sh), i.e.
 * -march=rv64imafdc_zfh_zicsr_zifencei, which has neither xtheadcmo nor
 * xtheadsync, so `th.dcache.iall` will not assemble. Raw words assemble
 * identically under the server's Xuantie GCC, so one source builds in both
 * places.
 *
 * Format: opcode 0001011 (custom-0), funct3 000, rd 00000, inst[31:26] 000000.
 * The IDU sub-decodes on {inst[25], inst[24:20], inst[19:15]} only
 * (gen_rtl/idu/rtl/aq_idu_id_decd.v:3002), so inst[31:26] is a don't-care; the
 * canonical zero encoding is used here. Every one of these is illegal when
 * MXSTATUS.THEADISAEE (bit 22) is clear (aq_idu_id_decd.v:1005).
 */

#ifndef CP0_TH_INSN_H
#define CP0_TH_INSN_H

/* --- no-operand forms (rs1 = x0) -------------------------------------- *
 * Executed inside CP0; aq_cp0_cache_inst.v splits func into {type,op,dst}. */
#define TH_DCACHE_CALL      0x0010000b  /* D$ clean all                    */
#define TH_DCACHE_IALL      0x0020000b  /* D$ invalidate all, NO writeback  */
#define TH_DCACHE_CIALL     0x0030000b  /* D$ clean + invalidate all        */
/* Re-encoded by the IDU as FUNC_FENCEI -- behave exactly like fence.i */
#define TH_ICACHE_IALL      0x0100000b
#define TH_ICACHE_IALLS     0x0110000b
/* dst decodes to 2'b00 -> silent no-op in this core (no L2 present) */
#define TH_L2CACHE_CALL     0x0150000b
#define TH_L2CACHE_IALL     0x0160000b
#define TH_L2CACHE_CIALL    0x0170000b
/* Ordering ops -> FUNC_SYNC / FUNC_SYNCI. Legal even in U mode. */
#define TH_SYNC             0x0180000b
#define TH_SYNC_S           0x0190000b
#define TH_SYNC_I           0x01a0000b
#define TH_SYNC_IS          0x01b0000b

/* --- rs1 forms: OR in (regnum << 15) --------------------------------- */
/* Set/way ops, executed inside CP0 */
#define TH_DCACHE_CSW       0x0210000b
#define TH_DCACHE_ISW       0x0220000b  /* no writeback */
#define TH_DCACHE_CISW      0x0230000b
/* VA/PA ops -- dispatched to the LSU, not CP0, but they close the decode
 * matrix and exercise CP0's UCME gating of U-mode cache maintenance. */
#define TH_DCACHE_CVAL1     0x0240000b
#define TH_DCACHE_CVA       0x0250000b
#define TH_DCACHE_IVA       0x0260000b  /* no writeback */
#define TH_DCACHE_CIVA      0x0270000b
#define TH_DCACHE_CPAL1     0x0280000b
#define TH_DCACHE_CPA       0x0290000b
#define TH_DCACHE_IPA       0x02a0000b  /* no writeback */
#define TH_DCACHE_CIPA      0x02b0000b
/* Split into two uops by the IDU (aq_idu_id_split.v:610-612); only the
 * second reaches CP0. */
#define TH_ICACHE_IVA       0x0300000b
#define TH_ICACHE_IPA       0x0380000b

/* --- other raw encodings ---------------------------------------------- *
 * Illegal-instruction sources plain binutils will not emit for us. */
#define INSN_DRET           0x7b200073  /* illegal outside debug mode      */
#define INSN_HFENCE_VVMA    0x22000073  /* unconditionally illegal (:865)  */
#define INSN_RESERVED       0x0000707b  /* undecodable custom-3            */
#define INSN_VSETVLI        0x00007057  /* vector is removed from this core */

#endif /* CP0_TH_INSN_H */
