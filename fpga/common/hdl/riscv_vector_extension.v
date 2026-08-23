module riscv_vector_extension_alu( // does not handle cases where vl > VLMAX - this must be handled by the calling module
clk,
rst,
vsew,
vl,
mask,
vmask,
vstart, //ignoring this for now
vin1,
vin2,
vout_initial, // keep original value if masked, or if tail/inactive elements
op, //{ ..., <insert new op here>, srl, sll, mul, sub, add}
vout,
in_valid, 
out_valid 
);

parameter VLEN = 1024;
parameter XLEN = 32;

parameter ENABLE_SEW_8 = 1;
parameter ALU_UNITS_SEW_8 =  4;
parameter ENABLE_SEW_8_ALU_ADD = 1;
parameter ENABLE_SEW_8_ALU_SUB = 1;
parameter ENABLE_SEW_8_ALU_MUL = 1;
parameter ENABLE_SEW_8_ALU_SLL = 1;
parameter ENABLE_SEW_8_ALU_SRL = 1;
parameter ENABLE_SEW_16 = 1;
parameter ALU_UNITS_SEW_16 = 4;
parameter ENABLE_SEW_16_ALU_ADD = 1;
parameter ENABLE_SEW_16_ALU_SUB = 1;
parameter ENABLE_SEW_16_ALU_MUL = 1;
parameter ENABLE_SEW_16_ALU_SLL = 1;
parameter ENABLE_SEW_16_ALU_SRL = 1;
parameter ENABLE_SEW_32 = 1;
parameter ALU_UNITS_SEW_32 = 4;
parameter ENABLE_SEW_32_ALU_ADD = 1;
parameter ENABLE_SEW_32_ALU_SUB = 1;
parameter ENABLE_SEW_32_ALU_MUL = 1;
parameter ENABLE_SEW_32_ALU_SLL = 1;
parameter ENABLE_SEW_32_ALU_SRL = 1;
parameter ENABLE_SEW_64 = 1;
parameter ALU_UNITS_SEW_64 = 4;
parameter ENABLE_SEW_64_ALU_ADD = 1;
parameter ENABLE_SEW_64_ALU_SUB = 1;
parameter ENABLE_SEW_64_ALU_MUL = 1;
parameter ENABLE_SEW_64_ALU_SLL = 1;
parameter ENABLE_SEW_64_ALU_SRL = 1;


localparam VLMAX_SEW_8 = VLEN >> 3; 
localparam VLMAX_SEW_16 = VLEN >> 4; 
localparam VLMAX_SEW_32 = VLEN >> 5; 
localparam VLMAX_SEW_64 = VLEN >> 6; 


input clk;
input rst;
input [2:0] vsew;
input mask;

input [XLEN-1:0] vl;
input [XLEN-1:0] vstart;
input [XLEN-1:0] op;

input [VLEN-1:0] vin1;
input [VLEN-1:0] vin2;
input [VLEN-1:0] vmask;
input [VLEN-1:0] vout_initial;
output reg [VLEN-1:0] vout;

input in_valid;
output reg out_valid;


reg [2:0] vsew_buff;
reg [XLEN-1:0] vl_buff;
reg [XLEN-1:0] op_buff;

reg [VLEN-1:0] vin1_buff;
reg [VLEN-1:0] vin2_buff;
reg [VLEN-1:0] vmask_buff;
reg [VLEN-1:0] vout_initial_buff;
reg  mask_buff;

reg [7:0] state;
reg [XLEN-1:0] counter;
reg [XLEN-1:0] write_counter;



reg [(ALU_UNITS_SEW_8<<3)-1:0]  vout_sew_8_add;	
reg [(ALU_UNITS_SEW_16<<4)-1:0] vout_sew_16_add;	
reg [(ALU_UNITS_SEW_32<<5)-1:0] vout_sew_32_add;	
reg [(ALU_UNITS_SEW_64<<6)-1:0] vout_sew_64_add;	

generate 
	if (ENABLE_SEW_8 && ENABLE_SEW_8_ALU_ADD) begin
        integer i_8_add;
		always @(*) begin
            for (i_8_add=0; i_8_add < ALU_UNITS_SEW_8; i_8_add=i_8_add+1) begin
                vout_sew_8_add[(i_8_add<<3)+:8] = 
                ((counter+i_8_add < vl_buff) && (!mask_buff || vmask_buff[i_8_add])) ? 
                vin1_buff[(i_8_add<<3)+:8] + vin2_buff[(i_8_add<<3)+:8] : 
                vout_initial_buff[(i_8_add<<3)+:8];
            end
		end
	end
endgenerate
generate 
	if (ENABLE_SEW_16 && ENABLE_SEW_16_ALU_ADD) begin
        integer i_16_add;
		always @(*) begin
            for (i_16_add=0; i_16_add < ALU_UNITS_SEW_16; i_16_add=i_16_add+1) begin
                vout_sew_16_add[(i_16_add<<4)+:16] = 
                ((counter+i_16_add < vl_buff) && (!mask_buff || vmask_buff[i_16_add])) ? 
                vin1_buff[(i_16_add<<4)+:16] + vin2_buff[(i_16_add<<4)+:16] : 
                vout_initial_buff[(i_16_add<<4)+:16];
            end
		end
	end
endgenerate
generate 
	if (ENABLE_SEW_32 && ENABLE_SEW_32_ALU_ADD) begin
        integer i_32_add;
		always @(*) begin
            for (i_32_add=0; i_32_add < ALU_UNITS_SEW_32; i_32_add=i_32_add+1) begin
                vout_sew_32_add[(i_32_add<<5)+:32] = 
                ((counter+i_32_add < vl_buff) && (!mask_buff || vmask_buff[i_32_add])) ? 
                vin1_buff[(i_32_add<<5)+:32] + vin2_buff[(i_32_add<<5)+:32] : 
                vout_initial_buff[(i_32_add<<5)+:32];
            end
		end
	end
endgenerate
generate 
	if (ENABLE_SEW_64 && ENABLE_SEW_64_ALU_ADD) begin
        integer i_64_add;
		always @(*) begin
            for (i_64_add=0; i_64_add < ALU_UNITS_SEW_64; i_64_add=i_64_add+1) begin
                vout_sew_64_add[(i_64_add<<6)+:64] = 
                ((counter+i_64_add < vl_buff) && (!mask_buff || vmask_buff[i_64_add])) ? 
                vin1_buff[(i_64_add<<6)+:64] + vin2_buff[(i_64_add<<6)+:64] : 
                vout_initial_buff[(i_64_add<<6)+:64];
            end
		end
	end
endgenerate



reg supported;

