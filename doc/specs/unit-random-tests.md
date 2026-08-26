# OpenC906 per-unit randomized stress tests — `iu_random`, `vidu_random`, `idu_random`, `ifu_random`

Companion to `doc/specs/cp0-design-and-test.md` Part II, which introduced this
methodology for CP0. Read that first if you have not: §16 (what these are and
are not), §19 (how groups are chosen), §20 (safety rails) and §22 (coverage
measurement) apply here almost verbatim.

---

# Part 0 — Common

## 1. What these are, and are not

Four cases, one per pipeline unit, each a seeded xorshift64 dispatch loop over a
few dozen operation groups. Each group is a small burst of instructions aimed at
a *named RTL structure* — a case arm, a state machine, a queue-full condition, a
forwarding comparator — with the operands, register indices and sub-case choice
taken from the random word.

They are **stimulus, not verification**. There is no golden model, no
expected-value comparison and no self-check. A case passes by running to
completion: `main` returns, `crt0.s __exit` writes the PASS magic, and the
testbench sees it. The consequences are worth stating plainly:

- A hang, a livelock, a wild jump or a lost trap **is** caught — by the
  testbench's 50,000-cycle no-retire watchdog, by the simulation-time limit, or
  by the trap-cause histogram coming out wrong.
- A wrong ALU mask, a wrong multiplier partial-product sum or a wrong divider
  quotient digit **is not** caught. It produces `TEST PASS`.

That trade was made deliberately, for consistency with `cp0_random` and to keep
the cases cheap to write and cheap to trust. The hook for changing it later is a
`-D<U>_CHECK` flag over the same groups.

Three evidence channels:

| Evidence | Where |
|---|---|
| Nothing hung, deadlocked or wandered off | `TEST PASS` in `work/run_case.report` |
| The unit was really exercised | `work/<unit>_toggle.report` (port toggle) and `make covreport` (line/branch/toggle coverage) |
| Traps went where expected | the cause histogram printed over UART into `work/run_case.report` |

Because there is no self-check, **robustness is the design constraint**. Every
group that perturbs persistent state saves and restores it masked to that CSR's
writable bits; `rand_restore_sane_state()` re-baselines everything every 4096
iterations; and the trap handler unwinds to the loop head via `rand_longjmp` on
any nested or unexpected trap, so a wild jump costs one iteration rather than the
run. `recovered=` in the report counts those unwinds and should be 0 outside the
groups that bail by design.

Results are folded into a `volatile u64 rand_sink` **only** so the compiler
cannot delete the instruction under test. The printed value is a fingerprint of
one (seed, iters, toolchain) combination; it is not compared against anything.

## 2. The shared harness

`smart_run/tests/cases/rand_common/` — see its `README.md` for the rules that
keep it safe to share (enumerated file copies, exactly one `.c` and one `.S`,
`rand_`-prefixed symbols, no newlib stdio, and the `main()` ordering rule).

| File | Role |
|---|---|
| `rand_common.h` | CSR access macros, raw-instruction macros, `DCACHE_SAFE_POINT()`, `RAND_ICACHE_SYNC()`, the safe-GPR list, all prototypes |
| `rand_csrs.h` | CSR numbers and field masks, CLINT/PLIC/UART addresses, the `rand_ctx` layout, and the **address-window rules** |
| `rand_th_insn.h` | every T-Head raw encoding plus the `TH_R`/`TH_I`/`TH_EXT`/`TH_ADDSL`/`TH_IDX` builders |
| `rand_trap.S` | own `mtvec`/`stvec`, cause histogram, nested-trap bail, `rand_run_at()` fault net, setjmp/longjmp, S/U-mode trampolines |
| `rand_lib.c` | xorshift64, `rand_restore_sane_state()`, `rand_pmp_open_everything()`, LPMD wake arming, the D-cache-off UART printer, `rand_hist_dump()` |

**`cp0_random` is deliberately not built on this.** It has its own
`cp0_trap.S` / `cp0_csrs.h` / `cp0_th_insn.h`, because (a) it is working,
committed and baselined at 169/201 ports with `recovered=0` and all 42 groups
verified individually, and refactoring it risks the one artifact that gives this
methodology its credibility; and (b) `cp0_trap.S` is not generic — it carries
vectored dispatch, the ecall-back-to-M trampoline, per-source CLINT/PLIC
interrupt teardown, `cp0_sret_land` and `CP0_FORCE_BAIL`. The cost is one
duplicated ~250-line handler skeleton. **If you fix a bug in one, check the
other.**

## 3. Running them

```bash
source setup/mac_setup.sh                 # or setup/server_setup.csh
make compile CASE=<case> SIM=verilator DUMP=off     # once per RTL change
make runcase CASE=<case> SIM=verilator DUMP=off
```

| Knob | Default | What it does |
|---|---|---|
| `<U>_ITERS` | per case, see `smart_cfg.mk` | dynamic dispatch-loop iterations. The defaults are **measured, not extrapolated**, and they differ by ~80x because per-iteration cost does. `iu` 16000, `vidu` 10000, `idu` 6000 each land near 90 s wall in the plain configuration; **`ifu` is 200 because of the open issue in Part IV** -- raising it without re-measuring will run for hours. |
| `<U>_SEED` | `0x2024C906` | xorshift64 seed — fixes the whole data sequence |
| `<U>_OPT` | `-O2` | **changes the stimulus**: the same source at `-O0/-O1/-O2/-Os` gives four different decode streams for free. Highest-value knob for `idu_random` and `ifu_random` |
| `<U>_EXTRA` | empty | extra `-D`, e.g. `-DIU_ONLY_GROUP=23` |
| `IFU_ARENA_SEED` | `0x5A5AC906` | reseeds the **code layout** — a different program, not just different data |
| `SIM_ARGS` | empty | plusargs for the run step, e.g. `SIM_ARGS=+MAX_SIM_TIME=4e6` |
| `MON=all` | off | compile all five per-unit toggle monitors, so any case can be measured against every unit |
| `COVERAGE` | off | `line` or `all`; forces `DUMP=off` |

