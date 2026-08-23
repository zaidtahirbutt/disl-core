module tb_top;

    reg clk_i;
    initial clk_i = 0;
    always #5000 clk_i = ~clk_i;
    

	wire ddr_reset_n; wire [CKE_BITS-1:0] ddr_cke; wire [CK_BITS-1:0] ddr_ck_p; wire [CK_BITS-1:0]  ddr_ck_n;
	wire [CS_BITS-1:0] ddr_cs_n; wire ddr_ras_n; wire ddr_cas_n; wire ddr_we_n;
	wire [BA_BITS-1:0] ddr_ba; wire [ADDR_BITS-1:0] ddr_addr; wire [ODT_BITS-1:0] ddr_odt; wire [DM_BITS-1:0] ddr_dm;
	wire [DQS_BITS-1:0] ddr_dqs_p; wire [DQS_BITS-1:0] ddr_dqs_n; wire [DQ_BITS-1:0] ddr_dq;
    
 

   ddr3 sdramddr3_0 (
        .ddr3_reset_n(ddr_reset_n),
        .ddr3_ck_p(ddr_ck_p),
        .ddr3_ck_n(ddr_ck_n),
        .ddr3_cke(ddr_cke),
        .ddr3_cs_n(ddr_cs_n),
        .ddr3_ras_n(ddr_ras_n),
        .ddr3_cas_n(ddr_cas_n),
        .ddr3_we_n(ddr_we_n),
        .ddr3_dm(ddr_dm),
        .ddr3_ba(ddr_ba),
        .ddr3_addr(ddr_addr),
        .ddr3_dq(ddr_dq),
        .ddr3_dqs_p(ddr_dqs_p),
        .ddr3_dqs_n(ddr_dqs_n),
        .ddr3_odt(ddr_odt)
    );



