module ddr4_mig(
    //Clocks
    clk_i_p, 
    clk_i_n,
    ui_clk,

    // Resets
    rst_i, 
    ui_rst,
    

    // Run-time Simple Bus
    r_read,
    r_write,
    r_address,
    r_wrdata,
    r_wrstrb,
    r_rdvalid,
    r_rddata,
    r_rdaddress,
    r_ready,

    // IO
    ddr_reset_n,ddr_ck_c,ddr_ck_t,ddr_cke,ddr_cs_n,
    ddr_dm,ddr_ba,ddr_bg,ddr_addr,ddr_dq,ddr_dqs_c,ddr_dqs_t,ddr_act_n,ddr_odt
); 
   
   
    parameter USER_ADDR_WIDTH = 32;
    parameter USER_MASK_WIDTH = 64;
    parameter USER_DATA_WIDTH = 512;

    parameter CKE_BITS = 1;
    parameter CK_BITS = 1;
    parameter CS_BITS = 1;
    parameter DDR_BA_WIDTH = 2;
    parameter DDR_BG_WIDTH = 2;
    parameter DDR_ADDR_BITS = 17;
    parameter ODT_BITS = 1;
    parameter DM_BITS = 8;
    parameter DQS_BITS = 8;
    parameter DQ_BITS = 64;

    localparam USER_ADDR_BITS = USER_ADDR_WIDTH;
    localparam USER_MASK_BITS = USER_MASK_WIDTH;
    localparam USER_DATA_BITS = USER_DATA_WIDTH;
    
    
   input clk_i_p; 
   input clk_i_n; 
    output ui_clk;

    // Resets
    input rst_i;
    output ui_rst;

    // Run-time Bus
    input r_read;
    input r_write;
    input [USER_ADDR_BITS-1:0] r_address;
    input [USER_DATA_BITS-1:0] r_wrdata;
    input [USER_MASK_BITS-1:0] r_wrstrb;
    output r_rdvalid;
    output [USER_DATA_BITS-1:0] r_rddata;
    output reg  [USER_ADDR_BITS-1:0] r_rdaddress;
    output r_ready;
    

        // IO
    output ddr_reset_n; output [CKE_BITS-1:0] ddr_cke; output [CK_BITS-1:0] ddr_ck_c; output [CK_BITS-1:0]  ddr_ck_t;
    output [CS_BITS-1:0] ddr_cs_n; output ddr_act_n;
    output [DDR_BA_WIDTH-1:0] ddr_ba; output [DDR_BG_WIDTH-1:0] ddr_bg;output [DDR_ADDR_BITS-1:0] ddr_addr; output [ODT_BITS-1:0] ddr_odt; output [DM_BITS-1:0] ddr_dm;
    inout [DQS_BITS-1:0] ddr_dqs_c; inout [DQS_BITS-1:0] ddr_dqs_t; inout [DQ_BITS-1:0] ddr_dq;



    wire app_rdy;
    wire app_wdf_rdy;
    wire app_rd_data_end;
    wire app_wdf_end;
    wire [2:0] app_cmd;
    wire bank_busy;

    assign r_ready = !( !app_rdy || (r_write && (!app_wdf_rdy)));
    assign app_cmd = r_write ? 3'b000 : 3'b001;
    assign app_wdf_end = r_write & r_ready;


    ddr4_0 uut
      (
       .sys_rst                (rst_i),
       .c0_sys_clk_p           (clk_i_p),
       .c0_sys_clk_n           (clk_i_n),
       .c0_ddr4_act_n          (ddr_act_n),
       .c0_ddr4_adr            (ddr_addr),
       .c0_ddr4_ba             (ddr_ba),
       .c0_ddr4_bg             (ddr_bg),
       .c0_ddr4_cke            (ddr_cke),
       .c0_ddr4_odt            (ddr_odt),
       .c0_ddr4_cs_n           (ddr_cs_n),
       .c0_ddr4_ck_t           (ddr_ck_t),
       .c0_ddr4_ck_c           (ddr_ck_c),
       .c0_ddr4_reset_n        (ddr_reset_n),
       .c0_ddr4_dm_dbi_n       (ddr_dm),
       .c0_ddr4_dq             (ddr_dq),
       .c0_ddr4_dqs_c          (ddr_dqs_c),
       .c0_ddr4_dqs_t          (ddr_dqs_t),
       
       .c0_ddr4_ui_clk         (ui_clk),
       .c0_ddr4_ui_clk_sync_rst         (ui_rst),
       .c0_init_calib_complete(),

       .c0_ddr4_app_addr(r_address),
       .c0_ddr4_app_cmd(app_cmd),
       .c0_ddr4_app_en((r_read || r_write) && r_ready),
       .c0_ddr4_app_hi_pri(0),
       .c0_ddr4_app_wdf_data(r_wrdata),
       .c0_ddr4_app_wdf_end(app_wdf_end),
       .c0_ddr4_app_wdf_mask(r_wrstrb),
       .c0_ddr4_app_wdf_wren(r_write & r_ready),
       .c0_ddr4_app_rd_data(r_rddata),
       .c0_ddr4_app_rd_data_end(app_rd_data_end),
       .c0_ddr4_app_rd_data_valid(r_rdvalid),
       .c0_ddr4_app_rdy(app_rdy),
       .c0_ddr4_app_wdf_rdy(app_wdf_rdy)
       );   
  endmodule