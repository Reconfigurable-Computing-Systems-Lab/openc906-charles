#!/usr/bin/env python3
"""
Build-time code-layout generator for the ifu_random stress test.

IFU coverage is coverage *of an address layout*, which C cannot express. The
structures under test are indexed and tagged by address bits, not by data:

  * the BTB tags and stores targets with PC[15:0] only (aq_ifu_btb.v:154,
    :628-630), so it aliases every 64 KB and its 16 entries can only be walked
    by 16+ taken branches at 16 distinct PC[15:0];
  * the I-cache index is VA[13:6] (aq_ifu_icache.v:534-535), so set conflicts
    need blocks 16 KB apart at the same line offset;
  * the I-uTLB has 10 entries (aq_mmu_utlb.v:310) and is filled by the jTLB
    even with translation off, so multi-cycle translations need code spread over
    11+ distinct 4 KB pages;
  * `ipack_pred_unalign` / `icache_ipack_unalign` (aq_ifu_ipack.v:472,
    aq_ifu_icache.v:1331) need 32-bit instructions at 2 mod 4;
  * the RAS stores PC[23:0] only (aq_ifu_ras.v:53-58), so a guaranteed
    return-mispredict needs a call across a 16 MB boundary.

None of that survives a compiler. This script emits the whole arena as raw
`.short` / `.word` encodings at generator-computed addresses, plus the matching
C header and the far-stub pattern file.

Design rules, all load-bearing:

  * Raw encodings only, with `.option norelax` at the top of the output. GNU as
    relaxation (c.j <-> j, li expansion, `call` -> jal) silently changes
    instruction *sizes*, which would destroy the byte-exact layout every one of
    the coverage points above depends on. Raw words also assemble identically
    under the Xuantie toolchain and under upstream binutils (the macOS build
    runs THEAD_GCC=0 with no xtheadc).
  * Layout by `.balign` and `.fill` inside ONE section, `.text.arena`, pinned by
    linker_ifu.lcf. No `.org`: it is forward-only and section-relative, so a
    single mistake silently shifts every later block.
  * Inter-block padding is `.fill n, 2, 0x0001` (c.nop) rather than `.space`.
    Zero-filled padding is an illegal RVC encoding, so a runaway would trap once
    per halfword across a whole page; a c.nop slide runs forward into the next
    block, which ends in `ret`, and the run continues.
  * Zero indirect jumps through memory. Every arena control transfer is
    j / jal / b* with a generator-computed offset. Blocks are entered by a call
    from the C dispatcher and left by `ret`. `jalr`-based *calls* are emitted on
    purpose (the RAS groups need them) and one deliberately unpredictable
    `jalr rd!=x1, rs1!=x1` built from `auipc` -- PC-relative, never loaded from
    memory.
  * Register discipline matches the C harness: the arena writes only
    t0-t2 / t3-t6 / a0-a7, never sp/gp/tp/s0-s11. `ra` is touched only by
    deterministic call/return save-restore sequences, never by a randomised
    register field. RVC forms that carry a 3-bit register field use a0-a5 only
    (the 3-bit field encodes x8..x15, and x8/x9 are s0/s1).
  * Every count that reaches a loop from C is masked and incremented inside the
    block (`andi n,n,63; addi n,n,1`), so no argument value can produce an
    unbounded loop. A hang here would show up as a testbench watchdog FAIL with
    no clue attached.

--check (run from the build recipe) asserts every invariant that would otherwise
fail silently: fetch-window legality of every emitted target, no target in the
APB window, unique PC[15:0] for the 20 BTB-fill branches, branch offsets in
range for their encoding, no block overlap, every block terminated, the arena
inside --arena-size -- and re-parses the emitted assembly to confirm the byte
accounting of every label matches the model that computed the offsets.

Usage (exactly as setup/smart_cfg.mk invokes it):
    gen_ifu_arena.py --seed S --arena-base B --arena-size N \\
        --out-s ./work/ifu_arena.S --out-h ./work/ifu_arena.h \\
        --out-far-pat ./work/ifu_far.patgen --far-base 0x01000000 --check

Deterministic: the PRNG is the same xorshift64 as rand_lib.c, seeded only from
--seed, so one seed reproduces byte-identical output. --seed reseeds the code
*layout*, not just the data.
"""

import argparse
import re
import sys

# ==================================================================== #
# PRNG -- xorshift64, the same generator rand_lib.c uses, so the arena and the
# dispatch loop are describable with one algorithm. Never `random`: an unseeded
# global would make the build irreproducible.
# ==================================================================== #
MASK64 = (1 << 64) - 1


class Rng(object):
    def __init__(self, seed):
        self.s = (seed | 1) & MASK64

    def next(self):
        x = self.s
        x ^= (x << 13) & MASK64
        x ^= x >> 7
        x ^= (x << 17) & MASK64
        self.s = x
        return x

    def below(self, n):
        return self.next() % n

    def between(self, lo, hi):
        """inclusive both ends"""
        return lo + self.next() % (hi - lo + 1)

    def pick(self, seq):
        return seq[self.next() % len(seq)]

    def shuffle(self, lst):
        for i in range(len(lst) - 1, 0, -1):
            j = self.next() % (i + 1)
            lst[i], lst[j] = lst[j], lst[i]


# ==================================================================== #
# Register numbers
# ==================================================================== #
X0, RA, SP, GP, TP = 0, 1, 2, 3, 4
T0, T1, T2 = 5, 6, 7
S0, S1 = 8, 9
A0, A1, A2, A3, A4, A5, A6, A7 = 10, 11, 12, 13, 14, 15, 16, 17
T3, T4, T5, T6 = 28, 29, 30, 31

# Writable by arena code. Excludes x0 (writes are dropped), x1/x2/x3/x4/x8
# (ra/sp/gp/tp/s0 -- tp holds &rand_ctx for the trap handler) and x9,x18..x27
# (s1..s11, callee-saved across the C call that entered the block).
SAFE_REGS = (T0, T1, T2, A0, A1, A2, A3, A4, A5, A6, A7, T3, T4, T5, T6)

# Registers the RVC 3-bit rs1'/rd' field can name AND that we are allowed to
# write: the field encodes x8..x15, of which x8/x9 are s0/s1.
CREGS = (A0, A1, A2, A3, A4, A5)

# ra save slots for the nested RAS call chain, one per depth.
RA_SAVE = (T0, T1, T2, T3, T4, T5, T6)


# ==================================================================== #
# Instruction encoders. Every one returns a fixed-size item so the layout pass
# can assign addresses before offsets are known.
#
# Item forms:
#   ('h',  half, txt)                    2 bytes, literal
#   ('w',  word, txt)                    4 bytes, literal
#   ('b16', enc, label, txt)             2 bytes, offset patched in pass B
#   ('b32', enc, label, txt)             4 bytes, offset patched in pass B
#   ('lbl', name)                        0 bytes
#   ('glob', name, proto_args)           0 bytes, global entry point
#   ('align', n)                         pad to n
#   ('fill', nbytes)                     nbytes of c.nop
# ==================================================================== #
def sx(v, bits):
    """assert v fits in a `bits`-wide signed field"""
    lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    if not (lo <= v <= hi):
        raise ValueError("immediate %d out of %d-bit signed range" % (v, bits))
    return v


def c_nop():
    return ('h', 0x0001, 'c.nop')


def c_li(rd, imm):
    sx(imm, 6)
    h = (0b010 << 13) | (((imm >> 5) & 1) << 12) | (rd << 7) | ((imm & 0x1F) << 2) | 0b01
    return ('h', h, 'c.li x%d, %d' % (rd, imm))


def c_addi(rd, imm):
    sx(imm, 6)
    h = (0b000 << 13) | (((imm >> 5) & 1) << 12) | (rd << 7) | ((imm & 0x1F) << 2) | 0b01
    return ('h', h, 'c.addi x%d, %d' % (rd, imm))


def c_mv(rd, rs2):
    h = (0b100 << 13) | (0 << 12) | (rd << 7) | (rs2 << 2) | 0b10
    return ('h', h, 'c.mv x%d, x%d' % (rd, rs2))


def c_add(rd, rs2):
    h = (0b100 << 13) | (1 << 12) | (rd << 7) | (rs2 << 2) | 0b10
    return ('h', h, 'c.add x%d, x%d' % (rd, rs2))


def c_jr(rs1):
    h = (0b100 << 13) | (0 << 12) | (rs1 << 7) | 0b10
    return ('h', h, 'c.jr x%d' % rs1)


def c_jalr(rs1):
    h = (0b100 << 13) | (1 << 12) | (rs1 << 7) | 0b10
    return ('h', h, 'c.jalr x%d' % rs1)


def _enc_cb(funct3, rs1, off):
    """C.BEQZ / C.BNEZ. Field placement cross-checked against the consumer,
    aq_ifu_pre_decd.v:139-141 (cbtype_imm0)."""
    sx(off, 9)
    if off & 1:
        raise ValueError("odd branch offset")
    if rs1 not in CREGS and rs1 not in (S0, S1):
        raise ValueError("c.beqz/c.bnez rs1 x%d is not in x8..x15" % rs1)
    return ((funct3 << 13) | (((off >> 8) & 1) << 12) | (((off >> 3) & 3) << 10) |
            ((rs1 - 8) << 7) | (((off >> 6) & 3) << 5) | (((off >> 1) & 3) << 3) |
            (((off >> 5) & 1) << 2) | 0b01)


def c_beqz(rs1, label):
    return ('b16', lambda o, r=rs1: _enc_cb(0b110, r, o), label,
            'c.beqz x%d, %s' % (rs1, label))


def c_bnez(rs1, label):
    return ('b16', lambda o, r=rs1: _enc_cb(0b111, r, o), label,
            'c.bnez x%d, %s' % (rs1, label))


