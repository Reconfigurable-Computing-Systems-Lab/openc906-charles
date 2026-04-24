# Plan: Python Simulation Runner (`smart_runner.py`)

## Problem

The existing `smart_run/Makefile` runs regression tests **sequentially** — each
case compiles RTL, builds, and simulates one at a time. For 24+ test cases this
is extremely slow. We need a Python script that:

1. Replicates all Makefile functionality (`showcase`, `compile`, `buildcase`,
   `runcase`, `regress`, `clean`)
2. Supports **parallel regression** with `-j JOBS` — maintains exactly JOBS
   concurrent simulations, submitting new jobs as others finish
3. Pre-checks `.pat` data size against the **256MB SRAM limit** before
   submitting simulation, marking oversized cases as FAIL
4. Supports **per-case simulation timeout** (`--timeout TIME`) where TIME uses
   suffixes `ps`, `ns`, `us`, `ms`, `s` (e.g., `1us`, `500ns`, `3s`). If a
   simulation exceeds the timeout, it is stopped and marked as FAIL.

## Approach

Create `smart_run/scripts/smart_runner.py` — a self-contained Python 3 script
using only stdlib (`argparse`, `subprocess`, `concurrent.futures`, `glob`,
`shutil`, `os`, `pathlib`).

### CLI Interface

```bash
# Run from smart_run/ directory
python3 scripts/smart_runner.py showcase
python3 scripts/smart_runner.py compile  [--sim vcs] [--dump on]
python3 scripts/smart_runner.py buildcase --case CASE
python3 scripts/smart_runner.py runcase  --case CASE [--sim vcs] [--dump on] [--timeout 1us]
python3 scripts/smart_runner.py regress  [--sim vcs] [--dump on] [-j 4] [--timeout 1us]
python3 scripts/smart_runner.py clean
```

### Architecture

```
smart_runner.py
├── Case Discovery
│   ├── STANDARD_CASES dict (12 hardcoded cases with src/file metadata)
│   ├── discover_nn_model_cases() — glob model_compiled/*/model.c
│   └── get_all_cases() — merged list
├── Build Recipes
│   ├── build_standard_case(case, work_dir)
│   ├── build_conv_softmax(work_dir) — special CSI-NN2 case
│   └── build_nn_model_case(case, work_dir)
├── RTL Compilation
│   └── compile_rtl(sim, dump, work_dir, case=None)
│       └── handles debug case special SIM_FILELIST
├── Size Check
│   └── check_pat_size(work_dir) → (ok: bool, data_bytes: int)
│       └── counts data lines in inst.pat + data.pat + input.pat
│       └── data_bytes = data_lines × 4; limit = 256MB
├── Simulation Timeout
│   └── parse_timeout("1us") → 1000.0 (nanoseconds)
│       └── supports ps, ns, us, ms, s suffixes
│       └── passed to simv as +MAX_SIM_TIME=<ns> plusarg
├── Simulation
│   └── run_simulation(sim, work_dir)
├── Single Case Flow
│   └── cmd_runcase() → compile + build + check + run
└── Parallel Regression
    └── cmd_regress(jobs)
        ├── compile RTL once in work/
        ├── ThreadPoolExecutor(max_workers=jobs)
        ├── per case: isolated work_regress/<case>/ dir
        │   ├── symlink simv/simv.daidir from work/
        │   ├── build case
        │   ├── check .pat size → skip if > 256MB
        │   └── run simulation
        ├── collect reports to tests/regress/regress_result/
        └── generate summary report (Python, replaces report_gen.pl)
```

### Parallel Regression Design

**Key challenge**: The current Makefile uses a single `work/` directory. For
parallel execution, each case needs an **isolated work directory**.

**Solution**: Each parallel case gets `work_regress/<case_name>/` with:

1. **Symlinks** to the shared compiled RTL binary:
   - VCS: `simv` + `simv.daidir/`
   - NC: `INCA_libs/`
   - iverilog: `xuantie_core.vvp`
