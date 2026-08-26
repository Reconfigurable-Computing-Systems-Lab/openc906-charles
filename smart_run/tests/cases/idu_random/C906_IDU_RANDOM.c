/*
 * idu_random -- randomized decode / dispatch stress test for the OpenC906 IDU.
 *
 * Executes IDU_ITERS (default 20000) dynamic iterations of a seeded xorshift64
 * dispatch loop over 46 operation groups that together cover the parts of
 * C906_RTL_FACTORY/gen_rtl/idu/rtl/ that software can reach: the four decode
 * tables (RVC, base 32-bit, FP, FMA) plus the two T-Head sub-decoders, the four
 * instruction-cracking state machines (LSD, AMO, cache, fence), the immediate
 * and register-index selection muxes, the shadow GPR file's three read ports,
 * the writeback tracker and its RAW / WAW except matrix, the forwarding-bus
 * comparators, the EX1 execute-unit select and its full/stall terms, and the
 * exception-priority and EU-override paths.
 *
 * There is deliberately NO golden-model self-check. PASS means the test ran to
 * completion (main returns -> crt0.s __exit -> the magic value the testbench
 * watches the RTU writeback buses for). Results are folded into rand_sink only
 * so that the compiler cannot delete the instruction under test; rand_sink is
 * printed at the end as a fingerprint and is NOT compared against anything.
 * The evidence that the IDU was actually stimulated is the port-toggle report
 * the monitor bound into the testbench writes (tests/cases/idu_random/
 * idu_toggle_mon.v), plus the trap-cause histogram in the run report.
 *
 * ==================================================================== *
 * THE RULE THAT SHAPES THIS FILE
 * ==================================================================== *
 * A decode-matrix sweep is tempting to write as "cast rand_rnd() down to 32
 * bits and execute it". That is not what this does, and idu_encodings.h
 * explains at length why: a random word can be `wfi` (retirement stops, the
 * 50,000-cycle no-retire watchdog fires, and a WFI with nothing armed in
 * (mie & mip) cannot be woken), `csrw mtvec, x0` (the harness loses its trap
 * handler), `mret`, an arbitrary store into our own stack, `sfence.vma` with a
 * live satp, or a write to ra / sp / gp / tp. Instead every stream here comes
 * from the whitelisted table in idu_encodings.h with its fields filled in from
 * six fixed, safe operand slots -- a curated sweep rather than a lottery, which
 * is exactly what cp0_random's 42 groups already are.
 *
 * Corollary: because each encoding has to be a compile-time constant (see
 * idu_encodings.h on the "n" constraint), *field* diversity comes from a switch
 * over variants rather than from a runtime value, and the four leaves that are
 * small enough to enumerate exhaustively -- the two immediate-select cases, the
 * 96 GPR read-port mux bins and the forwarding comparators -- are emitted by
 * gen_idu_sweeps.py instead of being sampled here.
 *
 * ==================================================================== *
 * KNOWN-UNREACHABLE IN THIS CONFIGURATION -- NOT TARGETED
 * ==================================================================== *
 *  - The entire vector decoder. `decd_sel[5] = 1'b0` (aq_idu_id_decd.v:1011)
 *    and `decd_vec_inst = 1'b0` (:3740) make roughly 2900 lines of
 *    aq_idu_id_decd.v dead, along with every decd_vec_* signal,
 *    idu_vidu_ex1_vec_sel, cp0_idu_vsetvl_dis_stall and ctrl_dis_vec_stall
 *    (aq_idu_id_ctrl.v:386-388), EU_VEC dispatch, HPCP instruction category
 *    [2], and decd_src1_imm_sel[13] (14'h2000). Group 17 confirms the boundary
 *    from the outside -- every RVV encoding must trap -- and that is all that
 *    is worth spending iterations on.
 *  - C.JAL. RV64 reuses the encoding for C.ADDIW.
 *  - The debug-trigger cancel arm of the exception override
 *    (dp_ctrl_dis_inst_cancel <- ifu_idu_id_halt_info[TDT_HINFO_CANCEL],
 *    aq_idu_id_dp.v:525) and decd_debug_illegal (:963): both need
 *    rtu_yy_xx_dbgon, i.e. a JTAG-driven debug-mode entry. Out of reach from a
 *    program; see tests/cases/debug/ for the case that does have a JTAG driver.
 *  - ctrl_dis_cp0_stall's `rtu_yy_xx_dbgon && cp0_idu_dis_fence_in_dbg` escape
 *    (aq_idu_id_ctrl.v:384). Same reason.
 *  - `dret` outside debug mode decodes, but decd_i_illegal always fires on it
 *    (:857-858), so only the illegal path is reachable. Group 26 takes it.
 *  - The instruction page-fault leg of the exception priority
 *    (aq_idu_id_dp.v:541). It needs satp in Sv39 with an identity-mapped
 *    kernel and a deliberately unmapped target page, which is the MMU case's
 *    job (tests/cases/MMU/); this test keeps satp Bare throughout so that no
 *    group can lose access to its own code.
 *  - DIS_INT_EXPT_HIGH (aq_idu_id_dp.v:543) and therefore
 *    idu_cp0_ex1_expt_high. Its source is
 *      ipack_expt_high = ipack_inst_32 && !acc_err[0] && acc_err[1]
 *    (aq_ifu_ibuf.v:1312), i.e. a 32-bit instruction whose FIRST halfword
 *    fetched cleanly and whose SECOND took an access fault. rand_csrs.h leaves
 *    a lever for that boundary (RAND_SO_LAST_OK = 0x8FFFEFFE, the last two
 *    bytes of sysmap region 0 before the strong-order window), but it cannot be
 *    used from a Bare-satp program on this SoC: 0x8FFFEFFE is far above the
 *    SRAM window, so the first halfword comes from the AXI error slave as
 *    16'h0000, ipack_inst_32 is 0, and the term never asserts. Reaching it
 *    needs Sv39 with a mapped page abutting an unmapped one -- the MMU case's
 *    job again.
 *
 * Everything else is derived from the RTL and each group names the structure
 * and file:line it is aimed at.
 */

#include "idu_defs.h"
#include "idu_encodings.h"
#include "idu_sweeps.h"

#ifndef IDU_ITERS
#define IDU_ITERS 20000
#endif
#ifndef IDU_SEED
#define IDU_SEED 0x2024C906
#endif

/* ==================================================================== *
 * Bookkeeping. All volatile so that they survive a rand_longjmp out of the
 * trap handler.
 * ==================================================================== */
static volatile u64 group_hits[IDU_NGROUPS_TOTAL];
static volatile u64 idu_priv_trips;    /* excursions into S or U mode        */
static volatile u64 idu_sweep_calls;   /* calls into the generated sweeps    */
static volatile u64 idu_zvamo_tries;   /* group 45 attempts, if enabled      */
static volatile u64 idu_mode_arg;      /* parameter for the S/U-mode bodies  */

/* A cache-miss arena. 4 KB is 64 D-cache lines, which is enough for the WAW
 * cnt==2 group to keep three loads outstanding at a 64-byte stride, and small
 * enough not to matter against the 256 KB .text and 768 KB MEM2 budgets. Every
 * user cleans and invalidates the whole D-cache first (DCACHE_SAFE_POINT), so
 * the first touch of each line is guaranteed to miss. */
static volatile u64 idu_miss_arena[512];

/* ==================================================================== *
 * Local helpers
 * ==================================================================== */

/* An sp-relative compressed form needs a stack slot it owns: c.lwsp / c.swsp /
 * c.sdsp reach 0..252 bytes *up* from sp, which is our own frame and possibly
 * our caller's saved registers. Pushing sp down inside the same asm block gives
 * the sequence 64 freshly-allocated bytes that nothing else can be using. The
 * pop is unconditional: a trap in the body is stepped over by the handler and
 * still reaches it, and a bail-out restores sp from rand_ctx.
 *
 * "a2" is in the clobber list because the c.lwsp / c.ldsp bodies name a2 as
 * their destination: the point of those arms is that dst0 comes from inst[11:7]
 * on an sp-relative form, so the register has to be a literal in the body and
 * cannot be an asm operand. Without the clobber GCC is free to keep a live
 * value there across the block, and the load would silently destroy it. */
#define IDU_SP_BLOCK(body) do {                                             \
        register u64 v_ __asm__("a1") = rand_iter;                          \
        __asm__ volatile ("addi sp, sp, -64\n\t"                            \
                          "sd   a1, 0(sp)\n\t"                              \
                          "sd   a1, 8(sp)\n\t"                              \
                          "sd   a1, 16(sp)\n\t"                             \
                          "sd   a1, 24(sp)\n\t"                             \
                          "sd   a1, 32(sp)\n\t"                             \
                          "sd   a1, 40(sp)\n\t"                             \
                          body "\n\t"                                       \
                          "addi sp, sp, 64"                                 \
                          : "+r"(v_) :: "memory", "fa0", "a2");             \
        rand_sink += v_;                                                    \
    } while (0)

/* A raw halfword whose only operand is a1 (x11), so that the compressed forms
 * can be aimed at a scratch pointer. */
#define IDU_C_PTR(body, ptr) do {                                           \
        register u64 p_ __asm__("a1") = (u64)(ptr);                         \
        __asm__ volatile (body : "+r"(p_) :: "memory", "fa0", "a2");        \
        rand_sink += p_;                                                    \
    } while (0)

/* Read one specific architectural register into rand_sink. The register number
 * has to be a literal (it is an instruction field), hence the macro. */
#define IDU_READ_REG(n, v) do {                                             \
        u64 d_;                                                             \
        __asm__ volatile ("add %0, x" STR(n) ", %1"                         \
                          : "=r"(d_) : "r"((u64)(v)));                      \
        rand_sink += d_;                                                    \
    } while (0)

/* Clean+invalidate the whole D-cache, then walk `n` lines of the miss arena at
 * a 64-byte stride so that every access is a fresh miss and the LSU queue
 * fills. The workhorse of the cnt==2 / eu_full / pipe-select groups.
 *
 * The accumulator is a plain local, deliberately: folding each load straight
 * into `rand_sink` would put a volatile STORE between every pair of loads, and
 * the queue would then never hold more than one outstanding miss -- exactly
 * what this helper exists to produce. idu_miss_arena is itself volatile, so the
 * loads cannot be removed or reordered; only the adds chain, and an ALU chain
 * forwards from EX1. One store at the end keeps the result alive. */
static void idu_fill_lsu(unsigned n)
{
    unsigned i;
    u64 acc = 0;

    DCACHE_SAFE_POINT();
    for (i = 0; i < n; i++)
        acc += idu_miss_arena[(i * 8u) & 511u];
    rand_sink += acc;
}

/* ==================================================================== *
 * Group 0: the 32-arm RVC decode table
 *   aq_idu_id_decd.v:1271-1478, casez on {inst[15:10], inst[6:5], inst[1:0]}.
 *
 * The two nested arms are the interesting ones and get their own sub-switches:
 *   10'b1000??_??10  c.jr vs c.mv, on inst[6:2] == 0            (:1459-1467)
 *   10'b1001??_??10  c.jalr vs c.add vs c.ebreak, on inst[6:2]
 *                    and inst[11:7]                             (:1468-1479)
 * c.jr and c.jalr are the only encodings in this file that take a computed
 * target, and both take it from `la` on a local label -- never from data.
 * c.jalr writes ra, so it is bracketed by a save/restore through a2.
 * ==================================================================== */
static void g_rvc_table(u64 r)
{
    u64 p = IDU_PTR(r >> 5);
    u64 v = IDU_POOL(r >> 11);

    switch ((unsigned)((r >> 16) % 26u)) {
    /* ---- quadrant 0: op == 2'b00 ---- */
    case 0:  /* c.addi4spn: src0 is hardwired to x2, imm from
              * decd_caddi4spn_src1_imm (:531) */
        { u64 d_;
          __asm__ volatile ("c.addi4spn a1, sp, 8\n\t"
                            "mv %0, a1" : "=r"(d_) :: "a1");
          rand_sink += d_; }
        break;
    case 1:  IDU_C_PTR("c.fld  fa0, 8(a1)",  p); break;
    case 2:  IDU_C_PTR("c.lw   a2, 4(a1)",   p); break;
    case 3:  IDU_C_PTR("c.ld   a2, 8(a1)",   p); break;
    case 4:  IDU_C_PTR("c.fsd  fa0, 16(a1)", p); break;
    case 5:  IDU_C_PTR("c.sw   a1, 20(a1)",  p); break;
    case 6:  IDU_C_PTR("c.sd   a1, 24(a1)",  p); break;
    case 7:  /* funct3 == 3'b100 in quadrant 0 is reserved: the casez has arms
              * for 000/001/010/011/101/110/111 (:1271-1319) and none for
              * 10'b100000_00_00, so decd_16_illegal fires from the default
              * (:1479). The encoding is {funct3, ..., op} == {100, ..., 00},
              * i.e. inst[15:13] = 3'b100 -- 0x8000, NOT 0x2000: 0x2000 has
              * inst[15:13] = 3'b001, which is c.fld, a legal FP load already
              * covered by case 1. (Verified: with 0x2000 this group took zero
              * illegal-instruction traps in 300 iterations.) */
        IDU_HALF(0x8000u);
        break;

    /* ---- quadrant 1: op == 2'b01 ---- */
    case 8:
        __asm__ volatile ("c.nop" ::: "memory");
        __asm__ volatile ("c.addi a2, 7" ::: "a2");
        break;
    case 9:  __asm__ volatile ("c.addiw a2, -3" ::: "a2"); break;
    case 10: __asm__ volatile ("c.li a2, 21"    ::: "a2"); break;
    case 11: /* funct3 011: c.addi16sp when rd == x2, c.lui otherwise. c.lui is
              * the only producer of the alu adder's rs1 one-hot arm 5'b00001,
              * so the harness keeps a canonical encoding for it. */
        if ((r >> 40) & 1u) {
            __asm__ volatile ("c.addi16sp sp, -32\n\t"
                              "c.addi16sp sp, 32" ::: "memory");
        } else {
            IDU_HALF_A0(C_LUI_A0_1);   /* c.lui a0, 1 -- writes a0, so a0 is
                                        * an asm output, not a bare .2byte */
        }
        break;
    case 12: /* the nine MISC-ALU sub-arms (funct3 == 3'b100, op == 2'b01) */
        switch ((unsigned)((r >> 24) % 9u)) {
        case 0: __asm__ volatile ("c.srli a2, 5" ::: "a2"); break;
        case 1: __asm__ volatile ("c.srai a2, 5" ::: "a2"); break;
        case 2: __asm__ volatile ("c.andi a2, 9" ::: "a2"); break;
        case 3: __asm__ volatile ("c.sub  a2, a3" ::: "a2"); break;
        case 4: __asm__ volatile ("c.xor  a2, a3" ::: "a2"); break;
        case 5: __asm__ volatile ("c.or   a2, a3" ::: "a2"); break;
        case 6: __asm__ volatile ("c.and  a2, a3" ::: "a2"); break;
        case 7: __asm__ volatile ("c.subw a2, a3" ::: "a2"); break;
        default:__asm__ volatile ("c.addw a2, a3" ::: "a2"); break;
        }
        break;
    case 13: __asm__ volatile ("c.j 1f\n1:" ::: "memory"); break;
    case 14: __asm__ volatile ("mv a2, %0\n\t"
                               "c.beqz a2, 1f\n\t"
                               "c.nop\n1:" :: "r"(v) : "a2"); break;
    case 15: __asm__ volatile ("mv a2, %0\n\t"
                               "c.bnez a2, 1f\n\t"
                               "c.nop\n1:" :: "r"(v) : "a2"); break;

    /* ---- quadrant 2: op == 2'b10 ---- */
    case 16: __asm__ volatile ("c.slli a2, 13" ::: "a2"); break;
    case 17: IDU_SP_BLOCK("c.fldsp fa0, 8(sp)");  break;
    case 18: IDU_SP_BLOCK("c.lwsp  a2, 16(sp)");  break;
    case 19: IDU_SP_BLOCK("c.ldsp  a2, 24(sp)");  break;
    case 20: /* 10'b1000??_??10 -- c.jr when inst[6:2] == 0, else c.mv */
        if ((r >> 41) & 1u) {
            __asm__ volatile ("la a2, 1f\n\t"
                              "c.jr a2\n1:" ::: "a2", "memory");
        } else {
            __asm__ volatile ("c.mv a2, a3" ::: "a2");
        }
        break;
    case 21: /* 10'b1001??_??10 -- c.jalr / c.add / c.ebreak.
              * c.ebreak is inst[11:2] == 10'b0000011100 and dispatches to
              * EU_CP0; c.jalr writes x1 through the hardwired dst0 arm. */
        switch ((unsigned)((r >> 25) % 3u)) {
        case 0:
            __asm__ volatile ("mv a3, ra\n\t"      /* park the return address */
                              "la a2, 1f\n\t"
                              "c.jalr a2\n1:\n\t"
                              "mv ra, a3" ::: "a2", "a3", "memory");
            break;
        case 1:
            __asm__ volatile ("c.add a2, a3" ::: "a2");
            break;
        default:
            __asm__ volatile ("c.ebreak" ::: "memory");
            break;
        }
        break;
    case 22: IDU_SP_BLOCK("c.fsdsp fa0, 32(sp)"); break;
    case 23: IDU_SP_BLOCK("c.swsp  a1, 36(sp)");  break;
    case 24: IDU_SP_BLOCK("c.sdsp  a1, 40(sp)");  break;
    default: /* all four c.* forms that need a c-register base, back to back,
              * so the RVC table is walked in one dispatch burst */
        IDU_C_PTR("c.lw a2, 0(a1)\n\t"
                  "c.ld a2, 8(a1)\n\t"
                  "c.sw a1, 16(a1)\n\t"
                  "c.sd a1, 24(a1)", p);
        break;
    }
}

