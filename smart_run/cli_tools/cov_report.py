#!/usr/bin/env python3
"""
Per-unit code-coverage report for the OpenC906 pipeline units.

Reads either
  * Verilator `coverage.dat` files (produced by `make ... COVERAGE=line|all`,
    which passes `+verilator+coverage+file+../cov/<case>.dat`), or
  * a VCS `urg -format text` report directory (`urg -dir cov/simv.vdb
    -format text -report cov/urgReport`, whose `modinfo.txt` carries the
    per-module numbers),

and prints one row per RTL unit with covered/total and percentage for each
coverage type, optionally as a delta against a committed baseline.

Why per unit rather than whole design: `verilator_coverage --annotate` only
prints a single design-wide percentage, and the absolute number is meaningless
here anyway -- `gen_rtl/` contains behavioural SRAM models, legs of the design
compiled out by cpu_cfig.h, and the gutted vector path in vidu/, all of which
form an unreachable floor nobody will ever close. What is meaningful is the
*delta* between two runs, which is why --baseline / --save-baseline exist.

A coverage point is attributed to unit X when its source path contains
`gen_rtl/X/rtl/`. That works because Verilator records the filename in every
point, so ONE instrumented compile serves all the units at once and an existing
case (coremark) can be measured for free -- no compile-time scoping needed.

Typical use:

    # reference: what a real workload already covers
    make runcase CASE=coremark SIM=verilator DUMP=off MON=all COVERAGE=line
    make covreport SIM=verilator \\
         COV_ARGS="--save-baseline ../doc/results/unit_coverage_baseline.json"

    # after writing more stimulus
    make runcase CASE=iu_random SIM=verilator DUMP=off COVERAGE=line IU_ITERS=5000
    make covreport SIM=verilator \\
         COV_ARGS="--baseline ../doc/results/unit_coverage_baseline.json --top-cold 5"

Stdlib only, like the rest of cli_tools/.
"""

import argparse
import glob
import json
import os
import re
import sys

# The four pipeline units the randomized stress tests target, plus cp0, plus the
# FP execution units. The FP ones are here because of a measurement: at 200
# iterations vidu_random moved gen_rtl/vidu/ by +0.0 points -- coremark alone
# already covers 96.6% of that directory, and the residue is the tied-off vector
# logic -- while moving vfalu 27.6%->51.2%, vfmau 21.5%->43.8% and vfdsu branch
# 62.2%->92.7%. All of that was invisible in the "other" row. VIDU is only the
# issue queue; the work happens in the units it issues to.
DEFAULT_UNITS = ["ifu", "idu", "iu", "vidu", "cp0",
                 "vdsp", "vfalu", "vfmau", "vfdsu", "vdiv"]

# Coverage types shown, in column order. Verilator emits 'line', 'toggle',
# 'branch', 'expr', 'fsm_state', 'fsm_arc', 'user'; VCS urg gives line, cond,
# branch, toggle, fsm.
DEFAULT_TYPES = ["line", "branch", "toggle"]

# Verilator writes  C '<\x01key\x02value>...' <count>
DAT_RE = re.compile(r"^C '(?P<body>.*)' (?P<count>\d+)\s*$")
UNESC_RE = re.compile(r"%([0-9A-Fa-f]{2})")


def unescape(s):
    """Undo VerilatedCov::dequote(): non-printable, '%' and '"' -> %XX."""
    return UNESC_RE.sub(lambda m: chr(int(m.group(1), 16)), s)


def parse_dat(path, points):
    """Accumulate Verilator coverage points from one coverage.dat.

    points: dict keyed by (type, file, line, col, comment) -> [count, module]
    Counts from several files are summed, which is how cases get merged.
    """
    n = 0
    with open(path, errors="replace") as fh:
        for line in fh:
            m = DAT_RE.match(line)
            if not m:
                continue  # header, blank, or a format we do not know
            kv = {}
            for field in m.group("body").split("\001"):
                if not field:
                    continue
                if "\002" in field:
                    k, v = field.split("\002", 1)
                else:
                    k, v = field, ""
                kv[unescape(k)] = unescape(v)
            # 't' is the short key for type; 'page' is v_<type>/<module>.
            ctype = kv.get("t")
            page = kv.get("page", "")
            module = ""
            if "/" in page:
                module = page.split("/", 1)[1]
            if ctype is None and page.startswith("v_"):
                ctype = page[2:].split("/", 1)[0]
            if ctype is None:
                continue
            key = (ctype, kv.get("f", ""), kv.get("l", ""),
                   kv.get("n", ""), kv.get("o", ""))
            rec = points.get(key)
            if rec is None:
                points[key] = [int(m.group("count")), module]
            else:
                rec[0] += int(m.group("count"))
            n += 1
    return n


