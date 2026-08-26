#!/usr/bin/env python3
"""
Generate a port-toggle monitor for a Verilog module instance, by parsing the
module's own `input`/`output` declarations.

Written for the OpenC906 pipeline-unit tops, whose declarations all follow the
regular T-Head style:

    input   [2  :0]  biu_cp0_coreid;
    output           cp0_ifu_bht_en;

The emitted module samples every port of the instance through a hierarchical
reference once per rising clock edge and accumulates, per port:

  * `mask`  -- OR of every observed transition, so popcount(mask) is the number
               of *bits* of that port that ever changed value;
  * `cnt`   -- number of cycles in which the port's value differed from the
               previous cycle;
  * `xcnt`  -- number of cycles in which the port held an X or Z bit.

At `$finish` a `final` block writes a report listing all three figures per port
plus a summary and the list of ports that never toggled at all. That report is
the evidence that the module was actually stimulated by a test.

The `xcnt` column exists because the accumulate guard is deliberately
*whole-port* (`m | X` would latch X into a mask bit forever, so a per-bit guard
is not an option). Under a 4-state simulator a 180-bit port with one
permanently-X bit therefore records zero toggles for all 180 bits, while under
Verilator with `--x-assign fast` the same port toggles freely. Without the
column, a VCS-versus-Verilator baseline diff is uninterpretable; with it, the
discrepancy is visible instead of mysterious.

Ports whose leaf name is a clock, a reset or a scan pin are classified as
*infrastructure* and excluded from the summary percentage (they are still
listed).

The whole generated file is wrapped in `ifdef <GUARD>` so it can sit in a
filelist permanently and cost nothing -- and so that it is not elaborated as a
stray second top-level module -- until a case defines the macro. The hierarchy
macro is named `<PREFIX>_MON_I` and is `undef`d at the end of the file, so
several generated monitors can be compiled into one elaboration (which is what
MON=all does).

Usage:
    python3 gen_toggle_mon.py --unit iu \\
        --out tests/cases/iu_random/iu_toggle_mon.v

    # or fully explicit:
    python3 gen_toggle_mon.py \\
        --rtl  ../C906_RTL_FACTORY/gen_rtl/cp0/rtl/aq_cp0_top.v \\
        --out  tests/cases/cp0_random/cp0_toggle_mon.v

Options:
    --unit    one of cp0/iu/idu/ifu/vidu; fills in the five defaults below
    --inst    hierarchical path of the instance to probe
    --module  monitor module name          (default <unit>_toggle_mon)
    --define  guard macro                  (default <UNIT>_TOGGLE_MON)
    --prefix  macro / report-text prefix   (default: --define minus _TOGGLE_MON)
    --report  runtime output filename      (default <unit>_toggle.report)
"""

import argparse
import re
import sys

# input/output, optional [msb:lsb] with arbitrary internal padding, then a name.
PORT_RE = re.compile(
    r"^\s*(?P<dir>input|output)\s+"
    r"(?:\[\s*(?P<msb>\d+)\s*:\s*(?P<lsb>\d+)\s*\]\s*)?"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_$]*)\s*;"
)

# Infrastructure = genuine clock / reset / DFT pins only. Deliberately NOT the
# aggressive substring match used by extract_rc.py: on CP0 that would also
# swallow `cp0_yy_clk_en` (the WFI clock enable, the single most important
# output to see toggling), `idu_cp0_ex1_gateclk_sel` (CP0's functional-decode
# qualifier) and the `rst_inv` invalidation handshake -- all functional signals.
# Verified to match exactly cpurst_b / forever_cpuclk / pad_yy_icg_scan_en on
# all five unit tops, and nothing else.
INFRA_RE = re.compile(
    r"^(?:"
    r"forever_[A-Za-z0-9_]*clk"     # forever_cpuclk
    r"|[A-Za-z0-9_]*_clk"           # *_clk
    r"|clk[A-Za-z0-9_]*"            # clk*
    r"|[A-Za-z0-9_]*rst_b"          # cpurst_b
    r"|[A-Za-z0-9_]*scan_en"        # pad_yy_icg_scan_en
    r")$", re.IGNORECASE)

# The one place the testbench hierarchy is written down.
CORE = ("tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top"
        ".x_aq_top_0.x_aq_core")

# unit -> (instance leaf under CORE, top-module file stem)
UNITS = {
    "cp0":  ("x_aq_cp0_top",  "aq_cp0_top"),
    "idu":  ("x_aq_idu_top",  "aq_idu_top"),
    "ifu":  ("x_aq_ifu_top",  "aq_ifu_top"),
    "iu":   ("x_aq_iu_top",   "aq_iu_top"),
    "vidu": ("x_aq_vidu_top", "aq_vidu_top"),
}

