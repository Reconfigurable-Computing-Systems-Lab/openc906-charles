# OpenC906 CP0 — Design Reference and Stress Test

This document covers the `cp0` unit of the T-Head OpenC906 in two parts:

- **Part I (§1–§15) — functional reference.** What the unit is, how it is built,
  and how it behaves, derived entirely from the RTL in
  `C906_RTL_FACTORY/gen_rtl/cp0/rtl/` (15 files, 9,989 lines). Every claim
  carries a `file:line` reference into that directory unless another path is
  given. Where a statement is an inference rather than something the RTL states
  outright, it is labelled as such.
- **Part II (§16–§23) — the `cp0_random` stress test.** A `smart_run` case that
  executes ~100,000 randomly selected CP0-touching instruction sequences from a
  reproducible seed, plus a generated monitor that reports which of
  `aq_cp0_top`'s 204 ports the run actually stimulated.

No document in this repo states a single C906 CSR address; the addresses here all
come from the parameter block at `aq_cp0_regs.v:635-939`, which is the
authoritative map for this RTL. The manuals in `doc/pdfs/` are CID-encoded
Chinese PDFs with no `/ToUnicode` table and could not be text-extracted in this
environment — see §24.

---

# Part I — Functional reference

## 1. What CP0 is

**CP0 is the core's control-and-status unit.** It plays three roles at once:

1. **CSR file owner** — machine/supervisor trap state, `satp`, floating-point
   state, and the whole T-Head (Xtheadc) extension register set.
2. **An EX1-stage execution unit** — IDU issues CSR, `ECALL`/`EBREAK`,
   `MRET`/`SRET`/`DRET`, `WFI`, `FENCE`/`FENCE.I`/`SFENCE.VMA`/`SYNC` and
   cache-maintenance instructions to it like any other functional unit.
3. **The core's control plane** — it broadcasts privilege mode plus every cache,
   branch-predictor, MMU and clock-gating enable to all other units; evaluates
   and prioritizes interrupts and computes the trap vector for RTU to take at
   retire; sequences cache/TLB/BHT invalidation; and generates the core-wide
   clock enable that `WFI` uses to stop the pipeline.

It is a **fan-out block, not a datapath block**: `aq_cp0_top` has 204 ports —
**73 inputs, 131 outputs** — and CSR read data leaves the unit only through the
RTU writeback port. Port distribution by peer unit:

| Direction | rtu | lsu | ifu | mmu | idu | hpcp | dtu | biu | vpu | pmp | iu |
|---|---|---|---|---|---|---|---|---|---|---|---|
| CP0 → peer | 27 | 21 | 19 | 17 | 14 | 10 | 9 | 2 | 4 | 4 | 1 |
| peer → CP0 | 15 | 5 | 6 | 3 | 15 | 3 | 4 | 8 | – | 1 | 1 |

### Why "CP0"?

RISC-V has no "coprocessor 0" — the spec calls this the CSR address space, and
most RISC-V cores name the equivalent unit `csr`. The name is inherited
terminology. The one concrete lineage clue in the RTL is `aq_cp0_info_csr.v:207`,
where MCPUID word 0 has the field comment *"CSKY V3 ISA Arch"*: this RTL descends
from T-Head's C-SKY line, where (as in MIPS, which originated the convention with
CP0 holding Status/Cause/EPC/TLB) the privileged register file was coprocessor 0.
The MIPS → C-SKY → C906 chain is inference from that field plus naming; only the
gloss "Coprocessor 0 (CSR / control-status registers)" is documented, at
`doc/results/aq_core_lvl1_inports.md:12`.

The legacy is still architecturally visible: the `mxstatus.cskyisaee` field
(`aq_cp0_ext_csr.v:643`) leaves CP0 as `cp0_idu_cskyee` (`:1196`) and gates decode
of the custom opcode groups in IDU (`aq_idu_id_decd.v:1005`; see also the comment
at `:912`).

---

## 2. Hierarchy

`aq_cp0_top` is instantiated once, in `aq_core.v:1936`.

```
aq_cp0_top                    pure wrapper — 3 child instances, no logic of its own
│                             except the cp0_dtu_debug_info concatenation
│                             {lpmd_state[1:0], fence_state[2:0], rst_op_done}
│                             and three tie-offs
├─ aq_cp0_iui                 EX1 instruction interface
├─ aq_cp0_regs                CSR address table, illegal decode, write strobes, read mux
│  ├─ aq_cp0_info_csr             read-only ID + MCPUID window
│  ├─ aq_cp0_trap_csr             all M/S trap state, interrupts, privilege mode
│  ├─ aq_cp0_prtc_csr             satp; PMP/MMU CSR feed-through
│  ├─ aq_cp0_hpcp_csr             counter access policy
│  ├─ aq_cp0_float_csr            fflags/frm/fxcr
│  └─ aq_cp0_ext_csr              T-Head extension CSRs; largest fan-out
└─ aq_cp0_special             special-instruction side-effect engine
   ├─ aq_cp0_lpmd                 WFI FSM + core clock enable
   ├─ aq_cp0_rst_ctrl             invalidation arbiter/barrier (5 FSMs)
   ├─ aq_cp0_cache_inst           combinational cache-op field splitter
   ├─ aq_cp0_fence_inst           6-state fence ordering engine
   └─ aq_cp0_vector_inst          stub (outputs hardwired to 0)
```

`doc/c906-hier.md` shows only the three level-1 children; that file scopes itself
to "the level-1 submodules of `aq_core`", so it is not wrong, but it gives no
visibility into the other 12 files.

The unit contains exactly **four** `gated_clk_cell` instances: `x_regs_clk` and
`x_regs_flush_clk` (`aq_cp0_regs.v:2183`, `:2208`), `x_special_clk`
(`aq_cp0_special.v:417`) and `x_float_clk` (`aq_cp0_float_csr.v:374`).

### File roles

| File | Lines | Role |
|---|---:|---|
| `aq_cp0_top.v` | 1054 | Pure wrapper. 204 ports (73 in / 131 out). No clock-gate cell. |
| `aq_cp0_regs.v` | 2242 | CSR hub. Owns the complete 12-bit address table (`:635-939`), the two-level illegal-address/privilege decoder, every per-CSR write strobe, the 64-bit read mux and the separate read-for-write mux. Stores almost no state itself. |
| `aq_cp0_iui.v` | 869 | EX1 instruction interface. The acronym is never expanded anywhere in the RTL (the banner says only "CP0 IUI Module"). Contains exactly **one** flip-flop. |
| `aq_cp0_special.v` | 486 | Structural wrapper + glue for the side-effect engine; composes the stall, routes fence/sync requests. |
| `aq_cp0_trap_csr.v` | 1439 | All M/S trap CSR state: `mstatus`/`sstatus`, `medeleg`/`mideleg`, `mie`/`sie`, `mip`/`sip`, `mtvec`/`stvec`, `mscratch`/`sscratch`, `mepc`/`sepc`, `mcause`/`scause`, `mtval`/`stval`. Delegation, privilege register, `mret`/`sret` status-stack pops, interrupt priority, `cp0_rtu_trap_pc`. |
| `aq_cp0_ext_csr.v` | 1276 | All T-Head extension CSR state and the MCINS/MCINDEX/MCDATA inspection window. The single largest fan-out block in the unit. |
| `aq_cp0_float_csr.v` | 441 | FP state — only **12 flops** (`fflags[4:0]`, `frm[2:0]`, `fxcr.bf16/dqnan/fe`) — plus the locally gated `float_clk` it exports back up for trap_csr's `mstatus.FS` flop. |
| `aq_cp0_info_csr.v` | 469 | Read-only machine-identification CSRs and the 7-word MCPUID configuration window. Its only sequential element is the 3-bit MCPUID index. |
| `aq_cp0_prtc_csr.v` | 190 | **"Protection and Translation"** per its own banner — *not* a timer, despite the abbreviation. No counter, no `mtime`/`mtimecmp`. Real state is `satp` only. |
| `aq_cp0_hpcp_csr.v` | 285 | Counter *access policy* only — no counters and no event logic (its header notes the counters are "instanced in HPCP"). Three 32-bit flops: `mcounteren`, `scounteren`, `mcountwen`. |
| `aq_cp0_lpmd.v` | 233 | WFI low-power FSM (IDLE/WAIT/LPMD) and generator of the core-wide `cp0_yy_clk_en`. |
| `aq_cp0_rst_ctrl.v` | 612 | Shared invalidation arbiter and barrier. Generates **no** reset — `cpurst_b` is an input — and holds no reset vector. |
| `aq_cp0_fence_inst.v` | 247 | 6-state ordering engine (FNC_IDLE/FENC/CDCA/CMMU/IICA/CMPLT). |
| `aq_cp0_cache_inst.v` | 84 | Purely combinational field splitter — no clock, no reset, no `always` block. |
| `aq_cp0_vector_inst.v` | 62 | Gutted stub. Both outputs hardwired, all five inputs dangling. |