/* ==================================================================== *
 * Groups 1 and 2: the 104-arm 32-bit decode table
 *   aq_idu_id_decd.v:1544-2165, casez on {inst[31:25], inst[14:12], inst[6:2]}.
 *
 * Split in two halves so that run_groups.sh can bisect them: group 1 is the
 * ALU / MULT / DIV / BJU arms, group 2 the load / store / fence / CSR arms.
 *
 * Deliberately absent from group 2: mret, sret, wfi and dret. Their legal forms
 * are a jump to mepc/sepc, a stop, and a debug-mode-only return -- none of
 * which a stimulus generator has any business executing. Their decode arms are
 * covered from the illegal side in group 26, where a reserved-field violation
 * gets the decode path without the behaviour. sfence.vma has its own group (22)
 * because it is a cracked instruction.
 * ==================================================================== */
static void g_base32_alu(u64 r)
{
    u64 a = IDU_POOL(r >> 5);
    u64 b = IDU_POOL(r >> 11);

    switch ((unsigned)((r >> 16) % 25u)) {
    case 0:  IDU_M_RR("add",    a, b); IDU_M_RR("sub",  a, b); break;
    case 1:  IDU_M_RR("sll",    a, b); IDU_M_RR("srl",  a, b);
             IDU_M_RR("sra",    a, b); break;
    case 2:  IDU_M_RR("slt",    a, b); IDU_M_RR("sltu", a, b); break;
    case 3:  IDU_M_RR("xor",    a, b); IDU_M_RR("or",   a, b);
             IDU_M_RR("and",    a, b); break;
    case 4:  IDU_M_RR("addw",   a, b); IDU_M_RR("subw", a, b); break;
    case 5:  IDU_M_RR("sllw",   a, b); IDU_M_RR("srlw", a, b);
             IDU_M_RR("sraw",   a, b); break;
    case 6:  IDU_M_RI("addi",   a, -1365); IDU_M_RI("addiw", a, 1365); break;
    case 7:  IDU_M_RI("slti",   a, -7);    IDU_M_RI("sltiu", a, 1000); break;
    case 8:  IDU_M_RI("xori",   a, -1);    IDU_M_RI("ori",   a, 682);
             IDU_M_RI("andi",   a, 341);   break;
    case 9:  IDU_M_RI("slli",   a, 63);    IDU_M_RI("srli",  a, 1);
             IDU_M_RI("srai",   a, 62);    break;
    case 10: IDU_M_RI("slliw",  a, 31);    IDU_M_RI("srliw", a, 1);
             IDU_M_RI("sraiw",  a, 30);    break;
    case 11: IDU_M_RR("mul",    a, b); IDU_M_RR("mulh",   a, b); break;
    case 12: IDU_M_RR("mulhsu", a, b); IDU_M_RR("mulhu",  a, b); break;
    case 13: IDU_M_RR("div",    a, b); IDU_M_RR("divu",   a, b); break;
    case 14: IDU_M_RR("rem",    a, b); IDU_M_RR("remu",   a, b); break;
    case 15: IDU_M_RR("mulw",   a, b); IDU_M_RR("divw",   a, b); break;
    case 16: IDU_M_RR("divuw",  a, b); IDU_M_RR("remw",   a, b);
             IDU_M_RR("remuw",  a, b); break;
    case 17: /* lui / auipc: the two producers of decd_src1_imm_sel[0] */
        { u64 d_;
          __asm__ volatile ("lui   %0, 0x5A5A5" : "=r"(d_)); rand_sink += d_;
          __asm__ volatile ("auipc %0, 0x1"     : "=r"(d_)); rand_sink += d_; }
        break;
    case 18: /* jal with a scratch link register -- never ra, and never a
              * computed target (CLAUDE.md: an indirect jump used as a tail call
              * stalls retirement on this RTL) */
        __asm__ volatile ("jal a1, 1f\n1:" ::: "a1", "memory");
        break;
    case 19: /* jalr, likewise: target from `la` on a local label */
        __asm__ volatile ("la a2, 1f\n\t"
                          "jalr a1, 0(a2)\n1:" ::: "a1", "a2", "memory");
        break;
    case 20: /* the six conditional-branch arms, each both taken and not */
        __asm__ volatile ("beq  %0, %0, 1f\n\tnop\n1:" :: "r"(a) : "memory");
        __asm__ volatile ("bne  %0, %1, 1f\n\tnop\n1:" :: "r"(a), "r"(b)
                                                       : "memory");
        break;
    case 21:
        __asm__ volatile ("blt  %0, %1, 1f\n\tnop\n1:" :: "r"(a), "r"(b)
                                                       : "memory");
        __asm__ volatile ("bge  %0, %1, 1f\n\tnop\n1:" :: "r"(a), "r"(b)
                                                       : "memory");
        break;
    case 22:
        __asm__ volatile ("bltu %0, %1, 1f\n\tnop\n1:" :: "r"(a), "r"(b)
                                                       : "memory");
        __asm__ volatile ("bgeu %0, %1, 1f\n\tnop\n1:" :: "r"(a), "r"(b)
                                                       : "memory");
        break;
    case 23: /* the default arm: an undecodable custom-3 word (:2165) */
        IDU_WORD(INSN_RESERVED);
        break;
    default: /* a shift with a reserved funct7, which the casez pins to
              * 15'b000000?_?????? and therefore rejects */
        IDU_WORD(0x40001513u);   /* "slli a0, a0, 0" with funct7 = 0100000 */
        break;
    }
}

static void g_base32_ls_sys(u64 r)
{
    u64 p = IDU_PTR(r >> 5);
    u64 v = IDU_POOL(r >> 11);

    switch ((unsigned)((r >> 16) % 14u)) {
    case 0:  IDU_M_LOAD("lb",  p, 1);  IDU_M_LOAD("lbu", p, 3);  break;
    case 1:  IDU_M_LOAD("lh",  p, 2);  IDU_M_LOAD("lhu", p, 6);  break;
    case 2:  IDU_M_LOAD("lw",  p, 4);  IDU_M_LOAD("lwu", p, 8);  break;
    case 3:  IDU_M_LOAD("ld",  p, 0);  IDU_M_LOAD("ld",  p, 16); break;
    case 4:  IDU_M_STORE("sb", p, 1, v); IDU_M_STORE("sh", p, 2, v); break;
    case 5:  IDU_M_STORE("sw", p, 4, v); IDU_M_STORE("sd", p, 8, v); break;
    case 6:  /* the FP load/store arms of the 32-bit table: flh/flw/fld and
              * fsh/fsw/fsd. decd_src1_imm_sel[5] covers fs* through the
              * {inst[14],inst[6:0]} == 8'b0_0100111 term (:493-494). */
        __asm__ volatile ("flh fa0, 0(%0)\n\t"
                          "flw fa1, 4(%0)\n\t"
                          "fld fa2, 8(%0)"
                          :: "r"(p) : "fa0", "fa1", "fa2", "memory");
        break;
    case 7:
        __asm__ volatile ("fmv.d.x fa0, %1\n\t"
                          "fsh fa0, 16(%0)\n\t"
                          "fsw fa0, 20(%0)\n\t"
                          "fsd fa0, 24(%0)"
                          :: "r"(p), "r"(v) : "fa0", "memory");
        break;
    case 8:  /* fence / fence.i: FUNC_FENCE and FUNC_FENCEI, both EU_CP0 and
              * both subject to ctrl_dis_cp0_stall (group 43) */
        __asm__ volatile ("fence iorw, iorw" ::: "memory");
        __asm__ volatile ("fence.i" ::: "memory");
        break;
    case 9:  /* the register CSR forms. mscratch is the target because nothing
              * in rand_common uses it -- the handler keeps its state in
              * rand_ctx via tp, precisely so the tests can scribble here. */
        (void)CSR_RW(CSR_MSCRATCH, v);
        (void)CSR_RS(CSR_MSCRATCH, v);
        (void)CSR_RC(CSR_MSCRATCH, v);
        break;
    case 10: /* the immediate CSR forms */
        (void)CSR_RWI(CSR_MSCRATCH, 0x15);
        (void)CSR_RSI(CSR_MSCRATCH, 0x1f);
        (void)CSR_RCI(CSR_MSCRATCH, 0x0a);
        break;
    case 11: /* ecall from M: cause 11, which the handler steps over */
        __asm__ volatile ("ecall" ::: "memory");
        break;
    case 12: /* ebreak: cause 3 */
        __asm__ volatile ("ebreak" ::: "memory");
        break;
    default: /* a load with a reserved funct3: 110 is lwu, 111 is undefined.
              * rd is x0 so that even a decode we have mis-reasoned about
              * cannot land a value anywhere. */
        IDU_WORD(0x00007003u);   /* funct3 = 111 on the LOAD opcode */
        break;
    }
}

/* ==================================================================== *
 * Groups 3, 4, 5: the FP decode tables
 *   aq_idu_id_decd.v:2213-2770  the 79-arm OP-FP table (decd_fp0)
 *   aq_idu_id_decd.v:2798-2916  the 12-arm FMA table   (decd_fp1)
 *
 * Split .s/.d (group 3) from .h (group 4) because the Zfh arms are a distinct
 * third of the table and because a Zfh-less toolchain is a plausible future
 * build configuration -- keeping them separable means group 4 can be disabled
 * on its own.
 *
 * Every operand arrives through fmv.d.x from idu_fpool and every result leaves
 * through fmv.x.d, so no FP value crosses an inline-asm boundary as a C double
 * and the image needs no .rodata constant pool. NaNs and subnormals are in the
 * pool on purpose: they change how long FALU/FDIV take, which is what the
 * FP-dependency group (38) is really after.
 * ==================================================================== */
static void g_fp_table_sd(u64 r)
{
    u64 a = IDU_FPOOL(r >> 5);
    u64 b = IDU_FPOOL(r >> 7);
    unsigned dbl = (unsigned)((r >> 40) & 1u);

    switch ((unsigned)((r >> 16) % 14u)) {
    case 0:  if (dbl) { IDU_M_FP2("fadd.d", a, b); IDU_M_FP2("fsub.d", a, b); }
             else     { IDU_M_FP2("fadd.s", a, b); IDU_M_FP2("fsub.s", a, b); }
             break;
    case 1:  if (dbl) { IDU_M_FP2("fmul.d", a, b); IDU_M_FP2("fdiv.d", a, b); }
             else     { IDU_M_FP2("fmul.s", a, b); IDU_M_FP2("fdiv.s", a, b); }
             break;
    case 2:  if (dbl)   IDU_M_FP1("fsqrt.d", a);
             else        IDU_M_FP1("fsqrt.s", a);
             break;
    case 3:  if (dbl) { IDU_M_FP2("fsgnj.d",  a, b);
                        IDU_M_FP2("fsgnjn.d", a, b);
                        IDU_M_FP2("fsgnjx.d", a, b); }
             else     { IDU_M_FP2("fsgnj.s",  a, b);
                        IDU_M_FP2("fsgnjn.s", a, b);
                        IDU_M_FP2("fsgnjx.s", a, b); }
             break;
    case 4:  if (dbl) { IDU_M_FP2("fmin.d", a, b); IDU_M_FP2("fmax.d", a, b); }
             else     { IDU_M_FP2("fmin.s", a, b); IDU_M_FP2("fmax.s", a, b); }
             break;
    case 5:  if (dbl) { IDU_M_FP2X("feq.d", a, b); IDU_M_FP2X("flt.d", a, b);
                        IDU_M_FP2X("fle.d", a, b); }
             else     { IDU_M_FP2X("feq.s", a, b); IDU_M_FP2X("flt.s", a, b);
                        IDU_M_FP2X("fle.s", a, b); }
             break;
    case 6:  if (dbl)   IDU_M_FP1X("fclass.d", a);
             else        IDU_M_FP1X("fclass.s", a);
             break;
    case 7:  if (dbl) { IDU_M_FP1X("fcvt.w.d",  a);
                        IDU_M_FP1X("fcvt.wu.d", a); }
             else     { IDU_M_FP1X("fcvt.w.s",  a);
                        IDU_M_FP1X("fcvt.wu.s", a); }
             break;
    case 8:  if (dbl) { IDU_M_FP1X("fcvt.l.d",  a);
                        IDU_M_FP1X("fcvt.lu.d", a); }
             else     { IDU_M_FP1X("fcvt.l.s",  a);
                        IDU_M_FP1X("fcvt.lu.s", a); }
             break;
    case 9:  if (dbl) { IDU_M_XFP("fcvt.d.w",  a); IDU_M_XFP("fcvt.d.wu", a); }
             else     { IDU_M_XFP("fcvt.s.w",  a); IDU_M_XFP("fcvt.s.wu", a); }
             break;
    case 10: if (dbl) { IDU_M_XFP("fcvt.d.l",  a); IDU_M_XFP("fcvt.d.lu", a); }
             else     { IDU_M_XFP("fcvt.s.l",  a); IDU_M_XFP("fcvt.s.lu", a); }
             break;
    case 11: /* the fmv arms, i.e. decd_inst_fmv (:681) -- src1 comes from
              * inst[19:15] rather than inst[24:20] */
             if (dbl) { IDU_M_FP1X("fmv.x.d", a); IDU_M_XFP("fmv.d.x", a); }
             else     { IDU_M_FP1X("fmv.x.w", a); IDU_M_XFP("fmv.w.x", a); }
             break;
    case 12: /* the two cross-width conversions */
             IDU_M_FP1("fcvt.s.d", a);
             IDU_M_FP1("fcvt.d.s", a);
             break;
    default: /* an OP-FP word whose fmt field is 2'b11, the quad format this
              * core does not implement, so the 15-bit key
              * {inst[31:25], inst[24:20], inst[14:12]} matches no arm and the
              * table's default fires (:2770) */
             IDU_WORD(0x06000053u);   /* "fadd.q f0, f0, f0" */
             break;
    }
}

