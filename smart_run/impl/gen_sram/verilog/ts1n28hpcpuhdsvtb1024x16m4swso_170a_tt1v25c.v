//*#*********************************************************************************************************************/
//*# Software       : TSMC MEMORY COMPILER tsn28hpcpuhdspsram_2012.02.00.d.170a						*/
//*# Technology     : TSMC 28nm CMOS LOGIC High Performance Compact Mobile Computing Plus 1P10M HKMG CU_ELK 0.9V				*/
//*#  Memory Type    : TSMC 28nm High Performance Compact Mobile Computing Plus Ultra High Density Single Port SRAM with d127 bit cell SVT periphery */
//*# Library Name   : ts1n28hpcpuhdsvtb1024x16m4swso (user specify : TS1N28HPCPUHDSVTB1024X16M4SWSO)				*/
//*# Library Version: 170a												*/
//*# Generated Time : 2026/04/25, 09:59:03										*/
//*#*********************************************************************************************************************/
//*#															*/
//*# STATEMENT OF USE													*/
//*#															*/
//*# This information contains confidential and proprietary information of TSMC.					*/
//*# No part of this information may be reproduced, transmitted, transcribed,						*/
//*# stored in a retrieval system, or translated into any human or computer						*/
//*# language, in any form or by any means, electronic, mechanical, magnetic,						*/
//*# optical, chemical, manual, or otherwise, without the prior written permission					*/
//*# of TSMC. This information was prepared for informational purpose and is for					*/
//*# use by TSMC's customers only. TSMC reserves the right to make changes in the					*/
//*# information at any time and without notice.									*/
//*#															*/
//*#*********************************************************************************************************************/
//********************************************************************************/
//*                                                                              */
//*      Usage Limitation: PLEASE READ CAREFULLY FOR CORRECT USAGE               */
//*                                                                              */
//* The model doesn't support the control enable, data and address signals       */
//* transition at positive clock edge.                                           */
//* Please have some timing delays between control/data/address and clock signals*/
//* to ensure the correct behavior.                                              */
//*                                                                              */
//* Please be careful when using non 2^n  memory.                                */
//* In a non-fully decoded array, a write cycle to a nonexistent address location*/
//* does not change the memory array contents and output remains the same.       */
//* In a non-fully decoded array, a read cycle to a nonexistent address location */
//* does not change the memory array contents but the output becomes unknown.    */
//*                                                                              */
//* In the verilog model, the behavior of unknown clock will corrupt the         */
//* memory data and make output unknown regardless of CEB signal.  But in the    */
//* silicon, the unknown clock at CEB high, the memory and output data will be   */
//* held. The verilog model behavior is more conservative in this condition.     */
//*                                                                              */
//* The model doesn't identify physical column and row address.                  */
//*                                                                              */
//* The verilog model provides UNIT_DELAY mode for the fast function             */
//* simulation.                                                                  */
//* All timing values in the specification are not checked in the                */
//* UNIT_DELAY mode simulation.                                                  */
//* The model also provides NO_INPUT_FLOATING_CHECK mode to speed up simulation. */
//* However, it won't check floating input pins in standby mode.                 */
//*                                                                              */
//* Template Version : S_01_63701                                                */
//****************************************************************************** */
//*      Macro Usage       : (+define[MACRO] for Verilog compiliers)             */
//* +UNIT_DELAY : Enable fast function simulation.                               */
//* +no_warning : Disable all runtime warnings message from this model.          */
//* +TSMC_INITIALIZE_MEM : Initialize the memory data in verilog format.         */
//* +TSMC_INITIALIZE_FAULT : Initialize the memory fault data in verilog format. */
//* +TSMC_NO_TESTPINS_WARNING : Disable the wrong test pins connection error     */
//*                             message if necessary.                            */
//* +NO_INPUT_FLOATING_CHECK : Turn off floating check for all input pins in     */
//*                            standby mode.                                     */
//****************************************************************************** */
`resetall

`celldefine

`timescale 1ns/1ps
`delay_mode_path
`suppress_faults
`enable_portfaults

module TS1N28HPCPUHDSVTB1024X16M4SWSO (
            SLP,
            SD,
            CLK, CEB, WEB,
            A, D,
            BWEB,
            RTSEL,
            WTSEL,
            Q);

parameter numWord = 1024;
parameter numRow = 256;
parameter numCM = 4;
parameter numIOBit = 16;
parameter numBit = 16;
parameter numWordAddr = 10;
parameter numRowAddr = 8;
parameter numCMAddr = 2;
parameter numRowRedSize = 0;
parameter numColRedSize = 0;
parameter numSRSize = numRowRedSize + numColRedSize;
parameter numRR = 2;
parameter numCR = 1;
parameter numDC = 0;
parameter numStuckAt = 20;

`ifdef UNIT_DELAY
parameter SRAM_DELAY = 0.0100;
`endif
`ifdef TSMC_INITIALIZE_MEM
parameter INITIAL_MEM_DELAY = 0.01;
`endif
`ifdef TSMC_INITIALIZE_FAULT
parameter INITIAL_FAULT_DELAY = 0.01;
`endif

`ifdef TSMC_INITIALIZE_MEM
parameter cdeFileInit  = "TS1N28HPCPUHDSVTB1024X16M4SWSO_initial.cde";
`endif
`ifdef TSMC_INITIALIZE_FAULT
parameter cdeFileFault = "TS1N28HPCPUHDSVTB1024X16M4SWSO_fault.cde";
`endif

//=== IO Ports ===//

// Normal Mode Input
input SLP;
input SD;
input CLK;
input CEB;
input WEB;
input [9:0] A;
input [15:0] D;
input [15:0] BWEB;


// Data Output
output [15:0] Q;


// Test Mode
input [1:0] RTSEL;
input [1:0] WTSEL;

//=== Internal Signals ===//
        
// Normal Mode Input
wire SLP_i;
wire DSLP_i;
wire SD_i;
wire CLK_i;
wire CEB_i;
wire WEB_i;
wire [numWordAddr-1:0] A_i;
wire [numIOBit-1:0] D_i;
wire [numIOBit-1:0] BWEB_i;


// Data Output
wire [numIOBit-1:0] Q_i;

// Serial Shift Register Data

// Test Mode
wire [1:0] RTSEL_i;
wire [1:0] WTSEL_i;

//=== IO Buffers ===//
        
// Normal Mode Input
buf (SLP_i, SLP);
buf (SD_i, SD);
buf (CLK_i, CLK);
buf (CEB_i, CEB);
buf (WEB_i, WEB);
buf (A_i[0], A[0]);
buf (A_i[1], A[1]);
buf (A_i[2], A[2]);
buf (A_i[3], A[3]);
buf (A_i[4], A[4]);
buf (A_i[5], A[5]);
buf (A_i[6], A[6]);
buf (A_i[7], A[7]);
buf (A_i[8], A[8]);
buf (A_i[9], A[9]);
buf (D_i[0], D[0]);
buf (D_i[1], D[1]);
buf (D_i[2], D[2]);
buf (D_i[3], D[3]);
buf (D_i[4], D[4]);
buf (D_i[5], D[5]);
buf (D_i[6], D[6]);
buf (D_i[7], D[7]);
buf (D_i[8], D[8]);
buf (D_i[9], D[9]);
buf (D_i[10], D[10]);
buf (D_i[11], D[11]);
buf (D_i[12], D[12]);
buf (D_i[13], D[13]);
buf (D_i[14], D[14]);
buf (D_i[15], D[15]);
buf (BWEB_i[0], BWEB[0]);
buf (BWEB_i[1], BWEB[1]);
buf (BWEB_i[2], BWEB[2]);
buf (BWEB_i[3], BWEB[3]);
buf (BWEB_i[4], BWEB[4]);
buf (BWEB_i[5], BWEB[5]);
buf (BWEB_i[6], BWEB[6]);
buf (BWEB_i[7], BWEB[7]);
buf (BWEB_i[8], BWEB[8]);
buf (BWEB_i[9], BWEB[9]);
buf (BWEB_i[10], BWEB[10]);
buf (BWEB_i[11], BWEB[11]);
buf (BWEB_i[12], BWEB[12]);
buf (BWEB_i[13], BWEB[13]);
buf (BWEB_i[14], BWEB[14]);
buf (BWEB_i[15], BWEB[15]);