def _enc_cj(off):
    """C.J. Cross-checked against aq_ifu_pre_decd.v:144-147 (cjtype_imm0)."""
    sx(off, 12)
    if off & 1:
        raise ValueError("odd jump offset")
    return ((0b101 << 13) | (((off >> 11) & 1) << 12) | (((off >> 4) & 1) << 11) |
            (((off >> 8) & 3) << 9) | (((off >> 10) & 1) << 8) |
            (((off >> 6) & 1) << 7) | (((off >> 7) & 1) << 6) |
            (((off >> 1) & 7) << 3) | (((off >> 5) & 1) << 2) | 0b01)


def c_j(label):
    return ('b16', _enc_cj, label, 'c.j %s' % label)


def _enc_b(funct3, rs1, rs2, off):
    sx(off, 13)
    if off & 1:
        raise ValueError("odd branch offset")
    return ((((off >> 12) & 1) << 31) | (((off >> 5) & 0x3F) << 25) | (rs2 << 20) |
            (rs1 << 15) | (funct3 << 12) | (((off >> 1) & 0xF) << 8) |
            (((off >> 11) & 1) << 7) | 0b1100011)


def _b32(mnem, funct3, rs1, rs2, label):
    return ('b32', lambda o, f=funct3, a=rs1, b=rs2: _enc_b(f, a, b, o), label,
            '%s x%d, x%d, %s' % (mnem, rs1, rs2, label))


def beq(rs1, rs2, label):
    return _b32('beq', 0b000, rs1, rs2, label)


def bne(rs1, rs2, label):
    return _b32('bne', 0b001, rs1, rs2, label)


def beqz(rs1, label):
    return _b32('beqz', 0b000, rs1, X0, label)


def bnez(rs1, label):
    return _b32('bnez', 0b001, rs1, X0, label)


def _enc_j(rd, off):
    sx(off, 21)
    if off & 1:
        raise ValueError("odd jump offset")
    return ((((off >> 20) & 1) << 31) | (((off >> 1) & 0x3FF) << 21) |
            (((off >> 11) & 1) << 20) | (((off >> 12) & 0xFF) << 12) |
            (rd << 7) | 0b1101111)


def jal(rd, label):
    return ('b32', lambda o, r=rd: _enc_j(r, o), label, 'jal x%d, %s' % (rd, label))


def j32(label):
    return ('b32', lambda o: _enc_j(X0, o), label, 'j %s' % label)


def _itype(op, funct3, rd, rs1, imm):
    sx(imm, 12)
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | op


def addi(rd, rs1, imm):
    return ('w', _itype(0b0010011, 0b000, rd, rs1, imm),
            'addi x%d, x%d, %d' % (rd, rs1, imm))


def andi(rd, rs1, imm):
    return ('w', _itype(0b0010011, 0b111, rd, rs1, imm),
            'andi x%d, x%d, %d' % (rd, rs1, imm))


def ori(rd, rs1, imm):
    return ('w', _itype(0b0010011, 0b110, rd, rs1, imm),
            'ori x%d, x%d, %d' % (rd, rs1, imm))


def slli(rd, rs1, sh):
    return ('w', _itype(0b0010011, 0b001, rd, rs1, sh & 0x3F),
            'slli x%d, x%d, %d' % (rd, rs1, sh))


def srli(rd, rs1, sh):
    return ('w', _itype(0b0010011, 0b101, rd, rs1, sh & 0x3F),
            'srli x%d, x%d, %d' % (rd, rs1, sh))


def ld(rd, rs1, imm):
    return ('w', _itype(0b0000011, 0b011, rd, rs1, imm),
            'ld x%d, %d(x%d)' % (rd, imm, rs1))


def jalr(rd, rs1, imm):
    return ('w', _itype(0b1100111, 0b000, rd, rs1, imm),
            'jalr x%d, x%d, %d' % (rd, rs1, imm))


def ret_():
    return ('w', 0x00008067, 'ret')


def _rtype(op, funct3, funct7, rd, rs1, rs2):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | op


def add(rd, rs1, rs2):
    return ('w', _rtype(0b0110011, 0b000, 0b0000000, rd, rs1, rs2),
            'add x%d, x%d, x%d' % (rd, rs1, rs2))


def xor_(rd, rs1, rs2):
    return ('w', _rtype(0b0110011, 0b100, 0b0000000, rd, rs1, rs2),
            'xor x%d, x%d, x%d' % (rd, rs1, rs2))


def div(rd, rs1, rs2):
    return ('w', _rtype(0b0110011, 0b100, 0b0000001, rd, rs1, rs2),
            'div x%d, x%d, x%d' % (rd, rs1, rs2))


def rem(rd, rs1, rs2):
    return ('w', _rtype(0b0110011, 0b110, 0b0000001, rd, rs1, rs2),
            'rem x%d, x%d, x%d' % (rd, rs1, rs2))


def auipc(rd, imm20):
    return ('w', ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0b0010111,
            'auipc x%d, %d' % (rd, imm20))


def fence_i():
    return ('w', 0x0000100F, 'fence.i')


def lbl(name):
    return ('lbl', name)


def glob(name, args=''):
    return ('glob', name, args)


def align(n):
    return ('align', n)


def fill(nbytes):
    return ('fill', nbytes)


ITEM_SIZE = {'h': 2, 'w': 4, 'b16': 2, 'b32': 4, 'lbl': 0, 'glob': 0}


# ==================================================================== #
# Blocks
# ==================================================================== #
class Block(object):
    """One contiguous run of emitted bytes with at least one global entry.

    `balign` must be >= the largest internal align() request, so the block's
    size is independent of where it lands -- which is what lets the placement
    pass run before the offset pass.
    """

    def __init__(self, name, items, balign=4, place=None):
        self.name = name
        self.items = items
        self.balign = balign
        self.place = place            # None -> free slot, else absolute address
        self.addr = None
        self.size = None
        self.labels = {}              # local label -> absolute address
        self.globals = []             # (name, args, absolute address)

        for it in items:
            if it[0] == 'align' and it[1] > balign:
                raise AssertionError(
                    "%s: internal align(%d) exceeds block balign %d -- the "
                    "block size would depend on its address" %
                    (name, it[1], balign))

    def measure(self):
        """Size in bytes, assuming the block starts at a multiple of balign."""
        off = 0
        for it in self.items:
            k = it[0]
            if k in ITEM_SIZE:
                off += ITEM_SIZE[k]
            elif k == 'align':
                off = (off + it[1] - 1) & ~(it[1] - 1)
            elif k == 'fill':
                off += it[1]
            else:
                raise AssertionError('unknown item %r' % (it,))
        self.size = off
        return off

    def resolve(self, addr):
        """Assign `addr`, then record every label and global entry address."""
        self.addr = addr
        off = 0
        for it in self.items:
            k = it[0]
            if k == 'lbl':
                self.labels[it[1]] = addr + off
            elif k == 'glob':
                self.globals.append((it[1], it[2], addr + off))
            elif k in ITEM_SIZE:
                off += ITEM_SIZE[k]
            elif k == 'align':
                off = (off + it[1] - 1) & ~(it[1] - 1)
            elif k == 'fill':
                off += it[1]
        assert off == self.size

    def terminated(self):
        """The last emitted instruction must transfer control out of the block:
        ret / c.jr / jalr / j.  A block that falls off its end would slide
        through the c.nop padding into an unrelated block."""
        for it in reversed(self.items):
            if it[0] in ('h', 'w'):
                txt = it[2]
                return (txt.startswith('ret') or txt.startswith('c.jr') or
                        txt.startswith('jalr') or txt.startswith('j ') or
                        txt.startswith('c.j '))
            if it[0] in ('b16', 'b32'):
                return it[3].startswith('j ') or it[3].startswith('c.j ')
        return False


# ==================================================================== #
# Block bodies, one builder per family. Each cites the RTL structure it aims at;
# the group comments in C906_IFU_RANDOM.c carry the same references.
# ==================================================================== #
def b_b2b(rng, k):
    """Groups 0/1: back-to-back redirects. Every branch target's FIRST
    instruction is itself a taken transfer, which is the only way to make
    pcgen_buf_chgflw (aq_ifu_pcgen.v:221-229) matter -- its consumers
    (:277-278, :301-303) suppress a second redirect for exactly one cycle."""
    it = [glob('ifu_blk_b2b%d' % k), c_li(A2, 1)]
    it += [c_bnez(A2, 'L1')]
    it += [c_nop()] * rng.below(4)
    it += [lbl('L1'), c_j('L2')]
    it += [c_nop()] * rng.below(4)
    it += [lbl('L2'), c_bnez(A2, 'L3')]
    it += [c_nop()] * rng.below(4)
    it += [lbl('L3')]
    if rng.below(2):
        it += [c_jr(RA)]
    else:
        it += [ret_()]
    return Block('b2b%d' % k, it)


def b_line(rng, k):
    """Group 6: a loop wholly inside ONE 64 B I-cache line, so the way-predict
    / tag-hit buffer supplies every fetch (aq_ifu_icache.v:596-662: buf_upd_en,
    addr_equal, cen_mask_vld, direct_sel). Exit deliberately crosses the line so
    buf_clr_en / a fresh tag read follows."""
    p = rng.between(5, 12)                     # -> 8..15 RVC in the line
    it = [glob('ifu_blk_line%d' % k), align(64),
          c_li(A2, rng.between(3, 20)), lbl('L')]
    it += [c_addi(A2, -1)]
    it += [c_nop()] * p
    it += [c_bnez(A2, 'L')]
    body = 2 + 2 + 2 * p + 2
    assert body <= 62, body
    it += [fill(64 - body + 2 * rng.below(4))]
    it += [c_jr(RA)]
    return Block('line%d' % k, it, balign=64)


