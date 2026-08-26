# Run log — per-unit randomized stress tests

Append-only. One record block per sign-off run, in the format defined by
`doc/specs/unit-random-tests.md` Part 0 §6. The two fields people forget are the
**simulator version** (Verilator and VCS toggle numbers are not comparable — the
accumulate guard is whole-port, so one permanently-X bit zeroes a whole port
under 4-state) and the **full toolchain plus `-O` and `-march`** (the same seed
under Xuantie GCC and upstream GCC is a *different* stimulus).

---

## R001 — reference measurement: what a real workload already reaches

The baseline every randomized case is scored against. Not a randomized case
itself: one `coremark` iteration, with all five per-unit monitors compiled in and
line coverage on.

```
case            : coremark (ITERATIONS=1, core_portme.c:25)
rtl commit      : (unchanged from HEAD at the time of this work)
simulator       : Verilator 5.048 2026-04-26 rev v5.048-56-gc233a3905
host            : macOS 25.5.0 arm64, VL_JOBS=10 VL_THREADS=1
toolchain       : xPack riscv-none-elf-gcc 15.2.0 via ~/tools/riscv-wrap,
                  THEAD_GCC=0, CPU_ARCH_FLAG_0=c906fd,
                  -march=rv64imafdc_zfh_zicsr_zifencei -mabi=lp64d -O3
                  (coremark's own flags)
invocation      : make runcase CASE=coremark SIM=verilator DUMP=off \
                             MON=all COVERAGE=line
DUMP / COVERAGE : off / line
result          : TEST PASS  ("simulation finished successfully")
cost            : 782 us simulated, 28.7 s wall, 27.3 us/s
                  (elaboration + C++ build 26.5 s separately)
```

Port toggle, from a real workload:

| unit | functional ports toggled |
|---|---|
| cp0 | 93/201 |
| iu | **105/115** |
| vidu | 39/48 |
| idu | 98/127 |
| ifu | 80/107 |

Line and branch coverage (`cov_report.py`, saved to
`unit_coverage_baseline.json`):

| unit | line | branch |
|---|---|---|
| ifu | 346/372 93.0% | 262/282 92.9% |
| idu | 896/1096 81.8% | 97/142 68.3% |
| iu | **264/569 46.4%** | 186/210 88.6% |
| vidu | 255/264 96.6% | 25/34 73.5% |
| cp0 | 278/531 52.4% | 68/112 60.7% |

### What this reference immediately tells us

**Port toggle is a weak metric for a datapath unit, and now we can prove it.**
One coremark iteration already toggles 105 of the IU's 115 functional ports —
while covering only 46.4% of the IU's lines. The ports are mostly wide operand
and result buses that move on the first instruction; they say almost nothing
about whether the shifter's 64 mask arms or the divider's special-case matrix
were ever entered. This is exactly why code coverage was added alongside the
toggle monitors rather than instead of them, and it is the strongest single
argument for reading `make covreport` and not the toggle summary when judging a
randomized case.

**The cold lines are precisely the ones the plan targets.** `--top-cold` on this
reference run names, in order:

| file | uncovered | first uncovered lines |
|---|---|---|
| `gen_rtl/iu/rtl/aq_iu_alu.v` | 236/340 | 333, 361, 402, 403, 405, 411, 413, 414, 417, 418, … |
| `gen_rtl/idu/rtl/aq_idu_id_decd.v` | 180/726 | 405, 559, 560, 627, 672, 694, 1199, 1221, 1299, 1355, … |
| `gen_rtl/cp0/rtl/aq_cp0_regs.v` | 93/112 | 976, 992, 1012, 1045, … |
| `gen_rtl/cp0/rtl/aq_cp0_trap_csr.v` | 76/184 | 547, 577, 605, 607, … |
| `gen_rtl/iu/rtl/aq_iu_div.v` | 68/186 | 209, 222, 288, 290, 300, 302, 309, 384, 385, 386, … |
| `gen_rtl/idu/rtl/aq_idu_id_split.v` | 53/147 | 202, 206, 207, 235, 246, 252, 274, 283, 289, 394, … |

Line 333 and 361 of `aq_iu_alu.v` are the `alu_shift_input_127_64` and
`alu_shift_input_63_0` case arms; 402-418 are inside the 64-arm
`alu_shifter_extu_mask` case. 384-386 of `aq_iu_div.v` are the special-case
result muxes. 202-289 of `aq_idu_id_split.v` are the LSD cracking FSM and 394 is
the AMO_IDLE priority chain. Those are, respectively, `iu_random` groups 5-7,
group 24, and `idu_random` groups 18-20 — the taxonomy was derived from the RTL
independently, and the reference run confirms those arms are genuinely cold.

Note the two CP0 files in that list: `cp0_random` was not the case being run
here. They are cold *for coremark*, not cold in general — R002 below is the
comparison.

### Ports a real workload never touches, and which case should reach them

Triaged from the `NEVER TOGGLED` lines of the five reference reports. This is the
target list: a port in the middle column should move once the named group runs,
and a port in the right column should be expected to stay at zero forever.