The 15 files map 1:1 (alphabetically) onto `C906_asic_rtl.fl:15-29`. There are no
headers and no subdirectories, and **zero** `` `ifdef ``/`` `ifndef ``/`` `include ``
in the entire unit.

---

## 3. CSR access path

The 12-bit CSR address does **not** arrive from the opcode. It comes in on the
src1 operand bus: `iui_inst_imm[11:0] = idu_cp0_ex1_src1_data[11:0]`
(`aq_cp0_iui.v:444`).

Legality is split across two files by design:

| Check | Where | Logic |
|---|---|---|
| Address *fields* | `aq_cp0_iui.v:602-619` | read-only = `imm[11:10]==2'b11`; S-mode illegal = `imm[9:8]==2'b11`; U-mode illegal = `imm[9:8]!=2'b00` |
| Address *existence* | `aq_cp0_regs.v:968-1190` | `casez` over explicit constants, `default: regs_imm_inv = 1'b1` (`:1189`) |
| Extension windows | `aq_cp0_regs.v:1204-1309` | eight wildcard windows delegate to a second `case` whose `default: regs_ext_imm_inv = 1'b0` (`:1308`) — i.e. **legal** |

Reads are one large flat `case` into `regs_csr_rdata` (`:1526-1830`, default
`64'b0`). A **second, separate** mux produces `regs_csr_rdata_for_w` (`:1840-1849`).

Writes are one-hot `X_local_en = regs_csr_wen && imm==X` strobes (`:1316-1451`)
with three distinct qualification levels:

- fully qualified (the normal case);
- `*_no_imm_ill` for MCOR and MCINS — these fire **even when the address decoder
  says illegal**;
- `write_no_imm_ill` for SMCIR, which additionally bypasses the single-shot filter.

---

## 4. EX1 execution of system instructions

CP0 is a normal EX1 unit with a three-level valid handshake from IDU
(`aq_cp0_iui.v:434-437`):

| Signal | Qualifies |
|---|---|
| `gateclk_sel` | functional decode (and the CSR write side effect) |
| `dp_sel` | datapath / exception report |
| `sel` | completion and GPR writeback; additionally requires `rtu_idu_commit` |

Instruction class is one-hot in bits `[3:0]` of the 20-bit `idu_cp0_ex1_func`,
with subtype in `[9:4]` (`:462-549`):

| Bit | Class |
|---|---|
| `func[0]` | CSR |
| `func[1]` | privileged system — ECALL / EBREAK / MRET / SRET / WFI / DRET |
| `func[2]` | `fence.i` / `sfence` / `sync` / `sync.i` / cache ops |
| `func[3]` | `fence` and `vsetvl` |

The module's single flip-flop is `iui_csr_wen_f` (`:467-475`), a write-once guard
so that a CSR write which itself triggers a multi-cycle busy operation is applied
exactly once while the instruction is held in EX1.

**MRET/SRET redirect is generated in EX1**, not at retire:
`chgflw_pc = regs_iui_mepc/sepc` (`:728-746`).

Exception cause is a 4-bit priority encoder (`:650-675`), in this order:

```
page fault (12) > access fault (1) > IDU-reported illegal (2)
  > ECALL from M (11) > ECALL from S (9) > ECALL from U (8) > illegal (2)
```

Bit `[4]` of `cp0_rtu_ex1_expt_vec` is hardwired 0. `tval` (`:677-693`) is the EX1
PC — `+2` for the upper half of a split 32-bit instruction — for fetch faults and
debug-trigger cancels, and otherwise the full 32-bit instruction word.

Back-pressure to IDU: `cp0_idu_issue_stall = special_iui_stall` (WFI or fence)
`|| iui_csr_stall` (SMCIR waiting on `mmu_cp0_cmplt`, MCOR busy, MCINS busy)
(`:707-717`).

### Trap-on-privileged-instruction gating

`aq_cp0_iui.v:574-585` implements `mstatus.TSR`/`TW`/`TVM` plus a blanket U-mode
rule:

```verilog
iui_smode_special_inv = iui_smode && (mret
                                   || sret   && regs_iui_tsr
                                   || wfi    && regs_iui_tw
                                   || sfence && regs_iui_tvm);
iui_umode_special_inv = iui_umode && (mret || sret || wfi || sfence);
```

Both feed `iui_special_expt_vld` (`:588`) and hence the illegal-instruction cause.
`tsr`/`tw`/`tvm` are held at `aq_cp0_trap_csr.v:505-531`.

### Self-synchronizing CSR writes

Every CSR *write*, and every system instruction except CSR reads / `fence` /
`sfence` / `sync` / nop, asserts `cp0_rtu_ex1_flush` (`aq_cp0_iui.v:727-735` →
`:814`). This is the mechanism by which a CSR write takes architectural effect on
the following instruction without explicit hazard logic.

---

## 5. Trap, interrupt and privilege architecture

All M/S trap CSR state lives in `aq_cp0_trap_csr.v`, but **every architectural
update is driven by RTU retire signals, not by the EX1 pipe**: `mepc`/`sepc`
capture `rtu_cp0_epc`; `mcause`/`scause` capture `rtu_yy_xx_expt_int` and
`expt_vec`; the privilege register updates on
`rtu_yy_xx_expt_vld || mret || sret || rtu_cp0_exit_debug`.

**CP0 does not take the trap.** It evaluates 15 prioritized enabled-and-pending
interrupt conditions into `cp0_rtu_int_vld[14:0]` (`:1332-1338`) and supplies
`cp0_rtu_trap_pc[39:0]`. RTU makes the taken-trap decision at retire
(`retire_chgflw_pc = cp0_rtu_trap_pc`) and hands the result back for CP0 to latch.

Delegation is steered by a single signal
`mdeleg_vld_dp = medeleg_vld_dp || mideleg_vld_dp`, both of which require
`pm[1]==0` — so **delegation is structurally impossible while in M-mode**.

Effective privilege is `pm = pm_bits | {2{rtu_yy_xx_dbgon}}`, i.e. **debug mode
forces M-mode** for all accesses.

There is **no direct CLINT/PLIC connection**. The six `biu_cp0_*_int` pins come up
through sysio/cpuio from the CLINT and PLIC, which are siblings of `aq_top`
(see `openC906.v`), not of the core.

### T-Head local interrupts (causes 16–18)

`aq_cp0_trap_csr.v:1229-1232`:

```verilog
assign mhip = 1'b0;              // cause 18, PC-trace halt   — tied off
assign moip = hpcp_cp0_int_vld;  // cause 17, HPM overflow    — LIVE
// assign mcip = ecc_int_vld;
assign mcip = 1'b0;              // cause 16, error correction — commented out
```

So HPM counter overflow is a real interrupt source fed in from the HPCP, while
causes 16 and 18 are dead — which makes `mhip_nodeleg_vld`, `mhip_deleg_vld`,
`mcip_nodeleg_vld` and `mcip_deleg_vld` (4 of the 15 `int_sel` bits) unreachable.
Their delegation is doubly dead: `mhie_deleg = 1'b0` (`:815`),
`mcie_deleg = 1'b0` (`:817`); the register-name comments at `:807-809` confirm
the intent.

Cause 17 is not merely live but **reachable from software**: `mie[17]` (`:879`)
and `mideleg[17]` (`:826`) are both writable, and `hpcp_cp0_int_vld` is
`|(mcntinten & mcntof)` (`pmu/rtl/aq_hpcp_top.v:2674`), so writing MCNTINTEN
`0x7CA` and MCNTOF `0x7CB` raises it. Verified in simulation (§15).

### Which pending bits software can actually set

Only **SSIP (1), STIP (5) and SEIP (9)** have a software-writable register
behind them — `ssip_reg`/`stip_reg`/`seip_reg`, written from the MIP address
(`:1203-1227`). **MSIP (3), MTIP (7) and MEIP (11) are external-only**, wired
straight from `biu_cp0_ms_int`/`mt_int`/`me_int` (`:1234-1236`) with no register
at all, so they can be raised *only* from the CLINT and PLIC and cleared *only*
there. Two consequences that bite real code:

- an M-mode handler cannot dismiss MSIP/MTIP/MEIP through `mip`; it must write
  the CLINT (MSIP, or push MTIMECMP above MTIME) or claim+complete at the PLIC;
- symmetrically, a *delegated* STIP or SEIP cannot be dismissed from S mode at
  all, because a write to the SIP address only ever updates `ssip`
  (`:1216-1221`) — the S-mode handler has to mask the source in `sie` instead.
  Missing that produces an interrupt loop which, because it keeps retiring
  instructions, defeats a no-retirement watchdog.

### Deviations from the public RISC-V privileged spec

These are measured against the public spec, **not** against T-Head's own
documentation (see §11).

- **`mret` does not clear `mstatus.MPRV`.** The `mprv` flop
  (`aq_cp0_trap_csr.v:510-533`) has only two write arms: async reset (`:517`) and
  `else if(mstatus_local_en)` (`:524`, `wdata[17]`). Neither `mret`, `sret` nor
  trap entry touches it, and the bit really does gate load/store privilege via
  `cp0_lsu_mprv` → `ag_priv_mode`. **This is not a bug against the C906's declared
  architecture** — the user manual §1.5 pins C906 to Privileged Architecture
  **v1.10**, and `MPRV←0` on `xRET` was introduced in v1.11.
- **`mtvec[1]` always reads 0.** `mtvec`/`stvec` store `mode[1:0]` but the read
  value re-assembles as `{base, 1'b0, mode[0]}`, so only Direct and Vectored are
  observable.
- **Exception cause 0 can never be delegated.** The cause→one-hot decode
  (`aq_cp0_trap_csr.v:774-792`) covers causes 1–9, 11–13 and 15–18; causes 0, 10
  and 14 hit `default: vec_num = 19'h0`. So cause 0 cannot reach S-mode even with
  `medeleg[0]` set.
