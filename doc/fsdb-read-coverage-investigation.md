# FSDB Read Coverage Investigation Notes

This note records the methods used to answer the question:

> Has the C906 core read all content from `smart_run/work/inst.pat` and
> `smart_run/work/data.pat`, as verified from `smart_run/work/novas.fsdb`?

The final answer was **no**. The core only reads a small working subset of the
loaded instruction/data regions.

---

## Ground Truth Used During the Investigation

### Key waveform signals

The most relevant signals came from the **"L3 SRAM (axi_slave128)"** group in
`smart_run/key_signal.rc`:

- `/tb/x_soc/x_axi_slave128/cur_state[1:0]`
- `/tb/x_soc/x_axi_slave128/mem_addr[39:0]`
- `/tb/x_soc/x_axi_slave128/mem_cen_0`
- `/tb/x_soc/x_axi_slave128/mem_wen[15:0]`

These are sufficient to detect SRAM reads:

- `cur_state == 2'b11` means `READ`
- `mem_cen_0 == 0` means the low SRAM bank is selected
- `mem_wen == 16'hffff` means the access is a read, not a write
- SRAM row index = `mem_addr >> 4` because each row is 16 bytes wide

### How `inst.pat` and `data.pat` map into SRAM

Based on `smart_run/logical/tb/tb.v`, the testbench loads four 32-bit words
per 128-bit SRAM row:

- `inst.pat` starts at row `0x0000`
- `data.pat` starts at row `0x4000`

For the specific files in `smart_run/work/` during this investigation:

- `inst.pat` covered rows `0x0000` to `0x32bc`
  - byte range `0x00000000` to `0x00032bcf`
  - total rows: **12,989**
- `data.pat` covered rows `0x4000` to `0x428a`
  - byte range `0x00040000` to `0x000428af`
  - total rows: **651**

---

## Methods Tried

| # | Method | Result | Why it failed or was abandoned |
|---|--------|--------|--------------------------------|
| 1 | Use `fsdbextract -help` and `fsdb2vcd -help` first | Succeeded | This was just the tool-syntax discovery step required before reduction/conversion. |
| 2 | Directly extract the RC-file L3 SRAM signals from `novas.fsdb` using the literal RC slice `mem_addr[22:4]` | Failed | `fsdbextract` did not accept that exact sliced path from the command line. The readable internal bus had to be requested as the full signal `mem_addr[39:0]`. |
| 3 | Extract a wider `x_axi_slave128` scope FSDB | Technically worked, but abandoned | The result was larger than needed and slower to produce. For this task, the address/control signals were enough. |
| 4 | Extract a filtered L3 SRAM FSDB containing address/control/data (`l3_addr.fsdb`) | Partially worked | The extraction was valid, but still slow because `novas.fsdb` is about 9.5 GB. It was not the fastest path to a finished answer. |
| 5 | Convert the stopped partial FSDB directly with `fsdb2vcd` | Failed | `fsdb2vcd` refused to translate a filtered FSDB that had not been closed cleanly by a completed `fsdbextract` run (`failed to open FSDB file before it closed`). |
| 6 | Run `fsdbreport` directly on the full `novas.fsdb` for the entire run | Abandoned | The monolithic CSV export buffered for too long and did not flush a usable output file quickly enough. |
| 7 | Dump the readable stopped filtered FSDB to CSV with `fsdbreport` and analyze it | Succeeded | Even though the partial FSDB was not clean enough for `fsdb2vcd`, it was readable enough for `fsdb2vcd -summary` and `fsdbreport`. This gave a stable first-half trace. |
| 8 | Probe later time windows directly from the original `novas.fsdb` with `fsdbreport -bt/-et` | Succeeded | Windowed probes were much more practical than one monolithic full-run dump and confirmed that the same sparse working set reappeared in the middle and end of the run. |

---

## What Each Successful Step Showed

### First-half readable filtered trace

The readable partial filtered trace covered:

- time `0 ps` to `414,817,966,500 ps`

From that trace:

- the unique read-row set already plateaued by `100,000,000,000 ps`
- the counts stayed identical at:
  - `100,000,000,000 ps`
  - `200,000,000,000 ps`
  - `300,000,000,000 ps`
  - `400,000,000,000 ps`
  - `414,817,966,500 ps`

Plateau counts:

- `inst.pat`: **1,162** rows seen
- `data.pat`: **35** rows seen

### Later window probes on the original FSDB

Later windows were sampled directly from the original `novas.fsdb`:

- `500,000,000,000 ps` to `600,000,000,000 ps`
- `700,000,000,000 ps` to `800,000,000,000 ps`
- `900,000,000,000 ps` to `932,615,240,500 ps`

Results:

- `500–600 ms`: **1,160** instruction rows, **35** data rows
- `700–800 ms`: **1,160** instruction rows, **35** data rows
- `900–932.6152405 ms`: **1,160** instruction rows, **35** data rows

This showed that the run repeatedly touched the same sparse row set in the
middle and end of simulation, rather than expanding to cover the full
`inst.pat` or `data.pat` ranges.

---

## Final Method Used

The final answer came from the following procedure.

### 1. Identify the relevant SRAM signals

Read `smart_run/key_signal.rc` and keep only the L3 SRAM signals needed to
detect low-bank reads:

- `cur_state`
- `mem_addr`
- `mem_cen_0`
- `mem_wen`

### 2. Verify tool syntax

Use:

- `fsdbextract -help`
- `fsdb2vcd -help`

This was necessary because the original FSDB was too large to inspect directly.

### 3. Map the `.pat` files into SRAM rows

Read:

- `smart_run/logical/tb/tb.v`
- `smart_run/work/inst.pat`
- `smart_run/work/data.pat`

Then compute the exact row ranges that needed to be covered:

- `inst.pat`: rows `0x0000` to `0x32bc`
- `data.pat`: rows `0x4000` to `0x428a`

### 4. Create a filtered L3 SRAM FSDB

Reduce the original FSDB to the needed signals only.

In practice, a stopped filtered FSDB was still useful for:

- `fsdb2vcd -summary`
- `fsdbreport`

even though it was not clean enough for a full `fsdb2vcd` translation.

### 5. Dump the readable filtered FSDB to CSV

Use `fsdbreport` on the readable filtered FSDB to generate a stable CSV covering
the first large portion of the run.

### 6. Count unique read rows

For each CSV row, treat it as an SRAM read only when:

- `cur_state == 3`
- `mem_cen_0 == 0`
- `mem_wen == ffff`

Then compute:

- `row = mem_addr >> 4`

Track unique rows separately for:

- instruction region: `0x0000` to `0x32bc`
- data region: `0x4000` to `0x428a`

### 7. Check whether coverage plateaus

Measure the unique-row counts at multiple checkpoints in the first-half trace.

Observation:

- the counts stopped growing by `100,000,000,000 ps`
- they remained flat through `414,817,966,500 ps`

### 8. Probe later windows from the original FSDB

Use `fsdbreport -bt/-et` on the original `novas.fsdb` to sample middle and late
windows of the run:

- `500–600 ms`
- `700–800 ms`
- `900–932.6152405 ms`

Run the same unique-row counting logic on each window.

### 9. Compare observed rows against expected rows

Expected:

- `inst.pat`: **12,989** rows
- `data.pat`: **651** rows

Observed working set:

- `inst.pat`: **1,162** rows total
- `data.pat`: **35** rows total

### 10. Draw the conclusion

Because the observed row set plateaued early and the later windows showed the
same sparse working set, the C906 core does **not** read all content from
`inst.pat` or `data.pat`.

---

## Final Result

- `inst.pat`: `1,162 / 12,989` rows read (**about 8.9%**)
- `data.pat`: `35 / 651` rows read (**about 5.4%**)

Therefore:

> The C906 core reads only a small working subset of the loaded instruction and
> data images. It does **not** read the full contents of
> `smart_run/work/inst.pat` and `smart_run/work/data.pat`.
