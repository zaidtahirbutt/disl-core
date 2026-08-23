module ibufds_phy(
	input p,
	input n,
	output o
);
	IBUFDS init_clk_ibuf (.O(o), .I(p), .IB(n));
endmodule
