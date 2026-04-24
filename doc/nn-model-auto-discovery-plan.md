# Plan: Auto-Discovery and Build System for CSI-NN2 Model Simulation

## Problem

`smart_run/tests/cases/model_compiled/` contains 12 (and growing) HHB-generated
CSI-NN2 neural network model directories. Each has `model.c`, `model.params`, and
input `.bin` files. Currently only a single hand-crafted test case (`conv_softmax`)
exists for bare-metal C906 RTL simulation. We need an automated system that:

1. Auto-discovers model directories in `model_compiled/`
2. Generates the required bare-metal infrastructure per model
3. Integrates with `make runcase CASE=<model>` and `make regress`

## Approach Overview

**Key insight**: The CSI-NN2 `csinn_session` struct exposes `input_num`,
`output_num`, and `input[]`/`output[]` arrays at runtime. This means a **single
generic `bare_main.c`** can handle any model by querying the session after graph
construction — no per-model code generation for the entry point.

### Architecture

```
smart_run/
├── scripts/
│   └── prepare_model.py              # Preparation script (runs at build time)
├── tests/cases/
│   ├── model_compiled/               # Source models (user-managed, auto-discovered)
│   │   ├── c906_compiled_results.json
│   │   ├── conv_softmax_part000_c906_float16/
│   │   │   ├── model.c               # HHB-generated model graph
│   │   │   ├── model.params          # Serialized weights/qinfo
│   │   │   └── input.0.bin           # Float32 input data
│   │   ├── matmul_part000_c906_float32/
│   │   │   ├── model.c
│   │   │   ├── model.params
│   │   │   ├── input_1.0.bin         # Multiple inputs
│   │   │   └── input_2.1.bin
│   │   └── ... (other models)
│   └── nn_model_common/              # NEW: Shared bare-metal infrastructure
│       ├── bare_main.c               # Generic entry point (works for any model)
│       ├── sbrk.c                    # Heap, stubs, callback override
│       └── stubs/sys/syscall.h       # Empty header stub for newlib
└── setup/
    └── smart_cfg.mk                  # MODIFIED: auto-discovery + dynamic recipes
```

### Build-Time Flow

When `make runcase CASE=conv_softmax_part000_c906_float16` (or any model) runs:

1. **Copy shared files** → `work/bare_main.c`, `work/sbrk.c`, `work/stubs/`
2. **Run `prepare_model.py`** which generates into `work/`:
   - `model.c` — patched (`CSINN_C906` → `CSINN_REF`)
   - `test_data.h` — `model.params` converted to C byte array
   - `model_config.h` — input metadata (`HAS_REAL_INPUT`, `INPUT_BASE_ADDR`)
   - `input.pat` — input `.bin` files converted to Verilog hex (if ≤64KB total)
3. **Copy test lib** files to `work/`
4. **Compile** with CSI-NN2 flags (same as existing `conv_softmax`)
5. **Run VCS simulation**

### Input Data Handling

All models get **real input data** loaded via `input.pat`. The L3 SRAM has been
expanded to 256MB (2×128MB banks), which comfortably holds all current model
inputs:

| Model | Inputs | Total Size |
|-------|--------|-----------|
| conv_softmax_* | 1 × 50KB | ~50KB |
| matmul_* | 2 × 4MB | ~8MB |
| resgatedgraphconv_* | 15MB + 75KB | ~14.9MB |
| tagconv_* | 75KB + 15MB | ~14.9MB |

**Memory layout for inputs**: To avoid conflicts with code/data/BSS/heap/stack
(which occupy the first ~1MB), input data is loaded at a **high address**:

- **Input base address**: `0x01000000` (16MB offset)
- **Max input capacity**: 32MB (8M × 32-bit words in the temp array)
- Input extends from 16MB upward, well clear of stack (at 0xEE000)

**Testbench change (`tb.v`)**: A new, larger temp array and loading block is
added *alongside* the existing one at `0x80000` for backward compatibility:

