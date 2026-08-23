// n-input simple arbiter


module simple_arbiter_x8(
	clk, active,

	in0_read,in0_write,in0_address,in0_wrdata,in0_wrstrb,in0_rdvalid,in0_rddata,in0_rdaddress,in0_ready,
	in1_read,in1_write,in1_address,in1_wrdata,in1_wrstrb,in1_rdvalid,in1_rddata,in1_rdaddress,in1_ready,
	in2_read,in2_write,in2_address,in2_wrdata,in2_wrstrb,in2_rdvalid,in2_rddata,in2_rdaddress,in2_ready,
	in3_read,in3_write,in3_address,in3_wrdata,in3_wrstrb,in3_rdvalid,in3_rddata,in3_rdaddress,in3_ready,
	in4_read,in4_write,in4_address,in4_wrdata,in4_wrstrb,in4_rdvalid,in4_rddata,in4_rdaddress,in4_ready,
	in5_read,in5_write,in5_address,in5_wrdata,in5_wrstrb,in5_rdvalid,in5_rddata,in5_rdaddress,in5_ready,
	in6_read,in6_write,in6_address,in6_wrdata,in6_wrstrb,in6_rdvalid,in6_rddata,in6_rdaddress,in6_ready,
	in7_read,in7_write,in7_address,in7_wrdata,in7_wrstrb,in7_rdvalid,in7_rddata,in7_rdaddress,in7_ready,
	out_read,out_write,out_address,out_wrdata,out_wrstrb,out_rdvalid,out_rddata,out_rdaddress,out_ready
	);

	parameter ADDR_WIDTH = 32;
	parameter DATA_WIDTH = 32;
	parameter NUMBER_OF_INPUTS = 8;
	parameter POLICY = 0;
	parameter GENERATE_CROSSBAR = 1;
	parameter IN0_ADDRESS_OFFSET = 0;
	parameter IN1_ADDRESS_OFFSET = 0;
	parameter IN2_ADDRESS_OFFSET = 0;
	parameter IN3_ADDRESS_OFFSET = 0;
	parameter IN4_ADDRESS_OFFSET = 0;
	parameter IN5_ADDRESS_OFFSET = 0;
	parameter IN6_ADDRESS_OFFSET = 0;
	parameter IN7_ADDRESS_OFFSET = 0;
	parameter IN0_ADDRESS_MASK = 32'h00_FF_FF_FF; // 1MB
	parameter IN1_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN2_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN3_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN4_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN5_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN6_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN7_ADDRESS_MASK = 32'h00_FF_FF_FF;
	
	input clk; 
	output reg [2:0] active;


	input in0_read;
	input in0_write;
	input [ADDR_WIDTH-1:0] in0_address;
	input [DATA_WIDTH-1:0] in0_wrdata;
	input [(DATA_WIDTH>>3)-1:0] in0_wrstrb;
	output in0_rdvalid;
	output [DATA_WIDTH-1:0] in0_rddata;
	output [ADDR_WIDTH-1:0] in0_rdaddress;
	output in0_ready;

	input in1_read;
	input in1_write;
	input [ADDR_WIDTH-1:0] in1_address;
	input [DATA_WIDTH-1:0] in1_wrdata;
	input [(DATA_WIDTH>>3)-1:0] in1_wrstrb;
	output in1_rdvalid;
	output [DATA_WIDTH-1:0] in1_rddata;
	output [ADDR_WIDTH-1:0] in1_rdaddress;
	output in1_ready;

	input in2_read;
	input in2_write;
	input [ADDR_WIDTH-1:0] in2_address;
	input [DATA_WIDTH-1:0] in2_wrdata;
	input [(DATA_WIDTH>>3)-1:0] in2_wrstrb;
	output in2_rdvalid;
	output [DATA_WIDTH-1:0] in2_rddata;
	output [ADDR_WIDTH-1:0] in2_rdaddress;
	output in2_ready;

	input in3_read;
	input in3_write;
	input [ADDR_WIDTH-1:0] in3_address;
	input [DATA_WIDTH-1:0] in3_wrdata;
	input [(DATA_WIDTH>>3)-1:0] in3_wrstrb;
	output in3_rdvalid;
	output [DATA_WIDTH-1:0] in3_rddata;
	output [ADDR_WIDTH-1:0] in3_rdaddress;
	output in3_ready;

	input in4_read;
	input in4_write;
	input [ADDR_WIDTH-1:0] in4_address;
	input [DATA_WIDTH-1:0] in4_wrdata;
	input [(DATA_WIDTH>>3)-1:0] in4_wrstrb;
	output in4_rdvalid;
	output [DATA_WIDTH-1:0] in4_rddata;
	output [ADDR_WIDTH-1:0] in4_rdaddress;
	output in4_ready;

	input in5_read;
	input in5_write;
	input [ADDR_WIDTH-1:0] in5_address;
	input [DATA_WIDTH-1:0] in5_wrdata;
	input [(DATA_WIDTH>>3)-1:0] in5_wrstrb;
	output in5_rdvalid;
	output [DATA_WIDTH-1:0] in5_rddata;
	output [ADDR_WIDTH-1:0] in5_rdaddress;
	output in5_ready;

	input in6_read;
	input in6_write;
	input [ADDR_WIDTH-1:0] in6_address;
	input [DATA_WIDTH-1:0] in6_wrdata;
	input [(DATA_WIDTH>>3)-1:0] in6_wrstrb;
	output in6_rdvalid;
	output [DATA_WIDTH-1:0] in6_rddata;
	output [ADDR_WIDTH-1:0] in6_rdaddress;
	output in6_ready;

	input in7_read;
	input in7_write;
	input [ADDR_WIDTH-1:0] in7_address;
	input [DATA_WIDTH-1:0] in7_wrdata;
	input [(DATA_WIDTH>>3)-1:0] in7_wrstrb;
	output in7_rdvalid;
	output [DATA_WIDTH-1:0] in7_rddata;
	output [ADDR_WIDTH-1:0] in7_rdaddress;
	output in7_ready;

	output reg out_read;
	output reg out_write;
	output reg [ADDR_WIDTH-1:0] out_address;
	output reg [DATA_WIDTH-1:0] out_wrdata;
	output reg [(DATA_WIDTH>>3)-1:0] out_wrstrb;
	input out_rdvalid;
	input [DATA_WIDTH-1:0] out_rddata;
	input [ADDR_WIDTH-1:0] out_rdaddress;
	input out_ready;


	wire [7:0] in_read;
	wire [7:0] in_write;
	wire [(ADDR_WIDTH*8)-1:0] in_address;
	wire [(DATA_WIDTH*8)-1:0] in_wrdata;
	wire [((DATA_WIDTH>>3)*8)-1:0] in_wrstrb;
	reg [7:0] in_rdvalid;
	reg [(DATA_WIDTH*8)-1:0] in_rddata;
	reg [(ADDR_WIDTH*8)-1:0] in_rdaddress;
	reg [7:0] in_ready;


	// Input signals
	assign in_read = {in7_read,in6_read,in5_read,in4_read,in3_read,in2_read,in1_read,in0_read};
	assign in_write = {in7_write,in6_write,in5_write,in4_write,in3_write,in2_write,in1_write,in0_write};
	assign in_address = {(in7_address&IN7_ADDRESS_MASK)+IN7_ADDRESS_OFFSET,
						 (in6_address&IN6_ADDRESS_MASK)+IN6_ADDRESS_OFFSET,
						 (in5_address&IN5_ADDRESS_MASK)+IN5_ADDRESS_OFFSET,
						 (in4_address&IN4_ADDRESS_MASK)+IN4_ADDRESS_OFFSET,
						 (in3_address&IN3_ADDRESS_MASK)+IN3_ADDRESS_OFFSET,
						 (in2_address&IN2_ADDRESS_MASK)+IN2_ADDRESS_OFFSET,
						 (in1_address&IN1_ADDRESS_MASK)+IN1_ADDRESS_OFFSET,
						 (in0_address&IN0_ADDRESS_MASK)+IN0_ADDRESS_OFFSET};
	assign in_wrdata = {in7_wrdata,in6_wrdata,in5_wrdata,in4_wrdata,in3_wrdata,in2_wrdata,in1_wrdata,in0_wrdata};
	assign in_wrstrb = {in7_wrstrb,in6_wrstrb,in5_wrstrb,in4_wrstrb,in3_wrstrb,in2_wrstrb,in1_wrstrb,in0_wrstrb};

	generate 
		if(GENERATE_CROSSBAR) begin
			// Output signals
			//rddata
			assign in0_rddata = in_rddata[(0*DATA_WIDTH)+:DATA_WIDTH];
			assign in1_rddata = in_rddata[(1*DATA_WIDTH)+:DATA_WIDTH];
			assign in2_rddata = in_rddata[(2*DATA_WIDTH)+:DATA_WIDTH];
			assign in3_rddata = in_rddata[(3*DATA_WIDTH)+:DATA_WIDTH];
			assign in4_rddata = in_rddata[(4*DATA_WIDTH)+:DATA_WIDTH];
			assign in5_rddata = in_rddata[(5*DATA_WIDTH)+:DATA_WIDTH];
			assign in6_rddata = in_rddata[(6*DATA_WIDTH)+:DATA_WIDTH];
			assign in7_rddata = in_rddata[(7*DATA_WIDTH)+:DATA_WIDTH];

			//rdaddress
			assign in0_rdaddress = in_rdaddress[(0*ADDR_WIDTH)+:ADDR_WIDTH];
			assign in1_rdaddress = in_rdaddress[(1*ADDR_WIDTH)+:ADDR_WIDTH];
			assign in2_rdaddress = in_rdaddress[(2*ADDR_WIDTH)+:ADDR_WIDTH];
			assign in3_rdaddress = in_rdaddress[(3*ADDR_WIDTH)+:ADDR_WIDTH];
			assign in4_rdaddress = in_rdaddress[(4*ADDR_WIDTH)+:ADDR_WIDTH];
			assign in5_rdaddress = in_rdaddress[(5*ADDR_WIDTH)+:ADDR_WIDTH];
			assign in6_rdaddress = in_rdaddress[(6*ADDR_WIDTH)+:ADDR_WIDTH];
			assign in7_rdaddress = in_rdaddress[(7*ADDR_WIDTH)+:ADDR_WIDTH];

			//rdvalid
			assign in0_rdvalid = in_rdvalid[0];
			assign in1_rdvalid = in_rdvalid[1];
			assign in2_rdvalid = in_rdvalid[2];
			assign in3_rdvalid = in_rdvalid[3];
			assign in4_rdvalid = in_rdvalid[4];
			assign in5_rdvalid = in_rdvalid[5];
			assign in6_rdvalid = in_rdvalid[6];
			assign in7_rdvalid = in_rdvalid[7];
			
			//ready
			assign in0_ready = in_ready[0];
			assign in1_ready = in_ready[1];
			assign in2_ready = in_ready[2];
			assign in3_ready = in_ready[3];
			assign in4_ready = in_ready[4];
			assign in5_ready = in_ready[5];
			assign in6_ready = in_ready[6];
			assign in7_ready = in_ready[7];
			

			// Make connections
			integer i;
			always @(*) begin
				in_ready = 0;
				in_rdvalid = 0;
				in_rddata = 0;
				in_rdaddress = 0;
				out_read = 0;
				out_write = 0;
				out_wrdata = 0;
				out_wrstrb = 0;
				out_address = 0;
				for (i=0; i < NUMBER_OF_INPUTS; i=i+1) begin
					if (i == active) begin
					   in_ready[i] = out_ready;
					   in_rdvalid[i] = out_rdvalid;
					   in_rddata[(i*DATA_WIDTH)+:DATA_WIDTH] = out_rddata;
					   in_rdaddress[(i*ADDR_WIDTH)+:ADDR_WIDTH] = out_rdaddress;
					   out_read = in_read[i];
					   out_write = in_write[i];
					   out_wrdata= in_wrdata[(i*DATA_WIDTH)+:DATA_WIDTH];
					   out_address = in_address[(i*ADDR_WIDTH)+:ADDR_WIDTH];
					   out_wrstrb= in_wrstrb[(i*(DATA_WIDTH>>3))+:(DATA_WIDTH>>3)];
				    end           
			    end
			end
		end
	endgenerate
	

	// set active value
	generate
		if (POLICY == 0) begin // priority
			reg [2:0] select;
			integer j;

			always @(*) begin
				select  = NUMBER_OF_INPUTS-1;
				for (j=0; j < NUMBER_OF_INPUTS-1; j=j+1) begin
					if ((in_read[j] || in_write[j]) && (j < select))
						select = j;
				end
			end

			reg [2:0] active_buf;
			initial active_buf = NUMBER_OF_INPUTS-1;

			always @(*) begin
				active =  (out_ready && !(out_rdvalid)) ? select : active_buf;
			end

			always @(posedge clk) begin
				if (out_ready && !(out_rdvalid))
					active_buf <= active;
			end
		end
	endgenerate