def unit_of(path, units):
    """Which RTL unit a source path belongs to, or None."""
    norm = path.replace("\\", "/")
    for u in units:
        if "gen_rtl/%s/rtl/" % u in norm:
            return u
    return None


def tally(points, units, types):
    """-> (per_unit, per_file) tallies of [covered, total] per type."""
    per_unit = {}
    per_file = {}
    for (ctype, fname, lineno, col, comment), (count, module) in points.items():
        if ctype not in types:
            continue
        u = unit_of(fname, units) or "other"
        per_unit.setdefault(u, {}).setdefault(ctype, [0, 0])
        cell = per_unit[u][ctype]
        cell[1] += 1
        if count > 0:
            cell[0] += 1
        if u != "other":
            key = short_path(fname)
            per_file.setdefault(key, {}).setdefault(ctype, [0, 0])
            fcell = per_file[key][ctype]
            fcell[1] += 1
            if count > 0:
                fcell[0] += 1
            else:
                per_file[key].setdefault("_cold_lines", []).append(lineno)
    return per_unit, per_file


def short_path(p):
    """Trim an absolute RTL path down to gen_rtl/<unit>/rtl/<file>."""
    norm = p.replace("\\", "/")
    i = norm.find("gen_rtl/")
    return norm[i:] if i >= 0 else norm


# ---------------------------------------------------------------- VCS urg ----

# urg -format text writes modinfo.txt with a per-module block. The exact layout
# varies between VCS versions, so the parser is deliberately loose: it looks for
# a module name line and then "<covered> / <total>" style score lines. On the
# first real use, check the numbers against urg's own dashboard.html.
URG_MOD_RE = re.compile(r"^\s*(?:Module|MODULE)\s*:\s*(?P<mod>[\w$.]+)")
URG_SCORE_RE = re.compile(
    r"^\s*(?P<what>Line|Cond|Condition|Toggle|Branch|FSM)\b[^\d]*"
    r"(?P<cov>\d+)\s*/\s*(?P<tot>\d+)", re.IGNORECASE)

URG_TYPE_MAP = {"line": "line", "cond": "expr", "condition": "expr",
                "toggle": "toggle", "branch": "branch", "fsm": "fsm_state"}

# module -> unit. All five unit tops and their submodules follow the aq_<unit>_
# prefix convention documented in CLAUDE.md ("Core modules use aq_ prefix").
def unit_of_module(mod, units):
    m = mod.split(".")[-1]
    for u in units:
        if m.startswith("aq_%s_" % u) or m == "aq_%s_top" % u:
            return u
    return None


def parse_urg(dirpath, units, types):
    path = os.path.join(dirpath, "modinfo.txt")
    if not os.path.isfile(path):
        sys.exit("no modinfo.txt in %s -- run urg first "
                 "(make covreport SIM=vcs does that)" % dirpath)
    per_unit = {}
    cur = None
    with open(path, errors="replace") as fh:
        for line in fh:
            m = URG_MOD_RE.match(line)
            if m:
                cur = unit_of_module(m.group("mod"), units)
                continue
            if cur is None:
                continue
            m = URG_SCORE_RE.match(line)
            if not m:
                continue
            ctype = URG_TYPE_MAP.get(m.group("what").lower())
            if ctype is None or ctype not in types:
                continue
            cell = per_unit.setdefault(cur, {}).setdefault(ctype, [0, 0])
            cell[0] += int(m.group("cov"))
            cell[1] += int(m.group("tot"))
    return per_unit, {}


# ----------------------------------------------------------------- output ----

def pct(cov, tot):
    return (100.0 * cov / tot) if tot else 0.0


def fmt_cell(cell):
    if not cell or not cell[1]:
        return "%18s" % "-"
    return "%6d/%-6d %5.1f%%" % (cell[0], cell[1], pct(cell[0], cell[1]))


def print_table(per_unit, units, types, baseline, sources):
    if sources:
        print("source: %s" % " ".join(sources))
    print()
    head = "%-6s" % "unit"
    for t in types:
        head += " %-18s" % t
    if baseline:
        head += " %s" % "  ".join("d%-5s" % t[:5] for t in types)
    print(head)
    rule = "-" * len(head)
    print(rule)

    order = [u for u in units if u in per_unit]
    if "other" in per_unit:
        order.append("other")
    totals = {t: [0, 0] for t in types}
    for u in order:
        row = "%-6s" % u
        for t in types:
            cell = per_unit[u].get(t)
            row += " %s" % fmt_cell(cell)
            if u != "other" and cell:
                totals[t][0] += cell[0]
                totals[t][1] += cell[1]
        if baseline:
            for t in types:
                cell = per_unit[u].get(t)
                base = (baseline.get(u) or {}).get(t)
                if cell and base and base[1]:
                    d = pct(cell[0], cell[1]) - pct(base[0], base[1])
                    row += "  %+5.1f" % d
                else:
                    row += "  %5s" % "-"
        print(row)
    print(rule)
    row = "%-6s" % "TOTAL"
    for t in types:
        row += " %s" % fmt_cell(totals[t])
    print(row)


