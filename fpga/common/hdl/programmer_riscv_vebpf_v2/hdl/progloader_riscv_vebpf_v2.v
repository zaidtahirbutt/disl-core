`timescale 1ps/1ps
module progloader_riscv_vebpf_v2(
clk,rst,urx,reprogram,w_processing,busy,

// VeBPF ports
reprogram_VeBPF_in, 
VeBPF_prog_addr_out,
VeBPF_prog_data_out,
VeBPF_prog_write_enable_out,
VeBPF_prog_reset_out,						// separate reset for the prog mem of VeBPF
VeBPF_prog_busy_out,						// the progloader is busy writing to VeBPF prog mem
VeBPF_prog_done_out,  					// VeBPF prog has been completed
VeBPF_next_rule_switch_flag_out,
VeBPF_all_rules_done_switch_flag_out,

a_axi_araddr, a_axi_arvalid, a_axi_arready,
a_axi_rdata, a_axi_rvalid, a_axi_rready,

a_axi_awaddr,a_axi_awvalid,a_axi_awready,
a_axi_wdata,a_axi_wstrb,a_axi_wvalid,a_axi_wready,
a_b_ready,a_b_valid,a_b_response
);


parameter MEM_ADDR_SIZE = 32;
parameter DATA_WIDTH = 32;
parameter SIMULATION = 0;
parameter CLKS_PER_BIT = 83;
parameter VEBPF_PROG_ADDRESS_WIDTH = 12;  // for VeBPF depth parameter MEMORY_DEPTH = 2**ADDRESS_SIZE;  // 2**12 = 4096
parameter VEBPF_PROG_DATA_WIDTH = 64;
parameter VEBPF_PROG_DATA_BYTES = 8;
parameter VEBPF_MEMORY_DEPTH = 2**VEBPF_PROG_ADDRESS_WIDTH;  // 2**12 = 4096 // do not specify this when using module
parameter VIVADO_SIMULATION = 0;
parameter VEBPF_SIMULATION = 0;
parameter COCOTB_MANUAL_RISCV_PROG_LOADING = 0;//1;
parameter [63:0] VEBPF_CURR_RULE_START_DWORD = 64'hFFFFFFFFFFFFFFFF;
parameter [63:0] VEBPF_CURR_RULE_END_DWORD   = 64'hFFFFFFFFFFFFFF0F;
parameter [63:0] VEBPF_ALL_RULES_END_DWORD 	 = 64'hFFFFFFFFFFFFFFF0;





input 				clk;
input 				rst;
input 				urx;  // input serial rx data (1 bit line converted to 1 byte rxdata and rxdv)
input 				reprogram;
input					w_processing;
    // I believe the assignment of w_processing to w_ready from SmartSwitch in top.v is incorrect ... as per AXI-4 spec
    // A source is not permitted to wait until READY is asserted before asserting VALID.
    // Once VALID is asserted it must remain asserted until the handshake occurs, at a rising clock edge at which VALID
    // and READY are both asserted.
output				busy;


// VeBPF related ports
input 																					reprogram_VeBPF_in;  // just toggle this to 1 before uploading, then toggle it back to 0 after its finished, also make sure the riscv reprog isn't HIGH during this
output reg [VEBPF_PROG_ADDRESS_WIDTH-1:0]				VeBPF_prog_addr_out;
output reg [VEBPF_PROG_DATA_WIDTH-1:0]					VeBPF_prog_data_out;
output reg												VeBPF_prog_write_enable_out;
output reg												VeBPF_prog_reset_out;  				// separate reset for the prog mem of VeBPF
output reg												VeBPF_prog_busy_out;  				// the progloader is busy writing to VeBPF prog mem
output reg												VeBPF_prog_done_out;  				// VeBPF prog has been completed
output wire     										VeBPF_next_rule_switch_flag_out;  
output wire    											VeBPF_all_rules_done_switch_flag_out;


output	reg 	[MEM_ADDR_SIZE-1:0]			a_axi_awaddr;
output	reg						a_axi_awvalid;
input							a_axi_awready;
output	reg 	[DATA_WIDTH-1:0]			a_axi_wdata;
output   	[(DATA_WIDTH>>3)-1:0]			a_axi_wstrb;
output	reg						a_axi_wvalid;
input							a_axi_wready;
output	reg						a_b_ready;
input							a_b_valid;
input 		[1:0]					a_b_response;


input 		[MEM_ADDR_SIZE-1:0] 	a_axi_araddr;
input 			 		a_axi_arvalid;
output	reg 				a_axi_arready;
output	reg 	[DATA_WIDTH-1:0] 	a_axi_rdata;
output	reg	 			a_axi_rvalid;
input 			 		a_axi_rready;







// this version of progloader will automatically detect start and end of VeBPF pgm insts by matching a pattern 
// and will automatically raise the appropriate switches that will increment the VeBPF rules and the instructions


assign a_axi_wstrb = {(DATA_WIDTH>>3){1'b1}};
assign busy = (state > 0) ? 1'b1 : 1'b0;


reg [7:0] state;
wire rx_dv;
wire [7:0] rx_byte;
reg [7:0] rx_byte_buff;
reg [DATA_WIDTH-1:0] mem_data;


// Below is a Moore statemachine https://electronics.stackexchange.com/questions/418380/types-of-finites-state-machine-in-fpga-design
generate
    
    // we only want the prog loader to load riscv pgm instructions when we are testing in vivado simulation and in SYN
    //  we dont want the prog loader to load riscv pgm instructions when testing Cocotb i.e., !VIVADO_SIMULATION
	if ((VIVADO_SIMULATION || COCOTB_MANUAL_RISCV_PROG_LOADING) || (!SIMULATION)) begin
//	if (!SIMULATION) begin
		// Moore FSM output logic
		always @(posedge clk) begin
			if (rst) begin
				a_axi_wvalid <= 0;
				a_axi_awvalid <= 0;
				a_b_ready <= 0;
				a_axi_awaddr <= 0;
				a_axi_wdata <= 0;
				mem_data <= 0;
			
			// end else if ((state == 0) && reprogram && w_processing) begin
			end else if ((state == 0) && reprogram && (!reprogram_VeBPF_in) && w_processing) begin
					// adding !reprogram_VeBPF_in, making sure that VeBPF switch[2] is not turned on
				a_b_ready <= 1'b1;
				a_axi_wvalid <= a_axi_wready ? 1'b1 : 0;
				a_axi_awvalid <= a_axi_awready ? 1'b1 : 0;
				
			end else if (state == 0) begin
				a_axi_wvalid <= 0;
				a_axi_awvalid <= 0;
				a_b_ready <= 0;
				
			end else if (state == 8'd1) begin
				mem_data  <= {24'd0,rx_byte_buff};
				
			end else if (state == 8'd2) begin
				mem_data <= mem_data | {16'h0,rx_byte_buff, 8'd0};
				
			end else if (state == 8'd3) begin
				mem_data <= mem_data | {8'd0,rx_byte_buff, 16'd0};
				
			end else if (state == 8'd4) begin
				a_axi_awaddr <= mem_data | {rx_byte_buff,24'd0};
				
			end else if (state == 8'd5) begin
				mem_data  <= {24'd0,rx_byte_buff};
				
			end else if (state == 8'd6) begin
				mem_data <= mem_data | {16'h0,rx_byte_buff, 8'd0};
				
			end else if (state == 8'd7) begin
				mem_data <= mem_data | {8'd0,rx_byte_buff, 16'd0};
				
			end else if (state == 8'd8) begin
				a_axi_wdata <= mem_data | {rx_byte_buff,24'd0};
		        a_axi_wvalid <= 1'b1;
		        a_axi_awvalid <= 1'b1;
				
			end else if (state == 8'd9) begin
				a_axi_wvalid <= 1'b0;
				
			end else if (state == 8'd10) begin
				a_axi_awvalid <= 1'b0;
				
			end else if (state == 8'd11) begin
				a_axi_wvalid <= 1'b0;
				a_axi_awvalid <= 1'b0;
				a_b_ready <= 1'b1;
			end
		end

		// Moore FSM next_state logic
			// I guess there is a race condition here... UART takes 83 clk cycles per bit
			// so if bvalid takes longer than 83 x 8 clk cycles (1 byte), then next incoming
			// byte will be missed.. okay..
		always @(posedge clk) begin
				
			if (rst) begin
				state <= 0;	
				rx_byte_buff <= 0;
				
			end else if ((state == 0) && w_processing) begin
				
			
			// end else if (reprogram) begin
			end else if (reprogram && (!reprogram_VeBPF_in)) begin
				// adding !reprogram_VeBPF_in, making sure that VeBPF switch[2] is not turned on

				if (rx_dv) begin
					state <= state + 8'd1; 
					rx_byte_buff <= rx_byte;
					
				end else if (state == 8'd8) begin	
					if (a_axi_wready && a_axi_awready)
						state <= 8'd11;
					else if (a_axi_wready)
						state <= 8'd9;
					else if (a_axi_awready)
						state <= 8'd10;
						
				end else if (state == 8'd9) begin
					if (a_axi_awready)
						state <= 8'd11;
						
				end else if (state == 8'd10) begin
					if (a_axi_wready)
						state <= 8'd11;
						
				end else if (state == 8'd11) begin
					if (a_b_valid)  
						state <= 8'd0;
				end
			end
		end
	end 
	else begin 
		
		always @(posedge clk) begin
			if (rst) begin
				state <= 0;					
			end
		end 

	end 
endgenerate


reg [7:0] VeBPF_state;
// wire rx_dv;
// wire [7:0] rx_byte;
reg [7:0] VeBPF_rx_byte_buff;
reg [VEBPF_PROG_ADDRESS_WIDTH-1:0] VeBPF_prog_mem_addr;
reg [VEBPF_PROG_DATA_WIDTH-1:0] VeBPF_prog_mem_data;
reg VeBPF_prog_done_flag;

wire VeBPF_rule_upload_completed_flag_wire;
	
// For multi rules uploading there is a 3 step process:

	// sw[1] i.e., reprogram for riscv pgm should be 0.
	// sw[2] i.e, reprogram_VeBPF_in should be 1 for uploading the first rule
	// assign VeBPF_next_rule_switch_btn =  btn_int[0];
	// assign led_wires_set2[0] =  VeBPF_next_rule_switch_btn;
	// assign VeBPF_all_rules_done_switch_btn =  btn_int[1];
	// assign led_wires_set2[1] =  VeBPF_all_rules_done_switch_btn;

	// for the next rules after the 1st rule, follow the steps below

	// 1) reprogram_VeBPF_in should go to 0 after 1st rule is uploaded so that rules scheduler fsm can go to VEBPF_RULES_SCHEDULER_FSM_STATE_RULE_WRITING_DONE state
	// waiting for the next rule flag "VeBPF_next_rule_switch_flag_in" or all rules done flag "VeBPF_all_rules_done_switch_flag_in"

	// 2) VeBPF_next_rule_switch_flag_out switch will have to be toggled from 0 to 1 and back to 0 so that rules scheduler fsm can go to IDLE state 
	// and wait for the next rule... Then toggle reprogram_VeBPF_in back to 1 as well since next rule is about to be loaded..

	// 3) do steps 1 and 2 for consecutive VeBPF rules uploaded.. Then after all rules have been uploaded. toggle reprogram_VeBPF_in, it should go to 0 
	// so that rules scheduler fsm can go to VEBPF_RULES_SCHEDULER_FSM_STATE_RULE_WRITING_DONE and then toggle VeBPF_rule_upload_completed_flag_wire from 0 to 1 
	// to 0 using dip switch, so that rules scheduler fsm can move to uploading all rules to all VeBPF CPUs

	// Assignments made below relating to the 3 points above


// dont need to put this in ifelse condition since it will be used for both sim and syn
assign VeBPF_next_rule_switch_flag_out = VeBPF_next_rule_flag_reg;
assign VeBPF_all_rules_done_switch_flag_out = VeBPF_all_rules_done_flag_reg;

reg VeBPF_next_rule_flag_reg, VeBPF_all_rules_done_flag_reg;
reg VeBPF_rule_start_flag_reg;

// Moore FSM output logic
always @(posedge clk) begin
	if (rst) begin
		VeBPF_prog_addr_out <= 0;
		VeBPF_prog_data_out <= 0;
		VeBPF_prog_write_enable_out <= 0;
		VeBPF_prog_reset_out <= 1;
		VeBPF_prog_busy_out <= 0;
		VeBPF_prog_done_out <= 0;
		VeBPF_prog_done_flag <= 0;
		VeBPF_next_rule_flag_reg <= 0;
		VeBPF_all_rules_done_flag_reg <= 0;
		VeBPF_rule_start_flag_reg <= 0;
		
	end else if ((VeBPF_state == 0) && (!reprogram) && reprogram_VeBPF_in) begin  // if sw[2] is toggled to 1 from 0
			// reprogram_VeBPF_in = switch[2] 
				// is the reprogram switch for VeBPF programming
			// reprogram = reprogram2 => assign reprogram2 = sw[1];
				// reprogram is for riscv programming I believe 
		
		// deassert reset
		VeBPF_prog_reset_out <= 0;
		VeBPF_prog_write_enable_out <= 0;
		VeBPF_prog_busy_out <= 1;  // busy = 1 since reprogram_VeBPF_in = 1
		
		VeBPF_prog_done_flag <= 1;
		VeBPF_prog_done_out <= 0;
			// pull down prog done output to 0

		VeBPF_next_rule_flag_reg <= 0;
		VeBPF_all_rules_done_flag_reg <= 0;
		VeBPF_rule_start_flag_reg <= 0;

	end else if (VeBPF_state == 8'd1) begin

		// insert additional states before this that will check "START pattern of VEBPF pgm"

		// VeBPF_prog_addr_out is not used by VeBPF prog uploader
		// 12 bit VeBPF prog mem address being written first
		VeBPF_prog_addr_out  <= {8'd0,VeBPF_rx_byte_buff};
		VeBPF_prog_busy_out <= 1;
		
	end else if (VeBPF_state == 8'd2) begin

		// VeBPF_prog_addr_out is not used by VeBPF prog uploader 
		VeBPF_prog_addr_out <= VeBPF_prog_addr_out | {VeBPF_rx_byte_buff[3:0], 8'd0};  // since our VeBPF prog addr is 12bits
		
	end else if (VeBPF_state == 8'd3) begin

		// 64 bit VeBPF prog mem data being written now
		VeBPF_prog_data_out  <= {56'd0,VeBPF_rx_byte_buff};
		
	end else if (VeBPF_state == 8'd4) begin

		VeBPF_prog_data_out <= VeBPF_prog_data_out | {48'h0,VeBPF_rx_byte_buff, 8'd0};
		
	end else if (VeBPF_state == 8'd5) begin

		VeBPF_prog_data_out <= VeBPF_prog_data_out | {40'd0,VeBPF_rx_byte_buff, 16'd0};
		
	end else if (VeBPF_state == 8'd6) begin

		VeBPF_prog_data_out <= VeBPF_prog_data_out | {32'd0,VeBPF_rx_byte_buff, 24'd0};

	end else if (VeBPF_state == 8'd7) begin

		VeBPF_prog_data_out <= VeBPF_prog_data_out | {24'd0,VeBPF_rx_byte_buff, 32'd0};

	end else if (VeBPF_state == 8'd8) begin

		VeBPF_prog_data_out <= VeBPF_prog_data_out | {16'd0,VeBPF_rx_byte_buff, 40'd0};

	end else if (VeBPF_state == 8'd9) begin

		VeBPF_prog_data_out <= VeBPF_prog_data_out | {8'd0,VeBPF_rx_byte_buff, 48'd0};

	end else if (VeBPF_state == 8'd10) begin

		VeBPF_prog_data_out <= VeBPF_prog_data_out | {VeBPF_rx_byte_buff, 56'd0};

			// if start of a rule pattern is detected
	  	if ((VeBPF_prog_data_out | {VeBPF_rx_byte_buff, 56'd0}) == VEBPF_CURR_RULE_START_DWORD) begin 

	  		// do nothing, just raise a flag for debugging
	  		VeBPF_rule_start_flag_reg <= 1;

	  		// not sending out flag VeBPF_prog_done_out <= 1; so a pgm word wont be registered
	
		// if end of a rule going to next rule pattern is detected	  	
	  	end else if ((VeBPF_prog_data_out | {VeBPF_rx_byte_buff, 56'd0}) == VEBPF_CURR_RULE_END_DWORD) begin

	  		VeBPF_prog_done_out <= 1;
	  		VeBPF_next_rule_flag_reg <= 1;


	  	// if end of a rule with all rules finished pattern is detected
	  	end else if ((VeBPF_prog_data_out | {VeBPF_rx_byte_buff, 56'd0}) == VEBPF_ALL_RULES_END_DWORD) begin 

			// 
	  		VeBPF_prog_done_out <= 1;
	  		VeBPF_all_rules_done_flag_reg <= 1;

	  	// if a normal rule word has been uploaded
	  	end else begin  

		  	// send write enable to write VeBPF_prog_data_out to VeBPF_prog_addr_out of VeBPF prog memory
		  	VeBPF_prog_write_enable_out <= 1;
		  		// skip this flag when the ending word of current VeBPF rule or start word of new rule is detected
		end 

	end
end

// Moore FSM next_VeBPF_state logic
	// I guess there is a race condition here... UART takes 83 clk cycles per bit
	// so if bvalid takes longer than 83 x 8 clk cycles (1 byte), then next incoming
	// byte will be missed.. okay..
always @(posedge clk) begin
		
	if (rst) begin
		VeBPF_state <= 0;	
		VeBPF_rx_byte_buff <= 0;
		// VeBPF_prog_done_flag <= 0;
		
	end else if ((VeBPF_state == 0) && (!reprogram_VeBPF_in)) begin
		// reprogram_VeBPF_in = switch[2] 
			// is the reprogram switch for VeBPF programming

		// adding !reprogram_VeBPF_in, making sure that VeBPF switch[2] is not turned on
		
		
		// VeBPF_prog_done_out <= VeBPF_prog_done_flag;
			// VeBPF prog done will become 1 once the sw[2] is toggled from 0 to 1 and then back to 0
				// In next version I can have another sw[3] to reset the prog done flag
					//  VeBPF_prog_done_flag <= VeBPF_prog_done_flag & !sw[3]
	
	// end else if (reprogram) begin
	end else if ((!reprogram) && reprogram_VeBPF_in) begin

		// VeBPF_prog_done_flag <= 1;

		// rx_dv will not stay 1 all the time since each bit is received after a number of clk cycles (83) dependant on baud rate
		// but still when all VeBPF rules are in 1 file, then there won't be an extremely large time gap between each VeBPF rule 
		if (rx_dv) begin

			VeBPF_state <= VeBPF_state + 8'd1; 
			VeBPF_rx_byte_buff <= rx_byte;
				
		end else if (VeBPF_state == 8'd10) begin 
				VeBPF_state <= 8'd0;
		end
	end
end			


generate 
	// riscv prog upload simulation commented out
  if (SIMULATION && (VIVADO_SIMULATION || COCOTB_MANUAL_RISCV_PROG_LOADING)) begin
    reg [7:0] uart_state;
    reg rx_dv_reg;
    initial rx_dv_reg = 0;
    assign rx_dv = rx_dv_reg;
    reg [31:0] pc;
    initial pc = 0;
    reg [7:0] rx_byte_reg;
    // reg [7:0] instrs [0: 1048575];
    reg [7:0] instrs [0: 65535];  // USING reduced linker depth 
    
    // initial $readmemh("firmware.hex", instrs);
    initial begin 
    	
    	// for vivado simulation
	    	// $readmemh("2024_4_12_edgetestbed_a100T27_tx_pipeline_v9_sim_also_SYN_VIVADO_sim.hex", instrs);

	    // for cocotb simulation
    	$readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_4_24_edgetestbed_a100T27_tx_pipeline_v10v2_1SIM_0DEBUG_sim_also_SYN_reducedLinker_VIVADO_sim.hex", instrs);

    	if (COCOTB_MANUAL_RISCV_PROG_LOADING) begin 
    		$display("\n\nCOCOTB_MANUAL_RISCV_PROG_LOADING == 1 so make sure you have the correct configurations!! \n\n");
    	end 

    	if (VIVADO_SIMULATION) begin 
    		$display("\n\VIVADO_SIMULATION == 1 so make sure you have the correct configurations!! \n\n");
    	end 

    
    end 

    integer i;

    initial begin

         $display("testing if instrs mem was read instrs[%d]:", i);

         for (i=0; i < 93; i=i+1)
            $display("%d:%h \n",i,instrs[i]);    

    end

    assign rx_byte = rx_byte_reg; 

		always @(posedge clk) begin
			if (rst || !reprogram) begin
				uart_state <= 0;
				pc <= 0;
				rx_byte_reg <= 0;
				
			end else if ((state == 0) && reprogram && w_processing) begin
			
			end else if (rx_dv_reg) begin
				rx_dv_reg <= 0;
			end else if (uart_state == 0) begin
				if (state == 0)
					uart_state <= uart_state + 8'd1;
			end else if (uart_state == 8'd1) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= pc[7:0];
				uart_state <= uart_state + 8'd1;
				
			end else if (uart_state == 8'd2) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= pc[15:8];
				uart_state <= uart_state + 8'd1;
				
			end else if (uart_state == 8'd3) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= pc[23:16];
				uart_state <= uart_state + 8'd1;
				
			end else if (uart_state == 8'd4) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= pc[31:24];
				uart_state <= uart_state + 8'd1;
				
			end else if (uart_state == 8'd5) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc];
				pc <= pc+ 32'd1;
				uart_state <= uart_state + 8'd1;
				
			end else if (uart_state == 8'd6) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc];
				pc <= pc+ 32'd1;
				uart_state <= uart_state + 8'd1;
				
			end else if (uart_state == 8'd7) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc];
				pc <= pc+ 32'd1;
				uart_state <= uart_state + 8'd1;
				
			end else if (uart_state == 8'd8) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc];
				pc <= pc+ 32'd1;
				uart_state <= 8'd0;
			end
		end
	end

	// ********************************************************************************************************************************************************************
	// ********************************************************************************************************************************************************************
	// **********************************************     VeBPF prog loading simulation     **********************************
	// ********************************************************************************************************************************************************************
	// ********************************************************************************************************************************************************************


	// THIS IS INSIDE A GENERATE BLOCK !!
	if (SIMULATION && VEBPF_SIMULATION) begin
	    reg [7:0] uart_state;
	    reg rx_dv_reg;
	    initial rx_dv_reg = 0;
	    assign rx_dv = rx_dv_reg;
	    reg [11:0] pc;
	    initial pc = 0;
	    reg [7:0] rx_byte_reg;
	    reg [63:0] instrs [VEBPF_MEMORY_DEPTH-1 : 0];
	    
	    // VeBPF pgm_loaderV2 exps sims
	    // initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/VeBPF/DISL_FPGA_eBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/data30_a100T30_eBPF_firewall_pgmloader_v2/combined_compilation_pgmloader_v2/test3/sim_combined_hex.hex", instrs);
	    // initial $readmemh("/home/zaidtahir/projects/2025_3_disl_virtio_smart_nic_v2_handoff_to_Jeffery/DISL/fpga/common/hdl/network_subsystem/VeBPF/firmware/VeBPF_firewall/sim_combined_hex.hex", instrs);
	    initial $readmemh("../../../fpga/common/hdl/network_subsystem/VeBPF/firmware/VeBPF_firewall/sim_combined_hex.hex", instrs);

	    integer i;

	    initial begin

	         $display("testing if VeBPF prog instrs mem was read instrs[%d]:", i);

	         for (i=0; i < 10; i=i+1)
	            $display("%d:%h \n",i,instrs[i]);    

	    end

	    integer idx6;

	    initial begin

	    	// #20
	    	$dumpfile("top.fst");
	    	// for (idx = 0; idx < `DUMP_DEPTH; idx = idx + 1) begin
	    	for (idx6 = 0; idx6 < 20; idx6 = idx6 + 1) begin
	    		$dumpvars(0, instrs[idx6]); // dumping mem data into the output waveform
	    	end 

	    end

	    assign rx_byte = rx_byte_reg;

		always @(posedge clk) begin
			if (rst || !reprogram_VeBPF_in) begin  // WAS ERROR HERE!!!
					// ERROR was that reprogram_VeBPF_in was going to 0 BEFORE all 17 firewall rules were uploaded!!
					// specifically it went to 0 while rule7 was uploading!!
				uart_state <= 0;
				pc <= 0;
				rx_byte_reg <= 0;

			// end else if ((VeBPF_state == 0) && reprogram_VeBPF_in) begin	
			end else if (rx_dv_reg) begin
				rx_dv_reg <= 0;
			end else if (uart_state == 0) begin

				// wait for VeBPF_state to become 0
				if (VeBPF_state == 0) begin
					uart_state <= uart_state + 8'd1;
				end

			end else if (uart_state == 8'd1) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= pc[7:0];
				uart_state <= uart_state + 8'd1;
				
			end else if (uart_state == 8'd2) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= pc[11:8];
				uart_state <= uart_state + 8'd1;
				
			end else if (uart_state == 8'd3) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc][7:0];
				uart_state <= uart_state + 8'd1;

			end else if (uart_state == 8'd4) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc][15:8];
				uart_state <= uart_state + 8'd1;

			end else if (uart_state == 8'd5) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc][23:16];
				uart_state <= uart_state + 8'd1;

			end else if (uart_state == 8'd6) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc][31:24];
				uart_state <= uart_state + 8'd1;

			end else if (uart_state == 8'd7) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc][39:32];
				uart_state <= uart_state + 8'd1; 

			end else if (uart_state == 8'd8) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc][47:40];
				uart_state <= uart_state + 8'd1;

			end else if (uart_state == 8'd9) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc][55:48];
				uart_state <= uart_state + 8'd1;

			end else if (uart_state == 8'd10) begin
				rx_dv_reg <= 1'b1;
				rx_byte_reg <= instrs[pc][63:56];
				pc <= pc + 1;
				uart_state <= 0;
			end
		end
	end 

	if (!SIMULATION) begin

		uart_rx_bram  #(.CLKS_PER_BIT(CLKS_PER_BIT)) rx(.i_Clock(clk),.i_Rx_Serial(urx),.o_Rx_DV(rx_dv),.o_Rx_Byte(rx_byte));

	end

endgenerate			
		

endmodule


//////////////////////////////////////////////////////////////////////
// File Downloaded from http://www.nandland.com
//////////////////////////////////////////////////////////////////////
// This file contains the UART Receiver.  This receiver is able to
// receive 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When receive is complete o_rx_dv will be
// driven high for one clock cycle.
// 
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87
  
module uart_rx_bram 
  (
   input        i_Clock,
   input        i_Rx_Serial,
   output       o_Rx_DV,
   output [7:0] o_Rx_Byte
   );
  parameter CLKS_PER_BIT   = 8'd83;
  parameter s_IDLE         = 3'b000;
  parameter s_RX_START_BIT = 3'b001;
  parameter s_RX_DATA_BITS = 3'b010;
  parameter s_RX_STOP_BIT  = 3'b011;
  parameter s_CLEANUP      = 3'b100;
   
  reg           r_Rx_Data_R = 1'b1;
  reg           r_Rx_Data   = 1'b1;
   
  reg [7:0]     r_Clock_Count = 0;
  reg [2:0]     r_Bit_Index   = 0; //8 bits total
  reg [7:0]     r_Rx_Byte     = 0;
  reg           r_Rx_DV       = 0;
  reg [2:0]     r_SM_Main     = 0;
   
  // Purpose: Double-register the incoming data.
  // This allows it to be used in the UART RX Clock Domain.
  // (It removes problems caused by metastability)
  always @(posedge i_Clock)
    begin
      r_Rx_Data_R <= i_Rx_Serial;
      r_Rx_Data   <= r_Rx_Data_R;
    end
   
   
  // Purpose: Control RX state machine
  always @(posedge i_Clock)
    begin
       
      case (r_SM_Main)
        s_IDLE :
          begin
            r_Rx_DV       <= 1'b0;
            r_Clock_Count <= 0;
            r_Bit_Index   <= 0;
             
            if (r_Rx_Data == 1'b0)          // Start bit detected
              r_SM_Main <= s_RX_START_BIT;
            else
              r_SM_Main <= s_IDLE;
          end
         
        // Check middle of start bit to make sure it's still low
        s_RX_START_BIT :
          begin
            if (r_Clock_Count == (CLKS_PER_BIT-1)/2)
              begin
                if (r_Rx_Data == 1'b0)
                  begin
                    r_Clock_Count <= 0;  // reset counter, found the middle
                    r_SM_Main     <= s_RX_DATA_BITS;
                  end
                else
                  r_SM_Main <= s_IDLE;
              end
            else
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_RX_START_BIT;
              end
          end // case: s_RX_START_BIT
         
         
        // Wait CLKS_PER_BIT-1 clock cycles to sample serial data
        s_RX_DATA_BITS :
          begin
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_RX_DATA_BITS;
              end
            else
              begin
                r_Clock_Count          <= 0;
                r_Rx_Byte[r_Bit_Index] <= r_Rx_Data;
                 
                // Check if we have received all bits
                if (r_Bit_Index < 7)
                  begin
                    r_Bit_Index <= r_Bit_Index + 1;
                    r_SM_Main   <= s_RX_DATA_BITS;
                  end
                else
                  begin
                    r_Bit_Index <= 0;
                    r_SM_Main   <= s_RX_STOP_BIT;
                  end
              end
          end // case: s_RX_DATA_BITS
     
     
        // Receive Stop bit.  Stop bit = 1
        s_RX_STOP_BIT :
          begin
            // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_RX_STOP_BIT;
              end
            else
              begin
                r_Rx_DV       <= 1'b1;
                r_Clock_Count <= 0;
                r_SM_Main     <= s_CLEANUP;
              end
          end // case: s_RX_STOP_BIT
     
         
        // Stay here 1 clock
        s_CLEANUP :
          begin
            r_SM_Main <= s_IDLE;
            r_Rx_DV   <= 1'b0;
          end
         
         
        default :
          r_SM_Main <= s_IDLE;
         
      endcase
    end   
   
  assign o_Rx_DV   = r_Rx_DV;
  assign o_Rx_Byte = r_Rx_Byte;
   
endmodule // uart_rx
