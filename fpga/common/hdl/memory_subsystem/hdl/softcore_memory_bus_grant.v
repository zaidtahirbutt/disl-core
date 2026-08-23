`timescale 1ns / 1ps


module softcore_memory_bus_grant(
	clk,rst,

	// softcore relevant ports
	m_softcore_axi_arvalid, m_softcore_axi_arready,
	m_softcore_axi_rvalid, m_softcore_axi_rready,
	m_softcore_axi_awvalid, m_softcore_axi_awready,
	m_softcore_axi_wvalid, m_softcore_axi_wready, m_softcore_axi_wstrb,
	m_softcore_axi_b_ready, m_softcore_axi_b_valid,

	// grant req 
	mem_bus_grant_request,

	// grant 
	mem_bus_grant,

	// mem bus smartswitch group selector ctrl line
	mem_bus_group_sel
);

parameter SIMULATION = 0;

input 						clk;
input 						rst;

// softcore ports
input 						m_softcore_axi_arvalid;
input 						m_softcore_axi_arready;
input 						m_softcore_axi_rvalid;
input 						m_softcore_axi_rready;
input 						m_softcore_axi_awvalid;
input 						m_softcore_axi_awready;
input 						m_softcore_axi_wvalid;
input 						m_softcore_axi_wready;
input  [3:0]				m_softcore_axi_wstrb;
input 						m_softcore_axi_b_ready;
input 						m_softcore_axi_b_valid;

// grant req and grant ports
input							mem_bus_grant_request;
output 						mem_bus_grant;

// SS mem bus ctrl line
output  	               mem_bus_group_sel;

localparam [3:0]
    STATE_IDLE = 4'd0,
    WAIT_FOR_RDATA_COMPL = 4'd1,
    WAIT_FOR_READ_COMPL = 4'd2,
    WAIT_FOR_WRITE_COMPL = 4'd3,
    GRANT_BUS_CONTROL = 4'd4;

reg [3:0] state_reg = STATE_IDLE, state_next;
reg mem_bus_grant_ctrl;
reg mem_bus_group_sel_ctrl;

assign mem_bus_grant = mem_bus_grant_ctrl;
assign mem_bus_group_sel = mem_bus_group_sel_ctrl;

always @(posedge clk) begin
	
	if (rst) begin
		
		state_reg <= STATE_IDLE;

	end else begin
		
		state_reg <= state_next;

	end

end

always @(*) begin
	
	state_next = STATE_IDLE;
	mem_bus_grant_ctrl = 0;
	mem_bus_group_sel_ctrl = 0;


	case(state_reg)
		STATE_IDLE: begin
			state_next = STATE_IDLE;
			mem_bus_group_sel_ctrl = 0;

			// checking for read
			if(m_softcore_axi_arvalid) begin
				state_next = WAIT_FOR_RDATA_COMPL;
				mem_bus_group_sel_ctrl = 0;  

			// included rready cx it gets HIGH after getting araddr
			end else if(m_softcore_axi_rready || m_softcore_axi_rvalid) begin  
				state_next = WAIT_FOR_READ_COMPL;
				mem_bus_group_sel_ctrl = 0;

			// checking for write
			end else if (m_softcore_axi_awvalid || m_softcore_axi_wvalid) begin

				state_next = WAIT_FOR_WRITE_COMPL;
				mem_bus_group_sel_ctrl = 0;

			// if no read or write request then check for mem bus grant request
			end else begin  

				// some other subsystem requests for bus grant from softcore
				if(mem_bus_grant_request) begin
					state_next = GRANT_BUS_CONTROL;

					// need to set the ctrl line at the same clk cycle so that we dont go into a read or write state again if there is a 1 or more clk cycle delay
					mem_bus_group_sel_ctrl = 1;  

					// the if statements below will take precedence and this 1 will be overwritten to 0

					// will check if softcore is busy reading or writing to memory (in the middle of that process)
					
					// // checking for read
					// if(m_softcore_axi_arvalid) begin
					// 	state_next = WAIT_FOR_RDATA_COMPL;
					// 	mem_bus_group_sel_ctrl = 0;  

					// // included rready cx it gets HIGH after getting araddr
					// end else if(m_softcore_axi_rready || m_softcore_axi_rvalid) begin  
					// 	state_next = WAIT_FOR_READ_COMPL;
					// 	mem_bus_group_sel_ctrl = 0;

					// end

					// // checking for write
					// if(m_softcore_axi_awvalid || m_softcore_axi_wvalid) begin
					// 	state_next = WAIT_FOR_WRITE_COMPL;
					// 	mem_bus_group_sel_ctrl = 0;

					// end

				end

			end 
		end

		WAIT_FOR_RDATA_COMPL: begin
			state_next = WAIT_FOR_RDATA_COMPL;
			mem_bus_group_sel_ctrl = 0;

			if (m_softcore_axi_rready || m_softcore_axi_rvalid) begin
				state_next = WAIT_FOR_RDATA_COMPL;
			end else if ((!m_softcore_axi_rready) && (!m_softcore_axi_rvalid)) begin
				state_next = STATE_IDLE;	
				// state_next = GRANT_BUS_CONTROL;	
				// mem_bus_group_sel_ctrl = 1; 
			end
		end


		WAIT_FOR_READ_COMPL: begin
			state_next = WAIT_FOR_READ_COMPL;
			mem_bus_group_sel_ctrl = 0;

			if((!m_softcore_axi_rready) && (!m_softcore_axi_rvalid)) begin
				state_next = STATE_IDLE;
				// state_next = GRANT_BUS_CONTROL;
				// mem_bus_group_sel_ctrl = 1; 

				// dont need to check for write when reading was happening 
					// checking again to see if write isnt happening 
					// if(m_softcore_axi_awvalid || m_softcore_axi_wvalid) begin
					// 	state_next = WAIT_FOR_WRITE_COMPL;
					// 	mem_bus_group_sel_ctrl = 0; 
					// end

			end
		end 

		WAIT_FOR_WRITE_COMPL: begin
			state_next = WAIT_FOR_WRITE_COMPL;
			mem_bus_group_sel_ctrl = 0;

			if(m_softcore_axi_b_valid) begin
				state_next = STATE_IDLE;
				// state_next = GRANT_BUS_CONTROL;
				// mem_bus_group_sel_ctrl = 1;

				// dont need to check for read while in the write state
					// checking again to see if any read is happening
					// if(m_softcore_axi_arvalid  || m_softcore_axi_rvalid) begin
					// 	state_next = WAIT_FOR_READ_COMPL;
					// end
			end
		end

		GRANT_BUS_CONTROL: begin
			state_next = GRANT_BUS_CONTROL;
			mem_bus_group_sel_ctrl = 1;
			mem_bus_grant_ctrl = 1;

			// if the subsystem pullsdown its mem bus grant req
			if(!mem_bus_grant_request) begin  
				state_next = STATE_IDLE;
				mem_bus_group_sel_ctrl = 0;
				mem_bus_grant_ctrl = 0;

			end
		end

	endcase  


end




// generate 


	// if (SIMULATION == 0) begin 


		// // Using ILA to debug  txpipeline 
		// ila_21 ILA_DEBUG_busGrant (

		// 	.clk(clk),  // 1 bit
		// 	.probe0({m_softcore_axi_arvalid, m_softcore_axi_arready, m_softcore_axi_rvalid, m_softcore_axi_rready, m_softcore_axi_awvalid,
		// 	m_softcore_axi_awready, m_softcore_axi_wvalid, m_softcore_axi_wready, m_softcore_axi_wstrb, m_softcore_axi_b_ready, 
		// 	m_softcore_axi_b_valid, mem_bus_grant_request, mem_bus_grant, mem_bus_group_sel, state_reg, state_next,
		// 	mem_bus_grant_ctrl, mem_bus_group_sel_ctrl})  // 27 bits


		// );


	// end

// endgenerate




 




endmodule