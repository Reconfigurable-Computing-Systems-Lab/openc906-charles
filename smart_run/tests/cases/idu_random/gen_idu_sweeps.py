#!/usr/bin/env python3
"""Generate the mechanically-enumerable half of idu_random's stimulus.

Four leaves of the IDU are small, finite and completely enumerable, and
sampling them from a randomised dispatch loop would be a waste of iterations:

  * ``decd_src1_imm_sel``  -- a 14-arm one-hot case
                              (aq_idu_id_decd.v:543-561), 13 arms reachable
  * ``decd_src2_imm_sel``  -- a 7-arm one-hot case  (:618-628)
  * the shadow-GPR read ports -- 3 ports x a 32-arm register mux each = 96 bins
                              (aq_idu_id_gpr.v:632-676 and the two ports after)
  * the forwarding-bus comparators -- 3 ports x 3 forward sources = 9 bins
                              (aq_idu_id_dp.v:639-727)

So they are emitted here as straight-line ``.word`` / ``.2byte`` blocks wrapped
in callable functions, and the C side calls each one whenever its group comes
up. That makes those bins deterministic (they are hit on the first visit, not
after N thousand iterations) and leaves the random dispatch loop to do what it
is actually good at: interleaving them with everything else.

Emission rules, all of them safety rules rather than style:

  1. No destination is ever x0-used-as-a-producer, x1 (ra), x2 (sp), x3 (gp),
     x4 (tp -- holds &rand_ctx) or x8 (s0). The two deliberate exceptions are
     ``c.addi16sp`` (writes sp, immediately undone) and ``c.jalr`` (writes ra,
     which the function has already spilled to its own frame); both exist
     because they are the ONLY encodings that reach their decode arm.
  2. No callee-saved register is written at all -- not x9 or x18..x27 either.
     These are leaf functions called from C, so the caller's values in them
     have to survive. Workers are t0-t2, a1-a7, t3-t5.
  3. Every store goes to ``0..248(a0)``, i.e. inside the scratch block the
     caller passes in, or to this function's own 128-byte frame.
  4. Every result is folded into t5, which is returned in a0, so that nothing
     is dead and nothing needs a volatile.
  5. Sequences whose decode arm depends on the instruction *width* are wrapped
     in ``.option norvc`` / ``.option rvc``. Without that, GAS happily
     compresses ``add t4, x0, x9`` into ``c.mv``, which moves the register
     index from src1 = inst[24:20] to src0 = inst[6:2] and silently guts the
     sweep.

Known-unreachable, deliberately not emitted:

  * ``decd_src1_imm_sel[13]`` (14'h2000, ``{59'b0, inst[19:15]}``) is
    ``decd_inst_vec && decd_vec_opivi``, and ``decd_vec_inst = 1'b0``
    (aq_idu_id_decd.v:3740). The vector decoder is tied off in this
    configuration, so 13 of the 14 immediate arms are reachable and the
    fourteenth is dead logic.

Stdlib only, in the style of smart_run/cli_tools/.
"""

import argparse
import sys

# --------------------------------------------------------------------------
# Register numbers, by name, so an encoding and its operand cannot drift apart.
# --------------------------------------------------------------------------
X = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7, "s0": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14, "a5": 15,
    "a6": 16, "a7": 17,
    "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}

FRAME = 128          # bytes of own stack frame
RA_SLOT = 120        # where ra is spilled
SCRATCH_MAX = 248    # highest byte offset the caller guarantees is writable


