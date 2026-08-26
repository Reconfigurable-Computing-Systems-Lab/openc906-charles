// -------------------------------------------------------------------
// AUTO-GENERATED -- do not edit by hand.
//   generator : smart_run/cli_tools/gen_toggle_mon.py
//   source    : ../C906_RTL_FACTORY/gen_rtl/cp0/rtl/aq_cp0_top.v
//   ports     : 204 total (178 functional, 3 infrastructure, 23 provably dead)
//
// Per-port toggle monitor. Reports, at $finish, how many bits of each
// port of the probed instance ever changed value. Used to prove that a
// test actually stimulated the module.
// -------------------------------------------------------------------

`ifdef CP0_TOGGLE_MON

`define CP0_MON_I tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top.x_aq_top_0.x_aq_core.x_aq_cp0_top

module cp0_toggle_mon (
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
wire [2:0] c0 = `CP0_MON_I.biu_cp0_coreid;
reg  [2:0] p0;
reg  [2:0] m0;
integer n0;
integer x0;
wire c1 = `CP0_MON_I.biu_cp0_me_int;
reg  p1;
reg  m1;
integer n1;
integer x1;
wire c2 = `CP0_MON_I.biu_cp0_ms_int;
reg  p2;
reg  m2;
integer n2;
integer x2;
wire c3 = `CP0_MON_I.biu_cp0_mt_int;
reg  p3;
reg  m3;
integer n3;
integer x3;
wire [39:0] c4 = `CP0_MON_I.biu_cp0_rvba;
reg  [39:0] p4;
reg  [39:0] m4;
integer n4;
integer x4;
wire c5 = `CP0_MON_I.biu_cp0_se_int;
reg  p5;
reg  m5;
integer n5;
integer x5;
wire c6 = `CP0_MON_I.biu_cp0_ss_int;
reg  p6;
reg  m6;
integer n6;
integer x6;
wire c7 = `CP0_MON_I.biu_cp0_st_int;
reg  p7;
reg  m7;
integer n7;
integer x7;
wire c8 = `CP0_MON_I.cpurst_b;
reg  p8;
reg  m8;
integer n8;
integer x8;
wire c9 = `CP0_MON_I.dtu_cp0_dcsr_mprven;
reg  p9;
reg  m9;
integer n9;
integer x9;
wire [1:0] c10 = `CP0_MON_I.dtu_cp0_dcsr_prv;
reg  [1:0] p10;
reg  [1:0] m10;
integer n10;
integer x10;
wire [63:0] c11 = `CP0_MON_I.dtu_cp0_rdata;
reg  [63:0] p11;
reg  [63:0] m11;
integer n11;
integer x11;
wire c12 = `CP0_MON_I.dtu_cp0_wake_up;
reg  p12;
reg  m12;
integer n12;
integer x12;
wire c13 = `CP0_MON_I.forever_cpuclk;
reg  p13;
reg  m13;
integer n13;
integer x13;
wire [63:0] c14 = `CP0_MON_I.hpcp_cp0_data;
reg  [63:0] p14;
reg  [63:0] m14;
integer n14;
integer x14;
wire c15 = `CP0_MON_I.hpcp_cp0_int_vld;
reg  p15;
reg  m15;
integer n15;
integer x15;
wire c16 = `CP0_MON_I.hpcp_cp0_sce;
reg  p16;
reg  m16;
integer n16;
integer x16;
wire c17 = `CP0_MON_I.idu_cp0_ex1_dp_sel;
reg  p17;
reg  m17;
integer n17;
integer x17;
wire [5:0] c18 = `CP0_MON_I.idu_cp0_ex1_dst0_reg;
reg  [5:0] p18;
reg  [5:0] m18;
integer n18;
integer x18;
wire c19 = `CP0_MON_I.idu_cp0_ex1_expt_acc_error;
reg  p19;
reg  m19;
integer n19;
integer x19;
wire c20 = `CP0_MON_I.idu_cp0_ex1_expt_high;
reg  p20;
reg  m20;
integer n20;
integer x20;
wire c21 = `CP0_MON_I.idu_cp0_ex1_expt_illegal;
reg  p21;
reg  m21;
integer n21;
integer x21;
wire c22 = `CP0_MON_I.idu_cp0_ex1_expt_page_fault;
reg  p22;
reg  m22;
integer n22;
integer x22;
wire [19:0] c23 = `CP0_MON_I.idu_cp0_ex1_func;
reg  [19:0] p23;
reg  [19:0] m23;
integer n23;
integer x23;
wire c24 = `CP0_MON_I.idu_cp0_ex1_gateclk_sel;
reg  p24;
reg  m24;
integer n24;
integer x24;
wire [21:0] c25 = `CP0_MON_I.idu_cp0_ex1_halt_info;
reg  [21:0] p25;
reg  [21:0] m25;
integer n25;
integer x25;
wire c26 = `CP0_MON_I.idu_cp0_ex1_length;
reg  p26;
reg  m26;
integer n26;
integer x26;
wire [31:0] c27 = `CP0_MON_I.idu_cp0_ex1_opcode;
reg  [31:0] p27;
reg  [31:0] m27;
integer n27;
integer x27;
wire c28 = `CP0_MON_I.idu_cp0_ex1_sel;
reg  p28;
reg  m28;
integer n28;
integer x28;
wire c29 = `CP0_MON_I.idu_cp0_ex1_split;
reg  p29;
reg  m29;
integer n29;
integer x29;
wire [63:0] c30 = `CP0_MON_I.idu_cp0_ex1_src0_data;
reg  [63:0] p30;
reg  [63:0] m30;
integer n30;
integer x30;
wire [63:0] c31 = `CP0_MON_I.idu_cp0_ex1_src1_data;
reg  [63:0] p31;
reg  [63:0] m31;
integer n31;
integer x31;
wire c32 = `CP0_MON_I.ifu_cp0_bht_inv_done;
reg  p32;
reg  m32;
integer n32;
integer x32;
wire c33 = `CP0_MON_I.ifu_cp0_icache_inv_done;
reg  p33;
reg  m33;
integer n33;
integer x33;
wire [127:0] c34 = `CP0_MON_I.ifu_cp0_icache_read_data;
reg  [127:0] p34;
reg  [127:0] m34;
integer n34;
integer x34;
wire c35 = `CP0_MON_I.ifu_cp0_icache_read_data_vld;
reg  p35;
reg  m35;
integer n35;
integer x35;
wire c36 = `CP0_MON_I.ifu_cp0_rst_inv_req;
reg  p36;
reg  m36;
integer n36;
integer x36;
wire c37 = `CP0_MON_I.ifu_cp0_warm_up;
reg  p37;
reg  m37;
integer n37;
integer x37;
wire c38 = `CP0_MON_I.ifu_yy_xx_no_op;
reg  p38;
reg  m38;
integer n38;
integer x38;
wire [39:0] c39 = `CP0_MON_I.iu_cp0_ex1_cur_pc;
reg  [39:0] p39;
reg  [39:0] m39;
integer n39;
integer x39;
wire [127:0] c40 = `CP0_MON_I.lsu_cp0_dcache_read_data;
reg  [127:0] p40;
reg  [127:0] m40;
integer n40;
integer x40;
wire c41 = `CP0_MON_I.lsu_cp0_dcache_read_data_vld;
reg  p41;
reg  m41;
integer n41;
integer x41;
wire c42 = `CP0_MON_I.lsu_cp0_fence_ack;
reg  p42;
reg  m42;
integer n42;
integer x42;
wire c43 = `CP0_MON_I.lsu_cp0_icc_done;
reg  p43;
reg  m43;
integer n43;
integer x43;
wire c44 = `CP0_MON_I.lsu_cp0_sync_ack;
reg  p44;
reg  m44;
integer n44;
integer x44;
wire c45 = `CP0_MON_I.mmu_cp0_cmplt;
reg  p45;
reg  m45;
integer n45;
integer x45;
wire [63:0] c46 = `CP0_MON_I.mmu_cp0_data;
reg  [63:0] p46;
reg  [63:0] m46;
integer n46;
integer x46;
wire c47 = `CP0_MON_I.mmu_cp0_tlb_inv_done;
reg  p47;
reg  m47;
integer n47;
integer x47;
wire c48 = `CP0_MON_I.mmu_yy_xx_no_op;
reg  p48;
reg  m48;
integer n48;
integer x48;
wire c49 = `CP0_MON_I.pad_yy_icg_scan_en;
reg  p49;
reg  m49;
integer n49;
integer x49;
wire [63:0] c50 = `CP0_MON_I.pmp_cp0_data;
reg  [63:0] p50;
reg  [63:0] m50;
integer n50;
integer x50;
wire [63:0] c51 = `CP0_MON_I.rtu_cp0_epc;
reg  [63:0] p51;
reg  [63:0] m51;
integer n51;
integer x51;
wire c52 = `CP0_MON_I.rtu_cp0_exit_debug;
reg  p52;
reg  m52;
integer n52;
integer x52;
wire [4:0] c53 = `CP0_MON_I.rtu_cp0_fflags;
reg  [4:0] p53;
reg  [4:0] m53;
integer n53;
integer x53;
wire c54 = `CP0_MON_I.rtu_cp0_fflags_updt;
reg  p54;
reg  m54;
integer n54;
integer x54;
wire c55 = `CP0_MON_I.rtu_cp0_fs_dirty_updt;
reg  p55;
reg  m55;
integer n55;
integer x55;
wire c56 = `CP0_MON_I.rtu_cp0_fs_dirty_updt_dp;
reg  p56;
reg  m56;
integer n56;
integer x56;
wire [63:0] c57 = `CP0_MON_I.rtu_cp0_tval;
reg  [63:0] p57;
reg  [63:0] m57;
integer n57;
integer x57;
wire [7:0] c58 = `CP0_MON_I.rtu_cp0_vl;
reg  [7:0] p58;
reg  [7:0] m58;
integer n58;
integer x58;
wire c59 = `CP0_MON_I.rtu_cp0_vl_vld;
reg  p59;
reg  m59;
integer n59;
integer x59;
wire c60 = `CP0_MON_I.rtu_cp0_vs_dirty_updt;
reg  p60;
reg  m60;
integer n60;
integer x60;
wire c61 = `CP0_MON_I.rtu_cp0_vs_dirty_updt_dp;
reg  p61;
reg  m61;
integer n61;
integer x61;
wire [6:0] c62 = `CP0_MON_I.rtu_cp0_vstart;
reg  [6:0] p62;
reg  [6:0] m62;
integer n62;
integer x62;
wire c63 = `CP0_MON_I.rtu_cp0_vstart_vld;
reg  p63;
reg  m63;
integer n63;
integer x63;
wire c64 = `CP0_MON_I.rtu_cp0_vxsat;
reg  p64;
reg  m64;
integer n64;
integer x64;
wire c65 = `CP0_MON_I.rtu_cp0_vxsat_vld;
reg  p65;
reg  m65;
integer n65;
integer x65;
wire c66 = `CP0_MON_I.rtu_yy_xx_dbgon;
reg  p66;
reg  m66;
integer n66;
integer x66;
wire c67 = `CP0_MON_I.rtu_yy_xx_expt_int;
reg  p67;
reg  m67;
integer n67;
integer x67;
wire [4:0] c68 = `CP0_MON_I.rtu_yy_xx_expt_vec;
reg  [4:0] p68;
reg  [4:0] m68;
integer n68;
integer x68;
wire c69 = `CP0_MON_I.rtu_yy_xx_expt_vld;
reg  p69;
reg  m69;
integer n69;
integer x69;
wire c70 = `CP0_MON_I.rtu_yy_xx_flush;
reg  p70;
reg  m70;
integer n70;
integer x70;
wire [39:0] c71 = `CP0_MON_I.sysio_cp0_apb_base;
reg  [39:0] p71;
reg  [39:0] m71;
integer n71;
integer x71;
wire c72 = `CP0_MON_I.vidu_cp0_vid_fof_vld;
reg  p72;
reg  m72;
integer n72;
integer x72;
wire c73 = `CP0_MON_I.cp0_biu_icg_en;
reg  p73;
reg  m73;
integer n73;
integer x73;
wire [1:0] c74 = `CP0_MON_I.cp0_biu_lpmd_b;
reg  [1:0] p74;
reg  [1:0] m74;
integer n74;
integer x74;
wire [11:0] c75 = `CP0_MON_I.cp0_dtu_addr;
reg  [11:0] p75;
reg  [11:0] m75;
integer n75;
integer x75;
wire [5:0] c76 = `CP0_MON_I.cp0_dtu_debug_info;
reg  [5:0] p76;
reg  [5:0] m76;
integer n76;
integer x76;
wire c77 = `CP0_MON_I.cp0_dtu_icg_en;
reg  p77;
reg  m77;
integer n77;
integer x77;
wire c78 = `CP0_MON_I.cp0_dtu_mexpt_vld;
reg  p78;
reg  m78;
integer n78;
integer x78;
wire c79 = `CP0_MON_I.cp0_dtu_pcfifo_frz;
reg  p79;
reg  m79;
integer n79;
integer x79;
wire c80 = `CP0_MON_I.cp0_dtu_rreg;
reg  p80;
reg  m80;
integer n80;
integer x80;
wire [63:0] c81 = `CP0_MON_I.cp0_dtu_satp;
reg  [63:0] p81;
reg  [63:0] m81;
integer n81;
integer x81;
wire [63:0] c82 = `CP0_MON_I.cp0_dtu_wdata;
reg  [63:0] p82;
reg  [63:0] m82;
integer n82;
integer x82;
wire c83 = `CP0_MON_I.cp0_dtu_wreg;
reg  p83;
reg  m83;
integer n83;
integer x83;
wire c84 = `CP0_MON_I.cp0_hpcp_icg_en;
reg  p84;
reg  m84;
integer n84;
integer x84;
wire [11:0] c85 = `CP0_MON_I.cp0_hpcp_index;
reg  [11:0] p85;
reg  [11:0] m85;
integer n85;
integer x85;
wire c86 = `CP0_MON_I.cp0_hpcp_int_off_vld;
reg  p86;
reg  m86;
integer n86;
integer x86;
wire [31:0] c87 = `CP0_MON_I.cp0_hpcp_mcntwen;
reg  [31:0] p87;
reg  [31:0] m87;
integer n87;
integer x87;
wire c88 = `CP0_MON_I.cp0_hpcp_pmdm;
reg  p88;
reg  m88;
integer n88;
integer x88;
wire c89 = `CP0_MON_I.cp0_hpcp_pmds;
reg  p89;
reg  m89;
integer n89;
integer x89;
wire c90 = `CP0_MON_I.cp0_hpcp_pmdu;
reg  p90;
reg  m90;
integer n90;
integer x90;
wire c91 = `CP0_MON_I.cp0_hpcp_sync_stall_vld;
reg  p91;
reg  m91;
integer n91;
integer x91;
wire [63:0] c92 = `CP0_MON_I.cp0_hpcp_wdata;
reg  [63:0] p92;
reg  [63:0] m92;
integer n92;
integer x92;
wire c93 = `CP0_MON_I.cp0_hpcp_wreg;
reg  p93;
reg  m93;
integer n93;
integer x93;
wire c94 = `CP0_MON_I.cp0_idu_cskyee;
reg  p94;
reg  m94;
integer n94;
integer x94;
wire c95 = `CP0_MON_I.cp0_idu_dis_fence_in_dbg;
reg  p95;
reg  m95;
integer n95;
integer x95;
wire [2:0] c96 = `CP0_MON_I.cp0_idu_frm;
reg  [2:0] p96;
reg  [2:0] m96;
integer n96;
integer x96;
wire [1:0] c97 = `CP0_MON_I.cp0_idu_fs;
reg  [1:0] p97;
reg  [1:0] m97;
integer n97;
integer x97;
wire c98 = `CP0_MON_I.cp0_idu_icg_en;
reg  p98;
reg  m98;
integer n98;
integer x98;
wire c99 = `CP0_MON_I.cp0_idu_issue_stall;
reg  p99;
reg  m99;
integer n99;
integer x99;
wire c100 = `CP0_MON_I.cp0_idu_ucme;
reg  p100;
reg  m100;
integer n100;
integer x100;
wire c101 = `CP0_MON_I.cp0_idu_vill;
reg  p101;
reg  m101;
integer n101;
integer x101;
wire c102 = `CP0_MON_I.cp0_idu_vl_zero;
reg  p102;
reg  m102;
integer n102;
integer x102;
wire [1:0] c103 = `CP0_MON_I.cp0_idu_vlmul;
reg  [1:0] p103;
reg  [1:0] m103;
integer n103;
integer x103;
wire [1:0] c104 = `CP0_MON_I.cp0_idu_vs;
reg  [1:0] p104;
reg  [1:0] m104;
integer n104;
integer x104;
wire c105 = `CP0_MON_I.cp0_idu_vsetvl_dis_stall;
reg  p105;
reg  m105;
integer n105;
integer x105;
wire [1:0] c106 = `CP0_MON_I.cp0_idu_vsew;
reg  [1:0] p106;
reg  [1:0] m106;
integer n106;
integer x106;
wire [6:0] c107 = `CP0_MON_I.cp0_idu_vstart;
reg  [6:0] p107;
reg  [6:0] m107;
integer n107;
integer x107;
wire c108 = `CP0_MON_I.cp0_ifu_bht_en;
reg  p108;
reg  m108;
integer n108;
integer x108;
wire c109 = `CP0_MON_I.cp0_ifu_bht_inv;
reg  p109;
reg  m109;
integer n109;
integer x109;
wire c110 = `CP0_MON_I.cp0_ifu_btb_clr;
reg  p110;
reg  m110;
integer n110;
integer x110;
wire c111 = `CP0_MON_I.cp0_ifu_btb_en;
reg  p111;
reg  m111;
integer n111;
integer x111;
wire c112 = `CP0_MON_I.cp0_ifu_icache_en;
reg  p112;
reg  m112;
integer n112;
integer x112;
wire [63:0] c113 = `CP0_MON_I.cp0_ifu_icache_inv_addr;
reg  [63:0] p113;
reg  [63:0] m113;
integer n113;
integer x113;
wire c114 = `CP0_MON_I.cp0_ifu_icache_inv_req;
reg  p114;
reg  m114;
integer n114;
integer x114;
wire [1:0] c115 = `CP0_MON_I.cp0_ifu_icache_inv_type;
reg  [1:0] p115;
reg  [1:0] m115;
integer n115;
integer x115;
wire c116 = `CP0_MON_I.cp0_ifu_icache_pref_en;
reg  p116;
reg  m116;
integer n116;
integer x116;
wire [13:0] c117 = `CP0_MON_I.cp0_ifu_icache_read_index;
reg  [13:0] p117;
reg  [13:0] m117;
integer n117;
integer x117;
wire c118 = `CP0_MON_I.cp0_ifu_icache_read_req;
reg  p118;
reg  m118;
integer n118;
integer x118;
wire c119 = `CP0_MON_I.cp0_ifu_icache_read_tag;
reg  p119;
reg  m119;
integer n119;
integer x119;
wire c120 = `CP0_MON_I.cp0_ifu_icache_read_way;
reg  p120;
reg  m120;
integer n120;
integer x120;
wire c121 = `CP0_MON_I.cp0_ifu_icg_en;
reg  p121;
reg  m121;
integer n121;
integer x121;
wire c122 = `CP0_MON_I.cp0_ifu_in_lpmd;
reg  p122;
reg  m122;
integer n122;
integer x122;
wire c123 = `CP0_MON_I.cp0_ifu_iwpe;
reg  p123;
reg  m123;
integer n123;
integer x123;
wire c124 = `CP0_MON_I.cp0_ifu_lpmd_req;
reg  p124;
reg  m124;
integer n124;
integer x124;
wire c125 = `CP0_MON_I.cp0_ifu_ras_en;
reg  p125;
reg  m125;
integer n125;
integer x125;
wire c126 = `CP0_MON_I.cp0_ifu_rst_inv_done;
reg  p126;
reg  m126;
integer n126;
integer x126;
wire c127 = `CP0_MON_I.cp0_iu_icg_en;
reg  p127;
reg  m127;
integer n127;
integer x127;
wire [1:0] c128 = `CP0_MON_I.cp0_lsu_amr;
reg  [1:0] p128;
reg  [1:0] m128;
integer n128;
integer x128;
wire c129 = `CP0_MON_I.cp0_lsu_dcache_en;
reg  p129;
reg  m129;
integer n129;
integer x129;
wire [1:0] c130 = `CP0_MON_I.cp0_lsu_dcache_pref_dist;
reg  [1:0] p130;
reg  [1:0] m130;
integer n130;
integer x130;
wire c131 = `CP0_MON_I.cp0_lsu_dcache_pref_en;
reg  p131;
reg  m131;
integer n131;
integer x131;
wire [16:0] c132 = `CP0_MON_I.cp0_lsu_dcache_read_idx;
reg  [16:0] p132;
reg  [16:0] m132;
integer n132;
integer x132;
wire c133 = `CP0_MON_I.cp0_lsu_dcache_read_req;
reg  p133;
reg  m133;
integer n133;
integer x133;
wire c134 = `CP0_MON_I.cp0_lsu_dcache_read_type;
reg  p134;
reg  m134;
integer n134;
integer x134;
wire [1:0] c135 = `CP0_MON_I.cp0_lsu_dcache_read_way;
reg  [1:0] p135;
reg  [1:0] m135;
integer n135;
integer x135;
wire c136 = `CP0_MON_I.cp0_lsu_dcache_wa;
reg  p136;
reg  m136;
integer n136;
integer x136;
wire c137 = `CP0_MON_I.cp0_lsu_dcache_wb;
reg  p137;
reg  m137;
integer n137;
integer x137;
wire c138 = `CP0_MON_I.cp0_lsu_fence_req;
reg  p138;
reg  m138;
integer n138;
integer x138;
wire [63:0] c139 = `CP0_MON_I.cp0_lsu_icc_addr;
reg  [63:0] p139;
reg  [63:0] m139;
integer n139;
integer x139;
wire [1:0] c140 = `CP0_MON_I.cp0_lsu_icc_op;
reg  [1:0] p140;
reg  [1:0] m140;
integer n140;
integer x140;
wire c141 = `CP0_MON_I.cp0_lsu_icc_req;
reg  p141;
reg  m141;
integer n141;
integer x141;
wire [1:0] c142 = `CP0_MON_I.cp0_lsu_icc_type;
reg  [1:0] p142;
reg  [1:0] m142;
integer n142;
integer x142;
wire c143 = `CP0_MON_I.cp0_lsu_icg_en;
reg  p143;
reg  m143;
integer n143;
integer x143;
wire c144 = `CP0_MON_I.cp0_lsu_mm;
reg  p144;
reg  m144;
integer n144;
integer x144;
wire [1:0] c145 = `CP0_MON_I.cp0_lsu_mpp;
reg  [1:0] p145;
reg  [1:0] m145;
integer n145;
integer x145;
wire c146 = `CP0_MON_I.cp0_lsu_mprv;
reg  p146;
reg  m146;
integer n146;
integer x146;
wire c147 = `CP0_MON_I.cp0_lsu_sync_req;
reg  p147;
reg  m147;
integer n147;
integer x147;
wire c148 = `CP0_MON_I.cp0_lsu_we_en;
reg  p148;
reg  m148;
integer n148;
integer x148;
wire [11:0] c149 = `CP0_MON_I.cp0_mmu_addr;
reg  [11:0] p149;
reg  [11:0] m149;
integer n149;
integer x149;
wire c150 = `CP0_MON_I.cp0_mmu_icg_en;
reg  p150;
reg  m150;
integer n150;
integer x150;
wire c151 = `CP0_MON_I.cp0_mmu_lpmd_req;
reg  p151;
reg  m151;
integer n151;
integer x151;
wire c152 = `CP0_MON_I.cp0_mmu_maee;
reg  p152;
reg  m152;
integer n152;
integer x152;
wire c153 = `CP0_MON_I.cp0_mmu_mxr;
reg  p153;
reg  m153;
integer n153;
integer x153;
wire c154 = `CP0_MON_I.cp0_mmu_ptw_en;
reg  p154;
reg  m154;
integer n154;
integer x154;
wire [63:0] c155 = `CP0_MON_I.cp0_mmu_satp_data;
reg  [63:0] p155;
reg  [63:0] m155;
integer n155;
integer x155;
wire c156 = `CP0_MON_I.cp0_mmu_satp_wen;
reg  p156;
reg  m156;
integer n156;
integer x156;
wire c157 = `CP0_MON_I.cp0_mmu_sum;
reg  p157;
reg  m157;
integer n157;
integer x157;
wire c158 = `CP0_MON_I.cp0_mmu_tlb_all_inv;
reg  p158;
reg  m158;
integer n158;
integer x158;
wire [15:0] c159 = `CP0_MON_I.cp0_mmu_tlb_asid;
reg  [15:0] p159;
reg  [15:0] m159;
integer n159;
integer x159;
wire c160 = `CP0_MON_I.cp0_mmu_tlb_asid_all_inv;
reg  p160;
reg  m160;
integer n160;
integer x160;
wire [26:0] c161 = `CP0_MON_I.cp0_mmu_tlb_va;
reg  [26:0] p161;
reg  [26:0] m161;
integer n161;
integer x161;
wire c162 = `CP0_MON_I.cp0_mmu_tlb_va_all_inv;
reg  p162;
reg  m162;
integer n162;
integer x162;
wire c163 = `CP0_MON_I.cp0_mmu_tlb_va_asid_inv;
reg  p163;
reg  m163;
integer n163;
integer x163;
wire [63:0] c164 = `CP0_MON_I.cp0_mmu_wdata;
reg  [63:0] p164;
reg  [63:0] m164;
integer n164;
integer x164;
wire c165 = `CP0_MON_I.cp0_mmu_wreg;
reg  p165;
reg  m165;
integer n165;
integer x165;
wire [11:0] c166 = `CP0_MON_I.cp0_pmp_addr;
reg  [11:0] p166;
reg  [11:0] m166;
integer n166;
integer x166;
wire c167 = `CP0_MON_I.cp0_pmp_icg_en;
reg  p167;
reg  m167;
integer n167;
integer x167;
wire [63:0] c168 = `CP0_MON_I.cp0_pmp_wdata;
reg  [63:0] p168;
reg  [63:0] m168;
integer n168;
integer x168;
wire c169 = `CP0_MON_I.cp0_pmp_wreg;
reg  p169;
reg  m169;
integer n169;
integer x169;
wire c170 = `CP0_MON_I.cp0_rtu_ex1_chgflw;
reg  p170;
reg  m170;
integer n170;
integer x170;
wire [39:0] c171 = `CP0_MON_I.cp0_rtu_ex1_chgflw_pc;
reg  [39:0] p171;
reg  [39:0] m171;
integer n171;
integer x171;
wire c172 = `CP0_MON_I.cp0_rtu_ex1_cmplt;
reg  p172;
reg  m172;
integer n172;
integer x172;
wire c173 = `CP0_MON_I.cp0_rtu_ex1_cmplt_dp;
reg  p173;
reg  m173;
integer n173;
integer x173;
wire [39:0] c174 = `CP0_MON_I.cp0_rtu_ex1_expt_tval;
reg  [39:0] p174;
reg  [39:0] m174;
integer n174;
integer x174;
wire [4:0] c175 = `CP0_MON_I.cp0_rtu_ex1_expt_vec;
reg  [4:0] p175;
reg  [4:0] m175;
integer n175;
integer x175;
wire c176 = `CP0_MON_I.cp0_rtu_ex1_expt_vld;
reg  p176;
reg  m176;
integer n176;
integer x176;
wire c177 = `CP0_MON_I.cp0_rtu_ex1_flush;
reg  p177;
reg  m177;
integer n177;
integer x177;
wire [21:0] c178 = `CP0_MON_I.cp0_rtu_ex1_halt_info;
reg  [21:0] p178;
reg  [21:0] m178;
integer n178;
integer x178;
wire c179 = `CP0_MON_I.cp0_rtu_ex1_inst_dret;
reg  p179;
reg  m179;
integer n179;
integer x179;
wire c180 = `CP0_MON_I.cp0_rtu_ex1_inst_ebreak;
reg  p180;
reg  m180;
integer n180;
integer x180;
wire c181 = `CP0_MON_I.cp0_rtu_ex1_inst_len;
reg  p181;
reg  m181;
integer n181;
integer x181;
wire c182 = `CP0_MON_I.cp0_rtu_ex1_inst_mret;
reg  p182;
reg  m182;
integer n182;
integer x182;
wire c183 = `CP0_MON_I.cp0_rtu_ex1_inst_split;
reg  p183;
reg  m183;
integer n183;
integer x183;
wire c184 = `CP0_MON_I.cp0_rtu_ex1_inst_sret;
reg  p184;
reg  m184;
integer n184;
integer x184;
wire c185 = `CP0_MON_I.cp0_rtu_ex1_vs_dirty;
reg  p185;
reg  m185;
integer n185;
integer x185;
wire c186 = `CP0_MON_I.cp0_rtu_ex1_vs_dirty_dp;
reg  p186;
reg  m186;
integer n186;
integer x186;
wire [63:0] c187 = `CP0_MON_I.cp0_rtu_ex1_wb_data;
reg  [63:0] p187;
reg  [63:0] m187;
integer n187;
integer x187;
wire c188 = `CP0_MON_I.cp0_rtu_ex1_wb_dp;
reg  p188;
reg  m188;
integer n188;
integer x188;
wire [5:0] c189 = `CP0_MON_I.cp0_rtu_ex1_wb_preg;
reg  [5:0] p189;
reg  [5:0] m189;
integer n189;
integer x189;
wire c190 = `CP0_MON_I.cp0_rtu_ex1_wb_vld;
reg  p190;
reg  m190;
integer n190;
integer x190;
wire c191 = `CP0_MON_I.cp0_rtu_fence_idle;
reg  p191;
reg  m191;
integer n191;
integer x191;
wire c192 = `CP0_MON_I.cp0_rtu_icg_en;
reg  p192;
reg  m192;
integer n192;
integer x192;
wire c193 = `CP0_MON_I.cp0_rtu_in_lpmd;
reg  p193;
reg  m193;
integer n193;
integer x193;
wire [14:0] c194 = `CP0_MON_I.cp0_rtu_int_vld;
reg  [14:0] p194;
reg  [14:0] m194;
integer n194;
integer x194;
wire [39:0] c195 = `CP0_MON_I.cp0_rtu_trap_pc;
reg  [39:0] p195;
reg  [39:0] m195;
integer n195;
integer x195;
wire c196 = `CP0_MON_I.cp0_rtu_vstart_eq_0;
reg  p196;
reg  m196;
integer n196;
integer x196;
wire c197 = `CP0_MON_I.cp0_vpu_icg_en;
reg  p197;
reg  m197;
integer n197;
integer x197;
wire c198 = `CP0_MON_I.cp0_vpu_xx_bf16;
reg  p198;
reg  m198;
integer n198;
integer x198;
wire c199 = `CP0_MON_I.cp0_vpu_xx_dqnan;
reg  p199;
reg  m199;
integer n199;
integer x199;
wire [2:0] c200 = `CP0_MON_I.cp0_vpu_xx_rm;
reg  [2:0] p200;
reg  [2:0] m200;
integer n200;
integer x200;
wire [39:0] c201 = `CP0_MON_I.cp0_xx_mrvbr;
reg  [39:0] p201;
reg  [39:0] m201;
integer n201;
integer x201;
wire c202 = `CP0_MON_I.cp0_yy_clk_en;
reg  p202;
reg  m202;
integer n202;
integer x202;
wire [1:0] c203 = `CP0_MON_I.cp0_yy_priv_mode;
reg  [1:0] p203;
reg  [1:0] m203;
integer n203;
integer x203;

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
  p130 = 0; m130 = 0; n130 = 0; x130 = 0;
  p131 = 0; m131 = 0; n131 = 0; x131 = 0;
  p132 = 0; m132 = 0; n132 = 0; x132 = 0;
  p133 = 0; m133 = 0; n133 = 0; x133 = 0;
  p134 = 0; m134 = 0; n134 = 0; x134 = 0;
  p135 = 0; m135 = 0; n135 = 0; x135 = 0;
  p136 = 0; m136 = 0; n136 = 0; x136 = 0;
  p137 = 0; m137 = 0; n137 = 0; x137 = 0;
  p138 = 0; m138 = 0; n138 = 0; x138 = 0;
  p139 = 0; m139 = 0; n139 = 0; x139 = 0;
  p140 = 0; m140 = 0; n140 = 0; x140 = 0;
  p141 = 0; m141 = 0; n141 = 0; x141 = 0;
  p142 = 0; m142 = 0; n142 = 0; x142 = 0;
  p143 = 0; m143 = 0; n143 = 0; x143 = 0;
  p144 = 0; m144 = 0; n144 = 0; x144 = 0;
  p145 = 0; m145 = 0; n145 = 0; x145 = 0;
  p146 = 0; m146 = 0; n146 = 0; x146 = 0;
  p147 = 0; m147 = 0; n147 = 0; x147 = 0;
  p148 = 0; m148 = 0; n148 = 0; x148 = 0;
  p149 = 0; m149 = 0; n149 = 0; x149 = 0;
  p150 = 0; m150 = 0; n150 = 0; x150 = 0;
  p151 = 0; m151 = 0; n151 = 0; x151 = 0;
  p152 = 0; m152 = 0; n152 = 0; x152 = 0;
  p153 = 0; m153 = 0; n153 = 0; x153 = 0;
  p154 = 0; m154 = 0; n154 = 0; x154 = 0;
  p155 = 0; m155 = 0; n155 = 0; x155 = 0;
  p156 = 0; m156 = 0; n156 = 0; x156 = 0;
  p157 = 0; m157 = 0; n157 = 0; x157 = 0;
  p158 = 0; m158 = 0; n158 = 0; x158 = 0;
  p159 = 0; m159 = 0; n159 = 0; x159 = 0;
  p160 = 0; m160 = 0; n160 = 0; x160 = 0;
  p161 = 0; m161 = 0; n161 = 0; x161 = 0;
  p162 = 0; m162 = 0; n162 = 0; x162 = 0;
  p163 = 0; m163 = 0; n163 = 0; x163 = 0;
  p164 = 0; m164 = 0; n164 = 0; x164 = 0;
  p165 = 0; m165 = 0; n165 = 0; x165 = 0;
  p166 = 0; m166 = 0; n166 = 0; x166 = 0;
  p167 = 0; m167 = 0; n167 = 0; x167 = 0;
  p168 = 0; m168 = 0; n168 = 0; x168 = 0;
  p169 = 0; m169 = 0; n169 = 0; x169 = 0;
  p170 = 0; m170 = 0; n170 = 0; x170 = 0;
  p171 = 0; m171 = 0; n171 = 0; x171 = 0;
  p172 = 0; m172 = 0; n172 = 0; x172 = 0;
  p173 = 0; m173 = 0; n173 = 0; x173 = 0;
  p174 = 0; m174 = 0; n174 = 0; x174 = 0;
  p175 = 0; m175 = 0; n175 = 0; x175 = 0;
  p176 = 0; m176 = 0; n176 = 0; x176 = 0;
  p177 = 0; m177 = 0; n177 = 0; x177 = 0;
  p178 = 0; m178 = 0; n178 = 0; x178 = 0;
  p179 = 0; m179 = 0; n179 = 0; x179 = 0;
  p180 = 0; m180 = 0; n180 = 0; x180 = 0;
  p181 = 0; m181 = 0; n181 = 0; x181 = 0;
  p182 = 0; m182 = 0; n182 = 0; x182 = 0;
  p183 = 0; m183 = 0; n183 = 0; x183 = 0;
  p184 = 0; m184 = 0; n184 = 0; x184 = 0;
  p185 = 0; m185 = 0; n185 = 0; x185 = 0;
  p186 = 0; m186 = 0; n186 = 0; x186 = 0;
  p187 = 0; m187 = 0; n187 = 0; x187 = 0;
  p188 = 0; m188 = 0; n188 = 0; x188 = 0;
  p189 = 0; m189 = 0; n189 = 0; x189 = 0;
  p190 = 0; m190 = 0; n190 = 0; x190 = 0;
  p191 = 0; m191 = 0; n191 = 0; x191 = 0;
  p192 = 0; m192 = 0; n192 = 0; x192 = 0;
  p193 = 0; m193 = 0; n193 = 0; x193 = 0;
  p194 = 0; m194 = 0; n194 = 0; x194 = 0;
  p195 = 0; m195 = 0; n195 = 0; x195 = 0;
  p196 = 0; m196 = 0; n196 = 0; x196 = 0;
  p197 = 0; m197 = 0; n197 = 0; x197 = 0;
  p198 = 0; m198 = 0; n198 = 0; x198 = 0;
  p199 = 0; m199 = 0; n199 = 0; x199 = 0;
  p200 = 0; m200 = 0; n200 = 0; x200 = 0;
  p201 = 0; m201 = 0; n201 = 0; x201 = 0;
  p202 = 0; m202 = 0; n202 = 0; x202 = 0;
  p203 = 0; m203 = 0; n203 = 0; x203 = 0;
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
    if ($isunknown(c130)) x130 <= x130 + 1;
    if (armed && !$isunknown(c130) && !$isunknown(p130)) begin
      m130 <= m130 | (c130 ^ p130);
      if (c130 !== p130) n130 <= n130 + 1;
    end
    p130 <= c130;
    if ($isunknown(c131)) x131 <= x131 + 1;
    if (armed && !$isunknown(c131) && !$isunknown(p131)) begin
      m131 <= m131 | (c131 ^ p131);
      if (c131 !== p131) n131 <= n131 + 1;
    end
    p131 <= c131;
    if ($isunknown(c132)) x132 <= x132 + 1;
    if (armed && !$isunknown(c132) && !$isunknown(p132)) begin
      m132 <= m132 | (c132 ^ p132);
      if (c132 !== p132) n132 <= n132 + 1;
    end
    p132 <= c132;
    if ($isunknown(c133)) x133 <= x133 + 1;
    if (armed && !$isunknown(c133) && !$isunknown(p133)) begin
      m133 <= m133 | (c133 ^ p133);
      if (c133 !== p133) n133 <= n133 + 1;
    end
    p133 <= c133;
    if ($isunknown(c134)) x134 <= x134 + 1;
    if (armed && !$isunknown(c134) && !$isunknown(p134)) begin
      m134 <= m134 | (c134 ^ p134);
      if (c134 !== p134) n134 <= n134 + 1;
    end
    p134 <= c134;
    if ($isunknown(c135)) x135 <= x135 + 1;
    if (armed && !$isunknown(c135) && !$isunknown(p135)) begin
      m135 <= m135 | (c135 ^ p135);
      if (c135 !== p135) n135 <= n135 + 1;
    end
    p135 <= c135;
    if ($isunknown(c136)) x136 <= x136 + 1;
    if (armed && !$isunknown(c136) && !$isunknown(p136)) begin
      m136 <= m136 | (c136 ^ p136);
      if (c136 !== p136) n136 <= n136 + 1;
    end
    p136 <= c136;
    if ($isunknown(c137)) x137 <= x137 + 1;
    if (armed && !$isunknown(c137) && !$isunknown(p137)) begin
      m137 <= m137 | (c137 ^ p137);
      if (c137 !== p137) n137 <= n137 + 1;
    end
    p137 <= c137;
    if ($isunknown(c138)) x138 <= x138 + 1;
    if (armed && !$isunknown(c138) && !$isunknown(p138)) begin
      m138 <= m138 | (c138 ^ p138);
      if (c138 !== p138) n138 <= n138 + 1;
    end
    p138 <= c138;
    if ($isunknown(c139)) x139 <= x139 + 1;
    if (armed && !$isunknown(c139) && !$isunknown(p139)) begin
      m139 <= m139 | (c139 ^ p139);
      if (c139 !== p139) n139 <= n139 + 1;
    end
    p139 <= c139;
    if ($isunknown(c140)) x140 <= x140 + 1;
    if (armed && !$isunknown(c140) && !$isunknown(p140)) begin
      m140 <= m140 | (c140 ^ p140);
      if (c140 !== p140) n140 <= n140 + 1;
    end
    p140 <= c140;
    if ($isunknown(c141)) x141 <= x141 + 1;
    if (armed && !$isunknown(c141) && !$isunknown(p141)) begin
      m141 <= m141 | (c141 ^ p141);
      if (c141 !== p141) n141 <= n141 + 1;
    end
    p141 <= c141;
    if ($isunknown(c142)) x142 <= x142 + 1;
    if (armed && !$isunknown(c142) && !$isunknown(p142)) begin
      m142 <= m142 | (c142 ^ p142);
      if (c142 !== p142) n142 <= n142 + 1;
    end
    p142 <= c142;
    if ($isunknown(c143)) x143 <= x143 + 1;
    if (armed && !$isunknown(c143) && !$isunknown(p143)) begin
      m143 <= m143 | (c143 ^ p143);
      if (c143 !== p143) n143 <= n143 + 1;
    end
    p143 <= c143;
    if ($isunknown(c144)) x144 <= x144 + 1;
    if (armed && !$isunknown(c144) && !$isunknown(p144)) begin
      m144 <= m144 | (c144 ^ p144);
      if (c144 !== p144) n144 <= n144 + 1;
    end
    p144 <= c144;
    if ($isunknown(c145)) x145 <= x145 + 1;
    if (armed && !$isunknown(c145) && !$isunknown(p145)) begin
      m145 <= m145 | (c145 ^ p145);
      if (c145 !== p145) n145 <= n145 + 1;
    end
    p145 <= c145;
    if ($isunknown(c146)) x146 <= x146 + 1;
    if (armed && !$isunknown(c146) && !$isunknown(p146)) begin
      m146 <= m146 | (c146 ^ p146);
      if (c146 !== p146) n146 <= n146 + 1;
    end
    p146 <= c146;
    if ($isunknown(c147)) x147 <= x147 + 1;
    if (armed && !$isunknown(c147) && !$isunknown(p147)) begin
      m147 <= m147 | (c147 ^ p147);
      if (c147 !== p147) n147 <= n147 + 1;
    end
    p147 <= c147;
    if ($isunknown(c148)) x148 <= x148 + 1;
    if (armed && !$isunknown(c148) && !$isunknown(p148)) begin
      m148 <= m148 | (c148 ^ p148);
      if (c148 !== p148) n148 <= n148 + 1;
    end
    p148 <= c148;
    if ($isunknown(c149)) x149 <= x149 + 1;
    if (armed && !$isunknown(c149) && !$isunknown(p149)) begin
      m149 <= m149 | (c149 ^ p149);
      if (c149 !== p149) n149 <= n149 + 1;
    end
    p149 <= c149;
    if ($isunknown(c150)) x150 <= x150 + 1;
    if (armed && !$isunknown(c150) && !$isunknown(p150)) begin
      m150 <= m150 | (c150 ^ p150);
      if (c150 !== p150) n150 <= n150 + 1;
    end
    p150 <= c150;
    if ($isunknown(c151)) x151 <= x151 + 1;
    if (armed && !$isunknown(c151) && !$isunknown(p151)) begin
      m151 <= m151 | (c151 ^ p151);
      if (c151 !== p151) n151 <= n151 + 1;
    end
    p151 <= c151;
    if ($isunknown(c152)) x152 <= x152 + 1;
    if (armed && !$isunknown(c152) && !$isunknown(p152)) begin
      m152 <= m152 | (c152 ^ p152);
      if (c152 !== p152) n152 <= n152 + 1;
    end
    p152 <= c152;
    if ($isunknown(c153)) x153 <= x153 + 1;
    if (armed && !$isunknown(c153) && !$isunknown(p153)) begin
      m153 <= m153 | (c153 ^ p153);
      if (c153 !== p153) n153 <= n153 + 1;
    end
    p153 <= c153;
    if ($isunknown(c154)) x154 <= x154 + 1;
    if (armed && !$isunknown(c154) && !$isunknown(p154)) begin
      m154 <= m154 | (c154 ^ p154);
      if (c154 !== p154) n154 <= n154 + 1;
    end
    p154 <= c154;
    if ($isunknown(c155)) x155 <= x155 + 1;
    if (armed && !$isunknown(c155) && !$isunknown(p155)) begin
      m155 <= m155 | (c155 ^ p155);
      if (c155 !== p155) n155 <= n155 + 1;
    end
    p155 <= c155;
    if ($isunknown(c156)) x156 <= x156 + 1;
    if (armed && !$isunknown(c156) && !$isunknown(p156)) begin
      m156 <= m156 | (c156 ^ p156);
      if (c156 !== p156) n156 <= n156 + 1;
    end
    p156 <= c156;
    if ($isunknown(c157)) x157 <= x157 + 1;
    if (armed && !$isunknown(c157) && !$isunknown(p157)) begin
      m157 <= m157 | (c157 ^ p157);
      if (c157 !== p157) n157 <= n157 + 1;
    end
    p157 <= c157;
    if ($isunknown(c158)) x158 <= x158 + 1;
    if (armed && !$isunknown(c158) && !$isunknown(p158)) begin
      m158 <= m158 | (c158 ^ p158);
      if (c158 !== p158) n158 <= n158 + 1;
    end
    p158 <= c158;
    if ($isunknown(c159)) x159 <= x159 + 1;
    if (armed && !$isunknown(c159) && !$isunknown(p159)) begin
      m159 <= m159 | (c159 ^ p159);
      if (c159 !== p159) n159 <= n159 + 1;
    end
    p159 <= c159;
    if ($isunknown(c160)) x160 <= x160 + 1;
    if (armed && !$isunknown(c160) && !$isunknown(p160)) begin
      m160 <= m160 | (c160 ^ p160);
      if (c160 !== p160) n160 <= n160 + 1;
    end
    p160 <= c160;
    if ($isunknown(c161)) x161 <= x161 + 1;
    if (armed && !$isunknown(c161) && !$isunknown(p161)) begin
      m161 <= m161 | (c161 ^ p161);
      if (c161 !== p161) n161 <= n161 + 1;
    end
    p161 <= c161;
    if ($isunknown(c162)) x162 <= x162 + 1;
    if (armed && !$isunknown(c162) && !$isunknown(p162)) begin
      m162 <= m162 | (c162 ^ p162);
      if (c162 !== p162) n162 <= n162 + 1;
    end
    p162 <= c162;
    if ($isunknown(c163)) x163 <= x163 + 1;
    if (armed && !$isunknown(c163) && !$isunknown(p163)) begin
      m163 <= m163 | (c163 ^ p163);
      if (c163 !== p163) n163 <= n163 + 1;
    end
    p163 <= c163;
    if ($isunknown(c164)) x164 <= x164 + 1;
    if (armed && !$isunknown(c164) && !$isunknown(p164)) begin
      m164 <= m164 | (c164 ^ p164);
      if (c164 !== p164) n164 <= n164 + 1;
    end
    p164 <= c164;
    if ($isunknown(c165)) x165 <= x165 + 1;
    if (armed && !$isunknown(c165) && !$isunknown(p165)) begin
      m165 <= m165 | (c165 ^ p165);
      if (c165 !== p165) n165 <= n165 + 1;
    end
    p165 <= c165;
    if ($isunknown(c166)) x166 <= x166 + 1;
    if (armed && !$isunknown(c166) && !$isunknown(p166)) begin
      m166 <= m166 | (c166 ^ p166);
      if (c166 !== p166) n166 <= n166 + 1;
    end
    p166 <= c166;
    if ($isunknown(c167)) x167 <= x167 + 1;
    if (armed && !$isunknown(c167) && !$isunknown(p167)) begin
      m167 <= m167 | (c167 ^ p167);
      if (c167 !== p167) n167 <= n167 + 1;
    end
    p167 <= c167;
    if ($isunknown(c168)) x168 <= x168 + 1;
    if (armed && !$isunknown(c168) && !$isunknown(p168)) begin
      m168 <= m168 | (c168 ^ p168);
      if (c168 !== p168) n168 <= n168 + 1;
    end
    p168 <= c168;
    if ($isunknown(c169)) x169 <= x169 + 1;
    if (armed && !$isunknown(c169) && !$isunknown(p169)) begin
      m169 <= m169 | (c169 ^ p169);
      if (c169 !== p169) n169 <= n169 + 1;
    end
    p169 <= c169;
    if ($isunknown(c170)) x170 <= x170 + 1;
    if (armed && !$isunknown(c170) && !$isunknown(p170)) begin
      m170 <= m170 | (c170 ^ p170);
      if (c170 !== p170) n170 <= n170 + 1;
    end
    p170 <= c170;
    if ($isunknown(c171)) x171 <= x171 + 1;
    if (armed && !$isunknown(c171) && !$isunknown(p171)) begin
      m171 <= m171 | (c171 ^ p171);
      if (c171 !== p171) n171 <= n171 + 1;
    end
    p171 <= c171;
    if ($isunknown(c172)) x172 <= x172 + 1;
    if (armed && !$isunknown(c172) && !$isunknown(p172)) begin
      m172 <= m172 | (c172 ^ p172);
      if (c172 !== p172) n172 <= n172 + 1;
    end
    p172 <= c172;
    if ($isunknown(c173)) x173 <= x173 + 1;
    if (armed && !$isunknown(c173) && !$isunknown(p173)) begin
      m173 <= m173 | (c173 ^ p173);
      if (c173 !== p173) n173 <= n173 + 1;
    end
    p173 <= c173;
    if ($isunknown(c174)) x174 <= x174 + 1;
    if (armed && !$isunknown(c174) && !$isunknown(p174)) begin
      m174 <= m174 | (c174 ^ p174);
      if (c174 !== p174) n174 <= n174 + 1;
    end
    p174 <= c174;
    if ($isunknown(c175)) x175 <= x175 + 1;
    if (armed && !$isunknown(c175) && !$isunknown(p175)) begin
      m175 <= m175 | (c175 ^ p175);
      if (c175 !== p175) n175 <= n175 + 1;
    end
    p175 <= c175;
    if ($isunknown(c176)) x176 <= x176 + 1;
    if (armed && !$isunknown(c176) && !$isunknown(p176)) begin
      m176 <= m176 | (c176 ^ p176);
      if (c176 !== p176) n176 <= n176 + 1;
    end
    p176 <= c176;
    if ($isunknown(c177)) x177 <= x177 + 1;
    if (armed && !$isunknown(c177) && !$isunknown(p177)) begin
      m177 <= m177 | (c177 ^ p177);
      if (c177 !== p177) n177 <= n177 + 1;
    end
    p177 <= c177;
    if ($isunknown(c178)) x178 <= x178 + 1;
    if (armed && !$isunknown(c178) && !$isunknown(p178)) begin
      m178 <= m178 | (c178 ^ p178);
      if (c178 !== p178) n178 <= n178 + 1;
    end
    p178 <= c178;
    if ($isunknown(c179)) x179 <= x179 + 1;
    if (armed && !$isunknown(c179) && !$isunknown(p179)) begin
      m179 <= m179 | (c179 ^ p179);
      if (c179 !== p179) n179 <= n179 + 1;
    end
    p179 <= c179;
    if ($isunknown(c180)) x180 <= x180 + 1;
    if (armed && !$isunknown(c180) && !$isunknown(p180)) begin
      m180 <= m180 | (c180 ^ p180);
      if (c180 !== p180) n180 <= n180 + 1;
    end
    p180 <= c180;
    if ($isunknown(c181)) x181 <= x181 + 1;
    if (armed && !$isunknown(c181) && !$isunknown(p181)) begin
      m181 <= m181 | (c181 ^ p181);
      if (c181 !== p181) n181 <= n181 + 1;
    end
    p181 <= c181;
    if ($isunknown(c182)) x182 <= x182 + 1;
    if (armed && !$isunknown(c182) && !$isunknown(p182)) begin
      m182 <= m182 | (c182 ^ p182);
      if (c182 !== p182) n182 <= n182 + 1;
    end
    p182 <= c182;
    if ($isunknown(c183)) x183 <= x183 + 1;
    if (armed && !$isunknown(c183) && !$isunknown(p183)) begin
      m183 <= m183 | (c183 ^ p183);
      if (c183 !== p183) n183 <= n183 + 1;
    end
    p183 <= c183;
    if ($isunknown(c184)) x184 <= x184 + 1;
    if (armed && !$isunknown(c184) && !$isunknown(p184)) begin
      m184 <= m184 | (c184 ^ p184);
      if (c184 !== p184) n184 <= n184 + 1;
    end
    p184 <= c184;
    if ($isunknown(c185)) x185 <= x185 + 1;
    if (armed && !$isunknown(c185) && !$isunknown(p185)) begin
      m185 <= m185 | (c185 ^ p185);
      if (c185 !== p185) n185 <= n185 + 1;
    end
    p185 <= c185;
    if ($isunknown(c186)) x186 <= x186 + 1;
    if (armed && !$isunknown(c186) && !$isunknown(p186)) begin
      m186 <= m186 | (c186 ^ p186);
      if (c186 !== p186) n186 <= n186 + 1;
    end
    p186 <= c186;
    if ($isunknown(c187)) x187 <= x187 + 1;
    if (armed && !$isunknown(c187) && !$isunknown(p187)) begin
      m187 <= m187 | (c187 ^ p187);
      if (c187 !== p187) n187 <= n187 + 1;
    end
    p187 <= c187;
    if ($isunknown(c188)) x188 <= x188 + 1;
    if (armed && !$isunknown(c188) && !$isunknown(p188)) begin
      m188 <= m188 | (c188 ^ p188);
      if (c188 !== p188) n188 <= n188 + 1;
    end
    p188 <= c188;
    if ($isunknown(c189)) x189 <= x189 + 1;
    if (armed && !$isunknown(c189) && !$isunknown(p189)) begin
      m189 <= m189 | (c189 ^ p189);
      if (c189 !== p189) n189 <= n189 + 1;
    end
    p189 <= c189;
    if ($isunknown(c190)) x190 <= x190 + 1;
    if (armed && !$isunknown(c190) && !$isunknown(p190)) begin
      m190 <= m190 | (c190 ^ p190);
      if (c190 !== p190) n190 <= n190 + 1;
    end
    p190 <= c190;
    if ($isunknown(c191)) x191 <= x191 + 1;
    if (armed && !$isunknown(c191) && !$isunknown(p191)) begin
      m191 <= m191 | (c191 ^ p191);
      if (c191 !== p191) n191 <= n191 + 1;
    end
    p191 <= c191;
    if ($isunknown(c192)) x192 <= x192 + 1;
    if (armed && !$isunknown(c192) && !$isunknown(p192)) begin
      m192 <= m192 | (c192 ^ p192);
      if (c192 !== p192) n192 <= n192 + 1;
    end
    p192 <= c192;
    if ($isunknown(c193)) x193 <= x193 + 1;
    if (armed && !$isunknown(c193) && !$isunknown(p193)) begin
      m193 <= m193 | (c193 ^ p193);
      if (c193 !== p193) n193 <= n193 + 1;
    end
    p193 <= c193;
    if ($isunknown(c194)) x194 <= x194 + 1;
    if (armed && !$isunknown(c194) && !$isunknown(p194)) begin
      m194 <= m194 | (c194 ^ p194);
      if (c194 !== p194) n194 <= n194 + 1;
    end
    p194 <= c194;
    if ($isunknown(c195)) x195 <= x195 + 1;
    if (armed && !$isunknown(c195) && !$isunknown(p195)) begin
      m195 <= m195 | (c195 ^ p195);
      if (c195 !== p195) n195 <= n195 + 1;
    end
    p195 <= c195;
    if ($isunknown(c196)) x196 <= x196 + 1;
    if (armed && !$isunknown(c196) && !$isunknown(p196)) begin
      m196 <= m196 | (c196 ^ p196);
      if (c196 !== p196) n196 <= n196 + 1;
    end
    p196 <= c196;
    if ($isunknown(c197)) x197 <= x197 + 1;
    if (armed && !$isunknown(c197) && !$isunknown(p197)) begin
      m197 <= m197 | (c197 ^ p197);
      if (c197 !== p197) n197 <= n197 + 1;
    end
    p197 <= c197;
    if ($isunknown(c198)) x198 <= x198 + 1;
    if (armed && !$isunknown(c198) && !$isunknown(p198)) begin
      m198 <= m198 | (c198 ^ p198);
      if (c198 !== p198) n198 <= n198 + 1;
    end
    p198 <= c198;
    if ($isunknown(c199)) x199 <= x199 + 1;
    if (armed && !$isunknown(c199) && !$isunknown(p199)) begin
      m199 <= m199 | (c199 ^ p199);
      if (c199 !== p199) n199 <= n199 + 1;
    end
    p199 <= c199;
    if ($isunknown(c200)) x200 <= x200 + 1;
    if (armed && !$isunknown(c200) && !$isunknown(p200)) begin
      m200 <= m200 | (c200 ^ p200);
      if (c200 !== p200) n200 <= n200 + 1;
    end
    p200 <= c200;
    if ($isunknown(c201)) x201 <= x201 + 1;
    if (armed && !$isunknown(c201) && !$isunknown(p201)) begin
      m201 <= m201 | (c201 ^ p201);
      if (c201 !== p201) n201 <= n201 + 1;
    end
    p201 <= c201;
    if ($isunknown(c202)) x202 <= x202 + 1;
    if (armed && !$isunknown(c202) && !$isunknown(p202)) begin
      m202 <= m202 | (c202 ^ p202);
      if (c202 !== p202) n202 <= n202 + 1;
    end
    p202 <= c202;
    if ($isunknown(c203)) x203 <= x203 + 1;
    if (armed && !$isunknown(c203) && !$isunknown(p203)) begin
      m203 <= m203 | (c203 ^ p203);
      if (c203 !== p203) n203 <= n203 + 1;
    end
    p203 <= c203;
  end
end

final begin
  FH = $fopen("cp0_toggle.report", "w");
  $fwrite(FH, "CP0 port toggle report -- instance:\n");
  $fwrite(FH, "  tb.x_soc.x_cpu_sub_system_axi.x_c906_wrapper.x_cpu_top.x_aq_top_0.x_aq_core.x_aq_cp0_top\n\n");
  $fwrite(FH, "port                               dir  width  bits_tog  tog_events  x_cycles\n");
  $fwrite(FH, "----------------------------------------------------------------------------\n");
  n_tog = 0;
  n_xseen = 0;
  $fwrite(FH, "biu_cp0_coreid                     in      3 %0d %0d %0d   [dead]\n", ones({125'b0, m0}), n0, x0);
  $fwrite(FH, "biu_cp0_me_int                     in      1 %0d %0d %0d\n", ones({127'b0, m1}), n1, x1);
  if (|m1) n_tog = n_tog + 1;
  if (x1 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "biu_cp0_ms_int                     in      1 %0d %0d %0d\n", ones({127'b0, m2}), n2, x2);
  if (|m2) n_tog = n_tog + 1;
  if (x2 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "biu_cp0_mt_int                     in      1 %0d %0d %0d\n", ones({127'b0, m3}), n3, x3);
  if (|m3) n_tog = n_tog + 1;
  if (x3 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "biu_cp0_rvba                       in     40 %0d %0d %0d   [dead]\n", ones({88'b0, m4}), n4, x4);
  $fwrite(FH, "biu_cp0_se_int                     in      1 %0d %0d %0d\n", ones({127'b0, m5}), n5, x5);
  if (|m5) n_tog = n_tog + 1;
  if (x5 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "biu_cp0_ss_int                     in      1 %0d %0d %0d\n", ones({127'b0, m6}), n6, x6);
  if (|m6) n_tog = n_tog + 1;
  if (x6 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "biu_cp0_st_int                     in      1 %0d %0d %0d\n", ones({127'b0, m7}), n7, x7);
  if (|m7) n_tog = n_tog + 1;
  if (x7 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cpurst_b                           in      1 %0d %0d %0d   [infra]\n", ones({127'b0, m8}), n8, x8);
  $fwrite(FH, "dtu_cp0_dcsr_mprven                in      1 %0d %0d %0d\n", ones({127'b0, m9}), n9, x9);
  if (|m9) n_tog = n_tog + 1;
  if (x9 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "dtu_cp0_dcsr_prv                   in      2 %0d %0d %0d\n", ones({126'b0, m10}), n10, x10);
  if (|m10) n_tog = n_tog + 1;
  if (x10 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "dtu_cp0_rdata                      in     64 %0d %0d %0d\n", ones({64'b0, m11}), n11, x11);
  if (|m11) n_tog = n_tog + 1;
  if (x11 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "dtu_cp0_wake_up                    in      1 %0d %0d %0d\n", ones({127'b0, m12}), n12, x12);
  if (|m12) n_tog = n_tog + 1;
  if (x12 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "forever_cpuclk                     in      1 %0d %0d %0d   [infra]\n", ones({127'b0, m13}), n13, x13);
  $fwrite(FH, "hpcp_cp0_data                      in     64 %0d %0d %0d\n", ones({64'b0, m14}), n14, x14);
  if (|m14) n_tog = n_tog + 1;
  if (x14 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "hpcp_cp0_int_vld                   in      1 %0d %0d %0d\n", ones({127'b0, m15}), n15, x15);
  if (|m15) n_tog = n_tog + 1;
  if (x15 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "hpcp_cp0_sce                       in      1 %0d %0d %0d\n", ones({127'b0, m16}), n16, x16);
  if (|m16) n_tog = n_tog + 1;
  if (x16 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_dp_sel                 in      1 %0d %0d %0d\n", ones({127'b0, m17}), n17, x17);
  if (|m17) n_tog = n_tog + 1;
  if (x17 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_dst0_reg               in      6 %0d %0d %0d\n", ones({122'b0, m18}), n18, x18);
  if (|m18) n_tog = n_tog + 1;
  if (x18 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_expt_acc_error         in      1 %0d %0d %0d\n", ones({127'b0, m19}), n19, x19);
  if (|m19) n_tog = n_tog + 1;
  if (x19 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_expt_high              in      1 %0d %0d %0d\n", ones({127'b0, m20}), n20, x20);
  if (|m20) n_tog = n_tog + 1;
  if (x20 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_expt_illegal           in      1 %0d %0d %0d\n", ones({127'b0, m21}), n21, x21);
  if (|m21) n_tog = n_tog + 1;
  if (x21 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_expt_page_fault        in      1 %0d %0d %0d\n", ones({127'b0, m22}), n22, x22);
  if (|m22) n_tog = n_tog + 1;
  if (x22 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_func                   in     20 %0d %0d %0d\n", ones({108'b0, m23}), n23, x23);
  if (|m23) n_tog = n_tog + 1;
  if (x23 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_gateclk_sel            in      1 %0d %0d %0d\n", ones({127'b0, m24}), n24, x24);
  if (|m24) n_tog = n_tog + 1;
  if (x24 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_halt_info              in     22 %0d %0d %0d\n", ones({106'b0, m25}), n25, x25);
  if (|m25) n_tog = n_tog + 1;
  if (x25 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_length                 in      1 %0d %0d %0d\n", ones({127'b0, m26}), n26, x26);
  if (|m26) n_tog = n_tog + 1;
  if (x26 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_opcode                 in     32 %0d %0d %0d\n", ones({96'b0, m27}), n27, x27);
  if (|m27) n_tog = n_tog + 1;
  if (x27 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_sel                    in      1 %0d %0d %0d\n", ones({127'b0, m28}), n28, x28);
  if (|m28) n_tog = n_tog + 1;
  if (x28 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_split                  in      1 %0d %0d %0d\n", ones({127'b0, m29}), n29, x29);
  if (|m29) n_tog = n_tog + 1;
  if (x29 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_src0_data              in     64 %0d %0d %0d\n", ones({64'b0, m30}), n30, x30);
  if (|m30) n_tog = n_tog + 1;
  if (x30 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "idu_cp0_ex1_src1_data              in     64 %0d %0d %0d\n", ones({64'b0, m31}), n31, x31);
  if (|m31) n_tog = n_tog + 1;
  if (x31 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_bht_inv_done               in      1 %0d %0d %0d\n", ones({127'b0, m32}), n32, x32);
  if (|m32) n_tog = n_tog + 1;
  if (x32 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_icache_inv_done            in      1 %0d %0d %0d\n", ones({127'b0, m33}), n33, x33);
  if (|m33) n_tog = n_tog + 1;
  if (x33 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_icache_read_data           in    128 %0d %0d %0d\n", ones({m34}), n34, x34);
  if (|m34) n_tog = n_tog + 1;
  if (x34 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_icache_read_data_vld       in      1 %0d %0d %0d\n", ones({127'b0, m35}), n35, x35);
  if (|m35) n_tog = n_tog + 1;
  if (x35 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_rst_inv_req                in      1 %0d %0d %0d\n", ones({127'b0, m36}), n36, x36);
  if (|m36) n_tog = n_tog + 1;
  if (x36 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_cp0_warm_up                    in      1 %0d %0d %0d\n", ones({127'b0, m37}), n37, x37);
  if (|m37) n_tog = n_tog + 1;
  if (x37 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "ifu_yy_xx_no_op                    in      1 %0d %0d %0d\n", ones({127'b0, m38}), n38, x38);
  if (|m38) n_tog = n_tog + 1;
  if (x38 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "iu_cp0_ex1_cur_pc                  in     40 %0d %0d %0d\n", ones({88'b0, m39}), n39, x39);
  if (|m39) n_tog = n_tog + 1;
  if (x39 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "lsu_cp0_dcache_read_data           in    128 %0d %0d %0d\n", ones({m40}), n40, x40);
  if (|m40) n_tog = n_tog + 1;
  if (x40 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "lsu_cp0_dcache_read_data_vld       in      1 %0d %0d %0d\n", ones({127'b0, m41}), n41, x41);
  if (|m41) n_tog = n_tog + 1;
  if (x41 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "lsu_cp0_fence_ack                  in      1 %0d %0d %0d\n", ones({127'b0, m42}), n42, x42);
  if (|m42) n_tog = n_tog + 1;
  if (x42 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "lsu_cp0_icc_done                   in      1 %0d %0d %0d\n", ones({127'b0, m43}), n43, x43);
  if (|m43) n_tog = n_tog + 1;
  if (x43 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "lsu_cp0_sync_ack                   in      1 %0d %0d %0d\n", ones({127'b0, m44}), n44, x44);
  if (|m44) n_tog = n_tog + 1;
  if (x44 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "mmu_cp0_cmplt                      in      1 %0d %0d %0d\n", ones({127'b0, m45}), n45, x45);
  if (|m45) n_tog = n_tog + 1;
  if (x45 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "mmu_cp0_data                       in     64 %0d %0d %0d\n", ones({64'b0, m46}), n46, x46);
  if (|m46) n_tog = n_tog + 1;
  if (x46 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "mmu_cp0_tlb_inv_done               in      1 %0d %0d %0d\n", ones({127'b0, m47}), n47, x47);
  if (|m47) n_tog = n_tog + 1;
  if (x47 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "mmu_yy_xx_no_op                    in      1 %0d %0d %0d\n", ones({127'b0, m48}), n48, x48);
  if (|m48) n_tog = n_tog + 1;
  if (x48 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "pad_yy_icg_scan_en                 in      1 %0d %0d %0d   [infra]\n", ones({127'b0, m49}), n49, x49);
  $fwrite(FH, "pmp_cp0_data                       in     64 %0d %0d %0d\n", ones({64'b0, m50}), n50, x50);
  if (|m50) n_tog = n_tog + 1;
  if (x50 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_cp0_epc                        in     64 %0d %0d %0d\n", ones({64'b0, m51}), n51, x51);
  if (|m51) n_tog = n_tog + 1;
  if (x51 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_cp0_exit_debug                 in      1 %0d %0d %0d\n", ones({127'b0, m52}), n52, x52);
  if (|m52) n_tog = n_tog + 1;
  if (x52 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_cp0_fflags                     in      5 %0d %0d %0d\n", ones({123'b0, m53}), n53, x53);
  if (|m53) n_tog = n_tog + 1;
  if (x53 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_cp0_fflags_updt                in      1 %0d %0d %0d\n", ones({127'b0, m54}), n54, x54);
  if (|m54) n_tog = n_tog + 1;
  if (x54 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_cp0_fs_dirty_updt              in      1 %0d %0d %0d\n", ones({127'b0, m55}), n55, x55);
  if (|m55) n_tog = n_tog + 1;
  if (x55 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_cp0_fs_dirty_updt_dp           in      1 %0d %0d %0d\n", ones({127'b0, m56}), n56, x56);
  if (|m56) n_tog = n_tog + 1;
  if (x56 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_cp0_tval                       in     64 %0d %0d %0d\n", ones({64'b0, m57}), n57, x57);
  if (|m57) n_tog = n_tog + 1;
  if (x57 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_cp0_vl                         in      8 %0d %0d %0d   [dead]\n", ones({120'b0, m58}), n58, x58);
  $fwrite(FH, "rtu_cp0_vl_vld                     in      1 %0d %0d %0d   [dead]\n", ones({127'b0, m59}), n59, x59);
  $fwrite(FH, "rtu_cp0_vs_dirty_updt              in      1 %0d %0d %0d   [dead]\n", ones({127'b0, m60}), n60, x60);
  $fwrite(FH, "rtu_cp0_vs_dirty_updt_dp           in      1 %0d %0d %0d   [dead]\n", ones({127'b0, m61}), n61, x61);
  $fwrite(FH, "rtu_cp0_vstart                     in      7 %0d %0d %0d   [dead]\n", ones({121'b0, m62}), n62, x62);
  $fwrite(FH, "rtu_cp0_vstart_vld                 in      1 %0d %0d %0d   [dead]\n", ones({127'b0, m63}), n63, x63);
  $fwrite(FH, "rtu_cp0_vxsat                      in      1 %0d %0d %0d   [dead]\n", ones({127'b0, m64}), n64, x64);
  $fwrite(FH, "rtu_cp0_vxsat_vld                  in      1 %0d %0d %0d\n", ones({127'b0, m65}), n65, x65);
  if (|m65) n_tog = n_tog + 1;
  if (x65 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_yy_xx_dbgon                    in      1 %0d %0d %0d\n", ones({127'b0, m66}), n66, x66);
  if (|m66) n_tog = n_tog + 1;
  if (x66 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_yy_xx_expt_int                 in      1 %0d %0d %0d\n", ones({127'b0, m67}), n67, x67);
  if (|m67) n_tog = n_tog + 1;
  if (x67 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_yy_xx_expt_vec                 in      5 %0d %0d %0d\n", ones({123'b0, m68}), n68, x68);
  if (|m68) n_tog = n_tog + 1;
  if (x68 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_yy_xx_expt_vld                 in      1 %0d %0d %0d\n", ones({127'b0, m69}), n69, x69);
  if (|m69) n_tog = n_tog + 1;
  if (x69 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "rtu_yy_xx_flush                    in      1 %0d %0d %0d\n", ones({127'b0, m70}), n70, x70);
  if (|m70) n_tog = n_tog + 1;
  if (x70 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "sysio_cp0_apb_base                 in     40 %0d %0d %0d\n", ones({88'b0, m71}), n71, x71);
  if (|m71) n_tog = n_tog + 1;
  if (x71 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "vidu_cp0_vid_fof_vld               in      1 %0d %0d %0d   [dead]\n", ones({127'b0, m72}), n72, x72);
  $fwrite(FH, "cp0_biu_icg_en                     out     1 %0d %0d %0d\n", ones({127'b0, m73}), n73, x73);
  if (|m73) n_tog = n_tog + 1;
  if (x73 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_biu_lpmd_b                     out     2 %0d %0d %0d\n", ones({126'b0, m74}), n74, x74);
  if (|m74) n_tog = n_tog + 1;
  if (x74 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_dtu_addr                       out    12 %0d %0d %0d\n", ones({116'b0, m75}), n75, x75);
  if (|m75) n_tog = n_tog + 1;
  if (x75 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_dtu_debug_info                 out     6 %0d %0d %0d\n", ones({122'b0, m76}), n76, x76);
  if (|m76) n_tog = n_tog + 1;
  if (x76 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_dtu_icg_en                     out     1 %0d %0d %0d\n", ones({127'b0, m77}), n77, x77);
  if (|m77) n_tog = n_tog + 1;
  if (x77 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_dtu_mexpt_vld                  out     1 %0d %0d %0d\n", ones({127'b0, m78}), n78, x78);
  if (|m78) n_tog = n_tog + 1;
  if (x78 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_dtu_pcfifo_frz                 out     1 %0d %0d %0d\n", ones({127'b0, m79}), n79, x79);
  if (|m79) n_tog = n_tog + 1;
  if (x79 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_dtu_rreg                       out     1 %0d %0d %0d\n", ones({127'b0, m80}), n80, x80);
  if (|m80) n_tog = n_tog + 1;
  if (x80 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_dtu_satp                       out    64 %0d %0d %0d\n", ones({64'b0, m81}), n81, x81);
  if (|m81) n_tog = n_tog + 1;
  if (x81 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_dtu_wdata                      out    64 %0d %0d %0d\n", ones({64'b0, m82}), n82, x82);
  if (|m82) n_tog = n_tog + 1;
  if (x82 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_dtu_wreg                       out     1 %0d %0d %0d\n", ones({127'b0, m83}), n83, x83);
  if (|m83) n_tog = n_tog + 1;
  if (x83 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_hpcp_icg_en                    out     1 %0d %0d %0d\n", ones({127'b0, m84}), n84, x84);
  if (|m84) n_tog = n_tog + 1;
  if (x84 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_hpcp_index                     out    12 %0d %0d %0d\n", ones({116'b0, m85}), n85, x85);
  if (|m85) n_tog = n_tog + 1;
  if (x85 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_hpcp_int_off_vld               out     1 %0d %0d %0d\n", ones({127'b0, m86}), n86, x86);
  if (|m86) n_tog = n_tog + 1;
  if (x86 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_hpcp_mcntwen                   out    32 %0d %0d %0d\n", ones({96'b0, m87}), n87, x87);
  if (|m87) n_tog = n_tog + 1;
  if (x87 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_hpcp_pmdm                      out     1 %0d %0d %0d\n", ones({127'b0, m88}), n88, x88);
  if (|m88) n_tog = n_tog + 1;
  if (x88 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_hpcp_pmds                      out     1 %0d %0d %0d\n", ones({127'b0, m89}), n89, x89);
  if (|m89) n_tog = n_tog + 1;
  if (x89 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_hpcp_pmdu                      out     1 %0d %0d %0d\n", ones({127'b0, m90}), n90, x90);
  if (|m90) n_tog = n_tog + 1;
  if (x90 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_hpcp_sync_stall_vld            out     1 %0d %0d %0d\n", ones({127'b0, m91}), n91, x91);
  if (|m91) n_tog = n_tog + 1;
  if (x91 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_hpcp_wdata                     out    64 %0d %0d %0d\n", ones({64'b0, m92}), n92, x92);
  if (|m92) n_tog = n_tog + 1;
  if (x92 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_hpcp_wreg                      out     1 %0d %0d %0d\n", ones({127'b0, m93}), n93, x93);
  if (|m93) n_tog = n_tog + 1;
  if (x93 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_cskyee                     out     1 %0d %0d %0d\n", ones({127'b0, m94}), n94, x94);
  if (|m94) n_tog = n_tog + 1;
  if (x94 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_dis_fence_in_dbg           out     1 %0d %0d %0d\n", ones({127'b0, m95}), n95, x95);
  if (|m95) n_tog = n_tog + 1;
  if (x95 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_frm                        out     3 %0d %0d %0d\n", ones({125'b0, m96}), n96, x96);
  if (|m96) n_tog = n_tog + 1;
  if (x96 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_fs                         out     2 %0d %0d %0d\n", ones({126'b0, m97}), n97, x97);
  if (|m97) n_tog = n_tog + 1;
  if (x97 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_icg_en                     out     1 %0d %0d %0d\n", ones({127'b0, m98}), n98, x98);
  if (|m98) n_tog = n_tog + 1;
  if (x98 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_issue_stall                out     1 %0d %0d %0d\n", ones({127'b0, m99}), n99, x99);
  if (|m99) n_tog = n_tog + 1;
  if (x99 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_ucme                       out     1 %0d %0d %0d\n", ones({127'b0, m100}), n100, x100);
  if (|m100) n_tog = n_tog + 1;
  if (x100 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_idu_vill                       out     1 %0d %0d %0d   [dead]\n", ones({127'b0, m101}), n101, x101);
  $fwrite(FH, "cp0_idu_vl_zero                    out     1 %0d %0d %0d   [dead]\n", ones({127'b0, m102}), n102, x102);
  $fwrite(FH, "cp0_idu_vlmul                      out     2 %0d %0d %0d   [dead]\n", ones({126'b0, m103}), n103, x103);
  $fwrite(FH, "cp0_idu_vs                         out     2 %0d %0d %0d   [dead]\n", ones({126'b0, m104}), n104, x104);
  $fwrite(FH, "cp0_idu_vsetvl_dis_stall           out     1 %0d %0d %0d   [dead]\n", ones({127'b0, m105}), n105, x105);
  $fwrite(FH, "cp0_idu_vsew                       out     2 %0d %0d %0d   [dead]\n", ones({126'b0, m106}), n106, x106);
  $fwrite(FH, "cp0_idu_vstart                     out     7 %0d %0d %0d   [dead]\n", ones({121'b0, m107}), n107, x107);
  $fwrite(FH, "cp0_ifu_bht_en                     out     1 %0d %0d %0d\n", ones({127'b0, m108}), n108, x108);
  if (|m108) n_tog = n_tog + 1;
  if (x108 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_bht_inv                    out     1 %0d %0d %0d\n", ones({127'b0, m109}), n109, x109);
  if (|m109) n_tog = n_tog + 1;
  if (x109 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_btb_clr                    out     1 %0d %0d %0d\n", ones({127'b0, m110}), n110, x110);
  if (|m110) n_tog = n_tog + 1;
  if (x110 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_btb_en                     out     1 %0d %0d %0d\n", ones({127'b0, m111}), n111, x111);
  if (|m111) n_tog = n_tog + 1;
  if (x111 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_en                  out     1 %0d %0d %0d\n", ones({127'b0, m112}), n112, x112);
  if (|m112) n_tog = n_tog + 1;
  if (x112 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_inv_addr            out    64 %0d %0d %0d\n", ones({64'b0, m113}), n113, x113);
  if (|m113) n_tog = n_tog + 1;
  if (x113 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_inv_req             out     1 %0d %0d %0d\n", ones({127'b0, m114}), n114, x114);
  if (|m114) n_tog = n_tog + 1;
  if (x114 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_inv_type            out     2 %0d %0d %0d\n", ones({126'b0, m115}), n115, x115);
  if (|m115) n_tog = n_tog + 1;
  if (x115 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_pref_en             out     1 %0d %0d %0d\n", ones({127'b0, m116}), n116, x116);
  if (|m116) n_tog = n_tog + 1;
  if (x116 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_read_index          out    14 %0d %0d %0d\n", ones({114'b0, m117}), n117, x117);
  if (|m117) n_tog = n_tog + 1;
  if (x117 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_read_req            out     1 %0d %0d %0d\n", ones({127'b0, m118}), n118, x118);
  if (|m118) n_tog = n_tog + 1;
  if (x118 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_read_tag            out     1 %0d %0d %0d\n", ones({127'b0, m119}), n119, x119);
  if (|m119) n_tog = n_tog + 1;
  if (x119 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icache_read_way            out     1 %0d %0d %0d\n", ones({127'b0, m120}), n120, x120);
  if (|m120) n_tog = n_tog + 1;
  if (x120 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_icg_en                     out     1 %0d %0d %0d\n", ones({127'b0, m121}), n121, x121);
  if (|m121) n_tog = n_tog + 1;
  if (x121 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_in_lpmd                    out     1 %0d %0d %0d\n", ones({127'b0, m122}), n122, x122);
  if (|m122) n_tog = n_tog + 1;
  if (x122 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_iwpe                       out     1 %0d %0d %0d\n", ones({127'b0, m123}), n123, x123);
  if (|m123) n_tog = n_tog + 1;
  if (x123 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_lpmd_req                   out     1 %0d %0d %0d\n", ones({127'b0, m124}), n124, x124);
  if (|m124) n_tog = n_tog + 1;
  if (x124 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_ras_en                     out     1 %0d %0d %0d\n", ones({127'b0, m125}), n125, x125);
  if (|m125) n_tog = n_tog + 1;
  if (x125 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_ifu_rst_inv_done               out     1 %0d %0d %0d\n", ones({127'b0, m126}), n126, x126);
  if (|m126) n_tog = n_tog + 1;
  if (x126 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_iu_icg_en                      out     1 %0d %0d %0d\n", ones({127'b0, m127}), n127, x127);
  if (|m127) n_tog = n_tog + 1;
  if (x127 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_amr                        out     2 %0d %0d %0d\n", ones({126'b0, m128}), n128, x128);
  if (|m128) n_tog = n_tog + 1;
  if (x128 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_dcache_en                  out     1 %0d %0d %0d\n", ones({127'b0, m129}), n129, x129);
  if (|m129) n_tog = n_tog + 1;
  if (x129 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_dcache_pref_dist           out     2 %0d %0d %0d\n", ones({126'b0, m130}), n130, x130);
  if (|m130) n_tog = n_tog + 1;
  if (x130 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_dcache_pref_en             out     1 %0d %0d %0d\n", ones({127'b0, m131}), n131, x131);
  if (|m131) n_tog = n_tog + 1;
  if (x131 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_dcache_read_idx            out    17 %0d %0d %0d\n", ones({111'b0, m132}), n132, x132);
  if (|m132) n_tog = n_tog + 1;
  if (x132 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_dcache_read_req            out     1 %0d %0d %0d\n", ones({127'b0, m133}), n133, x133);
  if (|m133) n_tog = n_tog + 1;
  if (x133 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_dcache_read_type           out     1 %0d %0d %0d\n", ones({127'b0, m134}), n134, x134);
  if (|m134) n_tog = n_tog + 1;
  if (x134 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_dcache_read_way            out     2 %0d %0d %0d\n", ones({126'b0, m135}), n135, x135);
  if (|m135) n_tog = n_tog + 1;
  if (x135 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_dcache_wa                  out     1 %0d %0d %0d\n", ones({127'b0, m136}), n136, x136);
  if (|m136) n_tog = n_tog + 1;
  if (x136 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_dcache_wb                  out     1 %0d %0d %0d   [dead]\n", ones({127'b0, m137}), n137, x137);
  $fwrite(FH, "cp0_lsu_fence_req                  out     1 %0d %0d %0d\n", ones({127'b0, m138}), n138, x138);
  if (|m138) n_tog = n_tog + 1;
  if (x138 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_icc_addr                   out    64 %0d %0d %0d\n", ones({64'b0, m139}), n139, x139);
  if (|m139) n_tog = n_tog + 1;
  if (x139 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_icc_op                     out     2 %0d %0d %0d\n", ones({126'b0, m140}), n140, x140);
  if (|m140) n_tog = n_tog + 1;
  if (x140 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_icc_req                    out     1 %0d %0d %0d\n", ones({127'b0, m141}), n141, x141);
  if (|m141) n_tog = n_tog + 1;
  if (x141 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_icc_type                   out     2 %0d %0d %0d\n", ones({126'b0, m142}), n142, x142);
  if (|m142) n_tog = n_tog + 1;
  if (x142 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_icg_en                     out     1 %0d %0d %0d\n", ones({127'b0, m143}), n143, x143);
  if (|m143) n_tog = n_tog + 1;
  if (x143 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_mm                         out     1 %0d %0d %0d\n", ones({127'b0, m144}), n144, x144);
  if (|m144) n_tog = n_tog + 1;
  if (x144 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_mpp                        out     2 %0d %0d %0d\n", ones({126'b0, m145}), n145, x145);
  if (|m145) n_tog = n_tog + 1;
  if (x145 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_mprv                       out     1 %0d %0d %0d\n", ones({127'b0, m146}), n146, x146);
  if (|m146) n_tog = n_tog + 1;
  if (x146 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_sync_req                   out     1 %0d %0d %0d\n", ones({127'b0, m147}), n147, x147);
  if (|m147) n_tog = n_tog + 1;
  if (x147 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_lsu_we_en                      out     1 %0d %0d %0d   [dead]\n", ones({127'b0, m148}), n148, x148);
  $fwrite(FH, "cp0_mmu_addr                       out    12 %0d %0d %0d\n", ones({116'b0, m149}), n149, x149);
  if (|m149) n_tog = n_tog + 1;
  if (x149 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_icg_en                     out     1 %0d %0d %0d\n", ones({127'b0, m150}), n150, x150);
  if (|m150) n_tog = n_tog + 1;
  if (x150 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_lpmd_req                   out     1 %0d %0d %0d\n", ones({127'b0, m151}), n151, x151);
  if (|m151) n_tog = n_tog + 1;
  if (x151 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_maee                       out     1 %0d %0d %0d\n", ones({127'b0, m152}), n152, x152);
  if (|m152) n_tog = n_tog + 1;
  if (x152 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_mxr                        out     1 %0d %0d %0d\n", ones({127'b0, m153}), n153, x153);
  if (|m153) n_tog = n_tog + 1;
  if (x153 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_ptw_en                     out     1 %0d %0d %0d\n", ones({127'b0, m154}), n154, x154);
  if (|m154) n_tog = n_tog + 1;
  if (x154 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_satp_data                  out    64 %0d %0d %0d\n", ones({64'b0, m155}), n155, x155);
  if (|m155) n_tog = n_tog + 1;
  if (x155 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_satp_wen                   out     1 %0d %0d %0d\n", ones({127'b0, m156}), n156, x156);
  if (|m156) n_tog = n_tog + 1;
  if (x156 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_sum                        out     1 %0d %0d %0d\n", ones({127'b0, m157}), n157, x157);
  if (|m157) n_tog = n_tog + 1;
  if (x157 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_tlb_all_inv                out     1 %0d %0d %0d\n", ones({127'b0, m158}), n158, x158);
  if (|m158) n_tog = n_tog + 1;
  if (x158 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_tlb_asid                   out    16 %0d %0d %0d\n", ones({112'b0, m159}), n159, x159);
  if (|m159) n_tog = n_tog + 1;
  if (x159 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_tlb_asid_all_inv           out     1 %0d %0d %0d\n", ones({127'b0, m160}), n160, x160);
  if (|m160) n_tog = n_tog + 1;
  if (x160 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_tlb_va                     out    27 %0d %0d %0d\n", ones({101'b0, m161}), n161, x161);
  if (|m161) n_tog = n_tog + 1;
  if (x161 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_tlb_va_all_inv             out     1 %0d %0d %0d\n", ones({127'b0, m162}), n162, x162);
  if (|m162) n_tog = n_tog + 1;
  if (x162 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_tlb_va_asid_inv            out     1 %0d %0d %0d\n", ones({127'b0, m163}), n163, x163);
  if (|m163) n_tog = n_tog + 1;
  if (x163 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_wdata                      out    64 %0d %0d %0d\n", ones({64'b0, m164}), n164, x164);
  if (|m164) n_tog = n_tog + 1;
  if (x164 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_mmu_wreg                       out     1 %0d %0d %0d\n", ones({127'b0, m165}), n165, x165);
  if (|m165) n_tog = n_tog + 1;
  if (x165 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_pmp_addr                       out    12 %0d %0d %0d\n", ones({116'b0, m166}), n166, x166);
  if (|m166) n_tog = n_tog + 1;
  if (x166 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_pmp_icg_en                     out     1 %0d %0d %0d\n", ones({127'b0, m167}), n167, x167);
  if (|m167) n_tog = n_tog + 1;
  if (x167 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_pmp_wdata                      out    64 %0d %0d %0d\n", ones({64'b0, m168}), n168, x168);
  if (|m168) n_tog = n_tog + 1;
  if (x168 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_pmp_wreg                       out     1 %0d %0d %0d\n", ones({127'b0, m169}), n169, x169);
  if (|m169) n_tog = n_tog + 1;
  if (x169 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_chgflw                 out     1 %0d %0d %0d\n", ones({127'b0, m170}), n170, x170);
  if (|m170) n_tog = n_tog + 1;
  if (x170 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_chgflw_pc              out    40 %0d %0d %0d\n", ones({88'b0, m171}), n171, x171);
  if (|m171) n_tog = n_tog + 1;
  if (x171 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_cmplt                  out     1 %0d %0d %0d\n", ones({127'b0, m172}), n172, x172);
  if (|m172) n_tog = n_tog + 1;
  if (x172 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_cmplt_dp               out     1 %0d %0d %0d\n", ones({127'b0, m173}), n173, x173);
  if (|m173) n_tog = n_tog + 1;
  if (x173 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_expt_tval              out    40 %0d %0d %0d\n", ones({88'b0, m174}), n174, x174);
  if (|m174) n_tog = n_tog + 1;
  if (x174 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_expt_vec               out     5 %0d %0d %0d\n", ones({123'b0, m175}), n175, x175);
  if (|m175) n_tog = n_tog + 1;
  if (x175 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_expt_vld               out     1 %0d %0d %0d\n", ones({127'b0, m176}), n176, x176);
  if (|m176) n_tog = n_tog + 1;
  if (x176 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_flush                  out     1 %0d %0d %0d\n", ones({127'b0, m177}), n177, x177);
  if (|m177) n_tog = n_tog + 1;
  if (x177 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_halt_info              out    22 %0d %0d %0d\n", ones({106'b0, m178}), n178, x178);
  if (|m178) n_tog = n_tog + 1;
  if (x178 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_inst_dret              out     1 %0d %0d %0d\n", ones({127'b0, m179}), n179, x179);
  if (|m179) n_tog = n_tog + 1;
  if (x179 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_inst_ebreak            out     1 %0d %0d %0d\n", ones({127'b0, m180}), n180, x180);
  if (|m180) n_tog = n_tog + 1;
  if (x180 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_inst_len               out     1 %0d %0d %0d\n", ones({127'b0, m181}), n181, x181);
  if (|m181) n_tog = n_tog + 1;
  if (x181 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_inst_mret              out     1 %0d %0d %0d\n", ones({127'b0, m182}), n182, x182);
  if (|m182) n_tog = n_tog + 1;
  if (x182 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_inst_split             out     1 %0d %0d %0d\n", ones({127'b0, m183}), n183, x183);
  if (|m183) n_tog = n_tog + 1;
  if (x183 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_inst_sret              out     1 %0d %0d %0d\n", ones({127'b0, m184}), n184, x184);
  if (|m184) n_tog = n_tog + 1;
  if (x184 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_vs_dirty               out     1 %0d %0d %0d   [dead]\n", ones({127'b0, m185}), n185, x185);
  $fwrite(FH, "cp0_rtu_ex1_vs_dirty_dp            out     1 %0d %0d %0d   [dead]\n", ones({127'b0, m186}), n186, x186);
  $fwrite(FH, "cp0_rtu_ex1_wb_data                out    64 %0d %0d %0d\n", ones({64'b0, m187}), n187, x187);
  if (|m187) n_tog = n_tog + 1;
  if (x187 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_wb_dp                  out     1 %0d %0d %0d\n", ones({127'b0, m188}), n188, x188);
  if (|m188) n_tog = n_tog + 1;
  if (x188 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_wb_preg                out     6 %0d %0d %0d\n", ones({122'b0, m189}), n189, x189);
  if (|m189) n_tog = n_tog + 1;
  if (x189 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_ex1_wb_vld                 out     1 %0d %0d %0d\n", ones({127'b0, m190}), n190, x190);
  if (|m190) n_tog = n_tog + 1;
  if (x190 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_fence_idle                 out     1 %0d %0d %0d\n", ones({127'b0, m191}), n191, x191);
  if (|m191) n_tog = n_tog + 1;
  if (x191 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_icg_en                     out     1 %0d %0d %0d\n", ones({127'b0, m192}), n192, x192);
  if (|m192) n_tog = n_tog + 1;
  if (x192 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_in_lpmd                    out     1 %0d %0d %0d\n", ones({127'b0, m193}), n193, x193);
  if (|m193) n_tog = n_tog + 1;
  if (x193 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_int_vld                    out    15 %0d %0d %0d\n", ones({113'b0, m194}), n194, x194);
  if (|m194) n_tog = n_tog + 1;
  if (x194 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_trap_pc                    out    40 %0d %0d %0d\n", ones({88'b0, m195}), n195, x195);
  if (|m195) n_tog = n_tog + 1;
  if (x195 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_rtu_vstart_eq_0                out     1 %0d %0d %0d   [dead]\n", ones({127'b0, m196}), n196, x196);
  $fwrite(FH, "cp0_vpu_icg_en                     out     1 %0d %0d %0d\n", ones({127'b0, m197}), n197, x197);
  if (|m197) n_tog = n_tog + 1;
  if (x197 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_vpu_xx_bf16                    out     1 %0d %0d %0d\n", ones({127'b0, m198}), n198, x198);
  if (|m198) n_tog = n_tog + 1;
  if (x198 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_vpu_xx_dqnan                   out     1 %0d %0d %0d\n", ones({127'b0, m199}), n199, x199);
  if (|m199) n_tog = n_tog + 1;
  if (x199 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_vpu_xx_rm                      out     3 %0d %0d %0d\n", ones({125'b0, m200}), n200, x200);
  if (|m200) n_tog = n_tog + 1;
  if (x200 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_xx_mrvbr                       out    40 %0d %0d %0d   [dead]\n", ones({88'b0, m201}), n201, x201);
  $fwrite(FH, "cp0_yy_clk_en                      out     1 %0d %0d %0d\n", ones({127'b0, m202}), n202, x202);
  if (|m202) n_tog = n_tog + 1;
  if (x202 != 0) n_xseen = n_xseen + 1;
  $fwrite(FH, "cp0_yy_priv_mode                   out     2 %0d %0d %0d\n", ones({126'b0, m203}), n203, x203);
  if (|m203) n_tog = n_tog + 1;
  if (x203 != 0) n_xseen = n_xseen + 1;

  $fwrite(FH, "\nSUMMARY: %0d/178 functional ports toggled (3 infrastructure + 23 provably dead excluded)\n", n_tog);
  $fwrite(FH, "EXCLUDED AS DEAD:");
  $fwrite(FH, " biu_cp0_coreid");
  $fwrite(FH, " biu_cp0_rvba");
  $fwrite(FH, " rtu_cp0_vl");
  $fwrite(FH, " rtu_cp0_vl_vld");
  $fwrite(FH, " rtu_cp0_vs_dirty_updt");
  $fwrite(FH, " rtu_cp0_vs_dirty_updt_dp");
  $fwrite(FH, " rtu_cp0_vstart");
  $fwrite(FH, " rtu_cp0_vstart_vld");
  $fwrite(FH, " rtu_cp0_vxsat");
  $fwrite(FH, " vidu_cp0_vid_fof_vld");
  $fwrite(FH, " cp0_idu_vill");
  $fwrite(FH, " cp0_idu_vl_zero");
  $fwrite(FH, " cp0_idu_vlmul");
  $fwrite(FH, " cp0_idu_vs");
  $fwrite(FH, " cp0_idu_vsetvl_dis_stall");
  $fwrite(FH, " cp0_idu_vsew");
  $fwrite(FH, " cp0_idu_vstart");
  $fwrite(FH, " cp0_lsu_dcache_wb");
  $fwrite(FH, " cp0_lsu_we_en");
  $fwrite(FH, " cp0_rtu_ex1_vs_dirty");
  $fwrite(FH, " cp0_rtu_ex1_vs_dirty_dp");
  $fwrite(FH, " cp0_rtu_vstart_eq_0");
  $fwrite(FH, " cp0_xx_mrvbr");
  $fwrite(FH, "\n");
  $fwrite(FH, "X-SEEN : %0d functional ports held an X/Z bit at some point\n", n_xseen);
  $fwrite(FH, "NEVER TOGGLED:");
  if (~|m1) $fwrite(FH, " biu_cp0_me_int");
  if (~|m2) $fwrite(FH, " biu_cp0_ms_int");
  if (~|m3) $fwrite(FH, " biu_cp0_mt_int");
  if (~|m5) $fwrite(FH, " biu_cp0_se_int");
  if (~|m6) $fwrite(FH, " biu_cp0_ss_int");
  if (~|m7) $fwrite(FH, " biu_cp0_st_int");
  if (~|m9) $fwrite(FH, " dtu_cp0_dcsr_mprven");
  if (~|m10) $fwrite(FH, " dtu_cp0_dcsr_prv");
  if (~|m11) $fwrite(FH, " dtu_cp0_rdata");
  if (~|m12) $fwrite(FH, " dtu_cp0_wake_up");
  if (~|m14) $fwrite(FH, " hpcp_cp0_data");
  if (~|m15) $fwrite(FH, " hpcp_cp0_int_vld");
  if (~|m16) $fwrite(FH, " hpcp_cp0_sce");
  if (~|m17) $fwrite(FH, " idu_cp0_ex1_dp_sel");
  if (~|m18) $fwrite(FH, " idu_cp0_ex1_dst0_reg");
  if (~|m19) $fwrite(FH, " idu_cp0_ex1_expt_acc_error");
  if (~|m20) $fwrite(FH, " idu_cp0_ex1_expt_high");
  if (~|m21) $fwrite(FH, " idu_cp0_ex1_expt_illegal");
  if (~|m22) $fwrite(FH, " idu_cp0_ex1_expt_page_fault");
  if (~|m23) $fwrite(FH, " idu_cp0_ex1_func");
  if (~|m24) $fwrite(FH, " idu_cp0_ex1_gateclk_sel");
  if (~|m25) $fwrite(FH, " idu_cp0_ex1_halt_info");
  if (~|m26) $fwrite(FH, " idu_cp0_ex1_length");
  if (~|m27) $fwrite(FH, " idu_cp0_ex1_opcode");
  if (~|m28) $fwrite(FH, " idu_cp0_ex1_sel");
  if (~|m29) $fwrite(FH, " idu_cp0_ex1_split");
  if (~|m30) $fwrite(FH, " idu_cp0_ex1_src0_data");
  if (~|m31) $fwrite(FH, " idu_cp0_ex1_src1_data");
  if (~|m32) $fwrite(FH, " ifu_cp0_bht_inv_done");
  if (~|m33) $fwrite(FH, " ifu_cp0_icache_inv_done");
  if (~|m34) $fwrite(FH, " ifu_cp0_icache_read_data");
  if (~|m35) $fwrite(FH, " ifu_cp0_icache_read_data_vld");
  if (~|m36) $fwrite(FH, " ifu_cp0_rst_inv_req");
  if (~|m37) $fwrite(FH, " ifu_cp0_warm_up");
  if (~|m38) $fwrite(FH, " ifu_yy_xx_no_op");
  if (~|m39) $fwrite(FH, " iu_cp0_ex1_cur_pc");
  if (~|m40) $fwrite(FH, " lsu_cp0_dcache_read_data");
  if (~|m41) $fwrite(FH, " lsu_cp0_dcache_read_data_vld");
  if (~|m42) $fwrite(FH, " lsu_cp0_fence_ack");
  if (~|m43) $fwrite(FH, " lsu_cp0_icc_done");
  if (~|m44) $fwrite(FH, " lsu_cp0_sync_ack");
  if (~|m45) $fwrite(FH, " mmu_cp0_cmplt");
  if (~|m46) $fwrite(FH, " mmu_cp0_data");
  if (~|m47) $fwrite(FH, " mmu_cp0_tlb_inv_done");
  if (~|m48) $fwrite(FH, " mmu_yy_xx_no_op");
  if (~|m50) $fwrite(FH, " pmp_cp0_data");
  if (~|m51) $fwrite(FH, " rtu_cp0_epc");
  if (~|m52) $fwrite(FH, " rtu_cp0_exit_debug");
  if (~|m53) $fwrite(FH, " rtu_cp0_fflags");
  if (~|m54) $fwrite(FH, " rtu_cp0_fflags_updt");
  if (~|m55) $fwrite(FH, " rtu_cp0_fs_dirty_updt");
  if (~|m56) $fwrite(FH, " rtu_cp0_fs_dirty_updt_dp");
  if (~|m57) $fwrite(FH, " rtu_cp0_tval");
  if (~|m65) $fwrite(FH, " rtu_cp0_vxsat_vld");
  if (~|m66) $fwrite(FH, " rtu_yy_xx_dbgon");
  if (~|m67) $fwrite(FH, " rtu_yy_xx_expt_int");
  if (~|m68) $fwrite(FH, " rtu_yy_xx_expt_vec");
  if (~|m69) $fwrite(FH, " rtu_yy_xx_expt_vld");
  if (~|m70) $fwrite(FH, " rtu_yy_xx_flush");
  if (~|m71) $fwrite(FH, " sysio_cp0_apb_base");
  if (~|m73) $fwrite(FH, " cp0_biu_icg_en");
  if (~|m74) $fwrite(FH, " cp0_biu_lpmd_b");
  if (~|m75) $fwrite(FH, " cp0_dtu_addr");
  if (~|m76) $fwrite(FH, " cp0_dtu_debug_info");
  if (~|m77) $fwrite(FH, " cp0_dtu_icg_en");
  if (~|m78) $fwrite(FH, " cp0_dtu_mexpt_vld");
  if (~|m79) $fwrite(FH, " cp0_dtu_pcfifo_frz");
  if (~|m80) $fwrite(FH, " cp0_dtu_rreg");
  if (~|m81) $fwrite(FH, " cp0_dtu_satp");
  if (~|m82) $fwrite(FH, " cp0_dtu_wdata");
  if (~|m83) $fwrite(FH, " cp0_dtu_wreg");
  if (~|m84) $fwrite(FH, " cp0_hpcp_icg_en");
  if (~|m85) $fwrite(FH, " cp0_hpcp_index");
  if (~|m86) $fwrite(FH, " cp0_hpcp_int_off_vld");
  if (~|m87) $fwrite(FH, " cp0_hpcp_mcntwen");
  if (~|m88) $fwrite(FH, " cp0_hpcp_pmdm");
  if (~|m89) $fwrite(FH, " cp0_hpcp_pmds");
  if (~|m90) $fwrite(FH, " cp0_hpcp_pmdu");
  if (~|m91) $fwrite(FH, " cp0_hpcp_sync_stall_vld");
  if (~|m92) $fwrite(FH, " cp0_hpcp_wdata");
  if (~|m93) $fwrite(FH, " cp0_hpcp_wreg");
  if (~|m94) $fwrite(FH, " cp0_idu_cskyee");
  if (~|m95) $fwrite(FH, " cp0_idu_dis_fence_in_dbg");
  if (~|m96) $fwrite(FH, " cp0_idu_frm");
  if (~|m97) $fwrite(FH, " cp0_idu_fs");
  if (~|m98) $fwrite(FH, " cp0_idu_icg_en");
  if (~|m99) $fwrite(FH, " cp0_idu_issue_stall");
  if (~|m100) $fwrite(FH, " cp0_idu_ucme");
  if (~|m108) $fwrite(FH, " cp0_ifu_bht_en");
  if (~|m109) $fwrite(FH, " cp0_ifu_bht_inv");
  if (~|m110) $fwrite(FH, " cp0_ifu_btb_clr");
  if (~|m111) $fwrite(FH, " cp0_ifu_btb_en");
  if (~|m112) $fwrite(FH, " cp0_ifu_icache_en");
  if (~|m113) $fwrite(FH, " cp0_ifu_icache_inv_addr");
  if (~|m114) $fwrite(FH, " cp0_ifu_icache_inv_req");
  if (~|m115) $fwrite(FH, " cp0_ifu_icache_inv_type");
  if (~|m116) $fwrite(FH, " cp0_ifu_icache_pref_en");
  if (~|m117) $fwrite(FH, " cp0_ifu_icache_read_index");
  if (~|m118) $fwrite(FH, " cp0_ifu_icache_read_req");
  if (~|m119) $fwrite(FH, " cp0_ifu_icache_read_tag");
  if (~|m120) $fwrite(FH, " cp0_ifu_icache_read_way");
  if (~|m121) $fwrite(FH, " cp0_ifu_icg_en");
  if (~|m122) $fwrite(FH, " cp0_ifu_in_lpmd");
  if (~|m123) $fwrite(FH, " cp0_ifu_iwpe");
  if (~|m124) $fwrite(FH, " cp0_ifu_lpmd_req");
  if (~|m125) $fwrite(FH, " cp0_ifu_ras_en");
  if (~|m126) $fwrite(FH, " cp0_ifu_rst_inv_done");
  if (~|m127) $fwrite(FH, " cp0_iu_icg_en");
  if (~|m128) $fwrite(FH, " cp0_lsu_amr");
  if (~|m129) $fwrite(FH, " cp0_lsu_dcache_en");
  if (~|m130) $fwrite(FH, " cp0_lsu_dcache_pref_dist");
  if (~|m131) $fwrite(FH, " cp0_lsu_dcache_pref_en");
  if (~|m132) $fwrite(FH, " cp0_lsu_dcache_read_idx");
  if (~|m133) $fwrite(FH, " cp0_lsu_dcache_read_req");
  if (~|m134) $fwrite(FH, " cp0_lsu_dcache_read_type");
  if (~|m135) $fwrite(FH, " cp0_lsu_dcache_read_way");
  if (~|m136) $fwrite(FH, " cp0_lsu_dcache_wa");
  if (~|m138) $fwrite(FH, " cp0_lsu_fence_req");
  if (~|m139) $fwrite(FH, " cp0_lsu_icc_addr");
  if (~|m140) $fwrite(FH, " cp0_lsu_icc_op");
  if (~|m141) $fwrite(FH, " cp0_lsu_icc_req");
  if (~|m142) $fwrite(FH, " cp0_lsu_icc_type");
  if (~|m143) $fwrite(FH, " cp0_lsu_icg_en");
  if (~|m144) $fwrite(FH, " cp0_lsu_mm");
  if (~|m145) $fwrite(FH, " cp0_lsu_mpp");
  if (~|m146) $fwrite(FH, " cp0_lsu_mprv");
  if (~|m147) $fwrite(FH, " cp0_lsu_sync_req");
  if (~|m149) $fwrite(FH, " cp0_mmu_addr");
  if (~|m150) $fwrite(FH, " cp0_mmu_icg_en");
  if (~|m151) $fwrite(FH, " cp0_mmu_lpmd_req");
  if (~|m152) $fwrite(FH, " cp0_mmu_maee");
  if (~|m153) $fwrite(FH, " cp0_mmu_mxr");
  if (~|m154) $fwrite(FH, " cp0_mmu_ptw_en");
  if (~|m155) $fwrite(FH, " cp0_mmu_satp_data");
  if (~|m156) $fwrite(FH, " cp0_mmu_satp_wen");
  if (~|m157) $fwrite(FH, " cp0_mmu_sum");
  if (~|m158) $fwrite(FH, " cp0_mmu_tlb_all_inv");
  if (~|m159) $fwrite(FH, " cp0_mmu_tlb_asid");
  if (~|m160) $fwrite(FH, " cp0_mmu_tlb_asid_all_inv");
  if (~|m161) $fwrite(FH, " cp0_mmu_tlb_va");
  if (~|m162) $fwrite(FH, " cp0_mmu_tlb_va_all_inv");
  if (~|m163) $fwrite(FH, " cp0_mmu_tlb_va_asid_inv");
  if (~|m164) $fwrite(FH, " cp0_mmu_wdata");
  if (~|m165) $fwrite(FH, " cp0_mmu_wreg");
  if (~|m166) $fwrite(FH, " cp0_pmp_addr");
  if (~|m167) $fwrite(FH, " cp0_pmp_icg_en");
  if (~|m168) $fwrite(FH, " cp0_pmp_wdata");
  if (~|m169) $fwrite(FH, " cp0_pmp_wreg");
  if (~|m170) $fwrite(FH, " cp0_rtu_ex1_chgflw");
  if (~|m171) $fwrite(FH, " cp0_rtu_ex1_chgflw_pc");
  if (~|m172) $fwrite(FH, " cp0_rtu_ex1_cmplt");
  if (~|m173) $fwrite(FH, " cp0_rtu_ex1_cmplt_dp");
  if (~|m174) $fwrite(FH, " cp0_rtu_ex1_expt_tval");
  if (~|m175) $fwrite(FH, " cp0_rtu_ex1_expt_vec");
  if (~|m176) $fwrite(FH, " cp0_rtu_ex1_expt_vld");
  if (~|m177) $fwrite(FH, " cp0_rtu_ex1_flush");
  if (~|m178) $fwrite(FH, " cp0_rtu_ex1_halt_info");
  if (~|m179) $fwrite(FH, " cp0_rtu_ex1_inst_dret");
  if (~|m180) $fwrite(FH, " cp0_rtu_ex1_inst_ebreak");
  if (~|m181) $fwrite(FH, " cp0_rtu_ex1_inst_len");
  if (~|m182) $fwrite(FH, " cp0_rtu_ex1_inst_mret");
  if (~|m183) $fwrite(FH, " cp0_rtu_ex1_inst_split");
  if (~|m184) $fwrite(FH, " cp0_rtu_ex1_inst_sret");
  if (~|m187) $fwrite(FH, " cp0_rtu_ex1_wb_data");
  if (~|m188) $fwrite(FH, " cp0_rtu_ex1_wb_dp");
  if (~|m189) $fwrite(FH, " cp0_rtu_ex1_wb_preg");
  if (~|m190) $fwrite(FH, " cp0_rtu_ex1_wb_vld");
  if (~|m191) $fwrite(FH, " cp0_rtu_fence_idle");
  if (~|m192) $fwrite(FH, " cp0_rtu_icg_en");
  if (~|m193) $fwrite(FH, " cp0_rtu_in_lpmd");
  if (~|m194) $fwrite(FH, " cp0_rtu_int_vld");
  if (~|m195) $fwrite(FH, " cp0_rtu_trap_pc");
  if (~|m197) $fwrite(FH, " cp0_vpu_icg_en");
  if (~|m198) $fwrite(FH, " cp0_vpu_xx_bf16");
  if (~|m199) $fwrite(FH, " cp0_vpu_xx_dqnan");
  if (~|m200) $fwrite(FH, " cp0_vpu_xx_rm");
  if (~|m202) $fwrite(FH, " cp0_yy_clk_en");
  if (~|m203) $fwrite(FH, " cp0_yy_priv_mode");
  $fwrite(FH, "\n");
  $fclose(FH);
  $display("[cp0_toggle_mon] %0d/178 functional CP0 ports toggled; report in cp0_toggle.report", n_tog);
end

endmodule

`undef CP0_MON_I
`endif // CP0_TOGGLE_MON