def b_conf(rng, k, addr):
    """Group 7: 2-way, 1-bit-FIFO replacement (aq_ifu_icache.v:604, :1257) and
    the critical-word-first counter req_cnt = icache_miss_addr[5:4]
    (:974-980). Placed at a fixed 16 KB stride with a per-block 16 B / 4 B entry
    offset so all four req_cnt bins and all four refill_bank bins are hit.

    The two entry-offset fields are what those two bins ARE:
      req_cnt      = icache_miss_addr[5:4]      (:974-980), the 16 B field
      refill_bankN = icache_refill_addr[3:2]    (:1004-1007), the 4 B field --
                     the word of the first beat bypassed straight to the packer
                     (icache_refill_addr is the missing FETCH address, :832, so
                     this really is a function of where the block is entered).
    Eight blocks cannot cover the full 4x4 product, so CONF_BANK picks eight
    (req_cnt, bank) pairs that hit all four values of each. --check re-derives
    both sets from the resolved addresses and fails if either is short."""
    it = [glob('ifu_blk_conf%02d' % k),
          c_li(A2, k & 0x1F), c_addi(A2, 1), c_jr(RA)]
    return Block('conf%02d' % k, it, place=addr)


def b_page(rng, k, addr):
    """Group 9: one small block per 4 KB page. Touching more than the 10 I-uTLB
    entries (aq_mmu_utlb.v:310) forces multi-cycle translations, i.e. the refill
    FSM's WFPA state and icache_stall (aq_ifu_icache.v:886-899, :938). The taken
    branch is what also makes these useful as BTB pressure."""
    it = [glob('ifu_blk_page%02d' % k), c_li(A2, 1), c_bnez(A2, 'P'),
          c_nop(), lbl('P'), c_jr(RA)]
    return Block('page%02d' % k, it, place=addr)


def b_walk(rng, addr, nbytes):
    """Group 8: a straight-line RVC sled several times the 32 KB cache, walked
    once, to force capacity eviction across all 256 sets."""
    n = (nbytes - 2) // 2
    it = [glob('ifu_blk_walk'), fill(2 * n), c_jr(RA)]
    return Block('walk', it, balign=64, place=addr)


def b_abort(rng, k, near, far):
    """Group 10: refill_data_abort (aq_ifu_icache.v:952-956) and
    icache_bypass_vld (:1324). The short forward branch is trained not-taken and
    resolved taken on the last trip, so ctrl_icache_abort lands while the
    unconditional jump to the cold 16 KB-distant partner is refilling."""
    n = rng.between(2, 4)
    near_items = [glob('ifu_blk_abort%d' % k),
                  c_li(A2, n), lbl('LOOP'), c_addi(A2, -1),
                  beqz(A2, 'END'),
                  j32('ifu_abort_far%d' % k),
                  lbl('END'), c_jr(RA)]
    far_items = [lbl('ifu_abort_far%d' % k)]
    far_items += [c_nop()] * rng.below(3)
    far_items += [j32('ifu_blk_abort%d_loop' % k)]
    # the far partner jumps back to LOOP: publish it as a cross-block label
    near_items.insert(2, lbl('ifu_blk_abort%d_loop' % k))
    return (Block('abort%d' % k, near_items, place=near),
            Block('abortfar%d' % k, far_items, place=far))


def b_pf(rng, k, addr):
    """Group 11: the prefetch FSM's pf_chk_pass FAIL arm (aq_ifu_icache.v:1046,
    :1071-1076). Two entries 64 B apart into one body: entering at pfa first
    makes line k+1 resident, so the later entry at pfb misses line k and finds
    its prefetch candidate already there."""
    it = [glob('ifu_blk_pfb%d' % k), align(64), fill(64),
          glob('ifu_blk_pfa%d' % k), c_li(A2, 2), lbl('L'), c_addi(A2, -1),
          c_bnez(A2, 'L'), c_jr(RA)]
    return Block('pf%d' % k, it, balign=64, place=addr)


def b_pflast(rng, addr):
    """Group 11: prefetch address arithmetic increments VA[11:6] only
    (aq_ifu_icache.v:1131-1135), so a prefetch never crosses a 4 KB page. A miss
    on the LAST line of a page therefore prefetches the FIRST line of the same
    page."""
    it = [glob('ifu_blk_pflast'), c_li(A2, 1), c_bnez(A2, 'P'), c_nop(),
          lbl('P'), c_nop(), c_nop(), c_jr(RA)]
    return Block('pflast', it, balign=64, place=addr)


def b_pgstraddle(rng, addr):
    """Groups 9 and 36: a 32-bit branch placed at page_off 0xFFE, so the single
    instruction spans TWO 4 KB pages and needs two I-uTLB lookups -- and, since
    0xFFE is 2 mod 4, it is also a 32-bit instruction straddling the fetch word
    (ipack_pred_unalign, aq_ifu_ipack.v:472; icache_ipack_unalign =
    icache_pa[1], aq_ifu_icache.v:1331). It is additionally the SRAM-side
    ingredient the Sv39 expt_high case would need: clear X on the following page
    and the fault lands on the HIGH half of a genuine 32-bit opcode."""
    it = [glob('ifu_blk_pgstraddle'),
          beq(A2, A2, 'T'),                    # 0xFFE..0x1001: crosses the page
          c_nop(),
          lbl('T'), c_jr(RA)]
    return Block('pgstraddle', it, balign=2, place=addr)


def b_btb(rng, k, addr):
    """Group 20: BTB allocation only happens when ibuf_pred_hungry
    (aq_ifu_pred.v:795-796, aq_ifu_ibuf.v:1346 = at most two valid halfwords in
    the IBUF), so each taken branch is preceded by a divide it depends on: the
    RAW hazard stalls the IDU, the IBUF drains, and the branch arrives hungry.
    20 of these at 20 distinct PC[15:0] walk btb_fifo (aq_ifu_btb.v:604-614)
    right round its 16 entries."""
    v = rng.between(3, 31)
    it = [glob('ifu_blk_btb%02d' % k),
          c_li(A5, v), c_li(A6, 1),
          div(A7, A5, A6),
          bne(A7, X0, 'T'),                    # RAW on a7 -> IDU stall
          c_nop(),
          lbl('T'), c_jr(RA)]
    return Block('btb%02d' % k, it, place=addr)


def b_mis(rng, k):
    """Group 21: both independent btb_mis_pred causes (aq_ifu_pred.v:718-721)
    at one trained PC. The direction comes from a caller-supplied random bit, so
    `!pred_br_taken with a valid BTB target` and a correct prediction alternate,
    which is what drives btb_clr_one and the FIFO steering
    (aq_ifu_btb.v:593-598, :610-611)."""
    it = [glob('ifu_blk_mis%d' % k, 'unsigned long'),
          andi(A2, A0, 1),
          c_bnez(A2, 'ALT'),
          c_j('T1'),
          lbl('ALT'), c_j('T2'),
          lbl('T1')]
    it += [c_nop()] * rng.between(1, 3)
    it += [c_jr(RA), lbl('T2')]
    it += [c_nop()] * rng.between(1, 4)
    it += [c_jr(RA)]
    return Block('mis%d' % k, it)


def b_alias(rng, tag, addr, extra_nops):
    """Group 22b: BTB tag AND target are PC[15:0] only (aq_ifu_btb.v:154,
    :628-630) with the upper bits re-attached from pcgen_ifpc[39:16]
    (aq_ifu_pcgen.v:307). These two blocks sit exactly 64 KB apart with an
    identical prologue, so their branches share a PC[15:0] and each one's
    training gives the other the wrong target."""
    it = [glob('ifu_blk_alias_%s' % tag),
          c_li(A2, 1),
          c_bnez(A2, 'T'),
          c_nop()]
    it += [c_nop()] * extra_nops
    it += [lbl('T'), c_jr(RA)]
    return Block('alias_%s' % tag, it, place=addr)


def b_x64k(rng, br_addr, tgt_addr):
    """Group 22a: a taken branch just below a 64 KB boundary whose target is
    just above it. The BTB records target[15:0] and pcgen re-attaches the
    fetch PC's own [39:16], so the prediction lands 64 KB low every time."""
    br = [glob('ifu_blk_x64k'), c_li(A2, 1), c_nop(),
          bne(A2, X0, 'ifu_x64k_tgt'), c_nop(), c_jr(RA)]
    tgt = [lbl('ifu_x64k_tgt')]
    tgt += [c_nop()] * rng.between(1, 3)
    tgt += [c_jr(RA)]
    return (Block('x64k', br, balign=64, place=br_addr),
            Block('x64ktgt', tgt, place=tgt_addr))


def b_stall(rng, k):
    """Group 5: ibuf_stall -> ibuf_ctrl_inst_fetch = 0 (aq_ifu_ibuf.v:1194,
    :1337) and the three ibuf_entry_stall arms (:1190-1193). A long-latency
    producer the next instruction depends on holds the IDU while a straight-line
    RVC run keeps filling the six-entry buffer."""
    use_load = bool(rng.below(2))
    it = [glob('ifu_blk_stall%d' % k, 'volatile unsigned long *'),
          c_li(A4, rng.between(3, 31)), c_li(A5, 3)]
    if use_load:
        it += [ld(A6, A0, 0x100 if rng.below(2) else 0)]
    else:
        it += [div(A6, A4, A5)]
    it += [add(A7, A6, A6)]                    # RAW: stalls issue
    it += [c_nop()] * rng.between(20, 30)
    it += [c_jr(RA)]
    return Block('stall%d' % k, it)


def b_delaybr(rng, k):
    """Groups 3/34: pred_delay_br_raw (aq_ifu_pred.v:546-555) needs a branch
    predicted NOT taken in slot0 and another branch in slot1 of the SAME 4-byte
    fetch group, which also produces pred_delay_reissue -> ipack_pcgen_reissue
    (aq_ifu_pcgen.v:245-246). The caller keeps a0 non-zero so slot0 trains
    not-taken."""
    it = [glob('ifu_blk_delaybr%d' % k, 'unsigned long'),
          andi(A2, A0, 1),
          align(4),
          c_beqz(A2, 'D1'),                    # slot0, trained not-taken
          c_bnez(A2, 'D2'),                    # slot1, same fetch group
          lbl('D1')]
    it += [c_nop()] * rng.between(1, 3)
    it += [c_jr(RA), lbl('D2')]
    it += [c_nop()] * rng.between(1, 3)
    it += [c_jr(RA)]
    return Block('delaybr%d' % k, it)