class Emitter(object):
    """Accumulates assembly lines and tracks the current RVC mode.

    The mode tracking exists purely so that `.option` directives are emitted
    only when the mode actually changes -- a wall of redundant push/pop makes
    the generated file unreadable when something needs debugging.
    """

    def __init__(self):
        self.lines = []
        self.rvc = True          # GAS default for a -march with `c`

    def raw(self, text):
        self.lines.append(text)

    def cmt(self, text):
        self.lines.append("\t/* %s */" % text)

    def hdr(self, text):
        self.lines.append("")
        self.lines.append("\t/* ---- %s ---- */" % text)

    def insn(self, text, comment=None):
        if comment:
            self.lines.append("\t%-34s /* %s */" % (text, comment))
        else:
            self.lines.append("\t%s" % text)

    def label(self, name):
        self.lines.append("%s:" % name)

    def norvc(self, force=False):
        """`force` emits the directive even when the tracker already believes
        RVC is off. Every function prologue forces it: `.option` is global
        assembler state, not function-scoped, so without the force a function
        would silently inherit whichever mode the previous one happened to end
        in -- and reordering the generators would then let GAS compress
        `add t2, x0, xN` into `c.mv`, moving the register index from
        src1 = inst[24:20] to src0 = inst[6:2] and gutting the sweep."""
        if self.rvc or force:
            self.lines.append("\t.option norvc")
            self.rvc = False

    def rvc_on(self):
        if not self.rvc:
            self.lines.append("\t.option rvc")
            self.rvc = True

    def word(self, value, comment):
        """A raw 32-bit encoding. Only used where binutils will not emit the
        instruction for us -- i.e. the Xtheadc family."""
        self.insn(".word 0x%08x" % (value & 0xFFFFFFFF), comment)

    def half(self, value, comment):
        self.insn(".2byte 0x%04x" % (value & 0xFFFF), comment)

    def text(self):
        return "\n".join(self.lines) + "\n"


# --------------------------------------------------------------------------
# Xtheadc encoders. Mirrors of the TH_* builders in rand_th_insn.h; duplicated
# here because the generator cannot include a C header.
# --------------------------------------------------------------------------
def th_idx(base, rd, rs1, rs2, sh):
    return (base
            | ((sh & 3) << 25)
            | ((rs2 & 0x1F) << 20)
            | ((rs1 & 0x1F) << 15)
            | ((rd & 0x1F) << 7))


TH_LDIA_B = 0x7800400B      # th.ldia rd, (rs1), imm5, imm2  (post-increment)
TH_LWD_B = 0xE000400B       # th.lwd  rd, rd2, (rs1), imm2


# --------------------------------------------------------------------------
# Function prologue / epilogue.
#
# a0 arrives holding the scratch pointer and leaves holding the accumulator, so
# every one of these is `u64 f(volatile u64 *scratch)` on the C side.
# --------------------------------------------------------------------------
def prologue(e, name, what):
    e.raw("")
    e.raw("/* ==================================================================== *")
    for line in what:
        e.raw(" * " + line if line else " *")
    e.raw(" * ==================================================================== */")
    e.raw("\t.balign 4")
    e.raw("\t.globl %s" % name)
    e.raw("\t.type %s, @function" % name)
    e.label(name)
    e.norvc(force=True)
    e.insn("addi\tsp, sp, -%d" % FRAME)
    e.insn("sd\tra, %d(sp)" % RA_SLOT, "c.jalr and the trap path both need this")
    e.insn("mv\tt3, a0", "t3 = caller's scratch block")
    e.insn("li\tt5, 0", "t5 = accumulator, returned in a0")
    e.insn("sd\tt5, 0(sp)", "define the frame slots the sp-relative")
    e.insn("sd\tt5, 8(sp)", "  compressed forms below read back, so")
    e.insn("sd\tt5, 16(sp)", "  nothing ever loads an undefined word")
    e.insn("sd\tt5, 24(sp)")
    e.insn("sd\tt5, 32(sp)")
    e.insn("sd\tt5, 40(sp)")


def epilogue(e, name):
    e.norvc()
    e.raw("")
    e.insn("mv\ta0, t5")
    e.insn("ld\tra, %d(sp)" % RA_SLOT)
    e.insn("addi\tsp, sp, %d" % FRAME)
    e.insn("ret")
    e.raw("\t.size %s, .-%s" % (name, name))


