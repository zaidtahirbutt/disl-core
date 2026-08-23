// n-input simple arbiter


module aximml_address_translation(
	
	clk, rst,

	in_axi_araddr,in_axi_arvalid,in_axi_arready,
	in_axi_awaddr,in_axi_awvalid,in_axi_awready,
	in_axi_rdata,in_axi_rvalid,in_axi_rready,
	in_axi_wdata,in_axi_wstrb,in_axi_wvalid,in_axi_wready,
	in_b_ready,in_b_valid,in_b_response,

	out_axi_araddr,out_axi_arvalid,out_axi_arready,
	out_axi_awaddr,out_axi_awvalid,out_axi_awready,
	out_axi_rdata,out_axi_rvalid,out_axi_rready,
	out_axi_wdata,out_axi_wstrb,out_axi_wvalid,out_axi_wready,
	out_b_ready,out_b_valid,out_b_response,

	c_axi_araddr,c_axi_arvalid,c_axi_arready,
	c_axi_awaddr,c_axi_awvalid,c_axi_awready,
	c_axi_rdata,c_axi_rvalid,c_axi_rready,
	c_axi_wdata,c_axi_wstrb,c_axi_wvalid,c_axi_wready,
	c_b_ready,c_b_valid,c_b_response
	);

	parameter ADDR_WIDTH = 32;
	parameter NUMBER_OF_MEMORY_REGIONS = 3;
	
	
	input clk; 
	input rst;

	
	input [ADDR_WIDTH-1:0]      in_axi_araddr;
	input                       in_axi_arvalid;
	output reg                  in_axi_arready;
	input [ADDR_WIDTH-1:0]      in_axi_awaddr;
	input                       in_axi_awvalid;
	output reg                  in_axi_awready;
	output reg [ADDR_WIDTH-1:0] in_axi_rdata;
	output reg                  in_axi_rvalid;
	input                       in_axi_rready;
	input [ADDR_WIDTH-1:0]      in_axi_wdata;
	input [(ADDR_WIDTH>>3)-1:0] in_axi_wstrb;
	input                       in_axi_wvalid;
	output reg                  in_axi_wready;
	input                       in_b_ready;
	output reg                  in_b_valid;
	output reg [1:0]            in_b_response;
	
	input [ADDR_WIDTH-1:0]      c_axi_araddr;
	input                       c_axi_arvalid;
	output                      c_axi_arready;
	input [ADDR_WIDTH-1:0]      c_axi_awaddr;
	input                       c_axi_awvalid;
	output                      c_axi_awready;
	output [ADDR_WIDTH-1:0]     c_axi_rdata;
	output                      c_axi_rvalid;
	input                       c_axi_rready;
	input [ADDR_WIDTH-1:0]      c_axi_wdata;
	input [(ADDR_WIDTH>>3)-1:0] c_axi_wstrb;
	input                       c_axi_wvalid;
	output                      c_axi_wready;
	input                       c_b_ready;
	output reg                  c_b_valid;
	output  [1:0]               c_b_response;


	output reg [ADDR_WIDTH-1:0]      out_axi_araddr;
	output reg                       out_axi_arvalid;
	input                            out_axi_arready;
	output reg [ADDR_WIDTH-1:0]      out_axi_awaddr;
	output reg                       out_axi_awvalid;
	input                            out_axi_awready;
	input  [ADDR_WIDTH-1:0]          out_axi_rdata;
	input                            out_axi_rvalid;
	output reg                       out_axi_rready;
	output reg [ADDR_WIDTH-1:0]      out_axi_wdata;
	output reg [(ADDR_WIDTH>>3)-1:0] out_axi_wstrb;
	output reg                       out_axi_wvalid;
	input                            out_axi_wready;
	output reg                       out_b_ready;
	input                            out_b_valid;
	input [1:0]                      out_b_response;


	reg [ADDR_WIDTH-1:0] upper [0:NUMBER_OF_MEMORY_REGIONS-1];
	reg [ADDR_WIDTH-1:0] lower [0:NUMBER_OF_MEMORY_REGIONS-1];
	reg [ADDR_WIDTH-1:0] offset [0:NUMBER_OF_MEMORY_REGIONS-1];
	reg read_only [0:NUMBER_OF_MEMORY_REGIONS-1];

	assign c_axi_wready = 1;
	assign c_axi_awready = 1;
	assign c_axi_arready = 0;
	assign c_axi_rvalid = 0;
	assign c_axi_rdata = 0;
	assign c_b_response = 0;

	always @(posedge clk) begin
		if (rst)
			c_b_valid <= 0;
		else if (c_axi_wvalid && c_axi_wready)
			c_b_valid <= 1;
		else if (in_b_ready)
			c_b_valid <= 0;

		if ((c_axi_awaddr[3:2] == 2'b00)) begin
			if (c_axi_wvalid)
				upper[c_axi_awaddr >> 4] <= c_axi_wdata;
		end else if ((c_axi_awaddr[3:2] == 2'b01)) begin
			if (c_axi_wvalid)
				lower[c_axi_awaddr >> 4] <= c_axi_wdata;
		end else if ((c_axi_awaddr[3:2] == 2'b10)) begin
			if (c_axi_wvalid)
				offset[c_axi_awaddr >> 4] <= c_axi_wdata;
		end else if ((c_axi_awaddr[3:2] == 2'b11)) begin
			if (c_axi_wvalid)
				read_only[c_axi_awaddr >> 4] <= c_axi_wdata[0];
		end
	end

	integer i;
	always @(*) begin
		in_axi_awready = 0;
		in_axi_rdata = 0;
		in_axi_rvalid = 0;
		in_axi_arready = 0;
		in_axi_wready = 0;
		out_axi_araddr = 0;
		out_axi_arvalid = 0;
		out_axi_awaddr = 0;
		out_axi_awvalid = 0;
		out_axi_rready = 0;
		out_axi_wdata = 0;
		out_axi_wstrb = 0;
		out_axi_wvalid = 0;
		out_b_ready = 0;
		in_b_valid = 0;
		in_b_response = 0;
		for (i=0; i < NUMBER_OF_MEMORY_REGIONS; i=i+1) begin
			if ((in_axi_awaddr >= lower[i]) && (in_axi_awaddr < upper[i])) begin
				out_axi_awaddr = (in_axi_awaddr - lower[i]) + offset[i];
				out_axi_awvalid = in_axi_awvalid;
				out_axi_wdata = in_axi_wdata;
				out_axi_wstrb = (read_only[i]) ? 0 : in_axi_wstrb;
				in_axi_wready = out_axi_wready;
				in_axi_awready = out_axi_awready;
				out_b_ready = in_b_ready;
				in_b_valid = out_b_valid;
				in_b_response = out_b_response;
				out_axi_wvalid = in_axi_wvalid;
			end
			if ((in_axi_araddr >= lower[i]) && (in_axi_araddr < upper[i])) begin
				out_axi_araddr = (in_axi_araddr - lower[i]) + offset[i];
				out_axi_rready = in_axi_rready;
				in_axi_arready = out_axi_arready;
				out_axi_arvalid = in_axi_arvalid;
				in_axi_rdata = out_axi_rdata;
				in_axi_rvalid = out_axi_rvalid;
			end
		end
	end
endmodule