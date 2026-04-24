#!/usr/bin/env python3
"""Prepare a CSI-NN2 model for bare-metal C906 RTL simulation.

Usage: prepare_model.py <model_dir> <output_dir>

Reads model.c, model.params, and *.bin from <model_dir>.
Generates patched model.c, test_data.h, model_config.h, and input.pat
in <output_dir>.
"""
import os
import re
import struct
import sys


INPUT_BASE_ADDR = 0x01000000


def patch_model_c(model_dir, output_dir):
    """Copy model.c, replacing CSINN_C906 with CSINN_REF."""
    src = os.path.join(model_dir, "model.c")
    dst = os.path.join(output_dir, "model.c")
    with open(src, "r") as f:
        content = f.read()
    content = content.replace("CSINN_C906", "CSINN_REF")
    with open(dst, "w") as f:
        f.write(content)


def generate_test_data_h(model_dir, output_dir):
    """Convert model.params to a C header with a byte array."""
    params_path = os.path.join(model_dir, "model.params")
    with open(params_path, "rb") as f:
        data = f.read()

    dst = os.path.join(output_dir, "test_data.h")
    with open(dst, "w") as f:
        f.write("/* Auto-generated from model.params */\n")
        f.write("#ifndef TEST_DATA_H\n")
        f.write("#define TEST_DATA_H\n\n")
        f.write("#include <stdint.h>\n\n")
        f.write(
            f"static const unsigned char model_params[{len(data)}] = {{\n"
        )
        for i in range(0, len(data), 16):
            chunk = data[i : i + 16]
            hex_vals = ", ".join(f"0x{b:02x}" for b in chunk)
            f.write(f"    {hex_vals},\n")
        f.write("};\n\n")
        f.write("#endif /* TEST_DATA_H */\n")


def find_input_bins(model_dir):
    """Find and sort input .bin files by their input index.

    Naming convention: <name>.<INDEX>.bin where INDEX is an integer.
    """
    bins = []
    for fname in os.listdir(model_dir):
        if not fname.endswith(".bin"):
            continue
        # Extract the index from the second-to-last dot-separated component
        parts = fname.rsplit(".", 2)  # e.g. ["input_1", "0", "bin"]
        if len(parts) >= 3:
            try:
                idx = int(parts[-2])
                bins.append((idx, os.path.join(model_dir, fname)))
            except ValueError:
                pass
    bins.sort(key=lambda x: x[0])
    return bins


def generate_input_pat(bins, output_dir):
    """Concatenate input .bin files and write as Verilog hex words."""
    dst = os.path.join(output_dir, "input.pat")
    with open(dst, "w") as f:
        for _, bin_path in bins:
            with open(bin_path, "rb") as bf:
                data = bf.read()
            # Pad to 4-byte alignment
            pad = (4 - len(data) % 4) % 4
            data += b"\x00" * pad
            for i in range(0, len(data), 4):
                word = struct.unpack("<I", data[i : i + 4])[0]
                f.write(f"{word:08x}\n")


def generate_model_config_h(output_dir, total_bytes, num_inputs):
    """Generate model_config.h with input metadata."""
    dst = os.path.join(output_dir, "model_config.h")
    with open(dst, "w") as f:
        f.write("/* Auto-generated model configuration */\n")
        f.write("#ifndef MODEL_CONFIG_H\n")
        f.write("#define MODEL_CONFIG_H\n\n")
        f.write(f"#define INPUT_BASE_ADDR   0x{INPUT_BASE_ADDR:08x}UL\n")
        f.write(f"#define TOTAL_INPUT_BYTES {total_bytes}\n")
        f.write(f"#define NUM_BIN_INPUTS    {num_inputs}\n\n")
        f.write("#endif /* MODEL_CONFIG_H */\n")


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <model_dir> <output_dir>", file=sys.stderr)
        sys.exit(1)

    model_dir = sys.argv[1]
    output_dir = sys.argv[2]

    # 1. Patch model.c
    patch_model_c(model_dir, output_dir)

    # 2. Generate test_data.h from model.params
    generate_test_data_h(model_dir, output_dir)

    # 3. Find input .bin files
    bins = find_input_bins(model_dir)
    total_bytes = sum(os.path.getsize(p) for _, p in bins)

    # 4. Generate model_config.h
    generate_model_config_h(output_dir, total_bytes, len(bins))

    # 5. Generate input.pat
    if bins:
        generate_input_pat(bins, output_dir)
    else:
        # Create an empty input.pat so $readmemh doesn't fail
        with open(os.path.join(output_dir, "input.pat"), "w") as f:
            f.write("00000000\n")

    print(
        f"  [prepare_model] {os.path.basename(model_dir)}: "
        f"{len(bins)} inputs, {total_bytes} bytes total"
    )


if __name__ == "__main__":
    main()
