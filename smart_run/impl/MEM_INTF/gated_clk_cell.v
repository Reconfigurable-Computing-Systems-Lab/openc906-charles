// SPDX-License-Identifier: Apache-2.0
// Behavioural integrated clock-gating cell for MEM_INTF self-test only.
// Replaces the stub at C906_RTL_FACTORY/gen_rtl/clk/rtl/gated_clk_cell.v
// (which is a wire pass-through) with a real low-active latch + AND so the
// c906_icg_test_tb checks pass.

`timescale 1ns/10ps

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
reg  clk_en_latched;

// Low-active latch: capture enable while clk_in is low.
always @(*)
  if (~clk_in)
    clk_en_latched = clk_en_bf_latch | pad_yy_icg_scan_en;

assign clk_out = clk_in & clk_en_latched;

endmodule