static void g_fp_table_h(u64 r)
{
    u64 a = IDU_FPOOL(r >> 5);
    u64 b = IDU_FPOOL(r >> 7);

    switch ((unsigned)((r >> 16) % 12u)) {
    case 0:  IDU_M_FP2("fadd.h", a, b); IDU_M_FP2("fsub.h", a, b); break;
    case 1:  IDU_M_FP2("fmul.h", a, b); IDU_M_FP2("fdiv.h", a, b); break;
    case 2:  IDU_M_FP1("fsqrt.h", a); break;
    case 3:  IDU_M_FP2("fsgnj.h",  a, b);
             IDU_M_FP2("fsgnjn.h", a, b);
             IDU_M_FP2("fsgnjx.h", a, b); break;
    case 4:  IDU_M_FP2("fmin.h", a, b); IDU_M_FP2("fmax.h", a, b); break;
    case 5:  IDU_M_FP2X("feq.h", a, b); IDU_M_FP2X("flt.h", a, b);
             IDU_M_FP2X("fle.h", a, b); break;
    case 6:  IDU_M_FP1X("fclass.h", a); IDU_M_FP1X("fmv.x.h", a); break;
    case 7:  IDU_M_FP1X("fcvt.w.h",  a); IDU_M_FP1X("fcvt.wu.h", a); break;
    case 8:  IDU_M_FP1X("fcvt.l.h",  a); IDU_M_FP1X("fcvt.lu.h", a); break;
    case 9:  IDU_M_XFP("fcvt.h.w", a); IDU_M_XFP("fcvt.h.wu", a);
             IDU_M_XFP("fmv.h.x",  a); break;
    case 10: IDU_M_XFP("fcvt.h.l", a); IDU_M_XFP("fcvt.h.lu", a); break;
    default: /* the four half<->single/double conversions */
             IDU_M_FP1("fcvt.s.h", a); IDU_M_FP1("fcvt.h.s", a);
             IDU_M_FP1("fcvt.d.h", a); IDU_M_FP1("fcvt.h.d", a);
             break;
    }
}

/* The 12-arm FMA table is keyed on {inst[26:25], inst[4:2]} only (:2798), so
 * three formats x four sign combinations is the whole table. */
static void g_fma_table(u64 r)
{
    u64 a = IDU_FPOOL(r >> 5);
    u64 b = IDU_FPOOL(r >> 7);
    u64 c = IDU_FPOOL(r >> 11);

    switch ((unsigned)((r >> 16) % 12u)) {
    case 0:  IDU_M_FMA("fmadd.s",  a, b, c); break;
    case 1:  IDU_M_FMA("fmsub.s",  a, b, c); break;
    case 2:  IDU_M_FMA("fnmsub.s", a, b, c); break;
    case 3:  IDU_M_FMA("fnmadd.s", a, b, c); break;
    case 4:  IDU_M_FMA("fmadd.d",  a, b, c); break;
    case 5:  IDU_M_FMA("fmsub.d",  a, b, c); break;
    case 6:  IDU_M_FMA("fnmsub.d", a, b, c); break;
    case 7:  IDU_M_FMA("fnmadd.d", a, b, c); break;
    case 8:  IDU_M_FMA("fmadd.h",  a, b, c); break;
    case 9:  IDU_M_FMA("fmsub.h",  a, b, c); break;
    case 10: IDU_M_FMA("fnmsub.h", a, b, c); break;
    default: IDU_M_FMA("fnmadd.h", a, b, c); break;
    }
}

/* ==================================================================== *
 * Group 6: FP rounding-mode decode
 *   aq_idu_id_decd.v:942-951. Static rm 101 and 110 are illegal outright;
 *   dynamic rm (111) is illegal iff cp0_idu_frm is 101, 110 or 111.
 *
 * The illegal-frm leg is the one dangerous corner in this file: leaving frm at
 * 5..7 makes EVERY subsequent dynamic-rounding FP op illegal, which degenerates
 * into a trap storm that retires instructions -- a livelock the no-retire
 * watchdog never catches. So fcsr is saved, exactly one instruction is issued
 * with the bad frm, and it is restored immediately.
 * ==================================================================== */
static void g_fp_rm(u64 r)
{
    u64 keep = CSR_R(CSR_FCSR);
    u64 a = IDU_FPOOL(r >> 5);
    u64 b = IDU_FPOOL(r >> 7);

    switch ((unsigned)((r >> 16) % 8u)) {
    case 0: IDU_M_FP2_RM("fadd.s", "rne", a, b); break;
    case 1: IDU_M_FP2_RM("fadd.s", "rtz", a, b); break;
    case 2: IDU_M_FP2_RM("fadd.d", "rdn", a, b); break;
    case 3: IDU_M_FP2_RM("fadd.d", "rup", a, b); break;
    case 4: IDU_M_FP2_RM("fmul.d", "rmm", a, b); break;
    case 5: /* rm = 101 and rm = 110: fp_static_rounding_illegal (:942-943).
             * Binutils will not assemble either, so they are raw words:
             * fadd.d fa0, fa1, fa2 with inst[14:12] forced. */
        IDU_WORD(0x02C5D553u);   /* fadd.d fa0, fa1, fa2, rm = 101 */
        IDU_WORD(0x02C5E553u);   /* fadd.d fa0, fa1, fa2, rm = 110 */
        break;
    case 6: /* dynamic rounding with a LEGAL frm */
        CSR_W(CSR_FRM, (r >> 32) % 5u);
        IDU_M_FP2_RM("fadd.d", "dyn", a, b);
        break;
    default: /* dynamic rounding with an ILLEGAL frm -- one instruction only */
        CSR_W(CSR_FRM, 5u + ((r >> 32) % 3u));
        IDU_M_FP2_RM("fadd.d", "dyn", a, b);
        break;
    }

    CSR_W(CSR_FCSR, keep & 0xFFUL);
}

/* ==================================================================== *
 * Group 7: mstatus.FS == 0
 *   With FS off, decd_flsu_illegal (aq_idu_id_decd.v:905-921) makes every FP
 *   load and store illegal -- including the four Xtheadc flr/fsr forms, which
 *   is the only place decd_flsu_illegal and decd_sel[4] interact -- and
 *   fp_fs_illegal (:952) makes every OP-FP instruction illegal.
 *
 * mstatus is saved and restored around the whole group, and the body is pure
 * asm so that nothing the compiler inserts can touch an FP register while FS is
 * off.
 * ==================================================================== */
static void g_fs_zero(u64 r)
{
    u64 keep = CSR_R(CSR_MSTATUS);
    u64 p = IDU_PTR(r >> 5);

    CSR_C(CSR_MSTATUS, MSTATUS_FS);

    switch ((unsigned)((r >> 16) % 6u)) {
    case 0: __asm__ volatile ("flw fa0, 0(%0)" :: "r"(p) : "memory"); break;
    case 1: __asm__ volatile ("fld fa0, 8(%0)" :: "r"(p) : "memory"); break;
    case 2: __asm__ volatile ("fsd fa0, 16(%0)" :: "r"(p) : "memory"); break;
    case 3: __asm__ volatile ("fadd.d fa0, fa0, fa0" ::: "memory"); break;
    case 4: /* the compressed FP load/store arms of decd_flsu_illegal */
        IDU_C_PTR("c.fld  fa0, 0(a1)\n\t"
                  "c.fsd  fa0, 8(a1)", p);
        break;
    default: /* th.flrd / th.fsrd: illegal via decd_flsu_illegal even though
              * they also live behind decd_sel[4] */
        IDU_ADDR_OP(TH_IDX(TH_FLRD_B, IDU_RD, 0, IDU_RS2, 0), p);
        IDU_ADDR_OP(TH_IDX(TH_FSRD_B, IDU_RD, 0, IDU_RS2, 0), p);
        break;
    }

    CSR_W(CSR_MSTATUS, keep);
}

/* ==================================================================== *
 * Group 8: the 25-arm cache / sync sub-decoder
 *   aq_idu_id_decd.v:3004-3159, casez on {inst[25], inst[24:20], inst[19:15]}.
 *   Reached only through decd_sel[3], which needs
 *   {inst[31:26], inst[14:0]} == 21'b000000_000_00000_0001011 AND
 *   cp0_idu_cskyee (:1004-1006) -- so inst[31:26] is a don't-care and the whole
 *   table disappears when MXSTATUS.THEADISAEE is clear (group 9).
 *
 * DCACHE_SAFE_POINT() precedes every arm, not just the invalidate-without-
 * writeback ones: it costs a clean+invalidate we would mostly have wanted
 * anyway, and it removes the need to get the "does this one write back?"
 * question right at each of 25 call sites.
 * ==================================================================== */
static void g_cache_sync_table(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);
    u64 sw = (r >> 11) & 0xFFUL;   /* a set/way index for the *sw forms */

    DCACHE_SAFE_POINT();

    switch ((unsigned)((r >> 16) % 26u)) {
    case 0:  TH_OP(TH_DCACHE_CALL);   break;
    case 1:  TH_OP(TH_DCACHE_IALL);   break;   /* no writeback */
    case 2:  TH_OP(TH_DCACHE_CIALL);  break;
    case 3:  TH_OP_RS1(TH_DCACHE_CSW,  sw); break;
    case 4:  TH_OP_RS1(TH_DCACHE_ISW,  sw); break;   /* no writeback */
    case 5:  TH_OP_RS1(TH_DCACHE_CISW, sw); break;
    case 6:  TH_OP_RS1(TH_DCACHE_CVAL1, p); break;
    case 7:  TH_OP_RS1(TH_DCACHE_CVA,   p); break;
    case 8:  TH_OP_RS1(TH_DCACHE_IVA,   p); break;   /* no writeback */
    case 9:  TH_OP_RS1(TH_DCACHE_CIVA,  p); break;
    case 10: TH_OP_RS1(TH_DCACHE_CPAL1, p); break;
    case 11: TH_OP_RS1(TH_DCACHE_CPA,   p); break;
    case 12: TH_OP_RS1(TH_DCACHE_IPA,   p); break;   /* no writeback */
    case 13: TH_OP_RS1(TH_DCACHE_CIPA,  p); break;
    case 14: TH_OP(TH_ICACHE_IALL);   break;   /* re-encoded as FUNC_FENCEI */
    case 15: TH_OP(TH_ICACHE_IALLS);  break;
    case 16: TH_OP(TH_L2CACHE_CALL);  break;   /* dst == 2'b00: silent no-op */
    case 17: TH_OP(TH_L2CACHE_IALL);  break;
    case 18: TH_OP(TH_L2CACHE_CIALL); break;
    case 19: TH_OP(TH_SYNC);          break;
    case 20: TH_OP(TH_SYNC_S);        break;
    case 21: TH_OP(TH_SYNC_I);        break;
    case 22: TH_OP(TH_SYNC_IS);       break;
    case 23: /* the two arms that are handled in the splitter rather than here
              * (":deal in fence / split"): group 21 covers the crack itself */
        TH_OP_RS1(TH_ICACHE_IVA, p);
        break;
    case 24:
        TH_OP_RS1(TH_ICACHE_IPA, p);
        break;
    default: /* an undecoded {inst[25], inst[24:20]} combination -> the table's
              * `default: decd_cache_illegal = 1'b1` arm (:3155) */
        IDU_WORD(0x0040000Bu);
        break;
    }

    RAND_ICACHE_SYNC();
}

/* ==================================================================== *
 * Group 9: MXSTATUS.THEADISAEE == 0
 *   cp0_idu_cskyee gates both decd_sel[3] (:1005) and decd_sel[4] (:1010), so
 *   clearing it makes every th.* encoding fall through to the 32-bit table,
 *   whose casez has no arm for opcode 0001011 -- i.e. illegal. It also clears
 *   lsd_split_type and che_split_type (aq_idu_id_split.v:152, :610), so the
 *   cracking FSMs cannot start either.
 *
 * A decode path nothing else in the repo covers, and the reason no th.* op --
 * including DCACHE_SAFE_POINT() -- may appear between the two mxstatus writes.
 * ==================================================================== */
static void g_theadisaee_off(u64 r)
{
    u64 keep = CSR_R(CSR_MXSTATUS);
    u64 p = IDU_PTR(r >> 5);

    CSR_C(CSR_MXSTATUS, MXSTATUS_THEADISAEE);

    switch ((unsigned)((r >> 16) % 6u)) {
    case 0: IDU_WORD(TH_DCACHE_CIALL);              break; /* decd_sel[3] leg */
    case 1: IDU_WORD(TH_SYNC);                      break;
    case 2: IDU_WORD(TH_R(TH_ADDSL_B, IDU_RD, IDU_RS1, IDU_RS2));
            break;                                         /* decd_sel[4] leg */
    case 3: IDU_WORD(TH_EXT(TH_EXT_B, IDU_RD, IDU_RS1, 31, 0)); break;
    case 4: IDU_ADDR_OP(TH_IDX(TH_LRD_B, IDU_RD, 0, IDU_RS2, 0), p); break;
    default:IDU_ADDR_OP(TH_IDX(TH_LWD_B, IDU_RD, 0, IDU_RD2, 0), p);
            break;                                  /* lsd_split_type is 0 too */
    }

    CSR_W(CSR_MXSTATUS, keep);
}

/* ==================================================================== *
 * Groups 10-16: the Xtheadc sub-decoder
 *   aq_idu_id_decd.v:3187-3730, casez on {inst[31:25], inst[14:12]}, reached
 *   through decd_sel[4] (opcode 0001011 with funct3 != 000 and cskyee).
 *
 * Raw words throughout: THEAD_GCC=0 builds have -march=rv64imafdc_zfh, which
 * has no xtheadc at all, so a mnemonic would not assemble on macOS. The word
 * builders are in rand_th_insn.h and the operand slots in idu_encodings.h.
 * ==================================================================== */

/* Group 10: the arithmetic arms. th.addsl's imm2 lives in inst[26:25] and
 * reaches the ALU as alu_adder_src2[6:5] (aq_iu_alu.v:217), so all four values
 * are separate decode points. */
static void g_xtheadc_alu(u64 r)
{
    u64 a = IDU_POOL(r >> 5);
    u64 b = IDU_POOL(r >> 7);

    switch ((unsigned)((r >> 16) % 12u)) {
    case 0:  IDU_ADDSL(0, a, b); break;
    case 1:  IDU_ADDSL(1, a, b); break;
    case 2:  IDU_ADDSL(2, a, b); break;
    case 3:  IDU_ADDSL(3, a, b); break;
    case 4:  IDU_I(TH_SRRI_B,  0,  a); break;   /* imm6 == 0: a full rotate  */
    case 5:  IDU_I(TH_SRRI_B,  1,  a); break;
    case 6:  IDU_I(TH_SRRI_B,  63, a); break;
    case 7:  IDU_I(TH_SRRIW_B, 0,  a); break;   /* imm5 for the .w form      */
    case 8:  IDU_I(TH_SRRIW_B, 31, a); break;
    case 9:  IDU_I(TH_TST_B,   5,  a); break;   /* tst: bit test on src1[5:0] */
    case 10: IDU_R(TH_MVEQZ_B, a, b); break;
    default: IDU_R(TH_MVNEZ_B, a, b); break;
    }
}