- **Writes via the SIP address update only `ssip`,** and only when `mideleg[1]` is
  set, even though `seip_acc_en`/`stip_acc_en` exist.
- `mcause`/`scause` implement a 1-bit interrupt flag plus a 5-bit cause only.

---

## 6. Debug-mode support

CP0 is the core's debug-mode control point:

| Mechanism | Where |
|---|---|
| Halt-on-exception hook: `cp0_dtu_mexpt_vld = rtu_yy_xx_expt_vld && !mdeleg_vld_dp` | `aq_cp0_trap_csr.v:1427` |
| DCSR/DPC/DSCRATCH0/1 illegal outside debug: `regs_imm_inv = !rtu_yy_xx_dbgon` | `aq_cp0_regs.v:1144-1147` |
| `ecall`/`mret`/`sret`/`wfi` decode suppressed by `&& !rtu_yy_xx_dbgon`; `dret` enabled only by `&& rtu_yy_xx_dbgon` — debug mode changes which system instructions CP0 recognizes at all | `aq_cp0_iui.v:522-533` |
| Privilege restored from `dtu_cp0_dcsr_prv[1:0]` on `rtu_cp0_exit_debug` | `aq_cp0_trap_csr.v:604` |
| `cp0_idu_dis_fence_in_dbg` from MHINT2[23] — disables fence in debug | `aq_cp0_ext_csr.v:920-928`, `:1199` |
| `cp0_dtu_pcfifo_frz` from MHINT[24] — freezes the debug PC FIFO | `aq_cp0_ext_csr.v:845-851`, `:1269` |
| `iui_cancel` (from `halt_info[TDT_HINFO_CANCEL]`) suppresses writeback/flush/chgflw and forces `tval` to the EX1 PC | `aq_cp0_iui.v:632`, `:728-746`, `:812` |
| Debug FSM state exported for visibility as `cp0_dtu_debug_info` | `aq_cp0_top.v` |

---

## 7. Distributed CSR ownership

A large fraction of the architectural CSR map is **decoded in CP0 but physically
implemented outside it**. `aq_cp0_iui.v:837-861` broadcasts the same
`{addr[11:0], wen, wdata[63:0]}` triple — unmodified and undecoded — to four
external blocks, each of which decodes for itself; CP0 then combinationally muxes
their return data into its read mux.

| Group | Registers | Read data from |
|---|---|---|
| PMP | PMPCFG0 `0x3A0`, PMPCFG2 `0x3A2`, PMPADDR0–15 `0x3B0-0x3BF` | `pmp_cp0_data` |
| Performance counters | MCYCLE `0xB00`, MINSTRET `0xB02`, MHPMCNT3–31 `0xB03-0xB1F`, MHPMEVT3–31 `0x323-0x33F`, MCNTIHBT `0x320`, MHPMCR `0x7F0`, MHPMSP `0x7F1`, MHPMEP `0x7F2`, MCNTINTEN `0x7CA`, MCNTOF `0x7CB`, CYCLE/TIME/INSTRET `0xC00-0xC02`, HPMCNT3–31 `0xC03-0xC1F`, SCYCLE `0x5E0`, SINSTRET `0x5E2`, SHPMCNT3–31 `0x5E3-0x5FF`, SCNTINTEN `0x5C4`, SCNTOF `0x5C5`, SCNTIHBT `0x5C8`, SHPMCR `0x5C9`, SHPMSP `0x5CA`, SHPMEP `0x5CB` | `hpcp_cp0_data` |
| TLB operations | SMIR `0x9C0`, SMEL `0x9C1`, SMEH `0x9C2`, SMCIR `0x9C3` | `mmu_cp0_data` |
| Debug + trigger | DCSR `0x7B0`, DPC `0x7B1`, DSCRATCH0/1 `0x7B2/3`, TSELECT `0x7A0`, TDATA1–3 `0x7A1-3`, TINFO `0x7A4`, TCONTROL `0x7A5`, MCONTEXT `0x7A8`, SCONTEXT `0x7AA`, MHALTCAUSE `0xFE0`, MDBGINFO `0xFE1`, MPCFIFO `0xFE2` | `dtu_cp0_rdata` |

Note that the architectural `time` CSR (`0xC01`) comes from the PMU's
`biu_hpcp_time` port — **there is no timer anywhere in CP0**.

What CP0 keeps for these groups is the **access-control policy**:

- `mcounteren` / `scounteren` / T-Head `mcountwen` live in `aq_cp0_hpcp_csr.v` and
  produce `regs_ucnt_inv` / `regs_scnt_inv` from a one-hot decode of `imm[4:0]`
  — which works because all three counter groups share the same low-5-bit offsets.
  `mcountwen` bit 1 (the `time` slot) is **forced to zero**, so S-mode can never
  be granted write permission to the time counter.
- S-mode legality of SHPMCR/SHPMSP/SHPMEP depends on an HPCP input,
  `hpcp_cp0_sce` (`aq_cp0_regs.v:1260-1262`).
- Two address-specific hooks: `regs_iui_trigger_mro` forces TINFO writes illegal;
  `regs_iui_trigger_smode` exempts SCONTEXT from the S-mode `0x3xx` block.
- SATP is gated by `regs_smode && regs_tvm`.
- An SMCIR write stalls the CSR pipe until `mmu_cp0_cmplt` returns.

### T-Head extension CSR addresses

| M-mode | | | S-mode | | U-mode | |
|---|---|---|---|---|---|---|
| MXSTATUS | `0x7C0` | MHINT2 | `0x7CC` | SXSTATUS | `0x5C0` | FXCR | `0x800` |
| MHCR | `0x7C1` | MHINT3 | `0x7CD` | SHCR | `0x5C1` | | |
| MCOR | `0x7C2` | MHINT4 | `0x7CE` | SCER2 | `0x5C2` | | |
| MCCR2 | `0x7C3` | MCINS | `0x7D2` | SCER | `0x5C3` | | |
| MCER2 | `0x7C4` | MCINDEX | `0x7D3` | SHINT | `0x5C6` | | |
| MHINT | `0x7C5` | MCDATA0 | `0x7D4` | SHINT2 | `0x5C7` | | |
| MRMR | `0x7C6` | MCDATA1 | `0x7D5` | | | | |
| MRVBR | `0x7C7` | MEICR | `0x7D6` | | | | |
| MCER | `0x7C8` | MEICR2 | `0x7D7` | | | | |
| MCNTWEN | `0x7C9` | MCPUID | `0xFC0` | | | | |
| | | MAPBADDR | `0xFC1` | | | | |

Declared windows: `0x5C0-0x5FF`, `0x7C0-0x7FF`, `0x800-0x8FF`, `0x9C0-0x9FF`,
`0xBC0-0xBFF`, `0xCC0-0xCFF`, `0xDC0-0xDFF`, `0xFC0-0xFFF`.

---

## 8. Core-wide machine-state and enable broadcast

This is what makes CP0 output-heavy. The extension registers in
`aq_cp0_ext_csr.v` are the core's global configuration knobs, and their bits leave
CP0 as named control wires.

**MHCR** (`0x7C1`) — cache and branch prediction. **All of these reset to 0, i.e.
caches and branch prediction are OFF out of reset.**

| Field | Drives |
|---|---|
| `ie` / `de` | I-cache enable / D-cache enable |
| `wa` | write-allocate (`wb` is tied constant 1 — write-back mode cannot be switched off) |
| `btbe` | `cp0_ifu_btb_en` |
| `bpe` | `cp0_ifu_bht_en` — note the bit named "bp**e**" drives the **BHT** enable |
| `rse` | `cp0_ifu_ras_en` |

**MHINT** (`0x7C5`) — prefetch enables and distance, I-cache way-predict (`iwpe`),
and `amr[1:0]`, which enables the LSU store-stream unit and selects its
consecutive-line threshold. Bit 24 is `pcfifo_freeze`.

**MXSTATUS** (`0x7C0`):

| Field | Effect |
|---|---|
| `cskyisaee` | gates custom-opcode decode in IDU |
| `ucme` | permits U-mode cache maintenance |
| `mm` | enables hardware unaligned load/store in the LSU |
| `maee` | makes the page-table walker take PTE[63:59] as memory attributes |
| `mhrd` | inverted into `cp0_mmu_ptw_en` — **setting it *disables* the hardware page-table walker** |
| `clintee` | gates the CLINT-sourced S-mode timer and software interrupts. Internal only — it never leaves CP0 (`aq_cp0_ext_csr.v:1162` → regs → `aq_cp0_trap_csr.v`), and unlike the cache/BP enables it **resets to 1** |
| `pmdm`/`pmds`/`pmdu` | per-privilege counter-disable, out to HPCP |
| — | also carries a non-standard live-privilege-mode field (`:643`, `:656`) |

**From `mstatus`/`satp`/`fcsr`:** `cp0_mmu_sum`/`mxr`; `cp0_lsu_mpp`/`mprv` (with
`mprv` overridden by `dcsr.mprven` in debug mode); `cp0_mmu_satp_data` with
`cp0_mmu_satp_wen` asserted in the same cycle as the write; `fcsr.frm` and
`fxcr.bf16`/`dqnan` to IDU and the VPU.

**MHINT2[22:14]** is a 9-bit `module_icg_en` vector (`aq_cp0_ext_csr.v:262`,
`:921-929`) that becomes eleven per-unit clock-gate enables. Verified sharing:

- bit 2 → `cp0_iu_icg_en` **and** `cp0_hpcp_icg_en` **and** CP0's own
  `regs_xx_icg_en`
- bit 4 → `cp0_mmu_icg_en` **and** `cp0_pmp_icg_en`

so IU/HPCP/CP0 and MMU/PMP cannot be clock-gated independently.

**Also exported:** `cp0_hpcp_int_off_vld`
(`= (pm==2'b11 && !mie_bit) || (pm==2'b01 && !sie_bit)`,
`aq_cp0_trap_csr.v:1364-1365` → `:1432`) so the performance counters can attribute
interrupts-disabled time.

---

## 9. Fence, cache maintenance and invalidation sequencing

CP0 turns single instructions into multi-cycle, ordered maintenance transactions.

**`aq_cp0_cache_inst.v`** — purely combinational field splitter
(`dst = func[1:0]`, `op = func[3:2]`, `type = func[5:4]`), covering the six
`th.dcache.{iall,call,ciall,isw,csw,cisw}` plus `th.icache.{iva,ipa}` forms. The
VA/PA dcache ops go to the LSU instead and never reach CP0; `th.icache.iall` is
re-encoded as `FENCE.I`; `th.l2cache.*` decodes to `dst=2'b00` and is therefore a
**silent no-op** in this core.

**`aq_cp0_fence_inst.v`** — 6-state ordering engine. The instruction-ordering
semantics live in the state chaining:

```
FNC_IDLE ─┬─ icache op        ──► IICA
          ├─ dcache op / fence.i ──► CDCA ──► IICA   (D-cache clean THEN I-cache inv)
          ├─ sfence           ──► CMMU ──► IICA      (TLB inv THEN I-cache inv)
          └─ else             ──► FENC
```

`FNC_FENC` waits on `lsu_cp0_sync_ack` for `sync`/`sync.i` (which also drains the
bus interface) versus `lsu_cp0_fence_ack` for `fence` (LSU buffers only).

**`aq_cp0_rst_ctrl.v`** — the shared arbiter/barrier behind all of it. It contains
**five** FSMs, not four:

| FSM | Line | Purpose |
|---|---|---|
| Reset | `:206-245` | 2-state `rst_cache_inv` (RST_IDLE/RST_WFC), entered by `ifu_cp0_rst_inv_req` (`:218`), left on `rst_inv_done = op_done` (`:243`); `cp0_ifu_rst_inv_done` at `:578` |
| ICACHE | `:290` | 3-state RST_IDLE/WFC/DONE |
| BHT | `:344` | " |
| DCACHE | `:396` | " |
| MMU | `:468` | " |

The four invalidation FSMs are driven by three request sources — post-reset
(which ORs into all four), fence phases, and MCOR writes (which have no MMU path)
— and joined by `op_done` = all four quiescent. That single `op_done` advances
each fence phase, drives `cp0_rtu_fence_idle`, and is what **holds IFU in its
RESET state after reset** until I-cache, BHT, D-cache and jTLB are all invalidated.
The fifth FSM is precisely the post-reset sequencer the module name refers to; the
module nevertheless generates no reset signal and holds no reset vector.

---

## 10. WFI low-power mode and the core clock enable

`aq_cp0_lpmd.v` is a 3-state FSM (IDLE/WAIT/LPMD) whose only entry trigger is
`WFI`. In WAIT it asserts `cp0_ifu_lpmd_req`, `cp0_mmu_lpmd_req` and an LSU sync
request (WFI reuses the store-buffer drain handshake), and enters LPMD only when
all three of `ifu_yy_xx_no_op`, `lsu_cp0_sync_ack` and `mmu_yy_xx_no_op` report
drained.

The mode holder `lpmd_b[1:0]` is deliberately clocked on the **ungated
`forever_cpuclk`** so wake-up can still be detected after the gated clocks stop.
Only `2'b11` (awake) and `2'b00` are ever loaded, so the 2-bit encoding carries no
extra information.

```
cp0_yy_clk_en = lpmd_b[1] & lpmd_b[0]
```

is the `global_en` of `gated_clk_cell` ICGs throughout the core (cp0, cpu, dtu,
idu, ifu, iu, rtu and the vector blocks) — this is the mechanism by which WFI
stops the pipeline. The state is also exported off-chip as
`cp0_biu_lpmd_b` → `core0_pad_lpmd_b` for external clock/power management.

Wake-up has exactly three sources: `dtu_cp0_wake_up`, `rtu_yy_xx_dbgon`, and
`regs_lpmd_int_vld` — an enabled-AND-pending interrupt OR that **deliberately
ignores privilege mode and delegation**.

One RTL-visible edge case: `rtu_yy_xx_flush` forces the FSM to IDLE but does not
clear `lpmd_b`, so a flush during low-power would leave the FSM idle with clocks
still gated, and recovery would still require a wake-up event.

---

## 11. Diagnostic and identification windows

**MCINS / MCINDEX / MCDATA0 / MCDATA1** (`0x7D2-0x7D5`,
`aq_cp0_ext_csr.v:999-1145`) form a RAM-inspection port. MCINS bit 0 is a
one-shot "go" flop and MCINS itself reads back 0 (write-only). MCINDEX supplies
`rid[3:0]` selecting I-cache tag / I-cache data / D-cache status-tag / D-cache
data plus way and index; the 128-bit result from `ifu_cp0_icache_read_data` or
`lsu_cp0_dcache_read_data` is latched into MCDATA0/1. Any other `rid` completes
immediately with no RAM read, and the L2 leg is tied off. Note the implied
geometry: the I-cache path uses a single way bit while the D-cache path uses two.

**MCPUID** (`0xFC0`) is a 7-word auto-indexed configuration window reporting ISA
family, revision, bus width (AXI128), PLIC/CLINT presence, BHT/BTB/cache sizes,
ways and line size, core count, and MMU/PMP zone counts. See §12 — reading it has
a side effect.

**Read-only ID registers** (`aq_cp0_info_csr.v`): `mvendorid = 64'h5B7` (T-Head's
JEDEC ID); `marchid` and `mimpid` both 0, with in-file "not implemented" comments;
`mhartid` from the 3-bit `biu_cp0_coreid` pin (so not a constant); `misa`
read-only at MXL=2 with A/C/D/F/I/M/S/U/X set and **V clear**. MRVBR and MAPBADDR
are read-only mirrors of the `biu_cp0_rvba` reset-vector and `sysio_cp0_apb_base`
pins.

---

## 12. Implementation facts and gotchas

Each of the following was independently re-derived from the RTL by a second agent
tasked with refuting it; the first two were additionally reproduced in simulation.

### Reading MCPUID mutates it

`mcpuid_local_en` (`aq_cp0_regs.v:1421`) is a bare address compare with **no write
qualifier**, and `aq_cp0_info_csr.v:169` advances a 3-bit index on
`iui_regs_csr_en && mcpuid_local_en`. Seven successive **reads** of `0xFC0`
therefore return seven different words. *Reproduced in module-level and full-core
SoC simulation.*

### All six vector CSRs trap as illegal instructions

VSTART `0x008`, VXSAT `0x009`, VXRM `0x00A`, VL `0xC20`, VTYPE `0xC21`, VLENB
`0xC22` appear in the parameter table (`aq_cp0_regs.v:774-779`) and in the read mux
(`:1668-1673`), but in **neither** illegal-decode `case` and they match no wildcard
window — so they fall through to `default: regs_imm_inv = 1'b1`. Their read-mux
entries are dead logic. *Reproduced in simulation.*

### The extension-window decode inverts the safe default

The stage-2 `case` ends in `default: regs_ext_imm_inv = 1'b0` (`:1308`), so
unimplemented addresses inside `0x800-0x8FF` and the unused parts of
`0x5C0`/`0x7C0`/`0x9C0`/`0xBC0`/`0xCC0`/`0xDC0`/`0xFC0` windows are treated as
**legal** and silently read `64'b0` instead of trapping.

### CSRRS/CSRRC on MIP/SIP operate on different data than a read returns

`regs_csr_rdata_for_w` returns the raw pending bits `sip_raw` for both MIP
(`0x344`) and SIP (`0x144`), while `regs_iui_rdata` returns the masked `sip_value`
(`aq_cp0_regs.v:1844-1847`). Two distinct read buses exist and feed different
consumers.

### Plain FENCE never enters the fence FSM

`|| iui_special_fence` is commented out of `fence_inst_vld`
(`aq_cp0_fence_inst.v:111`). FENCE is handled **entirely** by the stall term
`iui_special_fence && !lsu_cp0_fence_ack` (`:206`).

### MCOR's BTB invalidate bypasses the rst_ctrl barrier

`btb_inv` is set by `mcor_local_en` from `wdata[17]` and otherwise returns to 0
every cycle; the wait-for-IFU arms are commented out
(`aq_cp0_ext_csr.v:742-757`). It is a 1-cycle fire-and-forget pulse with no
completion handshake and no `op_done` arbitration — unlike every other MCOR
maintenance path.

### CSR write side effects are not commit-qualified

The CSR write is qualified only by `gateclk_sel`, while GPR writeback and
completion additionally require `rtu_idu_commit` (`aq_cp0_iui.v:434-437`).

### `aq_cp0_special.v` stall comment is stale