def b_twobr(rng, k):
    """Group 35: two transfers in one 4-byte group -- pred_inst1_taken
    (aq_ifu_pred.v:589-591) and pred_ras_link_vld1 / pred_ras_ret_vld1
    (:612, :618)."""
    it = [glob('ifu_blk_twobr%d' % k, 'unsigned long'),
          c_mv(T0, RA),                        # keep the real return address
          andi(A2, A0, 1)]
    if k == 0:
        it += [align(4), c_beqz(A2, 'X'), c_j('Y'),
               lbl('X')] + [c_nop()] * 2 + [lbl('Y')]
        it += [c_mv(RA, T0), c_jr(RA)]
    elif k == 1:
        # slot1 is a return: c.jr ra with ra still live
        it += [align(4), c_beqz(A2, 'X'), c_jr(RA),
               lbl('X'), c_nop(), c_mv(RA, T0), c_jr(RA)]
    else:
        # slot1 is a link: c.jalr ra, so ra must first point at the landing pad
        it += [auipc(T1, 0), addi(T1, T1, 16), c_mv(RA, T1),
               align(4), c_beqz(A2, 'X'), c_jalr(RA),
               lbl('X'), c_nop(), c_mv(RA, T0), c_jr(RA)]
    return Block('twobr%d' % k, it)


def b_strad(rng, k):
    """Group 36: ipack_pred_unalign steering pred_btb_cur_pc to a different PC
    source (aq_ifu_pred.v:804) and icache_ipack_unalign = icache_pa[1]
    (aq_ifu_icache.v:1331). A leading c.nop puts the 32-bit transfer at 2 mod 4;
    the target's own parity is randomised too, so the fetch that lands on it
    starts unaligned."""
    lead = k & 1                               # 32-bit inst at 2 mod 4 or 0 mod 4
    tgt_odd = (k >> 1) & 1                     # target at 2 mod 4 or not
    it = [glob('ifu_blk_strad%d' % k, 'unsigned long'), align(4),
          andi(A2, A0, 1)]
    it += [c_nop()] * lead
    it += [beq(A2, A2, 'T')]                   # always taken, 32-bit
    it += [c_nop()] * (1 + tgt_odd)
    it += [lbl('T')]
    it += [c_nop()] * rng.between(1, 2)
    it += [ret_() if rng.below(2) else c_jr(RA)]
    return Block('strad%d' % k, it)


def b_shape(rng, k):
    """Group 37: the five retire shapes of aq_ifu_ipack.v:373-380 plus
    ipack_one_16bit_vld (:399-403) and the three-halfword ipack_all_vld
    (:412-415). Block k starts its 32-bit instruction at halfword position k, so
    across the family a 32-bit instruction straddles the fetch word at every
    position."""
    it = [glob('ifu_blk_shape%d' % k), align(4)]
    it += [c_nop()] * k
    it += [addi(A2, A2, 0)]                    # the 32-bit at position k
    for _ in range(rng.between(2, 5)):
        if rng.below(2):
            it += [c_mv(A3, A2)]
        else:
            it += [addi(A3, A2, 1)]
    it += [c_jr(RA)]
    return Block('shape%d' % k, it)


def b_rot(rng, k):
    """Group 38: the three push-rotate amounts over six pointer positions
    (aq_ifu_ibuf.v:974-998 and the push1/push2 fan-out :1032-1078), the pop
    muxes (:754-816), the empty-buffer bypass (:938-971) and the flush pointer
    collapse push0 <= pop0 (:980). Each block is a random (length mix, stall
    index, flush index) triple: the divide creates the IDU stall, the
    random-direction branch creates the flush."""
    n = rng.between(10, 16)
    s_idx = rng.below(n - 2)
    f_idx = rng.between(s_idx + 1, n - 1)
    it = [glob('ifu_blk_rot%d' % k, 'unsigned long, volatile unsigned long *'),
          c_li(A4, rng.between(3, 31)), c_li(A5, 1)]
    for i in range(n):
        if i == s_idx:
            it += [div(A6, A4, A5), add(A7, A6, A6)]
        elif i == f_idx:
            it += [andi(A2, A0, 1), c_beqz(A2, 'F%d' % k)]
        elif rng.below(3) == 0:
            it += [ld(A3, A1, 8 * rng.below(16))]
        elif rng.below(2):
            it += [addi(A4, A4, 1)]
        else:
            it += [c_nop()]
    it += [lbl('F%d' % k)]
    it += [c_nop()] * rng.between(1, 3)
    it += [c_jr(RA)]
    return Block('rot%d' % k, it)


def b_loop(rng, k):
    """Groups 23/28: a trained loop for the BTB / BHT invalidate groups to
    knock down. The trip count is masked and incremented inside the block, so no
    caller value can make it unbounded."""
    it = [glob('ifu_blk_loop%d' % k, 'unsigned long'),
          andi(A2, A0, 63), c_addi(A2, 1),
          lbl('L'), c_addi(A2, -1)]
    it += [c_nop()] * rng.between(0, 3)
    it += [c_bnez(A2, 'L'), c_jr(RA)]
    return Block('loop%d' % k, it)


def b_bhtwalk(rng):
    """Group 24: ONE branch whose direction is a caller-supplied random bit.
    The BHT is indexed by the 14-bit global history alone (aq_ifu_bht.v:253-257,
    :305) -- pred_bht_pc is a forced, unused input (:134-135) -- so a single
    branch random-walking its direction covers the whole (index, way) space,
    while many distinct branches would all share one history and cover less."""
    it = [glob('ifu_blk_bhtwalk', 'unsigned long, unsigned long'),
          c_mv(A2, A0),                        # a2 = the random bit stream
          andi(A3, A1, 63), c_addi(A3, 1),     # a3 = 1..64 iterations
          lbl('L'),
          andi(A4, A2, 1),
          srli(A2, A2, 1),
          c_bnez(A4, 'T'),                     # <-- THE branch
          c_nop(),
          lbl('T'),
          c_addi(A3, -1),
          c_bnez(A3, 'L'),
          c_jr(RA)]
    return Block('bhtwalk', it)


def b_bhtrep(rng, k):
    """Group 25: BHT_REF_WRTE / BHT_REF_UPD stall while pred_bht_br_vld is set
    (aq_ifu_bht.v:427-441), so the repair FSM is only visible with a SECOND
    branch immediately behind a mispredicting one -- here two RVC branches two
    bytes apart at a 4-byte boundary."""
    it = [glob('ifu_blk_bhtrep%d' % k, 'unsigned long, unsigned long'),
          c_mv(A2, A0), andi(A3, A1, 63), c_addi(A3, 1),
          lbl('L'),
          andi(A4, A2, 1),
          srli(A2, A2, 1),
          align(4),
          c_beqz(A4, 'A'),                     # mispredicts ~half the time
          c_bnez(A4, 'B'),                     # 2 bytes later
          lbl('A')]
    it += [c_nop()] * (1 + k)
    it += [lbl('B'), c_addi(A3, -1), c_bnez(A3, 'L'), c_jr(RA)]
    return Block('bhtrep%d' % k, it)


def b_bhtbyp(rng):
    """Group 26: the BHT write-forward network (aq_ifu_bht.v:275-295). A
    two-instruction always-taken self-loop keeps vghr[11:2] constant, so
    back-to-back branches hit the same row and the bypass is the only source of
    a correct counter."""
    it = [glob('ifu_blk_bhtbyp', 'unsigned long'),
          andi(A2, A0, 63), c_addi(A2, 1),
          lbl('L'), c_addi(A2, -1), c_bnez(A2, 'L'),
          c_jr(RA)]
    return Block('bhtbyp', it)


def b_vghr(rng):
    """Group 27: the VGHR reload from GHR on mispredict (aq_ifu_bht.v:215) and
    the read/write index skew (write bht_ref_vghr[13:4], read vghr[11:2],
    :253-257). A deliberately mispredicting branch is planted after a long
    random history stream, at a caller-randomised depth."""
    it = [glob('ifu_blk_vghr', 'unsigned long, unsigned long'),
          c_mv(A2, A0), andi(A3, A1, 31), c_addi(A3, 1),
          lbl('L'),
          andi(A4, A2, 1), srli(A2, A2, 1),
          c_beqz(A4, 'S'), c_nop(), lbl('S'),
          c_addi(A3, -1), c_bnez(A3, 'L'),
          # the planted mispredictor: direction from a high bit of the stream,
          # reached with a deep, essentially random history
          srli(A5, A0, 40), andi(A5, A5, 1),
          c_beqz(A5, 'M'), c_nop(), lbl('M'),
          c_jr(RA)]
    return Block('vghr', it)


def b_ras_chain(rng, depth, nlevels):
    """Group 29: the RAS is 4 entries with a silently wrapping pointer
    (aq_ifu_ras.v:137, :206-214) and a 4-arm read case (:238-243). Calling level
    d gives a nested chain of depth nlevels-d, so depths 1..6 all occur and the
    pointer wraps. Each level parks the caller's ra in its own register, so the
    chain needs no stack traffic."""
    name = 'ifu_blk_ras_d%d' % depth
    it = [glob(name)]
    if depth == nlevels - 1:
        it += [c_jr(RA)]
    else:
        sv = RA_SAVE[depth % len(RA_SAVE)]
        it += [c_mv(sv, RA),
               jal(RA, 'ifu_blk_ras_d%d' % (depth + 1)),
               c_mv(RA, sv), c_jr(RA)]
    return Block('ras_d%d' % depth, it)


def b_ras_linkonly(rng):
    """Group 30: `jalr ra, ra, 0` has rd == x1, so aq_ifu_pre_decd.v:132 makes
    it a LINK and :127-128 refuses it as a return -- a push with no matching
    pop. It still lands on the caller's return address, so the block returns
    normally while leaving the RAS one entry deep."""
    it = [glob('ifu_blk_ras_linkonly')]
    it += [c_nop()] * rng.between(1, 3)
    it += [jalr(RA, RA, 0)]
    return Block('ras_linkonly', it)