| unit | reachable by a new group (group #) | permanently dead, and why |
|---|---|---|
| **iu** | `hpcp_iu_cnt_en` (39), `iu_hpcp_jump_8m` (40, gated), `iu_idu_mult_full` (20), `rtu_iu_div_wb_grant_for_full` (26), `idu_iu_ex1_split` / `rtu_iu_ex1_inst_split` / `iu_rtu_ex1_alu_inst_split` (via `idu_random` 18-22, which is what produces split uops), `cp0_iu_icg_en` (an `mhint2` bit-16 write gates the IU clocks) | `cp0_xx_mrvbr` (tied to `biu_cp0_rvba`), `mmu_xx_mmu_en` (needs `satp` != Bare, i.e. `IFU_MMU` or the `MMU` case) |
| **idu** | `hpcp_idu_cnt_en` (44), `cp0_idu_frm` (6), `ifu_idu_id_expt_acc_error` / `_expt_high` (via `ifu_random` 17-18), `idu_cp0_ex1_expt_acc_error` / `_expt_high` (same), `idu_{cp0,iu,lsu}_ex1_split` (18-22), `iu_idu_mult_full` (`iu_random` 20) | the whole `cp0_idu_v*` family — `vill`, `vl_zero`, `vlmul`, `vs`, `vsetvl_dis_stall`, `vsew`, `vstart` — plus `idu_vidu_ex1_vec_*`, `idu_lsu_ex1_vlmul/vsew` and `vidu_idu_vec_full`: the vector decoder is tied off. `rtu_yy_xx_dbgon`, `cp0_idu_dis_fence_in_dbg`, `ifu_idu_id_halt_info` need JTAG. `*_expt_page_fault` needs Sv39 (`IDU_MMU`) |
| **ifu** | `cp0_ifu_iwpe` (6), `cp0_ifu_lpmd_req` (4), `cp0_ifu_icache_inv_type` (13-15), `cp0_ifu_icache_read_{req,tag,way,index}` + `ifu_cp0_icache_read_data_vld` (16), `mmu_ifu_access_fault` (17), `ifu_idu_id_expt_acc_error` / `_expt_high` (17-18), `hpcp_ifu_cnt_en` (with counters on) | `biu_ifu_rresp` — **no AXI error response exists on this SoC** (`axi_err128.v:211` returns `2'b00`), so this and `refill_error`/`pf_err_ff` are unreachable by construction. `dtu_ifu_*`, `dtu_ifu_halt_on_reset`, `rtu_ifu_dbg_mask`, `rtu_yy_xx_dbgon`, `ifu_rtu_reset_halt_req` need JTAG. `ifu_biu_arprot`/`arsize` are constants. `_expt_page_fault` needs `IFU_MMU` |
| **vidu** | `vpu_vidu_vex1_fp_stall` (12), `vidu_vpu_vid_fp_inst_srcf2_rdy` (2 / 38 — the FMA and FP-store third operand), `rtu_yy_xx_async_flush` (29) | `idu_vidu_ex1_vec_{sel,dp_sel,gateclk_sel}`, `vidu_idu_vec_full`, `vidu_cp0_vid_fof_vld` — the vector side of `aq_vidu_top.v` is a tie-off block |

Two things worth noticing in that table. First, several of the IU's and IDU's
never-toggled ports are `*_split` signals, which no `iu_random` group can produce
on its own — they come from the IDU's instruction-cracking FSMs, so `idu_random`
groups 18-22 are what light them up. Coverage of one unit genuinely depends on
another unit's test. Second, `vpu_vidu_vex1_fp_stall` and
`vidu_vpu_vid_fp_inst_srcf2_rdy` being cold after a full coremark iteration is
direct evidence for the `vidu_random` design premise: real code does not stress
the FP issue queue's stall and third-operand paths at all.

---

## R002 — `cp0_random` after the monitor-generator refactor

Purpose: prove that renaming `gen_cp0_toggle_mon.py` to `gen_toggle_mon.py`,
parameterising the hierarchy macro, adding the `` `undef `` and adding the
`x_cycles` column did not change what the monitor measures. The committed
baseline to match is `doc/results/cp0_toggle_baseline.report`: **169/201
functional ports, `recovered=0`**.

```
case            : cp0_random
simulator       : Verilator 5.048 2026-04-26 rev v5.048-56-gc233a3905
host            : macOS 25.5.0 arm64, VL_JOBS=10 VL_THREADS=1
toolchain       : xPack riscv-none-elf-gcc 15.2.0, THEAD_GCC=0, c906fd, -O2
invocation      : make runcase CASE=cp0_random SIM=verilator DUMP=off \
                             MON=all COVERAGE=line
knobs           : CP0_ITERS=100000 CP0_SEED=0x2024C906
result          : TEST PASS
toggle          : 169/201 functional CP0 ports toggled  <-- MATCHES THE BASELINE
X-SEEN          : 0 functional ports (expected: Verilator runs --x-assign fast)
cost            : 52 ms simulated, 1768 s wall, 29.7 us/s
uart summary    : [cp0_random] iters=100000 mtraps=63197 straps=4776 recovered=0
                  M causes: 2=29913 3=1559 4=3803 6=803 8=4659 9=9569 11=1545
                  M ints:   1=770 3=278 5=7412 7=257 9=800 11=272 17=1557
                  S causes: 2=3183 i5=1593
                  all 42 group counters non-zero; main rotation ~3100 each,
                  sparse ~1550 each, as expected for r%32 and (r>>32)%64
```

**Verdict: the monitor-generator refactor is safe.** 169/201 and `recovered=0`
reproduce `cp0_toggle_baseline.report` exactly.

One honest discrepancy: `mtraps` is 63197 here against 63243 in
`cp0-design-and-test.md` §23, and the whole difference is in cause 2
(illegal instruction): 29913 versus 29959, 46 fewer. Every other cause and every
interrupt count is identical, `recovered` is 0 in both, and the toggle result is
unchanged. The likely explanation is that a few groups branch on a real-time
counter (`mcycle`/`time`/`mcpuid`, whose index self-increments per read) rather
than purely on the seeded random word, so the *number* of illegal probes shifts
slightly when simulation timing changes — and this run added five monitors and
coverage instrumentation. It does not affect the refactor verdict, but it does
mean the trap histogram is not a bit-exact regression signal the way the toggle
count is. Worth confirming before anyone treats a small histogram delta as a
finding.

Cost note, useful for planning: the same 100K-iteration run is documented at
441 s wall without coverage and with one monitor; here it took 1768 s with
`COVERAGE=line` **and** `MON=all`, i.e. about **4x**. That is consistent with the
~2x estimated for line coverage and ~2x for sampling ~600 ports instead of 204
every posedge. Both are measurement-only configurations; long soaks should run
neither.

### Coverage: what one randomized unit test is worth

`cov_report.py` summing `coremark.dat` + `cp0_random.dat` against the R001
baseline (which is coremark alone):

| unit | line | Δline vs coremark | branch | Δbranch |
|---|---|---|---|---|
| cp0 | 504/531 **94.9%** | **+42.6 pt** | 97/112 86.6% | +25.9 pt |
| idu | 975/1096 89.0% | +7.2 pt | 109/142 76.8% | +8.5 pt |
| ifu | 361/372 97.0% | +4.0 pt | 278/282 98.6% | +5.7 pt |
| iu | 294/569 51.7% | +5.3 pt | 186/210 88.6% | +0.0 pt |
| vidu | 255/264 96.6% | +0.0 pt | 25/34 73.5% | +0.0 pt |

This is the number that justifies the whole approach: a randomized test aimed at
one unit moved that unit's line coverage from 52.4% to 94.9%. It also shows the
shape to expect from the other three — a large jump in the targeted unit, a
useful side-effect gain in IDU and IFU (every test drives fetch and decode), and
**nothing at all** in the units it does not touch. `iu` at 51.7% and `vidu` at
96.6%-line-but-73.5%-branch are the standing gaps that `iu_random` and
`vidu_random` exist to close; note the IU's branch coverage did not move at all,
which is what an untargeted unit looks like.

---

## R003 — first end-to-end run of all four cases, 200 iterations each

Not a sign-off run. This is the bring-up measurement: does each case build, run
to completion, and move its unit? Deliberately tiny iteration counts so all four
could be measured in about a minute of simulation each.

```
simulator       : Verilator 5.048, macOS 25.5.0 arm64
toolchain       : xPack riscv-none-elf-gcc 15.2.0, THEAD_GCC=0, c906fd, -O2
model built with: MON=all COVERAGE=line   (all five monitors + line coverage)
invocation      : make buildcase CASE=<case> <U>_ITERS=200
                  cd work && ./simv +MAX_SIM_TIME=<2e7|4e7>
```

| case | result | sim time | wall | cycles/iter | .text+.rodata | recovered |
|---|---|---|---|---|---|---|
| `iu_random` | **TEST PASS** | 122 us | 5.2 s | ~610 | 16.3 KB | 0 |
| `vidu_random` | **TEST PASS** | 188 us | 7.2 s | ~940 | 45 KB | 0 |
| `idu_random` | **TEST PASS** | 361 us | 12.4 s | ~1805 | 22 KB | 0 |
| `ifu_random` | **TEST PASS** | 594 us | 20.0 s | ~2970 | 209 KB (188 KB of it the generated arena) | 0 |

`ifu_random`'s section layout, which is the part most likely to go wrong
silently, came out exactly as intended:

```
.text          16064 @ 0x00000    (fits below the pinned arena at 0x8000)
.text.arena   188416 @ 0x08000    (generator: 130 blocks, 35 code pages,
                                   188416 of 0x30000 bytes, --check OK)
.text.jit       4096 @ 0x36000
.rodata          396 @ 0x37000    (all of MEM1 used, nothing past 0x40000)
.data              6 @ 0x40000
.bss            6800 @ 0x40040    (ends 0x41A90, far below the 0x80000 ASSERT)
input.pat      16384 words        (exactly fills mem_input_temp; one word more
                                   would be a fatal $readmemh under VCS)
```

Port toggle, per case, against the coremark reference:

| unit | coremark | iu_random | vidu_random | idu_random | ifu_random | cp0_random |
|---|---|---|---|---|---|---|
| cp0 | 93 | 103 | 111 | 120 | 117 | **169** |
| iu | 105 | **107** | 103 | 109 | 109 | 108 |
| vidu | 39 | 16 | **40** | 41 | 16 | 39 |
| idu | 98 | 97 | 99 | **105** | 99 | 105 |
| ifu | 80 | 80 | 79 | 85 | **90** | 89 |

(Bold is each case's own unit. The numbers barely move, which is the point made
in R001: interface toggle saturates almost immediately and is a poor scorecard.
Read the coverage table below instead.)

### Coverage: all four merged with coremark, versus coremark alone

| unit | line | Δ line | branch | Δ branch |
|---|---|---|---|---|
| iu | 513/569 **90.2%** | **+43.8** | 204/210 97.1% | +8.6 |
| vfalu | 221/410 53.9% | **+26.3** | 561/576 97.4% | +17.0 |
| cp0 | 405/531 76.3% | +23.9 | 90/112 80.4% | +19.6 |
| vfmau | 141/317 44.5% | +23.0 | 90/104 86.5% | +10.6 |
| vfdsu | 182/367 49.6% | +16.1 | 228/246 92.7% | **+30.5** |
| idu | 1038/1096 **94.7%** | +13.0 | 120/142 84.5% | +16.2 |
| vdiv | 10/11 90.9% | +9.1 | — | — |
| vdsp | 56/64 87.5% | +7.8 | 63/84 75.0% | +4.8 |
| ifu | 361/372 **97.0%** | +4.0 | 279/282 **98.9%** | +6.0 |
| vidu | 255/264 96.6% | +0.0 | 25/34 73.5% | +0.0 |
| **TOTAL** | 3182/4001 79.5% | | 1660/1790 92.7% | |

Notes on reading this:

- **`iu_random` is the standout**: +43.8 points of IU line coverage from *200
  iterations*, and it took `aq_iu_alu.v` and `aq_iu_div.v` off the top-cold list
  entirely. Measured alone it reaches 88.8% line / 96.7% branch on the IU.
- **`vidu_random`'s +0.0 on `vidu` is not a failure** — see
  `doc/specs/unit-random-tests.md` Part II. `gen_rtl/vidu/` is 264 line points
  and coremark already covers 96.6% of them; the FP rows above are where that
  case's work shows up. This is why `cov_report.py`'s default unit list now
  includes `vdsp/vfalu/vfmau/vfdsu/vdiv`.
- **`ifu_random`'s +4.0 looks small because the IFU starts at 93.0%** — real code
  fetches instructions, so a real workload covers the front end well. Its branch
  coverage reaching 98.9% and its toggle going 80 → 90 are the better signals,
  and the 11 lines still uncovered are the JTAG and AXI-error paths that Part IV
  lists as unreachable.
- Per-case deltas measured *alone* against a coremark baseline show negatives on
  units the case does not touch. That is two different workloads, not a
  regression; only the merged column above is a fair comparison.

### What the adversarial review pass changed

Each case was written by one agent and then reviewed by a second one whose brief
was to recompute every raw encoding from the decode tables, re-run the compile
matrix, and hunt for groups that only *look* implemented. Every case came back
with real defects. The classes worth remembering:

**A. Degenerate sub-case selectors — the most damaging, and completely silent.**
The main rotation is `g = r % 32`, so bits [4:0] of `r` are pinned for the
lifetime of a main-rotation group. A selector like `(r >> 3) & 3` is therefore
bits [4:3] — a constant, one arm out of four, forever. In `vidu_random` this
collapsed **nine groups to a single arm each**, left two of eight
reserved-rounding-mode raw encodings permanently unexecuted (the two values
group 26 exists to test), and made group 29's "roughly half of these mispredict"
branch perfectly predictable because its condition was `r & 1`. The review
proved it by running the real xorshift64 from the real seed and printing the
reachable arm set per group, then moved 30 selectors to `>> 5`.

Auditing the other three found **37 more sites in `idu_random`** (`(r >> 3)` for
operand-pool and pointer selection, so bits [3:4] of every pool index were
pinned) and 3 in `iu_random`. All now shift by at least 5. Verified rather than
argued: simulating 400 000 iterations of the actual PRNG shows that for every
main group 0..31 and every sparse arm 0..13, `(r >> 5) % N` reaches **all** N
residues for N ∈ {2,3,4,5,6,8,10,12,24}. Written up as rail 11 in
`doc/specs/unit-random-tests.md` Part 0 §5.

**B. Wrong raw encodings that silently test nothing.** `idu_random` group 0 case
7 used `0x2000` believing it was a reserved quadrant-0 funct3; it is
`inst[15:13]==3'b001`, the legal `c.fld` arm. The group took **0**
illegal-instruction traps before the fix and **16** after — the reviewer measured
it rather than reasoning about it. `0x8000` is the encoding with no arm in the
`casez`.

**C. Groups that were stubs behind a default-off gate.** `idu_random`'s ZVAMO
group reported PASS while never executing. The review proved the feared hang does
not exist — opcode `0101111` with funct3 110/111 matches no arm in the 32-bit
table, so `decd_32_illegal` fires *upstream* of the splitter and the disabled-unit
dispatch never happens — measured 400/400 iterations to a clean cause-2 trap, and
ungated it.

**D. Coverage claims that did not hold.** `ifu_random`'s I-cache conflict family
claimed all four `refill_bank` bins; the offset formula only ever produced two of
them, so banks 2 and 3 were never entered. Replaced with an explicit
`(req_cnt, bank)` table and a `--check` assertion that negative-tests correctly.
`ifu_random` group 30 entered its RAS chain at the leaf instead of the head, and
group 19 incremented a hit counter for a compiled-out group — which is exactly the
signal `report()` exists to provide.

**E. Two defects in work I had done myself.**
- My `linker_ifu.lcf` pinned the arena with `. = 0x8000;` before a section
  assigned to `>MEM1`. **A location-counter assignment is ignored for an output
  section that names a memory region** — the link succeeds, the arena lands
  wherever `.text` ended, and every address-derived coverage point silently stops
  working while the test still passes. Replaced with an explicit section address
  plus three ASSERTs. My separate `ASSERT(end <= 0x80000)` for the `input.pat`
  shadow survived and is still needed.
- My `rand_th_insn.h` said Xtheadc store data comes from `inst[24:20]`. It comes
  from `inst[11:7]`: `decd_inst_src2_reg_32bit_24_20`
  (`aq_idu_id_decd.v:699-700`) matches only opcodes `0100011`/`0100111`, so for
  `0001011` the `..._11_7` term wins. `idu_random` followed the RTL rather than my
  comment; `iu_random` and `vidu_random` emit no Xtheadc stores at all, so nothing
  was built on it. Comment corrected.

And one claim in the plan that was simply wrong, now corrected in the spec: arm
`5'b01000` of the two ALU adder one-hot muxes is **not** unreachable.
`alu_func[16]` is `alu_shift_high_zero` as well as the min/max select, so every
left shift takes that arm. See Part I of the spec for why "only instruction X sets
this bit" is a claim about the whole encoding table, not one sub-unit.

---

## R004 — per-group bisect: 174/174 groups PASS

The gating criterion. Each group run in isolation via
`tests/cases/<case>/run_groups.sh`, i.e. `-D<U>_ONLY_GROUP=n` at 40 iterations
with a deliberately short `+MAX_SIM_TIME`, so a stall shows up as
`HANG (retire watchdog)` and a livelock as `TIMEOUT` rather than as a mystery
inside a long mixed run.

| case | groups | result |
|---|---|---|
| `iu_random` | 0-43 (44) | **all PASS** |
| `vidu_random` | 0-41 (42) | **all PASS** |
| `idu_random` | 0-45 (46) | **all PASS** |
| `ifu_random` | 0-41 (42) | **all PASS** |

No `HANG`, no `TIMEOUT`, no `BUILD-FAIL`, no `FAIL`. That includes every group the
plan flagged as fragile: `iu_random` 33 `div_flush` (the DIV FSM has no flush
term, so a wrong-path divide runs to completion), 40 `jump8m` (the runtime-built
far trampoline), `vidu_random` 32 `fs_off` (where even `csrr fcsr` is illegal),
`idu_random` 45 `zvamo_negative`, and `ifu_random` 2 `high_pc`, 17
`ifetch_accfault`, 18 `expt_high`, 19 `sv39_ifetch` and 41 `jit`.

## R005 — calibrated runs at the committed defaults

Run as `make runcase CASE=<case> SIM=verilator DUMP=off COVERAGE=line`, so the
wall times below carry the coverage penalty (roughly 2x) and the plain-config
figure is about half.

### `iu_random`, `IU_ITERS=16000` — TEST PASS, 157 s wall

```
iters=16000 sweeps=5491 mulops=11131 divops=24697 brexecs=40613
hpm3(condbr)=444838 hpm4(mispred)=119810 hpm5(iu_issue)=1635453 hpm6(evt40)=284553
mtraps=218 straps=0 nested=0 faultret=0 recovered=0
M causes: 2=164 11=54
groups: all 44 non-zero -- main rotation 443..544 each, sparse 218..283 each
toggle: 105/115 functional IU ports
```

The HPCP counters are the useful part: 444 838 conditional branches retired with
119 810 BHT mispredictions (a 27% mispredict rate, which is what an
LFSR-driven direction stream should look like) and 1.64 M ALU/MULT/DIV issues.
`recovered=0` and `nested=0` mean no group ever needed the unwind path. The only
traps are the deliberate ones: 164 illegal instructions and 54 ecalls.

**The port-toggle result refutes my own prediction table above, and the reason is
instructive.** `iu_random`'s `NEVER TOGGLED` list is *byte-identical* to
coremark's — the same ten ports — even though the case took IU line coverage from
46.4% to 88.8%. Going through them one by one:

| port | I predicted | actually |
|---|---|---|
| `hpcp_iu_cnt_en` | group 39 would toggle it | **constant, not unreachable** — and the reason turned out to be privilege mode, not what I first guessed. `hpcp_iu_cnt_en` and `hpcp_idu_cnt_en` are literally the same expression (`aq_hpcp_top.v:2693,2698`, both `= hpcp_xx_cnt_en = debug_mode_en && !cnt_mode_dis`), and `cnt_mode_dis` is `(priv==M && pmdm) \|\| (priv==S && pmds) \|\| (priv==U && pmdu)`. So it moves only when the privilege mode changes or a `mxstatus` PMD bit is written. `iu_random` never leaves M mode, so it holds constant; `idu_random` does 327 privilege round trips and **did** toggle it (see R005). The counters worked in both cases — 444 838 branches were counted. My first explanation ("stuck at 1 because M mode") was the right shape but the wrong mechanism, and it was falsifiable in one grep. |
| `iu_hpcp_jump_8m` | group 40 | group 40 is behind `IU_ENABLE_JUMP8M`, **default off**. My table should have said "gated", not "reachable". |
| `iu_idu_mult_full`, `rtu_iu_div_wb_grant_for_full` | groups 20, 26 | **not achieved.** Both need a cycle-exact writeback-port collision; issuing back-to-back long-latency ops is necessary but not sufficient. Genuine remaining gap. |
| `idu_iu_ex1_split`, `rtu_iu_ex1_inst_split`, `iu_rtu_ex1_alu_inst_split` | via `idu_random`'s cracking FSMs | correct, but **unmeasurable this way**: a per-case run compiles only that case's monitor, so an `idu_random` run cannot report IU ports. Needs `MON=all`. |
| `cp0_iu_icg_en` | via an `mhint2` write | correct — `iu_random` has no `mhint2` group; that is `cp0_random` group 12. |
| `cp0_xx_mrvbr`, `mmu_xx_mmu_en` | dead | correct. |

Two lessons, both worth carrying into how these reports are read:

1. **"Never toggled" conflates "never asserted" with "constantly asserted".** The
   monitor records transitions, not values, so a tied-high enable and a dead
   output look the same. `hpcp_iu_cnt_en` is the example. Adding a final-value
   column to `gen_toggle_mon.py` would fix this and is the obvious next
   improvement; it was not done here because it would invalidate the baselines
   captured in this log.
2. **Cross-unit coverage needs `MON=all`.** Three of the IU's cold ports are
   driven by the IDU's instruction-cracking FSMs, so no amount of `iu_random`
   will move them and no per-case run can even observe them moving.

### `vidu_random`, `VIDU_ITERS=10000` — TEST PASS, 198 s wall

```
iters=10000 regs=0xffffffff fflags_seen=0x1f fs_seen=0x6000
rm_illegal=295 frm_illegal=126 fsoff=146 wfi=133
mtraps=1183 straps=0 nested=0 faultret=0 recovered=0
M causes: 2=926 11=257
groups: all 42 non-zero -- main 275..351, sparse 133..184
toggle: 40/48 functional VIDU ports
```

Three self-reported invariants worth having: **`regs=0xffffffff` — all 32 FP
registers were exercised** (the 200-iteration run reached only 30, so the sweep
needs volume); `fflags_seen=0x1f` — every one of NX/UF/OF/DZ/NV was raised by
construction; `fs_seen=0x6000` — `mstatus.FS` reached Dirty, so the
`vpu_rtu_ex1_fp_dirty` path fired. The 926 illegal-instruction traps are the
reserved-rounding-mode encodings (295), the bad-`frm` dynamic ops (126) and the
`FS=0` probes (146), which is the intended distribution rather than a surprise.

### Coverage after `iu_random` + `vidu_random` at the committed defaults

Merged with the coremark reference, versus that reference. This is only two of
the four cases; `idu_random` and `ifu_random` are still to be added.

| unit | line | Δ line | branch | Δ branch |
|---|---|---|---|---|
| iu | 552/569 **97.0%** | **+50.6** | 203/210 96.7% | +8.1 |
| vfmau | 234/317 73.8% | **+52.4** | 90/104 86.5% | +10.6 |
| vfalu | 315/410 76.8% | **+49.3** | 570/576 **99.0%** | +18.6 |
| vfdsu | 227/367 61.9% | +28.3 | 235/246 95.5% | **+33.3** |
| cp0 | 369/531 69.5% | +17.1 | 85/112 75.9% | +15.2 |
| idu | 1023/1096 **93.3%** | +11.6 | 105/142 73.9% | +5.6 |
| vdsp | 56/64 87.5% | +7.8 | 63/84 75.0% | +4.8 |
| vdiv | 10/11 90.9% | +9.1 | — | — |
| ifu | 348/372 93.5% | +0.5 | 263/282 93.3% | +0.4 |
| vidu | 255/264 96.6% | +0.0 | 25/34 73.5% | +0.0 |
| **TOTAL** | 3389/4001 84.7% | | 1639/1790 91.6% | |

Volume matters a great deal here — compare with R003, which ran the same two
cases at 200 iterations: IU line went 88.8% → **97.0%**, `vfmau` 43.8% → 73.8%,
`vfalu` 51.2% → 76.8%. Line coverage is often said to saturate quickly; on the
FP execution units it plainly does not, because reaching a given rounding or
special-case path needs the right operand pair to come up.

The IU at 97.0% is close to done: 17 line points remain, which is about the size
of the dead min/max datapath plus the warm-up reset paths listed as unreachable.

### `idu_random`, `IDU_ITERS=6000` — TEST PASS, 351 s wall

```
iters=6000 sweeps=641 privtrips=327 zvamo=99
mtraps=2287 straps=0 nested=0 faultret=66 recovered=0
M causes: 1=30 2=1744 3=18 4=49 8=223 9=104 11=119
groups: all 46 non-zero and printed BY NAME -- main rotation 160..209 each,
        sparse 77..105 each
toggle: 106/127 functional IDU ports  (coremark reference: 98/127)
```

The cause histogram is the interesting artifact here, because every entry is a
group doing what it claims:

- **`1=30` — instruction access fault.** This is the `expt_priority` group's
  `rand_run_at()` excursion into the sysmap strong-order window landing exactly as
  designed, and `faultret=66` confirms the trap handler's fault net brought all of
  them back. Cause 1 does not appear in `cp0_random`'s histogram at all — that
  case declared fetch faults out of scope.
- `2=1744` illegal instruction: the reserved-field, `c.*`-illegal,
  `THEADISAEE`-off, `FS=0`, bad-`rm` and RVV groups.
- `3=18` breakpoint (`c.ebreak` in the RVC table), `4=49` misaligned load (the
  `lsd_interrupted` group's `mxstatus.mm=0` recipe).
- `8=223` / `9=104` ecall from U / from S: the privilege trampolines, 327
  round trips in total, matching the printed `privtrips=327`.
- `11=119` ecall from M.

Printing group hits **by name** rather than as a bare vector is worth copying to
the other three cases: the vector form requires counting columns to find which
group is cold.

#### Port triage: every remaining cold IDU port is accounted for

`idu_random` newly toggled **8** of the 29 ports coremark leaves cold, and the
21 that remain divide cleanly into four documented reasons — which is the
`cp0-design-and-test.md` §22 "ports that will never toggle, and why" table, now
done for the IDU:

| newly toggled (8) | why it moved |
|---|---|
| `cp0_idu_frm` | group 6 writes `frm` |
| `hpcp_idu_cnt_en`, `cp0_idu_icg_en` | privilege changes and the `mxstatus` PMD bits (groups 29, 44) |
| `ifu_idu_id_expt_acc_error`, `idu_cp0_ex1_expt_acc_error` | the `rand_run_at()` excursion into the strong-order window (group 39) |
| `idu_cp0_ex1_split`, `idu_iu_ex1_split`, `idu_lsu_ex1_split` | the four instruction-cracking FSMs (groups 18-22) |

| still cold (21) | count | reason |
|---|---|---|
| `cp0_idu_v{ill,l_zero,lmul,s,setvl_dis_stall,sew,start}`, `idu_vidu_ex1_vec_{sel,dp_sel,gateclk_sel}`, `idu_lsu_ex1_v{lmul,sew}`, `vidu_idu_vec_full` | 13 | the vector decoder is tied off (`decd_sel[5]=1'b0`) — permanently unreachable |
| `ifu_idu_id_expt_high`, `idu_cp0_ex1_expt_high`, `ifu_idu_id_expt_page_fault`, `idu_cp0_ex1_expt_page_fault` | 4 | need Sv39, i.e. `IFU_MMU`/`IDU_MMU`, default off |
| `rtu_yy_xx_dbgon`, `ifu_idu_id_halt_info`, `cp0_idu_dis_fence_in_dbg` | 3 | JTAG only — the `debug` case's territory |
| `iu_idu_mult_full` | 1 | **genuine remaining gap**: needs a cycle-exact mul/div writeback collision |

That is a complete account: 13 dead + 4 gated + 3 JTAG + 1 real gap = 21. The one
port worth chasing is `iu_idu_mult_full`.

**Concrete recipe for that last one, for whoever picks it up.**
`iu_idu_mult_full = mul_ex2_inst_vld && !mul_ex2_itering && mul_ex3_wb_vld &&
!rtu_iu_mul_wb_grant_for_full` (`aq_iu_mul.v:598`) — a multiply sitting in EX2,
*not* iterating, while a previous multiply's EX3 writeback is asserted and the
RTU has not granted it. Both `iu_random` group 20 and group 34 aim at it by
issuing a competing LSU or divide writeback, and neither lands, because the
collision is cycle-exact and the current groups fix the spacing.

The fix is not guesswork and does not need a waveform: **sweep the phase.** Emit
`mul; <n filler ALU ops>; mul; <competing load or div>` with `n` taken from the
random word over 0..7, so one of the eight spacings must put the second multiply
in EX2 on the cycle the first one's EX3 is stalled. That is the standard way to
hit a cycle-exact condition from software, and it is worth adding to group 20 as
an extra sub-case rather than as a new group. It was not done here because the
case is already verified and baselined, and churning it would invalidate both.

### `ifu_random` — the calibration was wrong, and why

`IFU_ITERS=3500` was derived by scaling the 200-iteration bring-up measurement
(2.97 us/iteration) up to a 90 s wall-clock target. That extrapolation is
**invalid for this case** and the run exceeded 600 s of simulation before being
cut off.

The reason is a sampling error, not a measurement error. `ifu_random`'s
per-iteration cost is wildly non-uniform:

- group 8 (`walk`, a ~48 KB straight-line sled for capacity eviction) is on the
  sparse selector *and* internally gated, so it fires roughly **1 in 1024**
  iterations — at 200 iterations it essentially never ran, and at 3500 it runs a
  handful of times, each one costing tens of thousands of cycles;
- group 24 (`bht_lfsr_history`) loops `2 + rand%60` times over a 64-iteration
  branch pattern, so a single visit can be ~23 000 instructions, and it is in the
  main rotation.

So a 200-iteration sample sees mostly cheap groups and under-estimates the mean
by a large factor. **Lesson: calibrate a case whose groups differ in cost by
three orders of magnitude from a sample large enough to include the rare
expensive ones — or calibrate from the sum of the per-group bisect timings, which
weights every group exactly once.** The three other cases have much flatter cost
profiles and their 200-iteration extrapolations held up (measured 157 s / 198 s /
351 s against a 90 s-plain target, i.e. right on it once the ~2x coverage penalty
is removed).

Measured, and it is worse than "heavy" -- it is a **cliff**, and I could not
localise it within this session:

| `IFU_ITERS` | simulated time | wall | result |
|---|---|---|---|
| 200 | 0.594 ms | 20 s | **TEST PASS** |
| 400 | **> 15 ms** | 969 s | hit the `+MAX_SIM_TIME` cap |
| 1200 | **> 20 ms** | 647 s | hit the cap |

Twice the iterations, at least twenty-five times the simulated time. Note what
this is *not*: a hang. The core retired instructions throughout -- the
50 000-cycle no-retire watchdog never fired, both runs stopped on the
simulation-time limit -- and the rate held at ~30 us/s. So it is cost, growing far
faster than the iteration count.

**My first explanation was wrong, and I had already written it into two documents
before checking it.** I attributed the cliff to group 39 (`enable_mix`) clearing
`MHCR.IE` and then running group 8's 48 KB sled uncached. Replaying the dispatch
sequence offline against the real PRNG and seed disproves it: that exact
combination fires at **iteration 135**, inside the run that completes in 0.594 ms.
Both documents are corrected.

Also ruled out by the same replay:

- **Not a newly-appearing group.** The only group whose first occurrence is past
  400 is group 34 (`delay_branch`, first at iteration 414). Group 32 (`ras_16m`)
  first fires at 199 -- inside the passing run.
- **Not group 8's sled by frequency.** Selected 5 times before iteration 200 and
  7 more between 200 and 400; even at ~100 k cycles a visit that is well under a
  millisecond.
- **Not an unrestored `MHCR.IE`.** Both groups that clear it (12 `noncacheable`,
  39 `enable_mix`) save and restore it, and `MHCR_WMASK` does not mask bit 0.

The leading remaining hypothesis -- untested -- is persistent state degradation:
some group leaving a predictor, prefetch or cache-enable bit in a slow
configuration that nothing restores, since `rand_restore_sane_state()` runs only
every 4096 iterations and so never runs at all in these short runs.

**Next diagnostic, small and decisive:** read `mcycle` around each group body,
accumulate per-group cycle totals, print them beside the hit counts in
`report()`. One 400-iteration run with a generous cap then names the group. That
is the right next step, and it is deliberately left undone rather than guessed at
again.

Default committed: **`IFU_ITERS=200`** -- the only value verified to complete --
with the caveat written into `smart_cfg.mk` next to it. The other three defaults
(16000 / 10000 / 6000) are calibrated and verified.

Port toggle is unaffected by any of this: **90/107 at 200, 400 and 1200
iterations alike.** The front-end interface saturates immediately.

### `ifu_random`, `IFU_ITERS=200` (the verified default) — TEST PASS, 19 s wall

```
iters=200 arena=0x8000-36000 layout_seed=0x5a5ac906
highpc=0 walk=0 far16m=2 jit=0 enmix_full=0 enmix_degraded=1
mtraps=21 straps=0 nested=0 faultret=10 recovered=0
M causes: 1=8 2=2 3=5 11=6
toggle: 90/107 functional IFU ports  (coremark reference: 80/107)
cost: 614 us simulated, 19.3 s wall, 31.8 us/s
```

`1=8` is eight instruction access faults from the strong-order excursions, with
`faultret=10` confirming the fault net returned from all of them. Groups 19
(`sv39_ifetch`) and 41 (`jit`) correctly report **0** hits because they are gated
off — that is the reviewer's fix to the phantom hit counter working as intended.

**The honest cost of the low default: `walk=0`.** Group 8 fires roughly 1 in 1024
iterations, so at 200 it never runs in the mixed stream, and `enmix_full=0` says
group 39 never once drew an all-enables-on vector either. The rarest groups are
therefore covered only by the per-group bisect (R004), not by the mixed run. Until
the runtime cliff above is diagnosed, reaching them in a mixed run means
`-DIFU_ONLY_GROUP=8` explicitly rather than raising `IFU_ITERS`.

---

## R006 — final merged coverage: all four cases at their committed defaults

`cov_report.py` summing `coremark.dat` plus the four `*_signoff.dat`, against the
coremark-only baseline of R001. **`cp0_random` is deliberately not in this merge**
— the CP0 delta below is what the four new cases reach incidentally, through the
CSR work every one of them does.

| unit | line | Δ line | branch | Δ branch |
|---|---|---|---|---|
| iu | 553/569 **97.2%** | **+50.8** | 204/210 **97.1%** | +8.6 |
| ifu | 361/372 **97.0%** | +4.0 | 279/282 **98.9%** | +6.0 |
| idu | 1059/1096 **96.6%** | +14.9 | 123/142 86.6% | +18.3 |
| vidu | 255/264 96.6% | +0.0 | 25/34 73.5% | +0.0 |
| vfalu | 323/410 78.8% | **+51.2** | 570/576 **99.0%** | +18.6 |
| vfmau | 234/317 73.8% | **+52.4** | 90/104 86.5% | +10.6 |
| vfdsu | 230/367 62.7% | +29.2 | 235/246 95.5% | **+33.3** |
| cp0 | 412/531 77.6% | +25.2 | 92/112 82.1% | +21.4 |
| vdsp | 56/64 87.5% | +7.8 | 63/84 75.0% | +4.8 |
| vdiv | 10/11 90.9% | +9.1 | — | — |
| **TOTAL** | 3493/4001 **87.3%** | | 1681/1790 **93.9%** | |

**Three of the four target units are at 96.6–97.2% line coverage**, up from
46.4% (iu), 81.8% (idu) and 93.0% (ifu). The fourth, `vidu`, was already at 96.6%
from coremark alone and its work shows in the FP execution units instead
(`vfalu` +51.2, `vfmau` +52.4).

Where the remaining cold code is, from `--top-cold`:

| file | uncovered | what it is |
|---|---|---|
| `vfdsu/rtl/aq_fdsu_round.v` | 70/204 | FP divide/sqrt rounding — needs directed operand corners, not random streams |
| `vfdsu/rtl/aq_fdsu_srt.v` | 59/140 | the SRT division iteration |
| `vfmau/rtl/aq_vfmau_lza_double.v` | 54/114 | leading-zero anticipation in the double FMA |
| `cp0/rtl/aq_cp0_regs.v` | 52/112 | CSRs only `cp0_random` reaches |
| `cp0/rtl/aq_cp0_trap_csr.v` | 44/184 | ditto |
| `idu/rtl/aq_idu_id_decd.v` | 28/726 | the residue of the tied-off vector decoder |

Note how the cold set has *moved*: at R001 it was the ALU shifter mask arms, the
divider special cases and the LSD cracking FSM — all now covered. What is left is
deep FP arithmetic (which wants directed corner vectors rather than more random
volume), CP0 (`cp0_random`'s job), and dead vector logic. That is a reasonable
place for a stimulus-only campaign to stop.

---

## Remaining work

Needs the Linux server:

1. **A VCS 4-state run of all five cases.** Authoritative for toggle, because
   Verilator's `--x-assign fast` hides exactly the X behaviour the new
   `x_cycles` column exists to expose. Save as
   `doc/results/<unit>_toggle_baseline.vcs.report` alongside the Verilator ones.
   The VCS `-cm` flags in `smart_run/Makefile` have **never been executed** — VCS
   is not installed on the development machine — so expect to debug them.
2. **`make regress`** end to end with the four cases in `REGRESS_LIST`.

Local, and specified:

3. **Diagnose the `ifu_random` runtime cliff** (R005): per-group `mcycle`
   accumulation printed beside the hit counts. One run then names the group.
4. **`iu_idu_mult_full`** — the one genuinely uncovered reachable port. Recipe in
   R005: sweep the instruction spacing 0..7 in group 20 so one phase puts the
   second multiply in EX2 while the first one's EX3 writeback is stalled.
5. **A final-value column in `gen_toggle_mon.py`**, so `NEVER TOGGLED` stops
   conflating "never asserted" with "tied high". Regenerates all five monitors and
   invalidates the report format of the baselines above, so do it as its own
   commit with fresh baselines.


### Still to do

1. The `idu_random` and `ifu_random` calibrated runs and their toggle baselines.
2. Merged coverage at the calibrated counts (the R003 numbers are a floor taken
   at 200 iterations).
3. A VCS 4-state run on the Linux server — authoritative for toggle, because
   Verilator's `--x-assign fast` hides the X behaviour the `x_cycles` column
   exists to expose — saved as `<unit>_toggle_baseline.vcs.report`.
4. `make regress` end to end with the four new cases in `REGRESS_LIST`.