The comment lists three stall sources including a cache-inst term; only two exist
in the code (`lpmd || fence`).

---

## 13. Dead and inert logic

**The vector path is entirely inert.** VSTART/VXSAT/VXRM/VL are hard constants 0
in `aq_cp0_float_csr.v`; `vtype.vill` is stuck at 1; `mstatus.VS` and `XS` are tied
`2'b00` so `mstatus.SD` only ever reflects `FS==3`; the `rtu_cp0_vl`/`vstart`/`vxsat`
inputs reach no flop and survive only as clock-enable terms.
`aq_cp0_vector_inst.v` is a 62-line stub with both outputs hardwired and empty
tool-directive marker pairs showing where roughly 180 lines of `vsetvl` logic were
removed. `aq_cp0_iui.v` ties `iui_inst_vsetvl`/`_raw`/`_dp` to 0 and `aq_cp0_top.v`
ties `special_regs_vill`, `special_vsetvl_illegal` and `iui_inst_vsetvl_decd` to 0,
so the stub is consistently unreachable and `vidu_cp0_vid_fof_vld` is dead.

The reporting is internally inconsistent, though: `vlenb` reads `64'd16` with the
comment `//VLEN 128 bit` while `vtype.vill` is 1, `misa.V` is 0, and all six vector
CSR addresses trap anyway.

**Dangling inputs at the CP0 boundary:** `ifu_cp0_warm_up` (declared at
`aq_cp0_iui.v:142`, routed in from `aq_cp0_top.v:753`, three occurrences total, no
logic use), `vidu_cp0_vid_fof_vld`, and prtc's `smcir_local_en`.

**Dead interrupt paths:** the four `mhip`/`mcip` deleg/nodeleg bits of §5.

**Hardwired outputs** (confirmed by the port-toggle monitor of §22 never seeing
them move across a 100k-iteration random run): `cp0_lsu_we_en = 1'b0`
(`aq_cp0_ext_csr.v:1225`) and `cp0_lsu_dcache_wb = wb` (`:1223`), where `wb` is
itself the constant 1 (`:702`) — so D-cache write-back mode cannot be switched
off and the write-enable output is inert.

---

## 14. Configuration dependence

There are **zero** `` `ifdef ``/`` `ifndef ``/`` `include `` directives in all 15
cp0 files, so nothing in the unit is conditionally compiled. CP0 does depend on
three config macros for widths:

| Macro | Defined in | Used at |
|---|---|---|
| `` `PA_WIDTH `` (40) | `cpu/rtl/cpu_cfig.h:440` | `aq_cp0_iui.v:677-679`, `:689-691`, `:824` — `iui_ex1_pc`, `iui_expt_tval`, `cp0_rtu_ex1_expt_tval` |
| `` `TDT_HINFO_WIDTH `` | `dtu/rtl/aq_dtu_cfig.h` | `aq_cp0_iui.v:450-451`, `:826` |
| `` `TDT_HINFO_CANCEL `` | `dtu/rtl/aq_dtu_cfig.h` | `aq_cp0_iui.v:632` |

Plus the MCPUID word-1 fields, which read revision/geometry macros from
`cpu_cfig.h`.

A consequence of having no `` `ifdef ``: `misa_vector = 1'b0` and `misa_fd = 1'b1`
are **hardcoded** at `aq_cp0_info_csr.v:150-151`. The vector removal and the FD
declaration cannot follow a `cpu_cfig.h` change.

---

## 15. Addenda from the `cp0_random` bring-up

These were established while bringing up the `cp0_random` test of Part II, and
are either absent from the sections above or refine them. Everything here was
observed in simulation as well as read out of the RTL. Two further findings from
the same work are folded into the sections they belong to rather than repeated
here: which pending bits software can set (§5) and the two hardwired LSU
outputs (§13).

**`csrrs`/`csrrc`/`csrrsi`/`csrrci` with `rs1`/`uimm == 0` perform no write.**
`iui_csr_wen` requires `!iui_inst_rs1_x0` (`aq_cp0_iui.v:455, 463-465`), so these
forms never trap on a read-only CSR and never fire a write side effect. Only the
`csrrw`/`csrrwi` forms, and set/clear with a non-zero source, can.

**Reading MCPUID mutates it, but an illegal write does not.** §12's finding is
correct for reads; the write side is qualified, because
`iui_regs_csr_en = iui_inst_csr && !iui_csr_expt_vld` (`:775`). Since `0xFC0`
has a read-only address encoding, a write attempt raises cause 2 *and* leaves
the 3-bit index untouched.

**MCOR bit 4 drives both cache invalidates.** `wdata[4]` sets `icache_inv`
(`aq_cp0_ext_csr.v:800`) **and** `dcache_inv` (`:814`); which of them actually
issues is then selected by the separate, *persistent* `sel[1:0]` register
(`:828`). An op and its `sel` must therefore be written by the same instruction —
writing `sel` first and the op second works only by accident of the previous
value. Also note bit 4 invalidates **without** write-back, so any dirty line is
lost; the same is true of `th.dcache.iall`/`isw`/`iva`/`ipa`.

**`satp` can only ever hold MODE 0 or MODE 8.** The mode field write is gated on
`wdata[62:60] == 3'b0` and then forced to `{wdata[63], 3'b0}`
(`aq_cp0_prtc_csr.v:137-142`), so Sv48/Sv57 encodings are unrepresentable rather
than merely unsupported.

**MXSTATUS resets to `0x0000_0000_C06B_8000`.** `cskyisaee` (22), `maee` (21),
`clintee` (17), `ucme` (16) and `mm` (15) are all **1** out of reset — §8 says
this only for `clintee`. Bits 31:30 are a read-only live copy of the current
privilege mode, so MXSTATUS doubles as a privilege-mode read port. MHCR by
contrast resets to `0x108` (`wb` and `wbr` read 1 and are not writable).

**Clearing `MXSTATUS.cskyisaee` makes every `th.*` opcode illegal**, via
`decd_sel[3]`/`[4]` in the IDU (`aq_idu_id_decd.v:1003-1009`). §1 notes the field
gates custom-opcode decode; the observable effect is an illegal-instruction trap
on every cache/sync op, which is a decode path no other test in this repo covers.

**`th.icache.ialls` also re-encodes to `FENCE.I`**, like `th.icache.iall`
(`aq_idu_id_decd.v:3105`), and `hfence.vvma` (`0x22000073`) is decoded
unconditionally illegal — its hypervisor guard is commented out (`:865-866`).

**An mcontrol trigger with `action != 0` enters debug mode.** TDATA1 `0x7A1` is
decoded by CP0 but implemented in the DTU; arming it with a non-zero action on a
system with no debugger attached halts the core with no way back, so it is not
safe to write randomly.

**Not reachable from a bare-metal program**, and so not exercisable by a test
like `cp0_random`: everything behind `rtu_yy_xx_dbgon` (the DCSR/DPC/DSCRATCH
window, `dret`, `dtu_cp0_wake_up`, `rtu_cp0_exit_debug`, `dtu_cp0_dcsr_prv`)
needs JTAG — the `debug` case drives those; and instruction-fetch faults
(`idu_cp0_ex1_expt_acc_error`, `idu_cp0_ex1_expt_page_fault`) plus the split-
instruction upper half (`idu_cp0_ex1_expt_high`) need the fetch stream itself to
fault.

**On the demo SoC, an out-of-range load or store does not fault.** Accesses to
the `axi_interconnect128` error window (`0x2000_0000` upward,
`logical/axi/axi_interconnect128.v:367-368`) complete without raising cause 5 or
7, so load/store access faults are not producible that way. Misaligned accesses
with `MXSTATUS.mm` cleared (causes 4 and 6) are, and are the practical route to
LSU-sourced exceptions.

**Fourteen extension CSRs are legal but have no write enable at all.** MCCR2
`0x7C3`, MCER2 `0x7C4`, MRMR `0x7C6`, MCER `0x7C8`, MHINT3 `0x7CD`, MHINT4
`0x7CE`, MEICR `0x7D6`, MEICR2 `0x7D7` and the S-mode SHCR `0x5C1`, SCER2
`0x5C2`, SCER `0x5C3`, SHINT `0x5C6`, SHINT2 `0x5C7` read as constants and
silently discard writes — no trap, no effect. MRVBR `0x7C7` behaves the same way
but reads the `biu_cp0_rvba` reset-vector pin (`aq_cp0_ext_csr.v:952`), and SHCR
mirrors MHCR (`:735`). There is no `mrvbr_local_en` anywhere in the unit, so
despite what a register list implies, writing the reset-vector CSR is a no-op
rather than something dangerous. The §8 field tables should not be read as
implying MHINT3/MHINT4 are writable.

---

# Part II — The `cp0_random` stress test

A randomized stimulus test for everything Part I describes, plus the port-toggle
monitor that measures how much of it was reached. Sources live in
`smart_run/tests/cases/cp0_random/`.

## 16. What it is and is not

**It is** a *stimulus* test. It passes by running to completion without hanging:
`main` returns → `tests/lib/crt0.s` `__exit` materialises `0x444333222` → the
testbench sees it on an RTU writeback bus and finishes with `TEST PASS`
(`logical/tb/tb.v:320-331`).

**It is not** a self-checking test. There is no golden model in this repo and no
per-instruction comparison. Correctness evidence comes from two places instead:

| Evidence | Where |
|---|---|
| Nothing hung, deadlocked or wandered off | `TEST PASS` in `work/run_case.report`; the testbench's 50,000-cycle retire watchdog (`tb.v:265`) and its simulation-time limit are the failure detectors |
| CP0 was really exercised | `work/cp0_toggle.report` — per-port toggled-bit counts for all 204 `aq_cp0_top` ports |
| Traps went where expected | the trap-cause histogram printed over the UART into `work/run_case.report` |

Because there is no self-check, **robustness is the design constraint.** Two
mechanisms carry it: every group saves and restores the state it perturbs
(masked to that CSR's writable bits), and `restore_sane_state()` re-baselines
everything every 4096 iterations; and the trap handler unwinds to the loop head
via `cp0_longjmp` on any nested or unexpected trap, so a wild jump costs one
iteration rather than the run. The `recovered=` field in the summary counts how
often that happened — it should be 0.

---

## 17. Running it

```bash
# once per RTL change
make compile CASE=cp0_random SIM=vcs DUMP=off

