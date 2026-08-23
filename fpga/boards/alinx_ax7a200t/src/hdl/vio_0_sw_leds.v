module vio_0_sw_leds (
	input clk,
	input [3:0] leds,  
	output sw0, 
	output sw1, 
	output sw2, 
	output sw3
);


	vio_0 vio_0_inst (
		.clk(clk),
		.probe_in0(leds),
		.probe_out0(sw0),
		.probe_out1(sw1),
		.probe_out2(sw2),
		.probe_out3(sw3)
	);

endmodule