#!/usr/bin/env python3
"""
List every net (Verilog wire-type signal) under a chosen top module of a
Verilator `--json-only` AST dump, one full hierarchical path per line.

"Net" means the strict Verilog language definition: wire / tri / wand /
wor / supply nets and ports that resolve to nets. Variables (reg/logic
flops and output regs), parameters, and genvars are excluded; excluded
counts are reported on stderr so the wire/reg split stays visible.

Usage:
    verilator --json-only --json-only-output design.tree.json \\
        --top-module <top> -Wno-fatal -f <filelist>
    python3 list_nets.py \\
        --json <design.tree.json> \\
        --top  <top_module_name> \\
        --out  <nets.txt> \\
        [--dump-modules]

Output format (vector range and unpacked dims appended when present):
    <top>.x_sub_inst.some_scalar
    <top>.x_sub_inst.some_bus [38:0]
    <top>.x_mem.ram [31:0] [0:2047]

Notes on the Verilator 5.x JSON schema this relies on:
  - NETLIST.modulesp is a flat list of MODULE nodes (dead modules
    already pruned when --top-module was given at dump time).
  - CELL links to its module via the "modp" pointer id, matched
    against MODULE "addr" (there is no modName string field).
  - The TYPETABLE under NETLIST.miscsp resolves "dtypep" pointers;
    BASICDTYPE carries "range":"msb:lsb" only when ranged,
    UNPACKARRAYDTYPE carries "declRange":"[l:r]" plus "refDTypep".
"""

import argparse
import json
import sys
from collections import Counter

# Wire-type varTypes to include (strict Verilog nets). PORT appears on
# ports never redeclared as wire/reg; ports redeclared as wire (the
# usual T-Head style) merge into varType WIRE with a direction.
NET_VARTYPES = frozenset({
    "PORT", "WIRE", "IMPLICITWIRE", "TRIWIRE", "TRI0", "TRI1",
    "WAND", "WOR", "SUPPLY0", "SUPPLY1", "WREAL",
})

# Subtrees that can never contain a CELL or a net declaration we want:
# VAR children (valuep/attrsp), CELL pin/param expressions, and
# function/task bodies (locals are not nets).
SKIP_NODE_TYPES = frozenset({"FUNC", "TASK"})
CELL_SKIP_KEYS = frozenset({"pinsp", "paramsp", "rangep", "intfRefsp"})


def iter_child_lists(node):
    for key, val in node.items():
        if isinstance(val, list) and val and isinstance(val[0], dict):
            yield key, val


def build_dtype_index(netlist):
    index = {}
    stack = [m for m in netlist.get("miscsp", []) if m.get("type") == "TYPETABLE"]
    while stack:
        node = stack.pop()
        addr = node.get("addr")
        if addr:
            index[addr] = node
        for _, children in iter_child_lists(node):
            stack.extend(children)
    return index


def dtype_suffix(dtypep, dtype_index):
    """Render ' [msb:lsb]' packed range and ' [l:r]...' unpacked dims."""
    packed = ""
    unpacked = []
    seen = set()
    node = dtype_index.get(dtypep)
    while node is not None and id(node) not in seen:
        seen.add(id(node))
        ntype = node.get("type", "")
        if ntype == "UNPACKARRAYDTYPE":
            unpacked.append(node.get("declRange", "[?]"))
        elif ntype == "PACKARRAYDTYPE":
            packed = " " + node.get("declRange", "[?]") + packed
        elif ntype == "BASICDTYPE":
            if "range" in node:
                packed = " [" + node["range"] + "]" + packed
            break
        else:
            break
        node = dtype_index.get(node.get("refDTypep"))
    return packed + "".join(" " + d for d in unpacked)