# the full run
make runcase CASE=cp0_random SIM=vcs DUMP=off

# shorter, or a different seed
make runcase CASE=cp0_random SIM=vcs DUMP=off CP0_ITERS=5000
make runcase CASE=cp0_random SIM=vcs DUMP=off CP0_SEED=0xDEADBEEF

# waveforms
make runcase CASE=cp0_random SIM=vcs DUMP=on FSDB_SCOPE=core
```

`SIM=verilator` works identically and is what this case was brought up on
(macOS, Verilator 5.048). `SIM=iverilog` is **not** supported: the monitor's
`+define+` is delivered through a `-f` filelist, and `iverilog`'s `-c` filelists
accept filenames only.

Knobs, all overridable on the `make` command line
(`setup/smart_cfg.mk`):

| Variable | Default | Meaning |
|---|---|---|
| `CP0_ITERS` | `100000` | dynamic dispatch-loop iterations |
| `CP0_SEED` | `0x2024C906` | xorshift64 seed; fixes the whole sequence |
| `CP0_EXTRA` | empty | extra `-D` flags, e.g. `-DCP0_ONLY_GROUP=21` |

`make regress` picks the case up automatically now that it is in `CASE_LIST`.

### Bisecting

`tests/cases/cp0_random/run_groups.sh` builds and runs each operation group in
isolation via `-DCP0_ONLY_GROUP=n` and prints PASS / HANG / TIMEOUT per group.
This is how the case was brought up, and it is the first thing to run if a
future RTL change makes it fail:

```bash
bash tests/cases/cp0_random/run_groups.sh          # all 42 groups
bash tests/cases/cp0_random/run_groups.sh 21 21 40 # just group 21
```

Note the distinction the script relies on: a **stall** (nothing retires) trips
the retire watchdog within 50,000 cycles and is reported in seconds, whereas a
**livelock** (an infinite trap loop, which does retire instructions) is only
caught by the simulation-time limit — hence the script's deliberately short
default `SIMTIME=4e6`.

### Testing the recovery path

In a healthy run `recovered=0`, which means the `cp0_setjmp`/`cp0_longjmp`
unwind is never exercised — an untested safety net. `CP0_FORCE_BAIL` makes the M
handler treat `ebreak` as unrecoverable so the path actually runs:

```bash
make runcase CASE=cp0_random SIM=verilator DUMP=off \
     CP0_ITERS=2000 CP0_EXTRA=-DCP0_FORCE_BAIL
```

Expect a non-zero `recovered=` and still `TEST PASS` — i.e. the run absorbs
one abandoned iteration per `ebreak` and carries on. Measured: `recovered=38`
against `3=38` ebreak traps, so every bail was accounted for.

---

## 18. Files

| File | Role |
|---|---|
| `tests/cases/cp0_random/C906_CP0_RANDOM.c` | the driver: xorshift64 RNG, dispatch loop, the 42 operation groups, `restore_sane_state()`, UART summary |
| `tests/cases/cp0_random/cp0_trap.S` | M- and S-mode trap handlers, privilege-mode trampolines, `cp0_setjmp`/`cp0_longjmp` |
| `tests/cases/cp0_random/cp0_csrs.h` | CSR numbers, writable-bit masks, CLINT/PLIC/UART addresses, trap-context layout — each with its RTL provenance |
| `tests/cases/cp0_random/cp0_th_insn.h` | raw `.word` encodings for the T-Head cache/sync ops |
| `tests/cases/cp0_random/cp0_toggle_mon.v` | **generated** port-toggle monitor |
| `tests/cases/cp0_random/cp0_mon.f` | filelist adding the monitor + `+define+CP0_TOGGLE_MON` |
| `tests/cases/cp0_random/run_groups.sh` | per-group bisect harness |
| `cli_tools/gen_toggle_mon.py` | regenerates the monitor from `aq_cp0_top.v` (`--unit cp0`); shared with the four per-unit stress tests |

Plus three small hooks outside the case directory:

- `logical/tb/tb.v` — guarded `cp0_toggle_mon` instantiation.
- `setup/smart_cfg.mk` — `CASE_LIST` entry, `cp0_random_build` recipe, and the
  `SIM_FILELIST` override that pulls in `cp0_mon.f`.

### Two implementation constraints worth knowing

**T-Head ops are emitted as raw `.word`, not mnemonics.** On macOS the
toolchain runs with `THEAD_GCC=0` (`setup/mac_setup.sh`), i.e.
`-march=rv64imafdc_zfh_zicsr_zifencei`, which has neither `xtheadcmo` nor
`xtheadsync`. Raw words assemble identically under the server's Xuantie GCC, so
one source builds in both places. The IDU sub-decodes these on
`{inst[25], inst[24:20], inst[19:15]}` only (`aq_idu_id_decd.v:3002`), so
`inst[31:26]` is a don't-care.

**`tp` (x4) permanently holds `&cp0_ctx`.** `tp` is a fixed register in the
RISC-V ABI — GCC never allocates it — and this is a single-threaded bare-metal
build with no TLS. That gives the trap handler a scratch base without stealing
`mscratch`/`sscratch`, both of which the test writes randomly. The test also
installs its own `mtvec`/`stvec` rather than using `crt0.s`'s `vector_table`,
whose entries are `.long` (4 bytes) while the dispatcher loads them with `ld`
(8 bytes) — the infinite-loop bug in `CLAUDE.md` § Known Bugs.

---

## 19. Coverage matrix

42 groups. Groups 0–31 are the main rotation (`r % 32`); groups 32–41 are rarer
and more expensive, so they ride a second sparser selector (`(r >> 32) % 64`)
instead of diluting the rotation. `-DCP0_ONLY_GROUP=n` reaches any of them.

### CSR-file mechanics — `aq_cp0_regs.v`, `aq_cp0_iui.v`

| # | Group | What it targets |
|---|---|---|
| 0 | `safe_rw` | 18 read/write CSRs × `csrrw`/`csrrs`/`csrrc`, masked random data, save/restore. The flat read mux (`:1526-1830`) and the one-hot write strobes (`:1316-1451`). |
| 1 | `imm_forms` | `csrrwi`/`csrrsi`/`csrrci` — the `func[9]` immediate-source select |
| 2 | `no_write` | `csrrs`/`csrrc` with `rs1 == x0`, which perform **no write** (`aq_cp0_iui.v:455, 463-465`) and so must not trap even on a read-only CSR |
| 3 | `read_only` | read then write MVENDORID/MARCHID/MIMPID/MHARTID/MISA/TINFO/MHALTCAUSE/MDBGINFO/MPCFIFO/CYCLE — every write must raise cause 2 |
| 4 | `ro_zero` | MCCR2/MCER/MCER2/MRMR/MRVBR/MHINT3/MHINT4/MEICR/MEICR2/SHCR/SHINT/SHINT2/SCER/SCER2: **legal, no write enable at all**, silently dropped, no trap |
| 5 | `trap_illegal` | the `default: regs_imm_inv = 1'b1` path (`:1189`) — 0x000, 0x3A1, 0x3A3, 0xB01, 0x5E1, 0x7B4, … |
| 6 | `vector_ill` | VSTART/VXSAT/VXRM/VL/VTYPE/VLENB and `vsetvli` — all always illegal |
| 7 | `legal_hole` | unimplemented addresses **inside** the eight extension windows: legal, read 0 (`default: regs_ext_imm_inv = 1'b0`, `:1308`). The most easily mis-modelled corner of the map. |
| 8 | `mcpuid` | 1–8 consecutive reads of `0xFC0`, whose 3-bit index advances on **every read** (`aq_cp0_info_csr.v:167-172`); plus an illegal write, which must **not** advance it |
| 9 | `mip_rmw` | `csrrs`/`csrrc` on MIP/SIP, which read-modify from `sip_raw` rather than the value a plain read returns (`:1840-1849`) |

### Extension CSRs and the core-wide enable broadcast — `aq_cp0_ext_csr.v`

