// -------------------------------------------------------------------
// AUTO-GENERATED -- do not edit by hand.
//   generator : smart_run/cli_tools/gen_toggle_mon.py
//   source    : ../C906_RTL_FACTORY/gen_rtl/vidu/rtl/aq_vidu_top.v
//   ports     : 51 total (48 functional, 3 infrastructure)
//
// Per-port toggle monitor. Reports, at $finish, how many bits of each
// port of the probed instance ever changed value. Used to prove that a
// test actually stimulated the module.
// -------------------------------------------------------------------

`ifdef VIDU_TOGGLE_MON

`define VIDU_MON_I tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top.x_aq_top_0.x_aq_core.x_aq_vidu_top

module vidu_toggle_mon (
  input clk,
  input rst_b
);

integer FH;
integer n_tog;          // functional ports with at least one bit toggled
integer n_xseen;        // functional ports that ever held an X/Z bit
reg     armed;          // suppress the first post-reset comparison

// popcount over the widest port in the module
function integer ones;
  input [179:0] v;
  integer i;
  begin
    ones = 0;
    for (i = 0; i < 180; i = i + 1)
      if (v[i] === 1'b1) ones = ones + 1;
  end
endfunction

always @(posedge clk or negedge rst_b)
  if (!rst_b) armed <= 1'b0;
  else        armed <= 1'b1;

// ---------------- per-port sample / accumulate ----------------
wire c0 = `VIDU_MON_I.cp0_idu_icg_en;
reg  p0;
reg  m0;
integer n0;
integer x0;
wire c1 = `VIDU_MON_I.cp0_yy_clk_en;
reg  p1;
reg  m1;
integer n1;
integer x1;
wire c2 = `VIDU_MON_I.cpurst_b;
reg  p2;
reg  m2;
integer n2;
integer x2;
wire c3 = `VIDU_MON_I.forever_cpuclk;
reg  p3;
reg  m3;
integer n3;
integer x3;
wire c4 = `VIDU_MON_I.idu_vidu_ex1_fp_dp_sel;
reg  p4;
reg  m4;
integer n4;
integer x4;
wire c5 = `VIDU_MON_I.idu_vidu_ex1_fp_gateclk_sel;
reg  p5;
reg  m5;
integer n5;
integer x5;
wire c6 = `VIDU_MON_I.idu_vidu_ex1_fp_sel;
reg  p6;
reg  m6;
integer n6;
integer x6;
wire [179:0] c7 = `VIDU_MON_I.idu_vidu_ex1_inst_data;
reg  [179:0] p7;
reg  [179:0] m7;
integer n7;
integer x7;
wire c8 = `VIDU_MON_I.idu_vidu_ex1_vec_dp_sel;
reg  p8;
reg  m8;
integer n8;
integer x8;
wire c9 = `VIDU_MON_I.idu_vidu_ex1_vec_gateclk_sel;
reg  p9;
reg  m9;
integer n9;
integer x9;
wire c10 = `VIDU_MON_I.idu_vidu_ex1_vec_sel;
reg  p10;
reg  m10;
integer n10;
integer x10;
wire c11 = `VIDU_MON_I.ifu_vidu_warm_up;
reg  p11;
reg  m11;
integer n11;
integer x11;
wire c12 = `VIDU_MON_I.pad_yy_icg_scan_en;
reg  p12;
reg  m12;
integer n12;
integer x12;
wire c13 = `VIDU_MON_I.rtu_vidu_flush_wbt;
reg  p13;
reg  m13;
integer n13;
integer x13;
wire c14 = `VIDU_MON_I.rtu_yy_xx_async_flush;
reg  p14;
reg  m14;
integer n14;
integer x14;
wire [63:0] c15 = `VIDU_MON_I.vpu_vidu_fp_fwd_data;
reg  [63:0] p15;
reg  [63:0] m15;
integer n15;
integer x15;
wire [4:0] c16 = `VIDU_MON_I.vpu_vidu_fp_fwd_reg;
reg  [4:0] p16;
reg  [4:0] m16;
integer n16;
integer x16;
wire c17 = `VIDU_MON_I.vpu_vidu_fp_fwd_vld;
reg  p17;
reg  m17;
integer n17;
integer x17;
wire [63:0] c18 = `VIDU_MON_I.vpu_vidu_fp_wb_data;
reg  [63:0] p18;
reg  [63:0] m18;
integer n18;
integer x18;
wire [4:0] c19 = `VIDU_MON_I.vpu_vidu_fp_wb_reg;
reg  [4:0] p19;
reg  [4:0] m19;
integer n19;
integer x19;
wire c20 = `VIDU_MON_I.vpu_vidu_fp_wb_vld;
reg  p20;
reg  m20;
integer n20;
integer x20;
wire c21 = `VIDU_MON_I.vpu_vidu_vex1_fp_stall;
reg  p21;
reg  m21;
integer n21;
integer x21;
wire [4:0] c22 = `VIDU_MON_I.vpu_vidu_wbt_fp_wb0_reg;
reg  [4:0] p22;
reg  [4:0] m22;
integer n22;
integer x22;
wire c23 = `VIDU_MON_I.vpu_vidu_wbt_fp_wb0_vld;
reg  p23;
reg  m23;
integer n23;
integer x23;
wire [4:0] c24 = `VIDU_MON_I.vpu_vidu_wbt_fp_wb1_reg;
reg  [4:0] p24;
reg  [4:0] m24;
integer n24;
integer x24;
wire c25 = `VIDU_MON_I.vpu_vidu_wbt_fp_wb1_vld;
reg  p25;
reg  m25;
integer n25;
integer x25;
wire c26 = `VIDU_MON_I.vidu_cp0_vid_fof_vld;
reg  p26;
reg  m26;
integer n26;
integer x26;
wire [7:0] c27 = `VIDU_MON_I.vidu_dtu_debug_info;
reg  [7:0] p27;
reg  [7:0] m27;
integer n27;
integer x27;
wire c28 = `VIDU_MON_I.vidu_idu_fp_full;
reg  p28;
reg  m28;
integer n28;
integer x28;
wire c29 = `VIDU_MON_I.vidu_idu_vec_full;
reg  p29;
reg  m29;
integer n29;
integer x29;
wire c30 = `VIDU_MON_I.vidu_rtu_no_op;
reg  p30;
reg  m30;
integer n30;
integer x30;
wire c31 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_dp_vld;
reg  p31;
reg  m31;
integer n31;
integer x31;
wire [5:0] c32 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_dst_reg;
reg  [5:0] p32;
reg  [5:0] m32;
integer n32;
integer x32;
wire c33 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_dst_vld;
reg  p33;
reg  m33;
integer n33;
integer x33;
wire c34 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_dste_vld;
reg  p34;
reg  m34;
integer n34;
integer x34;
wire [4:0] c35 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_dstf_reg;
reg  [4:0] p35;
reg  [4:0] m35;
integer n35;
integer x35;
wire c36 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_dstf_vld;
reg  p36;
reg  m36;
integer n36;
integer x36;
wire [9:0] c37 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_eu;
reg  [9:0] p37;
reg  [9:0] m37;
integer n37;
integer x37;
wire [19:0] c38 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_func;
reg  [19:0] p38;
reg  [19:0] m38;
integer n38;
integer x38;
wire c39 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_gateclk_vld;
reg  p39;
reg  m39;
integer n39;
integer x39;
wire [63:0] c40 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_src1_data;
reg  [63:0] p40;
reg  [63:0] m40;
integer n40;
integer x40;
wire [63:0] c41 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_srcf0_data;
reg  [63:0] p41;
reg  [63:0] m41;
integer n41;
integer x41;
wire [63:0] c42 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_srcf1_data;
reg  [63:0] p42;
reg  [63:0] m42;
integer n42;
integer x42;
wire [63:0] c43 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_srcf2_data;
reg  [63:0] p43;
reg  [63:0] m43;
integer n43;
integer x43;
wire c44 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_srcf2_rdy;
reg  p44;
reg  m44;
integer n44;
integer x44;
wire c45 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_srcf2_vld;
reg  p45;
reg  m45;
integer n45;
integer x45;
wire c46 = `VIDU_MON_I.vidu_vpu_vid_fp_inst_vld;
reg  p46;
reg  m46;
integer n46;
integer x46;
wire c47 = `VIDU_MON_I.vpu_rtu_ex1_cmplt;
reg  p47;
reg  m47;
integer n47;
integer x47;
wire c48 = `VIDU_MON_I.vpu_rtu_ex1_cmplt_dp;
reg  p48;
reg  m48;
integer n48;
integer x48;
wire c49 = `VIDU_MON_I.vpu_rtu_ex1_fp_dirty;
reg  p49;
reg  m49;
integer n49;
integer x49;
wire c50 = `VIDU_MON_I.vpu_rtu_ex1_vec_dirty;
reg  p50;
reg  m50;
integer n50;
integer x50;

initial begin
  armed = 1'b0;
  p0 = 0; m0 = 0; n0 = 0; x0 = 0;
  p1 = 0; m1 = 0; n1 = 0; x1 = 0;
  p2 = 0; m2 = 0; n2 = 0; x2 = 0;
  p3 = 0; m3 = 0; n3 = 0; x3 = 0;
  p4 = 0; m4 = 0; n4 = 0; x4 = 0;
  p5 = 0; m5 = 0; n5 = 0; x5 = 0;
  p6 = 0; m6 = 0; n6 = 0; x6 = 0;
  p7 = 0; m7 = 0; n7 = 0; x7 = 0;
  p8 = 0; m8 = 0; n8 = 0; x8 = 0;
  p9 = 0; m9 = 0; n9 = 0; x9 = 0;
  p10 = 0; m10 = 0; n10 = 0; x10 = 0;
  p11 = 0; m11 = 0; n11 = 0; x11 = 0;
  p12 = 0; m12 = 0; n12 = 0; x12 = 0;
  p13 = 0; m13 = 0; n13 = 0; x13 = 0;
  p14 = 0; m14 = 0; n14 = 0; x14 = 0;
  p15 = 0; m15 = 0; n15 = 0; x15 = 0;
  p16 = 0; m16 = 0; n16 = 0; x16 = 0;
  p17 = 0; m17 = 0; n17 = 0; x17 = 0;
  p18 = 0; m18 = 0; n18 = 0; x18 = 0;
  p19 = 0; m19 = 0; n19 = 0; x19 = 0;
  p20 = 0; m20 = 0; n20 = 0; x20 = 0;
  p21 = 0; m21 = 0; n21 = 0; x21 = 0;
  p22 = 0; m22 = 0; n22 = 0; x22 = 0;
  p23 = 0; m23 = 0; n23 = 0; x23 = 0;
  p24 = 0; m24 = 0; n24 = 0; x24 = 0;
  p25 = 0; m25 = 0; n25 = 0; x25 = 0;
  p26 = 0; m26 = 0; n26 = 0; x26 = 0;
  p27 = 0; m27 = 0; n27 = 0; x27 = 0;
  p28 = 0; m28 = 0; n28 = 0; x28 = 0;
  p29 = 0; m29 = 0; n29 = 0; x29 = 0;
  p30 = 0; m30 = 0; n30 = 0; x30 = 0;
  p31 = 0; m31 = 0; n31 = 0; x31 = 0;
  p32 = 0; m32 = 0; n32 = 0; x32 = 0;
  p33 = 0; m33 = 0; n33 = 0; x33 = 0;
  p34 = 0; m34 = 0; n34 = 0; x34 = 0;
  p35 = 0; m35 = 0; n35 = 0; x35 = 0;
  p36 = 0; m36 = 0; n36 = 0; x36 = 0;
  p37 = 0; m37 = 0; n37 = 0; x37 = 0;
  p38 = 0; m38 = 0; n38 = 0; x38 = 0;
  p39 = 0; m39 = 0; n39 = 0; x39 = 0;
  p40 = 0; m40 = 0; n40 = 0; x40 = 0;
  p41 = 0; m41 = 0; n41 = 0; x41 = 0;
  p42 = 0; m42 = 0; n42 = 0; x42 = 0;
  p43 = 0; m43 = 0; n43 = 0; x43 = 0;
  p44 = 0; m44 = 0; n44 = 0; x44 = 0;
  p45 = 0; m45 = 0; n45 = 0; x45 = 0;
  p46 = 0; m46 = 0; n46 = 0; x46 = 0;
  p47 = 0; m47 = 0; n47 = 0; x47 = 0;
  p48 = 0; m48 = 0; n48 = 0; x48 = 0;
  p49 = 0; m49 = 0; n49 = 0; x49 = 0;
  p50 = 0; m50 = 0; n50 = 0; x50 = 0;
end

always @(posedge clk) begin
  if (rst_b) begin
    if ($isunknown(c0)) x0 <= x0 + 1;
    if (armed && !$isunknown(c0) && !$isunknown(p0)) begin
      m0 <= m0 | (c0 ^ p0);
      if (c0 !== p0) n0 <= n0 + 1;
    end
    p0 <= c0;
    if ($isunknown(c1)) x1 <= x1 + 1;
    if (armed && !$isunknown(c1) && !$isunknown(p1)) begin
      m1 <= m1 | (c1 ^ p1);
      if (c1 !== p1) n1 <= n1 + 1;
    end
    p1 <= c1;
    if ($isunknown(c2)) x2 <= x2 + 1;
    if (armed && !$isunknown(c2) && !$isunknown(p2)) begin
      m2 <= m2 | (c2 ^ p2);
      if (c2 !== p2) n2 <= n2 + 1;
    end
    p2 <= c2;
    if ($isunknown(c3)) x3 <= x3 + 1;
    if (armed && !$isunknown(c3) && !$isunknown(p3)) begin
      m3 <= m3 | (c3 ^ p3);
      if (c3 !== p3) n3 <= n3 + 1;
    end
    p3 <= c3;
    if ($isunknown(c4)) x4 <= x4 + 1;
    if (armed && !$isunknown(c4) && !$isunknown(p4)) begin
      m4 <= m4 | (c4 ^ p4);
      if (c4 !== p4) n4 <= n4 + 1;
    end
    p4 <= c4;
    if ($isunknown(c5)) x5 <= x5 + 1;
    if (armed && !$isunknown(c5) && !$isunknown(p5)) begin
      m5 <= m5 | (c5 ^ p5);
      if (c5 !== p5) n5 <= n5 + 1;
    end
    p5 <= c5;
    if ($isunknown(c6)) x6 <= x6 + 1;
    if (armed && !$isunknown(c6) && !$isunknown(p6)) begin
      m6 <= m6 | (c6 ^ p6);
      if (c6 !== p6) n6 <= n6 + 1;
    end
    p6 <= c6;
    if ($isunknown(c7)) x7 <= x7 + 1;
    if (armed && !$isunknown(c7) && !$isunknown(p7)) begin
      m7 <= m7 | (c7 ^ p7);
      if (c7 !== p7) n7 <= n7 + 1;
    end
    p7 <= c7;
    if ($isunknown(c8)) x8 <= x8 + 1;
    if (armed && !$isunknown(c8) && !$isunknown(p8)) begin
      m8 <= m8 | (c8 ^ p8);
      if (c8 !== p8) n8 <= n8 + 1;
    end
    p8 <= c8;
    if ($isunknown(c9)) x9 <= x9 + 1;
    if (armed && !$isunknown(c9) && !$isunknown(p9)) begin
      m9 <= m9 | (c9 ^ p9);
      if (c9 !== p9) n9 <= n9 + 1;
    end
    p9 <= c9;
    if ($isunknown(c10)) x10 <= x10 + 1;
    if (armed && !$isunknown(c10) && !$isunknown(p10)) begin
      m10 <= m10 | (c10 ^ p10);
      if (c10 !== p10) n10 <= n10 + 1;
    end
    p10 <= c10;
    if ($isunknown(c11)) x11 <= x11 + 1;
    if (armed && !$isunknown(c11) && !$isunknown(p11)) begin
      m11 <= m11 | (c11 ^ p11);
      if (c11 !== p11) n11 <= n11 + 1;
    end
    p11 <= c11;
    if ($isunknown(c12)) x12 <= x12 + 1;
    if (armed && !$isunknown(c12) && !$isunknown(p12)) begin
      m12 <= m12 | (c12 ^ p12);
      if (c12 !== p12) n12 <= n12 + 1;
    end
    p12 <= c12;
    if ($isunknown(c13)) x13 <= x13 + 1;
    if (armed && !$isunknown(c13) && !$isunknown(p13)) begin
      m13 <= m13 | (c13 ^ p13);
      if (c13 !== p13) n13 <= n13 + 1;
    end
    p13 <= c13;
    if ($isunknown(c14)) x14 <= x14 + 1;
    if (armed && !$isunknown(c14) && !$isunknown(p14)) begin
      m14 <= m14 | (c14 ^ p14);
      if (c14 !== p14) n14 <= n14 + 1;
    end
    p14 <= c14;
    if ($isunknown(c15)) x15 <= x15 + 1;
    if (armed && !$isunknown(c15) && !$isunknown(p15)) begin
      m15 <= m15 | (c15 ^ p15);
      if (c15 !== p15) n15 <= n15 + 1;
    end
    p15 <= c15;
    if ($isunknown(c16)) x16 <= x16 + 1;
    if (armed && !$isunknown(c16) && !$isunknown(p16)) begin
      m16 <= m16 | (c16 ^ p16);
      if (c16 !== p16) n16 <= n16 + 1;
    end
    p16 <= c16;
    if ($isunknown(c17)) x17 <= x17 + 1;
    if (armed && !$isunknown(c17) && !$isunknown(p17)) begin
      m17 <= m17 | (c17 ^ p17);
      if (c17 !== p17) n17 <= n17 + 1;
    end
    p17 <= c17;
    if ($isunknown(c18)) x18 <= x18 + 1;
    if (armed && !$isunknown(c18) && !$isunknown(p18)) begin
      m18 <= m18 | (c18 ^ p18);
      if (c18 !== p18) n18 <= n18 + 1;
    end
    p18 <= c18;
    if ($isunknown(c19)) x19 <= x19 + 1;
    if (armed && !$isunknown(c19) && !$isunknown(p19)) begin
      m19 <= m19 | (c19 ^ p19);
      if (c19 !== p19) n19 <= n19 + 1;
    end
    p19 <= c19;
    if ($isunknown(c20)) x20 <= x20 + 1;
    if (armed && !$isunknown(c20) && !$isunknown(p20)) begin
      m20 <= m20 | (c20 ^ p20);
      if (c20 !== p20) n20 <= n20 + 1;
    end
    p20 <= c20;
    if ($isunknown(c21)) x21 <= x21 + 1;
    if (armed && !$isunknown(c21) && !$isunknown(p21)) begin
      m21 <= m21 | (c21 ^ p21);
      if (c21 !== p21) n21 <= n21 + 1;
    end
    p21 <= c21;
    if ($isunknown(c22)) x22 <= x22 + 1;
    if (armed && !$isunknown(c22) && !$isunknown(p22)) begin
      m22 <= m22 | (c22 ^ p22);
      if (c22 !== p22) n22 <= n22 + 1;
    end
    p22 <= c22;
    if ($isunknown(c23)) x23 <= x23 + 1;
    if (armed && !$isunknown(c23) && !$isunknown(p23)) begin
      m23 <= m23 | (c23 ^ p23);
      if (c23 !== p23) n23 <= n23 + 1;
    end
    p23 <= c23;
    if ($isunknown(c24)) x24 <= x24 + 1;
    if (armed && !$isunknown(c24) && !$isunknown(p24)) begin
      m24 <= m24 | (c24 ^ p24);
      if (c24 !== p24) n24 <= n24 + 1;
    end
    p24 <= c24;
    if ($isunknown(c25)) x25 <= x25 + 1;
    if (armed && !$isunknown(c25) && !$isunknown(p25)) begin
      m25 <= m25 | (c25 ^ p25);
      if (c25 !== p25) n25 <= n25 + 1;
    end
    p25 <= c25;
    if ($isunknown(c26)) x26 <= x26 + 1;
    if (armed && !$isunknown(c26) && !$isunknown(p26)) begin
      m26 <= m26 | (c26 ^ p26);
      if (c26 !== p26) n26 <= n26 + 1;
    end
    p26 <= c26;
    if ($isunknown(c27)) x27 <= x27 + 1;
    if (armed && !$isunknown(c27) && !$isunknown(p27)) begin
      m27 <= m27 | (c27 ^ p27);
      if (c27 !== p27) n27 <= n27 + 1;
    end
    p27 <= c27;
    if ($isunknown(c28)) x28 <= x28 + 1;
    if (armed && !$isunknown(c28) && !$isunknown(p28)) begin
      m28 <= m28 | (c28 ^ p28);
      if (c28 !== p28) n28 <= n28 + 1;
    end
    p28 <= c28;
    if ($isunknown(c29)) x29 <= x29 + 1;
    if (armed && !$isunknown(c29) && !$isunknown(p29)) begin
      m29 <= m29 | (c29 ^ p29);
      if (c29 !== p29) n29 <= n29 + 1;
    end
    p29 <= c29;
    if ($isunknown(c30)) x30 <= x30 + 1;
    if (armed && !$isunknown(c30) && !$isunknown(p30)) begin
      m30 <= m30 | (c30 ^ p30);
      if (c30 !== p30) n30 <= n30 + 1;
    end
    p30 <= c30;
    if ($isunknown(c31)) x31 <= x31 + 1;
    if (armed && !$isunknown(c31) && !$isunknown(p31)) begin
      m31 <= m31 | (c31 ^ p31);
      if (c31 !== p31) n31 <= n31 + 1;
    end
    p31 <= c31;
    if ($isunknown(c32)) x32 <= x32 + 1;
    if (armed && !$isunknown(c32) && !$isunknown(p32)) begin
      m32 <= m32 | (c32 ^ p32);
      if (c32 !== p32) n32 <= n32 + 1;
    end
    p32 <= c32;
    if ($isunknown(c33)) x33 <= x33 + 1;
    if (armed && !$isunknown(c33) && !$isunknown(p33)) begin
      m33 <= m33 | (c33 ^ p33);
      if (c33 !== p33) n33 <= n33 + 1;
    end
    p33 <= c33;
    if ($isunknown(c34)) x34 <= x34 + 1;
    if (armed && !$isunknown(c34) && !$isunknown(p34)) begin
      m34 <= m34 | (c34 ^ p34);
      if (c34 !== p34) n34 <= n34 + 1;
    end
    p34 <= c34;
    if ($isunknown(c35)) x35 <= x35 + 1;
    if (armed && !$isunknown(c35) && !$isunknown(p35)) begin
      m35 <= m35 | (c35 ^ p35);
      if (c35 !== p35) n35 <= n35 + 1;
    end
    p35 <= c35;
    if ($isunknown(c36)) x36 <= x36 + 1;
    if (armed && !$isunknown(c36) && !$isunknown(p36)) begin
      m36 <= m36 | (c36 ^ p36);
      if (c36 !== p36) n36 <= n36 + 1;
    end
    p36 <= c36;
    if ($isunknown(c37)) x37 <= x37 + 1;
    if (armed && !$isunknown(c37) && !$isunknown(p37)) begin
      m37 <= m37 | (c37 ^ p37);
      if (c37 !== p37) n37 <= n37 + 1;
    end
    p37 <= c37;
    if ($isunknown(c38)) x38 <= x38 + 1;
    if (armed && !$isunknown(c38) && !$isunknown(p38)) begin
      m38 <= m38 | (c38 ^ p38);
      if (c38 !== p38) n38 <= n38 + 1;
    end
    p38 <= c38;
    if ($isunknown(c39)) x39 <= x39 + 1;
    if (armed && !$isunknown(c39) && !$isunknown(p39)) begin
      m39 <= m39 | (c39 ^ p39);
      if (c39 !== p39) n39 <= n39 + 1;
    end
    p39 <= c39;
    if ($isunknown(c40)) x40 <= x40 + 1;
    if (armed && !$isunknown(c40) && !$isunknown(p40)) begin
      m40 <= m40 | (c40 ^ p40);
      if (c40 !== p40) n40 <= n40 + 1;
    end
    p40 <= c40;
    if ($isunknown(c41)) x41 <= x41 + 1;
    if (armed && !$isunknown(c41) && !$isunknown(p41)) begin
      m41 <= m41 | (c41 ^ p41);
      if (c41 !== p41) n41 <= n41 + 1;
    end
    p41 <= c41;
    if ($isunknown(c42)) x42 <= x42 + 1;
    if (armed && !$isunknown(c42) && !$isunknown(p42)) begin
      m42 <= m42 | (c42 ^ p42);
      if (c42 !== p42) n42 <= n42 + 1;
    end
    p42 <= c42;
    if ($isunknown(c43)) x43 <= x43 + 1;
    if (armed && !$isunknown(c43) && !$isunknown(p43)) begin
      m43 <= m43 | (c43 ^ p43);
      if (c43 !== p43) n43 <= n43 + 1;
    end
    p43 <= c43;
    if ($isunknown(c44)) x44 <= x44 + 1;
    if (armed && !$isunknown(c44) && !$isunknown(p44)) begin
      m44 <= m44 | (c44 ^ p44);
      if (c44 !== p44) n44 <= n44 + 1;
    end
    p44 <= c44;
    if ($isunknown(c45)) x45 <= x45 + 1;
    if (armed && !$isunknown(c45) && !$isunknown(p45)) begin
      m45 <= m45 | (c45 ^ p45);
      if (c45 !== p45) n45 <= n45 + 1;
    end
    p45 <= c45;
    if ($isunknown(c46)) x46 <= x46 + 1;
    if (armed && !$isunknown(c46) && !$isunknown(p46)) begin
      m46 <= m46 | (c46 ^ p46);
      if (c46 !== p46) n46 <= n46 + 1;
    end
    p46 <= c46;
    if ($isunknown(c47)) x47 <= x47 + 1;
    if (armed && !$isunknown(c47) && !$isunknown(p47)) begin
      m47 <= m47 | (c47 ^ p47);
      if (c47 !== p47) n47 <= n47 + 1;
    end
    p47 <= c47;
    if ($isunknown(c48)) x48 <= x48 + 1;
    if (armed && !$isunknown(c48) && !$isunknown(p48)) begin
      m48 <= m48 | (c48 ^ p48);
      if (c48 !== p48) n48 <= n48 + 1;
    end
    p48 <= c48;
    if ($isunknown(c49)) x49 <= x49 + 1;
    if (armed && !$isunknown(c49) && !$isunknown(p49)) begin
      m49 <= m49 | (c49 ^ p49);
      if (c49 !== p49) n49 <= n49 + 1;
    end
    p49 <= c49;
    if ($isunknown(c50)) x50 <= x50 + 1;
    if (armed && !$isunknown(c50) && !$isunknown(p50)) begin
      m50 <= m50 | (c50 ^ p50);
      if (c50 !== p50) n50 <= n50 + 1;
    end
    p50 <= c50;
  end
end

final begin
  FH = $fopen("vidu_toggle.report", "w");
  $fwrite(FH, "VIDU port toggle report -- instance:\n");
  $fwrite(FH, "  tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top.x_aq_top_0.x_aq_core.x_aq_vidu_top\n\n");
  $fwrite(FH, "port                               dir  width  bits_tog  tog_events  x_cycles\n");
  $fwrite(FH, "----------------------------------------------------------------------------\n");
  n_tog = 0;
  n_xseen = 0;
  $fwrite(FH, "cp0_idu_icg_en                     in      1 %0d %0d %0d\n", ones({179'b0, m0}), n0, x0);
  if (|m0) n_tog = n_tog + 1;
  if (x0 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_yy_clk_en                      in      1 %0d %0d %0d\n", ones({179'b0, m1}), n1, x1);
  if (|m1) n_tog = n_tog + 1;
  if (x1 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cpurst_b                           in      1 %0d %0d %0d   [infra]\n", ones({179'b0, m2}), n2, x2);
  $fwrite(FH, "forever_cpuclk                     in      1 %0d %0d %0d   [infra]\n", ones({179'b0, m3}), n3, x3);
  $fwrite(FH, "idu_vidu_ex1_fp_dp_sel             in      1 %0d %0d %0d\n", ones({179'b0, m4}), n4, x4);
  if (|m4) n_tog = n_tog + 1;
  if (x4 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_fp_gateclk_sel        in      1 %0d %0d %0d\n", ones({179'b0, m5}), n5, x5);
  if (|m5) n_tog = n_tog + 1;
  if (x5 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_fp_sel                in      1 %0d %0d %0d\n", ones({179'b0, m6}), n6, x6);
  if (|m6) n_tog = n_tog + 1;
  if (x6 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_inst_data             in    180 %0d %0d %0d\n", ones({m7}), n7, x7);
  if (|m7) n_tog = n_tog + 1;
  if (x7 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_vec_dp_sel            in      1 %0d %0d %0d\n", ones({179'b0, m8}), n8, x8);
  if (|m8) n_tog = n_tog + 1;
  if (x8 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_vec_gateclk_sel       in      1 %0d %0d %0d\n", ones({179'b0, m9}), n9, x9);
  if (|m9) n_tog = n_tog + 1;
  if (x9 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_vec_sel               in      1 %0d %0d %0d\n", ones({179'b0, m10}), n10, x10);
  if (|m10) n_tog = n_tog + 1;
  if (x10 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_vidu_warm_up                   in      1 %0d %0d %0d\n", ones({179'b0, m11}), n11, x11);
  if (|m11) n_tog = n_tog + 1;
  if (x11 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "pad_yy_icg_scan_en                 in      1 %0d %0d %0d   [infra]\n", ones({179'b0, m12}), n12, x12);
  $fwrite(FH, "rtu_vidu_flush_wbt                 in      1 %0d %0d %0d\n", ones({179'b0, m13}), n13, x13);
  if (|m13) n_tog = n_tog + 1;
  if (x13 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_yy_xx_async_flush              in      1 %0d %0d %0d\n", ones({179'b0, m14}), n14, x14);
  if (|m14) n_tog = n_tog + 1;
  if (x14 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_vidu_fp_fwd_data               in     64 %0d %0d %0d\n", ones({116'b0, m15}), n15, x15);
  if (|m15) n_tog = n_tog + 1;
  if (x15 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_vidu_fp_fwd_reg                in      5 %0d %0d %0d\n", ones({175'b0, m16}), n16, x16);
  if (|m16) n_tog = n_tog + 1;
  if (x16 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_vidu_fp_fwd_vld                in      1 %0d %0d %0d\n", ones({179'b0, m17}), n17, x17);
  if (|m17) n_tog = n_tog + 1;
  if (x17 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_vidu_fp_wb_data                in     64 %0d %0d %0d\n", ones({116'b0, m18}), n18, x18);
  if (|m18) n_tog = n_tog + 1;
  if (x18 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_vidu_fp_wb_reg                 in      5 %0d %0d %0d\n", ones({175'b0, m19}), n19, x19);
  if (|m19) n_tog = n_tog + 1;
  if (x19 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_vidu_fp_wb_vld                 in      1 %0d %0d %0d\n", ones({179'b0, m20}), n20, x20);
  if (|m20) n_tog = n_tog + 1;
  if (x20 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_vidu_vex1_fp_stall             in      1 %0d %0d %0d\n", ones({179'b0, m21}), n21, x21);
  if (|m21) n_tog = n_tog + 1;
  if (x21 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_vidu_wbt_fp_wb0_reg            in      5 %0d %0d %0d\n", ones({175'b0, m22}), n22, x22);
  if (|m22) n_tog = n_tog + 1;
  if (x22 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_vidu_wbt_fp_wb0_vld            in      1 %0d %0d %0d\n", ones({179'b0, m23}), n23, x23);
  if (|m23) n_tog = n_tog + 1;
  if (x23 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_vidu_wbt_fp_wb1_reg            in      5 %0d %0d %0d\n", ones({175'b0, m24}), n24, x24);
  if (|m24) n_tog = n_tog + 1;
  if (x24 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_vidu_wbt_fp_wb1_vld            in      1 %0d %0d %0d\n", ones({179'b0, m25}), n25, x25);
  if (|m25) n_tog = n_tog + 1;
  if (x25 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_cp0_vid_fof_vld               out     1 %0d %0d %0d\n", ones({179'b0, m26}), n26, x26);
  if (|m26) n_tog = n_tog + 1;
  if (x26 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_dtu_debug_info                out     8 %0d %0d %0d\n", ones({172'b0, m27}), n27, x27);
  if (|m27) n_tog = n_tog + 1;
  if (x27 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_idu_fp_full                   out     1 %0d %0d %0d\n", ones({179'b0, m28}), n28, x28);
  if (|m28) n_tog = n_tog + 1;
  if (x28 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_idu_vec_full                  out     1 %0d %0d %0d\n", ones({179'b0, m29}), n29, x29);
  if (|m29) n_tog = n_tog + 1;
  if (x29 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_rtu_no_op                     out     1 %0d %0d %0d\n", ones({179'b0, m30}), n30, x30);
  if (|m30) n_tog = n_tog + 1;
  if (x30 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_dp_vld        out     1 %0d %0d %0d\n", ones({179'b0, m31}), n31, x31);
  if (|m31) n_tog = n_tog + 1;
  if (x31 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_dst_reg       out     6 %0d %0d %0d\n", ones({174'b0, m32}), n32, x32);
  if (|m32) n_tog = n_tog + 1;
  if (x32 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_dst_vld       out     1 %0d %0d %0d\n", ones({179'b0, m33}), n33, x33);
  if (|m33) n_tog = n_tog + 1;
  if (x33 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_dste_vld      out     1 %0d %0d %0d\n", ones({179'b0, m34}), n34, x34);
  if (|m34) n_tog = n_tog + 1;
  if (x34 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_dstf_reg      out     5 %0d %0d %0d\n", ones({175'b0, m35}), n35, x35);
  if (|m35) n_tog = n_tog + 1;
  if (x35 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_dstf_vld      out     1 %0d %0d %0d\n", ones({179'b0, m36}), n36, x36);
  if (|m36) n_tog = n_tog + 1;
  if (x36 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_eu            out    10 %0d %0d %0d\n", ones({170'b0, m37}), n37, x37);
  if (|m37) n_tog = n_tog + 1;
  if (x37 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_func          out    20 %0d %0d %0d\n", ones({160'b0, m38}), n38, x38);
  if (|m38) n_tog = n_tog + 1;
  if (x38 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_gateclk_vld   out     1 %0d %0d %0d\n", ones({179'b0, m39}), n39, x39);
  if (|m39) n_tog = n_tog + 1;
  if (x39 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_src1_data     out    64 %0d %0d %0d\n", ones({116'b0, m40}), n40, x40);
  if (|m40) n_tog = n_tog + 1;
  if (x40 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_srcf0_data    out    64 %0d %0d %0d\n", ones({116'b0, m41}), n41, x41);
  if (|m41) n_tog = n_tog + 1;
  if (x41 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_srcf1_data    out    64 %0d %0d %0d\n", ones({116'b0, m42}), n42, x42);
  if (|m42) n_tog = n_tog + 1;
  if (x42 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_srcf2_data    out    64 %0d %0d %0d\n", ones({116'b0, m43}), n43, x43);
  if (|m43) n_tog = n_tog + 1;
  if (x43 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_srcf2_rdy     out     1 %0d %0d %0d\n", ones({179'b0, m44}), n44, x44);
  if (|m44) n_tog = n_tog + 1;
  if (x44 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_srcf2_vld     out     1 %0d %0d %0d\n", ones({179'b0, m45}), n45, x45);
  if (|m45) n_tog = n_tog + 1;
  if (x45 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_vpu_vid_fp_inst_vld           out     1 %0d %0d %0d\n", ones({179'b0, m46}), n46, x46);
  if (|m46) n_tog = n_tog + 1;
  if (x46 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_rtu_ex1_cmplt                  out     1 %0d %0d %0d\n", ones({179'b0, m47}), n47, x47);
  if (|m47) n_tog = n_tog + 1;
  if (x47 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_rtu_ex1_cmplt_dp               out     1 %0d %0d %0d\n", ones({179'b0, m48}), n48, x48);
  if (|m48) n_tog = n_tog + 1;
  if (x48 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_rtu_ex1_fp_dirty               out     1 %0d %0d %0d\n", ones({179'b0, m49}), n49, x49);
  if (|m49) n_tog = n_tog + 1;
  if (x49 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vpu_rtu_ex1_vec_dirty              out     1 %0d %0d %0d\n", ones({179'b0, m50}), n50, x50);
  if (|m50) n_tog = n_tog + 1;
  if (x50 != 0) n_xseen = n_xseen + 1;

  $fwrite(FH, "\nSUMMARY: %0d/48 functional ports toggled (3 infrastructure ports excluded)\n", n_tog);
  $fwrite(FH, "X-SEEN : %0d functional ports held an X/Z bit at some point\n", n_xseen);
  $fwrite(FH, "NEVER TOGGLED:");
  if (~|m0) $fwrite(FH, " cp0_idu_icg_en");
  if (~|m1) $fwrite(FH, " cp0_yy_clk_en");
  if (~|m4) $fwrite(FH, " idu_vidu_ex1_fp_dp_sel");
  if (~|m5) $fwrite(FH, " idu_vidu_ex1_fp_gateclk_sel");
  if (~|m6) $fwrite(FH, " idu_vidu_ex1_fp_sel");
  if (~|m7) $fwrite(FH, " idu_vidu_ex1_inst_data");
  if (~|m8) $fwrite(FH, " idu_vidu_ex1_vec_dp_sel");
  if (~|m9) $fwrite(FH, " idu_vidu_ex1_vec_gateclk_sel");
  if (~|m10) $fwrite(FH, " idu_vidu_ex1_vec_sel");
  if (~|m11) $fwrite(FH, " ifu_vidu_warm_up");
  if (~|m13) $fwrite(FH, " rtu_vidu_flush_wbt");
  if (~|m14) $fwrite(FH, " rtu_yy_xx_async_flush");
  if (~|m15) $fwrite(FH, " vpu_vidu_fp_fwd_data");
  if (~|m16) $fwrite(FH, " vpu_vidu_fp_fwd_reg");
  if (~|m17) $fwrite(FH, " vpu_vidu_fp_fwd_vld");
  if (~|m18) $fwrite(FH, " vpu_vidu_fp_wb_data");
  if (~|m19) $fwrite(FH, " vpu_vidu_fp_wb_reg");
  if (~|m20) $fwrite(FH, " vpu_vidu_fp_wb_vld");
  if (~|m21) $fwrite(FH, " vpu_vidu_vex1_fp_stall");
  if (~|m22) $fwrite(FH, " vpu_vidu_wbt_fp_wb0_reg");
  if (~|m23) $fwrite(FH, " vpu_vidu_wbt_fp_wb0_vld");
  if (~|m24) $fwrite(FH, " vpu_vidu_wbt_fp_wb1_reg");
  if (~|m25) $fwrite(FH, " vpu_vidu_wbt_fp_wb1_vld");
  if (~|m26) $fwrite(FH, " vidu_cp0_vid_fof_vld");
  if (~|m27) $fwrite(FH, " vidu_dtu_debug_info");
  if (~|m28) $fwrite(FH, " vidu_idu_fp_full");
  if (~|m29) $fwrite(FH, " vidu_idu_vec_full");
  if (~|m30) $fwrite(FH, " vidu_rtu_no_op");
  if (~|m31) $fwrite(FH, " vidu_vpu_vid_fp_inst_dp_vld");
  if (~|m32) $fwrite(FH, " vidu_vpu_vid_fp_inst_dst_reg");
  if (~|m33) $fwrite(FH, " vidu_vpu_vid_fp_inst_dst_vld");
  if (~|m34) $fwrite(FH, " vidu_vpu_vid_fp_inst_dste_vld");
  if (~|m35) $fwrite(FH, " vidu_vpu_vid_fp_inst_dstf_reg");
  if (~|m36) $fwrite(FH, " vidu_vpu_vid_fp_inst_dstf_vld");
  if (~|m37) $fwrite(FH, " vidu_vpu_vid_fp_inst_eu");
  if (~|m38) $fwrite(FH, " vidu_vpu_vid_fp_inst_func");
  if (~|m39) $fwrite(FH, " vidu_vpu_vid_fp_inst_gateclk_vld");
  if (~|m40) $fwrite(FH, " vidu_vpu_vid_fp_inst_src1_data");
  if (~|m41) $fwrite(FH, " vidu_vpu_vid_fp_inst_srcf0_data");
  if (~|m42) $fwrite(FH, " vidu_vpu_vid_fp_inst_srcf1_data");
  if (~|m43) $fwrite(FH, " vidu_vpu_vid_fp_inst_srcf2_data");
  if (~|m44) $fwrite(FH, " vidu_vpu_vid_fp_inst_srcf2_rdy");
  if (~|m45) $fwrite(FH, " vidu_vpu_vid_fp_inst_srcf2_vld");
  if (~|m46) $fwrite(FH, " vidu_vpu_vid_fp_inst_vld");
  if (~|m47) $fwrite(FH, " vpu_rtu_ex1_cmplt");
  if (~|m48) $fwrite(FH, " vpu_rtu_ex1_cmplt_dp");
  if (~|m49) $fwrite(FH, " vpu_rtu_ex1_fp_dirty");
  if (~|m50) $fwrite(FH, " vpu_rtu_ex1_vec_dirty");
  $fwrite(FH, "\n");
  $fclose(FH);
  $display("[vidu_toggle_mon] %0d/48 functional VIDU ports toggled; report in vidu_toggle.report", n_tog);
end

endmodule

`undef VIDU_MON_I
`endif // VIDU_TOGGLE_MON
