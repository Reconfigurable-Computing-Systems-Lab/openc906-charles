#!/usr/bin/env python3
"""
Convert the 'Hierarchical area distribution' table in a *.mapped.area_hier.rpt
report into a CSV file.

Tested with Python 3.13.

Usage:
  python3 rpt_area_hier_to_csv.py ad_mp_top.mapped.area_hier.rpt -o area_hier.csv

If -o/--out is omitted, output defaults to <input>.csv (same basename, .csv suffix).
"""

import argparse
import csv
from pathlib import Path

TABLE_TITLE = "Hierarchical area distribution"
HEADER_ROW_START = "Hierarchical cell"

FIELDNAMES = [
    "hierarchical_cell",
    "global_abs_total",
    "global_percent_total",
    "local_combinational",
    "local_noncombinational",
    "local_black_boxes",
    "design",
]


def _is_sep_line(line: str) -> bool:
    """
    Table separator lines in these reports are composed of '-' and spaces only.
    Example:
      --------------------------------  -------------  -------  ...
    """
    s = line.strip()
    return bool(s) and (set(s) <= {"-", " "}) and (s.count("-") >= 20)


def _parse_table_row(line: str) -> dict[str, str] | None:
    s = line.strip()
    if not s or s.startswith("Total"):
        return None

    toks = s.split()
    if len(toks) < 7:
        # Not a normal data row (could be wrapping/noise); skip.
        return None

    # Parse from the right:
    #   <hier_cell> <abs_total> <pct_total> <combi> <noncombi> <black_boxes> <design>
    design = toks[-1]
    black_boxes = toks[-2]
    noncombi = toks[-3]
    combi = toks[-4]
    pct_total = toks[-5]
    abs_total = toks[-6]
    hier_cell = " ".join(toks[:-6])

    return {
        "hierarchical_cell": hier_cell,
        "global_abs_total": abs_total,
        "global_percent_total": pct_total,
        "local_combinational": combi,
        "local_noncombinational": noncombi,
        "local_black_boxes": black_boxes,
        "design": design,
    }


def extract_hier_area_rows(rpt_path: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []

    found_title = False
    found_header = False
    in_table = False

    with rpt_path.open("r", encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.rstrip("\n")

            if not found_title:
                if line.strip() == TABLE_TITLE:
                    found_title = True
                continue

            # After the title, wait until we see the actual table header row,
            # then wait for the separator line that starts the data block.
            if not found_header:
                if line.lstrip().startswith(HEADER_ROW_START):
                    found_header = True
                continue

            if not in_table:
                if _is_sep_line(line):
                    in_table = True
                continue

            # Now consuming data rows until the next separator line.
            if _is_sep_line(line):
                break

            row = _parse_table_row(line)
            if row is not None:
                rows.append(row)

    if not found_title:
        raise RuntimeError(f"Couldn't find section title: {TABLE_TITLE!r}")
    if not found_header:
        raise RuntimeError(f"Couldn't find table header row starting with: {HEADER_ROW_START!r}")
    if not rows:
        raise RuntimeError("Found the table header, but no data rows were parsed.")

    return rows


def write_csv(rows: list[dict[str, str]], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDNAMES)
        w.writeheader()
        w.writerows(rows)


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Extract 'Hierarchical area distribution' table to CSV."
    )
    ap.add_argument("rpt", type=Path, help="Input .rpt file")
    ap.add_argument(
        "-o",
        "--out",
        type=Path,
        default=None,
        help="Output .csv path (default: same as input with .csv suffix)",
    )
    args = ap.parse_args()

    out = args.out if args.out is not None else args.rpt.with_suffix(".csv")
    rows = extract_hier_area_rows(args.rpt)
    write_csv(rows, out)
    print(f"Wrote {len(rows)} rows to: {out}")


if __name__ == "__main__":
    main()