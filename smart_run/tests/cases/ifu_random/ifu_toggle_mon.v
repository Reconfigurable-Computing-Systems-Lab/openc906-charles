// -------------------------------------------------------------------
// AUTO-GENERATED -- do not edit by hand.
//   generator : smart_run/cli_tools/gen_toggle_mon.py
//   source    : ../C906_RTL_FACTORY/gen_rtl/ifu/rtl/aq_ifu_top.v
//   ports     : 110 total (107 functional, 3 infrastructure)
//
// Per-port toggle monitor. Reports, at $finish, how many bits of each
// port of the probed instance ever changed value. Used to prove that a
// test actually stimulated the module.
// -------------------------------------------------------------------

`ifdef IFU_TOGGLE_MON

`define IFU_MON_I tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top.x_aq_top_0.x_aq_core.x_aq_ifu_top

module ifu_toggle_mon (
  input clk,
  input rst_b
);

integer FH;
integer n_tog;          // functional ports with at least one bit toggled
integer n_xseen;        // functional ports that ever held an X/Z bit
reg     armed;          // suppress the first post-reset comparison

// popcount over the widest port in the module
function integer ones;
  input [127:0] v;
  integer i;
  begin
    ones = 0;
    for (i = 0; i < 128; i = i + 1)
      if (v[i] === 1'b1) ones = ones + 1;
  end
endfunction

always @(posedge clk or negedge rst_b)
  if (!rst_b) armed <= 1'b0;
  else        armed <= 1'b1;

// ---------------- per-port sample / accumulate ----------------
wire c0 = `IFU_MON_I.biu_ifu_arready;
reg  p0;
reg  m0;
integer n0;
integer x0;
wire [127:0] c1 = `IFU_MON_I.biu_ifu_rdata;
reg  [127:0] p1;
reg  [127:0] m1;
integer n1;
integer x1;
wire c2 = `IFU_MON_I.biu_ifu_rid;
reg  p2;
reg  m2;
integer n2;
integer x2;
wire c3 = `IFU_MON_I.biu_ifu_rlast;
reg  p3;
reg  m3;
integer n3;
integer x3;
wire [1:0] c4 = `IFU_MON_I.biu_ifu_rresp;
reg  [1:0] p4;
reg  [1:0] m4;
integer n4;
integer x4;
wire c5 = `IFU_MON_I.biu_ifu_rvalid;
reg  p5;
reg  m5;
integer n5;
integer x5;
wire c6 = `IFU_MON_I.cp0_ifu_bht_en;
reg  p6;
reg  m6;
integer n6;
integer x6;
wire c7 = `IFU_MON_I.cp0_ifu_bht_inv;
reg  p7;
reg  m7;
integer n7;
integer x7;
wire c8 = `IFU_MON_I.cp0_ifu_btb_clr;
reg  p8;
reg  m8;
integer n8;
integer x8;
wire c9 = `IFU_MON_I.cp0_ifu_btb_en;
reg  p9;
reg  m9;
integer n9;
integer x9;
wire c10 = `IFU_MON_I.cp0_ifu_icache_en;
reg  p10;
reg  m10;
integer n10;
integer x10;
wire [63:0] c11 = `IFU_MON_I.cp0_ifu_icache_inv_addr;
reg  [63:0] p11;
reg  [63:0] m11;
integer n11;
integer x11;
wire c12 = `IFU_MON_I.cp0_ifu_icache_inv_req;
reg  p12;
reg  m12;
integer n12;
integer x12;
wire [1:0] c13 = `IFU_MON_I.cp0_ifu_icache_inv_type;
reg  [1:0] p13;
reg  [1:0] m13;
integer n13;
integer x13;
wire c14 = `IFU_MON_I.cp0_ifu_icache_pref_en;
reg  p14;
reg  m14;
integer n14;
integer x14;
wire [13:0] c15 = `IFU_MON_I.cp0_ifu_icache_read_index;
reg  [13:0] p15;
reg  [13:0] m15;
integer n15;
integer x15;
wire c16 = `IFU_MON_I.cp0_ifu_icache_read_req;
reg  p16;
reg  m16;
integer n16;
integer x16;
wire c17 = `IFU_MON_I.cp0_ifu_icache_read_tag;
reg  p17;
reg  m17;
integer n17;
integer x17;
wire c18 = `IFU_MON_I.cp0_ifu_icache_read_way;
reg  p18;
reg  m18;
integer n18;
integer x18;
wire c19 = `IFU_MON_I.cp0_ifu_icg_en;
reg  p19;
reg  m19;
integer n19;
integer x19;
wire c20 = `IFU_MON_I.cp0_ifu_in_lpmd;
reg  p20;
reg  m20;
integer n20;
integer x20;
wire c21 = `IFU_MON_I.cp0_ifu_iwpe;
reg  p21;
reg  m21;
integer n21;
integer x21;
wire c22 = `IFU_MON_I.cp0_ifu_lpmd_req;
reg  p22;
reg  m22;
integer n22;
integer x22;
wire c23 = `IFU_MON_I.cp0_ifu_ras_en;
reg  p23;
reg  m23;
integer n23;
integer x23;
wire c24 = `IFU_MON_I.cp0_ifu_rst_inv_done;
reg  p24;
reg  m24;
integer n24;
integer x24;
wire [39:0] c25 = `IFU_MON_I.cp0_xx_mrvbr;
reg  [39:0] p25;
reg  [39:0] m25;
integer n25;
integer x25;
wire c26 = `IFU_MON_I.cp0_yy_clk_en;
reg  p26;
reg  m26;
integer n26;
integer x26;
wire c27 = `IFU_MON_I.cpurst_b;
reg  p27;
reg  m27;
integer n27;
integer x27;
wire [31:0] c28 = `IFU_MON_I.dtu_ifu_debug_inst;
reg  [31:0] p28;
reg  [31:0] m28;
integer n28;
integer x28;
wire c29 = `IFU_MON_I.dtu_ifu_debug_inst_vld;
reg  p29;
reg  m29;
integer n29;
integer x29;
wire [21:0] c30 = `IFU_MON_I.dtu_ifu_halt_info0;
reg  [21:0] p30;
reg  [21:0] m30;
integer n30;
integer x30;
wire [21:0] c31 = `IFU_MON_I.dtu_ifu_halt_info1;
reg  [21:0] p31;
reg  [21:0] m31;
integer n31;
integer x31;
wire c32 = `IFU_MON_I.dtu_ifu_halt_info_vld;
reg  p32;
reg  m32;
integer n32;
integer x32;
wire c33 = `IFU_MON_I.dtu_ifu_halt_on_reset;
reg  p33;
reg  m33;
integer n33;
integer x33;
wire c34 = `IFU_MON_I.forever_cpuclk;
reg  p34;
reg  m34;
integer n34;
integer x34;
wire c35 = `IFU_MON_I.hpcp_ifu_cnt_en;
reg  p35;
reg  m35;
integer n35;
integer x35;
wire c36 = `IFU_MON_I.idu_ifu_id_stall;
reg  p36;
reg  m36;
integer n36;
integer x36;
wire [39:0] c37 = `IFU_MON_I.iu_ifu_bht_cur_pc;
reg  [39:0] p37;
reg  [39:0] m37;
integer n37;
integer x37;
wire c38 = `IFU_MON_I.iu_ifu_bht_mispred;
reg  p38;
reg  m38;
integer n38;
integer x38;
wire c39 = `IFU_MON_I.iu_ifu_bht_mispred_gate;
reg  p39;
reg  m39;
integer n39;
integer x39;
wire [1:0] c40 = `IFU_MON_I.iu_ifu_bht_pred;
reg  [1:0] p40;
reg  [1:0] m40;
integer n40;
integer x40;
wire c41 = `IFU_MON_I.iu_ifu_bht_taken;
reg  p41;
reg  m41;
integer n41;
integer x41;
wire c42 = `IFU_MON_I.iu_ifu_br_vld;
reg  p42;
reg  m42;
integer n42;
integer x42;
wire c43 = `IFU_MON_I.iu_ifu_br_vld_gate;
reg  p43;
reg  m43;
integer n43;
integer x43;
wire c44 = `IFU_MON_I.iu_ifu_link_vld;
reg  p44;
reg  m44;
integer n44;
integer x44;
wire c45 = `IFU_MON_I.iu_ifu_link_vld_gate;
reg  p45;
reg  m45;
integer n45;
integer x45;
wire c46 = `IFU_MON_I.iu_ifu_pc_mispred;
reg  p46;
reg  m46;
integer n46;
integer x46;
wire c47 = `IFU_MON_I.iu_ifu_pc_mispred_gate;
reg  p47;
reg  m47;
integer n47;
integer x47;
wire c48 = `IFU_MON_I.iu_ifu_ret_vld;
reg  p48;
reg  m48;
integer n48;
integer x48;
wire c49 = `IFU_MON_I.iu_ifu_ret_vld_gate;
reg  p49;
reg  m49;
integer n49;
integer x49;
wire [63:0] c50 = `IFU_MON_I.iu_ifu_tar_pc;
reg  [63:0] p50;
reg  [63:0] m50;
integer n50;
integer x50;
wire c51 = `IFU_MON_I.iu_ifu_tar_pc_vld;
reg  p51;
reg  m51;
integer n51;
integer x51;
wire c52 = `IFU_MON_I.iu_ifu_tar_pc_vld_gate;
reg  p52;
reg  m52;
integer n52;
integer x52;
wire c53 = `IFU_MON_I.mmu_ifu_access_fault;
reg  p53;
reg  m53;
integer n53;
integer x53;
wire [27:0] c54 = `IFU_MON_I.mmu_ifu_pa;
reg  [27:0] p54;
reg  [27:0] m54;
integer n54;
integer x54;
wire c55 = `IFU_MON_I.mmu_ifu_pa_vld;
reg  p55;
reg  m55;
integer n55;
integer x55;
wire [4:0] c56 = `IFU_MON_I.mmu_ifu_prot;
reg  [4:0] p56;
reg  [4:0] m56;
integer n56;
integer x56;
wire c57 = `IFU_MON_I.pad_yy_icg_scan_en;
reg  p57;
reg  m57;
integer n57;
integer x57;
wire [39:0] c58 = `IFU_MON_I.rtu_ifu_chgflw_pc;
reg  [39:0] p58;
reg  [39:0] m58;
integer n58;
integer x58;
wire c59 = `IFU_MON_I.rtu_ifu_chgflw_vld;
reg  p59;
reg  m59;
integer n59;
integer x59;
wire c60 = `IFU_MON_I.rtu_ifu_dbg_mask;
reg  p60;
reg  m60;
integer n60;
integer x60;
wire c61 = `IFU_MON_I.rtu_ifu_flush_fe;
reg  p61;
reg  m61;
integer n61;
integer x61;
wire c62 = `IFU_MON_I.rtu_yy_xx_dbgon;
reg  p62;
reg  m62;
integer n62;
integer x62;
wire [39:0] c63 = `IFU_MON_I.ifu_biu_araddr;
reg  [39:0] p63;
reg  [39:0] m63;
integer n63;
integer x63;
wire [1:0] c64 = `IFU_MON_I.ifu_biu_arburst;
reg  [1:0] p64;
reg  [1:0] m64;
integer n64;
integer x64;
wire [3:0] c65 = `IFU_MON_I.ifu_biu_arcache;
reg  [3:0] p65;
reg  [3:0] m65;
integer n65;
integer x65;
wire c66 = `IFU_MON_I.ifu_biu_arid;
reg  p66;
reg  m66;
integer n66;
integer x66;
wire [1:0] c67 = `IFU_MON_I.ifu_biu_arlen;
reg  [1:0] p67;
reg  [1:0] m67;
integer n67;
integer x67;
wire [2:0] c68 = `IFU_MON_I.ifu_biu_arprot;
reg  [2:0] p68;
reg  [2:0] m68;
integer n68;
integer x68;
wire [2:0] c69 = `IFU_MON_I.ifu_biu_arsize;
reg  [2:0] p69;
reg  [2:0] m69;
integer n69;
integer x69;
wire c70 = `IFU_MON_I.ifu_biu_arvalid;
reg  p70;
reg  m70;
integer n70;
integer x70;
wire c71 = `IFU_MON_I.ifu_cp0_bht_inv_done;
reg  p71;
reg  m71;
integer n71;
integer x71;
wire c72 = `IFU_MON_I.ifu_cp0_icache_inv_done;
reg  p72;
reg  m72;
integer n72;
integer x72;
wire [127:0] c73 = `IFU_MON_I.ifu_cp0_icache_read_data;
reg  [127:0] p73;
reg  [127:0] m73;
integer n73;
integer x73;
wire c74 = `IFU_MON_I.ifu_cp0_icache_read_data_vld;
reg  p74;
reg  m74;
integer n74;
integer x74;
wire c75 = `IFU_MON_I.ifu_cp0_rst_inv_req;
reg  p75;
reg  m75;
integer n75;
integer x75;
wire c76 = `IFU_MON_I.ifu_cp0_warm_up;
reg  p76;
reg  m76;
integer n76;
integer x76;
wire c77 = `IFU_MON_I.ifu_dtu_addr_vld0;
reg  p77;
reg  m77;
integer n77;
integer x77;
wire c78 = `IFU_MON_I.ifu_dtu_addr_vld1;
reg  p78;
reg  m78;
integer n78;
integer x78;
wire c79 = `IFU_MON_I.ifu_dtu_data_vld0;
reg  p79;
reg  m79;
integer n79;
integer x79;
wire c80 = `IFU_MON_I.ifu_dtu_data_vld1;
reg  p80;
reg  m80;
integer n80;
integer x80;
wire [20:0] c81 = `IFU_MON_I.ifu_dtu_debug_info;
reg  [20:0] p81;
reg  [20:0] m81;
integer n81;
integer x81;
wire [39:0] c82 = `IFU_MON_I.ifu_dtu_exe_addr0;
reg  [39:0] p82;
reg  [39:0] m82;
integer n82;
integer x82;
wire [39:0] c83 = `IFU_MON_I.ifu_dtu_exe_addr1;
reg  [39:0] p83;
reg  [39:0] m83;
integer n83;
integer x83;
wire [31:0] c84 = `IFU_MON_I.ifu_dtu_exe_data0;
reg  [31:0] p84;
reg  [31:0] m84;
integer n84;
integer x84;
wire [31:0] c85 = `IFU_MON_I.ifu_dtu_exe_data1;
reg  [31:0] p85;
reg  [31:0] m85;
integer n85;
integer x85;
wire c86 = `IFU_MON_I.ifu_hpcp_icache_access;
reg  p86;
reg  m86;
integer n86;
integer x86;
wire c87 = `IFU_MON_I.ifu_hpcp_icache_miss;
reg  p87;
reg  m87;
integer n87;
integer x87;
wire [1:0] c88 = `IFU_MON_I.ifu_idu_id_bht_pred;
reg  [1:0] p88;
reg  [1:0] m88;
integer n88;
integer x88;
wire c89 = `IFU_MON_I.ifu_idu_id_expt_acc_error;
reg  p89;
reg  m89;
integer n89;
integer x89;
wire c90 = `IFU_MON_I.ifu_idu_id_expt_high;
reg  p90;
reg  m90;
integer n90;
integer x90;
wire c91 = `IFU_MON_I.ifu_idu_id_expt_page_fault;
reg  p91;
reg  m91;
integer n91;
integer x91;
wire [21:0] c92 = `IFU_MON_I.ifu_idu_id_halt_info;
reg  [21:0] p92;
reg  [21:0] m92;
integer n92;
integer x92;
wire [31:0] c93 = `IFU_MON_I.ifu_idu_id_inst;
reg  [31:0] p93;
reg  [31:0] m93;
integer n93;
integer x93;
wire c94 = `IFU_MON_I.ifu_idu_id_inst_vld;
reg  p94;
reg  m94;
integer n94;
integer x94;
wire c95 = `IFU_MON_I.ifu_idu_warm_up;
reg  p95;
reg  m95;
integer n95;
integer x95;
wire [39:0] c96 = `IFU_MON_I.ifu_iu_chgflw_pc;
reg  [39:0] p96;
reg  [39:0] m96;
integer n96;
integer x96;
wire c97 = `IFU_MON_I.ifu_iu_chgflw_vld;
reg  p97;
reg  m97;
integer n97;
integer x97;
wire [39:0] c98 = `IFU_MON_I.ifu_iu_ex1_pc_pred;
reg  [39:0] p98;
reg  [39:0] m98;
integer n98;
integer x98;
wire c99 = `IFU_MON_I.ifu_iu_reset_vld;
reg  p99;
reg  m99;
integer n99;
integer x99;
wire c100 = `IFU_MON_I.ifu_iu_warm_up;
reg  p100;
reg  m100;
integer n100;
integer x100;
wire c101 = `IFU_MON_I.ifu_lsu_warm_up;
reg  p101;
reg  m101;
integer n101;
integer x101;
wire c102 = `IFU_MON_I.ifu_mmu_abort;
reg  p102;
reg  m102;
integer n102;
integer x102;
wire [51:0] c103 = `IFU_MON_I.ifu_mmu_va;
reg  [51:0] p103;
reg  [51:0] m103;
integer n103;
integer x103;
wire c104 = `IFU_MON_I.ifu_mmu_va_vld;
reg  p104;
reg  m104;
integer n104;
integer x104;
wire c105 = `IFU_MON_I.ifu_rtu_reset_halt_req;
reg  p105;
reg  m105;
integer n105;
integer x105;
wire c106 = `IFU_MON_I.ifu_rtu_warm_up;
reg  p106;
reg  m106;
integer n106;
integer x106;
wire c107 = `IFU_MON_I.ifu_vidu_warm_up;
reg  p107;
reg  m107;
integer n107;
integer x107;
wire c108 = `IFU_MON_I.ifu_vpu_warm_up;
reg  p108;
reg  m108;
integer n108;
integer x108;
wire c109 = `IFU_MON_I.ifu_yy_xx_no_op;
reg  p109;
reg  m109;
integer n109;
integer x109;

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
  end
end

final begin
  FH = $fopen("ifu_toggle.report", "w");
  $fwrite(FH, "IFU port toggle report -- instance:\n");
  $fwrite(FH, "  tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top.x_aq_top_0.x_aq_core.x_aq_ifu_top\n\n");
  $fwrite(FH, "port                               dir  width  bits_tog  tog_events  x_cycles\n");
  $fwrite(FH, "----------------------------------------------------------------------------\n");
  n_tog = 0;
  n_xseen = 0;
  $fwrite(FH, "biu_ifu_arready                    in      1 %0d %0d %0d\n", ones({127'b0, m0}), n0, x0);
  if (|m0) n_tog = n_tog + 1;
  if (x0 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "biu_ifu_rdata                      in    128 %0d %0d %0d\n", ones({m1}), n1, x1);
  if (|m1) n_tog = n_tog + 1;
  if (x1 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "biu_ifu_rid                        in      1 %0d %0d %0d\n", ones({127'b0, m2}), n2, x2);
  if (|m2) n_tog = n_tog + 1;
  if (x2 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "biu_ifu_rlast                      in      1 %0d %0d %0d\n", ones({127'b0, m3}), n3, x3);
  if (|m3) n_tog = n_tog + 1;
  if (x3 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "biu_ifu_rresp                      in      2 %0d %0d %0d\n", ones({126'b0, m4}), n4, x4);
  if (|m4) n_tog = n_tog + 1;
  if (x4 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "biu_ifu_rvalid                     in      1 %0d %0d %0d\n", ones({127'b0, m5}), n5, x5);
  if (|m5) n_tog = n_tog + 1;
  if (x5 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_bht_en                     in      1 %0d %0d %0d\n", ones({127'b0, m6}), n6, x6);
  if (|m6) n_tog = n_tog + 1;
  if (x6 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_bht_inv                    in      1 %0d %0d %0d\n", ones({127'b0, m7}), n7, x7);
  if (|m7) n_tog = n_tog + 1;
  if (x7 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_btb_clr                    in      1 %0d %0d %0d\n", ones({127'b0, m8}), n8, x8);
  if (|m8) n_tog = n_tog + 1;
  if (x8 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_btb_en                     in      1 %0d %0d %0d\n", ones({127'b0, m9}), n9, x9);
  if (|m9) n_tog = n_tog + 1;
  if (x9 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_en                  in      1 %0d %0d %0d\n", ones({127'b0, m10}), n10, x10);
  if (|m10) n_tog = n_tog + 1;
  if (x10 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_inv_addr            in     64 %0d %0d %0d\n", ones({64'b0, m11}), n11, x11);
  if (|m11) n_tog = n_tog + 1;
  if (x11 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_inv_req             in      1 %0d %0d %0d\n", ones({127'b0, m12}), n12, x12);
  if (|m12) n_tog = n_tog + 1;
  if (x12 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_inv_type            in      2 %0d %0d %0d\n", ones({126'b0, m13}), n13, x13);
  if (|m13) n_tog = n_tog + 1;
  if (x13 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_pref_en             in      1 %0d %0d %0d\n", ones({127'b0, m14}), n14, x14);
  if (|m14) n_tog = n_tog + 1;
  if (x14 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_read_index          in     14 %0d %0d %0d\n", ones({114'b0, m15}), n15, x15);
  if (|m15) n_tog = n_tog + 1;
  if (x15 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_read_req            in      1 %0d %0d %0d\n", ones({127'b0, m16}), n16, x16);
  if (|m16) n_tog = n_tog + 1;
  if (x16 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_read_tag            in      1 %0d %0d %0d\n", ones({127'b0, m17}), n17, x17);
  if (|m17) n_tog = n_tog + 1;
  if (x17 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_read_way            in      1 %0d %0d %0d\n", ones({127'b0, m18}), n18, x18);
  if (|m18) n_tog = n_tog + 1;
  if (x18 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icg_en                     in      1 %0d %0d %0d\n", ones({127'b0, m19}), n19, x19);
  if (|m19) n_tog = n_tog + 1;
  if (x19 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_in_lpmd                    in      1 %0d %0d %0d\n", ones({127'b0, m20}), n20, x20);
  if (|m20) n_tog = n_tog + 1;
  if (x20 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_iwpe                       in      1 %0d %0d %0d\n", ones({127'b0, m21}), n21, x21);
  if (|m21) n_tog = n_tog + 1;
  if (x21 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_lpmd_req                   in      1 %0d %0d %0d\n", ones({127'b0, m22}), n22, x22);
  if (|m22) n_tog = n_tog + 1;
  if (x22 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_ras_en                     in      1 %0d %0d %0d\n", ones({127'b0, m23}), n23, x23);
  if (|m23) n_tog = n_tog + 1;
  if (x23 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_rst_inv_done               in      1 %0d %0d %0d\n", ones({127'b0, m24}), n24, x24);
  if (|m24) n_tog = n_tog + 1;
  if (x24 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_xx_mrvbr                       in     40 %0d %0d %0d\n", ones({88'b0, m25}), n25, x25);
  if (|m25) n_tog = n_tog + 1;
  if (x25 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_yy_clk_en                      in      1 %0d %0d %0d\n", ones({127'b0, m26}), n26, x26);
  if (|m26) n_tog = n_tog + 1;
  if (x26 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cpurst_b                           in      1 %0d %0d %0d   [infra]\n", ones({127'b0, m27}), n27, x27);
  $fwrite(FH, "dtu_ifu_debug_inst                 in     32 %0d %0d %0d\n", ones({96'b0, m28}), n28, x28);
  if (|m28) n_tog = n_tog + 1;
  if (x28 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "dtu_ifu_debug_inst_vld             in      1 %0d %0d %0d\n", ones({127'b0, m29}), n29, x29);
  if (|m29) n_tog = n_tog + 1;
  if (x29 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "dtu_ifu_halt_info0                 in     22 %0d %0d %0d\n", ones({106'b0, m30}), n30, x30);
  if (|m30) n_tog = n_tog + 1;
  if (x30 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "dtu_ifu_halt_info1                 in     22 %0d %0d %0d\n", ones({106'b0, m31}), n31, x31);
  if (|m31) n_tog = n_tog + 1;
  if (x31 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "dtu_ifu_halt_info_vld              in      1 %0d %0d %0d\n", ones({127'b0, m32}), n32, x32);
  if (|m32) n_tog = n_tog + 1;
  if (x32 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "dtu_ifu_halt_on_reset              in      1 %0d %0d %0d\n", ones({127'b0, m33}), n33, x33);
  if (|m33) n_tog = n_tog + 1;
  if (x33 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "forever_cpuclk                     in      1 %0d %0d %0d   [infra]\n", ones({127'b0, m34}), n34, x34);
  $fwrite(FH, "hpcp_ifu_cnt_en                    in      1 %0d %0d %0d\n", ones({127'b0, m35}), n35, x35);
  if (|m35) n_tog = n_tog + 1;
  if (x35 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_ifu_id_stall                   in      1 %0d %0d %0d\n", ones({127'b0, m36}), n36, x36);
  if (|m36) n_tog = n_tog + 1;
  if (x36 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_bht_cur_pc                  in     40 %0d %0d %0d\n", ones({88'b0, m37}), n37, x37);
  if (|m37) n_tog = n_tog + 1;
  if (x37 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_bht_mispred                 in      1 %0d %0d %0d\n", ones({127'b0, m38}), n38, x38);
  if (|m38) n_tog = n_tog + 1;
  if (x38 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_bht_mispred_gate            in      1 %0d %0d %0d\n", ones({127'b0, m39}), n39, x39);
  if (|m39) n_tog = n_tog + 1;
  if (x39 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_bht_pred                    in      2 %0d %0d %0d\n", ones({126'b0, m40}), n40, x40);
  if (|m40) n_tog = n_tog + 1;
  if (x40 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_bht_taken                   in      1 %0d %0d %0d\n", ones({127'b0, m41}), n41, x41);
  if (|m41) n_tog = n_tog + 1;
  if (x41 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_br_vld                      in      1 %0d %0d %0d\n", ones({127'b0, m42}), n42, x42);
  if (|m42) n_tog = n_tog + 1;
  if (x42 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_br_vld_gate                 in      1 %0d %0d %0d\n", ones({127'b0, m43}), n43, x43);
  if (|m43) n_tog = n_tog + 1;
  if (x43 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_link_vld                    in      1 %0d %0d %0d\n", ones({127'b0, m44}), n44, x44);
  if (|m44) n_tog = n_tog + 1;
  if (x44 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_link_vld_gate               in      1 %0d %0d %0d\n", ones({127'b0, m45}), n45, x45);
  if (|m45) n_tog = n_tog + 1;
  if (x45 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_pc_mispred                  in      1 %0d %0d %0d\n", ones({127'b0, m46}), n46, x46);
  if (|m46) n_tog = n_tog + 1;
  if (x46 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_pc_mispred_gate             in      1 %0d %0d %0d\n", ones({127'b0, m47}), n47, x47);
  if (|m47) n_tog = n_tog + 1;
  if (x47 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_ret_vld                     in      1 %0d %0d %0d\n", ones({127'b0, m48}), n48, x48);
  if (|m48) n_tog = n_tog + 1;
  if (x48 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_ret_vld_gate                in      1 %0d %0d %0d\n", ones({127'b0, m49}), n49, x49);
  if (|m49) n_tog = n_tog + 1;
  if (x49 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_tar_pc                      in     64 %0d %0d %0d\n", ones({64'b0, m50}), n50, x50);
  if (|m50) n_tog = n_tog + 1;
  if (x50 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_tar_pc_vld                  in      1 %0d %0d %0d\n", ones({127'b0, m51}), n51, x51);
  if (|m51) n_tog = n_tog + 1;
  if (x51 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_ifu_tar_pc_vld_gate             in      1 %0d %0d %0d\n", ones({127'b0, m52}), n52, x52);
  if (|m52) n_tog = n_tog + 1;
  if (x52 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "mmu_ifu_access_fault               in      1 %0d %0d %0d\n", ones({127'b0, m53}), n53, x53);
  if (|m53) n_tog = n_tog + 1;
  if (x53 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "mmu_ifu_pa                         in     28 %0d %0d %0d\n", ones({100'b0, m54}), n54, x54);
  if (|m54) n_tog = n_tog + 1;
  if (x54 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "mmu_ifu_pa_vld                     in      1 %0d %0d %0d\n", ones({127'b0, m55}), n55, x55);
  if (|m55) n_tog = n_tog + 1;
  if (x55 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "mmu_ifu_prot                       in      5 %0d %0d %0d\n", ones({123'b0, m56}), n56, x56);
  if (|m56) n_tog = n_tog + 1;
  if (x56 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "pad_yy_icg_scan_en                 in      1 %0d %0d %0d   [infra]\n", ones({127'b0, m57}), n57, x57);
  $fwrite(FH, "rtu_ifu_chgflw_pc                  in     40 %0d %0d %0d\n", ones({88'b0, m58}), n58, x58);
  if (|m58) n_tog = n_tog + 1;
  if (x58 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_ifu_chgflw_vld                 in      1 %0d %0d %0d\n", ones({127'b0, m59}), n59, x59);
  if (|m59) n_tog = n_tog + 1;
  if (x59 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_ifu_dbg_mask                   in      1 %0d %0d %0d\n", ones({127'b0, m60}), n60, x60);
  if (|m60) n_tog = n_tog + 1;
  if (x60 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_ifu_flush_fe                   in      1 %0d %0d %0d\n", ones({127'b0, m61}), n61, x61);
  if (|m61) n_tog = n_tog + 1;
  if (x61 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_yy_xx_dbgon                    in      1 %0d %0d %0d\n", ones({127'b0, m62}), n62, x62);
  if (|m62) n_tog = n_tog + 1;
  if (x62 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_biu_araddr                     out    40 %0d %0d %0d\n", ones({88'b0, m63}), n63, x63);
  if (|m63) n_tog = n_tog + 1;
  if (x63 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_biu_arburst                    out     2 %0d %0d %0d\n", ones({126'b0, m64}), n64, x64);
  if (|m64) n_tog = n_tog + 1;
  if (x64 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_biu_arcache                    out     4 %0d %0d %0d\n", ones({124'b0, m65}), n65, x65);
  if (|m65) n_tog = n_tog + 1;
  if (x65 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_biu_arid                       out     1 %0d %0d %0d\n", ones({127'b0, m66}), n66, x66);
  if (|m66) n_tog = n_tog + 1;
  if (x66 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_biu_arlen                      out     2 %0d %0d %0d\n", ones({126'b0, m67}), n67, x67);
  if (|m67) n_tog = n_tog + 1;
  if (x67 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_biu_arprot                     out     3 %0d %0d %0d\n", ones({125'b0, m68}), n68, x68);
  if (|m68) n_tog = n_tog + 1;
  if (x68 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_biu_arsize                     out     3 %0d %0d %0d\n", ones({125'b0, m69}), n69, x69);
  if (|m69) n_tog = n_tog + 1;
  if (x69 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_biu_arvalid                    out     1 %0d %0d %0d\n", ones({127'b0, m70}), n70, x70);
  if (|m70) n_tog = n_tog + 1;
  if (x70 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_bht_inv_done               out     1 %0d %0d %0d\n", ones({127'b0, m71}), n71, x71);
  if (|m71) n_tog = n_tog + 1;
  if (x71 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_icache_inv_done            out     1 %0d %0d %0d\n", ones({127'b0, m72}), n72, x72);
  if (|m72) n_tog = n_tog + 1;
  if (x72 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_icache_read_data           out   128 %0d %0d %0d\n", ones({m73}), n73, x73);
  if (|m73) n_tog = n_tog + 1;
  if (x73 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_icache_read_data_vld       out     1 %0d %0d %0d\n", ones({127'b0, m74}), n74, x74);
  if (|m74) n_tog = n_tog + 1;
  if (x74 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_rst_inv_req                out     1 %0d %0d %0d\n", ones({127'b0, m75}), n75, x75);
  if (|m75) n_tog = n_tog + 1;
  if (x75 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_warm_up                    out     1 %0d %0d %0d\n", ones({127'b0, m76}), n76, x76);
  if (|m76) n_tog = n_tog + 1;
  if (x76 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_dtu_addr_vld0                  out     1 %0d %0d %0d\n", ones({127'b0, m77}), n77, x77);
  if (|m77) n_tog = n_tog + 1;
  if (x77 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_dtu_addr_vld1                  out     1 %0d %0d %0d\n", ones({127'b0, m78}), n78, x78);
  if (|m78) n_tog = n_tog + 1;
  if (x78 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_dtu_data_vld0                  out     1 %0d %0d %0d\n", ones({127'b0, m79}), n79, x79);
  if (|m79) n_tog = n_tog + 1;
  if (x79 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_dtu_data_vld1                  out     1 %0d %0d %0d\n", ones({127'b0, m80}), n80, x80);
  if (|m80) n_tog = n_tog + 1;
  if (x80 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_dtu_debug_info                 out    21 %0d %0d %0d\n", ones({107'b0, m81}), n81, x81);
  if (|m81) n_tog = n_tog + 1;
  if (x81 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_dtu_exe_addr0                  out    40 %0d %0d %0d\n", ones({88'b0, m82}), n82, x82);
  if (|m82) n_tog = n_tog + 1;
  if (x82 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_dtu_exe_addr1                  out    40 %0d %0d %0d\n", ones({88'b0, m83}), n83, x83);
  if (|m83) n_tog = n_tog + 1;
  if (x83 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_dtu_exe_data0                  out    32 %0d %0d %0d\n", ones({96'b0, m84}), n84, x84);
  if (|m84) n_tog = n_tog + 1;
  if (x84 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_dtu_exe_data1                  out    32 %0d %0d %0d\n", ones({96'b0, m85}), n85, x85);
  if (|m85) n_tog = n_tog + 1;
  if (x85 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_hpcp_icache_access             out     1 %0d %0d %0d\n", ones({127'b0, m86}), n86, x86);
  if (|m86) n_tog = n_tog + 1;
  if (x86 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_hpcp_icache_miss               out     1 %0d %0d %0d\n", ones({127'b0, m87}), n87, x87);
  if (|m87) n_tog = n_tog + 1;
  if (x87 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_bht_pred                out     2 %0d %0d %0d\n", ones({126'b0, m88}), n88, x88);
  if (|m88) n_tog = n_tog + 1;
  if (x88 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_expt_acc_error          out     1 %0d %0d %0d\n", ones({127'b0, m89}), n89, x89);
  if (|m89) n_tog = n_tog + 1;
  if (x89 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_expt_high               out     1 %0d %0d %0d\n", ones({127'b0, m90}), n90, x90);
  if (|m90) n_tog = n_tog + 1;
  if (x90 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_expt_page_fault         out     1 %0d %0d %0d\n", ones({127'b0, m91}), n91, x91);
  if (|m91) n_tog = n_tog + 1;
  if (x91 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_halt_info               out    22 %0d %0d %0d\n", ones({106'b0, m92}), n92, x92);
  if (|m92) n_tog = n_tog + 1;
  if (x92 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_inst                    out    32 %0d %0d %0d\n", ones({96'b0, m93}), n93, x93);
  if (|m93) n_tog = n_tog + 1;
  if (x93 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_id_inst_vld                out     1 %0d %0d %0d\n", ones({127'b0, m94}), n94, x94);
  if (|m94) n_tog = n_tog + 1;
  if (x94 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_idu_warm_up                    out     1 %0d %0d %0d\n", ones({127'b0, m95}), n95, x95);
  if (|m95) n_tog = n_tog + 1;
  if (x95 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_iu_chgflw_pc                   out    40 %0d %0d %0d\n", ones({88'b0, m96}), n96, x96);
  if (|m96) n_tog = n_tog + 1;
  if (x96 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_iu_chgflw_vld                  out     1 %0d %0d %0d\n", ones({127'b0, m97}), n97, x97);
  if (|m97) n_tog = n_tog + 1;
  if (x97 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_iu_ex1_pc_pred                 out    40 %0d %0d %0d\n", ones({88'b0, m98}), n98, x98);
  if (|m98) n_tog = n_tog + 1;
  if (x98 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_iu_reset_vld                   out     1 %0d %0d %0d\n", ones({127'b0, m99}), n99, x99);
  if (|m99) n_tog = n_tog + 1;
  if (x99 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_iu_warm_up                     out     1 %0d %0d %0d\n", ones({127'b0, m100}), n100, x100);
  if (|m100) n_tog = n_tog + 1;
  if (x100 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_lsu_warm_up                    out     1 %0d %0d %0d\n", ones({127'b0, m101}), n101, x101);
  if (|m101) n_tog = n_tog + 1;
  if (x101 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_mmu_abort                      out     1 %0d %0d %0d\n", ones({127'b0, m102}), n102, x102);
  if (|m102) n_tog = n_tog + 1;
  if (x102 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_mmu_va                         out    52 %0d %0d %0d\n", ones({76'b0, m103}), n103, x103);
  if (|m103) n_tog = n_tog + 1;
  if (x103 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_mmu_va_vld                     out     1 %0d %0d %0d\n", ones({127'b0, m104}), n104, x104);
  if (|m104) n_tog = n_tog + 1;
  if (x104 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_rtu_reset_halt_req             out     1 %0d %0d %0d\n", ones({127'b0, m105}), n105, x105);
  if (|m105) n_tog = n_tog + 1;
  if (x105 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_rtu_warm_up                    out     1 %0d %0d %0d\n", ones({127'b0, m106}), n106, x106);
  if (|m106) n_tog = n_tog + 1;
  if (x106 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_vidu_warm_up                   out     1 %0d %0d %0d\n", ones({127'b0, m107}), n107, x107);
  if (|m107) n_tog = n_tog + 1;
  if (x107 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_vpu_warm_up                    out     1 %0d %0d %0d\n", ones({127'b0, m108}), n108, x108);
  if (|m108) n_tog = n_tog + 1;
  if (x108 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_yy_xx_no_op                    out     1 %0d %0d %0d\n", ones({127'b0, m109}), n109, x109);
  if (|m109) n_tog = n_tog + 1;
  if (x109 != 0) n_xseen = n_xseen + 1;

  $fwrite(FH, "\nSUMMARY: %0d/107 functional ports toggled (3 infrastructure ports excluded)\n", n_tog);
  $fwrite(FH, "X-SEEN : %0d functional ports held an X/Z bit at some point\n", n_xseen);
  $fwrite(FH, "NEVER TOGGLED:");
  if (~|m0) $fwrite(FH, " biu_ifu_arready");
  if (~|m1) $fwrite(FH, " biu_ifu_rdata");
  if (~|m2) $fwrite(FH, " biu_ifu_rid");
  if (~|m3) $fwrite(FH, " biu_ifu_rlast");
  if (~|m4) $fwrite(FH, " biu_ifu_rresp");
  if (~|m5) $fwrite(FH, " biu_ifu_rvalid");
  if (~|m6) $fwrite(FH, " cp0_ifu_bht_en");
  if (~|m7) $fwrite(FH, " cp0_ifu_bht_inv");
  if (~|m8) $fwrite(FH, " cp0_ifu_btb_clr");
  if (~|m9) $fwrite(FH, " cp0_ifu_btb_en");
  if (~|m10) $fwrite(FH, " cp0_ifu_icache_en");
  if (~|m11) $fwrite(FH, " cp0_ifu_icache_inv_addr");
  if (~|m12) $fwrite(FH, " cp0_ifu_icache_inv_req");
  if (~|m13) $fwrite(FH, " cp0_ifu_icache_inv_type");
  if (~|m14) $fwrite(FH, " cp0_ifu_icache_pref_en");
  if (~|m15) $fwrite(FH, " cp0_ifu_icache_read_index");
  if (~|m16) $fwrite(FH, " cp0_ifu_icache_read_req");
  if (~|m17) $fwrite(FH, " cp0_ifu_icache_read_tag");
  if (~|m18) $fwrite(FH, " cp0_ifu_icache_read_way");
  if (~|m19) $fwrite(FH, " cp0_ifu_icg_en");
  if (~|m20) $fwrite(FH, " cp0_ifu_in_lpmd");
  if (~|m21) $fwrite(FH, " cp0_ifu_iwpe");
  if (~|m22) $fwrite(FH, " cp0_ifu_lpmd_req");
  if (~|m23) $fwrite(FH, " cp0_ifu_ras_en");
  if (~|m24) $fwrite(FH, " cp0_ifu_rst_inv_done");
  if (~|m25) $fwrite(FH, " cp0_xx_mrvbr");
  if (~|m26) $fwrite(FH, " cp0_yy_clk_en");
  if (~|m28) $fwrite(FH, " dtu_ifu_debug_inst");
  if (~|m29) $fwrite(FH, " dtu_ifu_debug_inst_vld");
  if (~|m30) $fwrite(FH, " dtu_ifu_halt_info0");
  if (~|m31) $fwrite(FH, " dtu_ifu_halt_info1");
  if (~|m32) $fwrite(FH, " dtu_ifu_halt_info_vld");
  if (~|m33) $fwrite(FH, " dtu_ifu_halt_on_reset");
  if (~|m35) $fwrite(FH, " hpcp_ifu_cnt_en");
  if (~|m36) $fwrite(FH, " idu_ifu_id_stall");
  if (~|m37) $fwrite(FH, " iu_ifu_bht_cur_pc");
  if (~|m38) $fwrite(FH, " iu_ifu_bht_mispred");
  if (~|m39) $fwrite(FH, " iu_ifu_bht_mispred_gate");
  if (~|m40) $fwrite(FH, " iu_ifu_bht_pred");
  if (~|m41) $fwrite(FH, " iu_ifu_bht_taken");
  if (~|m42) $fwrite(FH, " iu_ifu_br_vld");
  if (~|m43) $fwrite(FH, " iu_ifu_br_vld_gate");
  if (~|m44) $fwrite(FH, " iu_ifu_link_vld");
  if (~|m45) $fwrite(FH, " iu_ifu_link_vld_gate");
  if (~|m46) $fwrite(FH, " iu_ifu_pc_mispred");
  if (~|m47) $fwrite(FH, " iu_ifu_pc_mispred_gate");
  if (~|m48) $fwrite(FH, " iu_ifu_ret_vld");
  if (~|m49) $fwrite(FH, " iu_ifu_ret_vld_gate");
  if (~|m50) $fwrite(FH, " iu_ifu_tar_pc");
  if (~|m51) $fwrite(FH, " iu_ifu_tar_pc_vld");
  if (~|m52) $fwrite(FH, " iu_ifu_tar_pc_vld_gate");
  if (~|m53) $fwrite(FH, " mmu_ifu_access_fault");
  if (~|m54) $fwrite(FH, " mmu_ifu_pa");
  if (~|m55) $fwrite(FH, " mmu_ifu_pa_vld");
  if (~|m56) $fwrite(FH, " mmu_ifu_prot");
  if (~|m58) $fwrite(FH, " rtu_ifu_chgflw_pc");
  if (~|m59) $fwrite(FH, " rtu_ifu_chgflw_vld");
  if (~|m60) $fwrite(FH, " rtu_ifu_dbg_mask");
  if (~|m61) $fwrite(FH, " rtu_ifu_flush_fe");
  if (~|m62) $fwrite(FH, " rtu_yy_xx_dbgon");
  if (~|m63) $fwrite(FH, " ifu_biu_araddr");
  if (~|m64) $fwrite(FH, " ifu_biu_arburst");
  if (~|m65) $fwrite(FH, " ifu_biu_arcache");
  if (~|m66) $fwrite(FH, " ifu_biu_arid");
  if (~|m67) $fwrite(FH, " ifu_biu_arlen");
  if (~|m68) $fwrite(FH, " ifu_biu_arprot");
  if (~|m69) $fwrite(FH, " ifu_biu_arsize");
  if (~|m70) $fwrite(FH, " ifu_biu_arvalid");
  if (~|m71) $fwrite(FH, " ifu_cp0_bht_inv_done");
  if (~|m72) $fwrite(FH, " ifu_cp0_icache_inv_done");
  if (~|m73) $fwrite(FH, " ifu_cp0_icache_read_data");
  if (~|m74) $fwrite(FH, " ifu_cp0_icache_read_data_vld");
  if (~|m75) $fwrite(FH, " ifu_cp0_rst_inv_req");
  if (~|m76) $fwrite(FH, " ifu_cp0_warm_up");
  if (~|m77) $fwrite(FH, " ifu_dtu_addr_vld0");
  if (~|m78) $fwrite(FH, " ifu_dtu_addr_vld1");
  if (~|m79) $fwrite(FH, " ifu_dtu_data_vld0");
  if (~|m80) $fwrite(FH, " ifu_dtu_data_vld1");
  if (~|m81) $fwrite(FH, " ifu_dtu_debug_info");
  if (~|m82) $fwrite(FH, " ifu_dtu_exe_addr0");
  if (~|m83) $fwrite(FH, " ifu_dtu_exe_addr1");
  if (~|m84) $fwrite(FH, " ifu_dtu_exe_data0");
  if (~|m85) $fwrite(FH, " ifu_dtu_exe_data1");
  if (~|m86) $fwrite(FH, " ifu_hpcp_icache_access");
  if (~|m87) $fwrite(FH, " ifu_hpcp_icache_miss");
  if (~|m88) $fwrite(FH, " ifu_idu_id_bht_pred");
  if (~|m89) $fwrite(FH, " ifu_idu_id_expt_acc_error");
  if (~|m90) $fwrite(FH, " ifu_idu_id_expt_high");
  if (~|m91) $fwrite(FH, " ifu_idu_id_expt_page_fault");
  if (~|m92) $fwrite(FH, " ifu_idu_id_halt_info");
  if (~|m93) $fwrite(FH, " ifu_idu_id_inst");
  if (~|m94) $fwrite(FH, " ifu_idu_id_inst_vld");
  if (~|m95) $fwrite(FH, " ifu_idu_warm_up");
  if (~|m96) $fwrite(FH, " ifu_iu_chgflw_pc");
  if (~|m97) $fwrite(FH, " ifu_iu_chgflw_vld");
  if (~|m98) $fwrite(FH, " ifu_iu_ex1_pc_pred");
  if (~|m99) $fwrite(FH, " ifu_iu_reset_vld");
  if (~|m100) $fwrite(FH, " ifu_iu_warm_up");
  if (~|m101) $fwrite(FH, " ifu_lsu_warm_up");
  if (~|m102) $fwrite(FH, " ifu_mmu_abort");
  if (~|m103) $fwrite(FH, " ifu_mmu_va");
  if (~|m104) $fwrite(FH, " ifu_mmu_va_vld");
  if (~|m105) $fwrite(FH, " ifu_rtu_reset_halt_req");
  if (~|m106) $fwrite(FH, " ifu_rtu_warm_up");
  if (~|m107) $fwrite(FH, " ifu_vidu_warm_up");
  if (~|m108) $fwrite(FH, " ifu_vpu_warm_up");
  if (~|m109) $fwrite(FH, " ifu_yy_xx_no_op");
  $fwrite(FH, "\n");
  $fclose(FH);
  $display("[ifu_toggle_mon] %0d/107 functional IFU ports toggled; report in ifu_toggle.report", n_tog);
end

endmodule

`undef IFU_MON_I
`endif // IFU_TOGGLE_MON