Gated groups, all off by default: `IU_ENABLE_JUMP8M`, `IDU_ZVAMO`, `IFU_MMU`,
`IFU_JIT`. `RAND_FORCE_BAIL` turns `ebreak` into an unrecoverable trap so the
setjmp/longjmp recovery path itself gets exercised (`recovered` should then equal
the cause-3 count).

Bisecting a failure — always the first thing to run:

```bash
make compile CASE=iu_random SIM=verilator DUMP=off
bash tests/cases/iu_random/run_groups.sh          # one group at a time
```

The classification matters: a **stall** trips the 50,000-cycle no-retire
watchdog within seconds, but a **livelock that retires** (an infinite trap loop,
a self-re-arming interrupt) is only caught by the simulation-time limit. Hence
the deliberately short `SIMTIME` default in `run_groups.sh` and the `SIM_ARGS`
hook — the testbench default is `MAX_RUN_TIME 3e9` ns, which at the measured
~118 kcycle/s under Verilator is about seven hours before the run declares FAIL.

Long soaks and sweeps:

```bash
make runcase CASE=iu_random SIM=verilator DUMP=off IU_ITERS=200000
for s in 0x1 0xDEADBEEF 0x2024C906 0xFEEDFACE; do
  make runcase CASE=idu_random SIM=verilator DUMP=off IDU_SEED=$s
done
for o in -O0 -O1 -O2 -Os; do
  make runcase CASE=idu_random SIM=verilator DUMP=off IDU_OPT=$o COVERAGE=line
done
make covreport SIM=verilator
```

## 4. Measuring

Two independent measurements, and they answer different questions.

### 4.1 Port toggle — `work/<unit>_toggle.report`

Generated monitors, one per unit, produced by
`cli_tools/gen_toggle_mon.py --unit <cp0|iu|idu|ifu|vidu>` and bound into the
testbench behind a `+define+` that arrives via a `-f` filelist. Each reports,
per port of the unit's top module: how many *bits* ever changed, how many
*cycles* the port differed from the previous cycle, and how many cycles it held
an X or Z bit.

That third column exists because the accumulate guard is *whole-port* — masking
per bit would OR an X into the mask and latch it there forever. Under a 4-state
simulator a 180-bit port with one permanently-X bit therefore records zero
toggles for all 180 bits, while under Verilator with `--x-assign fast` the same
port toggles freely. **A Verilator toggle number and a VCS toggle number for the
same run are different numbers and must never be diffed against each other.**
The `x_cycles` column is what makes the discrepancy visible instead of
mysterious.

| Unit | Top module | Ports (functional) | Report |
|---|---|---|---|
| cp0 | `aq_cp0_top` | 204 (201) | `cp0_toggle.report` |
| idu | `aq_idu_top` | 130 (127) | `idu_toggle.report` |
| iu | `aq_iu_top` | 118 (115) | `iu_toggle.report` |
| ifu | `aq_ifu_top` | 110 (107) | `ifu_toggle.report` |
| vidu | `aq_vidu_top` | 51 (48) | `vidu_toggle.report` |

Interface toggle is a *weak* metric for a datapath unit — the IU's 118 ports are
mostly wide buses that toggle on cycle one. It is strong evidence for a control
block and weak evidence for a datapath, which is exactly why code coverage was
added alongside it. Measured: one coremark iteration already toggles 105 of the
IU's 115 functional ports while covering 46% of its lines, and `iu_random` — which
takes that to 89% — produces a *byte-identical* never-toggled list.

Two properties of the report that will mislead you if you do not know them:

- **`NEVER TOGGLED` conflates "never asserted" with "constantly asserted".** The
  monitor records transitions, not values. `hpcp_iu_cnt_en` appears in every
  never-toggled list because it is tied high for the whole run in bare-metal M
  mode, not because the counters are idle — they demonstrably are not. Adding a
  final-value column to `gen_toggle_mon.py` would resolve this and is the obvious
  next improvement.
- **A per-case run can only see its own unit.** The guard macro is a compile-time
  define, so `make runcase CASE=idu_random` compiles only the IDU monitor. Three
  of the IU's cold ports (`idu_iu_ex1_split`, `rtu_iu_ex1_inst_split`,
  `iu_rtu_ex1_alu_inst_split`) are driven by the IDU's instruction-cracking FSMs,
  so no `iu_random` run will ever move them and no `idu_random` run will report
  them. Cross-unit effects need `MON=all`.

### 4.2 Code coverage — `make covreport`

New in this work; before it, the repo had no coverage instrumentation at all.

```bash
make runcase CASE=coremark SIM=verilator DUMP=off MON=all COVERAGE=line
make covreport SIM=verilator COV_ARGS="--save-baseline ../doc/results/unit_coverage_baseline.json"
# ... write more stimulus ...
make runcase CASE=iu_random SIM=verilator DUMP=off COVERAGE=line IU_ITERS=5000
make covreport SIM=verilator COV_ARGS="--baseline ../doc/results/unit_coverage_baseline.json --top-cold 5"
```

- **Verilator**: `--coverage-line` for `COVERAGE=line`, plus `--coverage-toggle`
  and `setup/cov_units.vlt` for `COVERAGE=all`. Never bare `--coverage` — it
  aliases line+toggle+user, and toggle-instrumenting the whole SoC including the
  two 128 MB SRAM banks is unaffordable. `-O3` is safe: Verilator declines to
  apply its table optimization to any block containing coverage points.
  `coverage.dat` is written *after* the `final` blocks, which is why the toggle
  reports keep working.
