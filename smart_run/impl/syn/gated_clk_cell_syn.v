// SPDX-License-Identifier: Apache-2.0
// Synthesis replacement for C906_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v.
//
// The upstream RTL cell is a non-gating pass-through stub (clk_out = clk_in):
// the enable expression is computed but discarded, so every hand-instantiated
// clock gate in the C906 RTL is a wire.  For ASIC synthesis dc.tcl drops that
// file from the filelist and analyzes this one instead, mapping each instance
// onto a real TSMC 28HPC+ integrated clock-gating cell (low-active latch +
// AND, with test-enable override for scan).
//
// Pin mapping (CKLNQD*BWP30P140):
//   CP = clock in, E = functional enable, TE = test enable, Q = gated clock.
// dc.tcl marks these instances set_size_only so DC can resize the drive
// strength but cannot remove the gating function.

module gated_clk_cell(
  clk_in,
  global_en,
  module_en,
  local_en,
  external_en,
  pad_yy_icg_scan_en,
  clk_out
);

input  clk_in;
input  global_en;
input  module_en;
input  local_en;
input  external_en;
input  pad_yy_icg_scan_en;
output clk_out;

wire clk_en_bf_latch = (global_en & (module_en | local_en)) | external_en;

CKLNQD4BWP30P140 x_icg (
  .CP (clk_in),
  .E  (clk_en_bf_latch),
  .TE (pad_yy_icg_scan_en),
  .Q  (clk_out)
);

endmodule