| # | Group | What it targets |
|---|---|---|
| 10 | `mhcr` | `ie`/`de`/`wa`/`btbe`/`bpe`/`rse` (mask `0x77`). A `th.dcache.ciall` precedes any write that clears `de`, so no dirty line is stranded. |
| 11 | `mhint` | prefetch enables and distance, `iwpe`, `amr[1:0]`, `pcfifo_freeze` (mask `0x0100651C`) |
| 12 | `mhint2` | the 9-bit `module_icg_en` (bits 22:14) + `fence_in_dbg_dis`. Bit 16 gates IU, HPCP **and** CP0's own `regs_clk`/`regs_flush_clk`/`special_clk` — the most disruptive legal write in the map. |
| 13 | `mxstatus` | `ucme`/`mm`/`maee`/`mhrd`/`clintee`/`pmdm`/`pmds`/`pmdu`, plus a misaligned access with `mm` clear. Read-back shows bits 31:30 mirroring the live privilege mode. |
| 14 | `theadisaee_off` | clears MXSTATUS bit 22 and issues a `th.*` op, which must then be illegal (`aq_idu_id_decd.v:1005`) — a decode path nothing else in the repo covers |
| 15 | `sxstatus` | writes reach only `mm`/`pmds`/`pmdu`; everything else must read back unchanged |
| 16 | `mcor` | BTB-invalidate (bit 17, the fire-and-forget pulse with no `op_done` arbitration), BHT-invalidate, clean, invalidate. Op and `sel[1:0]` written together, because bit 4 drives both `icache_inv` and `dcache_inv` and `sel` is a persistent register. |
| 17 | `mcins` | the MCINS/MCINDEX/MCDATA RAM-inspection window across all 16 `rid` values — 0/1 I-cache tag/data, 2/3 D-cache, 4–15 the self-completing no-op leg — plus the MCINS-busy EX1 back-pressure |

### System instructions, fences, cache maintenance, WFI

| # | Group | What it targets |
|---|---|---|
| 18 | `cache_cp0` | `th.dcache.{call,iall,ciall,csw,isw,cisw}` (executed inside CP0) and `th.l2cache.{call,iall,ciall}`, which decode to `dst=2'b00` and are **silent no-ops** in this core |
| 19 | `cache_va` | `th.dcache.{cva,cval1,civa,iva,cpa,cpal1,cipa,ipa}` and `th.icache.{iva,ipa}` — these dispatch to the LSU or split into two uops, but they complete the decode matrix and drive CP0's UCME gate |
| 20 | `fence` | all six fence-FSM states. `fence` never enters the FSM at all (`aq_cp0_fence_inst.v:111,198`); `sfence.vma` always chains CMMU→IICA so it invalidates the I-cache too; `th.icache.iall`/`ialls` are re-encoded as `fence.i` |
| 21 | `wfi` | the LPMD FSM, `cp0_yy_clk_en`, `cp0_biu_lpmd_b` — see §20 for why arming this correctly is subtle |

### Traps

| # | Group | What it targets |
|---|---|---|
| 22 | `ecall_ebreak` | cause 11 from M, and `ebreak` (cause 3, forwarded as `cp0_rtu_ex1_inst_ebreak`, not as an `iui_expt_vld`) |
| 23 | `illegal` | a reserved word, `hfence.vvma` (`0x22000073`, unconditionally illegal), `dret` outside debug, DCSR access outside debug |
| 24 | `debug_csrs` | TSELECT/TDATA2/TDATA3/TCONTROL, and DCSR/DPC/DSCRATCH0/1 which are illegal unless `rtu_yy_xx_dbgon`. **TDATA1 is deliberately never written**: an mcontrol trigger with `action != 0` enters debug mode and wedges a bare-metal run. |
| 25 | `fault` | misaligned load and store with `MXSTATUS.mm` clear (causes 4/6), and accesses outside the SRAM window. The store case is followed by a `fence` to pin an imprecise store error inside the group. |
| 26 | `tvec` | random `mtvec`/`stvec` base and mode, restored immediately; read-back confirms bit 1 always reads 0 and only `mode[0]` is visible |
| 27 | `vectored` | `mtvec.mode=1`, so an interrupt dispatches to `base + 4*cause` through a jump table |

### Privilege modes and delegation

| # | Group | What it targets |
|---|---|---|
| 28 | `smode` | `mret` to S, then one of eight bodies; TSR/TW/TVM randomised so the same body sometimes traps and sometimes does not (`aq_cp0_iui.v:574-585`) |
| 29 | `umode` | `mret` to U: counter reads gated by `mcounteren`, the U-mode extension window (FXCR), M/S CSRs (always illegal), `wfi`/`sfence` (always illegal), and a cache op gated by UCME |
| 30 | `delegate` | random `medeleg`/`mideleg`, then a trap from S so it lands in `cp0_trap_s`. `medeleg[8]`/`[9]` are always kept clear — ecall from U/S is how lower-mode code hands control back to M. |
| 31 | `int_soft` | SSIP/STIP/SEIP raised through `mip` and taken in M mode; also `MXSTATUS.clintee=0` |

### Interrupts and externally-implemented CSRs

| # | Group | What it targets |
|---|---|---|
| 32 | `int_deleg` | delegated STIP arriving through `sie`/`sip` and `cp0_trap_s` |
| 33 | `int_external` | the sources with no software-writable `mip` bit: CLINT MSIP (cause 3), CLINT MTIMECMP (cause 7), PLIC M context (cause 11), CLINT S-mode SSIP/STIMECMP (`biu_cp0_ss_int`/`st_int`), and the PLIC S context (`biu_cp0_se_int`) |
| 34 | `int_hpm` | cause 17, MOIP — the one **live** T-Head local interrupt, raised via MCNTINTEN + MCNTOF. Causes 16 and 18 are tied off in the RTL and unreachable. |
| 35 | `hpcp` | MCYCLE/MINSTRET/MHPMCNT3,31/MHPMEVT3,31/MCNTIHBT/MHPMCR/SP/EP and the U and S counter shadows |
| 36 | `cnt_policy` | `mcounteren`/`scounteren`/`mcountwen` → `regs_ucnt_inv`/`regs_scnt_inv`, checked by reading a counter from U mode. `mcountwen` bit 1 must read back 0. |
| 37 | `pmp` | PMPADDR1/7/15 and PMPCFG2; PMPCFG1/3 are not decoded and must trap. Entry 0 is never touched — see §20. |
| 38 | `mmu_tlb` | SMEH/SMEL/SMIR/SMCIR with all six ops (`invall` > `invasid` > `tlbp` > `tlbwi` > `tlbwr` > `tlbr`) plus the `mcir_no_op` leg; exercises the SMCIR stall until `mmu_cp0_cmplt` |
| 39 | `satp` | random Sv39 `{mode, asid, ppn}` **in M mode only**, and a `satp` access from S under TVM |
| 40 | `mprv` | `mstatus.MPRV` with `MPP` = M/S, plus SUM and MXR |
| 41 | `float` | FFLAGS/FRM/FCSR/FXCR, a real FP op to dirty `mstatus.FS` and light up SD, and an `FS=0` pass where the float CSRs *and* every F/D instruction must trap |

---

## 20. Safety rails, and why each exists

Each of these was added because the group hung or misbehaved without it. They
are the interesting output of bringing the test up.

**A WFI must have a wake armed that will not be taken as a trap first.** The
wake condition is `lpmd_ack_vld = |(mie & mip)`, which deliberately ignores both
privilege mode and delegation (`aq_cp0_trap_csr.v:1340`, `aq_cp0_lpmd.v:190`).
The naive sequence — set `mie[5]`, set `mip[5]`, enable `MIE`, `wfi` — hangs,
because the interrupt is taken *before* the WFI, the handler clears the source,
and the WFI then has nothing to wake it. A WFI with nothing armed is
unrecoverable short of reset. `arm_lpmd_wake()` therefore delegates STIP
(`mideleg[5] = 1`) with `sstatus.SIE` clear, which leaves a source that neither
M nor S mode will take but that still wakes the FSM — the privilege-blind wake
path §10 describes.

**The S-mode handler cannot clear a delegated STIP or SEIP.** A write to the SIP
address only ever updates `ssip`; `stip_reg` and `seip_reg` are explicitly held
(`aq_cp0_trap_csr.v:1216-1221`). A delegated STIP therefore re-traps forever —
and because that livelock *retires instructions*, the retire watchdog never
fires and only the simulation-time limit catches it. `cp0_trap_s` now masks the
source in `sie` as a fallback, which is writable from S mode for any delegated
bit.

**CLINT-sourced S interrupts cannot be cleared through `mip` either.**
`stip = biu_cp0_st_int && clintee || stip_reg`, so the M handler writes the CLINT
registers back as well as clearing `mip`.

**The PLIC S context is driven with `MIE` clear.** The M handler can clear
`seip_reg` but has no way to retract a PLIC-sourced `seip`, so the source is
raised, observed in `mip`, and torn down without ever being taken.

**A legal S-mode `sret` needs a real `sepc`.** With TSR clear, `sret` in S mode
is legal and jumps to `sepc` — which random groups have been writing garbage
into. `g_smode` points it at `cp0_sret_land` (with `SPP=1`, so we stay in S) and
clears `SPIE` so the `sret` does not pop `SIE` back to 1 and expose the WFI wake
source.

**Invalidate-without-writeback needs a clean first.** `th.dcache.iall`/`isw`/
`iva`/`ipa` and MCOR bit 4 discard dirty lines; doing that with a dirty stack
would make the test read stale globals and jump wild. `DCACHE_SAFE_POINT()`
(`th.dcache.ciall`) precedes every one of them, and every MHCR write that clears
`de`.

**PMP entry 0 spans everything, permissively.** With no matching PMP entry, S
and U mode are denied every access, so the privilege groups could not run at
all. Entry 0 is highest priority, which also makes whatever `g_pmp` writes to
entries 1–15 harmless. It is re-established after every `g_pmp` and by
`restore_sane_state()`.