# --------------------------------------------------------------------------
# idu_sweep_imm_src1 -- the 14-arm decd_src1_imm_sel case
# --------------------------------------------------------------------------
def gen_imm_src1(e):
    name = "idu_sweep_imm_src1"
    prologue(e, name, [
        "One instruction per arm of the 14-way decd_src1_imm_sel case",
        "(aq_idu_id_decd.v:543-561). The selector is a one-hot built from ten",
        "independent opcode compares (:468-519), so the only way to walk the",
        "case is one representative instruction per arm.",
        "",
        "Arm 14'h2000 is NOT emitted: its selector is",
        "decd_inst_vec && decd_vec_opivi and decd_vec_inst is tied to 1'b0",
        "(:3740). 13 of 14 arms are reachable in this configuration.",
    ])

    e.insn("addi\tt0, t3, 64", "t0 = a writable slot, not sp")

    e.hdr("14'h01: 32-bit imm20 -- lui and auipc")
    e.norvc()
    e.insn("lui\tt4, 0x12345", "opcode 0110111")
    e.insn("xor\tt5, t5, t4")
    e.insn("auipc\tt4, 1", "opcode 0010111")
    e.insn("xor\tt5, t5, t4")

    e.hdr("14'h02: 32-bit imm12 -- everything else with inst[1:0] == 11")
    e.insn("addi\tt4, t3, -1365")
    e.insn("xor\tt5, t5, t4")
    e.insn("andi\tt4, t3, 1023")
    e.insn("xor\tt5, t5, t4")

    e.hdr("14'h20: 32-bit store (decd_src1_imm_sel[5])")
    e.insn("sd\tt5, 8(t0)", "base is t0, not sp, or GAS emits c.sdsp")
    e.insn("sw\tt5, 16(t0)")
    e.insn("fsd\tfa0, 24(t0)", "the {inst[14],inst[6:0]} == 0_0100111 leg")

    e.hdr("14'h1000: Xtheadc lsi -- {{59{inst[24]}},inst[24:20]} << inst[26:25]")
    e.cmt("th.ldia a1, (a2), 1, 3  ->  a1 = mem[a2]; a2 += 1 << 3")
    e.insn("addi\ta2, t3, 128", "a2 must be a scratch pointer: it is updated")
    e.word(th_idx(TH_LDIA_B, X["a1"], X["a2"], 1, 3), "th.ldia a1,(a2),1,3")
    e.insn("xor\tt5, t5, a1")
    e.insn("xor\tt5, t5, a2", "fold the dst1 writeback too")

    e.hdr("14'h04: 16-bit imm6")
    e.rvc_on()
    e.insn("c.li\tt4, -5")
    e.norvc()
    e.insn("xor\tt5, t5, t4")

    e.hdr("14'h08: c.addi16sp -- the only encoding with rd == x2 and funct3 011")
    e.cmt("writes sp; undone on the next instruction, with nothing in between")
    e.rvc_on()
    e.insn("c.addi16sp\tsp, -16")
    e.insn("c.addi16sp\tsp, 16")

    e.hdr("14'h10: c.addi4spn")
    e.insn("c.addi4spn\ta1, sp, 8")
    e.norvc()
    e.insn("xor\tt5, t5, a1")

    e.hdr("14'h40 / h80 / h100: c.lwsp, c.lw/c.sw, c.swsp")
    e.insn("addi\ta2, t3, 32", "a2 = c-register scratch base for c.lw/c.sw")
    e.rvc_on()
    e.insn("c.lwsp\ta1, 8(sp)")
    e.insn("c.lw\ta1, 4(a2)")
    e.insn("c.sw\ta1, 8(a2)")
    e.insn("c.swsp\ta1, 24(sp)")
    e.norvc()
    e.insn("xor\tt5, t5, a1")

    e.hdr("14'h200 / h400 / h800: c.ld|c.sd|c.fld|c.fsd, c.ldsp|c.fldsp, "
          "c.sdsp|c.fsdsp")
    e.rvc_on()
    e.insn("c.ld\ta1, 8(a2)")
    e.insn("c.sd\ta1, 16(a2)")
    e.insn("c.fld\tfa0, 24(a2)")
    e.insn("c.fsd\tfa0, 32(a2)")
    e.insn("c.ldsp\ta1, 16(sp)")
    e.insn("c.fldsp\tfa0, 32(sp)")
    e.insn("c.sdsp\ta1, 40(sp)")
    e.insn("c.fsdsp\tfa0, 32(sp)")
    e.norvc()
    e.insn("xor\tt5, t5, a1")

    epilogue(e, name)