- **VCS**: `-cm line+cond+branch+fsm[+tgl] -cm_dir ../cov/simv.vdb -cm_name <case>
  -cm_hier ../setup/cov_hier.cfg -cm_line contassign -cm_cond allops`.
  `-cm_line contassign` is load-bearing — VCS line coverage ignores continuous
  assignments by default and this RTL is almost entirely `assign`. **The run step
  needs the `-cm` flags too**, or nothing is recorded.
- `cli_tools/cov_report.py` parses either backend and prints per-unit
  covered/total and percentage with a delta column against a committed baseline,
  plus `--top-cold N` listing the coldest files and their first uncovered lines —
  the "what do I write next" output.

Two rules for reading the table. First, **only compare like with like**: the
delta column is meaningful for the unit a case targets, or for the *merged* set
of `.dat` files, but a single case measured against a coremark baseline will show
negative deltas on the units it does not touch — that is not a regression, it is
two different workloads. Second, **check that the unit is where the logic is**;
see Part II for the case where it was not.

**Absolute percentages are meaningless here.** `gen_rtl/` contains behavioural
SRAM models, legs of the design compiled out by `cpu_cfig.h`, and the gutted
vector path in `vidu/`, so line coverage has an unreachable floor nobody will
ever close. The first measurement — `coremark` with `MON=all COVERAGE=line` — is
the **reference**, not the target. Every number after it is reported as a delta,
and each file `--top-cold` names is triaged as *reachable / config-dead /
needs-JTAG / needs-vector* and written down, the same way
`cp0-design-and-test.md` §22 tabulates the ports that will never toggle.

Coverage and `DUMP=on` are mutually exclusive by policy (`COV_ALLOW_DUMP=1` is
the escape hatch): multiplying a ~2× coverage penalty by a ~20× dump penalty
turns a 441 s run into hours, and the two artifacts answer different questions.
Practical consequence: **coverage runs use short iteration counts** — line
coverage saturates fast; it is toggle and branch that keep creeping — so the
iterate-on-coverage loop is `COVERAGE=line` plus a few thousand iterations, and
the long soaks run `COVERAGE=off`.

## 5. Safety rails common to all four

Each of these is here because the equivalent group hung or misbehaved without it
in `cp0_random`'s bring-up (`cp0-design-and-test.md` §20), or because the RTL
reading says it would.

1. **`-fno-optimize-sibling-calls -fno-jump-tables`** on every case. Both are in
   the recipes. Each case is essentially one giant `switch`; without
   `-fno-jump-tables` GCC emits a computed `jr` through a `.rodata` table, which
   is the construct in CLAUDE.md's first Known Bug.
2. **`rand_trap_init()` first, then `rand_pmp_open_everything()`.** `crt0.s` sets
   `mstatus.MIE=1` while `mtvec` still points at its own `vector_table`, whose
   entries are `.long` (4 bytes) but are loaded with `ld` (8 bytes) — so any trap
   before the handler is installed is an infinite exception loop.
   `rand_trap_init()` clears MIE as its first instruction so the ordering cannot
   be forgotten.
3. **PMP entry 0 spans everything, permissively.** Without it S and U mode are
   denied every access, so the privilege groups cannot run. Entry 0 has the
   highest priority, so whatever a group writes to entries 1–15 is harmless.
   **`pmpcfg.L` is never set** — a locked entry is sticky until reset and would
   poison the rest of the run. Where a fetch fault is wanted, the sysmap
   strong-order window is used instead; it has no persistent state.
4. **`DCACHE_SAFE_POINT()`** (`th.dcache.ciall`) before every
   invalidate-without-writeback (`th.dcache.iall/isw/iva/ipa`, `MCOR` bit 4) and
   before every `MHCR` write that clears `DE`. And if code is ever written at
   runtime the order is store → clean D-cache → `th.sync` → `fence.i` → jump;
   invalidating the D-cache first throws the freshly written code away.
   `RAND_ICACHE_SYNC()` exists so that sequence is written once.
5. **Printing only inside `rand_report_begin()`/`rand_report_end()`.** UART0 is
   in a cacheable region, so a cached store's line writeback carries
   `wstrb=16'hffff`, which the testbench's console decoder does not match; and
   consecutive stores to one address coalesce in the store buffer, so characters
   need `th.sync` plus a spin, not just ordering.
6. **`mstatus.MIE` is 0 throughout.** None of these four has an interrupt group —
   `cp0_random` owns that. Only the WFI groups touch interrupt state, via
   `rand_arm_lpmd_wake()`, which delegates STIP with `sstatus.SIE` clear: the
   LPMD wake condition is `|(mie & mip)` and is privilege- and delegation-blind,
   so a WFI with nothing armed is unrecoverable short of reset.
7. **Whitelisted encodings only.** No case ever executes `rand_rnd()` cast to an
   instruction word. A random word can be `wfi`, `csrw mtvec,x0`, an arbitrary
   store, `mret` or a wild jump.
8. **Reserved registers.** No generated encoding writes `x1` (ra), `x2` (sp),
   `x3` (gp), `x4` (tp — holds `&rand_ctx`) or `x8` (s0). Register fields come
   from `rand_safe_regs`.
9. **Address windows** — the full table is in `rand_csrs.h`; the two that will
   break a run are `0x1000_0000..0x1FFF_FFFF` (an I-cache refill there is a
   4-beat 16-byte WRAP burst `axi2ahb.v` cannot service) and
   `0x0016_3840..0x0FFF_FFFF` (`tb.v:98` wipes only below `0x0016_3830`, so it
   reads X under VCS even though Verilator reads 0).
10. **Bisect before mixing.** Every group must pass under `-D<U>_ONLY_GROUP=n`
    with a short `SIM_ARGS=+MAX_SIM_TIME=4e6` before it joins the rotation.
    Anything that might hang goes on the sparse selector, or behind its own
    `-D` gate, default off.