DEFAULT_INST = CORE + ".x_aq_cp0_top"

NAME_COL = 34


def parse_ports(path):
    """Return [(name, dir, width, msb, lsb)] in declaration order."""
    ports, seen = [], set()
    with open(path) as fh:
        for line in fh:
            m = PORT_RE.match(line)
            if not m:
                continue
            name = m.group("name")
            if name in seen:
                # T-Head files re-declare ports as wire/reg further down; the
                # input/output declaration is the only one we match, but guard
                # anyway so a duplicate cannot double-generate.
                continue
            seen.add(name)
            if m.group("msb") is None:
                msb = lsb = 0
                width = 1
            else:
                msb, lsb = int(m.group("msb")), int(m.group("lsb"))
                width = abs(msb - lsb) + 1
            ports.append((name, m.group("dir"), width, msb, lsb))
    return ports


def emit(ports, inst, module, guard, report, rtl, prefix):
    max_w = max(p[2] for p in ports)
    infra = [p for p in ports if INFRA_RE.search(p[0])]
    func = [p for p in ports if not INFRA_RE.search(p[0])]
    mac = "%s_MON_I" % prefix

    o = []
    w = o.append

    w("// -------------------------------------------------------------------")
    w("// AUTO-GENERATED -- do not edit by hand.")
    w("//   generator : smart_run/cli_tools/gen_toggle_mon.py")
    w("//   source    : %s" % rtl)
    w("//   ports     : %d total (%d functional, %d infrastructure)"
      % (len(ports), len(func), len(infra)))
    w("//")
    w("// Per-port toggle monitor. Reports, at $finish, how many bits of each")
    w("// port of the probed instance ever changed value. Used to prove that a")
    w("// test actually stimulated the module.")
    w("// -------------------------------------------------------------------")
    w("")
    w("`ifdef %s" % guard)
    w("")
    w("`define %s %s" % (mac, inst))
    w("")
    w("module %s (" % module)
    w("  input clk,")
    w("  input rst_b")
    w(");")
    w("")
    w("integer FH;")
    w("integer n_tog;          // functional ports with at least one bit toggled")
    w("integer n_xseen;        // functional ports that ever held an X/Z bit")
    w("reg     armed;          // suppress the first post-reset comparison")
    w("")
    w("// popcount over the widest port in the module")
    w("function integer ones;")
    w("  input [%d:0] v;" % (max_w - 1))
    w("  integer i;")
    w("  begin")
    w("    ones = 0;")
    w("    for (i = 0; i < %d; i = i + 1)" % max_w)
    w("      if (v[i] === 1'b1) ones = ones + 1;")
    w("  end")
    w("endfunction")
    w("")
    w("always @(posedge clk or negedge rst_b)")
    w("  if (!rst_b) armed <= 1'b0;")
    w("  else        armed <= 1'b1;")
    w("")

    # ---- per-port state ------------------------------------------------
    w("// ---------------- per-port sample / accumulate ----------------")
    for i, (name, d, width, msb, lsb) in enumerate(ports):
        rng = "" if width == 1 else "[%d:0] " % (width - 1)
        w("wire %sc%d = `%s.%s;" % (rng, i, mac, name))
        w("reg  %sp%d;" % (rng, i))
        w("reg  %sm%d;" % (rng, i))
        w("integer n%d;" % i)
        w("integer x%d;" % i)
    w("")

    w("initial begin")
    w("  armed = 1'b0;")
    for i, _ in enumerate(ports):
        w("  p%d = 0; m%d = 0; n%d = 0; x%d = 0;" % (i, i, i, i))
    w("end")
    w("")

    w("always @(posedge clk) begin")
    w("  if (rst_b) begin")
    for i, (name, d, width, msb, lsb) in enumerate(ports):
        # The guard is whole-port on purpose: masking per bit would OR an X
        # into the mask and latch it there forever. x%d makes the cost visible.
        w("    if ($isunknown(c%d)) x%d <= x%d + 1;" % (i, i, i))
        w("    if (armed && !$isunknown(c%d) && !$isunknown(p%d)) begin" % (i, i))
        w("      m%d <= m%d | (c%d ^ p%d);" % (i, i, i, i))
        w("      if (c%d !== p%d) n%d <= n%d + 1;" % (i, i, i, i))
        w("    end")
        w("    p%d <= c%d;" % (i, i))
    w("  end")
    w("end")
    w("")

    # ---- report --------------------------------------------------------
    w("final begin")
    w('  FH = $fopen("%s", "w");' % report)
    w('  $fwrite(FH, "%s port toggle report -- instance:\\n");' % prefix)
    w('  $fwrite(FH, "  %s\\n\\n");' % inst)
    w('  $fwrite(FH, "%s dir  width  bits_tog  tog_events  x_cycles\\n");'
      % "port".ljust(NAME_COL))
    w('  $fwrite(FH, "%s\\n");' % ("-" * (NAME_COL + 42)))
    w("  n_tog = 0;")
    w("  n_xseen = 0;")
    for i, (name, d, width, msb, lsb) in enumerate(ports):
        tag = "in " if d == "input" else "out"
        pad = name.ljust(NAME_COL)
        note = "   [infra]" if INFRA_RE.search(name) else ""
        # Width is known now, so bake it into the literal; only the runtime
        # counters stay as %0d. ones() takes the widest port width, so
        # zero-extend narrower ports before passing the mask in.
        ext = "" if width == max_w else ("%d'b0, " % (max_w - width))
        head = "%s %s %5s" % (pad, tag, width)
        w('  $fwrite(FH, "' + head + ' %0d %0d %0d' + note + '\\n"'
          + ', ones({' + ext + 'm%d}), n%d, x%d);' % (i, i, i))
        if not INFRA_RE.search(name):
            w("  if (|m%d) n_tog = n_tog + 1;" % i)
            w("  if (x%d != 0) n_xseen = n_xseen + 1;" % i)
    w("")
    w('  $fwrite(FH, "\\nSUMMARY: %%0d/%d functional ports toggled '
      '(%d infrastructure ports excluded)\\n", n_tog);' % (len(func), len(infra)))
    w('  $fwrite(FH, "X-SEEN : %0d functional ports held an X/Z bit at some '
      'point\\n", n_xseen);')
    w('  $fwrite(FH, "NEVER TOGGLED:");')
    for i, (name, d, width, msb, lsb) in enumerate(ports):
        if INFRA_RE.search(name):
            continue
        w('  if (~|m%d) $fwrite(FH, " %s");' % (i, name))
    w('  $fwrite(FH, "\\n");')
    w("  $fclose(FH);")
    w('  $display("[%s] %%0d/%d functional %s ports toggled; '
      'report in %s", n_tog);' % (module, len(func), prefix, report))
    w("end")
    w("")
    w("endmodule")
    w("")
    w("`undef %s" % mac)
    w("`endif // %s" % guard)
    w("")
    return "\n".join(o)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--unit", choices=sorted(UNITS),
                    help="fills in --rtl/--inst/--module/--define/--report "
                         "defaults for one of the five pipeline units")
    ap.add_argument("--rtl", default=None,
                    help="path to the module whose ports are probed")
    ap.add_argument("--out", required=True, help="output .v path")
    ap.add_argument("--inst", default=None,
                    help="hierarchical path of the instance to probe")
    ap.add_argument("--module", default=None)
    ap.add_argument("--define", default=None)
    ap.add_argument("--prefix", default=None,
                    help="macro and report-text prefix; default is --define "
                         "with a trailing _TOGGLE_MON stripped")
    ap.add_argument("--report", default=None)
    a = ap.parse_args()

    if a.unit:
        leaf, mod = UNITS[a.unit]
        if a.rtl is None:
            a.rtl = "../C906_RTL_FACTORY/gen_rtl/%s/rtl/%s.v" % (a.unit, mod)
        if a.inst is None:
            a.inst = "%s.%s" % (CORE, leaf)
        if a.module is None:
            a.module = "%s_toggle_mon" % a.unit
        if a.define is None:
            a.define = "%s_TOGGLE_MON" % a.unit.upper()
        if a.report is None:
            a.report = "%s_toggle.report" % a.unit

    # Explicit-flag mode keeps the historical CP0 defaults.
    if a.rtl is None:
        sys.exit("either --unit or --rtl is required")
    if a.inst is None:
        a.inst = DEFAULT_INST
    if a.module is None:
        a.module = "cp0_toggle_mon"
    if a.define is None:
        a.define = "CP0_TOGGLE_MON"
    if a.report is None:
        a.report = "cp0_toggle.report"

    prefix = a.prefix or re.sub(r"_TOGGLE_MON$", "", a.define)

    ports = parse_ports(a.rtl)
    if not ports:
        sys.exit("no input/output declarations found in %s" % a.rtl)

    text = emit(ports, a.inst, a.module, a.define, a.report, a.rtl, prefix)
    with open(a.out, "w") as fh:
        fh.write(text)

    infra = sum(1 for p in ports if INFRA_RE.search(p[0]))
    sys.stderr.write(
        "%s: %d ports (%d functional, %d infrastructure), widest %d bits -> %s\n"
        % (a.rtl, len(ports), len(ports) - infra, infra,
           max(p[2] for p in ports), a.out))


if __name__ == "__main__":
    main()