endmodule




// n-input aximml arbiter - wip


module aximml_arbiter_x8(
	clk, rst, active,

	out_axi_araddr,out_axi_arvalid,out_axi_arready,
	out_axi_awaddr,out_axi_awvalid,out_axi_awready,
	out_axi_rdata,out_axi_rvalid,out_axi_rready,
	out_axi_wdata,out_axi_wstrb,out_axi_wvalid,out_axi_wready,
	out_b_ready,out_b_valid,out_b_response,

	in0_axi_araddr,in0_axi_arvalid,in0_axi_arready,
	in0_axi_awaddr,in0_axi_awvalid,in0_axi_awready,
	in0_axi_rdata,in0_axi_rvalid,in0_axi_rready,
	in0_axi_wdata,in0_axi_wstrb,in0_axi_wvalid,in0_axi_wready,
	in0_b_ready,in0_b_valid,in0_b_response,
	
	in1_axi_araddr,in1_axi_arvalid,in1_axi_arready,
	in1_axi_awaddr,in1_axi_awvalid,in1_axi_awready,
	in1_axi_rdata,in1_axi_rvalid,in1_axi_rready,
	in1_axi_wdata,in1_axi_wstrb,in1_axi_wvalid,in1_axi_wready,
	in1_b_ready,in1_b_valid,in1_b_response,
	
	in2_axi_araddr,in2_axi_arvalid,in2_axi_arready,
	in2_axi_awaddr,in2_axi_awvalid,in2_axi_awready,
	in2_axi_rdata,in2_axi_rvalid,in2_axi_rready,
	in2_axi_wdata,in2_axi_wstrb,in2_axi_wvalid,in2_axi_wready,
	in2_b_ready,in2_b_valid,in2_b_response,
	
	in3_axi_araddr,in3_axi_arvalid,in3_axi_arready,
	in3_axi_awaddr,in3_axi_awvalid,in3_axi_awready,
	in3_axi_rdata,in3_axi_rvalid,in3_axi_rready,
	in3_axi_wdata,in3_axi_wstrb,in3_axi_wvalid,in3_axi_wready,
	in3_b_ready,in3_b_valid,in3_b_response,
	
	in4_axi_araddr,in4_axi_arvalid,in4_axi_arready,
	in4_axi_awaddr,in4_axi_awvalid,in4_axi_awready,
	in4_axi_rdata,in4_axi_rvalid,in4_axi_rready,
	in4_axi_wdata,in4_axi_wstrb,in4_axi_wvalid,in4_axi_wready,
	in4_b_ready,in4_b_valid,in4_b_response,
	
	in5_axi_araddr,in5_axi_arvalid,in5_axi_arready,
	in5_axi_awaddr,in5_axi_awvalid,in5_axi_awready,
	in5_axi_rdata,in5_axi_rvalid,in5_axi_rready,
	in5_axi_wdata,in5_axi_wstrb,in5_axi_wvalid,in5_axi_wready,
	in5_b_ready,in5_b_valid,in5_b_response,
	
	in6_axi_araddr,in6_axi_arvalid,in6_axi_arready,
	in6_axi_awaddr,in6_axi_awvalid,in6_axi_awready,
	in6_axi_rdata,in6_axi_rvalid,in6_axi_rready,
	in6_axi_wdata,in6_axi_wstrb,in6_axi_wvalid,in6_axi_wready,
	in6_b_ready,in6_b_valid,in6_b_response,
	
	in7_axi_araddr,in7_axi_arvalid,in7_axi_arready,
	in7_axi_awaddr,in7_axi_awvalid,in7_axi_awready,
	in7_axi_rdata,in7_axi_rvalid,in7_axi_rready,
	in7_axi_wdata,in7_axi_wstrb,in7_axi_wvalid,in7_axi_wready,
	in7_b_ready,in7_b_valid,in7_b_response
	);

	parameter ADDR_WIDTH = 32;
	parameter DATA_WIDTH = 32;
	parameter NUMBER_OF_INPUTS = 8;
	parameter POLICY = 0;
	parameter GENERATE_CROSSBAR = 1;
	parameter IN0_ADDRESS_OFFSET = 0;
	parameter IN1_ADDRESS_OFFSET = 0;
	parameter IN2_ADDRESS_OFFSET = 0;
	parameter IN3_ADDRESS_OFFSET = 0;
	parameter IN4_ADDRESS_OFFSET = 0;
	parameter IN5_ADDRESS_OFFSET = 0;
	parameter IN6_ADDRESS_OFFSET = 0;
	parameter IN7_ADDRESS_OFFSET = 0;
	parameter IN0_ADDRESS_MASK = 32'h00_FF_FF_FF; // 1MB
	parameter IN1_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN2_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN3_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN4_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN5_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN6_ADDRESS_MASK = 32'h00_FF_FF_FF;
	parameter IN7_ADDRESS_MASK = 32'h00_FF_FF_FF;
	
	input clk; 
	input rst;
	output reg [2:0] active;


	output reg [ADDR_WIDTH-1:0]      out_axi_araddr;
	output reg                       out_axi_arvalid;
	input                            out_axi_arready;
	output reg [ADDR_WIDTH-1:0]      out_axi_awaddr;
	output reg                       out_axi_awvalid;
	input                            out_axi_awready;
	input  [DATA_WIDTH-1:0]          out_axi_rdata;
	input                            out_axi_rvalid;
	output reg                       out_axi_rready;
	output reg [DATA_WIDTH-1:0]      out_axi_wdata;
	output reg [(DATA_WIDTH>>3)-1:0] out_axi_wstrb;
	output reg                       out_axi_wvalid;
	input                            out_axi_wready;
	output reg                       out_b_ready;
	input                            out_b_valid;
	input [1:0]                      out_b_response;

	input [ADDR_WIDTH-1:0]      in0_axi_araddr;
	input                       in0_axi_arvalid;
	output                      in0_axi_arready;
	input [ADDR_WIDTH-1:0]      in0_axi_awaddr;
	input                       in0_axi_awvalid;
	output                      in0_axi_awready;
	output  [DATA_WIDTH-1:0]    in0_axi_rdata;
	output                      in0_axi_rvalid;
	input                       in0_axi_rready;
	input [DATA_WIDTH-1:0]      in0_axi_wdata;
	input [(DATA_WIDTH>>3)-1:0] in0_axi_wstrb;
	input                       in0_axi_wvalid;
	output                      in0_axi_wready;
	input                       in0_b_ready;
	output                      in0_b_valid;
	output [1:0]                in0_b_response;

	input [ADDR_WIDTH-1:0]      in1_axi_araddr;
	input                       in1_axi_arvalid;
	output                      in1_axi_arready;
	input [ADDR_WIDTH-1:0]      in1_axi_awaddr;
	input                       in1_axi_awvalid;
	output                      in1_axi_awready;
	output  [DATA_WIDTH-1:0]    in1_axi_rdata;
	output                      in1_axi_rvalid;
	input                       in1_axi_rready;
	input [DATA_WIDTH-1:0]      in1_axi_wdata;
	input [(DATA_WIDTH>>3)-1:0] in1_axi_wstrb;
	input                       in1_axi_wvalid;
	output                      in1_axi_wready;
	input                       in1_b_ready;
	output                      in1_b_valid;
	output [1:0]                in1_b_response;

	input [ADDR_WIDTH-1:0]      in2_axi_araddr;
	input                       in2_axi_arvalid;
	output                      in2_axi_arready;
	input [ADDR_WIDTH-1:0]      in2_axi_awaddr;
	input                       in2_axi_awvalid;
	output                      in2_axi_awready;
	output  [DATA_WIDTH-1:0]    in2_axi_rdata;
	output                      in2_axi_rvalid;
	input                       in2_axi_rready;
	input [DATA_WIDTH-1:0]      in2_axi_wdata;
	input [(DATA_WIDTH>>3)-1:0] in2_axi_wstrb;
	input                       in2_axi_wvalid;
	output                      in2_axi_wready;
	input                       in2_b_ready;
	output                      in2_b_valid;
	output [1:0]                in2_b_response;

	input [ADDR_WIDTH-1:0]      in3_axi_araddr;
	input                       in3_axi_arvalid;
	output                      in3_axi_arready;
	input [ADDR_WIDTH-1:0]      in3_axi_awaddr;
	input                       in3_axi_awvalid;
	output                      in3_axi_awready;
	output  [DATA_WIDTH-1:0]    in3_axi_rdata;
	output                      in3_axi_rvalid;
	input                       in3_axi_rready;
	input [DATA_WIDTH-1:0]      in3_axi_wdata;
	input [(DATA_WIDTH>>3)-1:0] in3_axi_wstrb;
	input                       in3_axi_wvalid;
	output                      in3_axi_wready;
	input                       in3_b_ready;
	output                      in3_b_valid;
	output [1:0]                in3_b_response;

	input [ADDR_WIDTH-1:0]      in4_axi_araddr;
	input                       in4_axi_arvalid;
	output                      in4_axi_arready;
	input [ADDR_WIDTH-1:0]      in4_axi_awaddr;
	input                       in4_axi_awvalid;
	output                      in4_axi_awready;
	output  [DATA_WIDTH-1:0]    in4_axi_rdata;
	output                      in4_axi_rvalid;
	input                       in4_axi_rready;
	input [DATA_WIDTH-1:0]      in4_axi_wdata;
	input [(DATA_WIDTH>>3)-1:0] in4_axi_wstrb;
	input                       in4_axi_wvalid;
	output                      in4_axi_wready;
	input                       in4_b_ready;
	output                      in4_b_valid;
	output [1:0]                in4_b_response;

	input [ADDR_WIDTH-1:0]      in5_axi_araddr;
	input                       in5_axi_arvalid;
	output                      in5_axi_arready;
	input [ADDR_WIDTH-1:0]      in5_axi_awaddr;
	input                       in5_axi_awvalid;
	output                      in5_axi_awready;
	output  [DATA_WIDTH-1:0]    in5_axi_rdata;
	output                      in5_axi_rvalid;
	input                       in5_axi_rready;
	input [DATA_WIDTH-1:0]      in5_axi_wdata;
	input [(DATA_WIDTH>>3)-1:0] in5_axi_wstrb;
	input                       in5_axi_wvalid;
	output                      in5_axi_wready;
	input                       in5_b_ready;
	output                      in5_b_valid;
	output [1:0]                in5_b_response;

	input [ADDR_WIDTH-1:0]      in6_axi_araddr;
	input                       in6_axi_arvalid;
	output                      in6_axi_arready;
	input [ADDR_WIDTH-1:0]      in6_axi_awaddr;
	input                       in6_axi_awvalid;
	output                      in6_axi_awready;
	output  [DATA_WIDTH-1:0]    in6_axi_rdata;
	output                      in6_axi_rvalid;
	input                       in6_axi_rready;
	input [DATA_WIDTH-1:0]      in6_axi_wdata;
	input [(DATA_WIDTH>>3)-1:0] in6_axi_wstrb;
	input                       in6_axi_wvalid;
	output                      in6_axi_wready;
	input                       in6_b_ready;
	output                      in6_b_valid;
	output [1:0]                in6_b_response;

	input [ADDR_WIDTH-1:0]      in7_axi_araddr;
	input                       in7_axi_arvalid;
	output                      in7_axi_arready;
	input [ADDR_WIDTH-1:0]      in7_axi_awaddr;
	input                       in7_axi_awvalid;
	output                      in7_axi_awready;
	output  [DATA_WIDTH-1:0]    in7_axi_rdata;
	output                      in7_axi_rvalid;
	input                       in7_axi_rready;
	input [DATA_WIDTH-1:0]      in7_axi_wdata;
	input [(DATA_WIDTH>>3)-1:0] in7_axi_wstrb;
	input                       in7_axi_wvalid;
	output                      in7_axi_wready;
	input                       in7_b_ready;
	output                      in7_b_valid;
	output [1:0]                in7_b_response;

	wire  [(ADDR_WIDTH*8)-1:0]      in_axi_araddr;
	wire  [7:0]                     in_axi_arvalid;
	wire  [(ADDR_WIDTH*8)-1:0]      in_axi_awaddr;
	wire  [7:0]                     in_axi_awvalid;
	wire  [7:0]                     in_axi_rready;
	wire  [(DATA_WIDTH*8)-1:0]      in_axi_wdata;
	wire  [((DATA_WIDTH>>3)*8)-1:0] in_axi_wstrb;
	wire  [7:0]                     in_axi_wvalid;
	wire  [7:0]                     in_b_ready;
	reg   [7:0]                     in_axi_arready;
	reg   [7:0]                     in_axi_awready;
	reg   [(DATA_WIDTH*8)-1:0]      in_axi_rdata;
	reg   [7:0]                     in_axi_rvalid;
	reg   [7:0]                     in_axi_wready;
	reg   [7:0]                     in_b_valid;
	reg   [15:0]                    in_b_response;




	// Input signals
	assign in_axi_araddr = {(in7_axi_araddr&IN7_ADDRESS_MASK)+IN7_ADDRESS_OFFSET,
						 (in6_axi_araddr&IN7_ADDRESS_MASK)+IN6_ADDRESS_OFFSET,
						 (in5_axi_araddr&IN7_ADDRESS_MASK)+IN5_ADDRESS_OFFSET,
						 (in4_axi_araddr&IN7_ADDRESS_MASK)+IN4_ADDRESS_OFFSET,
						 (in3_axi_araddr&IN7_ADDRESS_MASK)+IN3_ADDRESS_OFFSET,
						 (in2_axi_araddr&IN7_ADDRESS_MASK)+IN2_ADDRESS_OFFSET,
						 (in1_axi_araddr&IN7_ADDRESS_MASK)+IN1_ADDRESS_OFFSET,
						 (in0_axi_araddr&IN7_ADDRESS_MASK)+IN0_ADDRESS_OFFSET};
	assign in_axi_arvalid = {in7_axi_arvalid,in6_axi_arvalid,in5_axi_arvalid,in4_axi_arvalid,in3_axi_arvalid,in2_axi_arvalid,in1_axi_arvalid,in0_axi_arvalid};					 
	assign in_axi_awaddr = {(in7_axi_awaddr&IN7_ADDRESS_MASK)+IN7_ADDRESS_OFFSET,
						 (in6_axi_awaddr&IN7_ADDRESS_MASK)+IN6_ADDRESS_OFFSET,
						 (in5_axi_awaddr&IN7_ADDRESS_MASK)+IN5_ADDRESS_OFFSET,
						 (in4_axi_awaddr&IN7_ADDRESS_MASK)+IN4_ADDRESS_OFFSET,
						 (in3_axi_awaddr&IN7_ADDRESS_MASK)+IN3_ADDRESS_OFFSET,
						 (in2_axi_awaddr&IN7_ADDRESS_MASK)+IN2_ADDRESS_OFFSET,
						 (in1_axi_awaddr&IN7_ADDRESS_MASK)+IN1_ADDRESS_OFFSET,
						 (in0_axi_awaddr&IN7_ADDRESS_MASK)+IN0_ADDRESS_OFFSET};	
	assign in_axi_awvalid = {in7_axi_awvalid,in6_axi_awvalid,in5_axi_awvalid,in4_axi_awvalid,in3_axi_awvalid,in2_axi_awvalid,in1_axi_awvalid,in0_axi_awvalid};					 
	assign in_axi_rready = {in7_axi_rready,in6_axi_rready,in5_axi_rready,in4_axi_rready,in3_axi_rready,in2_axi_rready,in1_axi_rready,in0_axi_rready};					 
	assign in_axi_wdata = {in7_axi_wdata,in6_axi_wdata,in5_axi_wdata,in4_axi_wdata,in3_axi_wdata,in2_axi_wdata,in1_axi_wdata,in0_axi_wdata};
	assign in_axi_wstrb = {in7_axi_wstrb,in6_axi_wstrb,in5_axi_wstrb,in4_axi_wstrb,in3_axi_wstrb,in2_axi_wstrb,in1_axi_wstrb,in0_axi_wstrb};
	assign in_axi_wvalid = {in7_axi_wvalid,in6_axi_wvalid,in5_axi_wvalid,in4_axi_wvalid,in3_axi_wvalid,in2_axi_wvalid,in1_axi_wvalid,in0_axi_wvalid};					 
	assign in_b_ready = {in7_b_ready,in6_b_ready,in5_b_ready,in4_b_ready,in3_b_ready,in2_b_ready,in1_b_ready,in0_b_ready};					 

	generate 
		if(GENERATE_CROSSBAR) begin
			// Output signals

			
			//axi_arready
			assign in0_axi_arready = in_axi_arready[0];
			assign in1_axi_arready = in_axi_arready[1];
			assign in2_axi_arready = in_axi_arready[2];
			assign in3_axi_arready = in_axi_arready[3];
			assign in4_axi_arready = in_axi_arready[4];
			assign in5_axi_arready = in_axi_arready[5];
			assign in6_axi_arready = in_axi_arready[6];
			assign in7_axi_arready = in_axi_arready[7];


			//axi_awready
			assign in0_axi_awready = in_axi_awready[0];
			assign in1_axi_awready = in_axi_awready[1];
			assign in2_axi_awready = in_axi_awready[2];
			assign in3_axi_awready = in_axi_awready[3];
			assign in4_axi_awready = in_axi_awready[4];
			assign in5_axi_awready = in_axi_awready[5];
			assign in6_axi_awready = in_axi_awready[6];
			assign in7_axi_awready = in_axi_awready[7];

			//axi_rvalid
			assign in0_axi_rvalid = in_axi_rvalid[0];
			assign in1_axi_rvalid = in_axi_rvalid[1];
			assign in2_axi_rvalid = in_axi_rvalid[2];
			assign in3_axi_rvalid = in_axi_rvalid[3];
			assign in4_axi_rvalid = in_axi_rvalid[4];
			assign in5_axi_rvalid = in_axi_rvalid[5];
			assign in6_axi_rvalid = in_axi_rvalid[6];
			assign in7_axi_rvalid = in_axi_rvalid[7];

			//axi_wready
			assign in0_axi_wready = in_axi_wready[0];
			assign in1_axi_wready = in_axi_wready[1];
			assign in2_axi_wready = in_axi_wready[2];
			assign in3_axi_wready = in_axi_wready[3];
			assign in4_axi_wready = in_axi_wready[4];
			assign in5_axi_wready = in_axi_wready[5];
			assign in6_axi_wready = in_axi_wready[6];
			assign in7_axi_wready = in_axi_wready[7];

			//b_valid
			assign in0_b_valid = in_b_valid[0];
			assign in1_b_valid = in_b_valid[1];
			assign in2_b_valid = in_b_valid[2];
			assign in3_b_valid = in_b_valid[3];
			assign in4_b_valid = in_b_valid[4];
			assign in5_b_valid = in_b_valid[5];
			assign in6_b_valid = in_b_valid[6];
			assign in7_b_valid = in_b_valid[7];

			//b_response
			assign in0_b_response = in_b_response[(0*2)+:2];
			assign in1_b_response = in_b_response[(1*2)+:2];
			assign in2_b_response = in_b_response[(2*2)+:2];
			assign in3_b_response = in_b_response[(3*2)+:2];
			assign in4_b_response = in_b_response[(4*2)+:2];
			assign in5_b_response = in_b_response[(5*2)+:2];
			assign in6_b_response = in_b_response[(6*2)+:2];
			assign in7_b_response = in_b_response[(7*2)+:2];

			//axi_rdata
			assign in0_axi_rdata = in_axi_rdata[(0*DATA_WIDTH)+:DATA_WIDTH];
			assign in1_axi_rdata = in_axi_rdata[(1*DATA_WIDTH)+:DATA_WIDTH];
			assign in2_axi_rdata = in_axi_rdata[(2*DATA_WIDTH)+:DATA_WIDTH];
			assign in3_axi_rdata = in_axi_rdata[(3*DATA_WIDTH)+:DATA_WIDTH];
			assign in4_axi_rdata = in_axi_rdata[(4*DATA_WIDTH)+:DATA_WIDTH];
			assign in5_axi_rdata = in_axi_rdata[(5*DATA_WIDTH)+:DATA_WIDTH];
			assign in6_axi_rdata = in_axi_rdata[(6*DATA_WIDTH)+:DATA_WIDTH];
			assign in7_axi_rdata = in_axi_rdata[(7*DATA_WIDTH)+:DATA_WIDTH];

			

			// Make connections
			integer i;
			always @(*) begin
				in_axi_arready = 0;
				in_axi_awready = 0;
				in_axi_rvalid = 0;
				in_axi_wready = 0;
				in_b_valid = 0;
				out_axi_araddr = 0;
				out_axi_arvalid = 0;
				out_axi_awaddr = 0;
				out_axi_awvalid = 0;
				out_axi_rready = 0;
				out_axi_wdata = 0;
				out_axi_wstrb = 0;
				out_axi_wvalid = 0;
				out_b_ready = 0;
				for (i=0; i < NUMBER_OF_INPUTS; i=i+1) begin
					in_axi_rdata[(i*DATA_WIDTH)+:DATA_WIDTH] = out_axi_rdata;
					in_b_response[(i*2)+:2] = out_b_response;
					if (i == active) begin
						in_axi_arready[i] = out_axi_arready;
						in_axi_awready[i] = out_axi_awready;
						in_axi_rvalid[i] = out_axi_rvalid;
						in_axi_wready[i] = out_axi_wready;
						in_b_valid[i] = out_b_valid;
						out_axi_araddr = in_axi_araddr[(i*ADDR_WIDTH)+:ADDR_WIDTH];
						out_axi_arvalid = in_axi_arvalid[i];
						out_axi_awaddr = in_axi_awaddr[(i*ADDR_WIDTH)+:ADDR_WIDTH];
						out_axi_awvalid = in_axi_awvalid[i];
						out_axi_rready = in_axi_rready[i];
						out_axi_wdata = in_axi_wdata[(i*DATA_WIDTH)+:DATA_WIDTH];
						out_axi_wstrb = in_axi_wstrb[(i*(DATA_WIDTH>>3))+:(DATA_WIDTH>>3)];
						out_axi_wvalid = in_axi_wvalid[i];
						out_b_ready = in_b_ready[i];
				    end           
			    end
			end
		end
	endgenerate
	

	// set active value
	generate
		if (POLICY == 0) begin // priority
			reg [2:0] select;

			integer j;
			always @(*) begin
				select  = NUMBER_OF_INPUTS-1;
				for (j=0; j < NUMBER_OF_INPUTS-1; j=j+1) begin
					if ((in_axi_arvalid[j] || in_axi_awvalid[j]) && (j < select))
						select = j;
				end
			end

			reg transaction_type;
			wire end_write_transaction = out_b_valid && out_b_ready ? 1'b1 : 1'b0;
			wire end_read_transaction = out_axi_rvalid && out_axi_rready ? 1'b1 : 1'b0;
			wire out_ready = transaction_type ? end_read_transaction : end_write_transaction;
			reg busy;

			initial active = NUMBER_OF_INPUTS-1;
			initial transaction_type = 0;
			initial busy = 0;

			always @(posedge clk) begin
				if (rst)
					busy <= 0;
				else if ((out_axi_arready && out_axi_arvalid) || (out_axi_awready && out_axi_awvalid))
					busy <= 1;
				else if (out_ready)
					busy <= 0;

				if (!busy)
					active <= select;

				if (out_axi_arready && out_axi_arvalid)
					transaction_type <= 1;
				else if (out_axi_awready && out_axi_awvalid)
					transaction_type <= 0;

			end
		end
	endgenerate


endmodule