/* Group 11: the bit-manipulation arms. All five of tstnbz/ff0/ff1/rev/revw
 * require rs2 == 0; group 27 covers the illegal side. th.ext/extu take msb in
 * inst[31:26] and lsb in inst[25:20] and the ALU computes msb-lsb
 * (aq_iu_alu.v:393), so msb < lsb is a legal encoding with a wrapping count --
 * worth issuing precisely because nothing rejects it. */
static void g_xtheadc_bits(u64 r)
{
    u64 a = IDU_POOL(r >> 5);

    switch ((unsigned)((r >> 16) % 10u)) {
    case 0: IDU_R0(TH_TSTNBZ_B, a); break;
    case 1: IDU_R0(TH_FF0_B,    a); break;
    case 2: IDU_R0(TH_FF1_B,    a); break;
    case 3: IDU_R0(TH_REV_B,    a); break;
    case 4: IDU_R0(TH_REVW_B,   a); break;
    case 5: IDU_EXT(TH_EXT_B,  63, 0,  a); break;
    case 6: IDU_EXT(TH_EXT_B,  31, 16, a); break;
    case 7: IDU_EXT(TH_EXTU_B, 63, 0,  a); break;
    case 8: IDU_EXT(TH_EXTU_B, 7,  0,  a); break;
    default:IDU_EXT(TH_EXTU_B, 0,  63, a); break;   /* msb < lsb */
    }
}

/* Group 12: the multiply-accumulate arms. These are the only Xtheadc
 * encodings whose rd is also a source, so they are the only ones that put an
 * MULT-typed producer and an MULT-typed destination on the same register --
 * which is what the WAW except's both-MULT term needs (aq_idu_id_ctrl.v:514). */
static void g_xtheadc_mac(u64 r)
{
    u64 acc = IDU_POOL(r >> 5);
    u64 a = IDU_POOL(r >> 7);
    u64 b = IDU_POOL(r >> 11);

    switch ((unsigned)((r >> 16) % 6u)) {
    case 0: IDU_ACC(TH_MULA_B,  acc, a, b); break;
    case 1: IDU_ACC(TH_MULS_B,  acc, a, b); break;
    case 2: IDU_ACC(TH_MULAW_B, acc, a, b); break;
    case 3: IDU_ACC(TH_MULSW_B, acc, a, b); break;
    case 4: IDU_ACC(TH_MULAH_B, acc, a, b); break;
    default:IDU_ACC(TH_MULSH_B, acc, a, b); break;
    }
}

/* Group 13: the register-indexed loads. The shift amount is inst[26:25] and
 * reaches the LSU as src3 (decd_lsr_src3_imm_vld, aq_idu_id_decd.v:634-637 --
 * note this is the !inst[27] half of the funct3 == 10x space; the inst[27]
 * half is the index-update family in group 14, which uses
 * decd_src1_imm_sel[12] == 14'h1000 instead).
 *
 * The shift is an instruction FIELD, so it has to be a literal -- see
 * idu_encodings.h on why every encoding is a compile-time constant. It is
 * therefore cycled 0,1,2,3 across the arms rather than randomised: what matters
 * is that all four values of inst[26:25] are issued, not which base each one
 * lands on. The index register is kept at 0..3 so that base + (idx << 3) cannot
 * leave rand_scratch. */
static void g_xtheadc_lr(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);
    u64 idx = (r >> 42) & 3u;

    switch ((unsigned)((r >> 16) % 14u)) {
    case 0:  IDU_IDXLD(TH_LRB_B,   0, p, idx); break;
    case 1:  IDU_IDXLD(TH_LRH_B,   1, p, idx); break;
    case 2:  IDU_IDXLD(TH_LRW_B,   2, p, idx); break;
    case 3:  IDU_IDXLD(TH_LRD_B,   3, p, idx); break;
    case 4:  IDU_IDXLD(TH_LRBU_B,  0, p, idx); break;
    case 5:  IDU_IDXLD(TH_LRHU_B,  1, p, idx); break;
    case 6:  IDU_IDXLD(TH_LRWU_B,  2, p, idx); break;
    case 7:  IDU_IDXLD(TH_LURB_B,  3, p, idx); break;
    case 8:  IDU_IDXLD(TH_LURH_B,  0, p, idx); break;
    case 9:  IDU_IDXLD(TH_LURW_B,  1, p, idx); break;
    case 10: IDU_IDXLD(TH_LURD_B,  2, p, idx); break;
    case 11: IDU_IDXLD(TH_LURBU_B, 3, p, idx); break;
    case 12: IDU_IDXLD(TH_LURHU_B, 0, p, idx); break;
    default: IDU_IDXLD(TH_LURWU_B, 1, p, idx); break;
    }
}

/* Group 14: the index-update loads.
 *
 * These are the ONLY encodings in the ISA that set dst1 = inst[19:15]
 * (aq_idu_id_decd.v:764), so they are the only route to ctrl_dis_dst1_waw
 * (aq_idu_id_ctrl.v:497) and to the second writeback port carrying a different
 * register from the first. The register they update is IDU_BASE (a3), which
 * always holds a pointer into rand_scratch and is never sp, gp or tp -- an
 * index-update form aimed at sp would silently move the stack.
 *
 * imm5 is inst[24:20] and is sign-extended before the shift, so the reachable
 * displacement is -16..15 scaled by 1/2/4/8, i.e. at most +/-120 bytes: inside
 * the 256-byte margin idu_defs.h leaves around every IDU_PTR. Both imm5 and the
 * shift are instruction fields and therefore literals; the shift is cycled
 * 0..3 across the arms for the same reason as in group 13. */
static void g_xtheadc_idxupd(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);

    switch ((unsigned)((r >> 16) % 14u)) {
    case 0:  IDU_IDXUPD(TH_LBIB_B,  0, 1,  p); break;
    case 1:  IDU_IDXUPD(TH_LBIA_B,  0, 31, p); break;   /* imm5 == -1 */
    case 2:  IDU_IDXUPD(TH_LHIB_B,  1, 2,  p); break;
    case 3:  IDU_IDXUPD(TH_LHIA_B,  1, 30, p); break;
    case 4:  IDU_IDXUPD(TH_LWIB_B,  2, 1,  p); break;
    case 5:  IDU_IDXUPD(TH_LWIA_B,  2, 0,  p); break;   /* imm5 == 0 */
    case 6:  IDU_IDXUPD(TH_LDIB_B,  3, 1,  p); break;
    case 7:  IDU_IDXUPD(TH_LDIA_B,  3, 15, p); break;   /* imm5 == +15 */
    case 8:  IDU_IDXUPD(TH_LBUIB_B, 0, 1,  p); break;
    case 9:  IDU_IDXUPD(TH_LBUIA_B, 1, 16, p); break;   /* imm5 == -16 */
    case 10: IDU_IDXUPD(TH_LHUIB_B, 2, 2,  p); break;
    case 11: IDU_IDXUPD(TH_LHUIA_B, 3, 1,  p); break;
    case 12: IDU_IDXUPD(TH_LWUIB_B, 1, 1,  p); break;
    default: IDU_IDXUPD(TH_LWUIA_B, 2, 1,  p); break;
    }
}

/* Group 15: the Xtheadc stores. For opcode 0001011 the store data is
 * src2 = inst[11:7], not inst[24:20]: decd_inst_src2_reg_32bit_24_20 only
 * matches opcodes 0100011 and 0100111 (aq_idu_id_decd.v:698-701), so everything
 * else with inst[1:0] == 11 falls to the inst[11:7] term. */
static void g_xtheadc_stores(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);
    u64 v = IDU_POOL(r >> 7);
    u64 idx = (r >> 42) & 3u;

    switch ((unsigned)((r >> 16) % 16u)) {
    case 0:  IDU_IDXST(TH_SRB_B,  0, v, p, idx); break;
    case 1:  IDU_IDXST(TH_SRH_B,  1, v, p, idx); break;
    case 2:  IDU_IDXST(TH_SRW_B,  2, v, p, idx); break;
    case 3:  IDU_IDXST(TH_SRD_B,  3, v, p, idx); break;
    case 4:  IDU_IDXST(TH_SURB_B, 0, v, p, idx); break;
    case 5:  IDU_IDXST(TH_SURH_B, 1, v, p, idx); break;
    case 6:  IDU_IDXST(TH_SURW_B, 2, v, p, idx); break;
    case 7:  IDU_IDXST(TH_SURD_B, 3, v, p, idx); break;
    case 8:  IDU_IDXSTUPD(TH_SBIB_B, 0, 1,  v, p); break;
    case 9:  IDU_IDXSTUPD(TH_SBIA_B, 0, 31, v, p); break;
    case 10: IDU_IDXSTUPD(TH_SHIB_B, 1, 2,  v, p); break;
    case 11: IDU_IDXSTUPD(TH_SHIA_B, 1, 30, v, p); break;
    case 12: IDU_IDXSTUPD(TH_SWIB_B, 2, 1,  v, p); break;
    case 13: IDU_IDXSTUPD(TH_SWIA_B, 2, 0,  v, p); break;
    case 14: IDU_IDXSTUPD(TH_SDIB_B, 3, 1,  v, p); break;
    default: IDU_IDXSTUPD(TH_SDIA_B, 3, 15, v, p); break;
    }
}

/* Group 16: the Xtheadc FP indexed loads and stores. These are the only
 * encodings that are both decd_sel[4] (the perf table) and decd_flsu_illegal
 * candidates (aq_idu_id_decd.v:914-921), which is why group 7 issues two of
 * them with FS == 0. */
static void g_xtheadc_fp(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);
    u64 v = IDU_FPOOL(r >> 7);
    u64 idx = (r >> 42) & 1u;

    switch ((unsigned)((r >> 16) % 8u)) {
    case 0: IDU_FIDXLD(TH_FLRW_B,  2, p, idx); break;
    case 1: IDU_FIDXLD(TH_FLRD_B,  3, p, idx); break;
    case 2: IDU_FIDXLD(TH_FLURW_B, 0, p, idx); break;
    case 3: IDU_FIDXLD(TH_FLURD_B, 1, p, idx); break;
    case 4: IDU_FIDXST(TH_FSRW_B,  2, v, p, idx); break;
    case 5: IDU_FIDXST(TH_FSRD_B,  3, v, p, idx); break;
    case 6: IDU_FIDXST(TH_FSURW_B, 0, v, p, idx); break;
    default:IDU_FIDXST(TH_FSURD_B, 1, v, p, idx); break;
    }
}

/* ==================================================================== *
 * Group 17: the dead vector decoder's boundary
 *   decd_sel[5] = 1'b0 (aq_idu_id_decd.v:1011) and decd_vec_illegal is
 *   therefore never selected, so an RVV encoding is not "illegal because the
 *   vector decoder said so" -- it is illegal because opcode 1010111 has no arm
 *   in the 32-bit table and decd_sel[0] is 1. One cheap group that confirms the
 *   boundary from the outside; nothing inside the vector decoder is targeted.
 * ==================================================================== */
static void g_rvv_illegal(u64 r)
{
    switch ((unsigned)((r >> 16) % 10u)) {
    case 0: IDU_WORD(IDU_VEC_OPIVV);  break;
    case 1: IDU_WORD(IDU_VEC_OPFVV);  break;
    case 2: IDU_WORD(IDU_VEC_OPMVV);  break;
    case 3: IDU_WORD(IDU_VEC_OPIVI);  break;
    case 4: IDU_WORD(IDU_VEC_OPIVX);  break;
    case 5: IDU_WORD(IDU_VEC_OPFVF);  break;
    case 6: IDU_WORD(IDU_VEC_OPMVX);  break;
    case 7: IDU_WORD(IDU_VEC_OPCFG);  break;
    case 8: IDU_WORD(IDU_VEC_LOAD);   break;
    default:IDU_WORD(IDU_VEC_STORE);  break;
    }
}

/* ==================================================================== *
 * Group 18: the load-store-double cracking FSM
 *   aq_idu_id_split.v:153-295. lsd_split_type recognises th.lwd / lwud / ldd /
 *   swd / sdd (:152-159); lsd_word = !inst[27] (:167) picks the 4-byte or
 *   8-byte stride; imm2 = inst[26:25] (:169-172) scales the first uop's offset
 *   by 8 or 16 and the second is +4 or +8 on top. IDU_SPLIT is set on the first
 *   uop only (:250, :288), which is what tells the RTU the pair is one
 *   instruction.
 *
 * imm2 is an instruction field and therefore a literal, so the switch is the
 * full 5 x 4 cross rather than a random shift: all four imm2 values on all five
 * instruction shapes, which is the whole reachable state of this FSM's offset
 * arithmetic. The largest effective address is base + 3*16 + 8 = base + 56,
 * inside the margin IDU_PTR_LINE leaves.
 * ==================================================================== */
static void g_lsd_split(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);
    u64 a = IDU_POOL(r >> 7);
    u64 b = IDU_POOL(r >> 11);

    switch ((unsigned)((r >> 16) % 20u)) {
    /* lsd_word = 1 (inst[27] == 0), FUNC_LW: offset imm2*8, then +4 */
    case 0:  IDU_LSDLD(TH_LWD_B,  0, p); break;
    case 1:  IDU_LSDLD(TH_LWD_B,  1, p); break;
    case 2:  IDU_LSDLD(TH_LWD_B,  2, p); break;
    case 3:  IDU_LSDLD(TH_LWD_B,  3, p); break;
    /* lsd_word = 1, FUNC_LWU (inst[28] == 1) */
    case 4:  IDU_LSDLD(TH_LWUD_B, 0, p); break;
    case 5:  IDU_LSDLD(TH_LWUD_B, 1, p); break;
    case 6:  IDU_LSDLD(TH_LWUD_B, 2, p); break;
    case 7:  IDU_LSDLD(TH_LWUD_B, 3, p); break;
    /* lsd_word = 0 (inst[27] == 1), FUNC_LD: offset imm2*16, then +8 */
    case 8:  IDU_LSDLD(TH_LDD_B,  0, p); break;
    case 9:  IDU_LSDLD(TH_LDD_B,  1, p); break;
    case 10: IDU_LSDLD(TH_LDD_B,  2, p); break;
    case 11: IDU_LSDLD(TH_LDD_B,  3, p); break;
    /* the store side: src2 comes from inst[11:7] then inst[24:20] (:284-286) */
    case 12: IDU_LSDST(TH_SWD_B,  0, a, b, p); break;
    case 13: IDU_LSDST(TH_SWD_B,  1, a, b, p); break;
    case 14: IDU_LSDST(TH_SWD_B,  2, a, b, p); break;
    case 15: IDU_LSDST(TH_SWD_B,  3, a, b, p); break;
    case 16: IDU_LSDST(TH_SDD_B,  0, a, b, p); break;
    case 17: IDU_LSDST(TH_SDD_B,  1, a, b, p); break;
    case 18: IDU_LSDST(TH_SDD_B,  2, a, b, p); break;
    default: IDU_LSDST(TH_SDD_B,  3, a, b, p); break;
    }
}

/* ==================================================================== *
 * Group 19: an LSD crack interrupted between its two uops
 *   The FSM resets on rtu_idu_flush_fe || iu_yy_xx_cancel
 *   (aq_idu_id_split.v:185-186) and freezes on ctrl_xx_dis_stall (:188-191).
 *   Three recipes, chosen at random:
 *
 *   (a) dispatch stall. ctrl_dis_stall includes ctrl_ex1_stall
 *       (aq_idu_id_ctrl.v:390-394), so filling the LSU queue with D$-missing
 *       loads and then issuing the th.lwd freezes the FSM in LSD_SPLIT with
 *       lsu_idu_full asserted. A long div immediately before the pair adds the
 *       dependency-stall variant: the base register is produced by the divider,
 *       so uop0 cannot dispatch and the FSM holds in LSD_IDLE with
 *       lsd_sm_start high -- the other side of the same `else` branch.
 *   (b) cancel. A data-dependent branch on a random value mispredicts about
 *       half the time; putting the th.lwd in its shadow drives
 *       iu_yy_xx_cancel while the FSM is mid-crack.
 *   (c) flush. With MXSTATUS.MM clear, hardware misaligned support is off, so a
 *       th.lwd on an odd address takes a load-address-misaligned exception on
 *       uop0 and the RTU flushes the front end. MM is restored immediately and
 *       nothing between the two writes performs an unaligned access.
 * ==================================================================== */
