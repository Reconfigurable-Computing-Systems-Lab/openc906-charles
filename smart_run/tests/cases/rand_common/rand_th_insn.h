/*
 * T-Head (Xtheadc) raw instruction encodings for the per-unit randomized stress
 * tests. A literal copy of cp0_random/cp0_th_insn.h, extended with the Xtheadc
 * arithmetic / bit-manipulation / indexed-memory encodings the IU and IDU tests
 * need.
 *
 * Emitted as raw .word rather than mnemonics on purpose: on macOS the toolchain
 * runs with THEAD_GCC=0 (setup/mac_setup.sh), i.e.
 * -march=rv64imafdc_zfh_zicsr_zifencei, which has neither xtheadcmo, xtheadsync
 * nor the xtheadc arithmetic ops, so `th.dcache.iall` and `th.ext` will not
 * assemble. Raw words assemble identically under the server's Xuantie GCC, so
 * one source builds in both places.
 *
 * Cache / sync format: opcode 0001011 (custom-0), funct3 000, rd 00000,
 * inst[31:26] 000000. The IDU sub-decodes on {inst[25], inst[24:20],
 * inst[19:15]} only (gen_rtl/idu/rtl/aq_idu_id_decd.v:3002), so inst[31:26] is a
 * don't-care; the canonical zero encoding is used here. Every one of these is
 * illegal when MXSTATUS.THEADISAEE (bit 22) is clear (aq_idu_id_decd.v:1005).
 */

#ifndef RAND_TH_INSN_H
#define RAND_TH_INSN_H

/* --- no-operand cache/sync forms (rs1 = x0) --------------------------- *
 * Executed inside CP0; aq_cp0_cache_inst.v splits func into {type,op,dst}. */
#define TH_DCACHE_CALL      0x0010000b  /* D$ clean all                     */
#define TH_DCACHE_IALL      0x0020000b  /* D$ invalidate all, NO writeback   */
#define TH_DCACHE_CIALL     0x0030000b  /* D$ clean + invalidate all         */
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

/* --- rs1 cache forms: OR in (regnum << 15) ---------------------------- */
#define TH_DCACHE_CSW       0x0210000b
#define TH_DCACHE_ISW       0x0220000b  /* no writeback */
#define TH_DCACHE_CISW      0x0230000b
#define TH_DCACHE_CVAL1     0x0240000b
#define TH_DCACHE_CVA       0x0250000b
#define TH_DCACHE_IVA       0x0260000b  /* no writeback */
#define TH_DCACHE_CIVA      0x0270000b
#define TH_DCACHE_CPAL1     0x0280000b
#define TH_DCACHE_CPA       0x0290000b
#define TH_DCACHE_IPA       0x02a0000b  /* no writeback */
#define TH_DCACHE_CIPA      0x02b0000b
/* Split into two uops by the IDU (aq_idu_id_split.v:610-612). */
#define TH_ICACHE_IVA       0x0300000b
#define TH_ICACHE_IPA       0x0380000b

/* ==================================================================== *
 * Xtheadc arithmetic / bit-manipulation, opcode 0001011 with funct3 != 000
 * (aq_idu_id_decd.v:3189-3730, casez on {inst[31:25], inst[14:12]}).
 *
 * Field placement verified against the consumers in aq_iu_alu.v:
 *   th.ext/extu   msb = inst[31:26], lsb = inst[25:20]
 *                 (alu_shift_ext_count = src1[11:6] - src1[5:0], :393)
 *   th.tst        imm6 = inst[25:20]  (alu_misc_tst_bit on src1[5:0], :714)
 *   th.srri       imm6 = inst[25:20]
 *   th.addsl      imm2 = inst[26:25]  (src1 << alu_adder_src2[6:5], :217)
 * ==================================================================== */
#define TH_R(base, rd, rs1, rs2) \
        ((base) | ((unsigned)(rs2) << 20) | ((unsigned)(rs1) << 15) | ((unsigned)(rd) << 7))
#define TH_I(base, rd, rs1, imm) \
        ((base) | ((unsigned)(imm) << 20) | ((unsigned)(rs1) << 15) | ((unsigned)(rd) << 7))
