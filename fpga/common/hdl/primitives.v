module clk_ibufds(
	input clk_p,
	input clk_n,
	output clk
);
ibufds_phy uut(.p(clk_p), .n(clk_n), .o(clk));
endmodule