static void g_lsd_interrupted(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);

    switch ((unsigned)((r >> 16) % 4u)) {
    case 0: /* (a) LSU-full freeze */
        idu_fill_lsu(8);
        IDU_LSDLD(TH_LDD_B, 2, p);
        break;
    case 1: /* (a') dependency stall: the pair's base register IS the divider's
             * destination, so uop0 cannot dispatch until the divide retires and
             * the FSM holds in LSD_IDLE with lsd_sm_start asserted -- the other
             * side of the same `else ctrl_xx_dis_stall` branch. Dividing the
             * pointer by an opaque 1 keeps the address exact. */
        {
            register u64 d0_ __asm__("a0");
            register u64 d1_ __asm__("a4");
            register u64 p_  __asm__("a3");
            u64 one = (u64)((r >> 7) & 0u) + 1u;

            __asm__ volatile ("div a3, %[p], %[one]\n\t"
                              ".word %[w_]"
                              : "=&r"(d0_), "=&r"(d1_), "=&r"(p_)
                              : [p]"r"(p), [one]"r"(one),
                                [w_]"n"(TH_IDX(TH_LWD_B, IDU_RD, IDU_BASE,
                                               IDU_RD2, 1))
                              : "memory");
            rand_sink += d0_ + d1_ + p_;
        }
        break;
    case 2: /* (b) cancel out of a mispredicting branch */
        {
            u64 v = IDU_POOL(r >> 7);
            register u64 d0_ __asm__("a0");
            register u64 d1_ __asm__("a4");
            register u64 p_  __asm__("a3") = p;
            __asm__ volatile ("beq %[v_], zero, 1f\n\t"
                              ".word %[w_]\n"
                              "1:"
                              : "=r"(d0_), "=r"(d1_), "+r"(p_)
                              : [w_]"n"(TH_IDX(TH_LDD_B, IDU_RD, IDU_BASE,
                                               IDU_RD2, 0)),
                                [v_]"r"(v) : "memory");
            rand_sink += d0_ + d1_;
        }
        break;
    default: /* (c) misaligned uop0 with hardware misaligned support off */
        {
            u64 keep = CSR_R(CSR_MXSTATUS);
            CSR_C(CSR_MXSTATUS, MXSTATUS_MM);
            IDU_LSDLD(TH_LDD_B, 0, p + 3u);
            CSR_W(CSR_MXSTATUS, keep);
        }
        break;
    }
}

/* ==================================================================== *
 * Group 20: the AMO cracking FSM
 *   aq_idu_id_split.v:365-369 declares five states (AMO_IDLE, AMO_AMO, AMO_LR,
 *   AMO_SC, AMO_AQ) and :390-408 is an eight-arm priority chain out of
 *   AMO_IDLE keyed on {lr_inst, sc_inst, amo_aq_inst, amo_rl_inst}. The
 *   ordering bits are amo_aq_inst = inst[26] and amo_rl_inst = inst[25]
 *   (:333-334), so the {lr, sc, amo} x {none, aq, rl, aqrl} matrix is twelve
 *   distinct paths through that chain -- and `aqrl` is the only shape that
 *   produces THREE uops: a leading fence, the operation, and a trailing fence
 *   (:428-467 and :583-597).
 *
 * Every address is an 8-byte-aligned slot in rand_scratch, i.e. normal
 * cacheable SRAM. An AMO aimed at the APB window or the strong-order window
 * would tell us nothing about the IDU and a great deal about hanging the bus.
 * ==================================================================== */
static void g_amo_matrix(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);
    u64 v = IDU_POOL(r >> 7);

    switch ((unsigned)((r >> 16) % 24u)) {
    /* lr x {none, aq, rl, aqrl} */
    case 0:  IDU_M_LR("lr.w",         p); break;
    case 1:  IDU_M_LR("lr.w.aq",      p); break;
    case 2:  IDU_M_LR("lr.w.rl",      p); break;
    case 3:  IDU_M_LR("lr.w.aqrl",    p); break;
    case 4:  IDU_M_LR("lr.d",         p); break;
    case 5:  IDU_M_LR("lr.d.aqrl",    p); break;
    /* sc x {none, aq, rl, aqrl}. sc without a preceding lr simply fails, which
     * is a perfectly good decode stimulus. */
    case 6:  IDU_M_AMO("sc.w",        p, v); break;
    case 7:  IDU_M_AMO("sc.w.aq",     p, v); break;
    case 8:  IDU_M_AMO("sc.w.rl",     p, v); break;
    case 9:  IDU_M_AMO("sc.w.aqrl",   p, v); break;
    case 10: IDU_M_AMO("sc.d",        p, v); break;
    case 11: IDU_M_AMO("sc.d.aqrl",   p, v); break;
    /* amo* x {none, aq, rl, aqrl}: all nine funct5 values appear, each with at
     * least one ordering combination, and the aqrl three-uop shape appears on
     * both widths. */
    case 12: IDU_M_AMO("amoadd.w",       p, v); break;
    case 13: IDU_M_AMO("amoadd.d.aqrl",  p, v); break;
    case 14: IDU_M_AMO("amoswap.w.aq",   p, v); break;
    case 15: IDU_M_AMO("amoswap.d.rl",   p, v); break;
    case 16: IDU_M_AMO("amoxor.w.rl",    p, v); break;
    case 17: IDU_M_AMO("amoxor.d.aq",    p, v); break;
    case 18: IDU_M_AMO("amoand.w.aqrl",  p, v); break;
    case 19: IDU_M_AMO("amoor.d",        p, v); break;
    case 20: IDU_M_AMO("amomin.w.aq",    p, v); break;
    case 21: IDU_M_AMO("amomax.d.rl",    p, v); break;
    case 22: IDU_M_AMO("amominu.w.aqrl", p, v); break;
    default: IDU_M_AMO("amomaxu.d",      p, v); break;
    }
}

/* ==================================================================== *
 * Group 21: the icache.iva / icache.ipa crack
 *   aq_idu_id_split.v:608-704. Each is cracked into a D-cache clean followed by
 *   an I-cache invalidate: che_va = !inst[23] (:622) selects
 *   dcache.cva + icache.iva or dcache.cpa + icache.ipa, EU_LSU for the first
 *   uop and EU_CP0 for the second, with IDU_SPLIT on the first only.
 *
 * The privilege guard is the point of interest (:610-613): icache.iva is
 * allowed from U mode when MXSTATUS.UCME is set, but icache.ipa has NO UCME
 * escape and is therefore *always* illegal from U. Both legs are exercised from
 * U mode with UCME set and clear.
 *
 * The address argument must never land in 0x1000_0000..0x1FFF_FFFF: an I-cache
 * operation there reaches the AXI-to-AHB-to-APB path, which cannot service the
 * 4-beat WRAP burst a refill turns into. IDU_PTR_LINE keeps it in .bss.
 * ==================================================================== */
static void idu_che_umode_body(void)
{
    u64 p = (u64)(unsigned long)&rand_scratch[48];

    if (idu_mode_arg & 1u)
        TH_OP_RS1(TH_ICACHE_IVA, p);   /* legal iff UCME */
    else
        TH_OP_RS1(TH_ICACHE_IPA, p);   /* always illegal from U */

    __asm__ volatile ("ecall" ::: "memory");
}

static void g_che_split(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);
    u64 keep;

    switch ((unsigned)((r >> 16) % 4u)) {
    case 0: /* both crack legs from M mode, where the guard is satisfied by
             * cp0_yy_priv_mode != 2'b0 alone */
        DCACHE_SAFE_POINT();
        TH_OP_RS1(TH_ICACHE_IVA, p);
        TH_OP_RS1(TH_ICACHE_IPA, p);
        RAND_ICACHE_SYNC();
        break;
    case 1: /* U mode with UCME set: iva cracks, ipa is illegal */
    case 2:
        keep = CSR_R(CSR_MXSTATUS);
        CSR_S(CSR_MXSTATUS, MXSTATUS_UCME);
        idu_mode_arg = (r >> 20) & 1u;
        DCACHE_SAFE_POINT();
        rand_run_in_umode(&idu_che_umode_body);
        idu_priv_trips++;
        CSR_W(CSR_MXSTATUS, keep);
        RAND_ICACHE_SYNC();
        break;
    default: /* U mode with UCME clear: both legs illegal */
        keep = CSR_R(CSR_MXSTATUS);
        CSR_C(CSR_MXSTATUS, MXSTATUS_UCME);
        idu_mode_arg = (r >> 20) & 1u;
        DCACHE_SAFE_POINT();
        rand_run_in_umode(&idu_che_umode_body);
        idu_priv_trips++;
        CSR_W(CSR_MXSTATUS, keep);
        RAND_ICACHE_SYNC();
        break;
    }
}

/* ==================================================================== *
 * Group 22: the sfence.vma crack
 *   aq_idu_id_split.v:721-811. fnc_split_type is a bare encoding compare with
 *   no cskyee and no privilege term (:727), and the crack is FUNC_SFENCE
 *   (src0 = rs1, src1 = rs2) followed by FUNC_SYNCI (src0 = rs1).
 *
 * satp stays Bare, so the TLB flush has nothing to invalidate and cannot lose
 * us access to our own code. mstatus.TVM is irrelevant in M mode and is held at
 * 0 by rand_restore_sane_state anyway.
 * ==================================================================== */
static void g_fnc_split(u64 r)
{
    u64 asid = IDU_POOL(r >> 5);
    u64 va = IDU_PTR(r >> 7);

    switch ((unsigned)((r >> 16) % 4u)) {
    case 0: __asm__ volatile ("sfence.vma" ::: "memory"); break;
    case 1: __asm__ volatile ("sfence.vma %0" :: "r"(va) : "memory"); break;
    case 2: __asm__ volatile ("sfence.vma zero, %0" :: "r"(asid) : "memory");
            break;
    default:__asm__ volatile ("sfence.vma %0, %1" :: "r"(va), "r"(asid)
                                                  : "memory"); break;
    }
}

/* ==================================================================== *
 * Groups 23, 24, 25: the generated sweeps
 *   Emitted by gen_idu_sweeps.py because they are finite and enumerable:
 *     23  the 14-arm decd_src1_imm_sel case (aq_idu_id_decd.v:543-561),
 *         13 arms reachable -- 14'h2000 needs decd_inst_vec, tied to 0
 *     24  the 7-arm decd_src2_imm_sel case (:618-628), all reachable
 *     25  the 96 shadow-GPR read-port mux bins (aq_idu_id_gpr.v:632-676 and
 *         the two ports after it), plus the index-select terms that do not come
 *         from a plain 32-bit field: c.mv's src0 = inst[6:2], the fmv/fcvtfx
 *         src1 override, the hardwired src0 = x2 forms, the compressed 3-bit
 *         destination arms, and c.jalr's hardwired dst0 = x1
 *
 * Calling the generated block is what makes those bins deterministic; group 25
 * then re-reads a random single register afterwards so that the same bins also
 * get seen interleaved with whatever the rest of the rotation is doing, which a
 * straight-line block on its own never achieves.
 * ==================================================================== */
static void g_imm_src1_sweep(u64 r)
{
    (void)r;
    idu_sweep_calls++;
    rand_sink += idu_sweep_imm_src1(&rand_scratch[IDU_SCRATCH_LO]);
}

static void g_imm_src2_sweep(u64 r)
{
    (void)r;
    idu_sweep_calls++;
    rand_sink += idu_sweep_imm_src2(&rand_scratch[IDU_SCRATCH_LO]);
}

static void g_regidx_sweep(u64 r)
{
    u64 v = IDU_POOL(r >> 5);

    idu_sweep_calls++;
    rand_sink += idu_sweep_regidx(&rand_scratch[IDU_SCRATCH_LO]);

    /* One extra read of one architectural register, to put a single mux bin in
     * a different pipeline context each visit. Reading x1/x2/x3/x4/x8 is safe
     * and is a coverage point; writing them never is, which is why the
     * destination is always compiler-chosen and the source is the literal. */
    switch ((unsigned)((r >> 16) % 20u)) {
    case 0:  IDU_READ_REG(1,  v); break;
    case 1:  IDU_READ_REG(2,  v); break;
    case 2:  IDU_READ_REG(3,  v); break;
    case 3:  IDU_READ_REG(4,  v); break;
    case 4:  IDU_READ_REG(8,  v); break;
    case 5:  IDU_READ_REG(9,  v); break;
    case 6:  IDU_READ_REG(5,  v); break;
    case 7:  IDU_READ_REG(6,  v); break;
    case 8:  IDU_READ_REG(7,  v); break;
    case 9:  IDU_READ_REG(16, v); break;
    case 10: IDU_READ_REG(17, v); break;
    case 11: IDU_READ_REG(18, v); break;
    case 12: IDU_READ_REG(19, v); break;
    case 13: IDU_READ_REG(20, v); break;
    case 14: IDU_READ_REG(21, v); break;
    case 15: IDU_READ_REG(22, v); break;
    case 16: IDU_READ_REG(23, v); break;
    case 17: IDU_READ_REG(27, v); break;
    case 18: IDU_READ_REG(30, v); break;
    default: IDU_READ_REG(31, v); break;
    }
}

/* ==================================================================== *
 * Group 26: reserved-field violations on the SYSTEM and LR encodings
 *   aq_idu_id_decd.v:855-878. Every arm of decd_i_illegal is a "this opcode is
 *   only legal with these exact reserved fields" check, and each is emitted
 *   here as a raw word with one reserved field set -- never as the bare legal
 *   instruction. That matters most for `wfi`: the arm has to be decoded, but
 *   executing a real WFI with nothing in (mie & mip) stops retirement for good.
 *   IDU_ILL_WFI is `wfi` with rd = x1, which decd_i_illegal rejects (:860-862)
 *   before the CP0 ever sees a low-power request.
 * ==================================================================== */
static void g_illegal_reserved(u64 r)
{
    switch ((unsigned)((r >> 16) % 10u)) {
    case 0: IDU_WORD(IDU_ILL_ECALL);  break;
    case 1: IDU_WORD(IDU_ILL_EBREAK); break;
    case 2: IDU_WORD(IDU_ILL_DRET);   break;   /* illegal outside debug mode */
    case 3: IDU_WORD(IDU_ILL_SRET);   break;
    case 4: IDU_WORD(IDU_ILL_WFI);    break;   /* NOT a wfi -- see above */
    case 5: IDU_WORD(IDU_ILL_MRET);   break;
    case 6: IDU_WORD(IDU_ILL_SFENCE); break;
    case 7: IDU_WORD(IDU_ILL_LR_W);   break;
    case 8: IDU_WORD(IDU_ILL_LR_D);   break;
    default:IDU_WORD(IDU_ILL_HFENCE); break;   /* unconditionally illegal */
    }
}

/* Group 27: the Xtheadc arm of decd_i_illegal (:875-878). tstnbz, rev, ff0 and
 * ff1 share one 15-bit compare; revw has its own 17-bit one. */