# --------------------------------------------------------------------------
# idu_sweep_imm_src2 -- the 7-arm decd_src2_imm_sel case
# --------------------------------------------------------------------------
def gen_imm_src2(e):
    name = "idu_sweep_imm_src2"
    prologue(e, name, [
        "One instruction per arm of the 7-way decd_src2_imm_sel case",
        "(aq_idu_id_decd.v:618-628). All seven arms are reachable.",
        "",
        "Note that arms 7'h20 and 7'h40 are selected on inst[15:14] == 2'b11",
        "and inst[15:13] == 3'b101 for ANY 16-bit opcode, so c.sw / c.swsp and",
        "c.fsd / c.fsdsp reach them as well as c.beqz and c.j -- the branch",
        "immediates below are simply the shortest way to say so.",
    ])

    e.norvc()
    e.hdr("7'h01: auipc")
    e.insn("auipc\tt4, 2")
    e.insn("xor\tt5, t5, t4")

    e.hdr("7'h02: any other 32-bit instruction")
    e.insn("addi\tt4, t3, 17")
    e.insn("xor\tt5, t5, t4")

    e.hdr("7'h08: 32-bit conditional branch")
    e.insn("beq\tt3, t3, 1f", "rs2 != x0 keeps GAS off c.beqz")
    e.insn("nop")
    e.label("1")

    e.hdr("7'h10: 32-bit jal -- rd is t4, NOT ra")
    e.insn("jal\tt4, 2f")
    e.label("2")
    e.insn("xor\tt5, t5, t4")

    e.hdr("7'h04: 16-bit imm6 (not c.branch, not c.j)")
    e.rvc_on()
    e.insn("c.li\tt4, 3")
    e.norvc()
    e.insn("xor\tt5, t5, t4")

    e.hdr("7'h20: c.beqz / c.bnez (inst[15:14] == 2'b11)")
    e.rvc_on()
    e.insn("c.beqz\ta1, 3f")
    e.label("3")
    e.insn("c.bnez\ta1, 4f")
    e.label("4")

    e.hdr("7'h40: c.j (inst[15:13] == 3'b101)")
    e.insn("c.j\t5f")
    e.label("5")
    e.norvc()

    epilogue(e, name)


