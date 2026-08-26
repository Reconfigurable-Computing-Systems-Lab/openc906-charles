// -------------------------------------------------------------------
// AUTO-GENERATED -- do not edit by hand.
//   generator : smart_run/cli_tools/gen_toggle_mon.py
//   source    : ../C906_RTL_FACTORY/gen_rtl/idu/rtl/aq_idu_top.v
//   ports     : 130 total (127 functional, 3 infrastructure)
//
// Per-port toggle monitor. Reports, at $finish, how many bits of each
// port of the probed instance ever changed value. Used to prove that a
// test actually stimulated the module.
// -------------------------------------------------------------------

`ifdef IDU_TOGGLE_MON

`define IDU_MON_I tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top.x_aq_top_0.x_aq_core.x_aq_idu_top

module idu_toggle_mon (
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
wire c0 = `IDU_MON_I.cp0_idu_cskyee;
reg  p0;
reg  m0;
integer n0;
integer x0;
wire c1 = `IDU_MON_I.cp0_idu_dis_fence_in_dbg;
reg  p1;
reg  m1;
integer n1;
integer x1;
wire [2:0] c2 = `IDU_MON_I.cp0_idu_frm;
reg  [2:0] p2;
reg  [2:0] m2;
integer n2;
integer x2;
wire [1:0] c3 = `IDU_MON_I.cp0_idu_fs;
reg  [1:0] p3;
reg  [1:0] m3;
integer n3;
integer x3;
wire c4 = `IDU_MON_I.cp0_idu_icg_en;
reg  p4;
reg  m4;
integer n4;
integer x4;
wire c5 = `IDU_MON_I.cp0_idu_issue_stall;
reg  p5;
reg  m5;
integer n5;
integer x5;
wire c6 = `IDU_MON_I.cp0_idu_ucme;
reg  p6;
reg  m6;
integer n6;
integer x6;
wire c7 = `IDU_MON_I.cp0_idu_vill;
reg  p7;
reg  m7;
integer n7;
integer x7;
wire c8 = `IDU_MON_I.cp0_idu_vl_zero;
reg  p8;
reg  m8;
integer n8;
integer x8;
wire [1:0] c9 = `IDU_MON_I.cp0_idu_vlmul;
reg  [1:0] p9;
reg  [1:0] m9;
integer n9;
integer x9;
wire [1:0] c10 = `IDU_MON_I.cp0_idu_vs;
reg  [1:0] p10;
reg  [1:0] m10;
integer n10;
integer x10;
wire c11 = `IDU_MON_I.cp0_idu_vsetvl_dis_stall;
reg  p11;
reg  m11;
integer n11;
integer x11;
wire [1:0] c12 = `IDU_MON_I.cp0_idu_vsew;
reg  [1:0] p12;
reg  [1:0] m12;
integer n12;
integer x12;
wire [6:0] c13 = `IDU_MON_I.cp0_idu_vstart;
reg  [6:0] p13;
reg  [6:0] m13;
integer n13;
integer x13;
wire c14 = `IDU_MON_I.cp0_yy_clk_en;
reg  p14;
reg  m14;
integer n14;
integer x14;
wire [1:0] c15 = `IDU_MON_I.cp0_yy_priv_mode;
reg  [1:0] p15;
reg  [1:0] m15;
integer n15;
integer x15;
wire c16 = `IDU_MON_I.cpurst_b;
reg  p16;
reg  m16;
integer n16;
integer x16;
wire c17 = `IDU_MON_I.forever_cpuclk;
reg  p17;
reg  m17;
integer n17;
integer x17;
wire c18 = `IDU_MON_I.hpcp_idu_cnt_en;
reg  p18;
reg  m18;
integer n18;
integer x18;
wire [1:0] c19 = `IDU_MON_I.ifu_idu_id_bht_pred;
reg  [1:0] p19;
reg  [1:0] m19;
integer n19;
integer x19;
wire c20 = `IDU_MON_I.ifu_idu_id_expt_acc_error;
reg  p20;
reg  m20;
integer n20;
integer x20;
wire c21 = `IDU_MON_I.ifu_idu_id_expt_high;
reg  p21;
reg  m21;
integer n21;
integer x21;
wire c22 = `IDU_MON_I.ifu_idu_id_expt_page_fault;
reg  p22;
reg  m22;
integer n22;
integer x22;
wire [21:0] c23 = `IDU_MON_I.ifu_idu_id_halt_info;
reg  [21:0] p23;
reg  [21:0] m23;
integer n23;
integer x23;
wire [31:0] c24 = `IDU_MON_I.ifu_idu_id_inst;
reg  [31:0] p24;
reg  [31:0] m24;
integer n24;
integer x24;
wire c25 = `IDU_MON_I.ifu_idu_id_inst_vld;
reg  p25;
reg  m25;
integer n25;
integer x25;
wire c26 = `IDU_MON_I.ifu_idu_warm_up;
reg  p26;
reg  m26;
integer n26;
integer x26;
wire c27 = `IDU_MON_I.iu_idu_bju_full;
reg  p27;
reg  m27;
integer n27;
integer x27;
wire c28 = `IDU_MON_I.iu_idu_bju_global_full;
reg  p28;
reg  m28;
integer n28;
integer x28;
wire c29 = `IDU_MON_I.iu_idu_div_full;
reg  p29;
reg  m29;
integer n29;
integer x29;
wire c30 = `IDU_MON_I.iu_idu_mult_full;
reg  p30;
reg  m30;
integer n30;
integer x30;
wire c31 = `IDU_MON_I.iu_idu_mult_issue_stall;
reg  p31;
reg  m31;
integer n31;
integer x31;
wire c32 = `IDU_MON_I.iu_yy_xx_cancel;
reg  p32;
reg  m32;
integer n32;
integer x32;
wire c33 = `IDU_MON_I.lsu_idu_full;
reg  p33;
reg  m33;
integer n33;
integer x33;
wire c34 = `IDU_MON_I.lsu_idu_global_full;
reg  p34;
reg  m34;
integer n34;
integer x34;
wire c35 = `IDU_MON_I.pad_yy_icg_scan_en;
reg  p35;
reg  m35;
integer n35;
integer x35;
wire c36 = `IDU_MON_I.rtu_idu_commit;
reg  p36;
reg  m36;
integer n36;
integer x36;
wire c37 = `IDU_MON_I.rtu_idu_commit_for_bju;
reg  p37;
reg  m37;
integer n37;
integer x37;
wire c38 = `IDU_MON_I.rtu_idu_flush_fe;
reg  p38;
reg  m38;
integer n38;
integer x38;
wire c39 = `IDU_MON_I.rtu_idu_flush_stall;
reg  p39;
reg  m39;
integer n39;
integer x39;
wire c40 = `IDU_MON_I.rtu_idu_flush_wbt;
reg  p40;
reg  m40;
integer n40;
integer x40;
wire [63:0] c41 = `IDU_MON_I.rtu_idu_fwd0_data;
reg  [63:0] p41;
reg  [63:0] m41;
integer n41;
integer x41;
wire [5:0] c42 = `IDU_MON_I.rtu_idu_fwd0_reg;
reg  [5:0] p42;
reg  [5:0] m42;
integer n42;
integer x42;
wire c43 = `IDU_MON_I.rtu_idu_fwd0_vld;
reg  p43;
reg  m43;
integer n43;
integer x43;
wire [63:0] c44 = `IDU_MON_I.rtu_idu_fwd1_data;
reg  [63:0] p44;
reg  [63:0] m44;
integer n44;
integer x44;
wire [5:0] c45 = `IDU_MON_I.rtu_idu_fwd1_reg;
reg  [5:0] p45;
reg  [5:0] m45;
integer n45;
integer x45;
wire c46 = `IDU_MON_I.rtu_idu_fwd1_vld;
reg  p46;
reg  m46;
integer n46;
integer x46;
wire [63:0] c47 = `IDU_MON_I.rtu_idu_fwd2_data;
reg  [63:0] p47;
reg  [63:0] m47;
integer n47;
integer x47;
wire [5:0] c48 = `IDU_MON_I.rtu_idu_fwd2_reg;
reg  [5:0] p48;
reg  [5:0] m48;
integer n48;
integer x48;
wire c49 = `IDU_MON_I.rtu_idu_fwd2_vld;
reg  p49;
reg  m49;
integer n49;
integer x49;
wire c50 = `IDU_MON_I.rtu_idu_pipeline_empty;
reg  p50;
reg  m50;
integer n50;
integer x50;
wire [63:0] c51 = `IDU_MON_I.rtu_idu_wb0_data;
reg  [63:0] p51;
reg  [63:0] m51;
integer n51;
integer x51;
wire [5:0] c52 = `IDU_MON_I.rtu_idu_wb0_reg;
reg  [5:0] p52;
reg  [5:0] m52;
integer n52;
integer x52;
wire c53 = `IDU_MON_I.rtu_idu_wb0_vld;
reg  p53;
reg  m53;
integer n53;
integer x53;
wire [63:0] c54 = `IDU_MON_I.rtu_idu_wb1_data;
reg  [63:0] p54;
reg  [63:0] m54;
integer n54;
integer x54;
wire [5:0] c55 = `IDU_MON_I.rtu_idu_wb1_reg;
reg  [5:0] p55;
reg  [5:0] m55;
integer n55;
integer x55;
wire c56 = `IDU_MON_I.rtu_idu_wb1_vld;
reg  p56;
reg  m56;
integer n56;
integer x56;
wire c57 = `IDU_MON_I.rtu_yy_xx_dbgon;
reg  p57;
reg  m57;
integer n57;
integer x57;
wire c58 = `IDU_MON_I.vidu_idu_fp_full;
reg  p58;
reg  m58;
integer n58;
integer x58;
wire c59 = `IDU_MON_I.vidu_idu_vec_full;
reg  p59;
reg  m59;
integer n59;
integer x59;
wire c60 = `IDU_MON_I.idu_alu_ex1_gateclk_sel;
reg  p60;
reg  m60;
integer n60;
integer x60;
wire c61 = `IDU_MON_I.idu_bju_ex1_gateclk_sel;
reg  p61;
reg  m61;
integer n61;
integer x61;
wire c62 = `IDU_MON_I.idu_cp0_ex1_dp_sel;
reg  p62;
reg  m62;
integer n62;
integer x62;
wire [5:0] c63 = `IDU_MON_I.idu_cp0_ex1_dst0_reg;
reg  [5:0] p63;
reg  [5:0] m63;
integer n63;
integer x63;
wire c64 = `IDU_MON_I.idu_cp0_ex1_expt_acc_error;
reg  p64;
reg  m64;
integer n64;
integer x64;
wire c65 = `IDU_MON_I.idu_cp0_ex1_expt_high;
reg  p65;
reg  m65;
integer n65;
integer x65;
wire c66 = `IDU_MON_I.idu_cp0_ex1_expt_illegal;
reg  p66;
reg  m66;
integer n66;
integer x66;
wire c67 = `IDU_MON_I.idu_cp0_ex1_expt_page_fault;
reg  p67;
reg  m67;
integer n67;
integer x67;
wire [19:0] c68 = `IDU_MON_I.idu_cp0_ex1_func;
reg  [19:0] p68;
reg  [19:0] m68;
integer n68;
integer x68;
wire c69 = `IDU_MON_I.idu_cp0_ex1_gateclk_sel;
reg  p69;
reg  m69;
integer n69;
integer x69;
wire [21:0] c70 = `IDU_MON_I.idu_cp0_ex1_halt_info;
reg  [21:0] p70;
reg  [21:0] m70;
integer n70;
integer x70;
wire c71 = `IDU_MON_I.idu_cp0_ex1_length;
reg  p71;
reg  m71;
integer n71;
integer x71;
wire [31:0] c72 = `IDU_MON_I.idu_cp0_ex1_opcode;
reg  [31:0] p72;
reg  [31:0] m72;
integer n72;
integer x72;
wire c73 = `IDU_MON_I.idu_cp0_ex1_sel;
reg  p73;
reg  m73;
integer n73;
integer x73;
wire c74 = `IDU_MON_I.idu_cp0_ex1_split;
reg  p74;
reg  m74;
integer n74;
integer x74;
wire [63:0] c75 = `IDU_MON_I.idu_cp0_ex1_src0_data;
reg  [63:0] p75;
reg  [63:0] m75;
integer n75;
integer x75;
wire [63:0] c76 = `IDU_MON_I.idu_cp0_ex1_src1_data;
reg  [63:0] p76;
reg  [63:0] m76;
integer n76;
integer x76;
wire c77 = `IDU_MON_I.idu_div_ex1_gateclk_sel;
reg  p77;
reg  m77;
integer n77;
integer x77;
wire [14:0] c78 = `IDU_MON_I.idu_dtu_debug_info;
reg  [14:0] p78;
reg  [14:0] m78;
integer n78;
integer x78;
wire c79 = `IDU_MON_I.idu_hpcp_backend_stall;
reg  p79;
reg  m79;
integer n79;
integer x79;
wire c80 = `IDU_MON_I.idu_hpcp_frontend_stall;
reg  p80;
reg  m80;
integer n80;
integer x80;
wire [6:0] c81 = `IDU_MON_I.idu_hpcp_inst_type;
reg  [6:0] p81;
reg  [6:0] m81;
integer n81;
integer x81;
wire c82 = `IDU_MON_I.idu_ifu_id_stall;
reg  p82;
reg  m82;
integer n82;
integer x82;
wire c83 = `IDU_MON_I.idu_iu_ex1_alu_dp_sel;
reg  p83;
reg  m83;
integer n83;
integer x83;
wire c84 = `IDU_MON_I.idu_iu_ex1_alu_sel;
reg  p84;
reg  m84;
integer n84;
integer x84;
wire [1:0] c85 = `IDU_MON_I.idu_iu_ex1_bht_pred;
reg  [1:0] p85;
reg  [1:0] m85;
integer n85;
integer x85;
wire c86 = `IDU_MON_I.idu_iu_ex1_bju_br_sel;
reg  p86;
reg  m86;
integer n86;
integer x86;
wire c87 = `IDU_MON_I.idu_iu_ex1_bju_dp_sel;
reg  p87;
reg  m87;
integer n87;
integer x87;
wire c88 = `IDU_MON_I.idu_iu_ex1_bju_sel;
reg  p88;
reg  m88;
integer n88;
integer x88;
wire c89 = `IDU_MON_I.idu_iu_ex1_div_dp_sel;
reg  p89;
reg  m89;
integer n89;
integer x89;
wire c90 = `IDU_MON_I.idu_iu_ex1_div_sel;
reg  p90;
reg  m90;
integer n90;
integer x90;
wire [5:0] c91 = `IDU_MON_I.idu_iu_ex1_dst0_reg;
reg  [5:0] p91;
reg  [5:0] m91;
integer n91;
integer x91;
wire [19:0] c92 = `IDU_MON_I.idu_iu_ex1_func;
reg  [19:0] p92;
reg  [19:0] m92;
integer n92;
integer x92;
wire c93 = `IDU_MON_I.idu_iu_ex1_inst_vld;
reg  p93;
reg  m93;
integer n93;
integer x93;
wire c94 = `IDU_MON_I.idu_iu_ex1_length;
reg  p94;
reg  m94;
integer n94;
integer x94;
wire c95 = `IDU_MON_I.idu_iu_ex1_mult_dp_sel;
reg  p95;
reg  m95;
integer n95;
integer x95;
wire c96 = `IDU_MON_I.idu_iu_ex1_mult_sel;
reg  p96;
reg  m96;
integer n96;
integer x96;
wire c97 = `IDU_MON_I.idu_iu_ex1_pipedown_vld;
reg  p97;
reg  m97;
integer n97;
integer x97;
wire c98 = `IDU_MON_I.idu_iu_ex1_split;
reg  p98;
reg  m98;
integer n98;
integer x98;
wire [63:0] c99 = `IDU_MON_I.idu_iu_ex1_src0_data;
reg  [63:0] p99;
reg  [63:0] m99;
integer n99;
integer x99;
wire c100 = `IDU_MON_I.idu_iu_ex1_src0_ready;
reg  p100;
reg  m100;
integer n100;
integer x100;
wire [5:0] c101 = `IDU_MON_I.idu_iu_ex1_src0_reg;
reg  [5:0] p101;
reg  [5:0] m101;
integer n101;
integer x101;
wire [63:0] c102 = `IDU_MON_I.idu_iu_ex1_src1_data;
reg  [63:0] p102;
reg  [63:0] m102;
integer n102;
integer x102;
wire c103 = `IDU_MON_I.idu_iu_ex1_src1_ready;
reg  p103;
reg  m103;
integer n103;
integer x103;
wire [5:0] c104 = `IDU_MON_I.idu_iu_ex1_src1_reg;
reg  [5:0] p104;
reg  [5:0] m104;
integer n104;
integer x104;
wire [63:0] c105 = `IDU_MON_I.idu_iu_ex1_src2_data;
reg  [63:0] p105;
reg  [63:0] m105;
integer n105;
integer x105;
wire c106 = `IDU_MON_I.idu_lsu_ex1_dp_sel;
reg  p106;
reg  m106;
integer n106;
integer x106;
wire [5:0] c107 = `IDU_MON_I.idu_lsu_ex1_dst0_reg;
reg  [5:0] p107;
reg  [5:0] m107;
integer n107;
integer x107;
wire [5:0] c108 = `IDU_MON_I.idu_lsu_ex1_dst1_reg;
reg  [5:0] p108;
reg  [5:0] m108;
integer n108;
integer x108;
wire [19:0] c109 = `IDU_MON_I.idu_lsu_ex1_func;
reg  [19:0] p109;
reg  [19:0] m109;
integer n109;
integer x109;
wire c110 = `IDU_MON_I.idu_lsu_ex1_gateclk_sel;
reg  p110;
reg  m110;
integer n110;
integer x110;
wire [21:0] c111 = `IDU_MON_I.idu_lsu_ex1_halt_info;
reg  [21:0] p111;
reg  [21:0] m111;
integer n111;
integer x111;
wire c112 = `IDU_MON_I.idu_lsu_ex1_length;
reg  p112;
reg  m112;
integer n112;
integer x112;
wire c113 = `IDU_MON_I.idu_lsu_ex1_sel;
reg  p113;
reg  m113;
integer n113;
integer x113;
wire c114 = `IDU_MON_I.idu_lsu_ex1_split;
reg  p114;
reg  m114;
integer n114;
integer x114;
wire [63:0] c115 = `IDU_MON_I.idu_lsu_ex1_src0_data;
reg  [63:0] p115;
reg  [63:0] m115;
integer n115;
integer x115;
wire [63:0] c116 = `IDU_MON_I.idu_lsu_ex1_src1_data;
reg  [63:0] p116;
reg  [63:0] m116;
integer n116;
integer x116;
wire [63:0] c117 = `IDU_MON_I.idu_lsu_ex1_src2_data;
reg  [63:0] p117;
reg  [63:0] m117;
integer n117;
integer x117;
wire c118 = `IDU_MON_I.idu_lsu_ex1_src2_ready;
reg  p118;
reg  m118;
integer n118;
integer x118;
wire [5:0] c119 = `IDU_MON_I.idu_lsu_ex1_src2_reg;
reg  [5:0] p119;
reg  [5:0] m119;
integer n119;
integer x119;
wire [1:0] c120 = `IDU_MON_I.idu_lsu_ex1_vlmul;
reg  [1:0] p120;
reg  [1:0] m120;
integer n120;
integer x120;
wire [1:0] c121 = `IDU_MON_I.idu_lsu_ex1_vsew;
reg  [1:0] p121;
reg  [1:0] m121;
integer n121;
integer x121;
wire c122 = `IDU_MON_I.idu_mult_ex1_gateclk_sel;
reg  p122;
reg  m122;
integer n122;
integer x122;
wire c123 = `IDU_MON_I.idu_vidu_ex1_fp_dp_sel;
reg  p123;
reg  m123;
integer n123;
integer x123;
wire c124 = `IDU_MON_I.idu_vidu_ex1_fp_gateclk_sel;
reg  p124;
reg  m124;
integer n124;
integer x124;
wire c125 = `IDU_MON_I.idu_vidu_ex1_fp_sel;
reg  p125;
reg  m125;
integer n125;
integer x125;
wire [179:0] c126 = `IDU_MON_I.idu_vidu_ex1_inst_data;
reg  [179:0] p126;
reg  [179:0] m126;
integer n126;
integer x126;
wire c127 = `IDU_MON_I.idu_vidu_ex1_vec_dp_sel;
reg  p127;
reg  m127;
integer n127;
integer x127;
wire c128 = `IDU_MON_I.idu_vidu_ex1_vec_gateclk_sel;
reg  p128;
reg  m128;
integer n128;
integer x128;
wire c129 = `IDU_MON_I.idu_vidu_ex1_vec_sel;
reg  p129;
reg  m129;
integer n129;
integer x129;

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
  p51 = 0; m51 = 0; n51 = 0; x51 = 0;
  p52 = 0; m52 = 0; n52 = 0; x52 = 0;
  p53 = 0; m53 = 0; n53 = 0; x53 = 0;
  p54 = 0; m54 = 0; n54 = 0; x54 = 0;
  p55 = 0; m55 = 0; n55 = 0; x55 = 0;
  p56 = 0; m56 = 0; n56 = 0; x56 = 0;
  p57 = 0; m57 = 0; n57 = 0; x57 = 0;
  p58 = 0; m58 = 0; n58 = 0; x58 = 0;
  p59 = 0; m59 = 0; n59 = 0; x59 = 0;
  p60 = 0; m60 = 0; n60 = 0; x60 = 0;
  p61 = 0; m61 = 0; n61 = 0; x61 = 0;
  p62 = 0; m62 = 0; n62 = 0; x62 = 0;
  p63 = 0; m63 = 0; n63 = 0; x63 = 0;
  p64 = 0; m64 = 0; n64 = 0; x64 = 0;
  p65 = 0; m65 = 0; n65 = 0; x65 = 0;
  p66 = 0; m66 = 0; n66 = 0; x66 = 0;
  p67 = 0; m67 = 0; n67 = 0; x67 = 0;
  p68 = 0; m68 = 0; n68 = 0; x68 = 0;
  p69 = 0; m69 = 0; n69 = 0; x69 = 0;
  p70 = 0; m70 = 0; n70 = 0; x70 = 0;
  p71 = 0; m71 = 0; n71 = 0; x71 = 0;
  p72 = 0; m72 = 0; n72 = 0; x72 = 0;
  p73 = 0; m73 = 0; n73 = 0; x73 = 0;
  p74 = 0; m74 = 0; n74 = 0; x74 = 0;
  p75 = 0; m75 = 0; n75 = 0; x75 = 0;
  p76 = 0; m76 = 0; n76 = 0; x76 = 0;
  p77 = 0; m77 = 0; n77 = 0; x77 = 0;
  p78 = 0; m78 = 0; n78 = 0; x78 = 0;
  p79 = 0; m79 = 0; n79 = 0; x79 = 0;
  p80 = 0; m80 = 0; n80 = 0; x80 = 0;
  p81 = 0; m81 = 0; n81 = 0; x81 = 0;
  p82 = 0; m82 = 0; n82 = 0; x82 = 0;
  p83 = 0; m83 = 0; n83 = 0; x83 = 0;
  p84 = 0; m84 = 0; n84 = 0; x84 = 0;
  p85 = 0; m85 = 0; n85 = 0; x85 = 0;
  p86 = 0; m86 = 0; n86 = 0; x86 = 0;
  p87 = 0; m87 = 0; n87 = 0; x87 = 0;
  p88 = 0; m88 = 0; n88 = 0; x88 = 0;
  p89 = 0; m89 = 0; n89 = 0; x89 = 0;
  p90 = 0; m90 = 0; n90 = 0; x90 = 0;
  p91 = 0; m91 = 0; n91 = 0; x91 = 0;
  p92 = 0; m92 = 0; n92 = 0; x92 = 0;
  p93 = 0; m93 = 0; n93 = 0; x93 = 0;
  p94 = 0; m94 = 0; n94 = 0; x94 = 0;
  p95 = 0; m95 = 0; n95 = 0; x95 = 0;
  p96 = 0; m96 = 0; n96 = 0; x96 = 0;
  p97 = 0; m97 = 0; n97 = 0; x97 = 0;
  p98 = 0; m98 = 0; n98 = 0; x98 = 0;
  p99 = 0; m99 = 0; n99 = 0; x99 = 0;
  p100 = 0; m100 = 0; n100 = 0; x100 = 0;
  p101 = 0; m101 = 0; n101 = 0; x101 = 0;
  p102 = 0; m102 = 0; n102 = 0; x102 = 0;
  p103 = 0; m103 = 0; n103 = 0; x103 = 0;
  p104 = 0; m104 = 0; n104 = 0; x104 = 0;
  p105 = 0; m105 = 0; n105 = 0; x105 = 0;
  p106 = 0; m106 = 0; n106 = 0; x106 = 0;
  p107 = 0; m107 = 0; n107 = 0; x107 = 0;
  p108 = 0; m108 = 0; n108 = 0; x108 = 0;
  p109 = 0; m109 = 0; n109 = 0; x109 = 0;
  p110 = 0; m110 = 0; n110 = 0; x110 = 0;
  p111 = 0; m111 = 0; n111 = 0; x111 = 0;
  p112 = 0; m112 = 0; n112 = 0; x112 = 0;
  p113 = 0; m113 = 0; n113 = 0; x113 = 0;
  p114 = 0; m114 = 0; n114 = 0; x114 = 0;
  p115 = 0; m115 = 0; n115 = 0; x115 = 0;
  p116 = 0; m116 = 0; n116 = 0; x116 = 0;
  p117 = 0; m117 = 0; n117 = 0; x117 = 0;
  p118 = 0; m118 = 0; n118 = 0; x118 = 0;
  p119 = 0; m119 = 0; n119 = 0; x119 = 0;
  p120 = 0; m120 = 0; n120 = 0; x120 = 0;
  p121 = 0; m121 = 0; n121 = 0; x121 = 0;
  p122 = 0; m122 = 0; n122 = 0; x122 = 0;
  p123 = 0; m123 = 0; n123 = 0; x123 = 0;
  p124 = 0; m124 = 0; n124 = 0; x124 = 0;
  p125 = 0; m125 = 0; n125 = 0; x125 = 0;
  p126 = 0; m126 = 0; n126 = 0; x126 = 0;
  p127 = 0; m127 = 0; n127 = 0; x127 = 0;
  p128 = 0; m128 = 0; n128 = 0; x128 = 0;
  p129 = 0; m129 = 0; n129 = 0; x129 = 0;
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
    if ($isunknown(c51)) x51 <= x51 + 1;
    if (armed && !$isunknown(c51) && !$isunknown(p51)) begin
      m51 <= m51 | (c51 ^ p51);
      if (c51 !== p51) n51 <= n51 + 1;
    end
    p51 <= c51;
    if ($isunknown(c52)) x52 <= x52 + 1;
    if (armed && !$isunknown(c52) && !$isunknown(p52)) begin
      m52 <= m52 | (c52 ^ p52);
      if (c52 !== p52) n52 <= n52 + 1;
    end
    p52 <= c52;
    if ($isunknown(c53)) x53 <= x53 + 1;
    if (armed && !$isunknown(c53) && !$isunknown(p53)) begin
      m53 <= m53 | (c53 ^ p53);
      if (c53 !== p53) n53 <= n53 + 1;
    end
    p53 <= c53;
    if ($isunknown(c54)) x54 <= x54 + 1;
    if (armed && !$isunknown(c54) && !$isunknown(p54)) begin
      m54 <= m54 | (c54 ^ p54);
      if (c54 !== p54) n54 <= n54 + 1;
    end
    p54 <= c54;
    if ($isunknown(c55)) x55 <= x55 + 1;
    if (armed && !$isunknown(c55) && !$isunknown(p55)) begin
      m55 <= m55 | (c55 ^ p55);
      if (c55 !== p55) n55 <= n55 + 1;
    end
    p55 <= c55;
    if ($isunknown(c56)) x56 <= x56 + 1;
    if (armed && !$isunknown(c56) && !$isunknown(p56)) begin
      m56 <= m56 | (c56 ^ p56);
      if (c56 !== p56) n56 <= n56 + 1;
    end
    p56 <= c56;
    if ($isunknown(c57)) x57 <= x57 + 1;
    if (armed && !$isunknown(c57) && !$isunknown(p57)) begin
      m57 <= m57 | (c57 ^ p57);
      if (c57 !== p57) n57 <= n57 + 1;
    end
    p57 <= c57;
    if ($isunknown(c58)) x58 <= x58 + 1;
    if (armed && !$isunknown(c58) && !$isunknown(p58)) begin
      m58 <= m58 | (c58 ^ p58);
      if (c58 !== p58) n58 <= n58 + 1;
    end
    p58 <= c58;
    if ($isunknown(c59)) x59 <= x59 + 1;
    if (armed && !$isunknown(c59) && !$isunknown(p59)) begin
      m59 <= m59 | (c59 ^ p59);
      if (c59 !== p59) n59 <= n59 + 1;
    end
    p59 <= c59;
    if ($isunknown(c60)) x60 <= x60 + 1;
    if (armed && !$isunknown(c60) && !$isunknown(p60)) begin
      m60 <= m60 | (c60 ^ p60);
      if (c60 !== p60) n60 <= n60 + 1;
    end
    p60 <= c60;
    if ($isunknown(c61)) x61 <= x61 + 1;
    if (armed && !$isunknown(c61) && !$isunknown(p61)) begin
      m61 <= m61 | (c61 ^ p61);
      if (c61 !== p61) n61 <= n61 + 1;
    end
    p61 <= c61;
    if ($isunknown(c62)) x62 <= x62 + 1;
    if (armed && !$isunknown(c62) && !$isunknown(p62)) begin
      m62 <= m62 | (c62 ^ p62);
      if (c62 !== p62) n62 <= n62 + 1;
    end
    p62 <= c62;
    if ($isunknown(c63)) x63 <= x63 + 1;
    if (armed && !$isunknown(c63) && !$isunknown(p63)) begin
      m63 <= m63 | (c63 ^ p63);
      if (c63 !== p63) n63 <= n63 + 1;
    end
    p63 <= c63;
    if ($isunknown(c64)) x64 <= x64 + 1;
    if (armed && !$isunknown(c64) && !$isunknown(p64)) begin
      m64 <= m64 | (c64 ^ p64);
      if (c64 !== p64) n64 <= n64 + 1;
    end
    p64 <= c64;
    if ($isunknown(c65)) x65 <= x65 + 1;
    if (armed && !$isunknown(c65) && !$isunknown(p65)) begin
      m65 <= m65 | (c65 ^ p65);
      if (c65 !== p65) n65 <= n65 + 1;
    end
    p65 <= c65;
    if ($isunknown(c66)) x66 <= x66 + 1;
    if (armed && !$isunknown(c66) && !$isunknown(p66)) begin
      m66 <= m66 | (c66 ^ p66);
      if (c66 !== p66) n66 <= n66 + 1;
    end
    p66 <= c66;
    if ($isunknown(c67)) x67 <= x67 + 1;
    if (armed && !$isunknown(c67) && !$isunknown(p67)) begin
      m67 <= m67 | (c67 ^ p67);
      if (c67 !== p67) n67 <= n67 + 1;
    end
    p67 <= c67;
    if ($isunknown(c68)) x68 <= x68 + 1;
    if (armed && !$isunknown(c68) && !$isunknown(p68)) begin
      m68 <= m68 | (c68 ^ p68);
      if (c68 !== p68) n68 <= n68 + 1;
    end
    p68 <= c68;
    if ($isunknown(c69)) x69 <= x69 + 1;
    if (armed && !$isunknown(c69) && !$isunknown(p69)) begin
      m69 <= m69 | (c69 ^ p69);
      if (c69 !== p69) n69 <= n69 + 1;
    end
    p69 <= c69;
    if ($isunknown(c70)) x70 <= x70 + 1;
    if (armed && !$isunknown(c70) && !$isunknown(p70)) begin
      m70 <= m70 | (c70 ^ p70);
      if (c70 !== p70) n70 <= n70 + 1;
    end
    p70 <= c70;
    if ($isunknown(c71)) x71 <= x71 + 1;
    if (armed && !$isunknown(c71) && !$isunknown(p71)) begin
      m71 <= m71 | (c71 ^ p71);
      if (c71 !== p71) n71 <= n71 + 1;
    end
    p71 <= c71;
    if ($isunknown(c72)) x72 <= x72 + 1;
    if (armed && !$isunknown(c72) && !$isunknown(p72)) begin
      m72 <= m72 | (c72 ^ p72);
      if (c72 !== p72) n72 <= n72 + 1;
    end
    p72 <= c72;
    if ($isunknown(c73)) x73 <= x73 + 1;
    if (armed && !$isunknown(c73) && !$isunknown(p73)) begin
      m73 <= m73 | (c73 ^ p73);
      if (c73 !== p73) n73 <= n73 + 1;
    end
    p73 <= c73;
    if ($isunknown(c74)) x74 <= x74 + 1;
    if (armed && !$isunknown(c74) && !$isunknown(p74)) begin
      m74 <= m74 | (c74 ^ p74);
      if (c74 !== p74) n74 <= n74 + 1;
    end
    p74 <= c74;
    if ($isunknown(c75)) x75 <= x75 + 1;
    if (armed && !$isunknown(c75) && !$isunknown(p75)) begin
      m75 <= m75 | (c75 ^ p75);
      if (c75 !== p75) n75 <= n75 + 1;
    end
    p75 <= c75;
    if ($isunknown(c76)) x76 <= x76 + 1;
    if (armed && !$isunknown(c76) && !$isunknown(p76)) begin
      m76 <= m76 | (c76 ^ p76);
      if (c76 !== p76) n76 <= n76 + 1;
    end
    p76 <= c76;
    if ($isunknown(c77)) x77 <= x77 + 1;
    if (armed && !$isunknown(c77) && !$isunknown(p77)) begin
      m77 <= m77 | (c77 ^ p77);
      if (c77 !== p77) n77 <= n77 + 1;
    end
    p77 <= c77;
    if ($isunknown(c78)) x78 <= x78 + 1;
    if (armed && !$isunknown(c78) && !$isunknown(p78)) begin
      m78 <= m78 | (c78 ^ p78);
      if (c78 !== p78) n78 <= n78 + 1;
    end
    p78 <= c78;
    if ($isunknown(c79)) x79 <= x79 + 1;
    if (armed && !$isunknown(c79) && !$isunknown(p79)) begin
      m79 <= m79 | (c79 ^ p79);
      if (c79 !== p79) n79 <= n79 + 1;
    end
    p79 <= c79;
    if ($isunknown(c80)) x80 <= x80 + 1;
    if (armed && !$isunknown(c80) && !$isunknown(p80)) begin
      m80 <= m80 | (c80 ^ p80);
      if (c80 !== p80) n80 <= n80 + 1;
    end
    p80 <= c80;
    if ($isunknown(c81)) x81 <= x81 + 1;
    if (armed && !$isunknown(c81) && !$isunknown(p81)) begin
      m81 <= m81 | (c81 ^ p81);
      if (c81 !== p81) n81 <= n81 + 1;
    end
    p81 <= c81;
    if ($isunknown(c82)) x82 <= x82 + 1;
    if (armed && !$isunknown(c82) && !$isunknown(p82)) begin
      m82 <= m82 | (c82 ^ p82);
      if (c82 !== p82) n82 <= n82 + 1;
    end
    p82 <= c82;
    if ($isunknown(c83)) x83 <= x83 + 1;
    if (armed && !$isunknown(c83) && !$isunknown(p83)) begin
      m83 <= m83 | (c83 ^ p83);
      if (c83 !== p83) n83 <= n83 + 1;
    end
    p83 <= c83;
    if ($isunknown(c84)) x84 <= x84 + 1;
    if (armed && !$isunknown(c84) && !$isunknown(p84)) begin
      m84 <= m84 | (c84 ^ p84);
      if (c84 !== p84) n84 <= n84 + 1;
    end
    p84 <= c84;
    if ($isunknown(c85)) x85 <= x85 + 1;
    if (armed && !$isunknown(c85) && !$isunknown(p85)) begin
      m85 <= m85 | (c85 ^ p85);
      if (c85 !== p85) n85 <= n85 + 1;
    end
    p85 <= c85;
    if ($isunknown(c86)) x86 <= x86 + 1;
    if (armed && !$isunknown(c86) && !$isunknown(p86)) begin
      m86 <= m86 | (c86 ^ p86);
      if (c86 !== p86) n86 <= n86 + 1;
    end
    p86 <= c86;
    if ($isunknown(c87)) x87 <= x87 + 1;
    if (armed && !$isunknown(c87) && !$isunknown(p87)) begin
      m87 <= m87 | (c87 ^ p87);
      if (c87 !== p87) n87 <= n87 + 1;
    end
    p87 <= c87;
    if ($isunknown(c88)) x88 <= x88 + 1;
    if (armed && !$isunknown(c88) && !$isunknown(p88)) begin
      m88 <= m88 | (c88 ^ p88);
      if (c88 !== p88) n88 <= n88 + 1;
    end
    p88 <= c88;
    if ($isunknown(c89)) x89 <= x89 + 1;
    if (armed && !$isunknown(c89) && !$isunknown(p89)) begin
      m89 <= m89 | (c89 ^ p89);
      if (c89 !== p89) n89 <= n89 + 1;
    end
    p89 <= c89;
    if ($isunknown(c90)) x90 <= x90 + 1;
    if (armed && !$isunknown(c90) && !$isunknown(p90)) begin
      m90 <= m90 | (c90 ^ p90);
      if (c90 !== p90) n90 <= n90 + 1;
    end
    p90 <= c90;
    if ($isunknown(c91)) x91 <= x91 + 1;
    if (armed && !$isunknown(c91) && !$isunknown(p91)) begin
      m91 <= m91 | (c91 ^ p91);
      if (c91 !== p91) n91 <= n91 + 1;
    end
    p91 <= c91;
    if ($isunknown(c92)) x92 <= x92 + 1;
    if (armed && !$isunknown(c92) && !$isunknown(p92)) begin
      m92 <= m92 | (c92 ^ p92);
      if (c92 !== p92) n92 <= n92 + 1;
    end
    p92 <= c92;
    if ($isunknown(c93)) x93 <= x93 + 1;
    if (armed && !$isunknown(c93) && !$isunknown(p93)) begin
      m93 <= m93 | (c93 ^ p93);
      if (c93 !== p93) n93 <= n93 + 1;
    end
    p93 <= c93;
    if ($isunknown(c94)) x94 <= x94 + 1;
    if (armed && !$isunknown(c94) && !$isunknown(p94)) begin
      m94 <= m94 | (c94 ^ p94);
      if (c94 !== p94) n94 <= n94 + 1;
    end
    p94 <= c94;
    if ($isunknown(c95)) x95 <= x95 + 1;
    if (armed && !$isunknown(c95) && !$isunknown(p95)) begin
      m95 <= m95 | (c95 ^ p95);
      if (c95 !== p95) n95 <= n95 + 1;
    end
    p95 <= c95;
    if ($isunknown(c96)) x96 <= x96 + 1;
    if (armed && !$isunknown(c96) && !$isunknown(p96)) begin
      m96 <= m96 | (c96 ^ p96);
      if (c96 !== p96) n96 <= n96 + 1;
    end
    p96 <= c96;
    if ($isunknown(c97)) x97 <= x97 + 1;
    if (armed && !$isunknown(c97) && !$isunknown(p97)) begin
      m97 <= m97 | (c97 ^ p97);
      if (c97 !== p97) n97 <= n97 + 1;
    end
    p97 <= c97;
    if ($isunknown(c98)) x98 <= x98 + 1;
    if (armed && !$isunknown(c98) && !$isunknown(p98)) begin
      m98 <= m98 | (c98 ^ p98);
      if (c98 !== p98) n98 <= n98 + 1;
    end
    p98 <= c98;
    if ($isunknown(c99)) x99 <= x99 + 1;
    if (armed && !$isunknown(c99) && !$isunknown(p99)) begin
      m99 <= m99 | (c99 ^ p99);
      if (c99 !== p99) n99 <= n99 + 1;
    end
    p99 <= c99;
    if ($isunknown(c100)) x100 <= x100 + 1;
    if (armed && !$isunknown(c100) && !$isunknown(p100)) begin
      m100 <= m100 | (c100 ^ p100);
      if (c100 !== p100) n100 <= n100 + 1;
    end
    p100 <= c100;
    if ($isunknown(c101)) x101 <= x101 + 1;
    if (armed && !$isunknown(c101) && !$isunknown(p101)) begin
      m101 <= m101 | (c101 ^ p101);
      if (c101 !== p101) n101 <= n101 + 1;
    end
    p101 <= c101;
    if ($isunknown(c102)) x102 <= x102 + 1;
    if (armed && !$isunknown(c102) && !$isunknown(p102)) begin
      m102 <= m102 | (c102 ^ p102);
      if (c102 !== p102) n102 <= n102 + 1;
    end
    p102 <= c102;
    if ($isunknown(c103)) x103 <= x103 + 1;
    if (armed && !$isunknown(c103) && !$isunknown(p103)) begin
      m103 <= m103 | (c103 ^ p103);
      if (c103 !== p103) n103 <= n103 + 1;
    end
    p103 <= c103;
    if ($isunknown(c104)) x104 <= x104 + 1;
    if (armed && !$isunknown(c104) && !$isunknown(p104)) begin
      m104 <= m104 | (c104 ^ p104);
      if (c104 !== p104) n104 <= n104 + 1;
    end
    p104 <= c104;
    if ($isunknown(c105)) x105 <= x105 + 1;
    if (armed && !$isunknown(c105) && !$isunknown(p105)) begin
      m105 <= m105 | (c105 ^ p105);
      if (c105 !== p105) n105 <= n105 + 1;
    end
    p105 <= c105;
    if ($isunknown(c106)) x106 <= x106 + 1;
    if (armed && !$isunknown(c106) && !$isunknown(p106)) begin
      m106 <= m106 | (c106 ^ p106);
      if (c106 !== p106) n106 <= n106 + 1;
    end
    p106 <= c106;
    if ($isunknown(c107)) x107 <= x107 + 1;
    if (armed && !$isunknown(c107) && !$isunknown(p107)) begin
      m107 <= m107 | (c107 ^ p107);
      if (c107 !== p107) n107 <= n107 + 1;
    end
    p107 <= c107;
    if ($isunknown(c108)) x108 <= x108 + 1;
    if (armed && !$isunknown(c108) && !$isunknown(p108)) begin
      m108 <= m108 | (c108 ^ p108);
      if (c108 !== p108) n108 <= n108 + 1;
    end
    p108 <= c108;
    if ($isunknown(c109)) x109 <= x109 + 1;
    if (armed && !$isunknown(c109) && !$isunknown(p109)) begin
      m109 <= m109 | (c109 ^ p109);
      if (c109 !== p109) n109 <= n109 + 1;
    end
    p109 <= c109;
    if ($isunknown(c110)) x110 <= x110 + 1;
    if (armed && !$isunknown(c110) && !$isunknown(p110)) begin
      m110 <= m110 | (c110 ^ p110);
      if (c110 !== p110) n110 <= n110 + 1;
    end
    p110 <= c110;
    if ($isunknown(c111)) x111 <= x111 + 1;
    if (armed && !$isunknown(c111) && !$isunknown(p111)) begin
      m111 <= m111 | (c111 ^ p111);
      if (c111 !== p111) n111 <= n111 + 1;
    end
    p111 <= c111;
    if ($isunknown(c112)) x112 <= x112 + 1;
    if (armed && !$isunknown(c112) && !$isunknown(p112)) begin
      m112 <= m112 | (c112 ^ p112);
      if (c112 !== p112) n112 <= n112 + 1;
    end
    p112 <= c112;
    if ($isunknown(c113)) x113 <= x113 + 1;
    if (armed && !$isunknown(c113) && !$isunknown(p113)) begin
      m113 <= m113 | (c113 ^ p113);
      if (c113 !== p113) n113 <= n113 + 1;
    end
    p113 <= c113;
    if ($isunknown(c114)) x114 <= x114 + 1;
    if (armed && !$isunknown(c114) && !$isunknown(p114)) begin
      m114 <= m114 | (c114 ^ p114);
      if (c114 !== p114) n114 <= n114 + 1;
    end
    p114 <= c114;
    if ($isunknown(c115)) x115 <= x115 + 1;
    if (armed && !$isunknown(c115) && !$isunknown(p115)) begin
      m115 <= m115 | (c115 ^ p115);
      if (c115 !== p115) n115 <= n115 + 1;
    end
    p115 <= c115;
    if ($isunknown(c116)) x116 <= x116 + 1;
    if (armed && !$isunknown(c116) && !$isunknown(p116)) begin
      m116 <= m116 | (c116 ^ p116);
      if (c116 !== p116) n116 <= n116 + 1;
    end
    p116 <= c116;
    if ($isunknown(c117)) x117 <= x117 + 1;
    if (armed && !$isunknown(c117) && !$isunknown(p117)) begin
      m117 <= m117 | (c117 ^ p117);
      if (c117 !== p117) n117 <= n117 + 1;
    end
    p117 <= c117;
    if ($isunknown(c118)) x118 <= x118 + 1;
    if (armed && !$isunknown(c118) && !$isunknown(p118)) begin
      m118 <= m118 | (c118 ^ p118);
      if (c118 !== p118) n118 <= n118 + 1;
    end
    p118 <= c118;
    if ($isunknown(c119)) x119 <= x119 + 1;
    if (armed && !$isunknown(c119) && !$isunknown(p119)) begin
      m119 <= m119 | (c119 ^ p119);
      if (c119 !== p119) n119 <= n119 + 1;
    end
    p119 <= c119;
    if ($isunknown(c120)) x120 <= x120 + 1;
    if (armed && !$isunknown(c120) && !$isunknown(p120)) begin
      m120 <= m120 | (c120 ^ p120);
      if (c120 !== p120) n120 <= n120 + 1;
    end
    p120 <= c120;
    if ($isunknown(c121)) x121 <= x121 + 1;
    if (armed && !$isunknown(c121) && !$isunknown(p121)) begin
      m121 <= m121 | (c121 ^ p121);
      if (c121 !== p121) n121 <= n121 + 1;
    end
    p121 <= c121;
    if ($isunknown(c122)) x122 <= x122 + 1;
    if (armed && !$isunknown(c122) && !$isunknown(p122)) begin
      m122 <= m122 | (c122 ^ p122);
      if (c122 !== p122) n122 <= n122 + 1;
    end
    p122 <= c122;
    if ($isunknown(c123)) x123 <= x123 + 1;
    if (armed && !$isunknown(c123) && !$isunknown(p123)) begin
      m123 <= m123 | (c123 ^ p123);
      if (c123 !== p123) n123 <= n123 + 1;
    end
    p123 <= c123;
    if ($isunknown(c124)) x124 <= x124 + 1;
    if (armed && !$isunknown(c124) && !$isunknown(p124)) begin
      m124 <= m124 | (c124 ^ p124);
      if (c124 !== p124) n124 <= n124 + 1;
    end
    p124 <= c124;
    if ($isunknown(c125)) x125 <= x125 + 1;
    if (armed && !$isunknown(c125) && !$isunknown(p125)) begin
      m125 <= m125 | (c125 ^ p125);
      if (c125 !== p125) n125 <= n125 + 1;
    end
    p125 <= c125;
    if ($isunknown(c126)) x126 <= x126 + 1;
    if (armed && !$isunknown(c126) && !$isunknown(p126)) begin
      m126 <= m126 | (c126 ^ p126);
      if (c126 !== p126) n126 <= n126 + 1;
    end
    p126 <= c126;
    if ($isunknown(c127)) x127 <= x127 + 1;
    if (armed && !$isunknown(c127) && !$isunknown(p127)) begin
      m127 <= m127 | (c127 ^ p127);
      if (c127 !== p127) n127 <= n127 + 1;
    end
    p127 <= c127;
    if ($isunknown(c128)) x128 <= x128 + 1;
    if (armed && !$isunknown(c128) && !$isunknown(p128)) begin
      m128 <= m128 | (c128 ^ p128);
      if (c128 !== p128) n128 <= n128 + 1;
    end
    p128 <= c128;
    if ($isunknown(c129)) x129 <= x129 + 1;
    if (armed && !$isunknown(c129) && !$isunknown(p129)) begin
      m129 <= m129 | (c129 ^ p129);
      if (c129 !== p129) n129 <= n129 + 1;
    end
    p129 <= c129;
  end
end

final begin
  FH = $fopen("idu_toggle.report", "w");
  $fwrite(FH, "IDU port toggle report -- instance:\n");
  $fwrite(FH, "  tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top.x_aq_top_0.x_aq_core.x_aq_idu_top\n\n");
  $fwrite(FH, "port                               dir  width  bits_tog  tog_events  x_cycles\n");
  $fwrite(FH, "----------------------------------------------------------------------------\n");
  n_tog = 0;
  n_xseen = 0;
  $fwrite(FH, "cp0_idu_cskyee                     in      1 %0d %0d %0d\n", ones({179'b0, m0}), n0, x0);
  if (|m0) n_tog = n_tog + 1;
  if (x0 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_dis_fence_in_dbg           in      1 %0d %0d %0d\n", ones({179'b0, m1}), n1, x1);
  if (|m1) n_tog = n_tog + 1;
  if (x1 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_frm                        in      3 %0d %0d %0d\n", ones({177'b0, m2}), n2, x2);
  if (|m2) n_tog = n_tog + 1;
  if (x2 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_fs                         in      2 %0d %0d %0d\n", ones({178'b0, m3}), n3, x3);
  if (|m3) n_tog = n_tog + 1;
  if (x3 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_icg_en                     in      1 %0d %0d %0d\n", ones({179'b0, m4}), n4, x4);
  if (|m4) n_tog = n_tog + 1;
  if (x4 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_issue_stall                in      1 %0d %0d %0d\n", ones({179'b0, m5}), n5, x5);
  if (|m5) n_tog = n_tog + 1;
  if (x5 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_ucme                       in      1 %0d %0d %0d\n", ones({179'b0, m6}), n6, x6);
  if (|m6) n_tog = n_tog + 1;
  if (x6 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_vill                       in      1 %0d %0d %0d\n", ones({179'b0, m7}), n7, x7);
  if (|m7) n_tog = n_tog + 1;
  if (x7 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_vl_zero                    in      1 %0d %0d %0d\n", ones({179'b0, m8}), n8, x8);
  if (|m8) n_tog = n_tog + 1;
  if (x8 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_vlmul                      in      2 %0d %0d %0d\n", ones({178'b0, m9}), n9, x9);
  if (|m9) n_tog = n_tog + 1;
  if (x9 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_vs                         in      2 %0d %0d %0d\n", ones({178'b0, m10}), n10, x10);
  if (|m10) n_tog = n_tog + 1;
  if (x10 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_vsetvl_dis_stall           in      1 %0d %0d %0d\n", ones({179'b0, m11}), n11, x11);
  if (|m11) n_tog = n_tog + 1;
  if (x11 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_vsew                       in      2 %0d %0d %0d\n", ones({178'b0, m12}), n12, x12);
  if (|m12) n_tog = n_tog + 1;
  if (x12 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_vstart                     in      7 %0d %0d %0d\n", ones({173'b0, m13}), n13, x13);
  if (|m13) n_tog = n_tog + 1;
  if (x13 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_yy_clk_en                      in      1 %0d %0d %0d\n", ones({179'b0, m14}), n14, x14);
  if (|m14) n_tog = n_tog + 1;
  if (x14 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_yy_priv_mode                   in      2 %0d %0d %0d\n", ones({178'b0, m15}), n15, x15);
  if (|m15) n_tog = n_tog + 1;
  if (x15 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cpurst_b                           in      1 %0d %0d %0d   [infra]\n", ones({179'b0, m16}), n16, x16);
  $fwrite(FH, "forever_cpuclk                     in      1 %0d %0d %0d   [infra]\n", ones({179'b0, m17}), n17, x17);
  $fwrite(FH, "hpcp_idu_cnt_en                    in      1 %0d %0d %0d\n", ones({179'b0, m18}), n18, x18);
  if (|m18) n_tog = n_tog + 1;
  if (x18 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_bht_pred                in      2 %0d %0d %0d\n", ones({178'b0, m19}), n19, x19);
  if (|m19) n_tog = n_tog + 1;
  if (x19 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_expt_acc_error          in      1 %0d %0d %0d\n", ones({179'b0, m20}), n20, x20);
  if (|m20) n_tog = n_tog + 1;
  if (x20 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_expt_high               in      1 %0d %0d %0d\n", ones({179'b0, m21}), n21, x21);
  if (|m21) n_tog = n_tog + 1;
  if (x21 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_expt_page_fault         in      1 %0d %0d %0d\n", ones({179'b0, m22}), n22, x22);
  if (|m22) n_tog = n_tog + 1;
  if (x22 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_halt_info               in     22 %0d %0d %0d\n", ones({158'b0, m23}), n23, x23);
  if (|m23) n_tog = n_tog + 1;
  if (x23 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_inst                    in     32 %0d %0d %0d\n", ones({148'b0, m24}), n24, x24);
  if (|m24) n_tog = n_tog + 1;
  if (x24 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_inst_vld                in      1 %0d %0d %0d\n", ones({179'b0, m25}), n25, x25);
  if (|m25) n_tog = n_tog + 1;
  if (x25 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_warm_up                    in      1 %0d %0d %0d\n", ones({179'b0, m26}), n26, x26);
  if (|m26) n_tog = n_tog + 1;
  if (x26 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_idu_bju_full                    in      1 %0d %0d %0d\n", ones({179'b0, m27}), n27, x27);
  if (|m27) n_tog = n_tog + 1;
  if (x27 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_idu_bju_global_full             in      1 %0d %0d %0d\n", ones({179'b0, m28}), n28, x28);
  if (|m28) n_tog = n_tog + 1;
  if (x28 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_idu_div_full                    in      1 %0d %0d %0d\n", ones({179'b0, m29}), n29, x29);
  if (|m29) n_tog = n_tog + 1;
  if (x29 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_idu_mult_full                   in      1 %0d %0d %0d\n", ones({179'b0, m30}), n30, x30);
  if (|m30) n_tog = n_tog + 1;
  if (x30 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_idu_mult_issue_stall            in      1 %0d %0d %0d\n", ones({179'b0, m31}), n31, x31);
  if (|m31) n_tog = n_tog + 1;
  if (x31 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_yy_xx_cancel                    in      1 %0d %0d %0d\n", ones({179'b0, m32}), n32, x32);
  if (|m32) n_tog = n_tog + 1;
  if (x32 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "lsu_idu_full                       in      1 %0d %0d %0d\n", ones({179'b0, m33}), n33, x33);
  if (|m33) n_tog = n_tog + 1;
  if (x33 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "lsu_idu_global_full                in      1 %0d %0d %0d\n", ones({179'b0, m34}), n34, x34);
  if (|m34) n_tog = n_tog + 1;
  if (x34 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "pad_yy_icg_scan_en                 in      1 %0d %0d %0d   [infra]\n", ones({179'b0, m35}), n35, x35);
  $fwrite(FH, "rtu_idu_commit                     in      1 %0d %0d %0d\n", ones({179'b0, m36}), n36, x36);
  if (|m36) n_tog = n_tog + 1;
  if (x36 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_commit_for_bju             in      1 %0d %0d %0d\n", ones({179'b0, m37}), n37, x37);
  if (|m37) n_tog = n_tog + 1;
  if (x37 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_flush_fe                   in      1 %0d %0d %0d\n", ones({179'b0, m38}), n38, x38);
  if (|m38) n_tog = n_tog + 1;
  if (x38 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_flush_stall                in      1 %0d %0d %0d\n", ones({179'b0, m39}), n39, x39);
  if (|m39) n_tog = n_tog + 1;
  if (x39 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_flush_wbt                  in      1 %0d %0d %0d\n", ones({179'b0, m40}), n40, x40);
  if (|m40) n_tog = n_tog + 1;
  if (x40 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_fwd0_data                  in     64 %0d %0d %0d\n", ones({116'b0, m41}), n41, x41);
  if (|m41) n_tog = n_tog + 1;
  if (x41 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_fwd0_reg                   in      6 %0d %0d %0d\n", ones({174'b0, m42}), n42, x42);
  if (|m42) n_tog = n_tog + 1;
  if (x42 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_fwd0_vld                   in      1 %0d %0d %0d\n", ones({179'b0, m43}), n43, x43);
  if (|m43) n_tog = n_tog + 1;
  if (x43 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_fwd1_data                  in     64 %0d %0d %0d\n", ones({116'b0, m44}), n44, x44);
  if (|m44) n_tog = n_tog + 1;
  if (x44 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_fwd1_reg                   in      6 %0d %0d %0d\n", ones({174'b0, m45}), n45, x45);
  if (|m45) n_tog = n_tog + 1;
  if (x45 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_fwd1_vld                   in      1 %0d %0d %0d\n", ones({179'b0, m46}), n46, x46);
  if (|m46) n_tog = n_tog + 1;
  if (x46 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_fwd2_data                  in     64 %0d %0d %0d\n", ones({116'b0, m47}), n47, x47);
  if (|m47) n_tog = n_tog + 1;
  if (x47 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_fwd2_reg                   in      6 %0d %0d %0d\n", ones({174'b0, m48}), n48, x48);
  if (|m48) n_tog = n_tog + 1;
  if (x48 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_fwd2_vld                   in      1 %0d %0d %0d\n", ones({179'b0, m49}), n49, x49);
  if (|m49) n_tog = n_tog + 1;
  if (x49 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_pipeline_empty             in      1 %0d %0d %0d\n", ones({179'b0, m50}), n50, x50);
  if (|m50) n_tog = n_tog + 1;
  if (x50 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_wb0_data                   in     64 %0d %0d %0d\n", ones({116'b0, m51}), n51, x51);
  if (|m51) n_tog = n_tog + 1;
  if (x51 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_wb0_reg                    in      6 %0d %0d %0d\n", ones({174'b0, m52}), n52, x52);
  if (|m52) n_tog = n_tog + 1;
  if (x52 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_wb0_vld                    in      1 %0d %0d %0d\n", ones({179'b0, m53}), n53, x53);
  if (|m53) n_tog = n_tog + 1;
  if (x53 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_wb1_data                   in     64 %0d %0d %0d\n", ones({116'b0, m54}), n54, x54);
  if (|m54) n_tog = n_tog + 1;
  if (x54 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_wb1_reg                    in      6 %0d %0d %0d\n", ones({174'b0, m55}), n55, x55);
  if (|m55) n_tog = n_tog + 1;
  if (x55 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_idu_wb1_vld                    in      1 %0d %0d %0d\n", ones({179'b0, m56}), n56, x56);
  if (|m56) n_tog = n_tog + 1;
  if (x56 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_yy_xx_dbgon                    in      1 %0d %0d %0d\n", ones({179'b0, m57}), n57, x57);
  if (|m57) n_tog = n_tog + 1;
  if (x57 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_idu_fp_full                   in      1 %0d %0d %0d\n", ones({179'b0, m58}), n58, x58);
  if (|m58) n_tog = n_tog + 1;
  if (x58 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_idu_vec_full                  in      1 %0d %0d %0d\n", ones({179'b0, m59}), n59, x59);
  if (|m59) n_tog = n_tog + 1;
  if (x59 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_alu_ex1_gateclk_sel            out     1 %0d %0d %0d\n", ones({179'b0, m60}), n60, x60);
  if (|m60) n_tog = n_tog + 1;
  if (x60 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_bju_ex1_gateclk_sel            out     1 %0d %0d %0d\n", ones({179'b0, m61}), n61, x61);
  if (|m61) n_tog = n_tog + 1;
  if (x61 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_dp_sel                 out     1 %0d %0d %0d\n", ones({179'b0, m62}), n62, x62);
  if (|m62) n_tog = n_tog + 1;
  if (x62 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_dst0_reg               out     6 %0d %0d %0d\n", ones({174'b0, m63}), n63, x63);
  if (|m63) n_tog = n_tog + 1;
  if (x63 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_expt_acc_error         out     1 %0d %0d %0d\n", ones({179'b0, m64}), n64, x64);
  if (|m64) n_tog = n_tog + 1;
  if (x64 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_expt_high              out     1 %0d %0d %0d\n", ones({179'b0, m65}), n65, x65);
  if (|m65) n_tog = n_tog + 1;
  if (x65 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_expt_illegal           out     1 %0d %0d %0d\n", ones({179'b0, m66}), n66, x66);
  if (|m66) n_tog = n_tog + 1;
  if (x66 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_expt_page_fault        out     1 %0d %0d %0d\n", ones({179'b0, m67}), n67, x67);
  if (|m67) n_tog = n_tog + 1;
  if (x67 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_func                   out    20 %0d %0d %0d\n", ones({160'b0, m68}), n68, x68);
  if (|m68) n_tog = n_tog + 1;
  if (x68 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_gateclk_sel            out     1 %0d %0d %0d\n", ones({179'b0, m69}), n69, x69);
  if (|m69) n_tog = n_tog + 1;
  if (x69 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_halt_info              out    22 %0d %0d %0d\n", ones({158'b0, m70}), n70, x70);
  if (|m70) n_tog = n_tog + 1;
  if (x70 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_length                 out     1 %0d %0d %0d\n", ones({179'b0, m71}), n71, x71);
  if (|m71) n_tog = n_tog + 1;
  if (x71 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_opcode                 out    32 %0d %0d %0d\n", ones({148'b0, m72}), n72, x72);
  if (|m72) n_tog = n_tog + 1;
  if (x72 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_sel                    out     1 %0d %0d %0d\n", ones({179'b0, m73}), n73, x73);
  if (|m73) n_tog = n_tog + 1;
  if (x73 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_split                  out     1 %0d %0d %0d\n", ones({179'b0, m74}), n74, x74);
  if (|m74) n_tog = n_tog + 1;
  if (x74 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_src0_data              out    64 %0d %0d %0d\n", ones({116'b0, m75}), n75, x75);
  if (|m75) n_tog = n_tog + 1;
  if (x75 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_src1_data              out    64 %0d %0d %0d\n", ones({116'b0, m76}), n76, x76);
  if (|m76) n_tog = n_tog + 1;
  if (x76 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_div_ex1_gateclk_sel            out     1 %0d %0d %0d\n", ones({179'b0, m77}), n77, x77);
  if (|m77) n_tog = n_tog + 1;
  if (x77 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_dtu_debug_info                 out    15 %0d %0d %0d\n", ones({165'b0, m78}), n78, x78);
  if (|m78) n_tog = n_tog + 1;
  if (x78 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_hpcp_backend_stall             out     1 %0d %0d %0d\n", ones({179'b0, m79}), n79, x79);
  if (|m79) n_tog = n_tog + 1;
  if (x79 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_hpcp_frontend_stall            out     1 %0d %0d %0d\n", ones({179'b0, m80}), n80, x80);
  if (|m80) n_tog = n_tog + 1;
  if (x80 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_hpcp_inst_type                 out     7 %0d %0d %0d\n", ones({173'b0, m81}), n81, x81);
  if (|m81) n_tog = n_tog + 1;
  if (x81 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_ifu_id_stall                   out     1 %0d %0d %0d\n", ones({179'b0, m82}), n82, x82);
  if (|m82) n_tog = n_tog + 1;
  if (x82 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_alu_dp_sel              out     1 %0d %0d %0d\n", ones({179'b0, m83}), n83, x83);
  if (|m83) n_tog = n_tog + 1;
  if (x83 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_alu_sel                 out     1 %0d %0d %0d\n", ones({179'b0, m84}), n84, x84);
  if (|m84) n_tog = n_tog + 1;
  if (x84 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_bht_pred                out     2 %0d %0d %0d\n", ones({178'b0, m85}), n85, x85);
  if (|m85) n_tog = n_tog + 1;
  if (x85 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_bju_br_sel              out     1 %0d %0d %0d\n", ones({179'b0, m86}), n86, x86);
  if (|m86) n_tog = n_tog + 1;
  if (x86 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_bju_dp_sel              out     1 %0d %0d %0d\n", ones({179'b0, m87}), n87, x87);
  if (|m87) n_tog = n_tog + 1;
  if (x87 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_bju_sel                 out     1 %0d %0d %0d\n", ones({179'b0, m88}), n88, x88);
  if (|m88) n_tog = n_tog + 1;
  if (x88 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_div_dp_sel              out     1 %0d %0d %0d\n", ones({179'b0, m89}), n89, x89);
  if (|m89) n_tog = n_tog + 1;
  if (x89 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_div_sel                 out     1 %0d %0d %0d\n", ones({179'b0, m90}), n90, x90);
  if (|m90) n_tog = n_tog + 1;
  if (x90 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_dst0_reg                out     6 %0d %0d %0d\n", ones({174'b0, m91}), n91, x91);
  if (|m91) n_tog = n_tog + 1;
  if (x91 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_func                    out    20 %0d %0d %0d\n", ones({160'b0, m92}), n92, x92);
  if (|m92) n_tog = n_tog + 1;
  if (x92 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_inst_vld                out     1 %0d %0d %0d\n", ones({179'b0, m93}), n93, x93);
  if (|m93) n_tog = n_tog + 1;
  if (x93 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_length                  out     1 %0d %0d %0d\n", ones({179'b0, m94}), n94, x94);
  if (|m94) n_tog = n_tog + 1;
  if (x94 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_mult_dp_sel             out     1 %0d %0d %0d\n", ones({179'b0, m95}), n95, x95);
  if (|m95) n_tog = n_tog + 1;
  if (x95 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_mult_sel                out     1 %0d %0d %0d\n", ones({179'b0, m96}), n96, x96);
  if (|m96) n_tog = n_tog + 1;
  if (x96 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_pipedown_vld            out     1 %0d %0d %0d\n", ones({179'b0, m97}), n97, x97);
  if (|m97) n_tog = n_tog + 1;
  if (x97 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_split                   out     1 %0d %0d %0d\n", ones({179'b0, m98}), n98, x98);
  if (|m98) n_tog = n_tog + 1;
  if (x98 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_src0_data               out    64 %0d %0d %0d\n", ones({116'b0, m99}), n99, x99);
  if (|m99) n_tog = n_tog + 1;
  if (x99 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_src0_ready              out     1 %0d %0d %0d\n", ones({179'b0, m100}), n100, x100);
  if (|m100) n_tog = n_tog + 1;
  if (x100 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_src0_reg                out     6 %0d %0d %0d\n", ones({174'b0, m101}), n101, x101);
  if (|m101) n_tog = n_tog + 1;
  if (x101 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_src1_data               out    64 %0d %0d %0d\n", ones({116'b0, m102}), n102, x102);
  if (|m102) n_tog = n_tog + 1;
  if (x102 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_src1_ready              out     1 %0d %0d %0d\n", ones({179'b0, m103}), n103, x103);
  if (|m103) n_tog = n_tog + 1;
  if (x103 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_src1_reg                out     6 %0d %0d %0d\n", ones({174'b0, m104}), n104, x104);
  if (|m104) n_tog = n_tog + 1;
  if (x104 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_iu_ex1_src2_data               out    64 %0d %0d %0d\n", ones({116'b0, m105}), n105, x105);
  if (|m105) n_tog = n_tog + 1;
  if (x105 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_dp_sel                 out     1 %0d %0d %0d\n", ones({179'b0, m106}), n106, x106);
  if (|m106) n_tog = n_tog + 1;
  if (x106 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_dst0_reg               out     6 %0d %0d %0d\n", ones({174'b0, m107}), n107, x107);
  if (|m107) n_tog = n_tog + 1;
  if (x107 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_dst1_reg               out     6 %0d %0d %0d\n", ones({174'b0, m108}), n108, x108);
  if (|m108) n_tog = n_tog + 1;
  if (x108 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_func                   out    20 %0d %0d %0d\n", ones({160'b0, m109}), n109, x109);
  if (|m109) n_tog = n_tog + 1;
  if (x109 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_gateclk_sel            out     1 %0d %0d %0d\n", ones({179'b0, m110}), n110, x110);
  if (|m110) n_tog = n_tog + 1;
  if (x110 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_halt_info              out    22 %0d %0d %0d\n", ones({158'b0, m111}), n111, x111);
  if (|m111) n_tog = n_tog + 1;
  if (x111 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_length                 out     1 %0d %0d %0d\n", ones({179'b0, m112}), n112, x112);
  if (|m112) n_tog = n_tog + 1;
  if (x112 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_sel                    out     1 %0d %0d %0d\n", ones({179'b0, m113}), n113, x113);
  if (|m113) n_tog = n_tog + 1;
  if (x113 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_split                  out     1 %0d %0d %0d\n", ones({179'b0, m114}), n114, x114);
  if (|m114) n_tog = n_tog + 1;
  if (x114 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_src0_data              out    64 %0d %0d %0d\n", ones({116'b0, m115}), n115, x115);
  if (|m115) n_tog = n_tog + 1;
  if (x115 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_src1_data              out    64 %0d %0d %0d\n", ones({116'b0, m116}), n116, x116);
  if (|m116) n_tog = n_tog + 1;
  if (x116 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_src2_data              out    64 %0d %0d %0d\n", ones({116'b0, m117}), n117, x117);
  if (|m117) n_tog = n_tog + 1;
  if (x117 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_src2_ready             out     1 %0d %0d %0d\n", ones({179'b0, m118}), n118, x118);
  if (|m118) n_tog = n_tog + 1;
  if (x118 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_src2_reg               out     6 %0d %0d %0d\n", ones({174'b0, m119}), n119, x119);
  if (|m119) n_tog = n_tog + 1;
  if (x119 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_vlmul                  out     2 %0d %0d %0d\n", ones({178'b0, m120}), n120, x120);
  if (|m120) n_tog = n_tog + 1;
  if (x120 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_lsu_ex1_vsew                   out     2 %0d %0d %0d\n", ones({178'b0, m121}), n121, x121);
  if (|m121) n_tog = n_tog + 1;
  if (x121 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_mult_ex1_gateclk_sel           out     1 %0d %0d %0d\n", ones({179'b0, m122}), n122, x122);
  if (|m122) n_tog = n_tog + 1;
  if (x122 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_fp_dp_sel             out     1 %0d %0d %0d\n", ones({179'b0, m123}), n123, x123);
  if (|m123) n_tog = n_tog + 1;
  if (x123 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_fp_gateclk_sel        out     1 %0d %0d %0d\n", ones({179'b0, m124}), n124, x124);
  if (|m124) n_tog = n_tog + 1;
  if (x124 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_fp_sel                out     1 %0d %0d %0d\n", ones({179'b0, m125}), n125, x125);
  if (|m125) n_tog = n_tog + 1;
  if (x125 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_inst_data             out   180 %0d %0d %0d\n", ones({m126}), n126, x126);
  if (|m126) n_tog = n_tog + 1;
  if (x126 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_vec_dp_sel            out     1 %0d %0d %0d\n", ones({179'b0, m127}), n127, x127);
  if (|m127) n_tog = n_tog + 1;
  if (x127 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_vec_gateclk_sel       out     1 %0d %0d %0d\n", ones({179'b0, m128}), n128, x128);
  if (|m128) n_tog = n_tog + 1;
  if (x128 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_vidu_ex1_vec_sel               out     1 %0d %0d %0d\n", ones({179'b0, m129}), n129, x129);
  if (|m129) n_tog = n_tog + 1;
  if (x129 != 0) n_xseen = n_xseen + 1;

  $fwrite(FH, "\nSUMMARY: %0d/127 functional ports toggled (3 infrastructure ports excluded)\n", n_tog);
  $fwrite(FH, "X-SEEN : %0d functional ports held an X/Z bit at some point\n", n_xseen);
  $fwrite(FH, "NEVER TOGGLED:");
  if (~|m0) $fwrite(FH, " cp0_idu_cskyee");
  if (~|m1) $fwrite(FH, " cp0_idu_dis_fence_in_dbg");
  if (~|m2) $fwrite(FH, " cp0_idu_frm");
  if (~|m3) $fwrite(FH, " cp0_idu_fs");
  if (~|m4) $fwrite(FH, " cp0_idu_icg_en");
  if (~|m5) $fwrite(FH, " cp0_idu_issue_stall");
  if (~|m6) $fwrite(FH, " cp0_idu_ucme");
  if (~|m7) $fwrite(FH, " cp0_idu_vill");
  if (~|m8) $fwrite(FH, " cp0_idu_vl_zero");
  if (~|m9) $fwrite(FH, " cp0_idu_vlmul");
  if (~|m10) $fwrite(FH, " cp0_idu_vs");
  if (~|m11) $fwrite(FH, " cp0_idu_vsetvl_dis_stall");
  if (~|m12) $fwrite(FH, " cp0_idu_vsew");
  if (~|m13) $fwrite(FH, " cp0_idu_vstart");
  if (~|m14) $fwrite(FH, " cp0_yy_clk_en");
  if (~|m15) $fwrite(FH, " cp0_yy_priv_mode");
  if (~|m18) $fwrite(FH, " hpcp_idu_cnt_en");
  if (~|m19) $fwrite(FH, " ifu_idu_id_bht_pred");
  if (~|m20) $fwrite(FH, " ifu_idu_id_expt_acc_error");
  if (~|m21) $fwrite(FH, " ifu_idu_id_expt_high");
  if (~|m22) $fwrite(FH, " ifu_idu_id_expt_page_fault");
  if (~|m23) $fwrite(FH, " ifu_idu_id_halt_info");
  if (~|m24) $fwrite(FH, " ifu_idu_id_inst");
  if (~|m25) $fwrite(FH, " ifu_idu_id_inst_vld");
  if (~|m26) $fwrite(FH, " ifu_idu_warm_up");
  if (~|m27) $fwrite(FH, " iu_idu_bju_full");
  if (~|m28) $fwrite(FH, " iu_idu_bju_global_full");
  if (~|m29) $fwrite(FH, " iu_idu_div_full");
  if (~|m30) $fwrite(FH, " iu_idu_mult_full");
  if (~|m31) $fwrite(FH, " iu_idu_mult_issue_stall");
  if (~|m32) $fwrite(FH, " iu_yy_xx_cancel");
  if (~|m33) $fwrite(FH, " lsu_idu_full");
  if (~|m34) $fwrite(FH, " lsu_idu_global_full");
  if (~|m36) $fwrite(FH, " rtu_idu_commit");
  if (~|m37) $fwrite(FH, " rtu_idu_commit_for_bju");
  if (~|m38) $fwrite(FH, " rtu_idu_flush_fe");
  if (~|m39) $fwrite(FH, " rtu_idu_flush_stall");
  if (~|m40) $fwrite(FH, " rtu_idu_flush_wbt");
  if (~|m41) $fwrite(FH, " rtu_idu_fwd0_data");
  if (~|m42) $fwrite(FH, " rtu_idu_fwd0_reg");
  if (~|m43) $fwrite(FH, " rtu_idu_fwd0_vld");
  if (~|m44) $fwrite(FH, " rtu_idu_fwd1_data");
  if (~|m45) $fwrite(FH, " rtu_idu_fwd1_reg");
  if (~|m46) $fwrite(FH, " rtu_idu_fwd1_vld");
  if (~|m47) $fwrite(FH, " rtu_idu_fwd2_data");
  if (~|m48) $fwrite(FH, " rtu_idu_fwd2_reg");
  if (~|m49) $fwrite(FH, " rtu_idu_fwd2_vld");
  if (~|m50) $fwrite(FH, " rtu_idu_pipeline_empty");
  if (~|m51) $fwrite(FH, " rtu_idu_wb0_data");
  if (~|m52) $fwrite(FH, " rtu_idu_wb0_reg");
  if (~|m53) $fwrite(FH, " rtu_idu_wb0_vld");
  if (~|m54) $fwrite(FH, " rtu_idu_wb1_data");
  if (~|m55) $fwrite(FH, " rtu_idu_wb1_reg");
  if (~|m56) $fwrite(FH, " rtu_idu_wb1_vld");
  if (~|m57) $fwrite(FH, " rtu_yy_xx_dbgon");
  if (~|m58) $fwrite(FH, " vidu_idu_fp_full");
  if (~|m59) $fwrite(FH, " vidu_idu_vec_full");
  if (~|m60) $fwrite(FH, " idu_alu_ex1_gateclk_sel");
  if (~|m61) $fwrite(FH, " idu_bju_ex1_gateclk_sel");
  if (~|m62) $fwrite(FH, " idu_cp0_ex1_dp_sel");
  if (~|m63) $fwrite(FH, " idu_cp0_ex1_dst0_reg");
  if (~|m64) $fwrite(FH, " idu_cp0_ex1_expt_acc_error");
  if (~|m65) $fwrite(FH, " idu_cp0_ex1_expt_high");
  if (~|m66) $fwrite(FH, " idu_cp0_ex1_expt_illegal");
  if (~|m67) $fwrite(FH, " idu_cp0_ex1_expt_page_fault");
  if (~|m68) $fwrite(FH, " idu_cp0_ex1_func");
  if (~|m69) $fwrite(FH, " idu_cp0_ex1_gateclk_sel");
  if (~|m70) $fwrite(FH, " idu_cp0_ex1_halt_info");
  if (~|m71) $fwrite(FH, " idu_cp0_ex1_length");
  if (~|m72) $fwrite(FH, " idu_cp0_ex1_opcode");
  if (~|m73) $fwrite(FH, " idu_cp0_ex1_sel");
  if (~|m74) $fwrite(FH, " idu_cp0_ex1_split");
  if (~|m75) $fwrite(FH, " idu_cp0_ex1_src0_data");
  if (~|m76) $fwrite(FH, " idu_cp0_ex1_src1_data");
  if (~|m77) $fwrite(FH, " idu_div_ex1_gateclk_sel");
  if (~|m78) $fwrite(FH, " idu_dtu_debug_info");
  if (~|m79) $fwrite(FH, " idu_hpcp_backend_stall");
  if (~|m80) $fwrite(FH, " idu_hpcp_frontend_stall");
  if (~|m81) $fwrite(FH, " idu_hpcp_inst_type");
  if (~|m82) $fwrite(FH, " idu_ifu_id_stall");
  if (~|m83) $fwrite(FH, " idu_iu_ex1_alu_dp_sel");
  if (~|m84) $fwrite(FH, " idu_iu_ex1_alu_sel");
  if (~|m85) $fwrite(FH, " idu_iu_ex1_bht_pred");
  if (~|m86) $fwrite(FH, " idu_iu_ex1_bju_br_sel");
  if (~|m87) $fwrite(FH, " idu_iu_ex1_bju_dp_sel");
  if (~|m88) $fwrite(FH, " idu_iu_ex1_bju_sel");
  if (~|m89) $fwrite(FH, " idu_iu_ex1_div_dp_sel");
  if (~|m90) $fwrite(FH, " idu_iu_ex1_div_sel");
  if (~|m91) $fwrite(FH, " idu_iu_ex1_dst0_reg");
  if (~|m92) $fwrite(FH, " idu_iu_ex1_func");
  if (~|m93) $fwrite(FH, " idu_iu_ex1_inst_vld");
  if (~|m94) $fwrite(FH, " idu_iu_ex1_length");
  if (~|m95) $fwrite(FH, " idu_iu_ex1_mult_dp_sel");
  if (~|m96) $fwrite(FH, " idu_iu_ex1_mult_sel");
  if (~|m97) $fwrite(FH, " idu_iu_ex1_pipedown_vld");
  if (~|m98) $fwrite(FH, " idu_iu_ex1_split");
  if (~|m99) $fwrite(FH, " idu_iu_ex1_src0_data");
  if (~|m100) $fwrite(FH, " idu_iu_ex1_src0_ready");
  if (~|m101) $fwrite(FH, " idu_iu_ex1_src0_reg");
  if (~|m102) $fwrite(FH, " idu_iu_ex1_src1_data");
  if (~|m103) $fwrite(FH, " idu_iu_ex1_src1_ready");
  if (~|m104) $fwrite(FH, " idu_iu_ex1_src1_reg");
  if (~|m105) $fwrite(FH, " idu_iu_ex1_src2_data");
  if (~|m106) $fwrite(FH, " idu_lsu_ex1_dp_sel");
  if (~|m107) $fwrite(FH, " idu_lsu_ex1_dst0_reg");
  if (~|m108) $fwrite(FH, " idu_lsu_ex1_dst1_reg");
  if (~|m109) $fwrite(FH, " idu_lsu_ex1_func");
  if (~|m110) $fwrite(FH, " idu_lsu_ex1_gateclk_sel");
  if (~|m111) $fwrite(FH, " idu_lsu_ex1_halt_info");
  if (~|m112) $fwrite(FH, " idu_lsu_ex1_length");
  if (~|m113) $fwrite(FH, " idu_lsu_ex1_sel");
  if (~|m114) $fwrite(FH, " idu_lsu_ex1_split");
  if (~|m115) $fwrite(FH, " idu_lsu_ex1_src0_data");
  if (~|m116) $fwrite(FH, " idu_lsu_ex1_src1_data");
  if (~|m117) $fwrite(FH, " idu_lsu_ex1_src2_data");
  if (~|m118) $fwrite(FH, " idu_lsu_ex1_src2_ready");
  if (~|m119) $fwrite(FH, " idu_lsu_ex1_src2_reg");
  if (~|m120) $fwrite(FH, " idu_lsu_ex1_vlmul");
  if (~|m121) $fwrite(FH, " idu_lsu_ex1_vsew");
  if (~|m122) $fwrite(FH, " idu_mult_ex1_gateclk_sel");
  if (~|m123) $fwrite(FH, " idu_vidu_ex1_fp_dp_sel");
  if (~|m124) $fwrite(FH, " idu_vidu_ex1_fp_gateclk_sel");
  if (~|m125) $fwrite(FH, " idu_vidu_ex1_fp_sel");
  if (~|m126) $fwrite(FH, " idu_vidu_ex1_inst_data");
  if (~|m127) $fwrite(FH, " idu_vidu_ex1_vec_dp_sel");
  if (~|m128) $fwrite(FH, " idu_vidu_ex1_vec_gateclk_sel");
  if (~|m129) $fwrite(FH, " idu_vidu_ex1_vec_sel");
  $fwrite(FH, "\n");
  $fclose(FH);
  $display("[idu_toggle_mon] %0d/127 functional IDU ports toggled; report in idu_toggle.report", n_tog);
end

endmodule

`undef IDU_MON_I
`endif // IDU_TOGGLE_MON