11. **Never let a sub-case selector read bits the group index already consumed.**
    This is the single most damaging bug found during bring-up, it is completely
    silent, and it cost nine groups of one case almost all of their coverage.

    The main rotation is `g = r % 32`, i.e. **bits [4:0] of `r` are pinned for
    the whole lifetime of a main-rotation group**. So inside group `g`, a
    selector like `(r >> 3) & 3` is bits [4:3] — a *compile-time constant*, one
    arm out of four, forever. `r & 1` is worse: always the same bit. In one case
    this collapsed nine groups to a single arm each, left two of eight
    reserved-rounding-mode encodings permanently unexecuted, and made a
    "roughly half of these mispredict" branch perfectly predictable.

    **Rule: main-rotation groups shift by at least 5.** `cp0_random` shifts by 8
    or more everywhere, which is why it never hit this. Sparse groups are
    selected by `(r >> 32) % 64`, which pins bits [37:32] and leaves [4:0] free,
    so they may use low bits — but shifting by 5 there too costs nothing and
    removes the need to remember which selector a group is on.

    It is worth *proving* rather than eyeballing: run the actual PRNG from the
    actual seed for a few hundred thousand iterations and, per group, print the
    set of sub-case values reachable. That is how this was found, and it takes
    about twenty lines of Python.

## 6. Reproducibility contract

The seed alone does **not** determine the stimulus. Every baseline records:

```
case            : iu_random
rtl commit      : <git rev-parse --short HEAD>
simulator       : Verilator 5.048 2026-04-26 rev v5.048-56-gc233a3905
host            : macOS 25.5.0 arm64, VL_JOBS=10 VL_THREADS=1
toolchain       : xPack riscv-none-elf-gcc 15.2.0, THEAD_GCC=0, CPU_ARCH_FLAG_0=c906fd
                  -march=rv64imafdc_zfh_zicsr_zifencei -mabi=lp64d -O2
extra cflags    : -fno-optimize-sibling-calls -fno-jump-tables
knobs           : IU_ITERS=... IU_SEED=0x2024C906 IU_OPT=-O2 IU_EXTRA=
plusargs        : (none) | +MAX_SIM_TIME=...
DUMP / COVERAGE : off / line
text size       : ..... bytes .text + .rodata   (256 KB budget)
result          : TEST PASS
toggle          : NN/115 functional ports toggled (3 infrastructure excluded)
coverage        : aq_iu_top line NN.N%  branch NN.N%   (delta over coremark: +NN.N pt)
cost            : NN ms simulated, NNN s wall, NNN kcycle/s
uart summary    : [iu_random] iters=... groups=... mtraps=... recovered=0
```

The two non-obvious mandatory fields are the **simulator name and version**
(Verilator and VCS toggle numbers are not comparable — see §4.1) and the **full
toolchain plus `-O` and `-march`** (the same seed under Xuantie GCC and under
upstream GCC produces different instruction selection, which for `idu_random`
and `ifu_random` is a first-order effect, not a detail).

Baselines live in `doc/results/`: `<unit>_toggle_baseline.report` (Verilator,
fast iteration) and `<unit>_toggle_baseline.vcs.report` (VCS 4-state,
authoritative), plus `unit_coverage_baseline.json` and an append-only
`unit_random_runlog.md`.

---

# Part I — `iu_random`

Target: `C906_RTL_FACTORY/gen_rtl/iu/rtl/` — `aq_iu_alu`, `aq_iu_bju`,
`aq_iu_mul`, `aq_iu_div` (+ `aq_iu_div_shift2_kernel`,
`multiplier_33x33_partial`, `booth_code_33_bit`, `aq_iu_addr_gen`).

44 groups: 32 in the main rotation (`r % 32`), 12 on the sparse selector
(`(r>>32) % 64`, arms 0–11). The exhaustive group table with its RTL citations
lives in the file header and per-group comments of
`tests/cases/iu_random/C906_IU_RANDOM.c`; the summary is:

| Range | Targets |
|---|---|
| 0–8 | ALU adder / compare / `th.addsl` / shifter (register and immediate forms) / `th.srri` / `th.ext` / `th.extu` / logic |
| 9–13 | ALU misc: `th.ff0`/`th.ff1`, `th.tst`, `th.tstnbz`, `th.rev`/`th.revw`, `th.mveqz`/`th.mvnez` |
| 14–18 | BJU: all six conditions, mispredict, the load-dependent replay entry, jal/jalr/RAS forms, auipc |
| 19–21 | MUL: the 33-bit early-out, the split iteration, the `th.mul*` accumulate forms |
| 22–26 | DIV: iteration-count and quotient-digit sweeps, the FF1 trees, the four special cases, the result-reuse buffer, writeback conflict |
| 27–31 | Forwarding (ALU/LSU/MUL/BJU × src0/1/2 × distance 1–3) and the RVC path |
| 32–43 | sparse: flush-shadowed mul and div, mul/div collision, dense branches, deep RAS, word boundaries, `x0` forwarding, HPCP counters, the ±8 MB jump (gated), traps, the everything-at-once block |

Three things carry most of the value, because nothing else in the repo reaches
them (`ISA_INT` has five `div` and five `rem` instructions in total, with no
divide-by-zero, no `INT_MIN/-1` and no div/rem fusion):

- **The divider special-case matrix and the result-reuse buffer.** `div a,b`
  followed by `rem a,b` with identical operands completes in two cycles from the
  buffer; changing signedness or word-ness misses. All four mismatch arms are
  covered individually (`aq_iu_div.v:779-782`).
- **The multiplier's 33-bit early-out asymmetry** (`aq_iu_mul.v:274`): the *same*
  bit patterns split for `mulhu` and do not for `mul`, because
  `src1_sign64 = sign && !su`.
- **The wide immediate sweeps.** With `lsb=0`, `alu_shift_ext_count = msb` and the
  sign probe indexes `msb`, so one 64-instruction `th.ext` sweep covers both the
  64-arm `alu_shifter_extu_mask` case and the 64-arm `alu_shift_ext_sign` case.
  `th.ff1`, `th.ff0`, `th.tstnbz` and the divider's FF1 trees are *data*-driven,
  not immediate-driven, so they cost no code at all.