# --------------------------------------------------------------------------
# idu_sweep_regidx -- the 96 shadow-GPR read-port mux bins
# --------------------------------------------------------------------------
def gen_regidx(e):
    name = "idu_sweep_regidx"
    prologue(e, name, [
        "All 96 shadow-GPR read-port mux bins: three read ports, each a",
        "32-arm case over the register index (aq_idu_id_gpr.v:632-676 for",
        "src0, and the two identical ports that follow it).",
        "",
        "The three ports are fed from different instruction fields, so each",
        "needs its own instruction shape:",
        "  src0 = inst[19:15] for a 32-bit op   ->  add t2, xN, t3",
        "  src1 = inst[24:20] for a 32-bit op   ->  add t2, t3, xN",
        "  src2 = inst[24:20] for a STORE only  ->  sd  xN, off(t0)",
        "src2 has no other producer in the 32-bit space: it is the store-data",
        "port (decd_inst_src2_reg_32bit_24_20, :698).",
        "",
        "Reading x1/x2/x3/x4/x8 is both safe and necessary -- the mux arm is",
        "the coverage point, and a read cannot corrupt anything. None of them",
        "is ever a destination here.",
        "",
        "Then the index-select terms that do not come from a plain 32-bit",
        "field: c.mv's src0 = inst[6:2], the fmv/fcvtfx src1 = inst[19:15]",
        "override (:678-687), the hardwired src0 = x2 forms, the 3-bit",
        "compressed destination arms, and c.jalr's hardwired dst0 = x1.",
    ])

    e.insn("addi\tt0, t3, 128", "t0 = store target, 8-byte aligned")
    e.insn("addi\ta2, t3, 32", "a2 = c-register base for the compressed forms")

    e.hdr("src0 mux, all 32 arms: src0 = inst[19:15]")
    e.norvc()
    for n in range(32):
        e.insn("add\tt2, x%d, t3" % n)
        e.insn("xor\tt5, t5, t2")

    e.hdr("src1 mux, all 32 arms: src1 = inst[24:20]")
    for n in range(32):
        e.insn("add\tt2, t3, x%d" % n)
        e.insn("xor\tt5, t5, t2")

    e.hdr("src2 mux, all 32 arms: store data = inst[24:20]")
    for n in range(32):
        e.insn("sd\tx%d, %d(t0)" % (n, 8 * (n % 8)))

    e.hdr("src1 override for fmv.*.x / fcvt.*.[wl]* -- src1 = inst[19:15]")
    e.cmt("decd_inst_fmv / decd_inst_fcvtfx, aq_idu_id_decd.v:681-684")
    for n in range(32):
        e.insn("fmv.d.x\tfa0, x%d" % n)
    e.insn("fmv.x.d\tt2, fa0")
    e.insn("xor\tt5, t5, t2")
    for n in range(0, 32, 8):
        e.insn("fcvt.d.l\tfa0, x%d" % n)
    e.insn("fmv.x.d\tt2, fa0")
    e.insn("xor\tt5, t5, t2")

    e.hdr("src0 via c.mv -- src0 = inst[6:2], which must be non-zero")
    e.cmt("decd_inst_src0_reg_cmv, aq_idu_id_decd.v:655")
    e.rvc_on()
    for n in range(1, 32):
        e.insn("c.mv\tt2, x%d" % n)
    e.norvc()
    e.insn("xor\tt5, t5, t2")

    e.hdr("src0 hardwired to x2 -- decd_inst_src0_reg_r2 (:660)")
    e.rvc_on()
    e.insn("c.addi4spn\ta1, sp, 16", "inst[14:13] == 2'b00, op == 00")
    e.insn("c.lwsp\ta1, 8(sp)")
    e.insn("c.ldsp\ta1, 16(sp)")
    e.insn("c.swsp\ta1, 24(sp)")
    e.insn("c.sdsp\ta1, 32(sp)")
    e.insn("c.fldsp\tfa0, 40(sp)")
    e.insn("c.fsdsp\tfa0, 40(sp)")
    e.cmt("c.addi16sp: src0 AND dst0 are x2; undone immediately")
    e.insn("c.addi16sp\tsp, -32")
    e.insn("c.addi16sp\tsp, 32")

    e.hdr("the 3-bit compressed source and destination arms")
    e.insn("c.srli\ta1, 1", "dst0 = {2'd1, inst[9:7]}")
    e.insn("c.srai\ta1, 1")
    e.insn("c.andi\ta1, 7")
    e.insn("c.and\ta1, a2")
    e.insn("c.or\ta1, a2")
    e.insn("c.xor\ta1, a2")
    e.insn("c.sub\ta1, a2")
    e.insn("c.addw\ta1, a2")
    e.insn("c.subw\ta1, a2")
    e.insn("c.lw\ta1, 4(a2)", "dst0 = {2'd1, inst[4:2]}")
    e.insn("c.ld\ta1, 8(a2)")
    e.norvc()
    e.insn("xor\tt5, t5, a1")

    e.hdr("dst0 hardwired to x1 -- decd_inst_dst0_reg_16bit_x1 (:735)")
    e.cmt("c.jalr is the ONLY encoding that reaches this arm. ra was spilled")
    e.cmt("to the frame in the prologue and is reloaded in the epilogue, so")
    e.cmt("clobbering it here costs nothing.")
    e.insn("la\tt2, 6f")
    e.rvc_on()
    e.insn("c.jalr\tt2")
    e.label("6")
    e.norvc()

    epilogue(e, name)


