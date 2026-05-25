# openC906 Backend Flow (`smart_run/impl/`)

End-to-end ASIC implementation flow for the openC906 core on TSMC 28HPC+: SRAM
generation → Design Compiler synthesis → PrimePower (PTPX) time-based power
analysis → post-processing into CSV / DataFrames.

```
gen_sram/   ─►   syn/   ─►   ptpx/   ─►   *.csv  *.pkl
 (.v + .db)     (mapped       (per-case      (post-
                .v/.ddc/.sdc   *_pwr.fsdb     processed
                + ptpxmap)     + reports)     data)
```

## Directory layout

| Path | Contents |
|---|---|
| `gen_sram/` | TSMC mc-2 compiler driver scripts, `.lib`/`.v` macros, and `db/` (`.db` for DC/PT) |
| `sdc/` | Synthesis/STA constraints (`C906_TOP.sdc`, `tdt_dmi_top.sdc`) |
| `syn/` | Design Compiler flow (`run_dc.csh`, `dc.tcl`, `read_ddc.tcl`, `aq_f_spsram_shim.v`, `rpt2csv.py`) and timestamped `batch_<YYYYMMDD_HH>/` output dirs |
| `ptpx/` | PrimePower flow: `script/` drivers + Tcl, per-case `<case>/{reports,results}/`, aggregated `ptpx_summary.csv`, pickled DataFrames in `db/` |
| `MEM_INTF/` | Standalone ASIC memory + ICG bench (`aq_umc_spsram_wrappers.v`, `c906_*_mem_test.v`, `gated_clk_cell.v`); see `MEM_INTF/README` |

## Prerequisites

- TSMC 28HPC+ PDK: standard cells (`tcbn28hpcplusbwp30p140*`), SRAM compilers
  (`tsn28hpcpd127spsram_180a`, `tsn28hpcpuhdspsram_170a`, `tsn28hpcp1prf_130a`).
  Paths are hard-coded in the driver scripts.
- Synopsys: `lc_shell`, `dc_shell`, `pwr_shell`, `fsdbreport` on `PATH`.
- Python 3 with `pandas` (recommended: `~/anaconda3/bin/python`).
- For phase 3, gate-level FSDBs from a regression run (e.g.
  `smart_run/tests/regress/regress_result/<case>.fsdb`).

---

## Step 1 — Generate SRAMs

Generates the eight TSMC SP-SRAM/RF macros instantiated by C906
(`aq_spsram_*` wrappers) and converts their `.lib` to Synopsys `.db`.

```tcsh
cd smart_run/impl/gen_sram
./gen_sram.sh        # invokes mc-2 compilers, drops .v/.lib in ts1*/ts5* dirs
./cvrt_lib2db.sh     # lc_shell: every *_tt1v25c.lib -> db/*_tt1v25c.db
```

Configurations live in `gen_sram/config/*.txt`. All macros keep BWEB
(per-bit write-mask) enabled. Outputs:

- `gen_sram/verilog/*.v` — behavioural models for simulation
- `gen_sram/db/*.db`     — timing/power libs linked by DC and PTPX

## Step 2 — Synthesis (Design Compiler)

`dc.tcl` reads the C906 RTL filelist (`C906_RTL_FACTORY/gen_rtl/filelists/
C906_asic_rtl.fl`), substitutes the FPGA behavioural SRAMs with
`syn/aq_f_spsram_shim.v` + `MEM_INTF/aq_umc_spsram_wrappers.v` (which bind to
the TSMC `.db` macros), applies `sdc/C906_TOP.sdc`, then `compile_ultra` →
`optimize_netlist -area`.

```tcsh
cd smart_run/impl/syn
./run_dc.csh -mode syn                                  # creates batch_YYYYMMDD_HH/
# Re-open an existing batch:
./run_dc.csh -mode read_ddc -batch_dir batch_YYYYMMDD_HH
```

Top module: **`openC906`**. Per-batch outputs:

```
syn/batch_<YYYYMMDD_HH>/
├── reports/   check_design / qor / area[_hier] / power_hier / timing / saif_annotation
└── results/   openC906.{mapped.v, mapped.ddc, mapped.sdc, mapped.sdf,
                         ptpxmap.tcl, unmapped.ddc}
```

`openC906.ptpxmap.tcl` is the RTL→gate name map consumed by PTPX.

## Step 3 — PTPX (time-based power)

`run_ptpx_parallel.py` fans out `pwr_shell` jobs over a list of FSDBs, each
sourcing `run_power_timebased_replay.tcl` against the synthesis batch.

```bash
cd smart_run/impl/ptpx/script
~/anaconda3/bin/python run_ptpx_parallel.py \
    --in_dir   ../../syn/batch_<YYYYMMDD_HH> \
    --clk_period 1 \
    --fsdb_list_file fsdb_run_list.txt \
    --max_jobs 8 --timeout 7200 --skip_completed
```

FSDB sources can also be passed inline with `--fsdb_names a.fsdb b.fsdb …`,
and a sub-window selected with `--start_ns / --end_ns`. Per-job outputs land
in `ptpx/<case>/`:

```
ptpx/<case>/
├── reports/   openC906_{check_power, check_timing, power_area,
│                        power_hier, switching_coverage, timing}.rpt
├── results/   openC906_pwr.fsdb        # per-instance switching/power waveform
└── run_ptpx.log
```

The runner also writes `ptpx/ptpx_summary.csv` (one row per job: status,
return code, elapsed, log) and `ptpx/ptpx_runner.log`.

## Step 4 — Collect data

Post-processing utilities turn the rpts and FSDBs into CSV / pickled
DataFrames for downstream analysis.

```bash
# (a) Synthesis area: hierarchical area report -> CSV
python3 smart_run/impl/syn/rpt2csv.py \
    syn/batch_<YYYYMMDD_HH>/reports/openC906.mapped.area_hier.rpt \
    -o area_hier.csv

# (b) Presim waveform + rc signal list -> fsdbreport CSVs
cd smart_run/impl/ptpx/script
~/anaconda3/bin/python fsdb_to_csv.py \
    --summary-csv ../ptpx_summary.csv \
    --clk-period 1 \
    --downsample 10 \
    --func-rc ../../../key_signal.rc \
    --mode func-sim \
    --processes 8 \
    --out-dir ../presim_db

# (c) fsdbreport CSVs -> pandas pickles
~/anaconda3/bin/python csv_to_pkl.py \
    --indir ../presim_db/_csv \
    --downsample 10 \
    --processes 8 \
    --out-dir ../presim_db \
    --rm-prefix

```

## Outputs map

| Phase | Where | Key artefacts |
|---|---|---|
| 1. SRAM | `gen_sram/{verilog,db}/` | `*.v`, `*_tt1v25c.db` |
| 2. Syn  | `syn/batch_<YYYYMMDD_HH>/{reports,results}/` | `openC906.mapped.{v,ddc,sdc,sdf}`, `ptpxmap.tcl`, qor/area/timing/power rpts |
| 3. PTPX | `ptpx/<case>/{reports,results}/`, `ptpx/ptpx_summary.csv` | `openC906_pwr.fsdb`, power/timing rpts |
| 4. Data | `*.csv`, `ptpx/presim_db/_csv/*.csv`, `ptpx/presim_db/*.pkl` | area CSV, per-case presim `_func.csv` / `_func.pkl` |