Unreachable, do not chase: `FUNC_MIN/MAX/MINU/MAXU/MINW/MAXW/MINUW/MAXUW` are
never emitted by the decoder (`grep -c` on `aq_idu_id_decd.v` returns 0 for all
eight) and the ALU's max/min datapath is commented out — `alu_adder_op_sel`
(`aq_iu_alu.v:195`), `alu_adder_rst_sel`/`rst_max` (`:246-247`),
`alu_adder_sel_rst_src0` (`:254`). Also the `ifu_iu_warm_up` reset paths and
anything gated on `rtu_yy_xx_dbgon`.

**Correction, because this document said otherwise at first.** Arm `5'b01000`
("unsign 32 op") of `alu_adder_rs0_sel_onehot` (`aq_iu_alu.v:205`) and
`alu_adder_rs1_sel_onehot` (`:229`) is **not** dead. Bit 3 of both one-hots is
`alu_func[16]` (`:198-199`), and `alu_func[16]` is *also*
`alu_shift_high_zero` (`:302`), which `FUNC_SLL`/`SLLI`/`SLLW`/`SLLIW`/`C_SLLI`
all set (`aq_idu_cfig.h:345-348, 440` — each is `17'b10000_…` zero-extended, so
the MSB lands on bit 16). Since `alu_func` is the whole 20-bit word regardless of
which sub-unit will use it (`:180`), **every left shift selects that arm in both
adder muxes**, and groups 3, 4 and 31 hit it on every dispatch. The earlier claim
came from assuming `alu_func[16]` was exclusive to `FUNC_MINUW`/`MAXUW`; it is
not. Worth keeping as a cautionary note: a shared `func` bus means "only
instruction X sets this bit" is a claim about the *whole* encoding table, not
about one sub-unit's decode.

A related consequence of the same sharing, which is *not* a test bug: a shift
whose adder select is non-one-hot (e.g. `FUNC_SRL` gives `5'b01100`) takes the
`default: {65{1'bx}}` arm of those muxes while the adder result is unused. Any
X-propagation check on `alu_adder_rs0/rs1_raw` will fire on ordinary compiler
output, not just on this test.

---

# Part II — `vidu_random`

**`gen_rtl/vidu/` contains no vector logic in this release.** Every `*_vec`
submodule in `aq_vidu_top.v:416-454` is a commented-out `&Instance`, the
`*_vec.v` files do not exist, and `:455-473` is a "Vector Dummy" tie-off block.
`decd_sel[5] = 1'b0` (`aq_idu_id_decd.v:1011`) makes every RVV instruction trap
illegal, and `mstatus.VS`, `vl` and `misa.V` are hardwired 0. What is there is
the **scalar FP issue unit**: `aq_vidu_vid_split_fp` (skid buffer),
`_ctrl_fp` (dependency stalls), `_dp_fp` (operands and forwarding), `_gpr_fp`
(32×64b FP register file, 3 read ports) and `aq_vidu_vid_wbt` (32-entry FP
scoreboard). The case therefore builds `c906fd`; `c906fdv` must never be used,
because GCC 14 emits RVV 1.0 and this RTL is RVV 0.7.1.

42 groups: 32 main + 10 sparse. `ISA_FP`'s `C906_FPU_SMOKE.s` (3886 lines)
already covers the FP *op matrix* and the static rounding modes, and it uses only
17 of the 32 FP registers — f13, f16–f19 and f22–f31 never appear in it. So
`vidu_random` targets what that directed test cannot reach:

| Range | Targets |
|---|---|
| 0–8 | RAW on srcf0/1/2, the forwarding exceptions and their negated VLSU qualifier, store-data forwarding, WAW and its single exception, and **all 32 scoreboard entries × 3 read ports** |
| 9–13 | the split skid buffer, `vidu_idu_fp_full` back-pressure, the cross-gated FP-load select, `vex1_fp_stall`, writeback-port collisions |
| 14–23 | the FP instruction space `FPU_SMOKE` misses: `flw`/`fsw`, the compressed FP loads/stores, the eight T-Head indexed FP forms, all 32 registers as every operand, and the long-latency `fdiv`/`fsqrt` mix |
| 24–31 | rounding modes incl. the illegal `rm=101/110` raw encodings, `fflags`, `FS` dirty tracking, scoreboard flush, the FP→int dependency (typed `WB_INT_TYPE_OTHER`, so it always takes the full stall), `fld` bursts |
| 32–41 | sparse: `FS=0` (the most dangerous group — it makes even `csrr fcsr` illegal), register-file walk, denormals, NaN propagation, Zfh, FP traps, WFI |

Scoreboard note: the entry `cnt` is **one bit**
(`aq_vidu_vid_wbt_entry.v:44`, comment `:103-104`), so the maximum is **two**
outstanding producers per FP register, reachable only via two consecutive `fld`s.
Do not chase a third.

### Measure this case on the FP execution units, not on `gen_rtl/vidu/`

A measured surprise, and the reason `cov_report.py`'s default unit list is wider
than the four target directories. `gen_rtl/vidu/rtl/` is small — 264 line
coverage points — and one coremark iteration already covers **96.6%** of it; the
residue is the tied-off vector logic listed above, which nothing can reach. So
`vidu_random` scores **+0.0 points** on its own directory, which looks like a
failed test and is not one.

Its actual effect, at only 200 iterations, is on the units VIDU issues *to*:

| directory | coremark alone | + `vidu_random` | Δ line | Δ branch |
|---|---|---|---|---|
| `vfalu/` (add/cmp/convert/sign) | 27.6% | **51.2%** | +23.7 | +17.0 |
| `vfmau/` (fused multiply-add) | 21.5% | **43.8%** | +22.4 | +10.6 |
| `vfdsu/` (divide / sqrt) | 33.5% | **49.0%** | +15.5 | **+30.5** |
| `vdsp/` (VPU wrapper) | 79.7% | 87.5% | +7.8 | +4.8 |
| `vidu/` (the issue queue itself) | 96.6% | 96.6% | +0.0 | +0.0 |

Read the FP rows, not the `vidu` row. The lesson generalises: **a unit's coverage
number is only a good scorecard when that unit is where the logic is.** VIDU is a
scoreboard and a skid buffer — a few hundred lines of control — so its saturation
point is low and a real workload reaches it. The arithmetic it gates is tens of
thousands of lines away in `vfalu`/`vfmau`/`vfdsu`, and that is where a
randomized FP stream pays off.

**All 32 FP registers are X at `main()` entry** — `crt0.s` writes no FP register
and `aq_vidu_vid_gpr_reg_fp.v:86-88` is an unreset flop — so the case begins with
32 × `fmv.d.x f_i, x0`. Under Verilator this is invisible; under VCS it is the
difference between a meaningful run and an X-poisoned one.

Unreachable, do not chase: the nine `fgpr_reuse` mux arms in `_dp_fp.v:242-266`
and the reuse arm of `dp_wb_inst_type` (`:295-296`) — the select is tied to 0 at
`aq_vidu_top.v:461`; the reuse terms in `_ctrl_fp.v:236-240`; the `vec_sel` terms
of `vpu_rtu_ex1_cmplt` (`:178-184`); `wbt_ctrl_fp_srcvm_info` (the vector mask
port); simultaneous `wbt` `wb0_vld`+`wb1_vld` (mutually exclusive by
construction, `aq_vpu_fwd_wb_rbus.v:462,500`); `viq1_xx_ex1_stall` (`:543`).

---

# Part III — `idu_random`

Target: `gen_rtl/idu/rtl/` — the seven decode sub-tables, the four instruction
cracking FSMs, the 31-entry scoreboard, the interlocks, and the 31×64b shadow
register file with its three 32-arm read-port muxes.

46 groups: 32 main + 14 sparse.

| Range | Targets |
|---|---|
| 0–17 | the decode tables: 32-arm RVC, 104-arm 32-bit (split in two for bisecting), 79-arm FP + 12-arm FMA, the rounding-mode and `FS=0` illegal paths, the 25-arm cache/sync table, `THEADISAEE` off, the 77-arm Xtheadc table in five thematic groups, and the RVV-illegal boundary |
| 18–22 | the four cracking FSMs: `th.lwd/lwud/ldd/swd/sdd` → 2 uops (and a flush or dis-stall landing **between** them), the 12-bin `{lr,sc,amo*} × {none,aq,rl,aqrl}` matrix where `aqrl` emits 3 uops, `icache.iva/ipa` → 2 uops with its U-mode privilege guard, and `sfence.vma` → 2 uops |
| 23–25 | the 14-arm and 7-arm immediate-select cases and the **96 shadow-GPR read-port bins** (src2 is store data, so `sd xN,0(sp)` is what sweeps it) |
| 26–31 | the illegal-instruction sources, the cache-op privilege checks, and the first RAW excepts |
| 32–45 | sparse: the forwarding-bus excepts and the `x0` guard, load→store-data forwarding, **`cnt==2`** (reachable only via three back-to-back D$-missing loads to one `rd`), `dst1_waw`, simultaneous `wb0`+`wb1`, late forwarding, the FP full-stall, the exception priority chain, EU-full saturation, the two commit qualifiers, fence-class dispatch stalls, the HPCP classification, and the gated ZVAMO negative test |