**`satp` is only ever Sv39 while in M mode**, and `MPRV` is only ever set while
`satp` is Bare. Either alone is safe; together they would translate the test's
own M-mode loads and stores.

**`mstatus.MIE` is 0 outside the interrupt groups**, so interrupts only arrive
where the test asks for them. That removes a large class of nondeterministic
interactions — notably, it makes the write-then-restore windows in `g_tvec`
safe.

---

## 21. UART reporting, and a testbench fix

The end-of-run summary is printed over UART0. Getting it out needed two things:

1. **The D-cache has to be off.** UART0 is at `0x1001_5000`
   (`logical/apb/apb.v:232`), which is in a cacheable region
   (`mmu/rtl/sysmap.h` region 0), so a plain store lands in the D-cache and its
   eventual line writeback has `wstrb = 16'hffff` — which the testbench's
   decoder does not match. `report()` does `th.dcache.ciall`, clears `MHCR.DE`,
   prints, and restores. (Note `tests/lib/clib/uart.h` says `0x4001_5000`; that
   is stale for this SoC, like `timer.h`'s `SMART_TIMER_BASE`.)
2. **Characters need real separation.** Consecutive stores to the same address
   coalesce in the store buffer, and the testbench samples the AXI port for one
   cycle per write. `uputc` issues the store, then `th.sync` (which drains the
   bus interface, not just the LSU buffers as `fence` does), then spins briefly.

While tracking this down, a genuine bug turned up in the shared testbench and is
fixed in `logical/tb/tb.v`: the console decoder qualified on *registered*
`awaddr`/`awlen`/`wstrb`/`wvalid` but read `biu_pad_wdata` **live**, a one-cycle
skew that printed whichever byte happened to be on the bus a cycle after the one
that was qualified. `wdata` is now delayed alongside its qualifiers. This is why
UART output from tests was previously "best-effort" (see the comment in
`tests/cases/nn_model_common/bare_main.c:52`) and it benefits every case, not
just this one.

---

## 22. Reading the toggle report

`work/cp0_toggle.report` lists every `aq_cp0_top` port with its width, how many
of its bits ever changed value, and how many cycles it changed in:

```
port                               dir  width  bits_tog  tog_events
cp0_ifu_bht_en                     out      1         1         412
cp0_mmu_satp_data                  out     64        41        1907
...
SUMMARY: NNN/201 functional ports toggled (3 infrastructure ports excluded)
NEVER TOGGLED: ...
```

Three ports are classed as infrastructure and excluded from the percentage:
`cpurst_b`, `forever_cpuclk`, `pad_yy_icg_scan_en`. Note the classifier is
deliberately *not* the aggressive substring match used by
`cli_tools/extract_rc.py` — on this module that would also swallow
`cp0_yy_clk_en` (the WFI clock enable, the single most important output to watch),
`idu_cp0_ex1_gateclk_sel`, and the `rst_inv` invalidation handshake, all of which
are functional.

Regenerate the monitor after any change to `aq_cp0_top`'s ports:

```bash
python3 cli_tools/gen_toggle_mon.py --unit cp0 \
    --out tests/cases/cp0_random/cp0_toggle_mon.v
```

The generator is shared with the four per-unit stress tests
(`doc/specs/unit-random-tests.md`); `--unit` fills in the RTL path, the instance
path, the module name, the guard macro and the report filename. It also emits a
per-port `x_cycles` column, which exists because the accumulate guard is
whole-port: under a 4-state simulator one permanently-X bit records zero toggles
for the whole port, so Verilator and VCS toggle numbers are not comparable and
the column is what makes that visible rather than mysterious.

### Ports that will never toggle, and why

A non-empty `NEVER TOGGLED` list is expected. These are not coverage holes:

| Category | Ports | Why |
|---|---|---|
| Vector path (gutted) | `rtu_cp0_vl`, `rtu_cp0_vl_vld`, `rtu_cp0_vstart`, `rtu_cp0_vstart_vld`, `rtu_cp0_vxsat`, `rtu_cp0_vs_dirty_updt`(`_dp`), `vidu_cp0_vid_fof_vld`, `cp0_idu_vill`, `cp0_idu_vl_zero`, `cp0_idu_vlmul`, `cp0_idu_vs`, `cp0_idu_vsew`, `cp0_idu_vstart`, `cp0_idu_vsetvl_dis_stall`, `cp0_rtu_ex1_vs_dirty`(`_dp`), `cp0_rtu_vstart_eq_0` | `misa.V = 0`, all vector CSRs trap, `aq_cp0_vector_inst.v` is a stub — §13 |
| Needs a JTAG debugger | `rtu_yy_xx_dbgon`, `rtu_cp0_exit_debug`, `dtu_cp0_wake_up`, `dtu_cp0_dcsr_prv`, `dtu_cp0_dcsr_mprven`, `cp0_rtu_ex1_inst_dret` | debug mode is unreachable from a bare-metal program; `dret` is not even decoded unless `dbgon`. The `debug` case drives these over JTAG. |
| Hardwired constants | `biu_cp0_coreid`, `biu_cp0_rvba`, `cp0_xx_mrvbr`, `cp0_lsu_we_en` (`= 1'b0`), `cp0_lsu_dcache_wb` (`= wb`, itself constant 1) | tie-offs |
| Instruction-fetch faults | `idu_cp0_ex1_expt_acc_error`, `idu_cp0_ex1_expt_page_fault`, `idu_cp0_ex1_expt_high` | would require jumping into unmapped memory or straddling a split 32-bit instruction across a fault boundary; both risk the run rather than the unit under test, so they are out of scope here |

---

## 23. Baseline results

Verilator 5.048 on macOS (arm64), default seed `0x2024C906`, `CP0_ITERS=100000`,
`DUMP=off`. Reproduce with a bare `make runcase CASE=cp0_random SIM=verilator DUMP=off`.

```
[cp0_random] iters=100000 mtraps=63243 straps=4776 recovered=0
[cp0_random] M causes: 2=29959 3=1559 4=3803 6=803 8=4659 9=9569 11=1545
[cp0_random] M ints:   1=770 3=278 5=7412 7=257 9=800 11=272 17=1557
[cp0_random] S causes: 2=3183 i5=1593
TEST PASS
SUMMARY: 169/201 functional ports toggled (3 infrastructure ports excluded)
```

Cost: 52 ms of simulated time, 441 s wall (~119 µs/s). That is comfortably
inside the testbench's default 3 s `MAX_RUN_TIME`, so no `+MAX_SIM_TIME` plusarg
is needed. VCS will be substantially faster.

The full per-port report from that run is committed as
`doc/results/cp0_toggle_baseline.report` — diff a new run against it to see what
an RTL change moved.

All 42 groups also pass individually
(`bash tests/cases/cp0_random/run_groups.sh`), which is the check to run first if
the mixed run ever fails.

Notes on what the histogram shows:

- **All seven reachable interrupt causes fire**: 1, 3, 5, 7, 9, 11 and 17. Causes
  16 and 18 are tied off in the RTL and cannot be raised at all.
- **Exception causes 2, 3, 4, 6, 8, 9 and 11 fire.** Causes 5/7 (load/store
  access fault) do not, because out-of-range accesses on this SoC complete
  silently; 12/13/15 (page faults) do not, because the test deliberately keeps
  `satp` in Bare mode. 1 (instruction access fault) needs a faulting fetch.
- **`recovered=0`**: no iteration hit an unexpected or nested trap. If a future
  RTL change makes this non-zero, that is the signal to investigate.
- All 42 group counters are non-zero and, for the main rotation, even
  (~3100 each of 100000 — as expected for `r % 32`).

---

---

# Appendix

## 24. Provenance and caveats

**Part I** was produced by a 21-agent audit: one reader per file group plus an
integration reader and a documentation reader, a synthesis pass, nine adversarial
verifiers (each instructed to refute a specific load-bearing claim), and a
completeness critic. Roughly 25 claims were spot-checked against the RTL; none was
contradicted. Two claims came back `PARTLY_WRONG` and are corrected in place above
(the MPRV/v1.10 point in §5, and the file count).

**Part II** documents a test that was written against Part I and then run: every
group was brought up individually under Verilator before the mixed run, and the
safety rails in §20 each exist because a group hung or livelocked without it. The
numbers in §23 are from an actual run, not an estimate.

Known limits of the Part I audit:

- **The authoritative CSR chapters in `doc/pdfs/` were never read** —
  `c906-user-guide.pdf` and `openc906-datasheet.pdf` could not be text-extracted
  in this environment. Every "spec deviation" in §5 is measured against the public
  RISC-V privileged specification, not against T-Head's own documentation. The
  MPRV finding shows why this matters: what looks like a spec violation against
  v1.11 is correct behavior for the v1.10 the manual actually pins.
- Field-level bit positions were read from the RTL's own field maps and comments,
  not cross-checked against the manual.
- Behavior under scan/DFT modes was not examined.

### Repo documentation issues found along the way

- `doc/tb-reference.md` **does not exist**, yet it is cited at `CLAUDE.md:55`,
  `CLAUDE.md:121` and `.github/copilot-instructions.md:222`.
- `CLAUDE.md`'s `doc/` index is generally stale relative to the current
  `doc/{specs,results,pdfs}/` layout.