def scan_module(module, dtype_index):
    """One pass over a module body: local nets, child cells, and the
    per-module excluded-varType counter. Instance-independent, so the
    result is memoized by the caller."""
    nets = []       # (relative_path, rendered_suffix)
    cells = []      # (instance_name, modp_pointer)
    excluded = Counter()
    stack = [(module, "")]
    while stack:
        node, prefix = stack.pop()
        ctype = node.get("type")
        if ctype == "VAR":
            vartype = node.get("varType", "")
            if vartype in NET_VARTYPES:
                nets.append((prefix + node["name"],
                             dtype_suffix(node.get("dtypep"), dtype_index)))
            else:
                excluded[vartype] += 1
            continue    # never descend into valuep/attrsp
        if ctype == "CELL":
            cells.append((prefix + node["name"], node.get("modp")))
            continue    # pinsp/paramsp reference the parent's vars only
        if ctype in SKIP_NODE_TYPES:
            continue    # function/task locals are not nets
        if ctype in ("BEGIN", "GENBLOCK"):
            # Named scopes add a hierarchy level. Unrolled generate-for
            # iterations arrive as GENBLOCK "NAME[i]"; the extra implied
            # GENBLOCK "NAME" wrapper around them adds no scope level.
            name = node.get("name", "")
            if name and not node.get("implied"):
                prefix = prefix + name + "."
        children = []
        for _, vals in iter_child_lists(node):
            children.extend(vals)
        for child in reversed(children):    # LIFO pop -> declaration order
            stack.append((child, prefix))
    return nets, cells, excluded


def main():
    ap = argparse.ArgumentParser(
        description="List nets under a top module from a Verilator "
                    "--json-only tree dump.")
    ap.add_argument("--json", required=True, help="path to *.tree.json")
    ap.add_argument("--top", required=True, help="top module name (e.g. aq_core)")
    ap.add_argument("--out", required=True, help="output text file")
    ap.add_argument("--dump-modules", action="store_true",
                    help="also list visited module names on stderr")
    args = ap.parse_args()

    with open(args.json) as f:
        netlist = json.load(f)
    if netlist.get("type") != "NETLIST":
        sys.exit("error: %s is not a Verilator NETLIST dump" % args.json)

    modules = [m for m in netlist.get("modulesp", []) if m.get("type") == "MODULE"]
    by_addr = {m["addr"]: m for m in modules}
    top = next((m for m in modules
                if m.get("name") == args.top or m.get("origName") == args.top), None)
    if top is None:
        sys.exit("error: module '%s' not found; modules present: %s"
                 % (args.top, ", ".join(sorted(m.get("name", "?") for m in modules))))

    dtype_index = build_dtype_index(netlist)
    scanned = {}    # module addr -> (nets, cells, excluded)
    lines = []
    excluded_total = Counter()
    visited_modules = Counter()   # origName -> instance count

    def expand(module, inst_path):
        addr = module["addr"]
        if addr not in scanned:
            scanned[addr] = scan_module(module, dtype_index)
        nets, cells, excluded = scanned[addr]
        visited_modules[module.get("origName", module.get("name", "?"))] += 1
        excluded_total.update(excluded)
        for rel, suffix in nets:
            lines.append(inst_path + "." + rel + suffix)
        for cell_name, modp in cells:
            child = by_addr.get(modp)
            if child is None:
                sys.exit("error: cell %s.%s points at unknown module %r"
                         % (inst_path, cell_name, modp))
            expand(child, inst_path + "." + cell_name)

    sys.setrecursionlimit(10000)  # hierarchy depth only; bodies scan iteratively
    expand(top, args.top)

    paths_only = [ln.split(" ", 1)[0] for ln in lines]
    dup = len(paths_only) - len(set(paths_only))
    if dup:
        sys.exit("error: %d duplicate net paths generated — walker bug" % dup)

    with open(args.out, "w") as f:
        f.write("# Nets (wire-type signals) under %s\n" % args.top)
        f.write("# Source: %s (Verilator --json-only dump)\n" % args.json)
        f.write("# Total nets: %d\n" % len(lines))
        for ln in lines:
            f.write(ln + "\n")

    print("total nets (wires):   %d" % len(lines), file=sys.stderr)
    print("module defs visited:  %d  (instances: %d)"
          % (len(visited_modules), sum(visited_modules.values())), file=sys.stderr)
    print("excluded per-instance var counts by varType:", file=sys.stderr)
    for vartype, count in sorted(excluded_total.items(), key=lambda kv: -kv[1]):
        print("    %-14s %d" % (vartype, count), file=sys.stderr)
    if args.dump_modules:
        print("modules (origName x instance count):", file=sys.stderr)
        for name, count in sorted(visited_modules.items()):
            print("    %-40s %d" % (name, count), file=sys.stderr)
    print("wrote %s" % args.out, file=sys.stderr)


if __name__ == "__main__":
    main()
