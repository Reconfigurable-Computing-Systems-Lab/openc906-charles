// SPDX-License-Identifier: Apache-2.0
//
// ASIC shim that overrides the C906 FPGA behavioral RAM models
// (gen_rtl/fpga/rtl/aq_f_spsram_*.v) with thin wrappers that delegate to
// the TSMC 28HPC+ hard-macro wrappers in
//   smart_run/impl/MEM_INTF/aq_umc_spsram_wrappers.v
//
// Used by the DC synthesis flow (see dc.tcl): the original FPGA .v files are
// filtered out of the filelist, and this shim + aq_umc_spsram_wrappers.v are
// analysed in their place.  The C906 RTL wrappers (aq_spsram_NxM, in
// gen_rtl/{ifu,lsu,mmu}/rtl/) still instantiate aq_f_spsram_NxM by name, so
// the module names below must match exactly.

`timescale 1ns/10ps

module aq_f_spsram_1024x16 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [9:0]  A;
  input         CEN;
  input         CLK;
  input  [15:0] D;
  input         GWEN;
  output [15:0] Q;
  input  [15:0] WEN;
  aq_umc_spsram_1024x16 u_mem (.A(A), .CEN(CEN), .CLK(CLK), .D(D),
                               .GWEN(GWEN), .Q(Q), .WEN(WEN));
endmodule

module aq_f_spsram_2048x32 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [10:0] A;
  input         CEN;
  input         CLK;
  input  [31:0] D;
  input         GWEN;
  output [31:0] Q;
  input  [31:0] WEN;
  aq_umc_spsram_2048x32 u_mem (.A(A), .CEN(CEN), .CLK(CLK), .D(D),
                               .GWEN(GWEN), .Q(Q), .WEN(WEN));
endmodule

module aq_f_spsram_256x59 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [7:0]  A;
  input         CEN;
  input         CLK;
  input  [58:0] D;
  input         GWEN;
  output [58:0] Q;
  input  [58:0] WEN;
  aq_umc_spsram_256x59 u_mem (.A(A), .CEN(CEN), .CLK(CLK), .D(D),
                              .GWEN(GWEN), .Q(Q), .WEN(WEN));
endmodule

module aq_f_spsram_1024x64 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [9:0]  A;
  input         CEN;
  input         CLK;
  input  [63:0] D;
  input         GWEN;
  output [63:0] Q;
  input  [63:0] WEN;
  aq_umc_spsram_1024x64 u_mem (.A(A), .CEN(CEN), .CLK(CLK), .D(D),
                               .GWEN(GWEN), .Q(Q), .WEN(WEN));
endmodule

module aq_f_spsram_64x58 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [5:0]  A;
  input         CEN;
  input         CLK;
  input  [57:0] D;
  input         GWEN;
  output [57:0] Q;
  input  [57:0] WEN;
  aq_umc_spsram_64x58 u_mem (.A(A), .CEN(CEN), .CLK(CLK), .D(D),
                             .GWEN(GWEN), .Q(Q), .WEN(WEN));
endmodule

module aq_f_spsram_64x88 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [5:0]  A;
  input         CEN;
  input         CLK;
  input  [87:0] D;
  input         GWEN;
  output [87:0] Q;
  input  [87:0] WEN;
  aq_umc_spsram_64x88 u_mem (.A(A), .CEN(CEN), .CLK(CLK), .D(D),
                             .GWEN(GWEN), .Q(Q), .WEN(WEN));
endmodule

module aq_f_spsram_64x98 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [5:0]  A;
  input         CEN;
  input         CLK;
  input  [97:0] D;
  input         GWEN;
  output [97:0] Q;
  input  [97:0] WEN;
  aq_umc_spsram_64x98 u_mem (.A(A), .CEN(CEN), .CLK(CLK), .D(D),
                             .GWEN(GWEN), .Q(Q), .WEN(WEN));
endmodule

module aq_f_spsram_128x8 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [6:0]  A;
  input         CEN;
  input         CLK;
  input  [7:0]  D;
  input         GWEN;
  output [7:0]  Q;
  input  [7:0]  WEN;
  aq_umc_spsram_128x8 u_mem (.A(A), .CEN(CEN), .CLK(CLK), .D(D),
                             .GWEN(GWEN), .Q(Q), .WEN(WEN));
endmodule