2. **Full copy** of case source files + test library
3. **Independent build** (C compilation + .pat generation)
4. **Independent simulation** run

The `Srec2vmem` converter path (`../tests/bin/Srec2vmem` in tests/lib/Makefile)
is relative to `work/`. For `work_regress/<case>/`, this path is wrong. Fixed by
passing `CONVERT=<absolute_path>` as a make variable override.

**Concurrency model**: `concurrent.futures.ThreadPoolExecutor(max_workers=jobs)`
with `as_completed()`. Each thread calls `subprocess.run()` for make/simv. The
executor automatically maintains exactly `jobs` concurrent threads — when one
finishes, the next pending case starts.

**Debug case special handling**: The `debug` case requires different RTL
compilation (extra Verilog files). The script groups cases by RTL config and
compiles each config once. Non-debug cases share one compiled binary; the debug
case gets its own.

### 256MB .pat Size Check

After building a case, before running simulation:

1. Parse `inst.pat`, `data.pat`, `input.pat` (if exists)
2. Count **data lines** (skip `@address` directives and comments)
3. `total_data_bytes = total_data_lines × 4`
4. If `total_data_bytes > 256 × 1024 × 1024`:
   - Write `"NOT RUN (SRAM overflow: {size}MB > 256MB)"` to `run_case.report`
   - Return SKIP status
   - Do NOT submit simulation

### Simulation Timeout (`--timeout`)

The user can specify a per-case **simulation-time** timeout (e.g., `--timeout
1us`). This controls how long the RTL simulation runs in simulation time (not
wall-clock time).

**Implementation**:

1. **Modify `tb.v`**: Replace the hardcoded `#\`MAX_RUN_TIME` delay with a
   runtime-configurable plusarg:

   ```verilog
   real max_sim_time;
   initial begin
     if (!$value$plusargs("MAX_SIM_TIME=%f", max_sim_time))
       max_sim_time = 3000000000.0;  // default 3s (in ns, timescale=1ns)
     #(max_sim_time);
     $display("meeting max simulation time, stop!");
     FILE = $fopen("run_case.report","a");
     $fwrite(FILE,"TEST FAIL");
     $finish;
   end
   ```

2. **Python `parse_timeout()`**: Converts user string to nanoseconds (float):
   - `"500ps"` → `0.5`
   - `"100ns"` → `100.0`
   - `"1us"`  → `1000.0`
   - `"10ms"` → `10000000.0`
   - `"3s"`   → `3000000000.0`

3. **Pass to simulator** via plusarg at runtime (no RTL recompilation needed):
   - VCS: `./simv +MAX_SIM_TIME=1000.0 -l run.vcs.log`
   - NC:  `irun -R +MAX_SIM_TIME=1000.0 -l run.irun.log`
   - iverilog: `vvp xuantie_core.vvp +MAX_SIM_TIME=1000.0 -l run.iverilog.log`

4. **Default behavior**: If `--timeout` is not specified, the plusarg is omitted
   and the testbench uses its default (3s).

This approach uses `$value$plusargs` which is supported by all three simulators
(VCS, irun, iverilog). The `real` type ensures sub-nanosecond precision (for ps
inputs) and handles large values (seconds) without integer overflow.

### Build Recipes (encoded in Python)