#define TH_EXT(base, rd, rs1, msb, lsb) \
        ((base) | ((unsigned)(msb) << 26) | ((unsigned)(lsb) << 20) \
               | ((unsigned)(rs1) << 15) | ((unsigned)(rd) << 7))
#define TH_ADDSL(rd, rs1, rs2, sh) \
        (0x0000100bU | ((unsigned)(sh) << 25) | ((unsigned)(rs2) << 20) \
                     | ((unsigned)(rs1) << 15) | ((unsigned)(rd) << 7))

/* funct3 = 001 : ALU / MULT family bases (rd/rs1/rs2 fields all zero) */
#define TH_ADDSL_B      0x0000100bU     /* + (sh << 25)     */
#define TH_SRRI_B       0x1000100bU     /* + (imm6 << 20)   */
#define TH_SRRIW_B      0x1400100bU     /* + (imm5 << 20)   */
#define TH_TSTNBZ_B     0x8000100bU
#define TH_REV_B        0x8200100bU
#define TH_FF0_B        0x8400100bU
#define TH_FF1_B        0x8600100bU
#define TH_TST_B        0x8800100bU     /* + (imm6 << 20)   */
#define TH_REVW_B       0x9000100bU
#define TH_MVEQZ_B      0x4000100bU
#define TH_MVNEZ_B      0x4200100bU
#define TH_MULA_B       0x2000100bU
#define TH_MULS_B       0x2200100bU
#define TH_MULAW_B      0x2400100bU
#define TH_MULSW_B      0x2600100bU
#define TH_MULAH_B      0x2800100bU
#define TH_MULSH_B      0x2A00100bU

/* funct3 = 010 / 011 : signed / unsigned bitfield extract */
#define TH_EXT_B        0x0000200bU
#define TH_EXTU_B       0x0000300bU

/* funct3 = 100/101/110/111 : the indexed and index-update memory family.
 *
 * The decoder selects on {inst[31:25], inst[14:12]} (aq_idu_id_decd.v:3187), so
 * each step of the 7-bit inst[31:25] field is 1 << 25 = 0x0200_0000. inst[26:25]
 * is the 2-bit shift amount (decd_lsr_src3_imm_vld, :636), which is why every
 * arm below is a `??` in the table and why the bases end in 0x_000_.
 *
 *   th.lrX   rd, rs1, rs2, sh2   -> rd = mem[rs1 + (rs2 << sh2)]
 *   th.lurX  rd, rs1, rs2, sh2   -> same, rs2 treated as 32-bit unsigned
 *   th.lXia  rd, rs1, imm5, sh2  -> rd = mem[rs1]; rs1 += imm5 << sh2 (post)
 *   th.lXib  rd, rs1, imm5, sh2  -> rs1 += imm5 << sh2 first (pre)
 *   th.lwd/lwud/ldd, th.swd/sdd  -> cracked into two uops by
 *                                   aq_idu_id_split.v:153-295
 *
 * The index-update forms are the only users of dst1 = inst[19:15]
 * (aq_idu_id_decd.v:764), hence the only route to dst1_waw. */
#define TH_IDX(base, rd, rs1, rs2, sh) \
        ((base) | ((unsigned)(sh) << 25) | ((unsigned)(rs2) << 20) \
                | ((unsigned)(rs1) << 15) | ((unsigned)(rd) << 7))

