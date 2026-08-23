module jtag_chip_manager(
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
parameter SIMULATION = 0;

input 									clk;
input 									rst;
output 		 	[MEM_ADDR_SIZE-1:0]		a_axi_awaddr;
output reg								a_axi_awvalid;
input									a_axi_awready;
output 		 	[DATA_WIDTH-1:0]		a_axi_wdata;
output 		   	[(DATA_WIDTH>>3)-1:0]	a_axi_wstrb;
output 									a_axi_wvalid;
input									a_axi_wready;
output 		 	[MEM_ADDR_SIZE-1:0]		a_axi_araddr;
output reg								a_axi_arvalid;
input									a_axi_arready;
input	 		[DATA_WIDTH-1:0]		a_axi_rdata;
input									a_axi_rvalid;
output 									a_axi_rready;
output 									a_b_ready;
input 									a_b_valid;
input 			[1:0] 					a_b_response;
output reg 		[95:0] 					control;


generate 
	if (SIMULATION == 0) begin
		wire tap_reset;
		wire tap_idle;
		wire tap_capture;
		wire tap_update;
		wire bscan_tck;
		wire bscan_tdi;
		wire bscan_tdo;
		wire data_valid;
		wire [7:0] cmd;
		wire	rddata_trigger;
		wire	wrdata_trigger;
		wire 	wraddr_trigger;
		wire 	rdaddr_trigger;
		wire 	loadjtagdata_trigger;
		wire 	control_trigger;
		wire [15:0] fifo_status;

		reg [103:0] jtag_write_data;
		reg [103:0] jtag_read_data;

		(* keep *) reg [7:0] state;
		reg int_a_axi_rvalid;
		reg [DATA_WIDTH-1:0] int_a_axi_rdata;

		initial jtag_write_data = 0;
		initial jtag_read_data = 0;
		initial int_a_axi_rdata = 0;
		initial jtag_write_data = 0;
		initial control = 0;

		assign a_axi_wstrb = {(DATA_WIDTH>>3){1'b1}};
		assign a_axi_wvalid = a_axi_awvalid;
		assign a_b_ready = a_b_valid;
		assign a_axi_rready = a_axi_rvalid;
		assign fifo_status[0] = a_axi_arready;
		assign fifo_status[1] = a_axi_awready;
		assign fifo_status[2] = int_a_axi_rvalid;
		assign fifo_status[3] = a_axi_wready;
		assign fifo_status[4] = a_axi_arvalid;
		assign fifo_status[5] = a_axi_awvalid;
		assign fifo_status[6] = a_axi_rvalid;
		assign fifo_status[7] = a_axi_wvalid;
		assign fifo_status[15:8] = state;
		assign {cmd, a_axi_wdata, a_axi_awaddr, a_axi_araddr} = jtag_write_data;
		assign {control_trigger, loadjtagdata_trigger, wrdata_trigger, rddata_trigger, wraddr_trigger, rdaddr_trigger} = cmd[5:0];
		assign bscan_tdo = jtag_read_data[0];

		jtag_phy #(.JTAG_USER_REG_ID(JTAG_USER_REG_ID)) 
		jphy(.tap_reset(tap_reset),.tap_idle(tap_idle),.tap_capture(tap_capture),.tap_update(tap_update),.bscan_tck(bscan_tck),.bscan_tdi(bscan_tdi),.bscan_tdo(bscan_tdo),.data_valid(data_valid));


		always @(posedge bscan_tck) begin
		    if (tap_idle) begin
		        jtag_read_data <= {56'd0,fifo_status,int_a_axi_rdata};
			end else if (data_valid) begin
				jtag_write_data <= {bscan_tdi, jtag_write_data[103:1]};
				jtag_read_data <= {1'd0, jtag_read_data[103:1]};
			end else if (control_trigger) begin
			   control <= jtag_write_data[95:0];
			end
		end

		always @(posedge clk) begin
			if (a_axi_rvalid)
				int_a_axi_rvalid <= 1;
			else if (rst)
				int_a_axi_rvalid <= 0;
			else if ((state == 4) || (state == 5))
				int_a_axi_rvalid <= 0;

			if (a_axi_rvalid)
				int_a_axi_rdata <= a_axi_rdata;

			if (rst) begin
				state <= 0;
				a_axi_awvalid <= 0;
				a_axi_arvalid <= 0;
			end else if (state == 0) begin
				a_axi_awvalid <= 0;
				a_axi_arvalid <= 0;
				if (tap_idle && (cmd[5:0] != 6'd0)) begin
					state <= 1;
				end
			end else if (state == 1) begin
				if (loadjtagdata_trigger) begin
					state <= 2;
				end else if (wrdata_trigger || wraddr_trigger) begin
					a_axi_awvalid <= 1;
					if (a_axi_awready && a_axi_wready) begin
						state <= 3;
					end
				end else if (rdaddr_trigger) begin
					a_axi_arvalid <= 1;
					if (a_axi_arready) begin
						state <= 4;
					end
				end else if (rddata_trigger && int_a_axi_rvalid) begin
					state <= 5;
				end
			end else if (state == 2) begin
				if (!tap_idle) begin
					state <= 0;
				end
			end else if (state == 3) begin
				a_axi_awvalid <= 0;
				state <= 2;
			end else if (state == 4) begin
				a_axi_arvalid <= 0;
				state <= 2;
			end else if (state == 5) begin
				state <= 2;
			end
		end
	end else begin
		//output reg [95:0] 	control;
		//output reg	a_axi_awvalid;

		reg [MEM_ADDR_SIZE-1:0]	a_axi_awaddr_reg;
		reg [DATA_WIDTH-1:0] a_axi_wdata_reg;
		reg [65:0] test_vectors [0:2048];
		initial $readmemh("../../../../../jtag.hex", test_vectors);
		assign a_axi_awaddr = a_axi_awaddr_reg;
		assign a_axi_wdata = a_axi_wdata_reg;
		assign a_axi_wstrb = {(DATA_WIDTH>>3){1'b1}};
		assign a_axi_wvalid = a_axi_awvalid;
		assign a_b_ready = a_b_valid;
		assign a_axi_rready = a_axi_rvalid;
		initial a_axi_arvalid = 0;
		assign a_axi_araddr = 0;
		initial control [95:64] = 32'd0;

		integer i;

		reg [64:0] mem_word;
		reg cmd;
		reg [31:0] a;
		reg [31:0] b;
		
		reg break ;
		initial begin
			control[63:0] = 0;
			a_axi_wdata_reg = 0;
			a_axi_awaddr_reg = 0;
			a_axi_awvalid = 0;
			break = 0;
			for (i=0; i <= 2048; i=i+1) begin
				mem_word = test_vectors[i];
				if (mem_word == (65'h1FFFFFFFFFFFFFFFF)) begin
					break = 1;
				end
				if (break == 0) begin
                    cmd = mem_word[64];
                    a = mem_word[63:32];
                    b = mem_word[31:0];              
                    if (cmd) begin
                        @(posedge clk);
                        a_axi_wdata_reg = a;
                        a_axi_awaddr_reg = b;
                        a_axi_awvalid = 1;
                        while (a_axi_wready == 0) begin
                           @(negedge clk);
                        end
                        @(posedge clk);
                        a_axi_awvalid = 0;
                    end else if (cmd == 0) begin
                        control[31:0] = b;
                        control [63:32] = a;
                        #100;
						while (rst == 1) begin
						@(posedge clk);
						end
                    end
               end
			end
		end
	end
endgenerate
endmodule