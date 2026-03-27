#!/usr/bin/env python3
"""
result_collect.py — Collect passed HHB C906 compilation artifacts.

Reads c906_results.json produced by run_hhb_c906.py, copies key artifacts
(model.c, model.params, input bins) for passed cases into hhb/model_compiled/,
and writes a filtered results JSON.

Usage:
    python3 result_collect.py [--results FILE] [--output-dir DIR] [--clean]
"""

import argparse
import json
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent          # hhb/
MODEL_SPLIT_DIR = SCRIPT_DIR / "model_split"
DEFAULT_RESULTS = MODEL_SPLIT_DIR / "c906_results.json"
DEFAULT_OUTPUT = SCRIPT_DIR / "model_compiled"         # hhb/model_compiled/


def collect(results_path: Path, output_dir: Path, clean: bool = False):
    if not results_path.exists():
        print(f"ERROR: {results_path} not found. Run run_hhb_c906.py first.", file=sys.stderr)
        sys.exit(1)

    with open(results_path) as f:
        data = json.load(f)

    passed = [r for r in data["results"] if r["status"] == "sim_done"]
    if not passed:
        print("No passed cases found in results.")
        return

    if clean and output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    bin_re = re.compile(r'^.+\.\d+\.bin$')
    copied = []

    for entry in passed:
        model, part, quant = entry["model"], entry["part"], entry["quant"]
        src_dir = MODEL_SPLIT_DIR / model / f"{part}_c906_{quant}"

        if not src_dir.exists():
            print(f"  SKIP {model}/{part}_c906_{quant}: source dir missing")
            continue

        dst_dir = output_dir / f"{model}_{part}_c906_{quant}"
        dst_dir.mkdir(parents=True, exist_ok=True)

        # Copy model.c, model.params
        for name in ("model.c", "model.params"):
            src = src_dir / name
            if src.exists():
                shutil.copy2(src, dst_dir / name)

        # Copy all input bin files (varied naming: input.0.bin, input_1.0.bin, x.0.bin, etc.)
        for f in src_dir.iterdir():
            if bin_re.match(f.name):
                shutil.copy2(f, dst_dir / f.name)

        copied.append(entry)
        print(f"  OK   {model}/{part}_c906_{quant}")

    # Write filtered results JSON
    out_json = output_dir / "c906_compiled_results.json"
    report = {
        "generated_at": datetime.now().isoformat(),
        "source": str(results_path),
        "total_passed": len(copied),
        "results": copied,
    }
    with open(out_json, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\nCollected {len(copied)} passed cases -> {output_dir}")
    print(f"Results JSON: {out_json}")


def main():
    parser = argparse.ArgumentParser(description="Collect passed HHB C906 artifacts")
    parser.add_argument("--results", type=Path, default=DEFAULT_RESULTS,
                        help="Path to c906_results.json")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT,
                        help="Output directory (default: hhb/model_compiled/)")
    parser.add_argument("--clean", action="store_true",
                        help="Remove output dir before collecting")
    args = parser.parse_args()
    collect(args.results, args.output_dir, args.clean)


if __name__ == "__main__":
    main()
