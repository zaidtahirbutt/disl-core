module fp32_exp(
	input clk, 
	input in_valid, 
	input [31:0] in_data, 
  	output result_valid, 
  	output [31:0] result_data
);
	ip_fp32_exp fpexp(
	.aclk(clk), 
	.s_axis_a_tvalid(in_valid), 
	.s_axis_a_tdata(in_data), 
  	.m_axis_result_tvalid(result_valid), 
  	.m_axis_result_tdata(result_data)
  	);
endmodule