static void g_illegal_xtheadc(u64 r)
{
    switch ((unsigned)((r >> 16) % 5u)) {
    case 0: IDU_WORD(IDU_ILL_TSTNBZ); break;
    case 1: IDU_WORD(IDU_ILL_REV);    break;
    case 2: IDU_WORD(IDU_ILL_FF0);    break;
    case 3: IDU_WORD(IDU_ILL_FF1);    break;
    default:IDU_WORD(IDU_ILL_REVW);   break;
    }
}

/* Group 28: decd_c_illegal (:883-897). Six RTL terms, seven encodings -- the
 * c.addi16sp and c.lui halves of the funct3 == 011 term are distinguished only
 * by inst[11:7], so both are emitted. */
static void g_c_illegal(u64 r)
{
    switch ((unsigned)((r >> 16) % 7u)) {
    case 0: IDU_HALF(IDU_CILL_ADDI4SPN); break;
    case 1: IDU_HALF(IDU_CILL_ADDIW);    break;
    case 2: IDU_HALF(IDU_CILL_ADDI16SP); break;
    case 3: IDU_HALF(IDU_CILL_LUI);      break;
    case 4: IDU_HALF(IDU_CILL_LWSP);     break;
    case 5: IDU_HALF(IDU_CILL_LDSP);     break;
    default:IDU_HALF(IDU_CILL_JR);       break;
    }
}

/* ==================================================================== *
 * Group 29: per-operation privilege checks on the cache table
 *   Every arm of the cache table carries its own decd_cache_illegal term
 *   (aq_idu_id_decd.v:3004-3159) and they are NOT uniform:
 *     - dcache.iall/call/ciall, the *sw forms, and the *pa forms are
 *       M/S-only with no escape
 *     - dcache.cva/cval1/civa have a cp0_idu_ucme escape
 *     - sync / sync.s / sync.i / sync.is carry no privilege term at all and
 *       must be legal even from U mode
 *   MXSTATUS.PMDU and PMDS are toggled around the excursion as well: they do
 *   not gate the cache ops, but they are the other two per-privilege enables in
 *   the same register, and the HPCP group cares which way they were left.
 * ==================================================================== */
static void idu_priv_cache_body(void)
{
    u64 p = (u64)(unsigned long)&rand_scratch[56];

    switch ((unsigned)(idu_mode_arg & 7u)) {
    case 0: TH_OP(TH_DCACHE_CIALL);       break;   /* M/S only            */
    case 1: TH_OP_RS1(TH_DCACHE_CISW, 0); break;   /* M/S only            */
    case 2: TH_OP_RS1(TH_DCACHE_CVA,  p); break;   /* UCME escape         */
    case 3: TH_OP_RS1(TH_DCACHE_CIVA, p); break;   /* UCME escape         */
    case 4: TH_OP_RS1(TH_DCACHE_CPA,  p); break;   /* no escape           */
    case 5: TH_OP(TH_SYNC);               break;   /* no privilege term   */
    case 6: TH_OP(TH_SYNC_I);             break;   /* no privilege term   */
    default:TH_OP(TH_ICACHE_IALL);        break;   /* M/S only            */
    }

    __asm__ volatile ("ecall" ::: "memory");
}

static void g_priv_cacheops(u64 r)
{
    u64 keep = CSR_R(CSR_MXSTATUS);

    idu_mode_arg = (r >> 20) & 7u;

    if ((r >> 24) & 1u) CSR_S(CSR_MXSTATUS, MXSTATUS_UCME);
    else                CSR_C(CSR_MXSTATUS, MXSTATUS_UCME);
    if ((r >> 25) & 1u) CSR_S(CSR_MXSTATUS, MXSTATUS_PMDU | MXSTATUS_PMDS);
    else                CSR_C(CSR_MXSTATUS, MXSTATUS_PMDU | MXSTATUS_PMDS);

    /* Clean before dropping privilege: several of the bodies invalidate without
     * writing back, and a trap taken in S or U must not find stale globals. */
    DCACHE_SAFE_POINT();

    if ((r >> 16) & 1u) rand_run_in_smode(&idu_priv_cache_body);
    else                rand_run_in_umode(&idu_priv_cache_body);
    idu_priv_trips++;

    CSR_W(CSR_MXSTATUS, keep);
    RAND_ICACHE_SYNC();
}

/* ==================================================================== *
 * Group 30: RAW except arms 1 and 2 -- the ALU and BJU producers
 *   aq_idu_id_ctrl.v:432-433 (and :449-450, :465-466 for src1/src2): a producer
 *   typed WB_INT_TYPE_ALU or WB_INT_TYPE_BJU never causes a RAW stall, because
 *   its result can be forwarded out of EX1. Back-to-back is the only way to see
 *   it: at distance 2 or more the writeback tracker has already gone valid.
 *
 * The BJU leg uses a scratch link register. `jal ra, L` followed by a reader of
 * ra would be a producer/consumer pair on the return address, which is one
 * mispredicted trap away from losing the call stack.
 * ==================================================================== */
static void g_raw_alu_bju(u64 r)
{
    u64 a = IDU_POOL(r >> 5);
    u64 b = IDU_POOL(r >> 7);
    u64 d;

    switch ((unsigned)((r >> 16) % 4u)) {
    case 0: /* ALU -> ALU on src0, distance 1 */
        __asm__ volatile ("add a0, %1, %2\n\t"
                          "add %0, a0, %1"
                          : "=r"(d) : "r"(a), "r"(b) : "a0");
        break;
    case 1: /* ALU -> ALU on src1, distance 1 */
        __asm__ volatile ("add a0, %1, %2\n\t"
                          "add %0, %1, a0"
                          : "=r"(d) : "r"(a), "r"(b) : "a0");
        break;
    case 2: /* BJU -> ALU: a jal into a scratch link register, read next cycle */
        __asm__ volatile ("jal a1, 1f\n"
                          "1:\n\t"
                          "add %0, a1, %1"
                          : "=r"(d) : "r"(a) : "a1", "memory");
        break;
    default: /* a three-deep ALU chain, so that two producers are outstanding */
        __asm__ volatile ("add a0, %1, %2\n\t"
                          "add a2, a0, %2\n\t"
                          "add %0, a2, a0"
                          : "=r"(d) : "r"(a), "r"(b) : "a0", "a2");
        break;
    }
    rand_sink += d;
}

/* ==================================================================== *
 * Group 31: RAW except arm 2 -- an LSU producer feeding a conditional branch
 *   aq_idu_id_ctrl.v:436-441. A load result may go straight to a BJU consumer,
 *   but only when the consumer is a conditional branch (FUNC_CONDBR_SEL) and
 *   only while the producer's cnt is 0 or 1. cnt counts un-written-back
 *   producers on that register (aq_idu_id_wbt_entry.v:119-133), so cnt == 1
 *   needs a second outstanding load to the same register -- hence the two-load
 *   variant.
 * ==================================================================== */
static void g_raw_load_condbr(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);
    u64 b = IDU_POOL(r >> 7);

    switch ((unsigned)((r >> 16) % 3u)) {
    case 0: /* cnt == 0: one outstanding load, branch immediately after */
        __asm__ volatile ("ld  a0, 0(%0)\n\t"
                          "beq a0, %1, 1f\n\t"
                          "nop\n"
                          "1:"
                          :: "r"(p), "r"(b) : "a0", "memory");
        break;
    case 1: /* cnt == 1: two loads to the same register, then the branch */
        __asm__ volatile ("ld  a0, 0(%0)\n\t"
                          "ld  a0, 8(%0)\n\t"
                          "bne a0, %1, 1f\n\t"
                          "nop\n"
                          "1:"
                          :: "r"(p), "r"(b) : "a0", "memory");
        break;
    default: /* the same shape but with the load missing, so the consumer really
              * does have to wait: this is where cnt reaches 1 and stays there */
        idu_fill_lsu(4);
        __asm__ volatile ("ld  a0, 0(%0)\n\t"
                          "ld  a0, 64(%0)\n\t"
                          "blt a0, %1, 1f\n\t"
                          "nop\n"
                          "1:"
                          :: "r"((u64)(unsigned long)&idu_miss_arena[64]),
                             "r"(b) : "a0", "memory");
        break;
    }
}

/* ==================================================================== *
 * Group 32 (sparse): the forwarding bus
 *   RAW except arm 3 (aq_idu_id_ctrl.v:442-447) lets a forwardable producer
 *   through UNLESS it is LSU or MULT with cnt == 2, and the forward itself is
 *   nine comparators: three source ports x rtu_idu_fwd0/1/2
 *   (aq_idu_id_dp.v:639-727). Each has a `reg != 0` guard (:663, :693, :723) so
 *   that a producer whose destination is x0 cannot match a consumer reading x0.
 *
 * The generated chain block walks all three producer types at distances 1..4 on
 * all three ports plus the x0 guard; the extra dependent burst here adds the
 * cnt == 2 exclusion, which needs three outstanding producers.
 * ==================================================================== */
static void g_raw_fwd_bus(u64 r)
{
    u64 p = (u64)(unsigned long)&idu_miss_arena[0];
    u64 a = IDU_POOL(r >> 5);

    idu_sweep_calls++;
    rand_sink += idu_sweep_fwd_chain(&rand_scratch[IDU_SCRATCH_LO]);

    if ((r >> 16) & 1u) {
        /* three missing loads to one register, then a consumer: the producer's
         * cnt is 2, so the forward is NOT taken and the consumer stalls */
        idu_fill_lsu(2);
        __asm__ volatile ("ld  a0, 0(%0)\n\t"
                          "ld  a0, 64(%0)\n\t"
                          "ld  a0, 128(%0)\n\t"
                          "add a1, a0, %1"
                          :: "r"(p), "r"(a) : "a0", "a1", "memory");
    } else {
        /* the same with MULT producers, which share the cnt == 2 exclusion */
        __asm__ volatile ("mul a0, %0, %0\n\t"
                          "mul a0, a0, %0\n\t"
                          "mul a0, a0, %0\n\t"
                          "add a1, a0, %0"
                          :: "r"(a) : "a0", "a1");
    }
}

/* ==================================================================== *
 * Group 33 (sparse): the src2-only RAW except
 *   aq_idu_id_ctrl.v:478-484 is an arm that exists for src2 and nowhere else: a
 *   load feeding a STORE's data operand is allowed through at cnt 0, at cnt 1,
 *   or -- the sub-arm no other port has -- whenever
 *   wbt_ctrl_src2_info[WB_INT_WB_CNT2] says the first of two producers is
 *   writing back this cycle.
 * ==================================================================== */
static void g_raw_src2_store(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);
    u64 q = (u64)(unsigned long)&idu_miss_arena[128];

    switch ((unsigned)((r >> 16) % 3u)) {
    case 0: /* cnt == 0 */
        __asm__ volatile ("ld a0, 0(%0)\n\t"
                          "sd a0, 8(%0)"
                          :: "r"(p) : "a0", "memory");
        break;
    case 1: /* cnt == 1: two loads to the same register before the store */
        __asm__ volatile ("ld a0, 0(%0)\n\t"
                          "ld a0, 16(%0)\n\t"
                          "sd a0, 24(%0)"
                          :: "r"(p) : "a0", "memory");
        break;
    default: /* the WB_CNT2 sub-arm: make both producers miss so that the store
              * arrives while the first one is still on its way back */
        idu_fill_lsu(2);
        __asm__ volatile ("ld a0, 0(%0)\n\t"
                          "ld a0, 64(%0)\n\t"
                          "sd a0, 0(%1)"
                          :: "r"(q), "r"(p) : "a0", "memory");
        break;
    }
}

/* ==================================================================== *
 * Group 34 (sparse): cnt == 2
 *   cnt only increments when a producer allocates without a concurrent
 *   writeback (aq_idu_id_wbt_entry.v:126-148), and allocating past one
 *   outstanding producer at all requires the both-LSU-or-both-MULT WAW except
 *   (aq_idu_id_ctrl.v:494-536). So the ONLY route to cnt == 2 is three
 *   back-to-back same-typed producers writing the same register while none of
 *   them has come back yet: three D$-missing loads, or three multiplies.
 *
 * The loads stride 64 bytes over idu_miss_arena after a clean+invalidate of the
 * whole D-cache, which is cheaper than sizing an array past the 32 KB cache and
 * does not eat into the .text or MEM2 budget.
 * ==================================================================== */
static void g_waw_cnt2(u64 r)
{
    u64 p = (u64)(unsigned long)&idu_miss_arena[(r >> 5) & 0x3Fu];

    if ((r >> 16) & 1u) {
        idu_fill_lsu(1);
        __asm__ volatile ("ld a0, 0(%0)\n\t"
                          "ld a0, 64(%0)\n\t"
                          "ld a0, 128(%0)\n\t"
                          "ld a0, 192(%0)\n\t"
                          "add a1, a0, a0"
                          :: "r"((u64)(unsigned long)&idu_miss_arena[0])
                           : "a0", "a1", "memory");
    } else {
        u64 v = IDU_POOL(r >> 7) | 1UL;
        __asm__ volatile ("mul a0, %0, %0\n\t"
                          "mul a0, %0, %0\n\t"
                          "mul a0, %0, %0\n\t"
                          "add a1, a0, a0"
                          :: "r"(v) : "a0", "a1");
    }
    rand_sink += p;
}

/* ==================================================================== *
 * Group 35 (sparse): dst1_waw
 *   ctrl_dis_dst1_waw (aq_idu_id_ctrl.v:497-499) and its except (:523-536) can
 *   only fire for the two encodings that have a dst1 at all: the Xtheadc
 *   index-update memory forms, whose dst1 is inst[19:15]
 *   (aq_idu_id_decd.v:764), and the second uop of an LSD crack, whose dst0 is
 *   inst[24:20] (aq_idu_id_split.v:247). Pairing one of each on the same base
 *   register is the only way to get two dst1-carrying producers outstanding.
 * ==================================================================== */
static void g_waw_dst1(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);

    /* Both of these update a3, so a3 is written by an index-update dst1 and
     * then read as the base of the crack that follows. */
    IDU_IDXUPD(TH_LDIA_B, 3, 1, p);
    IDU_IDXUPD(TH_LDIB_B, 3, 31, p);
    IDU_LSDLD(TH_LDD_B, 1, p);

    if ((r >> 16) & 1u) {
        /* the same pair with the loads missing, so both producers are still
         * outstanding when the second allocates */
        idu_fill_lsu(2);
        IDU_IDXUPD(TH_LDIA_B, 0, 1,
                   (u64)(unsigned long)&idu_miss_arena[64]);
        IDU_IDXUPD(TH_LDIA_B, 0, 1,
                   (u64)(unsigned long)&idu_miss_arena[128]);
    }
}

/* ==================================================================== *
 * Group 36 (sparse): both writeback ports on one register
 *   dp_wb0_vld and dp_wb1_vld are two independent 32-bit one-hot vectors that
 *   are OR-ed into dp_wbt_wb_vld (aq_idu_id_dp.v:593-617). They land on the
 *   same bit only when one instruction writes the same GPR twice: an
 *   index-update load whose rd and rs1 are the same register, or an LSD pair
 *   aliased onto one register.
 * ==================================================================== */
static void g_wb_same_reg(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);

    switch ((unsigned)((r >> 16) % 3u)) {
    case 0: /* rd == rs1 on a post-increment load: dst0 and dst1 are both a3 */
        IDU_IDXUPD_SAME(TH_LDIA_B, 3, 1, p);
        break;
    case 1: /* the same on a pre-increment load */
        IDU_IDXUPD_SAME(TH_LDIB_B, 3, 31, p);
        break;
    default: /* an LSD pair whose two destinations are the same register:
              * inst[11:7] == inst[24:20] == a0 */
        {
            register u64 d_ __asm__("a0");
            register u64 p_ __asm__("a3") = p;
            __asm__ volatile (".word %[w_]"
                : "=r"(d_)
                : [w_]"n"(TH_IDX(TH_LDD_B, IDU_RD, IDU_BASE, IDU_RD, 0)),
                  "r"(p_) : "memory");
            rand_sink += d_;
        }
        break;
    }
}