**Standard cases** — dictionary mapping:
```python
STANDARD_CASES = {
    'ISA_THEAD': {
        'src': 'tests/cases/ISA/ISA_THEAD',
        'file': 'C906_THEAD_ISA_EXTENSION',
    },
    'ISA_INT':   {'src': 'tests/cases/ISA/ISA_INT',   'file': 'C906_INT_SMOKE'},
    'ISA_LS':    {'src': 'tests/cases/ISA/ISA_LS',    'file': 'C906_LSU_SMOKE'},
    'ISA_FP':    {'src': 'tests/cases/ISA/ISA_FP',    'file': 'C906_FPU_SMOKE'},
    'coremark':  {'src': 'tests/cases/coremark',      'file': 'core_main',
                  'extra_dirs': ['tests/lib/clib', 'tests/lib/newlib_wrap']},
    'MMU':       {'src': 'tests/cases/MMU',           'file': 'C906_mmu_basic'},
    'interrupt': {'src': 'tests/cases/interrupt',     'file': 'C906_plic_int_smoke'},
    'exception': {'src': 'tests/cases/exception',     'file': 'C906_Exception'},
    'debug':     {'src': 'tests/cases/debug',         'file': 'C906_DEBUG_PATTERN',
                  'rtl_extra': ['tests/cases/debug/JTAG_DRV.vh',
                                'tests/cases/debug/C906_DEBUG_PATTERN.v']},
    'csr':       {'src': 'tests/cases/csr',           'file': 'C906_CSR_OPERATION'},
    'cache':     {'src': 'tests/cases/cache',         'file': 'C906_IDCACHE_OPER'},
}
```

**conv_softmax** — special recipe (copies from `tests/cases/conv_softmax/`, uses
CSI-NN2 flags, copies `input.pat` after build).

**NN model cases** — generic recipe using `prepare_model.py`:
1. Copy `nn_model_common/` files
2. Run `prepare_model.py <model_dir> <work_dir>`
3. Copy test lib
4. Compile with CSI-NN2 flags
5. Re-run `prepare_model.py` to restore `input.pat` (cleaned by `make clean`)

### Report & Waveform Collection

The script generates reports compatible with the existing `report_gen.pl` format:

- Per-case: `tests/regress/regress_result/<case>.report`
- Per-case waveform: `tests/regress/regress_result/<case>.fsdb` (VCS) or
  `<case>.vcd` (NC/iverilog), copied from each case's work directory after
  simulation completes
- Summary: `tests/regress/regress_report`
- Format: table with Block/Pattern/Result columns + Pass/Fail/Not run/Total

Waveform files are only present when `--dump on` (the default). The simulator
determines the filename:
- **VCS**: `novas.fsdb` → copied as `<case>.fsdb`
- **NC/iverilog**: `test.vcd` → copied as `<case>.vcd`

Implemented in Python (no Perl dependency).

---

## Files

### New File

| File | Purpose |
|------|---------|
| `smart_run/scripts/smart_runner.py` | Python simulation runner with parallel regress + size check |

### No Modifications to Existing Files

The Python script is a standalone alternative to the Makefile. It reads the same
case definitions, uses the same test infrastructure, and produces the same
output format. The Makefile continues to work unchanged.

### Modified File

| File | Change |
|------|--------|
| `smart_run/logical/tb/tb.v` | Replace hardcoded `#\`MAX_RUN_TIME` with `$value$plusargs("MAX_SIM_TIME=%f")` to support runtime-configurable simulation timeout |

---

## Todos

1. **modify-tb-v-timeout** — Modify `tb.v` to use `$value$plusargs` for
   configurable simulation timeout (replace hardcoded `#\`MAX_RUN_TIME`) — DONE
2. **create-smart-runner** — Create `smart_run/scripts/smart_runner.py` with
   full implementation (case discovery, build recipes, RTL compile, parallel
   regress, size check, timeout support, report generation) — DONE
3. **save-fsdb-in-regress** — Copy waveform dump files (`.fsdb` for VCS,
   `.vcd` for NC/iverilog) to `regress_result/<case>.*` after each simulation
4. **verify-showcase** — Run `python3 scripts/smart_runner.py showcase` and
   confirm all 24 cases are listed — DONE
5. **verify-buildcase** — Run `python3 scripts/smart_runner.py buildcase
   --case ISA_INT` and confirm build succeeds — DONE
6. **verify-pat-check** — Test the 256MB .pat size check logic — DONE
7. **update-doc** — Update `doc/smart-runner-plan.md` to reflect waveform
   collection feature