always @(*) begin
	if ((vsew == 3'b000) && ENABLE_SEW_8) begin
		if (op[0] && ENABLE_SEW_8_ALU_ADD)
			supported = 1;
		else if (op[1] && ENABLE_SEW_8_ALU_SUB)
			supported = 1;
		else if (op[2] && ENABLE_SEW_8_ALU_MUL)
			supported = 1;
		else if (op[3] && ENABLE_SEW_8_ALU_SLL)
			supported = 1;
		else if (op[4] && ENABLE_SEW_8_ALU_SRL)
			supported = 1;
		else
			supported = 0;
	end else if ((vsew == 3'b001) && ENABLE_SEW_16) begin
		if (op[0] && ENABLE_SEW_16_ALU_ADD)
			supported = 1;
		else if (op[1] && ENABLE_SEW_16_ALU_SUB)
			supported = 1;
		else if (op[2] && ENABLE_SEW_16_ALU_MUL)
			supported = 1;
		else if (op[3] && ENABLE_SEW_16_ALU_SLL)
			supported = 1;
		else if (op[4] && ENABLE_SEW_16_ALU_SRL)
			supported = 1;
		else
			supported = 0;
	end else if ((vsew == 3'b010) && ENABLE_SEW_32) begin
		if (op[0] && ENABLE_SEW_32_ALU_ADD)
			supported = 1;
		else if (op[1] && ENABLE_SEW_32_ALU_SUB)
			supported = 1;
		else if (op[2] && ENABLE_SEW_32_ALU_MUL)
			supported = 1;
		else if (op[3] && ENABLE_SEW_32_ALU_SLL)
			supported = 1;
		else if (op[4] && ENABLE_SEW_32_ALU_SRL)
			supported = 1;
		else
			supported = 0;
	end else if ((vsew == 3'b011) && ENABLE_SEW_64) begin
		if (op[0] && ENABLE_SEW_64_ALU_ADD)
			supported = 1;
		else if (op[1] && ENABLE_SEW_64_ALU_SUB)
			supported = 1;
		else if (op[2] && ENABLE_SEW_64_ALU_MUL)
			supported = 1;
		else if (op[3] && ENABLE_SEW_64_ALU_SLL)
			supported = 1;
		else if (op[4] && ENABLE_SEW_64_ALU_SRL)
			supported = 1;
		else
			supported = 0;
	end else begin
		supported = 0;
	end
end


always @(posedge clk) begin
	if (rst) begin
		out_valid <= 0;
		vout <= 0;
		vsew_buff <= 0;
		vl_buff <= 0;
		op_buff <= 0;
		vin1_buff <= 0;
		vin2_buff <= 0;
		vmask_buff <= 0;
		mask_buff <= 0;
		vout_initial_buff <= 0;
		state <= 0;
		counter <= 0;
		write_counter <= 0;

	end else if (state == 0) begin
		vout <= vout_initial;
		vsew_buff <= vsew;
		op_buff <= op;
		vin1_buff <= vin1;
		vin2_buff <= vin2;
		vmask_buff <= vmask;
		mask_buff <= mask;
		vout_initial_buff <= vout_initial;
		vl_buff <= vl;
		state <= (in_valid) ? supported : 0;
		out_valid <= (in_valid) ? !supported : 0;
		counter <= 0;
		write_counter <= 0;

	end else if (state == 1) begin
		if (vsew_buff == 3'b000) begin
			if (op[0]) begin
				vout[write_counter+:ALU_UNITS_SEW_8<<3] <= vout_sew_8_add;
				vout_initial_buff <= vout_initial_buff >> (ALU_UNITS_SEW_8<<3);
				vmask_buff <= vmask_buff >> ALU_UNITS_SEW_8;
				vin1_buff <= vin1_buff >> (ALU_UNITS_SEW_8<<3);
				vin2_buff <= vin2_buff >> (ALU_UNITS_SEW_8<<3);
				counter <= counter + ALU_UNITS_SEW_8;
				write_counter <= write_counter + (ALU_UNITS_SEW_8<<3);
			end
			if (counter + ALU_UNITS_SEW_8 > vl_buff) begin
				state <= 0;
				out_valid <= 1;
			end else begin
				out_valid <= 0;
			end
		end else if (vsew_buff == 3'b001) begin
			if (op[0]) begin
				vout[write_counter+:ALU_UNITS_SEW_16<<4] <= vout_sew_16_add;
				vout_initial_buff <= vout_initial_buff >> (ALU_UNITS_SEW_16<<4);
				vmask_buff <= vmask_buff >> ALU_UNITS_SEW_16;
				vin1_buff <= vin1_buff >> (ALU_UNITS_SEW_16<<4);
				vin2_buff <= vin2_buff >> (ALU_UNITS_SEW_16<<4);
				counter <= counter + ALU_UNITS_SEW_16;
				write_counter <= write_counter + (ALU_UNITS_SEW_16<<4);
			end
			if (counter + ALU_UNITS_SEW_16 > vl_buff) begin
				state <= 0;
				out_valid <= 1;
			end else begin
				out_valid <= 0;
			end
		end else if (vsew_buff == 3'b010) begin
			if (op[0]) begin
				vout[write_counter+:ALU_UNITS_SEW_32<<5] <= vout_sew_32_add;
				vout_initial_buff <= vout_initial_buff >> (ALU_UNITS_SEW_32<<5);
				vmask_buff <= vmask_buff >> ALU_UNITS_SEW_32;
				vin1_buff <= vin1_buff >> (ALU_UNITS_SEW_32<<5);
				vin2_buff <= vin2_buff >> (ALU_UNITS_SEW_32<<5);
				counter <= counter + ALU_UNITS_SEW_32;
				write_counter <= write_counter + (ALU_UNITS_SEW_32<<5);
			end
			if (counter + ALU_UNITS_SEW_32 > vl_buff) begin
				state <= 0;
				out_valid <= 1;
			end else begin
				out_valid <= 0;
			end
		end else if (vsew_buff == 3'b011) begin
			if (op[0]) begin
				vout[write_counter+:ALU_UNITS_SEW_64<<6] <= vout_sew_64_add;
				vout_initial_buff <= vout_initial_buff >> (ALU_UNITS_SEW_64<<6);
				vmask_buff <= vmask_buff >> ALU_UNITS_SEW_64;
				vin1_buff <= vin1_buff >> (ALU_UNITS_SEW_64<<6);
				vin2_buff <= vin2_buff >> (ALU_UNITS_SEW_64<<6);
				counter <= counter + ALU_UNITS_SEW_64;
				write_counter <= write_counter + (ALU_UNITS_SEW_64<<6);
			end
			if (counter + ALU_UNITS_SEW_64 > vl_buff) begin
				state <= 0;
				out_valid <= 1;
			end else begin
				out_valid <= 0;
			end
		end
	end
end
endmodule



module riscv_vector_extension(
input clk,
input rst, 

input        	pcpi_valid,
input [31:0] 	pcpi_insn,
input [31:0] 	pcpi_rs1,
input [31:0] 	pcpi_rs2,
output       	pcpi_wr,
output  [31:0] 	pcpi_rd,
output       	pcpi_wait,
output 	    	pcpi_ready,

output        	pcpi_passthrough_valid,
output [31:0] 	pcpi_passthrough_insn,
output [31:0] 	pcpi_passthrough_rs1,
output [31:0] 	pcpi_passthrough_rs2,
input       	pcpi_passthrough_wr,
input  [31:0] 	pcpi_passthrough_rd,
input       	pcpi_passthrough_wait,
input 	    	pcpi_passthrough_ready,

output reg			cache_read,
output reg			cache_write,
output reg [31:0]	cache_address,
output reg [31:0]	cache_wrdata,
output reg [3:0]	cache_wrstrb,
input				cache_rdvalid,
input 	   [31:0]	cache_rddata,
input 	   [31:0]	cache_rdaddress,
input				cache_ready,

output reg 			mem_request
);

parameter ENABLE_PCPI_PASSTHROUGH = 0;
parameter XLEN = 32;
parameter CACHE_WORD_SIZE = 32;
parameter CACHE_ADDR_SIZE = 32;
parameter VLEN = 2048;// bits


parameter ENABLE_SEW_8 = 1;
parameter ALU_UNITS_SEW_8 =  4;
parameter ENABLE_SEW_8_ALU_ADD = 1;
parameter ENABLE_SEW_8_ALU_SUB = 1;
parameter ENABLE_SEW_8_ALU_MUL = 1;
parameter ENABLE_SEW_8_ALU_SLL = 1;
parameter ENABLE_SEW_8_ALU_SRL = 1;

parameter ENABLE_SEW_16 = 1;
parameter ALU_UNITS_SEW_16 = 4;
parameter ENABLE_SEW_16_ALU_ADD = 1;
parameter ENABLE_SEW_16_ALU_SUB = 1;
parameter ENABLE_SEW_16_ALU_MUL = 1;
parameter ENABLE_SEW_16_ALU_SLL = 1;
parameter ENABLE_SEW_16_ALU_SRL = 1;

parameter ENABLE_SEW_32 = 1;
parameter ALU_UNITS_SEW_32 = 4;
parameter ENABLE_SEW_32_ALU_ADD = 1;
parameter ENABLE_SEW_32_ALU_SUB = 1;
parameter ENABLE_SEW_32_ALU_MUL = 1;
parameter ENABLE_SEW_32_ALU_SLL = 1;
parameter ENABLE_SEW_32_ALU_SRL = 1;

parameter ENABLE_SEW_64 = 1;
parameter ALU_UNITS_SEW_64 = 4;
parameter ENABLE_SEW_64_ALU_ADD = 1;
parameter ENABLE_SEW_64_ALU_SUB = 1;
parameter ENABLE_SEW_64_ALU_MUL = 1;
parameter ENABLE_SEW_64_ALU_SLL = 1;
parameter ENABLE_SEW_64_ALU_SRL = 1;


parameter ENABLE_CSRRS_RW_VSTART = 1;
parameter ENABLE_CSRRS_RW_VSXSAT = 1;
parameter ENABLE_CSRRS_RW_VXRM = 1;
parameter ENABLE_CSRRS_RW_VCSR = 1;
parameter ENABLE_CSRRS_RW_VL = 1;
parameter ENABLE_CSRRS_RW_VTYPE = 1;
parameter ENABLE_CSRRS_RW_VLENB = 1;
parameter ENABLE_VSETVL = 1;
parameter ENABLE_VSETVLI = 1;
parameter ENABLE_VSETIVLI = 1;
parameter ENABLE_VL_WHOLE_REGISTER = 1;
parameter ENABLE_VS_WHOLE_REGISTER = 1;
parameter ENABLE_VL_UNIT_STRIDE = 1;
parameter ENABLE_VS_UNIT_STRIDE = 1;
parameter ENABLE_VL_STRIDED = 1;
parameter ENABLE_VS_STRIDED = 1;
parameter ENABLE_VL_INDEX_UNORDERED = 1;
parameter ENABLE_VS_INDEX_UNORDERED = 1;
parameter ENABLE_VL_INDEX_ORDERED = 1;
parameter ENABLE_VS_INDEX_ORDERED = 1;
parameter ENABLE_INTEGER_VECTOR_VECTOR_ADD = 1;
parameter ENABLE_FLOATINGPOINT_VECTOR_VECTOR_ADD = 1;


localparam VLMAX_SEW_8 = VLEN >> 3; 
localparam VLMAX_SEW_16 = VLEN >> 4; 
localparam VLMAX_SEW_32 = VLEN >> 5; 
localparam VLMAX_SEW_64 = VLEN >> 6; 


localparam BYTES_PER_CACHE_WORD = CACHE_WORD_SIZE >> 3;
wire [CACHE_ADDR_SIZE-1:0] CACHE_ADDRESS_MASK = {CACHE_ADDR_SIZE{1'b1}} ^ (BYTES_PER_CACHE_WORD - 1);
wire [CACHE_ADDR_SIZE-1:0] CACHE_ADDRESS_MASK_INV = ~CACHE_ADDRESS_MASK;



//   c:	8241                	vmsge.vx	v4,v0,ra,v0.t
//   9c:	00554e47          	fmsub.s	ft8,fa0,ft5,ft0,rmm
//  8c4:	c22022f3          	csrr	t0,vlenb
//  950:	c50277d7          	vsetivli	a5,4,e32,m1,ta,mu
//  988:	0d077057          	vsetvli	zero,a4,e32,m1,ta,ma
//  98c:	0207ec07          	vle32.v	v24,(a5)
//  990:	02868c27          	vs1r.v	v24,(a3)
//  a18:	0286ec87          	vl1re32.v	v25,(a3)
//  a28:	039c0c57          	vadd.vv	v24,v25,v24
//  a6c:	0206ec27          	vse32.v	v24,(a3)



/////////////////////////////// 4 stage vector processor///////////////////////
/*
	Stage 1 (1 cycle): IF stage (buffer inputs from pcpi interface), also sets pcpi_wait to 1
	Stage 2 (1 cycle): ID stage (decodes instr, gets vector registers)
	Stage 3 (variable): CEM (CFG/EX/MEM) stage (does one of load, store, arithmetic, cfg operations)
	Stage 4 (1 cycle): WB stage (updates value of rd and wr, also sets pcpi_wait to 0) 
*/



///////////////////////////////////////////// Register File /////////////////////////////////////////////
reg [VLEN-1:0] vregFile [0:31];



///////////////////////////////////////////// Busy signalling /////////////////////////////////////////////
assign pcpi_ready = CEM_WB_valid;
assign pcpi_wait = !pcpi_ready;



///////////////////////////////////////////// IF /////////////////////////////////////////////
reg [1:0]   IF_ID_valid;
reg [31:0] 	IF_ID_insn;
reg [XLEN-1:0] 	IF_ID_rs1;
reg [XLEN-1:0] 	IF_ID_rs2;

// pcpi_valid is held high while PCPI is active, but we want to generate a single cycle pulse per
// valid new pcpi instruction - this ensures only one pipeline stage has a <stage_src>_<stage_dst>_valid signal of `1`.
// Thus, IF_ID_valid is 2 bits to encode the states: 0: idle, 1: new pcpi transaction, 2: busy 
always @(posedge clk) begin
	// Only the IF_ID_valid signal needs to be conditionally modified, since the value of everything else
	// is ignored if IF_ID_valid[0] == 0
	IF_ID_insn <= pcpi_insn;
	IF_ID_rs1 <= pcpi_rs1;
	IF_ID_rs2 <= pcpi_rs2;
	// IF_ID_valid state machine
	if (rst)
		IF_ID_valid <= 0;
	else if (pcpi_valid  && (IF_ID_valid[1] == 1'b0))
		IF_ID_valid <= IF_ID_valid + 2'd1;
	else if (!pcpi_valid)
		IF_ID_valid <= 0;
end

///////////////////////////////////////////// ID /////////////////////////////////////////////

// Types of immediate supported
//  imm_19_15:  imm[4:0] <- insn[19:15]
//  imm_31_20:  imm[11:0] <- insn[31:20]
wire [6:0] ID_opcode = IF_ID_insn[6:0];
wire [4:0] ID_imm_19_15 = IF_ID_insn[19:15];
wire [12:0] ID_imm_31_20 = IF_ID_insn[31:20];
wire [5:0] ID_func6 = IF_ID_insn[31:26];
wire [2:0] ID_func3 = IF_ID_insn[14:12];
wire [4:0] ID_vd_regid = IF_ID_insn[11:7];
wire [4:0] ID_vs1_regid = IF_ID_insn[19:15];
wire [4:0] ID_vs2_regid = IF_ID_insn[24:20];
wire [4:0] ID_vs3_regid = IF_ID_insn[11:7];
wire [4:0] ID_rd_regid = IF_ID_insn[11:7];
wire [4:0] ID_rs1_regid = IF_ID_insn[19:15];
wire [4:0] ID_rs2_regid = IF_ID_insn[24:20];
wire ID_vm = IF_ID_insn[25];
wire [2:0] ID_nf = IF_ID_insn[31:29];
wire ID_mew = IF_ID_insn[28];
wire [1:0] ID_mop = IF_ID_insn[27:26];
wire [4:0] ID_sumop = IF_ID_insn[24:20];
wire [4:0] ID_lumop = IF_ID_insn[24:20];
wire [2:0] ID_loadstore_width = IF_ID_insn[14:12];
wire [10:0] ID_vtypei_vsetvli = IF_ID_insn[30:20];
wire [9:0] ID_vtypei_vsetivli = IF_ID_insn[29:20];
wire [XLEN-1:0] ID_avl = (ID_rs1_regid != 5'b00000) ? IF_ID_rs1 : ((ID_rd_regid != 5'b00000) ? {XLEN{1'b1}} : vl);

// Supported CSR instructions
reg ID_CEM_instr_csrrs_rw_vstart;
reg ID_CEM_instr_csrrs_rw_vxsat;
reg ID_CEM_instr_csrrs_rw_vxrm;
//// 0x00B - 0x00E are reserved for future vector CSRs
reg ID_CEM_instr_csrrs_rw_vcsr;
reg ID_CEM_instr_csrrs_ro_vl;
reg ID_CEM_instr_csrrs_ro_vtype;
reg ID_CEM_instr_csrrs_ro_vlenb;
// Supported Config Instructions
reg ID_CEM_instr_vsetivli;
reg ID_CEM_instr_vsetvli;
reg ID_CEM_instr_vsetvl;
// Supported Memory Instructions
reg ID_CEM_instr_vl_whole_register;
reg ID_CEM_instr_vs_whole_register;
reg ID_CEM_instr_vl_unit_stride;
reg ID_CEM_instr_vs_unit_stride;
reg ID_CEM_instr_vl_strided;
reg ID_CEM_instr_vs_strided;
reg ID_CEM_instr_vl_index_unordered;
reg ID_CEM_instr_vs_index_unordered;
reg ID_CEM_instr_vl_index_ordered;
reg ID_CEM_instr_vs_index_ordered;
// Supported Arithmetic Instructions
reg ID_CEM_instr_integer_vector_vector_add;
reg ID_CEM_instr_fp_vector_vector_add;


reg [VLEN-1:0] 	ID_CEM_vs1;
reg [VLEN-1:0] 	ID_CEM_vs2;
reg [31:0] ID_CEM_instr_flags;
reg ID_CEM_valid;
reg [31:0] 	ID_CEM_insn;
reg [XLEN-1:0] 	ID_CEM_rs1;
reg [XLEN-1:0] 	ID_CEM_rs2;

always @(posedge clk) begin
	ID_CEM_valid <= IF_ID_valid[0];
	if (IF_ID_valid[0]) begin
		ID_CEM_vs1 <= vregFile[(ID_opcode == 7'b0100111) ? ID_vs3_regid : ID_vs1_regid];
		ID_CEM_vs2 <= vregFile[ID_vs2_regid];
		ID_CEM_instr_csrrs_rw_vstart <=  (ID_opcode == 7'b1110011) && (ID_imm_31_20 == 12'h008) && (ID_func3 == 3'b010);
		ID_CEM_instr_csrrs_rw_vxsat <=  	(ID_opcode == 7'b1110011) && (ID_imm_31_20 == 12'h009) && (ID_func3 == 3'b010);
		ID_CEM_instr_csrrs_rw_vxrm <=  	(ID_opcode == 7'b1110011) && (ID_imm_31_20 == 12'h00A) && (ID_func3 == 3'b010);
		ID_CEM_instr_csrrs_rw_vcsr <=  	(ID_opcode == 7'b1110011) && (ID_imm_31_20 == 12'h00F) && (ID_func3 == 3'b010);
		ID_CEM_instr_csrrs_ro_vl <=  	(ID_opcode == 7'b1110011) && (ID_imm_31_20 == 12'hC20) && (ID_func3 == 3'b010);
		ID_CEM_instr_csrrs_ro_vtype <=  	(ID_opcode == 7'b1110011) && (ID_imm_31_20 == 12'hC21) && (ID_func3 == 3'b010);
		ID_CEM_instr_csrrs_ro_vlenb <=  	(ID_opcode == 7'b1110011) && (ID_imm_31_20 == 12'hC22) && (ID_func3 == 3'b010);
		ID_CEM_instr_vsetivli <= (ID_opcode == 7'b1010111) && (ID_func3 == 3'b111) && (IF_ID_insn[31:30] == 2'b11);
		ID_CEM_instr_vsetvli <= (ID_opcode == 7'b1010111) && (ID_func3 == 3'b111) && (IF_ID_insn[31] == 1'b0);
		ID_CEM_instr_vsetvl <= (ID_opcode == 7'b1010111) && (ID_func3 == 3'b111) && (IF_ID_insn[31] == 1'b1) && (IF_ID_insn[30:25] == 6'b000000);
		ID_CEM_instr_vl_whole_register <= (ID_opcode == 7'b0000111) && (ID_mop == 2'b00) && (ID_lumop == 5'b01000);
		ID_CEM_instr_vs_whole_register <= (ID_opcode == 7'b0100111) && (ID_mop == 2'b00) && (ID_sumop == 5'b01000);
		ID_CEM_instr_vl_unit_stride <= (ID_opcode == 7'b0000111) && (ID_mop == 2'b00) && (ID_lumop == 5'b00000);
		ID_CEM_instr_vs_unit_stride <= (ID_opcode == 7'b0100111) && (ID_mop == 2'b00) && (ID_sumop == 5'b00000);
		ID_CEM_instr_vl_strided <= (ID_opcode == 7'b0000111) && (ID_mop == 2'b10);
		ID_CEM_instr_vs_strided <= (ID_opcode == 7'b0100111) && (ID_mop == 2'b10);
		ID_CEM_instr_vl_index_unordered <= (ID_opcode == 7'b0000111) && (ID_mop == 2'b01);
		ID_CEM_instr_vs_index_unordered <= (ID_opcode == 7'b0100111) && (ID_mop == 2'b01);
		ID_CEM_instr_vl_index_ordered <= (ID_opcode == 7'b0000111) && (ID_mop == 2'b11);
		ID_CEM_instr_vs_index_ordered <= (ID_opcode == 7'b0100111) && (ID_mop == 2'b11);
		ID_CEM_instr_integer_vector_vector_add <= (ID_opcode == 7'b1010111) && (ID_func3 == 3'b000) && (ID_func6 == 6'b000000);
		ID_CEM_instr_fp_vector_vector_add <= (ID_opcode == 7'b1010111) && (ID_func3 == 3'b001) && (ID_func6 == 6'b000000);
		ID_CEM_insn <= IF_ID_insn;
		ID_CEM_rs1 <= IF_ID_rs1;
		ID_CEM_rs2 <= IF_ID_rs2;
	end
end

///////////////////////////////////////////// CEM (CFG/EX/MEM) /////////////////////////////////////////////


wire [6:0] CEM_opcode = ID_CEM_insn[6:0];
wire [4:0] CEM_imm_19_15 = ID_CEM_insn[19:15];
wire [12:0] CEM_imm_31_20 = ID_CEM_insn[31:20];
wire [5:0] CEM_func6 = ID_CEM_insn[31:26];
wire [2:0] CEM_func3 = ID_CEM_insn[14:12];
wire [4:0] CEM_vd_regid = ID_CEM_insn[11:7];
wire [4:0] CEM_vs1_regid = ID_CEM_insn[19:15];
wire [4:0] CEM_vs2_regid = ID_CEM_insn[24:20];
wire [4:0] CEM_vs3_regid = ID_CEM_insn[11:7];
wire [4:0] CEM_rd_regid = ID_CEM_insn[11:7];
wire [4:0] CEM_rs1_regid = ID_CEM_insn[19:15];
wire [4:0] CEM_rs2_regid = ID_CEM_insn[24:20];
wire CEM_vm = ID_CEM_insn[25];
wire [2:0] CEM_nf = ID_CEM_insn[31:29];
wire CEM_mew = ID_CEM_insn[28];
wire [1:0] CEM_mop = ID_CEM_insn[27:26];
wire [4:0] CEM_sumop = ID_CEM_insn[24:20];
wire [4:0] CEM_lumop = ID_CEM_insn[24:20];
wire [2:0] CEM_loadstore_width = ID_CEM_insn[14:12];
wire [10:0] CEM_vtypei_vsetvli = ID_CEM_insn[30:20];
wire [9:0] CEM_vtypei_vsetivli = ID_CEM_insn[29:20];
wire [XLEN-1:0] CEM_avl = (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? {XLEN{1'b1}} : vl);



wire [XLEN-1:0] vlenb = VLEN >> 3;
wire [XLEN-1:0] vtype;
wire [XLEN-1:0] vcsr;
assign vtype[XLEN-1] = vill;
assign vtype[XLEN-2:8] = 0;
assign vtype[7] = vma;
assign vtype[6] = vta;
assign vtype[5:3] = vsew;
assign vtype[2:0] = vlmul;
assign vcsr[XLEN-1:3] = 0;
assign vcsr[2:1] = vxrm[1:0];
assign vcsr[0] = vxsat[0];

reg [XLEN-1:0] vl;
reg [XLEN-1:0] vstart;
reg [XLEN-1:0] vxsat;
reg [XLEN-1:0] vxrm;
reg [2:0] vsew;
reg [2:0] vlmul;
reg vta;
reg vma;
reg vill;
reg [XLEN-1:0] avl;
reg [XLEN-1:0] CEM_WB_rd;
reg CEM_WB_wren;
reg CEM_WB_valid;

reg [7:0] ex_state;
reg [7:0] mem_state;
reg exit_em;
reg start_ex;
reg start_mem;


reg [31:0]			MEM_base_address;
reg [4:0]			MEM_base_destreg;
reg [4:0]			MEM_base_srcreg;
reg 				MEM_mem_load;
reg 				MEM_mem_store;
reg 				MEM_mask;
reg [XLEN-1:0]		MEM_bytes_to_load;
reg [XLEN-1:0]		MEM_bytes_to_store;
reg [XLEN-1:0]		MEM_bits_per_access;
reg [XLEN-1:0]		MEM_stride_size_bytes;
reg [CACHE_ADDR_SIZE-1:0]		MEM_single_element_width; // in bytes
reg MEM_whole_reg;

reg EX_mask;
reg EX_op_add;
reg EX_op_sub;
reg EX_op_mul;
reg EX_op_sll;
reg EX_op_srl;

// Illegal instruction 
always @(posedge clk) begin
	if (rst)
	   vill <= 0;
	else if (ID_CEM_valid && (|ID_CEM_instr_flags)) 
		vill <= 0;
	else if (ID_CEM_valid)
		vill <= 1;
end


always @(posedge clk) begin
	if (rst) begin
		CEM_WB_wren <= 0;
		CEM_WB_valid <= 0;
		CEM_WB_rd <= 0;
		vl <= VLMAX_SEW_32;
		vstart <= {XLEN{1'b0}};
		vxsat <= {XLEN{1'b0}}; // turned off
		vxrm <= { {XLEN-2{1'b0}},2'b10}; // round down
		vsew <= 3'b010; // Single Element Width (SEW) of 32
		vlmul <= 3'b000;  // VLEN/SEW
		vta <= 1'b1;
		vma <= 1'b1;
		avl <= {XLEN{1'b1}};
		exit_em <= 0;
		vill <= 0;
		start_ex <= 0;
		start_mem <= 0;
		MEM_base_address <= 0;
		MEM_base_destreg <= 0;
		MEM_base_srcreg <= 0;
		MEM_mem_load <= 0;
		MEM_mem_store <= 0;
		MEM_bytes_to_load <= 0;
		MEM_bytes_to_store <= 0;
		MEM_bits_per_access <= CACHE_WORD_SIZE; 
		MEM_stride_size_bytes <= 0;
		MEM_single_element_width <= 0;
		MEM_whole_reg <= 0;
		MEM_mask <= 0;			
		EX_op_add <= 0;
		EX_op_sub <= 0;
		EX_op_mul <= 0;
		EX_op_sll <= 0;
		EX_op_srl <= 0;
		EX_mask <= 0;


	end else if (ex_state | mem_state) begin
		exit_em <= 1;
		CEM_WB_wren <= 0; //(ex_state) ? CEM_WB_EX_wren : 0;
		CEM_WB_rd <= 0; // CEM_WB_EX_rd;
		vill <= 0;
		start_ex <= 0;
		start_mem <= 0;

	end else if (start_ex | start_mem) begin
		// wait for the ex/mem state machine to start

	end else if (exit_em) begin
		CEM_WB_valid <= 1;
		vill <= 0;
		vstart <= 0;
		exit_em <= 0;

	end else if (ID_CEM_valid) begin
		if (ID_CEM_instr_vsetvl && ENABLE_VSETVL) begin 
			if (ID_CEM_rs2[5:3] == 3'b000) begin
				vl <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_8 : vl);
			end else if (ID_CEM_rs2[5:3] == 3'b001) begin
				vl <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_16 : vl);
			end else if (ID_CEM_rs2[5:3] == 3'b010) begin
				vl <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_32 : vl);
			end else begin
				vl <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_64 : vl);
			end 
			vma <= ID_CEM_rs2[7];
			vta <= ID_CEM_rs2[6];
			vsew <= ID_CEM_rs2[5:3];
			vlmul <= ID_CEM_rs2[2:0];
			CEM_WB_wren <= 1;
			CEM_WB_rd <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_32 : vl);
			if (ID_CEM_rs2[5:3] == 3'b000) begin
				CEM_WB_rd <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_8 : vl);
			end else if (ID_CEM_rs2[5:3] == 3'b001) begin
				CEM_WB_rd <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_16 : vl);
			end else if (ID_CEM_rs2[5:3] == 3'b010) begin
				CEM_WB_rd <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_32 : vl);
			end else begin
				CEM_WB_rd <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_64 : vl);
			end 
			CEM_WB_valid <= 1;
			vill <= 0;
			vstart <= 0;

		end else if (ID_CEM_instr_vsetvli && ENABLE_VSETVLI) begin  	
			if (CEM_vtypei_vsetvli[5:3] == 3'b000) begin
				vl <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_8 : vl);
			end else if (CEM_vtypei_vsetvli[5:3] == 3'b001) begin
				vl <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_16 : vl);
			end else if (CEM_vtypei_vsetvli[5:3] == 3'b010) begin
				vl <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_32 : vl);
			end else begin
				vl <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_64 : vl);
			end 
			vma <= CEM_vtypei_vsetvli[7];
			vta <= CEM_vtypei_vsetvli[6];
			vsew <= CEM_vtypei_vsetvli[5:3];
			vlmul <= CEM_vtypei_vsetvli[2:0];
			CEM_WB_wren <= 1;
			if (CEM_vtypei_vsetvli[5:3] == 3'b000) begin
				CEM_WB_rd <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_8 : vl);
			end else if (CEM_vtypei_vsetvli[5:3] == 3'b001) begin
				CEM_WB_rd <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_16 : vl);
			end else if (CEM_vtypei_vsetvli[5:3] == 3'b010) begin
				CEM_WB_rd <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_32 : vl);
			end else begin
				CEM_WB_rd <= (CEM_rs1_regid != 5'b00000) ? ID_CEM_rs1 : ((CEM_rd_regid != 5'b00000) ? VLMAX_SEW_64 : vl);
			end 
			CEM_WB_valid <= 1;
			vill <= 0;
			vstart <= 0;

		end else if (ID_CEM_instr_vsetivli && ENABLE_VSETIVLI) begin 
			vl <= {{XLEN-5{1'b0}}, CEM_imm_19_15};
			vma <= CEM_vtypei_vsetivli[7];
			vta <= CEM_vtypei_vsetivli[6];
			vsew <= CEM_vtypei_vsetivli[5:3];
			vlmul <= CEM_vtypei_vsetivli[2:0];
			CEM_WB_wren <= 1;
			if (CEM_vtypei_vsetivli[5:3] == 3'b000) begin
				CEM_WB_rd <= {{XLEN-5{1'b0}}, CEM_imm_19_15};
			end else if (CEM_vtypei_vsetivli[5:3] == 3'b001) begin
				CEM_WB_rd <= {{XLEN-5{1'b0}}, CEM_imm_19_15};
			end else if (CEM_vtypei_vsetivli[5:3] == 3'b010) begin
				CEM_WB_rd <= {{XLEN-5{1'b0}}, CEM_imm_19_15};
			end else begin
				CEM_WB_rd <= {{XLEN-5{1'b0}}, CEM_imm_19_15};
			end 
			CEM_WB_valid <= 1;
			vill <= 0;
			vstart <= 0;

		end else if (ID_CEM_instr_csrrs_rw_vstart  && ENABLE_CSRRS_RW_VSTART) begin  
			vstart <= ID_CEM_rs1;
			CEM_WB_rd <= ID_CEM_rs1;
			CEM_WB_wren <= 1;
			CEM_WB_valid <= 1;

		end else if (ID_CEM_instr_csrrs_rw_vxsat && ENABLE_CSRRS_RW_VSXSAT) begin  
			vxsat <= ID_CEM_rs1;
			CEM_WB_rd <= vxsat;
			CEM_WB_wren <= 1;
			CEM_WB_valid <= 1;


		end else if (ID_CEM_instr_csrrs_rw_vxrm && ENABLE_CSRRS_RW_VXRM) begin   
			vxrm <= ID_CEM_rs1;
			CEM_WB_rd <= vxrm;
			CEM_WB_wren <= 1;
			CEM_WB_valid <= 1;


		end else if (ID_CEM_instr_csrrs_rw_vcsr && ENABLE_CSRRS_RW_VCSR) begin   
			vxsat[0] <= ID_CEM_rs1[0];  
			vxrm[1:0] <= ID_CEM_rs1[2:1];
			CEM_WB_rd <= vcsr;
			CEM_WB_wren <= 1;
			CEM_WB_valid <= 1;

		end else if (ID_CEM_instr_csrrs_ro_vl && ENABLE_CSRRS_RW_VL) begin  
			CEM_WB_rd <= vl;
			CEM_WB_wren <= 1;
			CEM_WB_valid <= 1;

		end else if (ID_CEM_instr_csrrs_ro_vtype && ENABLE_CSRRS_RW_VTYPE) begin  
			CEM_WB_rd <= vtype;
			CEM_WB_wren <= 1;
			CEM_WB_valid <= 1;

		end else if (ID_CEM_instr_csrrs_ro_vlenb && ENABLE_CSRRS_RW_VLENB) begin  
			CEM_WB_rd <= vlenb;
			CEM_WB_wren <= 1;
			CEM_WB_valid <= 1;

		end else if (ID_CEM_instr_vl_whole_register && ENABLE_VL_WHOLE_REGISTER) begin
			MEM_base_address <= ID_CEM_rs1;
			MEM_base_destreg <= CEM_vd_regid;
			MEM_mem_load <= 1;
			MEM_mem_store <= 0;
			MEM_bytes_to_load <= VLEN >> 3;
			MEM_bits_per_access <= CACHE_WORD_SIZE;
			MEM_mask <= ~CEM_vm;
			MEM_whole_reg <= 1;
			start_mem <= 1;
			if (vsew[2:0] == 3'b000) begin
				MEM_stride_size_bytes <= 1;
				MEM_single_element_width <= 1;
			end else if (vsew[2:0] == 3'b001) begin
				MEM_stride_size_bytes <= 2;
				MEM_single_element_width <= 2;
			end else if (vsew[2:0] == 3'b010) begin
				MEM_stride_size_bytes <= 4;
				MEM_single_element_width <= 4;
			end else if (vsew[2:0] == 3'b011) begin
				MEM_stride_size_bytes <= 8;
				MEM_single_element_width <= 8;
			end else  begin
				MEM_stride_size_bytes <= 0;
				MEM_single_element_width <= 0;
			end 
			
		end else if (ID_CEM_instr_vs_whole_register && ENABLE_VS_WHOLE_REGISTER) begin
			MEM_base_address <= ID_CEM_rs1;
			MEM_base_srcreg <= CEM_vd_regid;
			MEM_mem_load <= 0;
			MEM_mem_store <= 1;
			MEM_bytes_to_store <= VLEN >> 3;
			MEM_bits_per_access <= CACHE_WORD_SIZE;
			MEM_mask <= ~CEM_vm;
			MEM_whole_reg <= 1;
			start_mem <= 1;
			if (vsew[2:0] == 3'b000) begin
				MEM_stride_size_bytes <= 1;
				MEM_single_element_width <= 1;
			end else if (vsew[2:0] == 3'b001) begin
				MEM_stride_size_bytes <= 2;
				MEM_single_element_width <= 2;
			end else if (vsew[2:0] == 3'b010) begin
				MEM_stride_size_bytes <= 4;
				MEM_single_element_width <= 4;
			end else if (vsew[2:0] == 3'b011) begin
				MEM_stride_size_bytes <= 8;
				MEM_single_element_width <= 8;
			end else  begin
				MEM_stride_size_bytes <= 0;
				MEM_single_element_width <= 0;
			end 

		end else if (ID_CEM_instr_vl_unit_stride && ENABLE_VL_UNIT_STRIDE) begin
			MEM_base_address <= ID_CEM_rs1;
			MEM_base_destreg <= CEM_vd_regid;
			MEM_mem_load <= 1;
			MEM_mem_store <= 0;
			MEM_bits_per_access <= CACHE_WORD_SIZE;
			MEM_mask <= ~CEM_vm;
			MEM_whole_reg <= 0;
			start_mem <= 1;
			if (vsew[2:0] == 3'b000) begin
				MEM_bytes_to_load <= vl;
				MEM_stride_size_bytes <= 1;
				MEM_single_element_width <= 1;
			end else if (vsew[2:0] == 3'b001) begin
				MEM_bytes_to_load <= vl << 1; 
				MEM_stride_size_bytes <= 2;
				MEM_single_element_width <= 2;
			end else if (vsew[2:0] == 3'b010) begin
				MEM_bytes_to_load <= vl << 2; 
				MEM_stride_size_bytes <= 4;
				MEM_single_element_width <= 4;
			end else if (vsew[2:0] == 3'b011) begin
				MEM_bytes_to_load <= vl << 3; 
				MEM_stride_size_bytes <= 8;
				MEM_single_element_width <= 8;
			end else  begin
				MEM_bytes_to_load <= 0; // invalid vsew value, don't store anything
				MEM_stride_size_bytes <= 0;
				MEM_single_element_width <= 0;
			end 


		end else if (ID_CEM_instr_vs_unit_stride && ENABLE_VS_UNIT_STRIDE) begin
			MEM_base_address <= ID_CEM_rs1;
			MEM_base_srcreg <= CEM_vd_regid;
			MEM_mem_load <= 0;
			MEM_mem_store <= 1;
			MEM_bits_per_access <= CACHE_WORD_SIZE;
			MEM_mask <= ~CEM_vm;
			MEM_whole_reg <= 0;
			start_mem <= 1;
			if (vsew[2:0] == 3'b000) begin
				MEM_bytes_to_store <= vl << 0; // 8 bit single element width
				MEM_stride_size_bytes <= 1;
				MEM_single_element_width <= 1;
			end else if (vsew[2:0] == 3'b001) begin
				MEM_bytes_to_store <= vl << 1; // 16 bit single element width
				MEM_stride_size_bytes <= 2;
				MEM_single_element_width <= 2;
			end else if (vsew[2:0] == 3'b010) begin
				MEM_bytes_to_store <= vl << 2; // 32 bit single element width
				MEM_stride_size_bytes <= 4;
				MEM_single_element_width <= 4;
			end else if (vsew[2:0] == 3'b011) begin
				MEM_bytes_to_store <= vl << 3; // 64 bit single element width
				MEM_stride_size_bytes <= 8;
				MEM_single_element_width <= 8;
			end else  begin
				MEM_bytes_to_store <= 0; // invalid vsew value, don't store anything
				MEM_stride_size_bytes <= 0;
				MEM_single_element_width <= 0;
			end 
		
		end else if (ID_CEM_instr_vl_strided && ENABLE_VL_STRIDED) begin
			MEM_base_address <= ID_CEM_rs1;
			MEM_base_destreg <= CEM_vd_regid;
			MEM_mem_load <= 1;
			MEM_mem_store <= 0;
			MEM_bits_per_access <= CACHE_WORD_SIZE;
			MEM_mask <= ~CEM_vm;
			MEM_whole_reg <= 0;
			start_mem <= 1;
			if (vsew[2:0] == 3'b000) begin
				MEM_bytes_to_load <= vl << 0;
				MEM_stride_size_bytes <= ID_CEM_rs2; // multiply stride amount by 1
				MEM_single_element_width <= 1;
			end else if (vsew[2:0] == 3'b001) begin
				MEM_bytes_to_load <= vl << 1; 
				MEM_stride_size_bytes <= ID_CEM_rs2 << 1; // multiply stride amount by 2
				MEM_single_element_width <= 2;
			end else if (vsew[2:0] == 3'b010) begin
				MEM_bytes_to_load <= vl << 2; 
				MEM_stride_size_bytes <= ID_CEM_rs2 << 2; // multiply stride amount by 4
				MEM_single_element_width <= 4;
			end else if (vsew[2:0] == 3'b011) begin
				MEM_bytes_to_load <= vl << 3; 
				MEM_stride_size_bytes <= ID_CEM_rs2 << 3; // multiply stride amount by 8
				MEM_single_element_width <= 8;
			end else  begin
				MEM_bytes_to_load <= 0; // invalid vsew value, don't store anything
				MEM_stride_size_bytes <= 0;
				MEM_single_element_width <= 0;
			end 

		end else if (ID_CEM_instr_vs_strided && ENABLE_VS_STRIDED) begin
			MEM_base_address <= ID_CEM_rs1;
			MEM_base_srcreg <= CEM_vd_regid;
			MEM_mem_load <= 0;
			MEM_mem_store <= 1;
			MEM_bits_per_access <= CACHE_WORD_SIZE;
			MEM_mask <= ~CEM_vm;
			MEM_whole_reg <= 0;
			start_mem <= 1;
			if (vsew[2:0] == 3'b000) begin
				MEM_bytes_to_store <= vl << 0; // 8 bit single element width
				MEM_stride_size_bytes <= ID_CEM_rs2; // multiply stride amount by 1
				MEM_single_element_width <= 1;
			end else if (vsew[2:0] == 3'b001) begin
				MEM_bytes_to_store <= vl << 1; // 16 bit single element width
				MEM_stride_size_bytes <= ID_CEM_rs2 << 1; // multiply stride amount by 2
				MEM_single_element_width <= 2;
			end else if (vsew[2:0] == 3'b010) begin
				MEM_bytes_to_store <= vl << 2; // 32 bit single element width
				MEM_stride_size_bytes <= ID_CEM_rs2 << 2; // multiply stride amount by 4
				MEM_single_element_width <= 4;
			end else if (vsew[2:0] == 3'b011) begin
				MEM_bytes_to_store <= vl << 3; // 64 bit single element width
				MEM_stride_size_bytes <= ID_CEM_rs2 << 3; // multiply stride amount by 8
				MEM_single_element_width <= 8;
			end else  begin
				MEM_bytes_to_store <= 0; // invalid vsew value, don't store anything
				MEM_stride_size_bytes <= 0;
				MEM_single_element_width <= 0;
			end 

		// end else if (ID_CEM_instr_vl_index_unordered && ENABLE_VL_INDEX_UNORDERED) begin

		// end else if (ID_CEM_instr_vs_index_unordered && ENABLE_VS_INDEX_UNORDERED) begin

		// end else if (ID_CEM_instr_vl_index_ordered && ENABLE_VL_INDEX_ORDERED) begin

		// end else if (ID_CEM_instr_vs_index_ordered && ENABLE_VS_INDEX_ORDERED) begin

		end else if (ID_CEM_instr_integer_vector_vector_add && ENABLE_INTEGER_VECTOR_VECTOR_ADD) begin
			start_ex <= 1;
			EX_mask <= ~CEM_vm;
			EX_op_add <= 1;
			EX_op_sub <= 0;
			EX_op_mul <= 0;
			EX_op_sll <= 0;
			EX_op_srl <= 0;
			// EX_in_1_isVector <= 1;
			// EX_in_1_isScalar <= 0;
			// EX_in_1_rs1 <= ID_CEM_rs1;
			// if (vsew[2:0] == 3'b000) begin
			// 	EX_in_1_imm <= {{3{CEM_imm_19_15[4]}}, CEM_imm_19_15};
			// end else if (vsew[2:0] == 3'b001) begin
			// 	EX_in_1_imm <= {{11{CEM_imm_19_15[4]}}, CEM_imm_19_15};
			// end else if (vsew[2:0] == 3'b010) begin
			// 	EX_in_1_imm <= {{27{CEM_imm_19_15[4]}}, CEM_imm_19_15};
			// end else if (vsew[2:0] == 3'b011) begin
			// 	EX_in_1_imm <= {{59{CEM_imm_19_15[4]}}, CEM_imm_19_15};
			// end else  begin
			// 	EX_in_1_imm <= 0;
			// end 
			// EX_in_1_isVector <= 1;
			// EX_out_isVector <= 1;
			// EX_out_isScalar <= 0;
			


		// end else if (ID_CEM_instr_fp_vector_vector_add && ENABLE_FLOATINGPOINT_VECTOR_VECTOR_ADD) begin
			
		end else begin
			CEM_WB_wren <= 0;
			CEM_WB_valid <= 1; // return even if invalid instruction, but don't modify memory or regfile
			vill <= 1;
		end	

	end else begin
		CEM_WB_valid <= 0;
		CEM_WB_wren <= 0;
	end
end


// RegFile
reg [VLEN-1:0] vs1;
reg [VLEN-1:0] vs2;
reg [VLEN-1:0] vd_mem;
reg [VLEN-1:0] vd_ex;

reg [VLEN-1:0] v0_register;
initial v0_register = {VLEN{1'b1}};

reg vregFile_wen_mem;
reg vregFile_wen_ex;
wire vregFile_wen = vregFile_wen_mem | vregFile_wen_ex;

// Since operation length can exceed register length, we may need to update target regFile registers 
reg [4:0]			MEM_base_destreg_effective;
reg [4:0]			MEM_base_srcreg_effective;


always @(posedge clk) begin
	if (mem_request ) begin
		vs1 <= vregFile[MEM_mem_store ? MEM_base_srcreg_effective : MEM_base_destreg_effective]; // for mem ops, rs1 is used instead of vs1 to give base address, so vd is used for vs1 addr
		vs2 <= vregFile[CEM_vs2_regid];  // vs2 is typically address offsets, or sumop/lumop for unit strides
	end else if (ex_state == 1) begin
		vs1 <= vregFile[CEM_vs1_regid];
		vs2 <= vregFile[CEM_vs2_regid];
	end else if (ex_state == 2) begin
		vs1 <= vregFile[0];
		vs2 <= vregFile[CEM_vd_regid];
	end else begin
		vs1 <= vregFile[CEM_vs1_regid];
		vs2 <= vregFile[CEM_vs2_regid]; 
	end

	if (vregFile_wen) begin
		if (vregFile_wen_mem) begin// we only need to write something for load operations 
			vregFile[MEM_base_destreg_effective] <= vd_mem;  // mem ops load data into this register before writing to the regFile
			if (MEM_base_destreg_effective == 0) begin // for mask register, make a copy so we don't need another regFile port
				v0_register <= vd_mem;
			end
		end else if (vregFile_wen_ex) begin
			vregFile[CEM_vd_regid] <= vd_ex;
		end
	end
end



// Memory - little endian access
//vstart not supported in the current version

reg [CACHE_WORD_SIZE-1:0] cache_rddata_buff;
reg [31:0] vd_mem_elementcounter;
reg [31:0] vd_mem_pointer;
reg [31:0] vs1_mem_elementcounter;
reg [31:0] vs1_mem_pointer;
reg [31:0] total_bytes_processed;
reg [3:0] cache_elementcounter;
reg [XLEN-1:0] variable_MEM_stride_size_bytes;
reg [CACHE_ADDR_SIZE-1:0] cache_word_offset;
wire word_fully_loaded = ((cache_elementcounter + (CACHE_WORD_SIZE >> 3)) >= MEM_single_element_width) ? 1 : 0;
wire word_fully_stored = word_fully_loaded;
always @(posedge clk) begin
	if (rst) begin
		mem_state <= 0;
		cache_read <= 0;
		cache_write <= 0;
		cache_address <= 0;
		cache_wrdata <= 0;
		cache_wrstrb <= 0;
		mem_request <= 0;
		vregFile_wen_mem <= 0;
		vd_mem <= 0;
		vd_mem_pointer <= 0;
		vs1_mem_elementcounter <= 0;
		vs1_mem_pointer <= 0;
		MEM_base_destreg_effective <= MEM_base_destreg;
		MEM_base_srcreg_effective <= MEM_base_srcreg;
		cache_rddata_buff <= 0;
		cache_elementcounter <= 0;
		total_bytes_processed <= 0;
		variable_MEM_stride_size_bytes <= MEM_stride_size_bytes;
		cache_word_offset <= 0;
		// cache_rdvalid,
		// cache_rddata,
		// cache_rdaddress,
		// cache_ready,
	end else if (mem_state == 0) begin
		cache_read <= 0;
		cache_write <= 0;
		cache_address <= 0;
		cache_wrdata <= 0;
		cache_wrstrb <= 0;
		vregFile_wen_mem <= 0;
		vd_mem <= 0;
		vd_mem_elementcounter <= 0;
		vd_mem_pointer <= 0;
		vs1_mem_elementcounter <= 0;
		vs1_mem_pointer <= 0;
		MEM_base_destreg_effective <= MEM_base_destreg;
		MEM_base_srcreg_effective <= MEM_base_srcreg;
		cache_rddata_buff <= 0;
		cache_elementcounter <= 0;
		total_bytes_processed <= 0;
		variable_MEM_stride_size_bytes <= MEM_stride_size_bytes;
		cache_word_offset <= 0;
		if (start_mem) begin
			mem_state <= 1;
			mem_request <= 1;
		end else begin
			mem_state <= 0;
			mem_request <= 0;
		end

	end else if (mem_state == 1) begin
		cache_address <= MEM_base_address & CACHE_ADDRESS_MASK;
		cache_word_offset <= MEM_base_address & CACHE_ADDRESS_MASK_INV;
		if (MEM_single_element_width == 0) begin
			mem_state <= 0;
		end else if (MEM_mem_load) begin
			mem_state <= 2;
		end else begin
			mem_state <= 5;
		end

	end else if (mem_state == 2) begin // request cache read
		cache_read <= 1;
		vregFile_wen_mem <= 0;
		cache_elementcounter <= word_fully_loaded ? 0 : cache_elementcounter;
		if (cache_ready)		// if cache is ready, assume request will be accepted
			mem_state <= 3;

	end else if (mem_state == 3) begin // wait for cache to respond with read data
		cache_read <= 0;
		vd_mem <= vs1;
		if (cache_rdvalid) begin
			cache_rddata_buff <= cache_rddata;
			mem_state <= 4;
		end

	end else if (mem_state == 4) begin 
		vregFile_wen_mem <= 1;
		if ((CACHE_WORD_SIZE >> 3) == MEM_single_element_width) begin
			vd_mem[vd_mem_pointer +: CACHE_WORD_SIZE] <= (!MEM_mask || (MEM_mask && v0_register[vd_mem_elementcounter])) ?  cache_rddata_buff : vd_mem[vd_mem_pointer +: CACHE_WORD_SIZE];
			total_bytes_processed <= total_bytes_processed + (CACHE_WORD_SIZE >> 3);
			if (MEM_bytes_to_load <= total_bytes_processed + MEM_single_element_width) begin
				mem_state <= 0;
			end else if ((vd_mem_elementcounter + 1) > (MEM_whole_reg ? VLEN>>3 : vl)) begin
				MEM_base_destreg_effective <= MEM_base_destreg_effective + 1;
				vd_mem_elementcounter <= 0;
				vd_mem_pointer <= 0;
				cache_address <= cache_address + MEM_stride_size_bytes;
				mem_state <= 2;
			end else begin
				vd_mem_elementcounter <= vd_mem_elementcounter + 1;
				vd_mem_pointer <= vd_mem_pointer + CACHE_WORD_SIZE;
				cache_address <= cache_address + MEM_stride_size_bytes;
				mem_state <= 2;
			end

		end else if ((CACHE_WORD_SIZE>> 3) < MEM_single_element_width) begin
			vd_mem[vd_mem_pointer +:  CACHE_WORD_SIZE] <= (!MEM_mask || (MEM_mask && v0_register[vd_mem_elementcounter])) ?  cache_rddata_buff : vd_mem[vd_mem_pointer +:  CACHE_WORD_SIZE];
			total_bytes_processed <= total_bytes_processed + (CACHE_WORD_SIZE >> 3);
			cache_elementcounter <= cache_elementcounter + (CACHE_WORD_SIZE >> 3);
			if (MEM_bytes_to_load <= total_bytes_processed + MEM_single_element_width) begin
				mem_state <= 0;
			end else if ((vd_mem_elementcounter + 1) > (MEM_whole_reg ? VLEN>>3 : vl)) begin
				MEM_base_destreg_effective <= MEM_base_destreg_effective + 1;
				vd_mem_elementcounter <= 0;
				cache_address <= cache_address + (word_fully_loaded ? variable_MEM_stride_size_bytes : (CACHE_WORD_SIZE >> 3));
				variable_MEM_stride_size_bytes <= word_fully_loaded ? MEM_stride_size_bytes : variable_MEM_stride_size_bytes - (CACHE_WORD_SIZE >> 3);
				mem_state <= 2;
			end else begin
				vd_mem_elementcounter <= vd_mem_elementcounter + (word_fully_loaded ? 1 : 0);
				vd_mem_pointer <= vd_mem_pointer + CACHE_WORD_SIZE;
				cache_address <= cache_address + (word_fully_loaded ? variable_MEM_stride_size_bytes : (CACHE_WORD_SIZE >> 3));
				variable_MEM_stride_size_bytes <= word_fully_loaded ? MEM_stride_size_bytes : variable_MEM_stride_size_bytes - (CACHE_WORD_SIZE >> 3);
				mem_state <= 2;
			end

		end else begin
			if ((MEM_single_element_width == 1) && ENABLE_SEW_8) begin
				vd_mem[vd_mem_pointer +:  8] <= (!MEM_mask || (MEM_mask && v0_register[vd_mem_elementcounter])) ?  cache_rddata_buff[(cache_word_offset<<3)+:8] : vd_mem[vd_mem_pointer +:8]; // assuming the entire vector element fits in a single cache word
			end else if ((MEM_single_element_width == 2) && ENABLE_SEW_16) begin
				vd_mem[vd_mem_pointer +:  16] <= (!MEM_mask || (MEM_mask && v0_register[vd_mem_elementcounter])) ?  cache_rddata_buff[(cache_word_offset<<3)+:16] : vd_mem[vd_mem_pointer +: 16]; 
			end else if ((MEM_single_element_width == 4) && ENABLE_SEW_32) begin
				vd_mem[vd_mem_pointer +:  32] <= (!MEM_mask || (MEM_mask && v0_register[vd_mem_elementcounter])) ?  cache_rddata_buff[(cache_word_offset<<3)+: 32] : vd_mem[vd_mem_pointer +: 32]; 
			end else if ((MEM_single_element_width == 8) && ENABLE_SEW_64) begin
				vd_mem[vd_mem_pointer +:  64] <= (!MEM_mask || (MEM_mask && v0_register[vd_mem_elementcounter])) ?  cache_rddata_buff[(cache_word_offset<<3)+: 64] : vd_mem[vd_mem_pointer +: 64]; 
			end else begin
				vd_mem <= vd_mem;
			end

			total_bytes_processed <= total_bytes_processed + MEM_single_element_width;
			vd_mem_pointer <= vd_mem_pointer + (MEM_single_element_width<<3);
			if ((vd_mem_elementcounter + 1) > (MEM_whole_reg ? VLEN>>3 : vl)) begin
				MEM_base_destreg_effective <= MEM_base_destreg_effective + 1;
				vd_mem_elementcounter <= 0;
				vd_mem_pointer <= 0;
			end else begin
				vd_mem_elementcounter <= vd_mem_elementcounter + 1;
				vd_mem_pointer <= vd_mem_pointer + (MEM_single_element_width<<3);
			end
			if (MEM_bytes_to_load <= total_bytes_processed + MEM_single_element_width) begin
				mem_state <= 0;
			end else begin
				mem_state <= 2;
				cache_address <= (cache_address + cache_word_offset + MEM_stride_size_bytes) & CACHE_ADDRESS_MASK;
				cache_word_offset <= (cache_address + cache_word_offset +  MEM_stride_size_bytes) & CACHE_ADDRESS_MASK_INV;
			end
		end

	end else if (mem_state == 5) begin 
		if ((CACHE_WORD_SIZE >> 3) == MEM_single_element_width) begin
			cache_wrdata <= vs1[vs1_mem_pointer +: CACHE_WORD_SIZE];
			total_bytes_processed <= total_bytes_processed + (CACHE_WORD_SIZE >> 3);
			cache_wrstrb <= (!MEM_mask || (MEM_mask && v0_register[vs1_mem_elementcounter])) ? {CACHE_WORD_SIZE>>3{1'b1}} : 0;
			if ((vs1_mem_elementcounter + 1) > (MEM_whole_reg ? VLEN>>3 : vl)) begin
				MEM_base_srcreg_effective <= MEM_base_srcreg_effective + 1;
				vs1_mem_elementcounter <= 0;
				vs1_mem_pointer <= 0;
			end else begin
				vs1_mem_elementcounter <= vs1_mem_elementcounter + 1;
				vs1_mem_pointer <= vs1_mem_pointer + CACHE_WORD_SIZE;
			end
			mem_state <= 6; 

		end else if ((CACHE_WORD_SIZE>> 3) < MEM_single_element_width) begin
			cache_wrdata <= vs1[vs1_mem_pointer +: CACHE_WORD_SIZE];
			cache_wrstrb <= (!MEM_mask || (MEM_mask && v0_register[vs1_mem_elementcounter])) ? {CACHE_WORD_SIZE>>3{1'b1}} : 0;
			total_bytes_processed <= total_bytes_processed + (CACHE_WORD_SIZE >> 3);
			cache_elementcounter <= cache_elementcounter + (CACHE_WORD_SIZE >> 3);
			if ((vd_mem_elementcounter + 1) > (MEM_whole_reg ? VLEN>>3 : vl)) begin
				MEM_base_srcreg_effective <= MEM_base_srcreg_effective + 1;
				vs1_mem_elementcounter <= 0;
				vs1_mem_pointer <= 0;
			end else begin
				vs1_mem_elementcounter <= vs1_mem_elementcounter + (word_fully_loaded ? 1 : 0);
				vs1_mem_pointer <= vs1_mem_pointer + CACHE_WORD_SIZE;
			end
			mem_state <= 8; 

		
		end else begin 

			if ((MEM_single_element_width == 1) && ENABLE_SEW_8) begin
				cache_wrdata <= (vs1[vs1_mem_pointer +: 8]) << (cache_word_offset<<3);
				cache_wrstrb <= (!MEM_mask || (MEM_mask && v0_register[vs1_mem_elementcounter])) ? {1{1'b1}} <<  cache_word_offset : 0;
			end else if ((MEM_single_element_width == 2) && ENABLE_SEW_16) begin
				cache_wrdata <= (vs1[vs1_mem_pointer +: 16]) << (cache_word_offset<<3);
				cache_wrstrb <= (!MEM_mask || (MEM_mask && v0_register[vs1_mem_elementcounter])) ? {2{1'b1}} <<  cache_word_offset : 0;
			end else if ((MEM_single_element_width == 4) && ENABLE_SEW_32) begin
				cache_wrdata <= (vs1[vs1_mem_pointer +: 32]) << (cache_word_offset<<3);
				cache_wrstrb <= (!MEM_mask || (MEM_mask && v0_register[vs1_mem_elementcounter])) ? {4{1'b1}} <<  cache_word_offset : 0; 
			end else if ((MEM_single_element_width == 8) && ENABLE_SEW_64) begin
				cache_wrdata <= (vs1[vs1_mem_pointer +: 64]) << (cache_word_offset<<3);
				cache_wrstrb <= (!MEM_mask || (MEM_mask && v0_register[vs1_mem_elementcounter])) ? {8{1'b1}} <<  cache_word_offset : 0;
			end else begin
				cache_wrdata <= cache_wrdata;
				cache_wrstrb <= cache_wrstrb;
			end
			
			total_bytes_processed <= total_bytes_processed + MEM_single_element_width;
			vs1_mem_pointer <= vs1_mem_pointer + (MEM_single_element_width<<3);
			if ((vd_mem_elementcounter + 1) > (MEM_whole_reg ? VLEN>>3 : vl)) begin
				MEM_base_destreg_effective <= MEM_base_destreg_effective + 1;
				vs1_mem_elementcounter <= 0;
				vs1_mem_pointer <= 0;
			end else begin
				vs1_mem_elementcounter <= vs1_mem_elementcounter + 1;
				vs1_mem_pointer <= vs1_mem_pointer + (MEM_single_element_width<<3);
			end
			mem_state <= 10; 
		end

	end else if (mem_state == 6) begin
		cache_write <= 1;
		if (cache_ready) begin
			mem_state <= 7;
		end

	end else if (mem_state == 7) begin
		cache_write <= 0;
		if (MEM_bytes_to_store <= total_bytes_processed) begin
			mem_state <= 0;
		end else begin
			cache_address <= cache_address + MEM_stride_size_bytes;
			mem_state <= 5;
		end

	end else if (mem_state == 8) begin
		cache_write <= 1;
		if (cache_ready) begin
			mem_state <= 9;
		end

	end else if (mem_state == 9) begin
		cache_write <= 0;
		if (MEM_bytes_to_store <= total_bytes_processed) begin
			mem_state <= 0;
		end else begin
			cache_address <= cache_address + (word_fully_stored ? variable_MEM_stride_size_bytes : (CACHE_WORD_SIZE >> 3));
			variable_MEM_stride_size_bytes <= word_fully_stored ? MEM_stride_size_bytes : variable_MEM_stride_size_bytes - (CACHE_WORD_SIZE >> 3);
			cache_elementcounter <= word_fully_stored ? 0 : cache_elementcounter;
			mem_state <= 5;
		end

	end else if (mem_state == 10) begin
		cache_write <= 1;
		if (cache_ready) begin
			mem_state <= 11;
		end

	end else if (mem_state == 11) begin
		cache_write <= 0;
		if (MEM_bytes_to_store <= total_bytes_processed) begin
			mem_state <= 0;
		end else begin
			cache_address <= (cache_address + cache_word_offset + MEM_stride_size_bytes) & CACHE_ADDRESS_MASK;
			cache_word_offset <= (cache_address + cache_word_offset +  MEM_stride_size_bytes) & CACHE_ADDRESS_MASK_INV;
			mem_state <= 5;
		end
	end
end


// EX ///

reg [VLEN-1:0] ex_vin1;
reg [VLEN-1:0] ex_vin2;
reg [VLEN-1:0] ex_v0;
wire [VLEN-1:0] ex_vout;
reg [VLEN-1:0] ex_vout_initial;
reg ex_alu_in_valid;
wire ex_alu_out_valid;


riscv_vector_extension_alu 
#(
.VLEN(VLEN),
.XLEN(XLEN),
.ENABLE_SEW_8(ENABLE_SEW_8),
.ALU_UNITS_SEW_8(ALU_UNITS_SEW_8),
.ENABLE_SEW_8_ALU_ADD(ENABLE_SEW_8_ALU_ADD),
.ENABLE_SEW_8_ALU_SUB(ENABLE_SEW_8_ALU_SUB),
.ENABLE_SEW_8_ALU_MUL(ENABLE_SEW_8_ALU_MUL),
.ENABLE_SEW_8_ALU_SLL(ENABLE_SEW_8_ALU_SLL),
.ENABLE_SEW_8_ALU_SRL(ENABLE_SEW_8_ALU_SRL),
.ENABLE_SEW_16(ENABLE_SEW_16),
.ALU_UNITS_SEW_16(ALU_UNITS_SEW_16),
.ENABLE_SEW_16_ALU_ADD(ENABLE_SEW_16_ALU_ADD),
.ENABLE_SEW_16_ALU_SUB(ENABLE_SEW_16_ALU_SUB),
.ENABLE_SEW_16_ALU_MUL(ENABLE_SEW_16_ALU_MUL),
.ENABLE_SEW_16_ALU_SLL(ENABLE_SEW_16_ALU_SLL),
.ENABLE_SEW_16_ALU_SRL(ENABLE_SEW_16_ALU_SRL),
.ENABLE_SEW_32(ENABLE_SEW_32),
.ALU_UNITS_SEW_32(ALU_UNITS_SEW_32),
.ENABLE_SEW_32_ALU_ADD(ENABLE_SEW_32_ALU_ADD),
.ENABLE_SEW_32_ALU_SUB(ENABLE_SEW_32_ALU_SUB),
.ENABLE_SEW_32_ALU_MUL(ENABLE_SEW_32_ALU_MUL),
.ENABLE_SEW_32_ALU_SLL(ENABLE_SEW_32_ALU_SLL),
.ENABLE_SEW_32_ALU_SRL(ENABLE_SEW_32_ALU_SRL),
.ENABLE_SEW_64(ENABLE_SEW_64),
.ALU_UNITS_SEW_64(ALU_UNITS_SEW_64),
.ENABLE_SEW_64_ALU_ADD(ENABLE_SEW_64_ALU_ADD),
.ENABLE_SEW_64_ALU_SUB(ENABLE_SEW_64_ALU_SUB),
.ENABLE_SEW_64_ALU_MUL(ENABLE_SEW_64_ALU_MUL),
.ENABLE_SEW_64_ALU_SLL(ENABLE_SEW_64_ALU_SLL),
.ENABLE_SEW_64_ALU_SRL(ENABLE_SEW_64_ALU_SRL)
)
rvealu(
.clk(clk),
.rst(rst),
.vsew(vsew),
.vl(vl),
.mask(EX_mask),
.vmask(ex_v0),
.vstart(vstart), //ignoring this for now
.vin1(ex_vin1),
.vin2(ex_vin2),
.vout_initial(ex_vout_initial), // keep original value if masked, or if tail/inactive elements
.op({{XLEN-5{1'b0}},EX_op_srl, EX_op_sll, EX_op_mul, EX_op_sub, EX_op_add }), //{ ..., <insert new op here>, srl, sll, mul, sub, add}
.vout(ex_vout),
.in_valid(ex_alu_in_valid), 
.out_valid(ex_alu_out_valid) 
);

always @(posedge clk) begin

	if (rst) begin
		ex_state <= 0;
		vregFile_wen_ex <= 0;
		ex_vout_initial <= 0;
		ex_alu_in_valid <= 0;
	end else if (ex_state == 0) begin
		vregFile_wen_ex <= 0;
		ex_state <= start_ex ?  1 : 0;
		ex_vout_initial <= 0;
		ex_alu_in_valid <= 0;
	end else if (ex_state == 1) begin
		ex_state <= 2;
	end else if (ex_state == 2) begin
		ex_vin1 <= vs1;
		ex_vin2 <= vs2;
		ex_state <= 3;
	end	else if (ex_state == 3) begin
		ex_v0 <= vs1;
		ex_vout_initial <= vs2;
		ex_alu_in_valid <= 1;
		ex_state <= 4;
	end	else if (ex_state == 4) begin
		ex_alu_in_valid <= 0;
		if (ex_alu_out_valid) begin
			ex_state <= 0;
			vd_ex <= ex_vout;
			vregFile_wen_ex <= 1;
		end
	end	
end




///////////////////////////////////////////// WB /////////////////////////////////////////////

assign pcpi_wr = CEM_WB_wren;
assign pcpi_rd = CEM_WB_rd;

endmodule
