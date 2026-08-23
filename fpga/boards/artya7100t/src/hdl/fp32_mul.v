module fp32_mul(
	input clk, 
	input lhs_valid, 
	input [31:0] lhs_data, 
  	input rhs_valid, 
  	input [31:0] rhs_data, 
  	output result_valid, 
  	output [31:0] result_data
);
	ip_fp32_mul fpmul(
	.aclk(clk), 
	.s_axis_a_tvalid(lhs_valid), 
	.s_axis_a_tdata(lhs_data), 
  	.s_axis_b_tvalid(rhs_valid), 
  	.s_axis_b_tdata(rhs_data), 
  	.m_axis_result_tvalid(result_valid), 
  	.m_axis_result_tdata(result_data)
  	);
endmodule