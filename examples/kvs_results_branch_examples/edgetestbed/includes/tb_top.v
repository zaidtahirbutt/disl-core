`timescale 1ps/1ps
module tb_top;
	
    reg clk_i;
    initial clk_i = 0;
    always #5000 clk_i = ~clk_i;

    wire uart_tx;
    wire uart_rx = 1'b1;
    wire [3:0] led;
    reg [3:0] sw;

    	initial begin
		sw[0] = 1;
		sw[2] = 0;
	#100000;
		sw[0] = 0;
	end

	initial begin
		sw[3:1] = 1'b0;
		#130_000_000;
		sw[1] = 1'b1;
		#200_000_000;
		sw[1] = 1'b0;  
	end

    always #1000_000 sw[2] = sw[1] | (~sw[2]); 


	wire ddr3_reset_n; wire [1-1:0] ddr3_cke; wire [1-1:0] ddr3_ck_p; wire [1-1:0]  ddr3_ck_n;
	wire [1-1:0] ddr3_cs_n; wire ddr3_ras_n; wire ddr3_cas_n; wire ddr3_we_n;
	wire [3-1:0] ddr3_ba; wire [14-1:0] ddr3_addr; wire [1-1:0] ddr3_odt; wire [2-1:0] ddr3_dm;
	wire [2-1:0] ddr3_dqs_p; wire [2-1:0] ddr3_dqs_n; wire [16-1:0] ddr3_dq;
    
   ddr3 sdramddr3_0 (
        ddr3_reset_n,
        ddr3_ck_p,
        ddr3_ck_n,
        ddr3_cke,
        ddr3_cs_n,
        ddr3_ras_n,
        ddr3_cas_n,
        ddr3_we_n,
        ddr3_dm,
        ddr3_ba,
        ddr3_addr,
        ddr3_dq,
        ddr3_dqs_p,
        ddr3_dqs_n,
        ,
        ddr3_odt
    );


top uut(
	.clk_i(clk_i), 
	.led(led),
	.sw(sw),
	.uart_tx(uart_tx),
	.uart_rx(uart_rx),
 	.ddr_reset_n(ddr3_reset_n),
 	.ddr_ck_p(ddr3_ck_p),
 	.ddr_ck_n(ddr3_ck_n),
 	.ddr_cke(ddr3_cke),
 	.ddr_cs_n(ddr3_cs_n),
 	.ddr_ras_n(ddr3_ras_n),
 	.ddr_cas_n(ddr3_cas_n),
 	.ddr_we_n(ddr3_we_n),
	.ddr_dm(ddr3_dm),
	.ddr_ba(ddr3_ba),
	.ddr_addr(ddr3_addr),
	.ddr_dq(ddr3_dq),
	.ddr_dqs_p(ddr3_dqs_p),
	.ddr_dqs_n(ddr3_dqs_n),
	.ddr_odt(ddr3_odt)
	);
	
endmodule