The hard rule for this case is written into its file header: **never execute a
random word.** Every stream is built from a whitelisted encoding table with
randomised fields. A random 32-bit word can be `wfi` (unrecoverable short of
reset), `csrw mtvec, x0` (the next trap goes to address 0), an arbitrary store
(corrupting the test's own stack), `sfence.vma`, `mret`, or a wild jump — and it
can write `x1`/`x2`/`x3`/`x4`, destroying `ra`, `sp`, `gp` and the `tp`-held
context base.

The mechanically enumerable leaves (the two immediate-select sweeps, the 96 GPR
bins, the forwarding chains) come from `gen_idu_sweeps.py`, run from the build
recipe into `work/`.

Unreachable: the entire vector decoder — `decd_sel[5] = 1'b0` makes roughly 2900
lines of `aq_idu_id_decd.v` dead, along with `decd_vec_*`,
`idu_vidu_ex1_vec_sel`, `cp0_idu_vsetvl_dis_stall` and `ctrl_dis_vec_stall`;
`EU_VEC` dispatch; `C.JAL` (RV64); and everything gated on `rtu_yy_xx_dbgon`
(the debug-trigger cancel arm, `decd_debug_illegal`, and the fence-in-debug
escape) — that is the `debug` case's job.

---

# Part IV — `ifu_random`

Target: `gen_rtl/ifu/rtl/` — PC generation and the redirect priority, the 32 KB
2-way I-cache with its way-prediction buffer / refill / prefetch / cache-op
FSMs, the 16-entry BTB, the 16 Kb BHT, the 4-entry RAS, the 3-entry RVC packer
and the 6-entry instruction buffer.

42 groups: 32 main + 10 sparse. This is the one case whose stimulus is
**generated code**, because IFU coverage is per-address-layout and C cannot
express it: 16+ distinct taken-branch PCs at unique `PC[15:0]`, 16 KB-stride
I-cache set conflicts, code spread over 16+ distinct 4 KB pages, 32-bit
instructions straddling fetch words at 2 mod 4, and cross-64 KB / cross-16 MB
control transfers.

`gen_ifu_arena.py` emits, from `IFU_ARENA_SEED`, a `.text.arena` section of raw
`.short`/`.word` encodings pinned by the case's own linker script, plus a header
of block entry points and the far stub that goes into `input.pat` at exactly
16 MB.

**Two linker traps worth knowing, both of which bit during bring-up.** First,
`. = 0x8000;` before an output section that names a memory region (`>MEM1`) is
**silently ignored** — the link succeeds, `.text.arena` lands wherever `.text`
happened to end, and every address-derived coverage point in the test quietly
stops working while the test still passes. The section needs an explicit address
(`.text.arena 0x00008000 : { … }`), and `linker_ifu.lcf` carries three ASSERTs —
arena pinned at `IFU_ARENA_BASE`, `.text` fits below it, MEM1 not overflowed — so
that a mismatch is a link error rather than a silent loss of coverage.
`IFU_ARENA_BASE` in `smart_cfg.mk` and that address must be changed together.

Second, `tb.v` loads `input.pat` **twice**: into the NN window at `0x0100_0000`,
which is what the 16 MB RAS group needs, and into a legacy window at `0x8_0000`,
which lands on `.data`/`.bss` at time 0 — so a `.bss` object there would start
life holding far-stub bytes. A fourth ASSERT (`end <= 0x80000`) makes that a link
error too. And the far stub is capped at exactly 16384 words because under VCS
`$readmemh` into `mem_input_temp[16384]` is **fatal** if the file is longer. Design rules: raw encodings with `.option norelax` (GNU `as` relaxation
would silently change instruction sizes and destroy byte-exact layout), layout by
`.balign`/`.space` rather than `.org`, **zero computed jumps**, and a `--check`
mode — run from the build recipe — that asserts every emitted target lies in a
legal fetch window, no target is in the APB range, every BTB-group branch has a
unique `PC[15:0]`, and the byte accounting matches.

Three structural facts drive most of the design:

- **The BHT is indexed by the 14-bit global history only** — `pred_bht_pc` is a
  forced, unused input (`aq_ifu_bht.v:135-136`). So *one* branch whose direction
  comes from an LFSR random-walks the whole (index, way) space, and many distinct
  branches are strictly *worse* because they share the same history.
- **BTB allocation only happens when the instruction buffer is hungry**
  (≤2 valid halfwords, `aq_ifu_pred.v:795-796` + `aq_ifu_ibuf.v:1346`). So the
  generator emits "starved branch" blocks — a `div` or a 16 KB-conflicting load
  immediately before each taken branch — which is the only way the BTB learns.
- **The fetch-fault lever is the sysmap strong-order window.**
  `SYSMAP_FLG1 = 5'b10011` sets Strong Order for PA `0x8FFF_F000`+, and
  `aq_mmu_utlb.v:788-790`'s SO-exec deny has no M-mode escape, so a fetch there
  is an instruction **access fault** with no way to suppress it. `rand_run_at()`
  is the vehicle and its fault net brings the excursion back — measured
  `faultret=10` on a 200-iteration run, so the mechanism works.

Two corrections to earlier drafts of this section, both found by review:

**`ifu_idu_id_expt_high` is NOT reachable without Sv39.** The plan claimed a
32-bit instruction at `0x8FFF_EFFE` would put its low halfword in the fetch group
at `0x8FFF_EFFC` (region 0, succeeds) and its high halfword at `0x8FFF_F000`
(region 1, denied), giving a fault on the high half only. The fetch-group
arithmetic is right, but the low halfword is wrong: `0x8FFF_EFFC` is above
`0x2000_0000`, so it is served by the **error slave**, which returns zeros with
`rresp=OKAY`. `0x0000` has `inst[1:0]==2'b00`, so IPACK treats it as a 16-bit
(illegal) instruction and never sets `h0_vld` — the straddling case never forms,
and `ipack_expt_high` / `pop_entry_expt_high` / `ifu_idu_id_expt_high` stay
uncovered. Getting them needs real code whose last two bytes fall on an
inaccessible page, i.e. an Sv39 mapping, because there is no physical region that
both holds loadable code and abuts a fetch-denied one.

Instruction **page fault** likewise needs the full Sv39 + S-mode apparatus
(`utlb_page_fault` is gated on `regs_mmu_en && !mach_mode`). Both therefore live
in the group gated behind `IFU_MMU`, default off, along with the
runtime-code-generation group behind `IFU_JIT`.

### OPEN ISSUE: a runtime cliff between 200 and 400 iterations

**`IFU_ITERS` is 200, which is verified. Do not raise it without re-measuring.**

Measured, and unexplained:

| `IFU_ITERS` | simulated time | wall |
|---|---|---|
| 200 | 0.594 ms -- completes, TEST PASS | 20 s |
| 400 | **> 15 ms** -- hit the `+MAX_SIM_TIME` cap | 969 s |
| 1200 | **> 20 ms** -- hit the cap | 647 s |

Twice the iterations costs at least twenty-five times the simulated time. What
this is *not*: a hang. The core kept retiring throughout -- the 50 000-cycle
no-retire watchdog never fired, the runs stopped on the simulation-time limit --
and the simulation rate held steady at ~30 us/s. So it is cost, somewhere, that
grows far faster than the iteration count.

Ruled out, by replaying the dispatch sequence offline against the real PRNG and
seed:

- **Not group 39 (`enable_mix`) running a heavy body with the I-cache off.** That
  was the first hypothesis and it is wrong: the combination (`IE` cleared, body =
  group 8's 48 KB sled) fires at **iteration 135**, inside the run that completes
  in 0.594 ms.
- **Not a newly-appearing group.** The only group whose first occurrence is past
  400 is group 34 (`delay_branch`, first at iteration 414). Group 32 (`ras_16m`)
  first fires at 199, inside the passing run.
- **Not group 8's sled by frequency.** It is selected 5 times before iteration
  200 and 7 more between 200 and 400; even at ~100 k cycles a visit that is under
  a millisecond.
- **Not an unrestored `MHCR.IE`.** Both groups that clear it (12 `noncacheable`,
  39 `enable_mix`) save and restore it, and `MHCR_WMASK` does not drop bit 0.

The most likely remaining explanation is persistent state degradation -- some
group leaving a predictor, prefetch or cache-enable bit in a slow configuration
that nothing puts back, since `rand_restore_sane_state()` runs only every 4096
iterations and therefore never runs at all in these short runs. That is a
hypothesis, not a conclusion.

**The next diagnostic step is small and decisive:** read `mcycle` around each
group body, accumulate per-group cycle totals, and print them beside the hit
counts in `report()`. One 400-iteration run with a generous cap would then name
the group. Worth doing before this case goes into a regression at any iteration
count above 200.

Note separately that IFU port toggle reads 90/107 at 200, 400 and 1200
iterations alike -- the front-end interface saturates immediately, so extra
iterations buy line and branch coverage here, not toggle.

Unreachable: `refill_error` (`aq_ifu_icache.v:960-968`), `pf_err_ff`
(`:1138-1145`), `biu_icache_ref_err` (`:864`) and the AXI-error leg of
`icache_ipack_acc_err` (`:1332`) — `axi_err128.v:208,211` returns `rdata=0` with
`rresp=2'b00` (OKAY), so **no AXI error response exists on this SoC**; a fetch at
or above `0x2000_0000` returns zeros, i.e. a clean illegal-instruction trap.
Also `rtu_ifu_dbg_mask`, the `aq_ifu_vec.v` HALT state and the debug-mode
injected instruction (JTAG only); the RESET/WARM_UP states (once, before software
runs); indirect-branch prediction (`mhcr[7]` IBPE hardwired 0) and any loop
buffer (`mhcr[12]` L0BTBE hardwired 0); `cjltype_vld0/1` (C.JAL does not exist in
RV64). There is no misaligned-fetch exception in this core.

---

# Appendix A — Risk register

| # | Risk | Status / mitigation |
|---|---|---|
| R1 | A livelock that retires is only caught by `MAX_RUN_TIME` = 3e9 ns ≈ 7 h of wall time, and `make` had no way to shorten it | **Fixed**: `SIM_ARGS` pass-through added to `runcase`; every `run_groups.sh` defaults to a short `+MAX_SIM_TIME` |
| R2 | Stimulus-only means arithmetic bugs in IU/VIDU pass silently | **Accepted** by explicit decision; stated in §1; the hook is a future `-D<U>_CHECK` |
| R3 | Executing random words would destroy the test, not the DUT | **Prevented**: whitelisted encoding tables only; written into `idu_random`'s file header |
| R4 | The `jr` tail-call retirement stall is squarely in `ifu_random`'s target area | `-fno-optimize-sibling-calls -fno-jump-tables` everywhere; the arena has zero computed jumps; the runtime-codegen group is gated off. Root cause is a null `.bss` function-pointer table in CSI-NN2, not a `jalr` bug — `jalr ra, rs, 0` works |
| R5 | `-fno-jump-tables` turns the dispatcher into a compare chain, biasing IFU/IDU stimulus | Accepted: the dispatcher runs ~16 highly predictable branches per iteration against hundreds inside each arena block. Revisit if the BHT numbers look dispatcher-dominated |
| R6 | `main` inherits `mstatus.MIE=1` and crt0's broken trap table | **Fixed**: `rand_trap_init()` clears MIE as its first instruction |
| R7 | Invalidate-without-clean loses dirty lines; runtime codegen has an ordering trap | `DCACHE_SAFE_POINT()` and `RAND_ICACHE_SYNC()` exist so both sequences are written once |
| R8 | 256 KB `.text`+`.rodata` budget vs a test that wants to thrash a 32 KB I-cache | Conflict, not capacity, is the lever (16 KB alias stride); arena size is a build-time argument; the generator's `--check` asserts it fits |
| R9 | `--x-assign fast` masks X bugs and makes toggle baselines simulator-specific | Two baselines per unit (Verilator + VCS); the new `x_cycles` column makes the discrepancy visible; VCS is authoritative for sign-off |
| R10 | Absolute coverage percentages are meaningless | The `coremark MON=all` run is the reference; everything is a delta; `--top-cold` output is triaged and recorded |
| R11 | Randomising the enable bits disables the thing under test | `ifu_random`'s `enable_mix` biases 7:1 toward enabled, always restores, and prints the enabled fraction so the loss is auditable from the log |
| R12 | D-cache-on UART writes are silently dropped by the testbench | `rand_report_begin()`/`_end()` bracket every print |
| R13 | Reproducibility depends on the toolchain, not just the seed | The §6 record block is mandatory; turned into an asset by the `<U>_OPT` knob |
| R14 | Five monitors sampling ~600 ports every posedge is not free | `MON=all` is for measurement runs, never soaks; per-case default is one monitor |
| R15 | VCS `-cm` can change race resolution | Always reproduce a coverage-run failure without `-cm` before investigating |
| R16 | `SIM=iverilog` cannot compile any of the five cases (the `+define+` arrives via a `-f` filelist) | `smart_cfg.mk` emits a `$(warning)` for that combination |

# Appendix B — Provenance

The RTL facts in this document come from a multi-agent audit of
`gen_rtl/{ifu,idu,iu,vidu}/rtl/` plus the CP0, MMU, RTU, HPCP and SoC files they
depend on, with each finding cited to file:line and the load-bearing ones
re-verified by hand (the sysmap strong-order flags, the `aq_vidu_top.v` vector
tie-off, the Xtheadc encoding table, the error-slave `rresp`, and the
`aq_vidu_vid_wbt_entry.v` one-bit `cnt`). Where a claim was only inferred and not
verified, this document says so.

Measured numbers — toggle counts, coverage percentages, cycles per iteration,
wall times — are recorded in `doc/results/unit_random_runlog.md` with the full
§6 record block, and are **not** duplicated here.
