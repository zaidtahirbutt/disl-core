module jtag_chip_manager_emulator(
clk,rst,
a_axi_araddr,a_axi_arvalid,a_axi_arready,
a_axi_rdata, a_axi_rready, a_axi_rvalid,
a_axi_awaddr,a_axi_awvalid,a_axi_awready,
a_axi_wdata,a_axi_wstrb,a_axi_wvalid,a_axi_wready,
a_b_ready,a_b_valid,a_b_response,
control

);



parameter MEM_ADDR_SIZE = 32;
parameter DATA_WIDTH = 32;
parameter JTAG_USER_REG_ID = 4;
parameter CLOCK_CROSSING_FIFO_DEPTH = 8;

input 				clk;
input 				rst;


output reg	 	[MEM_ADDR_SIZE-1:0]			a_axi_awaddr;
output reg							a_axi_awvalid;
input							a_axi_awready;
output	 	[DATA_WIDTH-1:0]			a_axi_wdata;
output   	[(DATA_WIDTH>>3)-1:0]			a_axi_wstrb;
output reg							a_axi_wvalid;
input							a_axi_wready;
output 	 	[MEM_ADDR_SIZE-1:0]			a_axi_araddr;
output 							a_axi_arvalid;
input							a_axi_arready;
input	 	[DATA_WIDTH-1:0]			a_axi_rdata;
input							a_axi_rvalid;
output 							a_axi_rready;
output reg							a_b_ready;
input 							a_b_valid;
input [1:0] 						a_b_response;
output reg [95:0] control;

reg [7:0] firmware[0:32768];
initial $readmemh("cpu_firmware.hex", firmware);
assign a_axi_wdata = {firmware[a_axi_awaddr + 32'd3], firmware[a_axi_awaddr + 32'd2], firmware[a_axi_awaddr + 32'd1], firmware[a_axi_awaddr + 32'd0]};
assign a_axi_wstrb = 4'b1111;
assign a_axi_araddr = 0;
assign a_axi_rready = 0;
assign a_axi_arvalid = 0;
reg [3:0] counter;

initial begin
control[1:0] = 2'b11;
counter = 0;
a_axi_awaddr = 0;
a_axi_awvalid = 0;
a_axi_wvalid =  0;
a_b_ready = 0;
end

always @(posedge clk) begin
    if (control[1:0] == 2'b11) begin
        counter <= counter + 1'b1;
        if (counter[3])
            control <= 2'b10;
	end else if (control[1:0] == 2'b10) begin
		if ((a_axi_awaddr > 32'd32760) && (a_b_ready && a_b_valid)) begin
			a_b_ready <= 0;
			control <= 0;
		end else if (a_axi_awvalid && a_axi_awready) begin
			a_axi_awvalid <= 0;
			a_axi_wvalid <= 0;
			a_b_ready <= 1;
		end else if (a_b_ready && a_b_valid) begin
			a_axi_awaddr <= a_axi_awaddr + 32'd4;
			a_axi_awvalid <= 1;
			a_axi_wvalid <= 1;
			a_b_ready <= 0;
		end
	end
end



endmodule

