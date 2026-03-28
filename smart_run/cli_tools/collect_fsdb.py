#!/usr/bin/env python3
"""
Collect all ad_mp_top_pwr.fsdb files under the ptpx directory into a single
result/ folder, renaming them to ptpx_{original_folder_name}.fsdb, and remove
the original folders afterwards.

Usage:
    python3 collect_fsdb.py [--ptpx-dir <path>] [--dry-run]

Options:
    --ptpx-dir  Path to the ptpx directory (default: parent of this script's dir)
    --dry-run   Print actions without executing them
"""

import argparse
import os
import shutil
import sys


def main():
    parser = argparse.ArgumentParser(
        description="Collect ad_mp_top_pwr.fsdb files into ptpx/result/ and remove original folders."
    )
    parser.add_argument(
        "--ptpx-dir",
        default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        help="Path to the ptpx directory (default: parent of script/)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions without executing them",
    )
    args = parser.parse_args()

    ptpx_dir = os.path.abspath(args.ptpx_dir)
    result_dir = os.path.join(ptpx_dir, "result")
    dry_run = args.dry_run

    if not os.path.isdir(ptpx_dir):
        print(f"Error: ptpx directory does not exist: {ptpx_dir}", file=sys.stderr)
        sys.exit(1)

    # Collect all ad_mp_top_pwr.fsdb files
    fsdb_files = []
    for root, dirs, files in os.walk(ptpx_dir):
        # Skip the result directory itself and the script directory
        rel = os.path.relpath(root, ptpx_dir)
        if rel.startswith("result") or rel.startswith("script"):
            continue
        for f in files:
            if f == "ad_mp_top_pwr.fsdb":
                fsdb_files.append(os.path.join(root, f))

    if not fsdb_files:
        print("No ad_mp_top_pwr.fsdb files found.")
        sys.exit(0)

    print(f"Found {len(fsdb_files)} ad_mp_top_pwr.fsdb file(s).")

    # Create result directory
    if not dry_run:
        os.makedirs(result_dir, exist_ok=True)
    else:
        print(f"[DRY-RUN] mkdir -p {result_dir}")

    # Track folders to remove (top-level subdirectories under ptpx_dir)
    folders_to_remove = set()

    for fsdb_path in sorted(fsdb_files):
        # Determine the top-level folder name relative to ptpx_dir
        rel_path = os.path.relpath(fsdb_path, ptpx_dir)
        # rel_path looks like: coremark_43361208ns_44346690ns/results/ad_mp_top_pwr.fsdb
        folder_name = rel_path.split(os.sep)[0]

        new_name = f"ptpx_{folder_name}.fsdb"
        dest_path = os.path.join(result_dir, new_name)

        if dry_run:
            print(f"[DRY-RUN] mv {fsdb_path} -> {dest_path}")
        else:
            if os.path.exists(dest_path):
                print(f"Warning: {dest_path} already exists, overwriting.")
            shutil.move(fsdb_path, dest_path)
            print(f"Moved: {rel_path} -> result/{new_name}")

        # Record the top-level folder for removal
        top_folder = os.path.join(ptpx_dir, folder_name)
        folders_to_remove.add(top_folder)

    # Remove original folders
    for folder in sorted(folders_to_remove):
        if dry_run:
            print(f"[DRY-RUN] rm -rf {folder}")
        else:
            shutil.rmtree(folder)
            print(f"Removed: {os.path.basename(folder)}/")

    print("Done.")


if __name__ == "__main__":
    main()