```verilog
// NEW: Large input loading at 0x01000000 (row offset 0x100000)
parameter INPUT_TEMP_SIZE = 8388608;  // 8M words = 32MB max
reg [31:0] mem_input_temp_nn[0:INPUT_TEMP_SIZE-1];
initial $readmemh("input.pat", mem_input_temp_nn);

// Load with early-exit when hitting uninitialized entries
begin : nn_input_load_block
  for (i = 0; i < INPUT_TEMP_SIZE; i = i + 4) begin
    if (mem_input_temp_nn[i] === {32{1'bx}})
      disable nn_input_load_block;
    // ... byte-swizzle into 16 RAM sub-banks at row offset 0x100000
  end
end
```

The early-exit check (`=== {32{1'bx}}`) stops iteration at the first
uninitialized entry, so a 50KB input only iterates ~12.5K entries, not 8M.
The existing 16K-word loading at `0x80000` is preserved for backward
compatibility with the hand-crafted `conv_softmax` case.

---

## Detailed Design

### 1. `smart_run/scripts/prepare_model.py`

Python script invoked during build. Arguments: `<model_dir> <output_dir>`.

**Tasks:**
1. **Patch `model.c`**: Replace `CSINN_C906` with `CSINN_REF` so the reference
   C backend is used (C906-specific kernels require RVV 0.7.1 which GCC 14.3
   can't compile).
2. **Generate `test_data.h`**: Convert `model.params` binary to a C byte array
   (`static const unsigned char model_params[N] = { ... };`).
3. **Generate `model_config.h`**: Metadata defines:
   - `INPUT_BASE_ADDR` — `0x01000000UL` (where tb.v loads `input.pat` for NN models)
   - `TOTAL_INPUT_BYTES` — total size of all input `.bin` files
   - `NUM_BIN_INPUTS` — number of input `.bin` files
4. **Generate `input.pat`**: Concatenate all input `.bin` files (sorted by
   input index), convert each 32-bit word to hex. Input files follow the
   naming convention `<name>.<INDEX>.bin` where `INDEX` is the input position.
   Always generated — 256MB SRAM accommodates all current model inputs (up to ~32MB).

### 2. `smart_run/tests/cases/nn_model_common/bare_main.c`

Generic entry point that works for **any** CSI-NN2 model:

```c
#include "test_data.h"      // model_params[] (generated per model)
#include "model_config.h"   // HAS_REAL_INPUT, INPUT_BASE_ADDR
#include "csi_nn.h"
#include "shl_utils.h"
#include "shl_ref.h"

void *csinn_(char *params_base);  // Defined in model.c

int main(void) {
    install_trap_handler();  // Override crt0.s broken vector table
    
    // Build compute graph
    struct csinn_session *sess = csinn_((char *)model_params);
    
    // Allocate and fill input tensors
    int input_num = sess->input_num;
    struct csinn_tensor **inputs = malloc(input_num * sizeof(void *));
    
    for (int i = 0; i < input_num; i++) {
        struct csinn_tensor *ref = sess->input[i];  // Query session for metadata
        // ... clone tensor metadata, allocate data buffer ...
        // Load float32 from testbench memory at INPUT_BASE_ADDR, convert to model dtype
        shl_ref_f32_to_input_dtype(input, float_ptr, sess);
        float_ptr += elem_count;  // advance to next input's data
    }
    
    // Run inference
    for (int i = 0; i < input_num; i++)
        csinn_update_input(i, inputs[i], sess);
    csinn_session_run(sess);
    
    // Cleanup and return (triggers TEST PASS in testbench)
    ...
    return 0;
}
```

Key design points:
- Queries `sess->input_num` and `sess->input[i]` at runtime for tensor metadata
- Uses `csinn_update_input()` + `csinn_session_run()` directly (not the
  model-generated `csinn_update_input_and_run()`) for full generality
- Includes trap handler for exception safety (same as existing conv_softmax)

### 3. `smart_run/tests/cases/nn_model_common/sbrk.c`

Shared stubs (extracted from existing `conv_softmax/sbrk.c`):
- `_sbrk()` — newlib heap allocator
- `shl_target_init_c906()` — empty stub (RVV not available)
- `shl_trace_move_events()` — empty stub
- `shl_get_runtime_callback()` — override that calls `shl_gref_runtime_callback()`
  directly instead of through function pointer table (avoids C906 RTL tail-call bug)

### 4. `smart_run/setup/smart_cfg.mk` Changes

```makefile
# ---- Auto-discover model_compiled test cases ----
MODEL_COMPILED_DIR := ./tests/cases/model_compiled
MODEL_CASES := $(patsubst $(MODEL_COMPILED_DIR)/%/model.c,%, \
                 $(wildcard $(MODEL_COMPILED_DIR)/*/model.c))
CASE_LIST += $(MODEL_CASES)

CSI_NN2_INSTALL := ../../csi-nn2/install_nn2/c906

# Generic build recipe macro
define NN_MODEL_BUILD
$(1)_build:
	@echo "  [NN-Model] Building $(1)..."
	@cp ./tests/cases/nn_model_common/bare_main.c ./work/
	@cp ./tests/cases/nn_model_common/sbrk.c ./work/
	@cp -r ./tests/cases/nn_model_common/stubs ./work/stubs
	@python3 ./scripts/prepare_model.py \
	    ./tests/cases/model_compiled/$(1) ./work
	@find ./tests/lib/ -maxdepth 1 -type f -exec cp {} ./work/ \;
	@cd ./work && make -s clean && make -s all \
	    CPU_ARCH_FLAG_0=c906fd ENDIAN_MODE=little-endian \
	    CASENAME=$(1) FILE=bare_main \
	    EXTRA_CFLAGS="..." EXTRA_LDFLAGS="..." \
	    >& $(1)_build.case.log
endef

# Generate a build target for every discovered model
$(foreach case,$(MODEL_CASES),$(eval $(call NN_MODEL_BUILD,$(case))))
```

This means:
- **Adding a model**: Drop a new folder with `model.c` + `model.params` +
  `*.bin` into `model_compiled/`. It's automatically available.
- **Removing a model**: Delete the folder. It's automatically excluded.
- **`make showcase`**: Lists all cases including discovered models.
- **`make runcase CASE=tagconv_Opset17_part001_c906_float16`**: Just works.
- **`make regress`**: Runs all cases including all discovered models.

---

## Files Summary

### New Files (4)

| File | Purpose |
|------|---------|
| `smart_run/scripts/prepare_model.py` | Build-time model preparation (patch, convert, generate) |
| `smart_run/tests/cases/nn_model_common/bare_main.c` | Generic bare-metal entry point for any CSI-NN2 model |
| `smart_run/tests/cases/nn_model_common/sbrk.c` | Shared heap, stubs, RTL bug workarounds |
| `smart_run/tests/cases/nn_model_common/stubs/sys/syscall.h` | Empty header stub for newlib compatibility |

### Modified Files (2)

| File | Change |
|------|--------|
| `smart_run/setup/smart_cfg.mk` | Add auto-discovery wildcard, `CASE_LIST +=`, and `$(foreach)` dynamic build recipe generation |
| `smart_run/logical/tb/tb.v` | Add second larger temp array (8M words) loading `input.pat` at `0x01000000`; early-exit on X entries |

### Not Modified

| File | Why |
|------|-----|
| `smart_run/Makefile` | No changes needed — `runcase`/`regress` already work via CASE_LIST |
| `smart_run/tests/lib/Makefile` | Already supports `EXTRA_CFLAGS`/`EXTRA_LDFLAGS` |
| Existing `conv_softmax` case | Kept as-is for reference; auto-discovered models supplement it (uses old 0x80000 input address) |

---

## Prerequisites

- Python 3 (for `prepare_model.py`)
- Pre-built CSI-NN2 library at `csi-nn2/install_nn2/c906/` (see doc/csi-nn2-bare-metal-guide.md §3)
- RISC-V toolchain (`riscv64-unknown-elf-gcc`, elf-newlib variant)
- VCS simulator

---

## Todos

1. **create-nn-model-common** — Create `nn_model_common/` directory with `bare_main.c`, `sbrk.c`, and `stubs/sys/syscall.h`
2. **create-prepare-script** — Create `scripts/prepare_model.py` (patch model.c, generate test_data.h, model_config.h, input.pat)
3. **modify-tb-v** — Add larger input.pat loading block to `tb.v` at address `0x01000000` with 8M-word temp array and early-exit
4. **modify-smart-cfg** — Add auto-discovery and dynamic build recipe generation to `smart_cfg.mk`
5. **verify-build** — Test with at least one model: `make buildcase CASE=conv_softmax_part000_c906_int8_sym`