def b_ras_unpred(rng):
    """Group 30: `jalr rd!=x1, rs1!=x1` is neither a link nor a return
    (aq_ifu_pre_decd.v:127-133), so nothing predicts it and the resolved target
    arrives as iu_ifu_tar_pc_vld -- the only feeder of the pcgen_ifpc[63:40]
    path (aq_ifu_pcgen.v:258-259) and of redirect arm 2. The address comes from
    auipc, i.e. from the PC, never from memory."""
    it = [glob('ifu_blk_ras_unpred'),
          c_mv(T0, RA),
          auipc(T1, 0),
          addi(T1, T1, 12),                    # -> the instruction after jalr
          jalr(T2, T1, 0),
          c_mv(RA, T0),
          c_jr(RA)]
    return Block('ras_unpred', it)


def b_ras_cjalr(rng):
    """Group 30: ras_link_offset is 4 for a 32-bit link and 2 for a 16-bit one
    (aq_ifu_pred.v:625-626). This block links with c.jalr (16-bit); b_ras_jal
    links with jal (32-bit)."""
    it = [glob('ifu_blk_ras_cjalr'),
          c_mv(T0, RA),
          auipc(T1, 0),
          addi(T1, T1, 12),                    # -> L
          c_mv(RA, T1),
          c_jalr(RA),                           # 16-bit link: offset 2
          lbl('L'),
          c_mv(RA, T0),
          c_jr(RA)]
    return Block('ras_cjalr', it)


def b_ras_jal(rng):
    """Group 30: the 32-bit link form, ras_link_offset = 4."""
    it = [glob('ifu_blk_ras_jal'),
          c_mv(T0, RA),
          jal(RA, 'L'),
          c_mv(RA, T0),
          c_jr(RA),
          lbl('L'), c_jr(RA)]
    return Block('ras_jal', it)


def b_ras_retret(rng, wide):
    """Group 31: the RAS_IDLE/RAS_WAIT FSM and pred_ret_stall
    (aq_ifu_pred.v:659-697), which feeds the three-way pred_id_stall (:741).
    Two returns adjacent in one fetch group put a second pred_ras_ret_vld behind
    the first; the second is never executed, only fetched and pre-decoded."""
    name = 'ifu_blk_ras_retret32' if wide else 'ifu_blk_ras_retret'
    it = [glob(name), c_mv(T0, RA), jal(RA, 'RR'),
          c_mv(RA, T0), c_jr(RA),
          align(4), lbl('RR')]
    if wide:
        it += [ret_(), ret_()]                 # 4 bytes apart
    else:
        it += [c_jr(RA), c_jr(RA)]             # 2 bytes apart, one fetch group
    return Block(name[8:], it)


def b_noop(rng, k, near, far):
    """Group 40: ifu_yy_xx_no_op = ref_fsm_idle && pf_fsm_idle
    (aq_ifu_icache.v:1384). The fence.i sits at the head of a cold 16 KB-distant
    block, i.e. exactly where the demand refill that fetched it and the
    prefetch of the following line are both still outstanding."""
    near_items = [glob('ifu_blk_noop%d' % k), j32('ifu_noop_far%d' % k)]
    far_items = [lbl('ifu_noop_far%d' % k), fence_i()]
    far_items += [c_nop()] * rng.between(1, 3)
    far_items += [c_jr(RA)]
    return (Block('noop%d' % k, near_items, place=near),
            Block('noopfar%d' % k, far_items, balign=64, place=far))


def b_highpc(rng):
    """Group 2: pcgen_ifpc[63:40] <= iu_ifu_tar_pc[63:40]
    (aq_ifu_pcgen.v:258-259) is fed ONLY by a resolved jalr, so reaching it
    needs a real indirect jump to an address with VA bit 39 set. The fetch there
    always faults, which is why the C side wraps this in rand_run_at(): the
    excursion's fault net returns to its landing pad instead of trying to step
    over an instruction it cannot fetch."""
    it = [glob('ifu_blk_highpc'),
          addi(T1, X0, 1),
          slli(T1, T1, 39),
          jalr(T2, T1, 0),
          c_jr(RA)]                            # never reached; keeps the block
    return Block('highpc', it)                 # terminated for the checker


# ==================================================================== #
# Placement
# ==================================================================== #
PAGE = 0x1000
SLOT = 0x100
SLOTS_PER_PAGE = PAGE // SLOT
SLED_PAGES = 12
TAIL_SPARE_PAGES = 2

# Group 7, the 4 B component of each conflict block's entry offset -- i.e. which
# refill_bankN_sel it enters on (icache_refill_addr[3:2], aq_ifu_icache.v:1004).
# The 16 B component is k % 4, which is req_cnt (icache_miss_addr[5:4], :974).
# Eight blocks cannot cover the 4x4 product, so these eight (req_cnt, bank)
# pairs are chosen to cover all four values of EACH, subject to
# 16*(k%4) + 4*bank + sizeof(block) <= 0x40 so every block stays in one line.
CONF_BANK = (0, 1, 3, 2, 3, 2, 1, 0)


class Arena(object):
    def __init__(self, base, size, rng):
        if base & (PAGE - 1):
            die("--arena-base 0x%x is not 4 KB aligned" % base)
        if size & (PAGE - 1):
            die("--arena-size 0x%x is not a multiple of 4 KB" % size)
        self.base = base
        self.size = size
        self.rng = rng
        self.npages = size // PAGE
        if self.npages < 40:
            die("--arena-size 0x%x is only %d pages; the layout needs >= 40 "
                "(20 page-spread blocks, 8 blocks at a 16 KB stride and a "
                "48 KB sled)" % (size, self.npages))
        # MEM1 in linker_ifu.lcf is 0x0..0x40000 and .rodata follows the arena,
        # so an oversized --arena-size is a link failure waiting to happen.
        if base + size > 0x40000:
            die("--arena-base 0x%x + --arena-size 0x%x runs past MEM1 "
                "(0x0..0x40000 in linker_ifu.lcf)" % (base, size))
        if base + size > 0x3C000:
            sys.stderr.write("gen_ifu_arena.py: warning: the arena ends at "
                             "0x%x, leaving under 16 KB of MEM1 for .rodata\n"
                             % (base + size))
        self.sled_page = self.npages - SLED_PAGES - TAIL_SPARE_PAGES
        if self.sled_page < 32:
            die("--arena-size 0x%x leaves only %d pages below the sled; the "
                "16 KB-stride blocks need 32" % (size, self.sled_page))
        self.claimed = []              # list of (lo, hi) absolute byte ranges
        self.blocks = []

    def at(self, page, off):
        return self.base + page * PAGE + off

    def _overlaps(self, lo, hi):
        for (a, b) in self.claimed:
            if lo < b and a < hi:
                return True
        return False

    def add(self, blk):
        blk.measure()
        if blk.place is None:
            die("internal: %s has no placement" % blk.name)
        if blk.place & (blk.balign - 1):
            die("internal: %s wants balign %d at 0x%x" %
                (blk.name, blk.balign, blk.place))
        lo, hi = blk.place, blk.place + blk.size
        if self._overlaps(lo, hi):
            die("internal: %s at 0x%x..0x%x overlaps an earlier block"
                % (blk.name, lo, hi))
        self.claimed.append((lo, hi))
        self.blocks.append(blk)
        return blk

    def free_slots(self):
        """Every unclaimed 256 B slot below the sled, in a seed-shuffled order.
        This is the part that makes --seed reseed the code *layout*: the same
        block bodies land at different addresses, so the BTB tags, the I-cache
        sets and the page spread all change."""
        out = []
        for p in range(self.sled_page):
            for s in range(SLOTS_PER_PAGE):
                lo = self.at(p, s * SLOT)
                if not self._overlaps(lo, lo + SLOT):
                    out.append(lo)
        self.rng.shuffle(out)
        return out


def die(msg):
    sys.stderr.write("gen_ifu_arena.py: error: %s\n" % msg)
    sys.exit(1)


