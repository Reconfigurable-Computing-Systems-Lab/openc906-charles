# OpenC906 ASIC flow — how to run everything on the server

Server checkout: `/dfs/usrhome/jjiangan/github/hw_charles`.
Stage dependencies: `gen_sram` (once) → `syn` → `gls` → `ptpx`. The behavioral
sim is independent and is the functional reference.

## 0. Environment

```csh
cd /dfs/usrhome/jjiangan/github/hw_charles/smart_run
source setup/example_setup.csh      # sets CODE_BASE_PATH and the Xuantie GCC
```

## 1. Behavioral (RTL) simulation

```csh
make showcase                             # list cases
make runcase CASE=coremark SIM=vcs DUMP=on
make regress                              # all cases
```
Waveforms/logs in `smart_run/work/`; regress reports in
`tests/regress/regress_result/`.

## 2. SRAM generation (only when regenerating the macros)

```csh
cd impl/gen_sram
source gen_sram.sh          # runs the three TSMC N28HPC+ memory compilers
source cvrt_lib2db.sh       # lib -> db for synthesis/PT (lc_shell)
```
Outputs: `verilog/` (functional models, used by GLS) and `db/` (Liberty db,
linked by syn/ptpx). Both are committed, so this stage is normally skipped.

## 3. Synthesis (Design Compiler) — clock gating enabled

```csh
cd impl/syn
./run_dc.csh -mode syn                    # log: dc.log, outputs: batch_YYYYMMDD_HH/
```
Clock gating is on in two ways:
- `compile_ultra -no_autoungroup -gate_clock` with
  `set_clock_gating_style ... -positive_edge_logic {integrated}` — DC infers
  integrated clock-gating cells on register banks (min bitwidth 4).
- `gated_clk_cell_syn.v` replaces the RTL pass-through stub so the C906's own
  `gated_clk_cell` instances map to real TSMC ICGs (CKLNQD4BWP30P140).

Check `batch_*/reports/openC906.mapped.clock_gating.rpt` (gating coverage) and
`openC906.mapped.qor.rpt`. Netlist/SDF/SDC/DDC in `batch_*/results/`.

Interactive re-analysis of an existing run:
`./run_dc.csh -mode read_ddc -batch_dir batch_YYYYMMDD_HH`.

## 4. Gate-level simulation (SDF-annotated VCS)

```csh
cd impl/gls
make compile BATCH_DIR=../syn/batch_YYYYMMDD_HH
make runcase BATCH_DIR=../syn/batch_YYYYMMDD_HH CASE=coremark
```
- Reuses the smart_run testbench and case builder; only openC906 is the DC
  netlist. VCS runs in `smart_run/work_gls/`.
- SDF is annotated onto `tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top`
  (max corner, timing checks on, `+neg_tchk -negdelay`). The tb/SoC RTL outside
  the core simulates zero-delay.
- Gate-level FSDB + pass/fail report per case land in
  `impl/gls/results/<CASE>.{fsdb,report}` — the FSDBs feed PrimePower.
- Debug fallback without timing: add `NTC=1` (compiles with
  `+nospecify +notimingchecks`, no SDF) to separate functional netlist issues
  from timing/X problems.
- If the std-cell Verilog model paths differ on the server, adjust the four
  entries at the top of `impl/gls/gls.f`.

## 5. PrimePower (time-based, gate-level FSDB)

```csh
cd impl/ptpx/script
python3 run_ptpx_parallel.py \
    --in_dir ../../syn/batch_YYYYMMDD_HH \
    --clk_period 1 \
    --fsdb_list_file fsdb_run_list.txt \
    --max_jobs 8 --skip_completed
```
- `fsdb_run_list.txt` now points at the GLS FSDBs in `impl/gls/results/`;
  edit it (or use `--fsdb_names <file.fsdb> ...`) for a subset.
- The tcl (`run_power_timebased_replay.tcl`) reads the mapped DDC + SDC from
  the syn batch and replays each gate-level FSDB directly (no `-rtl`, no DC
  ptpxmap needed anymore). `--start_ns/--end_ns` window the FSDB.
- Reports per FSDB in `--in_dir`-relative output dirs: `*_power_hier.rpt`,
  `*_switching_coverage.rpt` (annotation coverage should be near 100% now that
  the activity is gate-level), plus a power-waveform FSDB.

## Sanity checks after each stage

1. RTL sim: case report says PASS in `work/run_case.report`.
2. Synthesis: `dc.log` free of errors; `*.clock_gating.rpt` shows a non-empty
   list of gating elements and a high % of gated registers.
3. GLS: `comp.gls.log` shows the SDF annotation completed; `run.gls.log` /
   `results/<CASE>.report` shows PASS.
4. PTPX: `*_switching_coverage.rpt` shows high annotated coverage;
   `*_power_hier.rpt` totals look sane vs. the DC power report.