/* ==================================================================== *
 * Group 37 (sparse): a source that is neither tracked nor forwarded
 *   DIS_INT_SRC0_RDY and its two siblings (aq_idu_id_dp.v:737-797) are
 *   wbt_vld || fwd_vld || !src_vld. The combination wbt_vld == 0,
 *   fwd_vld == 0, src_vld == 1 -- a source that is genuinely not ready, being
 *   dispatched anyway -- only happens under a RAW except: the producer is ALU
 *   or BJU typed, so no stall is raised, but its result has not reached a
 *   forward bus yet either. Long tight ALU chains are the way to sit in that
 *   state for many cycles in a row.
 * ==================================================================== */
static void g_late_forward(u64 r)
{
    u64 a = IDU_POOL(r >> 5);
    u64 d;

    if ((r >> 16) & 1u) {
        __asm__ volatile ("add a0, %1, %1\n\t"
                          "add a1, a0, %1\n\t"
                          "add a2, a1, a0\n\t"
                          "add a3, a2, a1\n\t"
                          "add a4, a3, a2\n\t"
                          "add a5, a4, a3\n\t"
                          "add %0, a5, a4"
                          : "=r"(d) : "r"(a)
                          : "a0", "a1", "a2", "a3", "a4", "a5");
    } else {
        /* the same chain with a taken branch in it, so that the producers are
         * BJU-typed as well as ALU-typed */
        __asm__ volatile ("add a0, %1, %1\n\t"
                          "jal a1, 1f\n"
                          "1:\n\t"
                          "add a2, a1, a0\n\t"
                          "add %0, a2, a1"
                          : "=r"(d) : "r"(a)
                          : "a0", "a1", "a2", "memory");
    }
    rand_sink += d;
}

/* ==================================================================== *
 * Group 38 (sparse): FP dependencies always take the full stall
 *   dp_wb_dst0_type (aq_idu_id_dp.v:563-580) is masked by
 *   dp_wb_inst_type_mask, which is 0 for anything dispatched to EU_FP or
 *   EU_VEC. So an FP destination is typed WB_INT_TYPE_OTHER (3'b000), which
 *   matches neither the ALU/BJU except arms nor the LSU/MULT ones -- every FP
 *   producer/consumer pair takes the unconditional RAW stall, and every FP WAW
 *   pair takes the unconditional WAW stall.
 * ==================================================================== */
static void g_fp_dep_stall(u64 r)
{
    u64 a = IDU_FPOOL(r >> 5);
    u64 b = IDU_FPOOL(r >> 7);
    u64 o;

    switch ((unsigned)((r >> 16) % 3u)) {
    case 0: /* RAW: fadd -> fmul on the same FP register, back to back */
        __asm__ volatile ("fmv.d.x fa1, %1\n\t"
                          "fmv.d.x fa2, %2\n\t"
                          "fadd.d  fa0, fa1, fa2\n\t"
                          "fmul.d  fa3, fa0, fa2\n\t"
                          "fmv.x.d %0, fa3"
                          : "=r"(o) : "r"(a), "r"(b)
                          : "fa0", "fa1", "fa2", "fa3");
        break;
    case 1: /* WAW: two long-latency producers on one FP register */
        __asm__ volatile ("fmv.d.x fa1, %1\n\t"
                          "fmv.d.x fa2, %2\n\t"
                          "fdiv.d  fa0, fa1, fa2\n\t"
                          "fdiv.d  fa0, fa2, fa1\n\t"
                          "fsqrt.d fa0, fa1\n\t"
                          "fmv.x.d %0, fa0"
                          : "=r"(o) : "r"(a), "r"(b)
                          : "fa0", "fa1", "fa2");
        break;
    default: /* an FP producer feeding an INTEGER consumer, i.e. the type mask
              * on one side of the pair only */
        __asm__ volatile ("fmv.d.x  fa1, %1\n\t"
                          "fadd.d   fa0, fa1, fa1\n\t"
                          "fcvt.l.d a0, fa0\n\t"
                          "add      %0, a0, a0"
                          : "=r"(o) : "r"(a) : "a0", "fa0", "fa1");
        break;
    }
    rand_sink += o;
}

/* ==================================================================== *
 * Group 39 (sparse): exception priority
 *   aq_idu_id_dp.v:537-546. DIS_INT_EXPT_ACC and DIS_INT_EXPT_PAGE are passed
 *   through unqualified, but DIS_INT_EXPT_ILLE is gated on neither of them
 *   being set -- i.e. acc_error > page_fault > illegal.
 *
 * The access-fault leg uses rand_run_at(RAND_SO_BASE + n): sysmap region 1 is
 * strong-order, and aq_mmu_utlb.v:788-790 denies execute there with no M-mode
 * escape, so every fetch in that window is an instruction access fault. The
 * error slave also returns zeros with rresp=OKAY, so the same excursion is
 * simultaneously an access fault and (if the fault were suppressed) an illegal
 * encoding -- which is exactly the priority question.
 *
 * The page-fault bin is NOT covered here: it needs satp in Sv39 with an
 * identity-mapped kernel, which is the MMU case's business. Keeping satp Bare
 * is what stops any group in this file from losing access to its own code.
 * ==================================================================== */
static void g_expt_priority(u64 r)
{
    switch ((unsigned)((r >> 16) % 3u)) {
    case 0: /* acc_error, and acc_error over illegal */
        rand_run_at(RAND_SO_BASE + 16u * ((r >> 20) & 0x3Fu));
        break;
    case 1: /* illegal alone, from a word that has no arm anywhere */
        IDU_WORD(INSN_RESERVED);
        break;
    default: /* fetch from the error slave: a legal fetch that returns zeros,
              * which decode as an all-zero (illegal) instruction with no
              * access fault -- the "illegal only" side of the priority */
        rand_run_at(RAND_ERR_BASE + 16u * ((r >> 20) & 0x3Fu));
        break;
    }
}

/* ==================================================================== *
 * Group 40 (sparse): the exception EU override
 *   aq_idu_id_ctrl.v:573-582. Any instruction with dp_ctrl_dis_inst_expt_vld
 *   (or dp_ctrl_dis_inst_cancel) has its EU select replaced wholesale by
 *   EU_CP0, whatever the decoder said -- so a faulting FP instruction, a
 *   faulting load and a faulting branch all have to arrive at CP0 instead of at
 *   their own unit.
 *
 * The cancel term is driven from ifu_idu_id_halt_info[TDT_HINFO_CANCEL], i.e.
 * from a debug trigger match, and needs rtu_yy_xx_dbgon. That is JTAG-only and
 * is NOT covered here; tests/cases/debug/ is the case with a JTAG driver.
 * ==================================================================== */
static void g_expt_override_cp0(u64 r)
{
    u64 keep;

    switch ((unsigned)((r >> 16) % 4u)) {
    case 0: /* an illegal instruction the decoder would have sent to EU_FALU */
        IDU_WORD(0x06000053u);
        break;
    case 1: /* one it would have sent to EU_LSU */
        IDU_WORD(0x00007003u);
        break;
    case 2: /* one it would have sent to EU_ALU: an FP op with FS off */
        keep = CSR_R(CSR_MSTATUS);
        CSR_C(CSR_MSTATUS, MSTATUS_FS);
        __asm__ volatile ("fadd.d fa0, fa0, fa0" ::: "memory");
        CSR_W(CSR_MSTATUS, keep);
        break;
    default: /* one it would have sent to EU_BJU: a th.* op with the T-Head
              * decode disabled, so that the whole opcode is illegal */
        keep = CSR_R(CSR_MXSTATUS);
        CSR_C(CSR_MXSTATUS, MXSTATUS_THEADISAEE);
        IDU_WORD(TH_SYNC);
        CSR_W(CSR_MXSTATUS, keep);
        break;
    }
}

/* ==================================================================== *
 * Group 41 (sparse): the EX1 full and stall terms
 *   ctrl_ex1_eu_full is six terms, one per unit (aq_idu_id_ctrl.v:669-676);
 *   ctrl_ex1_issue_stall is iu_idu_mult_issue_stall || cp0_idu_issue_stall
 *   (:678-682); ctrl_ex1_internal_stall is iu_idu_bju_global_full ||
 *   lsu_idu_global_full (:683-687). Each needs its own unit saturated on its
 *   own, so the group picks one unit per visit and hits it with eight
 *   back-to-back operations rather than mixing them.
 * ==================================================================== */
static void g_ex1_eu_full(u64 r)
{
    u64 a = IDU_POOL(r >> 5) | 1UL;
    u64 b = IDU_FPOOL(r >> 7);

    switch ((unsigned)((r >> 16) % 5u)) {
    case 0: /* div: iu_idu_div_full */
        __asm__ volatile ("div a0, %0, %0\n\t" "div a1, %0, %0\n\t"
                          "div a2, %0, %0\n\t" "div a3, %0, %0\n\t"
                          "div a4, %0, %0\n\t" "div a5, %0, %0\n\t"
                          "div a6, %0, %0\n\t" "div a7, %0, %0"
                          :: "r"(a)
                          : "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7");
        break;
    case 1: /* mult: iu_idu_mult_full and iu_idu_mult_issue_stall.
             *   iu_idu_mult_full = mul_ex2_inst_vld && !mul_ex2_itering
             *                      && mul_ex3_wb_vld
             *                      && !rtu_iu_mul_wb_grant_for_full
             *                                            (aq_iu_mul.v:598)
             * and rtu_iu_mul_wb_grant_for_full is exactly !rbus_div_wb_vld
             * (aq_rtu_rbus.v:471), so the only way to raise it is a DIVIDE
             * writing back in the same cycle that one multiply sits in EX3
             * wanting the port and another sits in EX2 without iterating. A
             * burst of multiplies on its own reaches iu_idu_mult_issue_stall
             * and never mult_full -- measured, the port stayed at zero toggles.
             * Three things have to line up:
             *   - !mul_ex2_itering. mul_ex1_iter_start is
             *     inst64 && !inst64_nosplit, and nosplit is "both operands fit
             *     in 32 bits" (aq_iu_mul.v:395-398), so the burst has to use
             *     SMALL operands -- a `mul` of two full-width pool values
             *     splits, iterates, and can never satisfy the term.
             *   - a long divide, so that its writeback is still to come while
             *     the burst is in steady-state issue: full-width dividend over
             *     a tiny divisor.
             *   - the burst still running on that exact cycle, hence the loop
             *     rather than a twelve-instruction straight line, plus a
             *     seed-driven phase offset so successive visits sample
             *     different alignments.
             * HONEST STATUS: this reaches iu_idu_mult_issue_stall, both the
             * splitting and the non-splitting multiply paths, and the only
             * divide/multiply overlap in the test -- but iu_idu_mult_full still
             * measures zero toggles, at every phase and iteration count tried.
             * coremark does not toggle it either (doc/results/
             * idu_toggle_coremark_ref.report), so it is a cycle-exact corner
             * rather than something this arm is getting wrong. Left documented
             * rather than claimed. */
        {
            unsigned k;
            unsigned ph = (unsigned)((r >> 44) & 0x1Fu);
            u64 s = 1UL + ((r >> 50) & 0xFFFFUL);   /* fits in 32 bits */

            __asm__ volatile ("div a0, %0, %1"
                              :: "r"(0x7FFFFFFFFFFFFFFFUL), "r"(3UL) : "a0");
            for (k = 0; k < ph; k++)
                __asm__ volatile ("nop");
            for (k = 0; k < 8u; k++)
                __asm__ volatile ("mul a1, %0, %0\n\t" "mul a2, %0, %0\n\t"
                                  "mul a3, %0, %0\n\t" "mul a4, %0, %0\n\t"
                                  "mul a5, %0, %0\n\t" "mul a6, %0, %0\n\t"
                                  "mul a7, %0, %0\n\t" "mul a1, %0, %0"
                                  :: "r"(s)
                                  : "a1", "a2", "a3", "a4", "a5", "a6", "a7");
            __asm__ volatile ("mulh a1, %0, %0\n\t" "mulh a2, %0, %0"
                              :: "r"(a) : "a1", "a2");
        }
        break;
    case 2: /* lsu: lsu_idu_full and lsu_idu_global_full */
        idu_fill_lsu(16);
        break;
    case 3: /* fp: vidu_idu_fp_full */
        __asm__ volatile ("fmv.d.x fa1, %0\n\t"
                          "fdiv.d fa0, fa1, fa1\n\t" "fdiv.d fa2, fa1, fa1\n\t"
                          "fdiv.d fa3, fa1, fa1\n\t" "fdiv.d fa4, fa1, fa1\n\t"
                          "fdiv.d fa5, fa1, fa1\n\t" "fdiv.d fa6, fa1, fa1\n\t"
                          "fdiv.d fa7, fa1, fa1\n\t" "fsqrt.d fa0, fa1"
                          :: "r"(b)
                          : "fa0", "fa1", "fa2", "fa3", "fa4", "fa5",
                            "fa6", "fa7");
        break;
    default: /* bju: iu_idu_bju_full and iu_idu_bju_global_full. All taken, all
              * to the next instruction, so there is no control-flow risk. */
        __asm__ volatile ("beq %0, %0, 1f\n1:\t" "beq %0, %0, 2f\n2:\t"
                          "beq %0, %0, 3f\n3:\t" "beq %0, %0, 4f\n4:\t"
                          "beq %0, %0, 5f\n5:\t" "beq %0, %0, 6f\n6:\t"
                          "beq %0, %0, 7f\n7:\t" "beq %0, %0, 8f\n8:"
                          :: "r"(a) : "memory");
        break;
    }
}

/* ==================================================================== *
 * Group 42 (sparse): the EX1 pipe select, crossed
 *   aq_idu_id_ctrl.v:627-662. Two details:
 *
 *   - idu_iu_ex1_bju_sel is qualified by rtu_idu_commit while
 *     idu_iu_ex1_bju_br_sel is qualified by rtu_idu_commit_for_bju
 *     (:628-630). Two distinct commit signals for the same instruction, so a
 *     branch sitting at EX1 across a commit boundary sees them disagree.
 *   - the FP-load selects are cross-gated: idu_lsu_ex1_sel needs
 *     !vidu_idu_fp_full and idu_vidu_ex1_fp_sel needs !lsu_idu_full
 *     (:634-640), because an `fld` occupies both queues. So filling the LSU
 *     queue and then issuing an `fld` blocks the FP select, and vice versa.
 * ==================================================================== */
static void g_pipe_sel_cross(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);
    u64 b = IDU_FPOOL(r >> 7);

    switch ((unsigned)((r >> 16) % 3u)) {
    case 0: /* LSU queue full, then an FP load */
        idu_fill_lsu(12);
        __asm__ volatile ("fld fa0, 0(%0)\n\t"
                          "fld fa1, 8(%0)"
                          :: "r"(p) : "fa0", "fa1", "memory");
        break;
    case 1: /* FP queue busy, then an integer load and an FP store */
        __asm__ volatile ("fmv.d.x fa1, %1\n\t"
                          "fdiv.d fa0, fa1, fa1\n\t"
                          "fdiv.d fa2, fa1, fa1\n\t"
                          "fdiv.d fa3, fa1, fa1\n\t"
                          "ld  a0, 0(%0)\n\t"
                          "fsd fa0, 16(%0)"
                          :: "r"(p), "r"(b)
                          : "a0", "fa0", "fa1", "fa2", "fa3", "memory");
        break;
    default: /* branches interleaved with missing loads, so that a branch is at
              * EX1 while lsu_idu_global_full holds the stage */
        idu_fill_lsu(4);
        __asm__ volatile ("ld  a0, 0(%0)\n\t"
                          "beq a0, a0, 1f\n"
                          "1:\t"
                          "ld  a1, 64(%0)\n\t"
                          "bne a1, a0, 2f\n\t"
                          "nop\n"
                          "2:"
                          :: "r"((u64)(unsigned long)&idu_miss_arena[192])
                           : "a0", "a1", "memory");
        break;
    }
}

