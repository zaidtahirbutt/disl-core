`timescale 1ps/1ps
module tb_top;

	// simulated in project_1 inside the vivado project since vivado versions were diff from US server and couldn't edit in Vbox Ubuntu
	
    reg clk_i;
    initial clk_i = 0;
    always #5000 clk_i = ~clk_i;

    wire uart_tx;
    wire uart_rx = 1'b1;
    wire [3:0] led;
    reg [3:0] sw;

   	initial begin
		sw = 0;
		sw[0] = 1;
		#100000;
		sw[0] = 0;
		sw[1] = 1;
		#100000;
		sw[1] = 0;
		sw = 0;
	end

	// Use this when simulating progloader for riscv pgm insts
	// initial begin
	// 	sw[3:1] = 1'b0;
	// 	#130_000_000;
	// 	sw[1] = 1'b1;
	// 	#200_000_000;
	// 	sw[1] = 1'b0;  
	// end

    // always #1000_000 sw[2] = sw[1] | (~sw[2]); 

top uut(
	.clk_i(clk_i), 
	.led(led),
	.sw(sw),
	.uart_tx(uart_tx),
	.uart_rx(uart_rx)
	);
	
endmodule