/* funct3 = 100 : loads */
#define TH_LRB_B        0x0000400bU     /* 0000000 */
#define TH_LRH_B        0x2000400bU     /* 0010000 */
#define TH_LRW_B        0x4000400bU     /* 0100000 */
#define TH_LRD_B        0x6000400bU     /* 0110000 */
#define TH_LRBU_B       0x8000400bU     /* 1000000 */
#define TH_LRHU_B       0xA000400bU     /* 1010000 */
#define TH_LRWU_B       0xC000400bU     /* 1100000 */
#define TH_LURB_B       0x1000400bU     /* 0001000 */
#define TH_LURH_B       0x3000400bU     /* 0011000 */
#define TH_LURW_B       0x5000400bU     /* 0101000 */
#define TH_LURD_B       0x7000400bU     /* 0111000 */
#define TH_LURBU_B      0x9000400bU     /* 1001000 */
#define TH_LURHU_B      0xB000400bU     /* 1011000 */
#define TH_LURWU_B      0xD000400bU     /* 1101000 */
#define TH_LBIB_B       0x0800400bU     /* 0000100 */
#define TH_LBIA_B       0x1800400bU     /* 0001100 */
#define TH_LHIB_B       0x2800400bU     /* 0010100 */
#define TH_LHIA_B       0x3800400bU     /* 0011100 */
#define TH_LWIB_B       0x4800400bU     /* 0100100 */
#define TH_LWIA_B       0x5800400bU     /* 0101100 */
#define TH_LDIB_B       0x6800400bU     /* 0110100 */
#define TH_LDIA_B       0x7800400bU     /* 0111100 */
#define TH_LBUIB_B      0x8800400bU     /* 1000100 */
#define TH_LBUIA_B      0x9800400bU     /* 1001100 */
#define TH_LHUIB_B      0xA800400bU     /* 1010100 */
#define TH_LHUIA_B      0xB800400bU     /* 1011100 */
#define TH_LWUIB_B      0xC800400bU     /* 1100100 */
#define TH_LWUIA_B      0xD800400bU     /* 1101100 */
#define TH_LWD_B        0xE000400bU     /* 1110000  pair rd, inst[24:20] */
#define TH_LWUD_B       0xF000400bU     /* 1111000 */
#define TH_LDD_B        0xF800400bU     /* 1111100 */

/* funct3 = 101 : stores.
 *
 * src2 -- the store DATA register -- is inst[11:7] for ALL of these, including
 * the srX/surX forms. (An earlier version of this comment said inst[24:20] for
 * srX; that is wrong. `decd_inst_src2_reg_32bit_24_20`
 * (aq_idu_id_decd.v:699-700) is true only for opcodes 0100011 and 0100111 -- the
 * ordinary S-type and FP stores -- so for opcode 0001011 the
 * `decd_inst_src2_reg_32bit_11_7` term at :701 wins and src2 comes from
 * inst[11:7]. inst[24:20] is the INDEX register rs2 for the srX/surX forms and
 * the imm5 for the index-update forms, which is why TH_IDX puts its `rs2`
 * argument there.) */
#define TH_SRB_B        0x0000500bU
#define TH_SRH_B        0x2000500bU
#define TH_SRW_B        0x4000500bU
#define TH_SRD_B        0x6000500bU
#define TH_SURB_B       0x1000500bU
#define TH_SURH_B       0x3000500bU
#define TH_SURW_B       0x5000500bU
#define TH_SURD_B       0x7000500bU
#define TH_SBIB_B       0x0800500bU
#define TH_SBIA_B       0x1800500bU
#define TH_SHIB_B       0x2800500bU
#define TH_SHIA_B       0x3800500bU
#define TH_SWIB_B       0x4800500bU
#define TH_SWIA_B       0x5800500bU
#define TH_SDIB_B       0x6800500bU
#define TH_SDIA_B       0x7800500bU
#define TH_SWD_B        0xE000500bU
#define TH_SDD_B        0xF800500bU

/* funct3 = 110 / 111 : FP indexed loads / stores */
#define TH_FLRW_B       0x4000600bU
#define TH_FLRD_B       0x6000600bU
#define TH_FLURW_B      0x5000600bU
#define TH_FLURD_B      0x7000600bU
#define TH_FSRW_B       0x4000700bU
#define TH_FSRD_B       0x6000700bU
#define TH_FSURW_B      0x5000700bU
#define TH_FSURD_B      0x7000700bU

/* --- other raw encodings ---------------------------------------------- *
 * Illegal-instruction sources plain binutils will not emit for us. */
#define INSN_DRET           0x7b200073  /* illegal outside debug mode      */
#define INSN_HFENCE_VVMA    0x22000073  /* unconditionally illegal (:865)  */
#define INSN_RESERVED       0x0000707b  /* undecodable custom-3            */
#define INSN_VSETVLI        0x00007057  /* vector removed: always illegal  */
#define INSN_VADD_VV        0x02000057  /* ditto                           */

/* 16-bit encodings that GCC will not emit on demand. c.lui is the only
 * producer of alu_adder_rs1_sel_onehot arm 5'b00001 (aq_iu_alu.v:227-234). */
#define C_LUI_A0_1          0x6505      /* c.lui a0, 1  */
#define C_NOP               0x0001

#endif /* RAND_TH_INSN_H */