/* ==================================================================== *
 * Group 43 (sparse): the dispatch-stall composition
 *   ctrl_dis_stall is five terms OR-ed together (aq_idu_id_ctrl.v:390-394):
 *   rtu_idu_flush_stall, ctrl_ex1_stall, ctrl_dis_dep_stall,
 *   ctrl_dis_cp0_stall and ctrl_dis_vec_stall. The last is dead
 *   (cp0_idu_vsetvl_dis_stall can never assert with the vector unit removed).
 *
 *   ctrl_dis_cp0_stall (:381-384) is the interesting one: a fence-class CP0
 *   operation waits for rtu_idu_pipeline_empty, so putting one immediately
 *   after a long divide makes it stall for the whole divide, and putting one
 *   after a barrier makes it not stall at all. Both are issued.
 *
 * This group also owns cp0_idu_icg_en, the IDU's module clock-gate enable. It
 * is MHINT2[22:14] = module_icg_en[8:0] (rand_csrs.h MHINT2_ICG_EN), nothing
 * else in the test writes mhint2, and rand_restore_sane_state() holds it at 0 --
 * so without this the port never toggles at all. It is safe to drive from
 * software here because gen_rtl/clk/rtl/gated_clk_cell.v is
 * `assign clk_out = clk_in` in behavioral sim: the enable reaches the IDU and
 * toggles the port, but no clock is actually gated. Restored on the way out,
 * and rand_restore_sane_state() would clear it anyway.
 * ==================================================================== */
static void g_dis_stall_compose(u64 r)
{
    u64 a = IDU_POOL(r >> 5) | 1UL;
    u64 p = IDU_PTR_LINE(r >> 7);
    u64 keep2 = CSR_R(CSR_MHINT2);

    if ((r >> 20) & 1u) CSR_S(CSR_MHINT2, MHINT2_ICG_EN);
    else                CSR_C(CSR_MHINT2, MHINT2_ICG_EN);

    if ((r >> 24) & 1u) {
        /* pipeline already empty: the same CP0 op must NOT stall */
        __asm__ volatile ("fence iorw, iorw" ::: "memory");
    } else {
        /* a long divide immediately before, so the pipeline is not empty */
        __asm__ volatile ("div a0, %0, %0" :: "r"(a) : "a0");
    }

    switch ((unsigned)((r >> 16) % 5u)) {
    case 0: __asm__ volatile ("fence iorw, iorw" ::: "memory"); break;
    case 1: __asm__ volatile ("fence.i" ::: "memory"); break;
    case 2: __asm__ volatile ("sfence.vma" ::: "memory"); break;
    case 3: DCACHE_SAFE_POINT(); break;
    default:TH_OP_RS1(TH_DCACHE_CVA, p); break;
    }

    /* and the dependency-stall term, which is the other software-visible one */
    __asm__ volatile ("div a0, %0, %0\n\t"
                      "add a1, a0, %0"
                      :: "r"(a) : "a0", "a1");

    CSR_W(CSR_MHINT2, keep2);
}

/* ==================================================================== *
 * Group 44 (sparse): the HPCP instruction classification
 *   aq_idu_id_ctrl.v:699-707 fans the EX1 selects out into seven categories:
 *     [0] ALU / MULT / DIV      [1] LSU            [2] VEC  -- dead
 *     [3] CP0 with dp_ctrl_inst_csr                [4] sync, or an LSU AMO
 *     [5] ecall                 [6] FP
 *   Category [2] is idu_vidu_ex1_vec_sel && !EU_LSU, and idu_vidu_ex1_vec_sel
 *   can never assert here (ex1_eu_sel[EU_VEC_SEL] comes from decd_sel[5]).
 *
 * The counters have to be running or the classification is never sampled
 * (the flop is gated on hpcp_idu_cnt_en, :735-741), so mcountinhibit is cleared
 * and mhpmevent3..6 pointed at something. mcntinten stays 0 so an overflow
 * cannot raise MOIP; rand_restore_sane_state puts the counter policy back.
 * ==================================================================== */
static void g_hpcp_class(u64 r)
{
    u64 p = IDU_PTR_LINE(r >> 5);
    u64 a = IDU_POOL(r >> 7) | 1UL;

    CSR_W(CSR_MCNTIHBT, 0);
    CSR_W(CSR_MHPMEVT3, 1UL + ((r >> 20) & 0x1FUL));
    CSR_W(CSR_MHPMEVT4, 1UL + ((r >> 26) & 0x1FUL));
    CSR_W(CSR_MHPMEVT5, 1UL + ((r >> 32) & 0x1FUL));
    CSR_W(CSR_MHPMEVT6, 1UL + ((r >> 38) & 0x1FUL));
    CSR_W(CSR_MCNTINTEN, 0);
    CSR_W(CSR_MCNTOF, 0);

    /* one instruction from each live category, in one burst */
    __asm__ volatile ("add a0, %0, %0\n\t"      /* [0] ALU  */
                      "mul a1, %0, %0\n\t"      /* [0] MULT */
                      "div a2, %0, %0\n\t"      /* [0] DIV  */
                      "ld  a3, 0(%1)\n\t"       /* [1] LSU  */
                      "fmv.d.x fa0, %0\n\t"     /* [6] FP   */
                      "fadd.d fa1, fa0, fa0"
                      :: "r"(a), "r"(p)
                      : "a0", "a1", "a2", "a3", "fa0", "fa1", "memory");
    rand_sink += CSR_R(CSR_MHPMCNT3);           /* [3] CSR   */
    TH_OP(TH_SYNC);                             /* [4] sync  */
    IDU_M_AMO("amoadd.d", p, a);                /* [4] AMO   */
    __asm__ volatile ("ecall" ::: "memory");    /* [5] ecall */

    rand_sink += CSR_R(CSR_MHPMCNT4) + CSR_R(CSR_MHPMCNT5)
               + CSR_R(CSR_MHPMCNT6) + CSR_R(CSR_MINSTRET);
}

/* ==================================================================== *
 * Group 45 (sparse): zvamo
 *   aq_idu_id_split.v:355: zvamo_inst = inst[14:13] == 2'b11, so an AMO opcode
 *   with funct3 110 or 111 sets zvamo_inst in the AMO cracking FSM, whose
 *   ordering terms are then suppressed (amo_aq_inst = inst[26] && !zvamo_inst,
 *   :335-336) and whose uop would be dispatched with EU_VEC -- a unit that does
 *   not exist in this configuration.
 *
 * The fear was that the instruction never issues and the pipeline deadlocks
 * until the testbench's 50,000-cycle no-retire watchdog fires. It does not, and
 * the reason is upstream of the splitter: the 32-bit table's AMO arms are
 * 15'b?????_??_01001011 and 15'b?????_??_01101011 (aq_idu_id_decd.v:2017-2094),
 * i.e. funct3 010 and 011 only. funct3 110/111 matches no arm, decd_fp_sel is
 * 0 for opcode 0101111 so decd_sel[0] is 1, and decd_32_illegal fires -- the
 * encoding is a plain illegal instruction and the EU select is overridden to
 * EU_CP0 before the vector dispatch can happen.
 *
 * Measured, not assumed: 400/400 iterations of this group took an
 * illegal-instruction trap (mcause 2) and the run finished normally, both alone
 * and interleaved with group 20's real AMO matrix. So it is on by default;
 * -DIDU_NO_ZVAMO takes it back out if a future configuration changes that.
 * ==================================================================== */
static void g_zvamo_negative(u64 r)
{
    idu_zvamo_tries++;
#ifndef IDU_NO_ZVAMO
    {
        u64 p = IDU_PTR_LINE(r >> 5);
        register u64 pp_ __asm__("a3") = p;

        if ((r >> 16) & 1u)
            __asm__ volatile (".word %[w_]"
                :: [w_]"n"(IDU_ZVAMO_ADD_W | (IDU_BASE << 15)), "r"(pp_)
                 : "memory");
        else
            __asm__ volatile (".word %[w_]"
                :: [w_]"n"(IDU_ZVAMO_ADD_D | (IDU_BASE << 15)), "r"(pp_)
                 : "memory");
    }
#else
    (void)r;
#endif
}

/* ==================================================================== *
 * Dispatch
 * ==================================================================== */
static void dispatch(u64 r)
{
#ifdef IDU_ONLY_GROUP
    /* Debug aid: build with -DIDU_ONLY_GROUP=n to run just one group, which is
     * how a group that hangs or misbehaves gets isolated. Groups 0..31 are the
     * main rotation; 32..45 are the sparse second selector. */
    unsigned g = (IDU_ONLY_GROUP);
#else
    unsigned g = (unsigned)(r % IDU_NGROUPS);
#endif

    if (g < IDU_NGROUPS_TOTAL) group_hits[g]++;

    switch (g) {
    case 0:  g_rvc_table(r);         break;
    case 1:  g_base32_alu(r);        break;
    case 2:  g_base32_ls_sys(r);     break;
    case 3:  g_fp_table_sd(r);       break;
    case 4:  g_fp_table_h(r);        break;
    case 5:  g_fma_table(r);         break;
    case 6:  g_fp_rm(r);             break;
    case 7:  g_fs_zero(r);           break;
    case 8:  g_cache_sync_table(r);  break;
    case 9:  g_theadisaee_off(r);    break;
    case 10: g_xtheadc_alu(r);       break;
    case 11: g_xtheadc_bits(r);      break;
    case 12: g_xtheadc_mac(r);       break;
    case 13: g_xtheadc_lr(r);        break;
    case 14: g_xtheadc_idxupd(r);    break;
    case 15: g_xtheadc_stores(r);    break;
    case 16: g_xtheadc_fp(r);        break;
    case 17: g_rvv_illegal(r);       break;
    case 18: g_lsd_split(r);         break;
    case 19: g_lsd_interrupted(r);   break;
    case 20: g_amo_matrix(r);        break;
    case 21: g_che_split(r);         break;
    case 22: g_fnc_split(r);         break;
    case 23: g_imm_src1_sweep(r);    break;
    case 24: g_imm_src2_sweep(r);    break;
    case 25: g_regidx_sweep(r);      break;
    case 26: g_illegal_reserved(r);  break;
    case 27: g_illegal_xtheadc(r);   break;
    case 28: g_c_illegal(r);         break;
    case 29: g_priv_cacheops(r);     break;
    case 30: g_raw_alu_bju(r);       break;
    case 31: g_raw_load_condbr(r);   break;
    /* 32..45 are only reachable through -DIDU_ONLY_GROUP; in a normal run they
     * come from the sparse selector below. */
    case 32: g_raw_fwd_bus(r);       break;
    case 33: g_raw_src2_store(r);    break;
    case 34: g_waw_cnt2(r);          break;
    case 35: g_waw_dst1(r);          break;
    case 36: g_wb_same_reg(r);       break;
    case 37: g_late_forward(r);      break;
    case 38: g_fp_dep_stall(r);      break;
    case 39: g_expt_priority(r);     break;
    case 40: g_expt_override_cp0(r); break;
    case 41: g_ex1_eu_full(r);       break;
    case 42: g_pipe_sel_cross(r);    break;
    case 43: g_dis_stall_compose(r); break;
    case 44: g_hpcp_class(r);        break;
    case 45: g_zvamo_negative(r);    break;
    default: break;
    }

#ifndef IDU_ONLY_GROUP
    /* The remaining groups are rarer, more expensive or more fragile, so they
     * ride along on a second, sparser selector rather than diluting the main
     * rotation. Group 45 is last on purpose: it is the one whose encoding is
     * furthest outside anything the RTL was built for. */
    switch ((unsigned)((r >> 32) % 64u)) {
    case 0:  g_raw_fwd_bus(r);       group_hits[32]++; break;
    case 1:  g_raw_src2_store(r);    group_hits[33]++; break;
    case 2:  g_waw_cnt2(r);          group_hits[34]++; break;
    case 3:  g_waw_dst1(r);          group_hits[35]++; break;
    case 4:  g_wb_same_reg(r);       group_hits[36]++; break;
    case 5:  g_late_forward(r);      group_hits[37]++; break;
    case 6:  g_fp_dep_stall(r);      group_hits[38]++; break;
    case 7:  g_expt_priority(r);     group_hits[39]++; break;
    case 8:  g_expt_override_cp0(r); group_hits[40]++; break;
    case 9:  g_ex1_eu_full(r);       group_hits[41]++; break;
    case 10: g_pipe_sel_cross(r);    group_hits[42]++; break;
    case 11: g_dis_stall_compose(r); group_hits[43]++; break;
    case 12: g_hpcp_class(r);        group_hits[44]++; break;
    case 13: g_zvamo_negative(r);    group_hits[45]++; break;
    default: break;
    }
#endif
}

/* ==================================================================== *
 * End-of-run summary over the UART.
 *
 * Diagnostics only: PASS/FAIL is the GPR magic value crt0.s writes, and the
 * real evidence of IDU stimulus is work/idu_toggle.report. The trap-cause
 * histogram is the one thing here that can catch a group not doing what its
 * comment says: with no golden model, an unexpected cause distribution is the
 * signal.
 * ==================================================================== */
static void report(void)
{
    unsigned i;

    rand_restore_sane_state();
    rand_report_begin();

    rand_puts("\n[idu_random] iters=");
    rand_putu(rand_iter);
    rand_puts(" sweeps=");
    rand_putu(idu_sweep_calls);
    rand_puts(" privtrips=");
    rand_putu(idu_priv_trips);
    rand_puts(" zvamo=");
    rand_putu(idu_zvamo_tries);

    rand_puts("\n[idu_random] groups:");
    for (i = 0; i < IDU_NGROUPS_TOTAL; i++) {
        if (!group_hits[i])
            continue;
        rand_putc(' ');
        rand_puts(idu_group_names[i]);
        rand_putc('=');
        rand_putu(group_hits[i]);
    }
    rand_putc('\n');

    rand_hist_dump("idu_random");

    /* Informational fingerprint. NOT compared against anything: it exists so
     * that the results of the instructions under test cannot be dead code, and
     * so that two runs of the same seed can be eyeballed for equality. */
    rand_puts("[idu_random] sink=");
    rand_putx(rand_sink);
    rand_putc('\n');

    rand_report_end();
}

/* ==================================================================== *
 * main
 * ==================================================================== */
int main(void)
{
    unsigned i;

    rand_srand((u64)IDU_SEED);
    rand_trap_init();              /* FIRST: clears MIE, installs mtvec */
    rand_pmp_open_everything();
    rand_restore_sane_state();

    /* Give every FP register a defined value before anything can read one back.
     * crt0.s does this too, but a group that runs with FS == 0 and then
     * restores it should not be the first thing to find out. */
    for (i = 0; i < 8u; i++)
        __asm__ volatile ("fmv.d.x fa0, %0" :: "r"((u64)i) : "fa0");

    /* Touch the miss arena once so that its lines exist in the SRAM image the
     * testbench loaded, rather than being first written from a cache eviction
     * halfway through a group that is measuring queue occupancy. */
    for (i = 0; i < 512u; i += 8u)
        idu_miss_arena[i] = (u64)i;

    for (rand_iter = 0; rand_iter < (u64)IDU_ITERS; rand_iter++) {
        if (rand_setjmp() != 0) {          /* trap-handler bail-out landing pad */
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
