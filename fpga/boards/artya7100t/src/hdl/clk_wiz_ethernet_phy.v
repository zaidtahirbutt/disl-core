module clk_wiz_ethernet_phy(
	input clk, 
	output clk_83_33_mhz_out, 
	output clk_100_mhz_out, 
	output clk_25_mhz_out
);
	clk_wiz_2 ethernet_phy_clock_generator (
		.clk_in1(clk),  // input clk 100Mhz
		.clk_out3_100MHz(clk_100_mhz_out),  // 100 MHz clk going to memory subsystem
		.clk_out2_83_33MHz(clk_83_33_mhz_out),  // 83.33 MHz clk going to memory subsystem which is compatible with current UART and ProgLoader settings
		.clk_out1_25Mhz(clk_25_mhz_out)  // output 25Mhz clk going out to ethernet phy as its 25MHz ref clock
	);

endmodule