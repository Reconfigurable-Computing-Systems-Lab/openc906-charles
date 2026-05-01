#!/usr/bin/env python3
"""
Extract a Verdi-compatible .rc waveform file from an .fsdb file, listing
every input/output port of a chosen top module and all of its
submodules, preserving the module hierarchy as nested groups.

Clock and reset ports are always excluded: any port whose leaf name
contains 'clk', 'clock', 'rst', or 'reset' (case-insensitive) is
dropped. This is an aggressive substring match, so unrelated names
embedding those tokens (e.g. arburst, expnt_rst) are also dropped.

Usage:
    python3 extract_rc.py \\
        --fsdb <path/to/file.fsdb> \\
        --type {input,output,all} \\
        --top  <dot.path.to.top> \\
        --out  <path/to/out.rc>

The script shells out to Synopsys `fsdbdebug -hier_tree` to read the
FSDB hierarchy (the FSDB binary format is proprietary). `fsdbdebug`
must be on PATH.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections import OrderedDict


VAR_RE = re.compile(
    r"^Var:\s+\S+\s+(?P<path>\S+?)\s+l:\S+\s+r:\S+\s+(?P<dir>input|output|inout)\b"
)

# Aggressive clock/reset filter: drop any port whose leaf name (with bit
# range stripped) contains 'clk', 'clock', 'rst', or 'reset' (case
# insensitive). Note this also catches some unrelated names that happen
# to embed those substrings (e.g. arburst, expnt_rst); accepted as
# collateral by design.
CLK_RST_RE = re.compile(r"(clk|clock|rst|reset)", re.IGNORECASE)


def is_clk_or_reset(leaf):
    """Return True if `leaf` (a port name possibly ending in [hi:lo])
    looks like a clock or reset signal under the aggressive policy."""
    bare = leaf.split("[", 1)[0]
    return CLK_RST_RE.search(bare) is not None


class Module:
    __slots__ = ("name", "children", "ports")

    def __init__(self, name):
        self.name = name
        # ordered children: instance_name -> Module
        self.children = OrderedDict()
        # ordered ports: list of (leaf_with_range, direction)
        self.ports = []

    def get_or_add_child(self, name):
        if name not in self.children:
            self.children[name] = Module(name)
        return self.children[name]


def run_fsdbdebug(fsdb_path):
    """Invoke fsdbdebug -hier_tree and return its stdout text."""
    if shutil.which("fsdbdebug") is None:
        sys.exit("error: 'fsdbdebug' not found on PATH; source your Verdi setup.")
    if not os.path.isfile(fsdb_path):
        sys.exit(f"error: fsdb file does not exist: {fsdb_path}")

    with tempfile.TemporaryDirectory() as tmp:
        try:
            proc = subprocess.run(
                ["fsdbdebug", "-hier_tree", os.path.abspath(fsdb_path)],
                cwd=tmp,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
            )
        except OSError as e:
            sys.exit(f"error: failed to run fsdbdebug: {e}")
    if proc.returncode != 0 and not proc.stdout:
        sys.exit(
            f"error: fsdbdebug exited {proc.returncode}"
        )
    return proc.stdout


def parse_tree(text):
    """Parse fsdbdebug -hier_tree output into a Module tree.

    Returns a dict { root_inst_name: Module } keyed by every top-level
    scope reported by fsdbdebug (typically `tb`, `mp_top_golden_port`,
    etc.).
    """
    roots = OrderedDict()
    for line in text.splitlines():
        m = VAR_RE.match(line)
        if not m:
            continue
        full = m.group("path")  # e.g. tb.x_soc.x_cpu_top.foo[7:0]
        direction = m.group("dir")

        # Split off the leaf (which may carry a [hi:lo] range suffix).
        # The hierarchical separator is '.'; ranges use '[' and never
        # appear inside an instance name, so the last '.' splits cleanly.
        dot = full.rfind(".")
        if dot < 0:
            # var sitting at root scope — skip; we only emit ports of
            # named modules.
            continue
        scope_path = full[:dot]
        leaf = full[dot + 1 :]

        parts = scope_path.split(".")
        root_name = parts[0]
        if root_name not in roots:
            roots[root_name] = Module(root_name)
        node = roots[root_name]
        for inst in parts[1:]:
            node = node.get_or_add_child(inst)
        node.ports.append((leaf, direction))
    return roots


def normalise_top(top):
    """Return the dot-path components of the top module."""
    s = top.strip().strip("/").replace("/", ".")
    if not s:
        sys.exit("error: --top is empty")
    return s.split(".")


def find_subtree(roots, top_parts):
    node = roots.get(top_parts[0])
    if node is None:
        sys.exit(
            f"error: top scope '{top_parts[0]}' not found in FSDB. "
            f"Known top scopes: {', '.join(roots) or '(none)'}"
        )
    for inst in top_parts[1:]:
        if inst not in node.children:
            sys.exit(
                f"error: instance '{inst}' not found under "
                f"'{'.'.join(top_parts[: top_parts.index(inst)])}'"
            )
        node = node.children[inst]
    return node


def filter_tree(node, want_dirs):
    """Return a new Module tree containing only ports whose direction is
    in want_dirs and that are not clocks/resets. Drops modules whose
    entire subtree has no port."""
    new = Module(node.name)
    new.ports = [
        (leaf, d)
        for (leaf, d) in node.ports
        if d in want_dirs and not is_clk_or_reset(leaf)
    ]
    for inst, child in node.children.items():
        fc = filter_tree(child, want_dirs)
        if fc.ports or fc.children:
            new.children[inst] = fc
    return new


# ---------------------------------------------------------------------------
# .rc emission
# ---------------------------------------------------------------------------

HEADER_TEMPLATE = """Magic 271485
Revision Verdi_X-2025.06

