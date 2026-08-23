module clk_mmcm_eth_rgmmi(
	input clkin200mhz, 
	// input CLKFBIN, 
	input rst, 
	output clkout125mhz, 
	output clkout125mhz_90shift, 
	// output CLKFBOUT,
	output locked
);

	wire mmcm_clkfb;
	// MMCM instance
	// 200 MHz in, 125 MHz out
	// PFD range: 10 MHz to 500 MHz
	// VCO range: 600 MHz to 1440 MHz
	// M = 5, D = 1 sets Fvco = 1000 MHz (in range)
	// Divide by 8 to get output frequency of 125 MHz
	// Need two 125 MHz outputs with 90 degree offset
	// Also need 200 MHz out for IODELAY
	// 1000 / 5 = 200 MHz
	MMCME2_BASE #(
		.BANDWIDTH("OPTIMIZED"),
		.CLKOUT0_DIVIDE_F(8),
		.CLKOUT0_DUTY_CYCLE(0.5),
		.CLKOUT0_PHASE(0),
		.CLKOUT1_DIVIDE(8),
		.CLKOUT1_DUTY_CYCLE(0.5),
		.CLKOUT1_PHASE(90),
		.CLKOUT2_DIVIDE(5),
		.CLKOUT2_DUTY_CYCLE(0.5),
		.CLKOUT2_PHASE(0),
		.CLKOUT3_DIVIDE(1),
		.CLKOUT3_DUTY_CYCLE(0.5),
		.CLKOUT3_PHASE(0),
		.CLKOUT4_DIVIDE(1),
		.CLKOUT4_DUTY_CYCLE(0.5),
		.CLKOUT4_PHASE(0),
		.CLKOUT5_DIVIDE(1),
		.CLKOUT5_DUTY_CYCLE(0.5),
		.CLKOUT5_PHASE(0),
		.CLKOUT6_DIVIDE(1),
		.CLKOUT6_DUTY_CYCLE(0.5),
		.CLKOUT6_PHASE(0),
		.CLKFBOUT_MULT_F(5),
		.CLKFBOUT_PHASE(0),
		.DIVCLK_DIVIDE(1),
		.REF_JITTER1(0.010),
		.CLKIN1_PERIOD(5.0),
		.STARTUP_WAIT("FALSE"),
		.CLKOUT4_CASCADE("FALSE")
	)
	clk_mmcm_inst (

		// .CLKIN1(clk_200mhz_ibufg),
		// .CLKIN1(clk_ibufg),  // 200 MHz clk in
		.CLKIN1(clkin200mhz),  // 200 MHz clk in
		
		.CLKFBIN(mmcm_clkfb),
		
		// .RST(mmcm_rst),
		.RST(rst),
		
		.PWRDWN(1'b0),
		
		// .CLKOUT0(clk_mmcm_out), // 125 MHz out
		.CLKOUT0(clkout125mhz), // 125 MHz out
		
		.CLKOUT0B(),

		// .CLKOUT1(clk90_mmcm_out), // 125 MHz out but 90 degrees phase shift
		.CLKOUT1(clkout125mhz_90shift), // 125 MHz out but 90 degrees phase shift
		
		.CLKOUT1B(),
		// .CLKOUT2(clk_200mhz_mmcm_out),
		// .CLKOUT2(clk_200_mmcm_out),
		.CLKOUT2(),
		.CLKOUT2B(),
		.CLKOUT3(),
		.CLKOUT3B(),
		.CLKOUT4(),
		.CLKOUT5(),
		.CLKOUT6(),
		
		.CLKFBOUT(mmcm_clkfb),
		
		.CLKFBOUTB(),
		
		// .LOCKED(mmcm_locked)
		.LOCKED(locked)
	);

endmodule