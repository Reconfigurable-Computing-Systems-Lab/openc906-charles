# `rand_common/` — shared harness for the per-unit randomized stress tests

Used by `iu_random`, `vidu_random`, `idu_random` and `ifu_random`.
Methodology and per-unit group tables: `doc/specs/unit-random-tests.md`.
The original of this pattern is `cp0_random` (`doc/specs/cp0-design-and-test.md`
Part II).

## What is here

| File | Contents |
|---|---|
| `rand_common.h` | typedefs, `CSR_*` access macros, `TH_OP`/`RAW_OP`/`RAW_OP16`, `DCACHE_SAFE_POINT()`, `RAND_ICACHE_SYNC()`, the safe-GPR list, and every prototype |
| `rand_csrs.h` | CSR numbers, writable-bit masks, CLINT/PLIC/UART addresses, the `rand_ctx` layout, and the **address-window rules** (which physical addresses are safe to fetch from and which will break the test) |
| `rand_th_insn.h` | raw `.word` encodings of the T-Head cache/sync ops and the whole Xtheadc arithmetic / bit-manipulation / indexed-memory family, plus the RVC halfwords and illegal encodings the assembler will not emit on request |
| `rand_trap.S` | `rand_ctx` in `.bss`; `rand_trap_init`; the M handler (cause histogram → nested-trap bail → fault-return → step over `mepc`); the S handler; `rand_setjmp`/`rand_longjmp`; `rand_run_in_smode`/`_umode`; `rand_run_at` |
| `rand_lib.c` | xorshift64 PRNG, `rand_restore_sane_state()`, `rand_pmp_open_everything()`, `rand_arm_lpmd_wake()`, the D-cache-off UART printer, `rand_hist_dump()` |

## Rules

These exist because `tests/lib/Makefile` globs `work/*.c work/*.s work/*.S` and
links every resulting object, and because `make cleancase` deletes `work/*.v`.

1. **Build recipes enumerate files.** Never `cp dir/*` — that is why
   `cp0_random_build` and the four new recipes list each file by name. A stray
   `.c` in `work/` gets compiled and linked into the case.
2. **Exactly one `.c` and one `.S` live here.** A second `.c` would be compiled
   into all four cases whether they want it or not. Optional code goes in a
   header as `static inline`, or in the per-case source.
3. **Every shared symbol is `rand_`-prefixed.** `LINKLIBS` has no
   `-Wl,-z,muldefs`, so a collision with a case-local helper is a hard link
   error — loud, not silent.
4. **No newlib stdio.** `rand_putu` formats digits by hand; pulling in `printf`
   would drag in newlib's `write` and a much larger `.text`.
5. **`main()` starts with `rand_trap_init()` then `rand_pmp_open_everything()`.**
   `crt0.s` sets `mstatus.MIE=1` while `mtvec` still points at its own
   `vector_table`, whose entries are `.long` (4 bytes) but are loaded with `ld`
   (8 bytes) — so any trap before `rand_trap_init()` is an infinite exception
   loop. `rand_trap_init()` clears MIE as its first instruction so the ordering
   cannot be forgotten.

## Deliberately *not* shared with `cp0_random`

`cp0_random` keeps its own `cp0_trap.S` / `cp0_csrs.h` / `cp0_th_insn.h`. That
is not an oversight:

- It is working, committed and **baselined** (169/201 ports toggled,
  `recovered=0`, all 42 groups verified individually). Refactoring it buys
  nothing functional and risks the one artifact that gives this whole
  methodology its credibility.
- `cp0_trap.S` is not generic. It carries `cp0_trap_m_vectored` (mtvec mode-1
  dispatch), `cp0_trap_m_toM` + `CTX_MODE_RET`, the per-source CLINT/PLIC
  interrupt teardown, `cp0_sret_land` and `CP0_FORCE_BAIL`. A handler that
  satisfied both cp0's needs and the four new units' would be the union of the
  two — more code, and more risk in cp0's path than it has today.

The cost is one duplicated ~250-line handler skeleton. **If you fix a bug in
`rand_trap.S`, check `cp0_trap.S`, and vice versa.**

## Address windows (the short version)

Full table with provenance is in `rand_csrs.h`.

| Range | Verdict |
|---|---|
| `0x0000_0000`–`0x0016_3830` | safe: wiped and loaded by `tb.v:98` |
| `0x0100_0000` + `input.pat` length | safe: the NN-input window `tb.v` loads |
| `0x0016_3840`–`0x0FFF_FFFF` | **never touch**: not wiped, reads X under VCS |
| `0x1000_0000`–`0x1FFF_FFFF` | **never fetch**: AXI→AHB→APB cannot service a 4-beat WRAP refill |
| `0x2000_0000`+ | safe to fetch: error slave returns zeros with `rresp=OKAY`, i.e. a clean illegal-instruction trap |
| `0x8FFF_F000`+ | sysmap region 1, strong-order: **instruction access fault** with no M-mode escape — the fault lever, reached via `rand_run_at()` |