; Window Layout <x> <y> <width> <height> <signalwidth> <valuewidth>
viewPort 0 11 1800 392 550 65

; File list:
; openDirFile [-d delimiter] [-s time_offset] [-rf auto_bus_rule_file] path_name file_name
openDirFile -d / "" "{fsdb}"

; file time scale:
; fileTimeScale ### s|ms|us|ns|ps

; signal spacing:
signalSpacing 5

; windowTimeUnit is used for zoom, cursor & marker
; waveform viewport range
zoom 0.000000 64508759.914164
cursor 0.000000
marker 0.000000

; user define markers
; userMarker time_pos marker_name color linestyle
; visible top row signal index
top 0
; marker line index
markerPos 0

; event list
; addEvent event_name event_expression
; curEvent event_name



COMPLEX_EVENT_BEGIN


COMPLEX_EVENT_END



; toolbar current search type
; curSTATUS search_type
curSTATUS ByChange


"""

TRAILER_TEMPLATE = """
; getSignalForm Scope Hierarchy Status
; active file of getSignalForm
activeDirFile "" "{fsdb}"

GETSIGNALFORM_SCOPE_HIERARCHY_BEGIN
getSignalForm close

"/{root}"

SCOPE_LIST_BEGIN
"/{root}"
SCOPE_LIST_END

GETSIGNALFORM_SCOPE_HIERARCHY_END

"""


def emit_rc(out_path, fsdb_path, top_parts, root_node):
    """Write the .rc file. `root_node` is the filtered top Module."""
    fsdb_abs = os.path.abspath(fsdb_path)
    base_slash = "/" + "/".join(top_parts)  # e.g. /tb/x_soc/.../x_cpu_top

    lines = [HEADER_TEMPLATE.format(fsdb=fsdb_abs)]
    lines.append(f'activeDirFile "" "{fsdb_abs}"\n')
    # Top-level group for the top module.
    lines.append(f'addGroup "{root_node.name}"\n')
    _emit_module_body(lines, root_node, base_slash)
    lines.append(TRAILER_TEMPLATE.format(fsdb=fsdb_abs, root=top_parts[0]))

    with open(out_path, "w") as f:
        f.writelines(lines)


def _emit_module_body(lines, node, slash_path):
    """Emit signals of `node` then recurse into its children as
    addSubGroup/endSubGroup blocks."""
    for leaf, _dir in node.ports:
        lines.append(
            f"addSignal -h 16 -UNSIGNED -HEX {slash_path}/{leaf}\n"
        )
    for inst, child in node.children.items():
        lines.append(f'addSubGroup "{inst}"\n')
        _emit_module_body(lines, child, f"{slash_path}/{inst}")
        lines.append(f'endSubGroup "{inst}"\n')


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    p = argparse.ArgumentParser(
        description="Extract a Verdi .rc file of input/output ports for a "
        "top module and its submodules from an FSDB."
    )
    p.add_argument("--fsdb", required=True, help="path to .fsdb file")
    p.add_argument(
        "--type",
        required=True,
        choices=["input", "output", "all"],
        help="which port directions to extract",
    )
    p.add_argument(
        "--top",
        required=True,
        help="hierarchical path of the top module, dot- or slash-separated "
        "(e.g. tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top)",
    )
    p.add_argument("--out", required=True, help="output .rc file path")
    args = p.parse_args()

    if args.type == "input":
        want = {"input"}
    elif args.type == "output":
        want = {"output"}
    else:
        want = {"input", "output", "inout"}

    text = run_fsdbdebug(args.fsdb)
    roots = parse_tree(text)
    top_parts = normalise_top(args.top)
    top_node = find_subtree(roots, top_parts)
    filtered = filter_tree(top_node, want)

    if not filtered.ports and not filtered.children:
        sys.exit(
            f"error: no ports of type '{args.type}' found under '{args.top}'"
        )

    out_dir = os.path.dirname(os.path.abspath(args.out))
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    emit_rc(args.out, args.fsdb, top_parts, filtered)

    n_ports, n_mods = _stats(filtered)
    print(
        f"wrote {args.out}: {n_ports} signals across {n_mods} modules "
        f"(type={args.type}, top={'.'.join(top_parts)})"
    )


def _stats(node):
    n_ports = len(node.ports)
    n_mods = 1
    for c in node.children.values():
        p, m = _stats(c)
        n_ports += p
        n_mods += m
    return n_ports, n_mods


if __name__ == "__main__":
    main()