# --------------------------------------------------------------------------
# idu_sweep_fwd_chain -- the 9 forwarding-bus comparator bins
# --------------------------------------------------------------------------
def gen_fwd_chain(e):
    name = "idu_sweep_fwd_chain"
    prologue(e, name, [
        "Producer -> consumer chains at distances 1..4, for each of the three",
        "source ports and for each of the three producer types that behave",
        "differently in the RAW-stall except (aq_idu_id_ctrl.v:431-484):",
        "",
        "  ALU  -- forwardable from EX1, except arm 1, never stalls",
        "  LSU  -- except arm 3 only while cnt != 2; arm 4 for store data",
        "  MULT -- same cnt == 2 exclusion as LSU",
        "",
        "Together with the three forward sources rtu_idu_fwd0/1/2 that is the",
        "9-bin dp comparator matrix (aq_idu_id_dp.v:639-727). Which physical",
        "forward slot a given producer lands in is a function of pipeline",
        "occupancy, not of the encoding, so the bins are covered by varying the",
        "distance rather than by naming a slot.",
        "",
        "The last block covers the `reg != 0` guard on all three fwd_vld terms",
        "(:663, :693, :723): a producer whose destination is x0 must not match",
        "a consumer that reads x0.",
    ])

    e.norvc()
    e.insn("addi\tt0, t3, 128", "t0 = store target")
    e.insn("li\tt1, 3")

    for kind, produce, note in (
        ("ALU", "add\tt4, t3, t5", "forwardable from EX1"),
        ("LSU", "ld\tt4, 0(t0)", "load: except arm 2/3, cnt-dependent"),
        ("MULT", "mul\tt4, t3, t1", "multiply: same cnt == 2 exclusion"),
    ):
        for dist in range(1, 5):
            e.hdr("%s producer, distance %d" % (kind, dist))
            for port in range(3):
                e.insn(produce, note if port == 0 else None)
                for _ in range(dist - 1):
                    e.insn("nop")
                if port == 0:
                    e.insn("add\tt2, t4, t3", "consumer reads it on src0")
                    e.insn("xor\tt5, t5, t2")
                elif port == 1:
                    e.insn("add\tt2, t3, t4", "consumer reads it on src1")
                    e.insn("xor\tt5, t5, t2")
                else:
                    e.insn("sd\tt4, 16(t0)", "consumer reads it as store data")

    e.hdr("the `reg != 0` guard on dp_fwd_srcN_fwd_vld")
    e.insn("add\tx0, t3, t5", "a producer whose result is discarded")
    e.insn("add\tt2, x0, t3", "reader of x0 on src0")
    e.insn("xor\tt5, t5, t2")
    e.insn("add\tx0, t3, t5")
    e.insn("add\tt2, t3, x0", "reader of x0 on src1")
    e.insn("xor\tt5, t5, t2")
    e.insn("add\tx0, t3, t5")
    e.insn("sd\tx0, 24(t0)", "reader of x0 on src2")

    epilogue(e, name)


# --------------------------------------------------------------------------
HEADER_S = """/*
 * GENERATED by tests/cases/idu_random/gen_idu_sweeps.py -- do not edit.
 *
 * Straight-line sweeps of the four enumerable leaves of the IDU. See the
 * generator's docstring for the emission rules; the short version is that no
 * destination here is ever x0-as-a-producer, ra, sp, gp, tp, s0 or any
 * callee-saved register, every store lands in the caller's scratch block or in
 * this file's own stack frame, and every result is folded into the return
 * value.
 */

\t.text
"""

HEADER_H = """/*
 * GENERATED by tests/cases/idu_random/gen_idu_sweeps.py -- do not edit.
 *
 * Each function takes a pointer to at least %d writable bytes (the C side
 * passes a slot in rand_scratch with that much slack either side) and returns
 * an accumulator built from every instruction it executed, so that the caller
 * can fold it into rand_sink and nothing can be optimised away.
 */

#ifndef IDU_SWEEPS_H
#define IDU_SWEEPS_H

#include "rand_common.h"

#define IDU_SWEEP_SLACK %d

u64 idu_sweep_imm_src1(volatile u64 *scratch);
u64 idu_sweep_imm_src2(volatile u64 *scratch);
u64 idu_sweep_regidx(volatile u64 *scratch);
u64 idu_sweep_fwd_chain(volatile u64 *scratch);

#endif /* IDU_SWEEPS_H */
""" % (SCRATCH_MAX + 8, SCRATCH_MAX + 8)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out-s", required=True,
                    help="assembly output (goes into work/)")
    ap.add_argument("--out-h", required=True,
                    help="header output (goes into work/)")
    args = ap.parse_args(argv[1:])

    e = Emitter()
    e.raw(HEADER_S)
    gen_imm_src1(e)
    gen_imm_src2(e)
    gen_regidx(e)
    gen_fwd_chain(e)
    e.norvc()          # leave the file in a known state
    e.rvc_on()

    with open(args.out_s, "w") as fh:
        fh.write(e.text())
    with open(args.out_h, "w") as fh:
        fh.write(HEADER_H)

    n = len([l for l in e.lines if l.startswith("\t") and
             not l.startswith("\t/*") and not l.startswith("\t.")])
    sys.stderr.write("gen_idu_sweeps: %s (%d instructions), %s\n"
                     % (args.out_s, n, args.out_h))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