def build_arena(rng, base, size):
    ar = Arena(base, size, rng)

    # ---- 1. the sled: 48 KB contiguous, so it has to be reserved first ----
    ar.add(b_walk(rng, ar.at(ar.sled_page, 0), SLED_PAGES * PAGE))

    # ---- 2. 16 KB-stride I-cache set conflicts (group 7) ----
    # base + k*0x4000 keeps VA[13:6] identical; the per-block 16 B / 4 B entry
    # offset sweeps req_cnt (icache_miss_addr[5:4]) and the refill bank select
    # (icache_refill_addr[3:2]).  CONF_BANK[k] is the 4 B field: the obvious
    # `(k >> 2) % 4` only ever yields 0 or 1 for k < 8, so banks 2 and 3 were
    # never entered from this family.  Every offset stays inside 0x800..0x83F so
    # all eight blocks still land in ONE 64 B line, i.e. one I-cache set.
    conf = []
    for k in range(8):
        off = 0x800 + 16 * (k % 4) + 4 * CONF_BANK[k]
        assert off + 8 <= 0x840, off       # must not spill into the next line
        conf.append(ar.add(b_conf(rng, k, ar.at(4 * k, off))))

    # ---- 3. addresses that are only interesting at one exact offset ----
    ar.add(b_pflast(rng, ar.at(30, 0xFC0)))          # last line of a page
    # Deliberately runs off the end of its page. add() records the whole range,
    # so the free-slot allocator will not hand slot 0 of the next page out.
    ar.add(b_pgstraddle(rng, ar.at(31, 0xFFE)))
    # The 64 KB boundary is a property of the absolute address, not of a page
    # index, so it has to be found rather than assumed -- with --arena-base
    # 0x8000 it falls at 0x10000, but any other base moves it.
    top = ar.at(ar.sled_page, 0)
    b64 = None
    a = (ar.base + 0xFFFF) & ~0xFFFF
    while a < top:
        if a - 0x40 >= ar.base and a + 0x80 < top:
            b64 = a
            break
        a += 0x10000
    if b64 is None:
        die("no 64 KB boundary inside the arena: group 22a cannot be built "
            "with --arena-base 0x%x / --arena-size 0x%x" % (ar.base, ar.size))
    x64k_br, x64k_tgt = b_x64k(rng, b64 - 0x40, b64 + 0x40)
    ar.add(x64k_br)
    ar.add(x64k_tgt)
    ar.add(b_alias(rng, 'lo', ar.at(2, 0xE00), 1))   # exactly 64 KB apart
    ar.add(b_alias(rng, 'hi', ar.at(18, 0xE00), 4))

    # ---- 4. 16 KB-strided near/far pairs (groups 10 and 40) ----
    for k in range(3):
        near, far = b_abort(rng, k, ar.at(1 + k, 0xA00), ar.at(5 + k, 0xA00))
        ar.add(near)
        ar.add(far)
    for k in range(3):
        near, far = b_noop(rng, k, ar.at(9 + k, 0xB00), ar.at(13 + k, 0xB40))
        ar.add(near)
        ar.add(far)

    # ---- 5. prefetch pairs, 64 B aligned ----
    for k in range(3):
        ar.add(b_pf(rng, k, ar.at(17 + k, 0xC00)))

    # ---- 6. 20 page-spread blocks, one per 4 KB page (group 9) ----
    # Placed before the BTB family because these want one fixed slot per page
    # and the BTB blocks pick their slot at random within a given page.
    pages = [p for p in range(1, ar.sled_page) if p % 4 != 0][:20]
    if len(pages) < 20:
        die("internal: only %d non-conflict pages available" % len(pages))
    for k, p in enumerate(pages):
        ar.add(b_page(rng, k, ar.at(p, 0x100)))

    # ---- 7. the 20 BTB-fill branches (group 20) ----
    # Distinct (page mod 16, slot) implies distinct block start [15:0], and
    # since a slot is 256 B and every body is shorter than that, distinct block
    # starts imply distinct branch PC[15:0]. --check re-derives and asserts it
    # from the resolved addresses rather than trusting this argument.
    used_ps = set()
    for k in range(20):
        p = k
        for _ in range(SLOTS_PER_PAGE * 8):
            s = rng.below(SLOTS_PER_PAGE)
            lo = ar.at(p, s * SLOT)
            if (p % 16, s) in used_ps or ar._overlaps(lo, lo + SLOT):
                continue
            used_ps.add((p % 16, s))
            ar.add(b_btb(rng, k, lo))
            break
        else:
            die("internal: no free slot for BTB block %d in page %d" % (k, p))

    # ---- 8. everything with no address constraint ----
    free = ar.free_slots()
    fi = [0]

    def place_free(blk):
        blk.measure()
        while fi[0] < len(free):
            lo = free[fi[0]]
            fi[0] += 1
            a = (lo + blk.balign - 1) & ~(blk.balign - 1)
            if a - lo + blk.size <= SLOT and not ar._overlaps(a, a + blk.size):
                blk.place = a
                return ar.add(blk)
        die("internal: out of free slots placing %s" % blk.name)

    for k in range(4):
        place_free(b_b2b(rng, k))
    for k in range(4):
        place_free(b_line(rng, k))
    for k in range(4):
        place_free(b_stall(rng, k))
    for k in range(4):
        place_free(b_delaybr(rng, k))
    for k in range(4):
        place_free(b_mis(rng, k))
    for k in range(3):
        place_free(b_twobr(rng, k))
    for k in range(4):
        place_free(b_strad(rng, k))
    for k in range(6):
        place_free(b_shape(rng, k))
    for k in range(8):
        place_free(b_rot(rng, k))
    for k in range(2):
        place_free(b_loop(rng, k))
    place_free(b_bhtwalk(rng))
    for k in range(2):
        place_free(b_bhtrep(rng, k))
    place_free(b_bhtbyp(rng))
    place_free(b_vghr(rng))
    for d in range(6):
        place_free(b_ras_chain(rng, d, 6))
    place_free(b_ras_linkonly(rng))
    place_free(b_ras_unpred(rng))
    place_free(b_ras_cjalr(rng))
    place_free(b_ras_jal(rng))
    place_free(b_ras_retret(rng, False))
    place_free(b_ras_retret(rng, True))
    place_free(b_highpc(rng))

    ar.blocks.sort(key=lambda b: b.place)
    return ar


# ==================================================================== #
# Offset resolution
# ==================================================================== #
def resolve(ar):
    """Pass 2: assign every label an absolute address, then patch every branch
    and jump with a generator-computed offset. Sizes were fixed in pass 1, so no
    offset can change a size and one pass is exact."""
    labels = {}
    for blk in ar.blocks:
        blk.resolve(blk.place)
        for name, addr in blk.labels.items():
            key = name if name.startswith('ifu_') else '%s.%s' % (blk.name, name)
            if key in labels:
                die("internal: duplicate label %s" % key)
            labels[key] = addr
        for name, _args, addr in blk.globals:
            if name in labels:
                die("internal: duplicate global %s" % name)
            labels[name] = addr

    edges = []          # (from_pc, to_addr, kind, block)
    for blk in ar.blocks:
        off = 0
        for idx, it in enumerate(blk.items):
            k = it[0]
            if k in ('b16', 'b32'):
                pc = blk.addr + off
                target = it[2]
                key = target if target.startswith('ifu_') \
                    else '%s.%s' % (blk.name, target)
                if key not in labels:
                    die("internal: %s references unknown label %s"
                        % (blk.name, target))
                dst = labels[key]
                try:
                    word = it[1](dst - pc)
                except ValueError as e:
                    die("%s at 0x%x: %s -> 0x%x: %s"
                        % (blk.name, pc, it[3], dst, e))
                blk.items[idx] = ('h' if k == 'b16' else 'w', word,
                                  '%s  # 0x%08x' % (it[3], dst))
                edges.append((pc, dst, it[3], blk.name))
            if k in ITEM_SIZE:
                off += ITEM_SIZE[k]
            elif k == 'align':
                off = (off + it[1] - 1) & ~(it[1] - 1)
            elif k == 'fill':
                off += it[1]
    return labels, edges


# ==================================================================== #
# Emission
# ==================================================================== #
HEADER = """/*
 * ifu_arena.S -- GENERATED by tests/cases/ifu_random/gen_ifu_arena.py.
 * DO NOT EDIT: the whole point of this file is that its byte layout is exact.
 *
 *   arena base 0x%08x   size 0x%08x   end 0x%08x   seed 0x%016x
 *   %d blocks, %d global entry points
 *
 * Everything is a raw .short / .word encoding and `.option norelax` is on,
 * because assembler relaxation changes instruction SIZES (c.j <-> j, li
 * expansion, call -> jal) and every coverage point here is a function of the
 * address a specific instruction lands on. Padding is c.nop rather than zero so
 * that a runaway slides into the next block -- which ends in `ret` -- instead of
 * trapping once per halfword.
 *
 * The arena writes only t0-t2 / t3-t6 / a0-a7. sp, gp, tp (which holds
 * &rand_ctx for the trap handler), s0 and s1-s11 are never touched; `ra` is
 * only ever moved by a deterministic save/restore around a call.
 */
"""