def print_cold(per_file, types, n):
    ranked = []
    for f, d in per_file.items():
        cold = d.get("_cold_lines") or []
        tot = sum(d[t][1] for t in types if t in d)
        if cold:
            ranked.append((len(cold), tot, f, cold))
    ranked.sort(reverse=True)
    if not ranked:
        return
    print("\ncoldest files (uncovered points / total, first uncovered lines):")
    for ncold, tot, f, cold in ranked[:n]:
        lines = sorted({int(x) for x in cold if x.isdigit()})
        shown = ",".join(str(x) for x in lines[:10])
        more = ",..." if len(lines) > 10 else ""
        print("  %-46s %5d/%-5d  lines %s%s" % (f, ncold, tot, shown, more))


def main():
    ap = argparse.ArgumentParser(
        description="per-unit line/branch/toggle coverage for the C906 "
                    "pipeline units")
    ap.add_argument("--dat", action="append", default=[],
                    help="Verilator coverage.dat file, or a directory to glob "
                         "*.dat from. Repeatable; counts are summed, which is "
                         "how several cases get merged.")
    ap.add_argument("--urg", help="VCS `urg -format text` report directory")
    ap.add_argument("--units", nargs="+", default=DEFAULT_UNITS)
    ap.add_argument("--types", default=",".join(DEFAULT_TYPES),
                    help="comma-separated coverage types (default %s)"
                         % ",".join(DEFAULT_TYPES))
    ap.add_argument("--by", choices=["unit", "file"], default="unit")
    ap.add_argument("--baseline", help="JSON from a previous --save-baseline")
    ap.add_argument("--save-baseline", metavar="FILE")
    ap.add_argument("--format", choices=["text", "csv", "json"], default="text")
    ap.add_argument("--fail-on-regress", action="store_true",
                    help="exit 1 if any (unit,type) covered count dropped "
                         "versus --baseline")
    ap.add_argument("--top-cold", type=int, default=0, metavar="N")
    a = ap.parse_args()

    types = [t.strip() for t in a.types.split(",") if t.strip()]

    if a.urg:
        per_unit, per_file = parse_urg(a.urg, a.units, types)
        sources = [a.urg]
    else:
        files = []
        for spec in (a.dat or ["../cov"]):
            if os.path.isdir(spec):
                files.extend(sorted(glob.glob(os.path.join(spec, "*.dat"))))
            else:
                files.append(spec)
        files = [f for f in files if os.path.isfile(f)]
        if not files:
            sys.exit("no coverage.dat found. Run a case with COVERAGE=line "
                     "first, e.g.\n  make runcase CASE=iu_random "
                     "SIM=verilator DUMP=off COVERAGE=line")
        points = {}
        npoints = 0
        for f in files:
            npoints += parse_dat(f, points)
        if not points:
            sys.exit("parsed %d files but found no coverage points -- check the "
                     "file format with: head -3 %s | cat -v"
                     % (len(files), files[0]))
        per_unit, per_file = tally(points, a.units, types)
        sources = ["%s (%d points, %d unique)"
                   % (" ".join(os.path.basename(f) for f in files),
                      npoints, len(points))]

    baseline = None
    if a.baseline:
        with open(a.baseline) as fh:
            baseline = json.load(fh).get("units", {})

    if a.format == "json":
        json.dump({"units": per_unit}, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    elif a.format == "csv":
        print("unit,type,covered,total,percent")
        for u in sorted(per_unit):
            for t in types:
                cell = per_unit[u].get(t)
                if cell:
                    print("%s,%s,%d,%d,%.2f"
                          % (u, t, cell[0], cell[1], pct(cell[0], cell[1])))
    else:
        print_table(per_unit, a.units, types, baseline, sources)
        if a.by == "file" or a.top_cold:
            print_cold(per_file, types, a.top_cold or 10)

    if a.save_baseline:
        with open(a.save_baseline, "w") as fh:
            json.dump({"units": per_unit, "types": types}, fh,
                      indent=2, sort_keys=True)
        sys.stderr.write("baseline written to %s\n" % a.save_baseline)

    if a.fail_on_regress and baseline:
        bad = []
        for u, d in per_unit.items():
            for t, cell in d.items():
                base = (baseline.get(u) or {}).get(t)
                if base and cell[0] < base[0]:
                    bad.append("%s/%s %d -> %d" % (u, t, base[0], cell[0]))
        if bad:
            sys.stderr.write("coverage regressed: %s\n" % "; ".join(bad))
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
