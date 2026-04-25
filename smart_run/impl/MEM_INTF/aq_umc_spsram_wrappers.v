// SPDX-License-Identifier: Apache-2.0
//
// Thin wrappers that adapt the canonical T-Head single-port SRAM interface
// (A, CEN, CLK, D, GWEN, Q, WEN) -- all CEN/GWEN/WEN active-low -- to the
// TSMC 28HPC+ SP-SRAM macros generated under ../gen_sram/.
//
// TSMC pin convention:
//   CEB  : chip-enable-bar  (active low)            <- CEN
//   WEB  : global write-enable-bar (active low)     <- GWEN
//   BWEB : per-bit  write-enable-bar (active low)   <- WEN
//   SLP/SD : sleep / shutdown -- tie low for normal operation
//   RTSEL[1:0]/WTSEL[1:0] : timing margin select -- datasheet defaults
//                            RTSEL=2'b01, WTSEL=2'b00.
//
// The C906 self-test TBs in this directory drive WEN[i]=1'b1 (no write) when
// idle and assert WEN[i]=1'b0 along with GWEN=1'b0 to write bit i, so passing
// GWEN -> WEB and WEN -> BWEB is a 1:1 mapping.

`timescale 1ns/10ps

// -------------------------------------------------------------------
// 1024 x 16  (BHT, BHT_16K)
// -------------------------------------------------------------------
module aq_umc_spsram_1024x16 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [9:0]  A;
  input         CEN;
  input         CLK;
  input  [15:0] D;
  input         GWEN;
  output [15:0] Q;
  input  [15:0] WEN;

  TS1N28HPCPUHDSVTB1024X16M4SWSO u_mem (
    .SLP   (1'b0),
    .SD    (1'b0),
    .CLK   (CLK),
    .CEB   (CEN),
    .WEB   (GWEN),
    .A     (A),
    .D     (D),
    .BWEB  (WEN),
    .RTSEL (2'b01),
    .WTSEL (2'b00),
    .Q     (Q)
  );
endmodule

// -------------------------------------------------------------------
// 2048 x 32  (I-cache data, ICACHE_32K)
// -------------------------------------------------------------------
module aq_umc_spsram_2048x32 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [10:0] A;
  input         CEN;
  input         CLK;
  input  [31:0] D;
  input         GWEN;
  output [31:0] Q;
  input  [31:0] WEN;

  TS1N28HPCPUHDSVTB2048X32M4SWSO u_mem (
    .SLP   (1'b0),
    .SD    (1'b0),
    .CLK   (CLK),
    .CEB   (CEN),
    .WEB   (GWEN),
    .A     (A),
    .D     (D),
    .BWEB  (WEN),
    .RTSEL (2'b01),
    .WTSEL (2'b00),
    .Q     (Q)
  );
endmodule

// -------------------------------------------------------------------
// 256 x 59  (I-cache tag, ICACHE_32K)
// -------------------------------------------------------------------
module aq_umc_spsram_256x59 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [7:0]  A;
  input         CEN;
  input         CLK;
  input  [58:0] D;
  input         GWEN;
  output [58:0] Q;
  input  [58:0] WEN;

  TS1N28HPCPUHDSVTB256X59M2SW u_mem (
    .CLK   (CLK),
    .CEB   (CEN),
    .WEB   (GWEN),
    .A     (A),
    .D     (D),
    .BWEB  (WEN),
    .RTSEL (2'b01),
    .WTSEL (2'b00),
    .Q     (Q)
  );
endmodule

// -------------------------------------------------------------------
// 1024 x 64  (D-cache data, DCACHE_32K)
// -------------------------------------------------------------------
module aq_umc_spsram_1024x64 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [9:0]  A;
  input         CEN;
  input         CLK;
  input  [63:0] D;
  input         GWEN;
  output [63:0] Q;
  input  [63:0] WEN;

  TS1N28HPCPHVTB1024X64M8SWSO u_mem (
    .SLP   (1'b0),
    .SD    (1'b0),
    .CLK   (CLK),
    .CEB   (CEN),
    .WEB   (GWEN),
    .A     (A),
    .D     (D),
    .BWEB  (WEN),
    .Q     (Q)
  );
endmodule

// -------------------------------------------------------------------
// 64 x 58  (D-cache tag, DCACHE_32K)
// -------------------------------------------------------------------
module aq_umc_spsram_64x58 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [5:0]  A;
  input         CEN;
  input         CLK;
  input  [57:0] D;
  input         GWEN;
  output [57:0] Q;
  input  [57:0] WEN;

  TS1N28HPCPUHDSVTB64X58M2SW u_mem (
    .CLK   (CLK),
    .CEB   (CEN),
    .WEB   (GWEN),
    .A     (A),
    .D     (D),
    .BWEB  (WEN),
    .RTSEL (2'b01),
    .WTSEL (2'b00),
    .Q     (Q)
  );
endmodule

// -------------------------------------------------------------------
// 128 x 8   (D-cache dirty, DCACHE_32K) -- 1-port register file
// -------------------------------------------------------------------
module aq_umc_spsram_128x8 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [6:0]  A;
  input         CEN;
  input         CLK;
  input  [7:0]  D;
  input         GWEN;
  output [7:0]  Q;
  input  [7:0]  WEN;

  TS5N28HPCPSVTA128X8M2FW u_mem (
    .CLK   (CLK),
    .CEB   (CEN),
    .WEB   (GWEN),
    .A     (A),
    .D     (D),
    .BWEB  (WEN),
    .Q     (Q)
  );
endmodule

// -------------------------------------------------------------------
// 64 x 88   (JTLB data, JTLB_ENTRY_128)
// -------------------------------------------------------------------
module aq_umc_spsram_64x88 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [5:0]  A;
  input         CEN;
  input         CLK;
  input  [87:0] D;
  input         GWEN;
  output [87:0] Q;
  input  [87:0] WEN;

  TS1N28HPCPUHDSVTB64X88M2SW u_mem (
    .CLK   (CLK),
    .CEB   (CEN),
    .WEB   (GWEN),
    .A     (A),
    .D     (D),
    .BWEB  (WEN),
    .RTSEL (2'b01),
    .WTSEL (2'b00),
    .Q     (Q)
  );
endmodule

// -------------------------------------------------------------------
// 64 x 98   (JTLB tag, JTLB_ENTRY_128)
// -------------------------------------------------------------------
module aq_umc_spsram_64x98 (A, CEN, CLK, D, GWEN, Q, WEN);
  input  [5:0]  A;
  input         CEN;
  input         CLK;
  input  [97:0] D;
  input         GWEN;
  output [97:0] Q;
  input  [97:0] WEN;

  TS1N28HPCPUHDSVTB64X98M2SW u_mem (
    .CLK   (CLK),
    .CEB   (CEN),
    .WEB   (GWEN),
    .A     (A),
    .D     (D),
    .BWEB  (WEN),
    .RTSEL (2'b01),
    .WTSEL (2'b00),
    .Q     (Q)
  );
endmodule