// Data Output
nmos (Q[0], Q_i[0], 1'b1);
nmos (Q[1], Q_i[1], 1'b1);
nmos (Q[2], Q_i[2], 1'b1);
nmos (Q[3], Q_i[3], 1'b1);
nmos (Q[4], Q_i[4], 1'b1);
nmos (Q[5], Q_i[5], 1'b1);
nmos (Q[6], Q_i[6], 1'b1);
nmos (Q[7], Q_i[7], 1'b1);
nmos (Q[8], Q_i[8], 1'b1);
nmos (Q[9], Q_i[9], 1'b1);
nmos (Q[10], Q_i[10], 1'b1);
nmos (Q[11], Q_i[11], 1'b1);
nmos (Q[12], Q_i[12], 1'b1);
nmos (Q[13], Q_i[13], 1'b1);
nmos (Q[14], Q_i[14], 1'b1);
nmos (Q[15], Q_i[15], 1'b1);



// Test Mode
buf sRTSEL0 (RTSEL_i[0], RTSEL[0]);
buf sRTSEL1 (RTSEL_i[1], RTSEL[1]);
buf sWTSEL0 (WTSEL_i[0], WTSEL[0]);
buf sWTSEL1 (WTSEL_i[1], WTSEL[1]);

//=== Data Structure ===//
reg [numBit-1:0] MEMORY[numRow-1:0][numCM-1:0];
reg [numBit-1:0] MEMORY_FAULT[numRow-1:0][numCM-1:0];
reg [numBit-1:0] RMEMORY [numRR-1:0][numCM-1:0];
reg [numIOBit-1:0] Q_d;
reg [numBit-1:0] Q_d_tmp;
reg [numIOBit-1:0] PRELOAD[0:numWord-1];

reg [numBit-1:0] DIN_tmp, ERR_tmp;
reg [numWordAddr-1:0] stuckAt0Addr [numStuckAt:0];
reg [numWordAddr-1:0] stuckAt1Addr [numStuckAt:0];
reg [numBit-1:0] stuckAt0Bit [numStuckAt:0];
reg [numBit-1:0] stuckAt1Bit [numStuckAt:0];

reg [numWordAddr-numCMAddr-1:0] row_tmp;
reg [numCMAddr-1:0] col_tmp;

integer i, j;
reg read_flag, write_flag, idle_flag;
reg slp_mode;
reg dslp_mode;
reg sd_mode;
reg clk_latch;

`ifdef UNIT_DELAY
`else
reg notify_sd;
reg notify_slp;
reg notify_clk;
reg notify_bist;
reg notify_ceb;
reg notify_web;
reg notify_addr;
reg notify_din;
reg notify_bweb;
`endif    //end `ifdef UNIT_DELAY

reg CEBL;
reg WEBL;

wire iCEB=CEB_i;
wire iWEB = WEB_i;
wire [numWordAddr-1:0] iA = A_i;

reg [numWordAddr-numCMAddr-1:0] iRowAddr;
reg [numCMAddr-1:0] iColAddr;
wire [numIOBit-1:0] iD = D_i;
wire [numIOBit-1:0] iBWEB = BWEB_i;


assign DSLP_i=1'b0;

`ifdef UNIT_DELAY
`else
wire check_read = read_flag;
wire check_write = write_flag;
wire check_nosd= ~SD;
wire check_nodslp= 1'b1;
wire check_noslp= ~SLP;
wire check_nosd_nodslp = ~SD_i & ~DSLP_i;
wire check_nopd = ~SD_i & ~DSLP_i & ~SLP_i;
wire check_noidle = ~idle_flag & ~SD_i & ~DSLP_i & ~SLP_i;

`endif    //end `ifdef UNIT_DELAY
assign Q_i= Q_d;

`ifdef UNIT_DELAY
parameter tSDQ = 0.4130;
parameter tSLPQ = 0.3063;
`else

specify
    specparam PATHPULSE$ = ( 0, 0.001 );

    specparam tCYC = 0.4234;
    specparam tCKH = 0.0572;
    specparam tCKL = 0.0871;
    specparam tCS = 0.0822;
    specparam tCH = 0.0685;
    specparam tWS = 0.0677;
    specparam tWH = 0.0677;
    specparam tAS = 0.0710;
    specparam tAH = 0.0686;
    specparam tDS = 0.0535;
    specparam tDH = 0.1065;
    specparam tCD = 0.3655;
`ifdef TSMC_CM_READ_X_SQUASHING
    specparam tHOLD = 0.3655;
`else    
    specparam tHOLD = 0.2965;
`endif    
    specparam tQH = 0.0000;

    specparam tSDWK = 3.7356;
    specparam tSDWK2CLK = 3.7356;
    specparam tSD = 0.4234;
    specparam tXSD = 0.1815;
    specparam tSDX = 0.0930;
    specparam tSDQ = 0.4130;
    specparam tSDQH = 0.0000;
    specparam tSLPWK = 0.3535;
    specparam tSLPWK2CLK = 0.3535;
    specparam tSLP = 0.4234;
    specparam tXSLP = 0.1815;
    specparam tSLPX = 0.3614;
    specparam tSLPQ = 0.3063;
    specparam tSLPQH = 0.0000;

    specparam tBWS = 0.0535;
    specparam tBWH = 0.1064;




    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[0] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[1] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[2] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[3] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[4] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[5] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[6] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[7] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[8] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[9] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[10] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[11] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[12] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[13] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[14] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);
    if(!SD & !SLP & !CEB & WEB) (posedge CLK => (Q[15] : 1'bx)) = (tCD, tCD, tHOLD, tCD, tHOLD, tCD);


    (posedge SD => (Q[0] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[0] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[1] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[1] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[2] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[2] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[3] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[3] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[4] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[4] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[5] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[5] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[6] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[6] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[7] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[7] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[8] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[8] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[9] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[9] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[10] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[10] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[11] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[11] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[12] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[12] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[13] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[13] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[14] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[14] : 1'bx)) = (0,0,tQH,0,tQH,0);
    (posedge SD => (Q[15] : 1'bx)) = (0,tSDQ,tSDQH,0,tSDQH,tSDQ);
    (negedge SD => (Q[15] : 1'bx)) = (0,0,tQH,0,tQH,0);


    if(!SD) (posedge SLP => (Q[0] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[0] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[1] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[1] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[2] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[2] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[3] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[3] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[4] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[4] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[5] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[5] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[6] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[6] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[7] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[7] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[8] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[8] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[9] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[9] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[10] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[10] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[11] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[11] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[12] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[12] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[13] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[13] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[14] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[14] : 1'bx)) = (0,0,tQH,0,tQH,0);
    if(!SD) (posedge SLP => (Q[15] : 1'bx)) = (0,tSLPQ,tSLPQH,0,tSLPQH,tSLPQ);
    if(!SD) (negedge SLP => (Q[15] : 1'bx)) = (0,0,tQH,0,tQH,0);

    $setuphold(negedge CEB, negedge SD, tSDWK,0, notify_sd);
    $setuphold(posedge CEB, posedge SD, 0,tSD, notify_sd);
    $setuphold(posedge CLK &&& check_noidle, negedge SD, tSDWK2CLK,0, notify_sd);
    $setuphold(negedge CEB, negedge SLP, tSLPWK,0, notify_slp);
    $setuphold(posedge CEB, posedge SLP, 0,tSLP, notify_slp);
    $setuphold(posedge CLK &&& check_noidle, negedge SLP, tSLPWK2CLK,0, notify_slp);

    $period(posedge CLK &&& ~CEB, tCYC, notify_clk);
    $width(posedge CLK &&& ~CEB, tCKH, 0, notify_clk);
    $width(negedge CLK &&& ~CEB, tCKL, 0, notify_clk);

    $setuphold(posedge CLK &&& check_nopd, negedge CEB, tCS, tCH, notify_ceb);
    $setuphold(posedge CLK &&& check_nopd, posedge CEB, tCS, tCH, notify_ceb);
    $setuphold(posedge CLK &&& check_noidle, negedge WEB, tWS, tWH, notify_web);
    $setuphold(posedge CLK &&& check_noidle, posedge WEB, tWS, tWH, notify_web);

    $setuphold(posedge CLK &&& check_noidle, negedge A[0], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, negedge A[1], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, negedge A[2], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, negedge A[3], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, negedge A[4], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, negedge A[5], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, negedge A[6], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, negedge A[7], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, negedge A[8], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, negedge A[9], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, posedge A[0], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, posedge A[1], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, posedge A[2], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, posedge A[3], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, posedge A[4], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, posedge A[5], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, posedge A[6], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, posedge A[7], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, posedge A[8], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_noidle, posedge A[9], tAS, tAH, notify_addr);
    $setuphold(posedge CLK &&& check_write, negedge D[0], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[1], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[2], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[3], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[4], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[5], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[6], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[7], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[8], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[9], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[10], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[11], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[12], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[13], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[14], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge D[15], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[0], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[1], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[2], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[3], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[4], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[5], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[6], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[7], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[8], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[9], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[10], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[11], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[12], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[13], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[14], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, posedge D[15], tDS, tDH, notify_din);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[0], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[1], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[2], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[3], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[4], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[5], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[6], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[7], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[8], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[9], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[10], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[11], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[12], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[13], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[14], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, negedge BWEB[15], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[0], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[1], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[2], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[3], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[4], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[5], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[6], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[7], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[8], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[9], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[10], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[11], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[12], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[13], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[14], tBWS, tBWH, notify_bweb);
    $setuphold(posedge CLK &&& check_write, posedge BWEB[15], tBWS, tBWH, notify_bweb);





    $setuphold(edge[0x] CLK_i , posedge SD, tSDX, 0, notify_clk);
    $setuphold(edge[1x] CLK_i , posedge SD, tSDX, 0, notify_clk);
    $setuphold(edge[x0] CLK_i , negedge SD, 0, tXSD, notify_clk);
    $setuphold(edge[x1] CLK_i , negedge SD, 0, tXSD, notify_clk);
    $setuphold(edge[0x] SLP_i , posedge SD, tSDX, 0, notify_clk);
    $setuphold(edge[1x] SLP_i , posedge SD, tSDX, 0, notify_clk);
    $setuphold(edge[x0] SLP_i , negedge SD, 0, tXSD, notify_clk);
    $setuphold(edge[x1] SLP_i , negedge SD, 0, tXSD, notify_clk);
    $setuphold (edge[0x] RTSEL_i[0], posedge SD, tSDX, 0, notify_clk);
    $setuphold (edge[1x] RTSEL_i[0], posedge SD, tSDX, 0, notify_clk);
    $setuphold (edge[x0] RTSEL_i[0], negedge SD, 0, tXSD, notify_clk);
    $setuphold (edge[x1] RTSEL_i[0], negedge SD, 0, tXSD, notify_clk);
    $setuphold (edge[0x] RTSEL_i[1], posedge SD, tSDX, 0, notify_clk);
    $setuphold (edge[1x] RTSEL_i[1], posedge SD, tSDX, 0, notify_clk);
    $setuphold (edge[x0] RTSEL_i[1], negedge SD, 0, tXSD, notify_clk);
    $setuphold (edge[x1] RTSEL_i[1], negedge SD, 0, tXSD, notify_clk);
    $setuphold (edge[0x] WTSEL_i[0], posedge SD, tSDX, 0, notify_clk);
    $setuphold (edge[1x] WTSEL_i[0], posedge SD, tSDX, 0, notify_clk);
    $setuphold (edge[x0] WTSEL_i[0], negedge SD, 0, tXSD, notify_clk);
    $setuphold (edge[x1] WTSEL_i[0], negedge SD, 0, tXSD, notify_clk);
    $setuphold (edge[0x] WTSEL_i[1], posedge SD, tSDX, 0, notify_clk);
    $setuphold (edge[1x] WTSEL_i[1], posedge SD, tSDX, 0, notify_clk);
    $setuphold (edge[x0] WTSEL_i[1], negedge SD, 0, tXSD, notify_clk);
    $setuphold (edge[x1] WTSEL_i[1], negedge SD, 0, tXSD, notify_clk);
    
    $setuphold(edge[0x] A_i[0] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[1x] A_i[0] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[x0] A_i[0] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[x1] A_i[0] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[0x] A_i[1] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[1x] A_i[1] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[x0] A_i[1] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[x1] A_i[1] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[0x] A_i[2] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[1x] A_i[2] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[x0] A_i[2] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[x1] A_i[2] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[0x] A_i[3] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[1x] A_i[3] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[x0] A_i[3] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[x1] A_i[3] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[0x] A_i[4] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[1x] A_i[4] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[x0] A_i[4] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[x1] A_i[4] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[0x] A_i[5] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[1x] A_i[5] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[x0] A_i[5] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[x1] A_i[5] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[0x] A_i[6] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[1x] A_i[6] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[x0] A_i[6] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[x1] A_i[6] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[0x] A_i[7] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[1x] A_i[7] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[x0] A_i[7] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[x1] A_i[7] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[0x] A_i[8] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[1x] A_i[8] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[x0] A_i[8] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[x1] A_i[8] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[0x] A_i[9] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[1x] A_i[9] , posedge SD, tSDX, 0, notify_addr);
    $setuphold(edge[x0] A_i[9] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[x1] A_i[9] , negedge SD, 0, tXSD, notify_addr);
    $setuphold(edge[0x] D_i[0] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[0] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[0] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[0] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[0] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[0] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[0] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[0] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[1] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[1] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[1] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[1] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[1] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[1] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[1] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[1] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[2] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[2] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[2] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[2] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[2] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[2] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[2] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[2] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[3] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[3] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[3] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[3] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[3] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[3] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[3] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[3] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[4] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[4] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[4] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[4] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[4] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[4] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[4] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[4] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[5] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[5] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[5] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[5] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[5] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[5] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[5] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[5] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[6] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[6] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[6] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[6] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[6] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[6] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[6] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[6] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[7] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[7] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[7] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[7] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[7] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[7] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[7] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[7] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[8] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[8] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[8] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[8] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[8] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[8] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[8] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[8] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[9] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[9] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[9] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[9] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[9] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[9] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[9] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[9] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[10] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[10] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[10] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[10] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[10] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[10] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[10] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[10] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[11] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[11] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[11] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[11] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[11] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[11] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[11] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[11] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[12] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[12] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[12] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[12] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[12] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[12] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[12] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[12] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[13] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[13] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[13] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[13] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[13] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[13] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[13] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[13] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[14] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[14] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[14] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[14] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[14] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[14] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[14] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[14] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] D_i[15] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[1x] D_i[15] , posedge SD, tSDX, 0, notify_din);
    $setuphold(edge[x0] D_i[15] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[x1] D_i[15] , negedge SD, 0, tXSD, notify_din);
    $setuphold(edge[0x] BWEB_i[15] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[15] , posedge SD, tSDX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[15] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[x1] BWEB_i[15] , negedge SD, 0, tXSD, notify_bweb);
    $setuphold(edge[0x] CEB_i , posedge SD, tSDX, 0, notify_ceb);
    $setuphold(edge[1x] CEB_i , posedge SD, tSDX, 0, notify_ceb);
    $setuphold(edge[x0] CEB_i , negedge SD, 0, tXSD, notify_ceb);
    $setuphold(edge[x1] CEB_i , negedge SD, 0, tXSD, notify_ceb);
    $setuphold(edge[0x] WEB_i , posedge SD, tSDX, 0, notify_web);
    $setuphold(edge[1x] WEB_i , posedge SD, tSDX, 0, notify_web);
    $setuphold(edge[x0] WEB_i , negedge SD, 0, tXSD, notify_web);
    $setuphold(edge[x1] WEB_i , negedge SD, 0, tXSD, notify_web);

    $setuphold(edge[0x] CLK_i &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_clk);
    $setuphold(edge[1x] CLK_i &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_clk);
    $setuphold(edge[x0] CLK_i &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_clk);
    $setuphold(edge[x1] CLK_i &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_clk);
    $setuphold (edge[0x] RTSEL_i[0] &&& check_nosd_nodslp, posedge SLP, tSLPX, 0, notify_clk);
    $setuphold (edge[1x] RTSEL_i[0] &&& check_nosd_nodslp, posedge SLP, tSLPX, 0, notify_clk);
    $setuphold (edge[x0] RTSEL_i[0] &&& check_nosd_nodslp, negedge SLP, 0, tXSLP, notify_clk);
    $setuphold (edge[x1] RTSEL_i[0] &&& check_nosd_nodslp, negedge SLP, 0, tXSLP, notify_clk);
    $setuphold (edge[0x] RTSEL_i[1] &&& check_nosd_nodslp, posedge SLP, tSLPX, 0, notify_clk);
    $setuphold (edge[1x] RTSEL_i[1] &&& check_nosd_nodslp, posedge SLP, tSLPX, 0, notify_clk);
    $setuphold (edge[x0] RTSEL_i[1] &&& check_nosd_nodslp, negedge SLP, 0, tXSLP, notify_clk);
    $setuphold (edge[x1] RTSEL_i[1] &&& check_nosd_nodslp, negedge SLP, 0, tXSLP, notify_clk);
    $setuphold (edge[0x] WTSEL_i[0] &&& check_nosd_nodslp, posedge SLP, tSLPX, 0, notify_clk);
    $setuphold (edge[1x] WTSEL_i[0] &&& check_nosd_nodslp, posedge SLP, tSLPX, 0, notify_clk);
    $setuphold (edge[x0] WTSEL_i[0] &&& check_nosd_nodslp, negedge SLP, 0, tXSLP, notify_clk);
    $setuphold (edge[x1] WTSEL_i[0] &&& check_nosd_nodslp, negedge SLP, 0, tXSLP, notify_clk);
    $setuphold (edge[0x] WTSEL_i[1] &&& check_nosd_nodslp, posedge SLP, tSLPX, 0, notify_clk);
    $setuphold (edge[1x] WTSEL_i[1] &&& check_nosd_nodslp, posedge SLP, tSLPX, 0, notify_clk);
    $setuphold (edge[x0] WTSEL_i[1] &&& check_nosd_nodslp, negedge SLP, 0, tXSLP, notify_clk);
    $setuphold (edge[x1] WTSEL_i[1] &&& check_nosd_nodslp, negedge SLP, 0, tXSLP, notify_clk);
    
    $setuphold(edge[0x] A_i[0] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[1x] A_i[0] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[x0] A_i[0] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[x1] A_i[0] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[0x] A_i[1] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[1x] A_i[1] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[x0] A_i[1] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[x1] A_i[1] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[0x] A_i[2] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[1x] A_i[2] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[x0] A_i[2] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[x1] A_i[2] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[0x] A_i[3] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[1x] A_i[3] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[x0] A_i[3] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[x1] A_i[3] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[0x] A_i[4] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[1x] A_i[4] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[x0] A_i[4] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[x1] A_i[4] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[0x] A_i[5] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[1x] A_i[5] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[x0] A_i[5] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[x1] A_i[5] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[0x] A_i[6] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[1x] A_i[6] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[x0] A_i[6] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[x1] A_i[6] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[0x] A_i[7] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[1x] A_i[7] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[x0] A_i[7] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[x1] A_i[7] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[0x] A_i[8] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[1x] A_i[8] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[x0] A_i[8] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[x1] A_i[8] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[0x] A_i[9] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[1x] A_i[9] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_addr);
    $setuphold(edge[x0] A_i[9] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[x1] A_i[9] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_addr);
    $setuphold(edge[0x] D_i[0] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[0] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[0] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[0] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[0] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[0] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[0] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[0] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[1] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[1] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[1] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[1] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[1] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[1] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[1] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[1] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[2] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[2] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[2] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[2] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[2] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[2] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[2] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[2] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[3] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[3] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[3] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[3] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[3] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[3] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[3] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[3] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[4] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[4] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[4] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[4] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[4] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[4] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[4] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[4] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[5] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[5] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[5] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[5] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[5] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[5] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[5] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[5] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[6] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[6] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[6] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[6] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[6] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[6] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[6] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[6] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[7] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[7] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[7] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[7] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[7] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[7] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[7] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[7] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[8] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[8] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[8] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[8] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[8] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[8] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[8] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[8] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[9] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[9] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[9] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[9] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[9] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[9] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[9] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[9] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[10] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[10] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[10] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[10] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[10] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[10] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[10] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[10] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[11] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[11] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[11] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[11] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[11] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[11] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[11] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[11] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[12] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[12] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[12] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[12] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[12] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[12] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[12] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[12] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[13] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[13] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[13] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[13] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[13] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[13] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[13] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[13] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[14] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[14] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[14] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[14] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[14] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[14] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[14] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[14] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] D_i[15] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[1x] D_i[15] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_din);
    $setuphold(edge[x0] D_i[15] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[x1] D_i[15] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_din);
    $setuphold(edge[0x] BWEB_i[15] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[1x] BWEB_i[15] &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_bweb);
    $setuphold(edge[x0] BWEB_i[15] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[x1] BWEB_i[15] &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_bweb);
    $setuphold(edge[0x] CEB_i &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_ceb);
    $setuphold(edge[1x] CEB_i &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_ceb);
    $setuphold(edge[x0] CEB_i &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_ceb);
    $setuphold(edge[x1] CEB_i &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_ceb);
    $setuphold(edge[0x] WEB_i &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_web);
    $setuphold(edge[1x] WEB_i &&& check_nosd_nodslp , posedge SLP, tSLPX, 0, notify_web);
    $setuphold(edge[x0] WEB_i &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_web);
    $setuphold(edge[x1] WEB_i &&& check_nosd_nodslp , negedge SLP, 0, tXSLP, notify_web);

endspecify
`endif    //end `ifdef UNIT_DELAY

initial begin
    read_flag = 0;
    write_flag = 0;
    idle_flag = 0;
    slp_mode = 0;
    dslp_mode=0;
    sd_mode=0;
end

 `ifdef TSMC_INITIALIZE_MEM
initial begin 
`ifdef TSMC_INITIALIZE_FORMAT_BINARY
     #(INITIAL_MEM_DELAY)  $readmemb(cdeFileInit, PRELOAD, 0, numWord-1);
`else
     #(INITIAL_MEM_DELAY)  $readmemh(cdeFileInit, PRELOAD, 0, numWord-1);
`endif
    for (i = 0; i < numWord; i = i + 1) begin
        {row_tmp, col_tmp} = i;
        MEMORY[row_tmp][col_tmp] = PRELOAD[i];
    end
end
`endif //  `ifdef TSMC_INITIALIZE_MEM
   
`ifdef TSMC_INITIALIZE_FAULT
initial begin
`ifdef TSMC_INITIALIZE_FORMAT_BINARY
     #(INITIAL_FAULT_DELAY) $readmemb(cdeFileFault, PRELOAD, 0, numWord-1);
`else
     #(INITIAL_FAULT_DELAY) $readmemh(cdeFileFault, PRELOAD, 0, numWord-1);
`endif
    for (i = 0; i < numWord; i = i + 1) begin
        {row_tmp, col_tmp} = i;
        MEMORY_FAULT[row_tmp][col_tmp] = PRELOAD[i];
    end
end
`endif //  `ifdef TSMC_INITIALIZE_FAULT


`ifdef TSMC_NO_TESTPINS_WARNING
`else
always @(CLK_i or RTSEL_i) begin
    if((RTSEL_i !== 2'b01) && ($realtime > 0) && !SLP_i && !DSLP_i && !SD_i) begin
        $display("\tError %m : input RTSEL should be set to 2'b01 at simulation time %.1f\n", $realtime);
        $display("\tError %m : Please refer the datasheet for the RTSEL setting in the different segment and mux configuration\n");
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
        Q_d = {numIOBit{1'bx}};
        xMemoryAll;
    end
end
always @(CLK_i or WTSEL_i) begin
    if((WTSEL_i !== 2'b00) && ($realtime > 0) && !SLP_i && !DSLP_i && !SD_i) begin
        $display("\tError %m : input WTSEL should be set to 2'b00 at simulation time %.1f\n", $realtime);
        $display("\tError %m : Please refer the datasheet for the WTSEL setting in the different segment and mux configuration\n");
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
        Q_d = {numIOBit{1'bx}};
        xMemoryAll;
    end
end
`endif


always @(CLK_i) begin
    if (CLK_i === 1'b1) begin
        read_flag=0;
        idle_flag=1;
        write_flag=0;
    end
    if (slp_mode === 0 && !SD_i && !DSLP_i && !SLP_i) begin
        if ((CLK_i === 1'bx || CLK_i === 1'bz) && !SD_i && !DSLP_i && !SLP_i) begin
`ifdef no_warning
`else
            $display("\tWarning %m : input CLK unknown/high-Z at simulation time %.1f\n", $realtime);
`endif
`ifdef UNIT_DELAY
            #(SRAM_DELAY);
`endif
            Q_d = {numIOBit{1'bx}};
            xMemoryAll;
        end
        else if ((CLK_i===1) &&(clk_latch===0) && !SD_i && !DSLP_i && !SLP_i) begin    //posedge
            iRowAddr = iA[numWordAddr-1:numCMAddr];
            iColAddr = iA[numCMAddr-1:0];
            if (iCEB === 1'b0) begin
                idle_flag = 0;
                if (iWEB === 1'b1) begin        // read
                        read_flag = 1;
                        if ( ^iA === 1'bx ) begin
`ifdef no_warning
`else
                            $display("\tWarning %m : input A unknown/high-Z in read cycle at simulation time %.1f\n", $realtime);
`endif
`ifdef UNIT_DELAY
                            #(SRAM_DELAY);
`endif
                            Q_d = {numIOBit{1'bx}};
                        //xMemoryAll;
                        end 
                        else if (iA >= numWord) begin
`ifdef no_warning
`else
                            $display("\tWarning %m : address exceed word depth in read cycle at simulation time %.1f\n", $realtime);
`endif
`ifdef UNIT_DELAY
                            #(SRAM_DELAY);
`endif
                            Q_d = {numIOBit{1'bx}};
                        end
                        else begin
`ifdef UNIT_DELAY
                            #(SRAM_DELAY);
    `ifdef TSMC_INITIALIZE_FAULT
                            Q_d = (MEMORY[iRowAddr][iColAddr] ^ MEMORY_FAULT[iRowAddr][iColAddr]);
    `else
                            Q_d =  MEMORY[iRowAddr][iColAddr];
    `endif
`else
  `ifdef TSMC_INITIALIZE_FAULT
                            Q_d = {numBit{1'bx}};    //transition to x first
                            #0.001 Q_d = (MEMORY[iRowAddr][iColAddr] ^ MEMORY_FAULT[iRowAddr][iColAddr]);
  `else
                            Q_d = {numBit{1'bx}};    //transition to x first
                            #0.001 Q_d =  MEMORY[iRowAddr][iColAddr];
  `endif
`endif
                        end // else: !if(iA >= numWord)
                end // if (iWEB === 1'b1)
                else if (iWEB === 1'b0) begin    // write
                    if ( ^iA === 1'bx ) begin
`ifdef no_warning
`else
                        $display("\tWarning %m : input A unknown/high-Z in write cycle at simulation time %.1f\n", $realtime);
`endif
                        xMemoryAll;
                    end 
                    else if (iA >= numWord) begin
`ifdef no_warning
`else
                        $display("\tWarning %m : address exceed word depth in write cycle at simulation time %.1f\n", $realtime);
`endif
                    end 
                    else begin
                        if ( ^iD === 1'bx ) begin
`ifdef no_warning
`else
                            $display("\tWarning %m : input D unknown/high-Z in write cycle at simulation time %.1f\n", $realtime);
`endif
                        end
                        if ( ^iBWEB === 1'bx ) begin
`ifdef no_warning
`else
                            $display("\tWarning %m : input BWEB unknown/high-Z in write cycle at simulation time %.1f\n", $realtime);
`endif
                        end
                        write_flag = 1;
                        begin
                            DIN_tmp = MEMORY[iRowAddr][iColAddr];
                            for (i = 0; i < numBit; i = i + 1) begin
                                if (iBWEB[i] === 1'b0) begin
                                    DIN_tmp[i] = iD[i];
                                end 
                                else if (iBWEB[i] === 1'bx) begin
                                    DIN_tmp[i] = 1'bx;
                                end
                            end
                            if ( isStuckAt0(iA) || isStuckAt1(iA) ) begin
                                combineErrors(iA, ERR_tmp);
                                for (j = 0; j < numBit; j = j + 1) begin
                                    if (ERR_tmp[j] === 1'b0) begin
                                        DIN_tmp[j] = 1'b0;
                                    end 
                                    else if (ERR_tmp[j] === 1'b1) begin
                                        DIN_tmp[j] = 1'b1;
                                    end
                                end
                            end
                            MEMORY[iRowAddr][iColAddr] = DIN_tmp;
                        end
                    end //end of if ( ^iA === 1'bx ) begin
                end 
                else begin
`ifdef no_warning
`else
                    $display("\tWarning %m : input WEB unknown/high-Z at simulation time %.1f\n", $realtime);
`endif
`ifdef UNIT_DELAY
                    #(SRAM_DELAY);
`endif
                    Q_d = {numIOBit{1'bx}};
                    xMemoryAll;
                end // else: !if(iWEB === 1'b0)
            end // if (iCEB === 1'b0)
            else if (iCEB === 1'b1) begin
                idle_flag = 1;
            end
            else begin    //CEB is 'x / 'Z                
`ifdef no_warning
`else
                $display("\tWarning %m : input CEB unknown/high-Z at simulation time %.1f\n", $realtime);
`endif
`ifdef UNIT_DELAY
                #(SRAM_DELAY);
`endif
                Q_d = {numIOBit{1'bx}};
                xMemoryAll;
            end // else: !if(iCEB === 1'b1)
        end // if ((CLK_i===1) &&(clk_latch===0))
    end
    clk_latch=CLK_i;    //latch CLK_i
end // always @ (CLK_i)




always @(posedge CLK_i) begin
    if (CLK_i === 1'b1) begin
        CEBL = iCEB;
        WEBL = iWEB;
    end
end

always @(SD_i or DSLP_i or SLP_i) begin
    //---- Check SD Unknown
    if ((SD_i === 1'bx || SD_i === 1'bz) && $realtime !=0) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input SD unknown/high-Z at simulation time %.1f\n", $realtime);
`endif
        slp_mode=0;
        dslp_mode=0;
        sd_mode=0;
`ifdef UNIT_DELAY
        #(SRAM_DELAY);
`endif
        Q_d={numIOBit{1'bx}};
        xMemoryAll;
    end  //  End Check SD Unknown
    //---- When entering SD mode, check if CEB is asserted or not
    else if (SLP_i===0 && DSLP_i === 0 && SD_i===1 && iCEB!==1'b1 && (sd_mode === 0)) begin
`ifdef no_warning
`else
        $display("\tWarning %m : Invalid Shut Down Mode Sequence. Input CEB 0/unknown/high-Z while entering shut down mode at simulation time %.1f", $realtime);
`endif
        slp_mode=0;
        dslp_mode=0;
        sd_mode=0;
`ifdef UNIT_DELAY
        #(SRAM_DELAY);
`endif
        Q_d={numIOBit{1'bx}};
        xMemoryAll;
    end  //  End When entering SD mode, check if CEB is asserted or not
    //---- When SD wake up, check if CEB is asserted or not
    else if ((SD_i===0  && DSLP_i === 0 && SLP_i === 0 ) && (iCEB!==1)) begin
`ifdef no_warning
`else
        if ($realtime > 0) $display("\tWarning %m : Invalid Wake Up Sequence. Input CEB is 0/unknown/high-Z while exiting shut down mode at simulation time %.1f", $realtime);
`endif
        slp_mode=0;
        dslp_mode=0;
        sd_mode=0;
`ifdef UNIT_DELAY
        #(SRAM_DELAY);
`endif
        Q_d={numIOBit{1'bx}};
        xMemoryAll;
    end  //  End When SD wake up, check if CEB is asserted or not
    //---- Power-Down Mode wake up
    else if ((SD_i===0) && (iCEB===1) && (sd_mode === 1)) begin
	sd_mode = 0;
        if(DSLP_i===0)
            dslp_mode=0;
        if(SLP_i===0)
            slp_mode=0;
        if(DSLP_i===1)
            dslp_mode=1;
        if(SLP_i===1)
            slp_mode=1;
        if(!(slp_mode === 1 || dslp_mode === 1)) begin
`ifdef UNIT_DELAY
            #(SRAM_DELAY);
`endif
            Q_d={numIOBit{1'bx}};
        end
    end  //  End Power-Down Mode wake up
    //---- Entering SD mode
    else if ((SD_i===1) && (iCEB===1) &&  (sd_mode === 0)) begin
        xMemoryAll;
        sd_mode = 1;
        if(DSLP_i===0)
            dslp_mode=0;
        if(SLP_i===0)
            slp_mode=0;
        if(DSLP_i===1)
            dslp_mode=1;
        if(SLP_i===1)
            slp_mode=1;
        if(|Q_d !== 1'b0 || !(slp_mode === 1 || dslp_mode === 1)) begin
`ifdef UNIT_DELAY
            #(SRAM_DELAY);
`endif
            Q_d={numIOBit{1'bx}};
            #0.001;
        end
        Q_d=0;
    end  //  End Entering SD mode
    //---- sd_mode initialization
    else if (sd_mode === 1'bx) begin
      sd_mode = SD_i;
    end  //  End sd_mode initialization
    if (SD_i === 1) begin
        xMemoryAll;   
    end
    //---- Check DSLP Unknown
    else if ((DSLP_i === 1'bx || DSLP_i === 1'bz) && (SD_i===0)  && $realtime !=0) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input DSLP unknown/high-Z at simulation time %.1f\n", $realtime);
`endif
        slp_mode=0;
        dslp_mode=0;
        sd_mode=0;
`ifdef UNIT_DELAY
        #(SRAM_DELAY);
`endif
        Q_d={numIOBit{1'bx}};
        xMemoryAll;
    end  //  End Check DSLP Unknown
    //---- When entering DSLP mode, check if CEB is asserted or not
    else if (SD_i === 0 && DSLP_i===1 && SLP_i===0 && iCEB!==1'b1 && (dslp_mode === 0) ) begin
`ifdef no_warning
`else
        $display("\tWarning %m : Invalid Deep Sleep Mode Sequence. Input CEB 0/unknown/high-Z while entering deep sleep mode at simulation time %.1f", $realtime);
`endif
        slp_mode=0;
        dslp_mode=0;
        sd_mode=0;
`ifdef UNIT_DELAY
        #(SRAM_DELAY);
`endif
        Q_d={numIOBit{1'bx}};
        xMemoryAll;
    end  //  End When entering DSLP mode, check if CEB is asserted or not
    //---- When DSLP wake up, check if CEB is asserted or not
    else if ((SD_i === 0 && DSLP_i===0 && SLP_i===0) && (iCEB!==1) && (dslp_mode === 1)) begin
`ifdef no_warning
`else
        if ($realtime > 0) $display("\tWarning %m : Invalid Wake Up Sequence. Input CEB is 0/unknown/high-Z while exiting deep sleep mode at simulation time %.1f", $realtime);
`endif
        slp_mode=0;
        dslp_mode=0;
        sd_mode=0;
`ifdef UNIT_DELAY
        #(SRAM_DELAY);
`endif
        Q_d={numIOBit{1'bx}};
        xMemoryAll;
    end  //  End When DSLP wake up, check if CEB is asserted or not
    //---- DSLP Wake up
    else if ((DSLP_i===0) && (iCEB===1) && (dslp_mode === 1)) begin
        dslp_mode=0;
        if(!(sd_mode === 1 || slp_mode === 1)) begin
            Q_d={numIOBit{1'bx}};
        end
    end  //  End DSLP wake up
    //---- Entering DSLP mode
    else if ((DSLP_i===1) && (iCEB===1) &&  (dslp_mode === 0)) begin
        dslp_mode=1;
        if(SLP_i===0)
            slp_mode=0;
        if(SLP_i===1)
            slp_mode=1;
        if(|Q_d !== 1'b0 || !(sd_mode === 1 || slp_mode === 1)) begin
`ifdef UNIT_DELAY
            #(SRAM_DELAY);
`endif
            Q_d={numIOBit{1'bx}};
            #0.001;
        end
        Q_d=0;
    end  //  End Entering DSLP mode
    //---- dslp_mode initialization
    else if (dslp_mode === 1'bx) begin
      dslp_mode = DSLP_i;
    end  //  End dslp_mode initialization
    //---- Check SLP Unknown
    else if ((SLP_i === 1'bx || SLP_i === 1'bz) && (DSLP_i===0) && (SD_i===0) && $realtime !=0) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input SLP unknown/high-Z at simulation time %.1f\n", $realtime);
`endif
        slp_mode=0;
        dslp_mode=0;
        sd_mode=0;
`ifdef UNIT_DELAY
        #(SRAM_DELAY);
`endif
        Q_d={numIOBit{1'bx}};
        xMemoryAll;
    end  //  End Check SLP Unknown
    //---- When entering SLP mode, check if CEB is asserted or not
    else if (SD_i === 0 && DSLP_i===0 && SLP_i===1 && iCEB!==1'b1 && (slp_mode === 0)) begin
`ifdef no_warning
`else
        $display("\tWarning %m : Invalid Sleep Mode Sequence. Input CEB 0/unknown/high-Z while entering sleep mode at simulation time %.1f", $realtime);
`endif
        slp_mode=0;
        dslp_mode=0;
        sd_mode=0;
`ifdef UNIT_DELAY
        #(SRAM_DELAY);
`endif
        Q_d={numIOBit{1'bx}};
        xMemoryAll;
    end  //  End When entering SLP mode, check if CEB is asserted or not
    //---- When SLP wake up, check if CEB is asserted or not
    else if ((SLP_i===0 && DSLP_i===0 && SLP_i===0) && (iCEB!==1) && (slp_mode === 1)) begin
`ifdef no_warning
`else
        if ($realtime > 0) $display("\tWarning %m : Invalid Wake Up Sequence. Input CEB is 0/unknown/high-Z while exiting sleep mode at simulation time %.1f", $realtime);
`endif
        slp_mode=0;
        dslp_mode=0;
        sd_mode=0;
`ifdef UNIT_DELAY
        #(SRAM_DELAY);
`endif
        Q_d={numIOBit{1'bx}};
        xMemoryAll;
    end   //  End When SLP wake up, check if CEB is asserted or not
    //---- SLP Wake up
    else if ((SLP_i===0) && (iCEB===1) && (slp_mode === 1)) begin
        slp_mode=0;
        if(!(sd_mode === 1 || dslp_mode === 1)) begin
            Q_d={numIOBit{1'bx}};
        end
    end  //  End SLP wake up
    //---- Entering SLP mode
    else if ((SLP_i===1) && (iCEB===1) &&  (slp_mode === 0)) begin
        slp_mode=1;
        if(!(sd_mode === 1 || dslp_mode === 1)) begin
`ifdef UNIT_DELAY
            #(SRAM_DELAY);
`endif
            Q_d={numIOBit{1'bx}};
            #0.001;
        end
        Q_d=0;
    end  //  End Entering SLP mode
    //---- slp_mode initialization
    else if (slp_mode === 1'bx) begin
      slp_mode = SLP_i;
    end  //  End slp_mode initialization
end


always @(posedge SD_i or posedge DSLP_i or posedge SLP_i) begin
    if (SD_i === 1'b1 && SLP === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input SLP high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && RTSEL[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input RTSEL[0] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && RTSEL[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input RTSEL[0] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && RTSEL[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input RTSEL[0] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && RTSEL[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input RTSEL[1] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && RTSEL[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input RTSEL[1] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && RTSEL[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input RTSEL[1] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && WTSEL[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WTSEL[0] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && WTSEL[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WTSEL[0] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && WTSEL[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WTSEL[0] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && WTSEL[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WTSEL[1] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && WTSEL[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WTSEL[1] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && WTSEL[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WTSEL[1] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[0] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && A[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[0] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && A[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[0] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[1] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && A[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[1] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && A[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[1] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[2] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && A[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[2] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && A[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[2] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[3] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && A[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[3] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && A[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[3] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[4] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && A[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[4] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && A[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[4] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[5] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && A[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[5] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && A[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[5] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[6] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && A[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[6] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && A[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[6] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[7] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && A[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[7] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && A[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[7] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[8] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && A[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[8] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && A[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[8] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[9] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && A[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[9] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && A[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[9] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end

    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[0] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[0] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[0] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[1] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[1] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[1] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[2] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[2] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[2] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[3] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[3] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[3] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[4] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[4] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[4] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[5] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[5] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[5] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[6] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[6] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[6] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[7] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[7] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[7] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[8] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[8] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[8] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[9] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[9] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[9] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[10] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[10] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[10] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[10] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[10] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[10] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[11] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[11] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[11] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[11] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[11] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[11] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[12] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[12] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[12] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[12] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[12] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[12] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[13] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[13] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[13] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[13] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[13] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[13] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[14] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[14] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[14] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[14] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[14] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[14] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[15] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[15] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && BWEB[15] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[15] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && BWEB[15] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[15] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end

    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[0] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[0] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[0] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[1] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[1] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[1] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[2] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[2] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[2] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[3] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[3] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[3] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[4] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[4] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[4] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[5] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[5] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[5] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[6] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[6] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[6] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[7] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[7] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[7] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[8] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[8] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[8] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[9] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[9] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[9] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[10] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[10] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[10] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[10] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[10] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[10] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[11] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[11] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[11] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[11] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[11] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[11] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[12] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[12] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[12] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[12] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[12] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[12] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[13] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[13] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[13] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[13] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[13] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[13] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[14] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[14] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[14] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[14] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[14] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[14] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[15] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[15] high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && D[15] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[15] high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && D[15] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[15] high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && CEB === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input CEB high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && CEB === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input CEB high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && CEB === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input CEB high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && WEB === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WEB high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && WEB === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WEB high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && WEB === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WEB high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end

    if (SD_i === 1'b1 && DSLP_i === 1'b0 && SLP_i === 1'b0 && CLK === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input CLK high-Z during Shut Down Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b1 && SLP_i === 1'b0 && CLK === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input CLK high-Z during DSLP Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    else if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b1 && CLK === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input CLK high-Z during Sleep Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
end
always @(negedge SD_i or negedge DSLP_i or negedge SLP_i) begin
    if (SD_i === 1'b1 && SLP === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input SLP high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && RTSEL[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input RTSEL[0] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && RTSEL[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input RTSEL[1] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && WTSEL[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WTSEL[0] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && WTSEL[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WTSEL[1] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end

    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[0] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[1] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[2] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[3] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[4] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[5] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[6] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[7] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[8] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && A[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input A[9] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end

    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[0] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[1] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[2] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[3] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[4] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[5] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[6] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[7] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[8] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[9] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[10] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[10] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[11] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[11] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[12] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[12] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[13] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[13] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[14] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[14] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && BWEB[15] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input BWEB[15] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end

    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[0] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[0] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[1] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[1] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[2] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[2] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[3] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[3] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[4] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[4] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[5] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[5] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[6] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[6] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[7] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[7] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[8] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[8] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[9] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[9] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[10] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[10] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[11] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[11] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[12] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[12] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[13] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[13] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[14] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[14] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && D[15] === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input D[15] high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && CEB === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input CEB high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && WEB === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input WEB high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end

    if (SD_i === 1'b0 && DSLP_i === 1'b0 && SLP_i === 1'b0 && CLK === 1'bz) begin
`ifdef no_warning
`else
        $display("\tWarning %m : input CLK high-Z during Wake Up Mode, Core Unknown at %t.>>", $realtime);
`endif
`ifdef UNIT_DELAY
    #(SRAM_DELAY);
`endif
      Q_d = {numIOBit{1'bx}};
      xMemoryAll;
    end
end

`ifdef UNIT_DELAY
`else
always @(notify_sd) begin
    Q_d = {numIOBit{1'bx}};
    xMemoryAll;
end
always @(notify_slp) begin
    Q_d = {numIOBit{1'bx}};
    xMemoryAll;
end


always @(notify_clk) begin
    Q_d = {numIOBit{1'bx}};
    xMemoryAll;
end
always @(notify_bist) begin
    Q_d = {numIOBit{1'bx}};
    xMemoryAll;
end
always @(notify_ceb) begin
    Q_d = {numIOBit{1'bx}};
    xMemoryAll;
    read_flag = 0;
    write_flag = 0;
end
always @(notify_web) begin
    Q_d = {numIOBit{1'bx}};
    xMemoryAll;
    read_flag = 0;
    write_flag = 0;
end
always @(notify_addr) begin
    if (iWEB === 1'b1) begin
        Q_d = {numIOBit{1'bx}};
    end
    else if (iWEB === 1'b0) begin
        xMemoryAll;
    end
    else begin
        Q_d = {numIOBit{1'bx}};
    xMemoryAll;
    end
    read_flag = 0;
    write_flag = 0;
end
always @(notify_din) begin
    if ( ^iA === 1'bx ) begin
        xMemoryAll;
    end
    else begin
        xMemoryWord(iA);
    end
    write_flag = 0;
end
always @(notify_bweb) begin
    if ( ^iA === 1'bx ) begin
        xMemoryAll;
    end
    else begin
        xMemoryWord(iA);
    end
    write_flag = 0;
end

`endif    //end `ifdef UNIT_DELAY


task xMemoryAll;
reg [numRowAddr-1:0] row;
reg [numCMAddr-1:0] col;
reg [numRowAddr:0] row_index;
reg [numCMAddr:0] col_index;
begin
    for (row_index = 0; row_index <= numRow-1; row_index = row_index + 1) begin
        for (col_index = 0; col_index <= numCM-1; col_index = col_index + 1) begin
            row=row_index;
            col=col_index;
            MEMORY[row][col] = {numBit{1'bx}};
        end
    end
end
endtask

task zeroMemoryAll;
reg [numRowAddr-1:0] row;
reg [numCMAddr-1:0] col;
reg [numRowAddr:0] row_index;
reg [numCMAddr:0] col_index;
begin
    for (row_index = 0; row_index <= numRow-1; row_index = row_index + 1) begin
        for (col_index = 0; col_index <= numCM-1; col_index = col_index + 1) begin
            row=row_index;
            col=col_index;
            MEMORY[row][col] = {numBit{1'b0}};
        end
    end
end
endtask

task xMemoryWord;
input [numWordAddr-1:0] addr;
reg [numRowAddr-1:0] row;
reg [numCMAddr-1:0] col;
begin
    {row, col} = addr;
    MEMORY[row][col] = {numBit{1'bx}};
end
endtask

task preloadData;
input [256*8:1] infile;  // Max 256 character File Name
reg [numWordAddr:0] w;
reg [numWordAddr-numCMAddr-1:0] row;
reg [numCMAddr-1:0] col;
begin
`ifdef no_warning
`else
    $display("Preloading data from file %s", infile);
`endif
`ifdef TSMC_INITIALIZE_FORMAT_BINARY
        $readmemb(infile, PRELOAD);
`else
        $readmemh(infile, PRELOAD);
`endif
    for (w = 0; w < numWord; w = w + 1) begin
        {row, col} = w;
        {row, col} = w;
        MEMORY[row][col] = PRELOAD[w];
    end
end
endtask

/*
 * task injectSA - to inject a stuck-at error, please use hierarchical reference to call the injectSA task from the wrapper module
 *      input addr - the address location where the defect is to be introduced
 *      input bit - the bit location of the specified address where the defect is to occur
 *      input type - specify whether it's a s-a-0 (type = 0) or a s-a-1 (type = 1) fault
 *
 *      Multiple faults can be injected at the same address, regardless of the type.  This means that an address location can have 
 *      certain bits having stuck-at-0 faults while other bits have the stuck-at-1 defect.
 *
 * Examples:
 *      injectSA(0, 0, 0);  - injects a s-a-0 fault at address 0, bit 0
 *      injectSA(1, 0, 1);  - injects a s-a-1 fault at address 1, bit 0
 *      injectSA(1, 1, 0);  - injects a s-a-0 fault at address 1, bit 1
 *      injectSA(1, 2, 1);  - injects a s-a-1 fault at address 1, bit 2
 *      injectSA(1, 3, 1);  - injects a s-a-1 fault at address 1, bit 3
 *      injectSA(2, 2, 1);  - injects a s-a-1 fault at address 2, bit 2
 *      injectSA(14, 2, 0); - injects a s-a-0 fault at address 14, bit 2
 *
 */
task injectSA;
input [numWordAddr-1:0] addr;
input integer bitn;
input typen;
reg [numStuckAt:0] i;
reg [numBit-1:0] btmp;
begin
    j=bitn;
    if ( typen === 0 ) begin
        for (i = 0; i < numStuckAt; i = i + 1) begin
            if ( ^stuckAt0Addr[i] === 1'bx ) begin
                stuckAt0Addr[i] = addr;
                btmp = {numBit{1'bx}};
                btmp[j] = 1'b0;
                stuckAt0Bit[i] = btmp;
                i = numStuckAt;
`ifdef no_warning
`else
                $display("First s-a-0 error injected at address location %d = %b", addr, btmp);
`endif
                i = numStuckAt;
            end
            else if ( stuckAt0Addr[i] === addr ) begin
                btmp = stuckAt0Bit[i];
                btmp[j] = 1'b0;
                stuckAt0Bit[i] = btmp;
`ifdef no_warning
`else
                $display("More s-a-0 Error injected at address location %d = %b", addr, btmp);
`endif
                i = numStuckAt;
            end        
        end
    end
    else if (typen === 1) begin
        for (i = 0; i < numStuckAt; i = i + 1) begin
            if ( ^stuckAt1Addr[i] === 1'bx ) begin
                stuckAt1Addr[i] = addr;
                btmp = {numBit{1'bx}};
                btmp[j] = 1'b1;
                stuckAt1Bit[i] = btmp;
                i = numStuckAt;
`ifdef no_warning
`else
                $display("First s-a-1 error injected at address location %d = %b", addr, btmp);
`endif
                i = numStuckAt;
            end
            else if ( stuckAt1Addr[i] === addr ) begin
                btmp = stuckAt1Bit[i];
                btmp[j] = 1'b1;
                stuckAt1Bit[i] = btmp;
`ifdef no_warning
`else
                $display("More s-a-1 Error injected at address location %d = %b", addr, btmp);
`endif
                i = numStuckAt;
            end        
        end
    end
end
endtask

task combineErrors;
input [numWordAddr-1:0] addr;
output [numBit-1:0] errors;
integer j;
reg [numBit-1:0] btmp;
begin
    errors = {numBit{1'bx}};
    if ( isStuckAt0(addr) ) begin
        btmp = stuckAt0Bit[getStuckAt0Index(addr)];
        for ( j = 0; j < numBit; j = j + 1 ) begin
            if ( btmp[j] === 1'b0 ) begin
                errors[j] = 1'b0;
            end
        end
    end
    if ( isStuckAt1(addr) ) begin
        btmp = stuckAt1Bit[getStuckAt1Index(addr)];
        for ( j = 0; j < numBit; j = j + 1 ) begin
            if ( btmp[j] === 1'b1 ) begin
                errors[j] = 1'b1;
            end
        end
    end
end
endtask

function [numStuckAt-1:0] getStuckAt0Index;
input [numWordAddr-1:0] addr;
reg [numStuckAt:0] i;
begin
    for (i = 0; i < numStuckAt; i = i + 1) begin
        if (stuckAt0Addr[i] === addr) begin
            getStuckAt0Index = i;
        end
    end
end
endfunction

function [numStuckAt-1:0] getStuckAt1Index;
input [numWordAddr-1:0] addr;
reg [numStuckAt:0] i;
begin
    for (i = 0; i < numStuckAt; i = i + 1) begin
        if (stuckAt1Addr[i] === addr) begin
            getStuckAt1Index = i;
        end
    end
end
endfunction

function isStuckAt0;
input [numWordAddr-1:0] addr;
reg [numStuckAt:0] i;
reg flag;
begin
    flag = 0;
    for (i = 0; i < numStuckAt; i = i + 1) begin
        if (stuckAt0Addr[i] === addr) begin
            flag = 1;
            i = numStuckAt;
        end
    end
    isStuckAt0 = flag;
end
endfunction


function isStuckAt1;
input [numWordAddr-1:0] addr;
reg [numStuckAt:0] i;
reg flag;
begin
    flag = 0;
    for (i = 0; i < numStuckAt; i = i + 1) begin
        if (stuckAt1Addr[i] === addr) begin
            flag = 1;
            i = numStuckAt;
        end
    end
    isStuckAt1 = flag;
end
endfunction

task printMemory;
reg [numRowAddr-1:0] row;
reg [numCMAddr-1:0] col;
reg [numRowAddr:0] row_index;
reg [numCMAddr:0] col_index;
reg [numBit-1:0] temp;
begin
    $display("\n\nDumping memory content at %.1f...\n", $realtime);
    for (row_index = 0; row_index <= numRow-1; row_index = row_index + 1) begin
        for (col_index = 0; col_index <= numCM-1; col_index = col_index + 1) begin
             row=row_index;
            col=col_index;
            $display("[%d] = %b", {row, col}, MEMORY[row][col]);
        end
    end    
    $display("\n\n");
end
endtask

task printMemoryFromTo;
input [numWordAddr-1:0] addr1;
input [numWordAddr-1:0] addr2;
reg [numWordAddr:0] addr;
reg [numRowAddr-1:0] row;
reg [numCMAddr-1:0] col;
reg [numBit-1:0] temp;
begin
    $display("\n\nDumping memory content at %.1f...\n", $realtime);
    for (addr = addr1; addr < addr2; addr = addr + 1) begin
        {row, col} = addr;
        $display("[%d] = %b", addr, MEMORY[row][col]);
    end    
    $display("\n\n");
end
endtask


endmodule
`endcelldefine