def emit(ar, seed, path):
    nglob = sum(len(b.globals) for b in ar.blocks)
    end = max(b.addr + b.size for b in ar.blocks)
    lines = [HEADER % (ar.base, ar.size, end, seed, len(ar.blocks), nglob)]
    lines.append('\t.option norelax')
    lines.append('\t.section .text.arena, "ax", @progbits')
    lines.append('\t.balign 4096')
    lines.append('')

    cur = ar.base
    for blk in ar.blocks:
        gap = blk.addr - cur
        if gap < 0:
            die("internal: block %s at 0x%x is behind the cursor 0x%x"
                % (blk.name, blk.addr, cur))
        if gap:
            if gap & 1:
                die("internal: odd gap %d before %s" % (gap, blk.name))
            lines.append('\t.fill %d, 2, 0x0001\t\t/* pad to 0x%08x */'
                         % (gap // 2, blk.addr))
            cur += gap
        if blk.balign > 2:
            lines.append('\t.balign %d' % blk.balign)
        lines.append('/* ---- %s : 0x%08x .. 0x%08x (%d bytes) ---- */'
                     % (blk.name, blk.addr, blk.addr + blk.size, blk.size))
        off = 0
        for it in blk.items:
            k = it[0]
            if k == 'glob':
                lines.append('\t.globl %s' % it[1])
                lines.append('\t.type  %s, @function' % it[1])
                lines.append('%s:' % it[1])
            elif k == 'lbl':
                lines.append('%s_%s:' % (blk.name, it[1]) if
                             not it[1].startswith('ifu_') else '%s:' % it[1])
            elif k == 'h':
                lines.append('\t.short 0x%04x\t\t/* %s */' % (it[1], it[2]))
                off += 2
            elif k == 'w':
                lines.append('\t.word  0x%08x\t/* %s */' % (it[1] & 0xFFFFFFFF,
                                                            it[2]))
                off += 4
            elif k == 'align':
                lines.append('\t.balign %d' % it[1])
                off = (off + it[1] - 1) & ~(it[1] - 1)
            elif k == 'fill':
                if it[1]:
                    lines.append('\t.fill %d, 2, 0x0001\t\t/* %d bytes */'
                                 % (it[1] // 2, it[1]))
                off += it[1]
        for name, _args, _addr in blk.globals:
            lines.append('\t.size  %s, . - %s' % (name, name))
        # End-of-block marker. A local `.L` label, so the assembler keeps it out
        # of the symbol table -- its only job is to give --check something to
        # compare after the LAST item of every block. Without it, a miscounted
        # intra-block .fill would go unnoticed whenever no label follows it: the
        # next block's own .balign silently absorbs the deficit.
        lines.append('.Lend_%s:' % blk.name)
        cur = blk.addr + blk.size
        lines.append('')

    # A 4 KB runtime code-generation buffer. It lives in this file rather than in
    # the C source so that linker_ifu.lcf can keep both pinned sections out of
    # the ordinary .text with one EXCLUDE_FILE clause.
    lines.append('/* ---- .text.jit : runtime code-generation buffer '
                 '(group 41, -DIFU_JIT) ---- */')
    lines.append('\t.section .text.jit, "ax", @progbits')
    lines.append('\t.balign 64')
    lines.append('\t.globl ifu_jit_buf')
    lines.append('ifu_jit_buf:')
    lines.append('\t.fill 2048, 2, 0x0001\t\t/* 4096 bytes of c.nop */')
    lines.append('\t.size  ifu_jit_buf, . - ifu_jit_buf')
    lines.append('')

    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    return lines, end


HDR_HEADER = """/*
 * ifu_arena.h -- GENERATED by tests/cases/ifu_random/gen_ifu_arena.py.
 * DO NOT EDIT.
 *
 * Declarations for the generated code arena plus one IFU_CALL_<FAMILY>(sel,...)
 * macro per family. The macros expand to a `switch` of direct calls on purpose:
 * a table of function pointers would be a computed jump through memory, and an
 * indirect jump used as a tail call stalls retirement on this RTL
 * (CLAUDE.md "Known Bugs"). The build also passes -fno-jump-tables so the
 * switch itself cannot become one.
 *
 *   arena 0x%08x .. 0x%08x   far stub 0x%08x   layout seed 0x%016x
 */

#ifndef IFU_ARENA_H
#define IFU_ARENA_H

#define IFU_ARENA_BASE   0x%08xUL
#define IFU_ARENA_END    0x%08xUL
#define IFU_ARENA_SIZE   0x%08xUL
#define IFU_ARENA_SEED   0x%016xUL

/* Page / line geometry the C side needs to build cache-maintenance addresses.
 * The I-cache is 32 KB, 2-way, 64 B lines, 256 sets, index VA[13:6]
 * (aq_ifu_icache.v:534-535), so 0x4000 is the alias stride. */
#define IFU_LINE_SIZE    64UL
#define IFU_ALIAS_STRIDE 0x4000UL
#define IFU_PAGE_SIZE    0x1000UL

/* The far stub, loaded by the testbench from input.pat at exactly 16 MB. The
 * RAS stores PC[23:0] only (aq_ifu_ras.v:53-58) and the predicted return is
 * {pred_idpc[39:24], ras_pred_tar_pc[23:0]} (aq_ifu_pred.v:656-657), so a call
 * from .text to here and its return can never both be predicted right. */
#define IFU_FAR_BASE     0x%08xUL
#define IFU_FAR_ENTRY0   0x%08xUL   /* nops + ret                     */
#define IFU_FAR_ENTRY1   0x%08xUL   /* nested far call, then ret      */
#define IFU_FAR_ENTRY2   0x%08xUL   /* nops + ret, different line     */
#define IFU_FAR_WORDS    %d

"""


def emit_header(ar, labels, seed, far_base, far_words, path):
    end = max(b.addr + b.size for b in ar.blocks)
    out = [HDR_HEADER % (ar.base, end, far_base, seed,
                         ar.base, end, ar.size, seed,
                         far_base, far_base, far_base + 0x10, far_base + 0x40,
                         far_words)]

    # Per-family grouping: a global's family is its name with the trailing
    # digits stripped.
    fams = {}
    order = []
    for blk in ar.blocks:
        for name, args, addr in blk.globals:
            fam = re.sub(r'\d+$', '', name)
            if fam not in fams:
                fams[fam] = []
                order.append(fam)
            fams[fam].append((name, args, addr))

    # Sort each family by name, not by address: the C side pairs
    # IFU_CALL_PFA(k) with IFU_CALL_PFB(k) and expects index k to mean the same
    # block in both, and a name-ordered header stays readable as the layout seed
    # changes.
    for fam in fams:
        fams[fam].sort(key=lambda m: m[0])

    out.append('/* ==== entry points ==== */\n')
    for fam in order:
        members = fams[fam]
        args = members[0][1]
        for name, a, addr in members:
            if a != args:
                die("internal: family %s has inconsistent prototypes" % fam)
        out.append('/* %s: %d entr%s */\n'
                   % (fam, len(members), 'y' if len(members) == 1 else 'ies'))
        for name, _a, addr in members:
            out.append('extern void %s(%s);\t/* 0x%08x */\n'
                       % (name, args if args else 'void', addr))
        out.append('\n')

    out.append('/* ==== counts ==== */\n')
    for fam in order:
        if len(fams[fam]) > 1:
            out.append('#define IFU_N_%-14s %du\n'
                       % (fam[len('ifu_blk_'):].upper(), len(fams[fam])))
    out.append('\n/* ==== dispatch macros (switch of direct calls) ==== */\n')
    for fam in order:
        members = fams[fam]
        if len(members) < 2:
            continue
        short = fam[len('ifu_blk_'):].upper()
        args = members[0][1]
        # Turn "unsigned long, volatile unsigned long *" into "a0, a1".
        nargs = 0 if not args else args.count(',') + 1
        params = ', '.join('a%d' % i for i in range(nargs))
        head = 'IFU_CALL_%s(sel%s)' % (short, (', ' + params) if params else '')
        out.append('#define %s \\\n' % head)
        out.append('    do { switch ((unsigned)(sel) %% %du) { \\\n' % len(members))
        for i, (name, _a, _addr) in enumerate(members):
            out.append('    case %du: %s(%s); break; \\\n' % (i, name, params))
        out.append('    default: break; } } while (0)\n\n')

    out.append('/* The runtime code-generation buffer (group 41). Emitted '
               'unconditionally so\n * linker_ifu.lcf always has a '
               '.text.jit to place. */\n')
    out.append('extern unsigned char ifu_jit_buf[4096];\n\n')
    out.append('#endif /* IFU_ARENA_H */\n')

    with open(path, 'w') as f:
        f.write(''.join(out))
    return fams, order


# ==================================================================== #
# Far stub
#
# Format is the inst.pat / data.pat vmem format produced by
# tests/bin/srec2vmem.py: one 32-bit word per line, 8 lowercase hex digits, and
# the LEFTMOST hex pair is the LOWEST byte address (tb.v writes patword[31:24]
# into SRAM byte lane 0). tb.v:126-130 $readmemh's input.pat into
# mem_input_temp[16384] and mem_nn_input_temp[8388608] and loads the latter at
# row offset 0x100000, i.e. byte address 0x0100_0000 = exactly 16 MB -- which is
# what makes the RAS's PC[23:0]-only storage mispredict on the way back.
#
# Exactly 16384 words: that fills mem_input_temp without over-running it (an
# over-length $readmemh is fatal under Verilator) and leaves the words past the
# stub defined as zero, so nothing in the neighbourhood reads X. Padding is zero
# rather than c.nop on purpose: a stray fetch traps at once instead of sliding
# 64 KB into memory the testbench never wipes.
# ==================================================================== #
FAR_WORDS = 16384


def build_far(far_base):
    half = {}                       # byte offset -> halfword

    def put(off, h, _txt=''):
        half[off] = h & 0xFFFF

    def putw(off, w, _txt=''):
        half[off] = w & 0xFFFF
        half[off + 2] = (w >> 16) & 0xFFFF

    # entry 0: the plain far callee
    put(0x0000, c_nop()[1])
    put(0x0002, c_nop()[1])
    put(0x0004, c_jr(RA)[1])

    # entry 1: a nested far call, so a call/return pair also happens entirely
    # above the 16 MB line. The jal sits at 2 mod 4 -- a straddling 32-bit
    # instruction in a non-cacheable-adjacent window, for free.
    put(0x0010, c_mv(T0, RA)[1])
    putw(0x0012, _enc_j(RA, 0x0030 - 0x0012))
    put(0x0016, c_mv(RA, T0)[1])
    put(0x0018, c_jr(RA)[1])
    put(0x0030, c_jr(RA)[1])

    # entry 2: a second plain callee one cache line further on
    put(0x0040, c_nop()[1])
    put(0x0042, c_nop()[1])
    put(0x0044, c_jr(RA)[1])

    words = []
    for w in range(FAR_WORDS):
        off = w * 4
        lo = half.get(off, 0)
        hi = half.get(off + 2, 0)
        words.append((hi << 16) | lo)
    edges = [(far_base + 0x0012, far_base + 0x0030, 'jal ra, far leaf', 'far')]
    return words, edges


def emit_far(words, path):
    with open(path, 'w') as f:
        for w in words:
            b = [(w >> 0) & 0xFF, (w >> 8) & 0xFF, (w >> 16) & 0xFF,
                 (w >> 24) & 0xFF]
            # leftmost hex pair = lowest byte address (srec2vmem.py:42)
            f.write('%02x%02x%02x%02x\n' % (b[0], b[1], b[2], b[3]))


# ==================================================================== #
# --check
# ==================================================================== #
SAFE_LO, SAFE_HI = 0x00000000, 0x00163830      # tb.v:98 wipes and loads this
APB_LO, APB_HI = 0x10000000, 0x1FFFFFFF        # AXI->AHB->APB: never fetch
ERR_LO = 0x20000000                            # error slave: zeros, rresp OKAY


def legal_fetch(addr, far_base, far_bytes):
    if SAFE_LO <= addr <= SAFE_HI:
        return True
    if far_base <= addr < far_base + far_bytes:
        return True
    if addr >= ERR_LO:
        return True
    return False


def reparse(lines):
    """Independently re-derive the byte layout from the emitted directives and
    return {label: offset}. This is the check that the model which computed the
    offsets and the text that the assembler will see agree; a mismatch means a
    .balign or .fill was mis-accounted, which is exactly the failure mode that
    would otherwise show up as a mysterious hang."""
    off = 0
    out = {}
    section = None
    incomment = False
    for raw in lines:
        for line in raw.split('\n'):
            if incomment:
                if '*/' in line:
                    line = line.split('*/', 1)[1]
                    incomment = False
                else:
                    continue
            while '/*' in line:
                head, rest = line.split('/*', 1)
                if '*/' in rest:
                    line = head + rest.split('*/', 1)[1]
                else:
                    line = head
                    incomment = True
                    break
            s = line.strip()
            if not s:
                continue
            if s.startswith('.section') or s.startswith('\t.section'):
                section = s.split()[1].rstrip(',')
                off = 0
                continue
            s = s.strip()
            # Labels are tested first: no directive ends in ':', but the
            # end-of-block markers are local `.L...:` labels and would otherwise
            # be swallowed by the "any other directive" arm below.
            if s.endswith(':'):
                if section == '.text.arena':
                    out[s[:-1]] = off
            elif s.startswith('.short'):
                off += 2
            elif s.startswith('.word'):
                off += 4
            elif s.startswith('.fill'):
                m = re.match(r'\.fill\s+(\d+)\s*,\s*(\d+)\s*,', s)
                if not m:
                    die("--check: cannot parse %r" % s)
                off += int(m.group(1)) * int(m.group(2))
            elif s.startswith('.balign'):
                a = int(s.split()[1])
                off = (off + a - 1) & ~(a - 1)
            elif s.startswith('.'):
                pass                       # .option/.globl/.type/.size
            else:
                die("--check: unexpected line %r" % s)
    return out


def check(ar, labels, edges, far_base, far_bytes, lines, fams):
    errs = []

    # 1/2. fetch-window legality of every emitted target
    for (pc, dst, txt, blk) in edges:
        if APB_LO <= dst <= APB_HI:
            errs.append("%s: %s targets the APB window 0x%08x -- an I-cache "
                        "refill there is a 4-beat WRAP burst axi2ahb cannot "
                        "service" % (blk, txt, dst))
        elif not legal_fetch(dst, far_base, far_bytes):
            errs.append("%s: %s targets 0x%08x, which is not a legal fetch "
                        "window (0x0..0x%x, the input.pat window, or >=0x%x)"
                        % (blk, txt, dst, SAFE_HI, ERR_LO))
        if APB_LO <= pc <= APB_HI or not legal_fetch(pc, far_base, far_bytes):
            errs.append("%s: %s is itself at an unfetchable 0x%08x"
                        % (blk, txt, pc))

    # 3. every group-20 branch has a unique PC[15:0]: the BTB tags with
    #    PC[15:0] only (aq_ifu_btb.v:154), so two of them aliasing would quietly
    #    turn the 16-entry fill into a 15-entry one.
    seen = {}
    for (pc, dst, txt, blk) in edges:
        if not blk.startswith('btb'):
            continue
        if not (txt.startswith('bne') or txt.startswith('beq')):
            continue
        low = pc & 0xFFFF
        if low in seen:
            errs.append("group 20: branches in %s and %s share PC[15:0]=0x%04x"
                        % (seen[low], blk, low))
        seen[low] = blk
    if len(seen) < 16:
        errs.append("group 20: only %d distinct BTB branch PC[15:0] values; "
                    "the BTB has 16 entries" % len(seen))

    # 4. byte accounting: re-parse the emitted text and compare EVERY label,
    #    local ones included. The locals are what actually exercise the
    #    .balign / .fill accounting, because they are the only labels that sit
    #    after an internal alignment request -- and a two-byte miscount there
    #    would silently move a branch off its 4-byte fetch group, which is the
    #    entire mechanism groups 25, 34 and 35 depend on.
    parsed = reparse(lines)
    model = {}
    for blk in ar.blocks:
        for name, addr in blk.labels.items():
            key = name if name.startswith('ifu_') else '%s_%s' % (blk.name, name)
            model[key] = addr
        for name, _args, addr in blk.globals:
            model[name] = addr
        model['.Lend_%s' % blk.name] = blk.addr + blk.size
    for name in sorted(model):
        if name not in parsed:
            errs.append("byte accounting: label %s missing from the emitted "
                        "assembly" % name)
        elif ar.base + parsed[name] != model[name]:
            errs.append("byte accounting: %s modelled at 0x%08x, emitted text "
                        "puts it at 0x%08x"
                        % (name, model[name], ar.base + parsed[name]))

    # 5. the arena fits, blocks are aligned, and nothing falls off its end
    end = max(b.addr + b.size for b in ar.blocks)
    if end > ar.base + ar.size:
        errs.append("arena ends at 0x%08x, past --arena-size (0x%08x)"
                    % (end, ar.base + ar.size))
    for blk in ar.blocks:
        if blk.addr & (blk.balign - 1):
            errs.append("%s at 0x%08x violates its balign %d"
                        % (blk.name, blk.addr, blk.balign))
        if not blk.terminated():
            errs.append("%s does not end in a control transfer, so it would "
                        "slide into the next block" % blk.name)

    # 6. the 16 KB-stride blocks really do share an I-cache set
    conf = sorted(a for n, a in labels.items() if n.startswith('ifu_blk_conf'))
    if len(conf) < 3:
        errs.append("group 7 needs at least 3 aliasing blocks, found %d"
                    % len(conf))
    idx = set(((a >> 6) & 0xFF) for a in conf)
    if len(idx) != 1:
        errs.append("group 7: conflict blocks land in %d different I-cache "
                    "sets (VA[13:6] = %s), so they never evict each other"
                    % (len(idx), sorted('0x%02x' % i for i in idx)))
    # The entry offset IS the coverage: addr[5:4] is req_cnt (the
    # critical-word-first counter, aq_ifu_icache.v:974-980) and addr[3:2] is
    # refill_bankN_sel (the bypassed word of the first beat, :1004-1007). An
    # offset formula that quietly collapses either field would leave those bins
    # untoggled with nothing to say so.
    rq = set(((a >> 4) & 3) for a in conf)
    bk = set(((a >> 2) & 3) for a in conf)
    if len(rq) != 4:
        errs.append("group 7: conflict-block entry offsets cover only %d of the "
                    "4 req_cnt bins (addr[5:4] = %s)"
                    % (len(rq), sorted(rq)))
    if len(bk) != 4:
        errs.append("group 7: conflict-block entry offsets cover only %d of the "
                    "4 refill_bank bins (addr[3:2] = %s)"
                    % (len(bk), sorted(bk)))

    # 7. the alias pair is exactly 64 KB apart
    lo = labels.get('ifu_blk_alias_lo')
    hi = labels.get('ifu_blk_alias_hi')
    if lo is None or hi is None:
        errs.append("group 22: the alias pair is missing")
    elif hi - lo != 0x10000:
        errs.append("group 22: alias pair is 0x%x apart, not 0x10000"
                    % (hi - lo))

    # 8. the cross-64 KB branch really does cross
    for (pc, dst, txt, blk) in edges:
        if blk == 'x64k' and txt.startswith('bne'):
            if (pc >> 16) == (dst >> 16):
                errs.append("group 22a: the branch at 0x%08x and its target "
                            "0x%08x are in the same 64 KB block" % (pc, dst))

    # 9. >= 16 distinct 4 KB pages of code, for the 10-entry I-uTLB
    pages = set((a >> 12) for n, a in labels.items() if n.startswith('ifu_blk_'))
    if len(pages) < 16:
        errs.append("only %d distinct 4 KB code pages; the I-uTLB has 10 "
                    "entries, so forcing multi-cycle translations needs >= 16"
                    % len(pages))

    if errs:
        for e in errs:
            sys.stderr.write("gen_ifu_arena.py: CHECK FAILED: %s\n" % e)
        sys.exit(1)

    sys.stderr.write(
        "gen_ifu_arena.py: check OK -- %d blocks, %d entries, %d transfers, "
        "%d code pages, arena 0x%08x..0x%08x (%d of 0x%x bytes)\n"
        % (len(ar.blocks), sum(len(b.globals) for b in ar.blocks), len(edges),
           len(pages), ar.base, end, end - ar.base, ar.size))


# ==================================================================== #
# main
# ==================================================================== #
def main():
    ap = argparse.ArgumentParser(
        description='generate the ifu_random code arena, its C header and the '
                    'far-stub pattern file')
    ap.add_argument('--seed', required=True,
                    help='PRNG seed for the CODE LAYOUT (accepts 0x...)')
    ap.add_argument('--arena-base', required=True,
                    help='absolute address the arena is pinned at by '
                         'linker_ifu.lcf')
    ap.add_argument('--arena-size', required=True,
                    help='byte budget for the arena')
    ap.add_argument('--out-s', required=True, help='assembly output')
    ap.add_argument('--out-h', required=True, help='C header output')
    ap.add_argument('--out-far-pat', required=True,
                    help='far-stub pattern file (becomes work/input.pat)')
    ap.add_argument('--far-base', default='0x01000000',
                    help='address the testbench loads input.pat at')
    ap.add_argument('--check', action='store_true',
                    help='verify every layout invariant and exit non-zero on '
                         'any violation')
    args = ap.parse_args()

    seed = int(args.seed, 0)
    base = int(args.arena_base, 0)
    size = int(args.arena_size, 0)
    far_base = int(args.far_base, 0)

    if far_base != 0x01000000:
        sys.stderr.write("gen_ifu_arena.py: warning: --far-base 0x%08x is not "
                         "the 16 MB boundary tb.v loads input.pat at; group 32 "
                         "needs exactly 0x01000000 to cross the RAS's "
                         "PC[23:0] horizon\n" % far_base)

    rng = Rng(seed)
    ar = build_arena(rng, base, size)
    labels, edges = resolve(ar)
    lines, _end = emit(ar, seed, args.out_s)
    far_words, far_edges = build_far(far_base)
    emit_far(far_words, args.out_far_pat)
    fams, _order = emit_header(ar, labels, seed, far_base, FAR_WORDS,
                               args.out_h)

    if args.check:
        check(ar, labels, edges + far_edges, far_base, FAR_WORDS * 4, lines,
              fams)
    return 0


if __name__ == '__main__':
    sys.exit(main())
