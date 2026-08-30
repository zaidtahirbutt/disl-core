// `timescale 1ps/1ps

module bram_axi_cachecontroller_v2(
clk,rst,
a_axi_araddr,a_axi_arvalid,a_axi_arready,
a_axi_awaddr,a_axi_awvalid,a_axi_awready,
a_axi_rdata,a_axi_rvalid,a_axi_rready,
a_axi_wdata,a_axi_wstrb,a_axi_wvalid,a_axi_wready,
a_b_ready,a_b_valid,a_b_response
);

// comments from DISLv2 build.py file inserted by Zaid
// # so riscv linker and reset handler are populated by MAP fileds of the riscv address map in the system.tml file. The cache depth is not translated to the linker or reset handler.
// # the user has to manually specify cache depth separately and has to make sure that the cache depth/memory length of the riscv address map can fit into the cache (bram, etc) being
// # instantiated separately.

parameter ADDR_WIDTH = 16; // Tested and Verificed in Synthesis with risc-v 2^16 = 65,536 bytes memory after synthesis
parameter DATA_WIDTH = 32;
parameter SIMULATION = 0;
// Memory initialization image (Verilog $readmemh format, one word per line).
// Supplied by system.tml's [INSTANTIATIONS.<inst>.MEM_INIT.MEM_INIT_FILE] block,
// which build.py resolves to an absolute path and stages into <build_dir>/mem/.
// Empty means "do not initialize" -- the historical behaviour for any example
// that does not declare a MEM_INIT block.
parameter MEM_INIT_FILE = "";
// Set to 1 to also load MEM_INIT_FILE at time 0 with no delay, which is what
// lets Vivado infer a pre-initialized BRAM so the firmware ships inside the
// bitstream instead of needing a UART upload after every flash. Kept separate
// from the SIMULATION path below because that one deliberately delays past the
// zeroing loop, and a delay makes the block non-synthesizable.
parameter PRELOAD_MEM = 0;
parameter MEM_SIZE_BITS = 524288;  
	// 524288 bits (64 kB) => 524288 bits >> 5 (log_base_2 DATA_WIDTH) = 16384 32bit-words (DATA_WIDTHbit-words) (64kB = 65536 bytes) = DEPTH for 32 bit word BRAM when addres width = 16bits => 2^16 = 65,536

input clk;
input rst;
input 		[ADDR_WIDTH-1:0] 	a_axi_araddr;
input 			 		a_axi_arvalid;
output	reg 				a_axi_arready;
input 		[ADDR_WIDTH-1:0] 	a_axi_awaddr;
input 			 		a_axi_awvalid;
output	reg				a_axi_awready;

// unhacked :3
output	reg 	[DATA_WIDTH-1:0] 	a_axi_rdata;
// hack 3
// output	 	[DATA_WIDTH-1:0] 	a_axi_rdata;

// unhacked :3
output	reg	 			a_axi_rvalid;
// for hack 2
// output		 			a_axi_rvalid;

input 			 		a_axi_rready;
input 		[DATA_WIDTH-1:0] 	a_axi_wdata;
input 		[(DATA_WIDTH>>3)-1:0] 	a_axi_wstrb;
input 			 		a_axi_wvalid;
output	reg				a_axi_wready;
input 					a_b_ready;
output	reg				a_b_valid;
output	[1:0] 			a_b_response;



reg [ADDR_WIDTH-1:0] axi_araddr_buff;
reg axi_arready_internal;
reg axi_rvalid_internal;
reg [ADDR_WIDTH-1:0] axi_awaddr_buff;
reg [DATA_WIDTH-1:0] axi_wdata_buff;
reg [(DATA_WIDTH>>3)-1:0] axi_wstrb_buff;

assign a_b_response = 0; // is a wire cx we using an assign statement to drive it I think
//////////////////////////////////////////////////////////  MEMORY /////////////////////////////////////

// default MEM_SIZE_BITS = 524288 bits => 524288 bits >> 5 = 16384 32bit-words (64kB = 65536 bytes) = DEPTH for 32 bit word BRAM when addres width = 16bits => 2^16 = 65,536 
localparam MEM_DEPTH =  MEM_SIZE_BITS >> $clog2(DATA_WIDTH);  // $clog2(32) = 5 

// prev MEM_DEPTH assignment as per ADDR_WIDTH
// localparam MEM_DEPTH = (2**ADDR_WIDTH)/4; //  2^16 = 65,536 bytes memory  ... which means BRAM width is 4 bytes ... so BRAM depth is 65,536/4 = 16,384 



reg [DATA_WIDTH-1:0] mem [0: MEM_DEPTH-1];  //  2^16 = 65,536 bytes memory  ... which means BRAM width is 4 bytes ... so BRAM depth is 65,536/4 = 16,384  




// reg [DATA_WIDTH-1:0] mem [0: (2**ADDR_WIDTH)-1];
	// changing this for the version2 of BRAMcache

// Total bytes are 4 x 2^28 = 1,073,741,824 bytes = 1,048,576 KB = 1,024 MB = 1 GB
	// only possible to have this much BRAM in simulation
	
// REMEMBER TO RUN PYTHON SCRIPT AND GET THE HEX FILE IN BRAM FORMAT!

//initial $readmemh("firmware_for_sim.hex", mem);
//initial $readmemh("firmware_for_sim2_LED.hex", mem);
//initial $readmemh("Eth_icmp_tx_ping_sim.hex", mem);
//initial $readmemh("Eth_icmp_tx_ping_sim2.hex", mem);
//initial $readmemh("Eth_icmp_tx_ping_sim6.hex", mem);
//initial $readmemh("Eth_icmp_tx_ping_sims7.hex", mem);
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/fpga_core/firmware_sim.hex", mem);
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/fpga_core/2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex", mem);
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex", mem); // edgetestbed_a100T5_sim & edgetestbed_a100T6_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2022_11_4_netowrkSub_memWrite_sim.hex", mem);		// edgetestbed_a100T5_sim & edgetestbed_a100T6_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2022_11_16_netowrkSub_rx_pkt_memWrite_2_sim.hex", mem);		// edgetestbed_a100T5_sim & edgetestbed_a100T6_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2022_11_16_netowrkSub_rx_pkt_memWrite_3_sim.hex", mem);		// edgetestbed_a100T5_sim & edgetestbed_a100T6_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2022_11_17_netowrkSub_rx_pkt_memWrite_read_4_sim.hex", mem);		// edgetestbed_a100T5_sim & edgetestbed_a100T6_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2022_11_17_netowrkSub_rx_pkt_memWrite_read_5_sim.hex", mem);		// edgetestbed_a100T5_sim & edgetestbed_a100T6_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2022_11_17_netowrkSub_rx_pkt_memWrite_read_6_sim.hex", mem);		//  edgetestbed_a100T6_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2022_11_17_netowrkSub_rx_pkt_memWrite_read_6b_sim.hex", mem);		//   edgetestbed_a100T6_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2022_11_17_netowrkSub_rx_pkt_memWrite_read_6c_sim.hex", mem);		//  edgetestbed_a100T6_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2022_11_28_edgetestbed_a100T8_multiRxPkt_reads_fromMem_sim.hex", mem);		//  edgetestbed_a100T8_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_3_27_edgetestbed_a100T_retry_March2023_LED_turnOn_runningOna100T11_sim.hex", mem);		//  edgetestbed_a100T8_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_4_3_edgetestbed_a100T12_synthesis_multiRxPkt_reads_fromMem_sim.hex", mem);		//  edgetestbed_a100T8_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_4_7_edgetestbed_a100T13_sim_multiRxPkt_AND_VeBPF_result_reads_fromMem_sim.hex", mem);		//  
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_4_16_edgetestbed_a100T14_sim_multiRxPkt_AND_VeBPF_result_reads_fromMem_v4_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_4_24_edgetestbed_a100T14_sim_multiRxPkt_AND_VeBPF_result_reads_fromMem_v5_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_4_26_edgetestbed_a100T15_sim_Basil_Project_demo_VeBPF_running_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_4_26_edgetestbed_a100T15_sim_Basil_Project_demo_VeBPF_running_not_sim.hex", mem);		//  edgetestbed_a100T14_sim
	// worked with this # DISL_TEST=edgetestbed_a100T15_sim_FROM_CODES1server_ExperimentalStuff
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_10_19_edgetestbed_a100T20_sim_test1_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_11_3_edgetestbed_a100T21_sim_v1_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_11_10_edgetestbed_a100T21_sim_v2_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_11_15_edgetestbed_a100T21_stressTest2_sim_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_11_16_edgetestbed_a100T21_stressTest1_sim_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_11_10_edgetestbed_a100T21_sim_v2_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_11_22_edgetestbed_a100T22_stressTest3_v2_sim_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2023_11_27_edgetestbed_a100T22_stressTest3_v3_sim_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_1_2_edgetestbed_a100T22_stressTest3_v6_sim_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_1_3_edgetestbed_a100T25_VeBPF_Exp_debugging_sim_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_1_3_edgetestbed_a100T25_VeBPF_Exp_debuggingv2_withExpanded_csr_dest_bits_sim_sim.hex", mem);		//  edgetestbed_a100T14_sim
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_1_6_edgetestbed_a100T25_VeBPF_throughput_cal_sim_sim.hex", mem);
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_1_7_edgetestbed_a100T25_RISCV_throughput_cal_sim_sim.hex", mem);
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_1_7_edgetestbed_a100T25_RISCV_latency_cal_sim_sim.hex", mem);
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_1_24_edgetestbed_a100T26_RISCV_throughput_cal_firewallTYPE1_v5_v2_onlyHdr_TYPE4_Exp_throughput_cal_sim_sim.hex", mem);
// initial $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_2_12_edgetestbed_a100T27_tx_pipeline_v1_sim_sim.hex", mem);

// Use the initial block below with delay inlucded when reading RISC-V hex file. Reason for using delay mentioned in detailed comment below. 
// Also when uploading RISC-V code manually, comment out all delay and readmemhs.

initial begin
	if (SIMULATION) begin
		// introducing delays since we are zeroing the bram first in SIMULATION
		#5
		// $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_2_12_edgetestbed_a100T27_tx_pipeline_v1_sim_sim.hex", mem);
		// $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_2_12_edgetestbed_a100T27_tx_pipeline_v3_sim_sim.hex", mem);
		// $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_2_12_edgetestbed_a100T27_tx_pipeline_v4_sim_sim.hex", mem);
		// $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_2_12_edgetestbed_a100T27_tx_pipeline_v5_sim_sim.hex", mem);
		// $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_2_12_edgetestbed_a100T27_tx_pipeline_v6_sim_sim.hex", mem);
		// $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_4_12_edgetestbed_a100T27_tx_pipeline_v9_sim_also_SYN_sim.hex", mem);
		// $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_4_24_edgetestbed_a100T27_tx_pipeline_v10_sim_also_SYN_reducedLinker_sim.hex", mem);
		// $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_4_24_edgetestbed_a100T27_tx_pipeline_v10v2_1SIM_0DEBUG_sim_also_SYN_reducedLinker_sim.hex", mem);
		
		// 12 Sept 2024 checking if Automated VeBPF pgm_loaderV2 works.
		// $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_9_12_edgetestbed_a100T30_VeBPF_pgmLoaderV2_firewallTYPE1combinedSim_reducedLinker_1SIM_0DEBUG_SIM_sim.hex", mem);
		// $readmemh("/home/zaidtahir/projects/2025_3_RISCV_C_FW_VebpfManyCore/RISCV_C_FW_VebpfManyCore/fw/vebpf_network_packet_processing/2024_9_12_edgetestbed_a100T30_VeBPF_pgmLoaderV2_firewallTYPE1combinedSim_reducedLinker_1SIM_0DEBUG_SIM.hex", mem);
		// Was a hardcoded "../../../RISCV_C_FW_VebpfManyCore/fw/.../..._SIM.hex".
		// That path encoded the directory depth of one particular repository
		// layout, so once this tree was reused elsewhere it silently resolved
		// into a different checkout that happened to hold identical files.
		// The path now arrives as a parameter from system.tml's MEM_INIT block.
		if (MEM_INIT_FILE != "")
			$readmemh(MEM_INIT_FILE, mem);
	end
end

// Synthesis-time BRAM preload. Deliberately a separate block from the one
// above: no delay and no SIMULATION guard, which is what Vivado requires to
// infer an initialized block RAM. With SIMULATION=1 the block above already
// loads the same image after the zeroing loop, so leave PRELOAD_MEM at 0 for
// simulation builds and set it to 1 for synthesis builds that should carry
// the firmware inside the bitstream.
initial begin
	if (PRELOAD_MEM && MEM_INIT_FILE != "")
		$readmemh(MEM_INIT_FILE, mem);
end

integer i;

initial begin

	$display("bram_axi_cachecontroller_v2 DATA_WIDTH = %d and MEM_DEPTH = %d \n", DATA_WIDTH, MEM_DEPTH);

     #6

     // introducing delays since we are zeroing the bram first

     $display("rdata:");

     for (i=0; i < 93; i=i+1)

        $display("%d:%h \n",i,mem[i]);

    //  $display("No pgm ints uploaded in BRAM directly. Prog Loader riscv pgm instruction Manual loading is activated");     
    
	$display("RISC-V pgm uploaded in BRAM directly with delays that were required. Prog Loader riscv pgm instruction Manual loading is de-activated");     

end

// tx_pkt TX "x" Error and its solution mentioned below
	/*

	• VIP discovery while working on tx pipeline.. 
		○ I was getting Cocotb Mii Sink errors that it is receiving "x" whereas it can only receive 0 or 1..
		○ SOLUTION to prob above:
			§ I initialized the cache BRAM to 0 
			§ I had to introduce delays in the BRAM cache module (bram_axi_cachecontroller.v) since I was making the cache BRAM to 0 hence after that I load the riscv intr memory in it... 
				and then after that we read it.. 
			§ So what I think was happening was that when I was tx-ing tx_pkts in my riscv c code and sending the memory addresses and tx_pkt lengths to desc_table_tx in network subsystem.. 
				and since the cache BRAM memory was not initialized to 0.. hence when I was reading full words and when the last word was not fully written in memory (either 3 or 2 or 1 out 
				of the 4 bytes of a word were written with tx_pkt data), then the remaining bytes were uninitialized and had the value of "x" and when the network subsystem read that memory 
				address, it read those uninitialized words which were sent out as "x" bytes and hence Cocotb Mii.Sink tx was giving an error of "x" .. but it should not have since that "x" byte 
				shouldn't have been sent since I am sending tx_pkt data out byte by byte and only the "populated" bytes should have been tx-ed out... some error there probably..
				□ Some other solutions that couldve been used..
					i) OR the 4 byte word in network subsystem with 4 bytes of 0's so that any "x" in the  4 byte word becomes "0"
					ii) in the riscv c code I could have populated the last remaning bytes of the last word that were uninitialized in case of when the tx_pkt length is not a multiple of 4, 
						I could have written 0 to that while writing the tx_pkt to that memory bin..

	*/


integer i2;
initial begin

	// cant make this 0 since we are reading this bram at 0 time as well.. hence we introduced delays
	if (SIMULATION) begin
		for (i2 = 0 ; i2 < (2**ADDR_WIDTH); i2=i2+1) begin
			mem[i2] = 0;		
		end
	end 

	// $readmemh("/home/zaidtahir/projects/Git_synched_repos/DISL/subsystems/network_subsystem/tb/top/2024_2_12_edgetestbed_a100T27_tx_pipeline_v1_sim_sim.hex", mem);

end

/////////////////////////////////////////////////////////   READ ///////////////////////////////////////

// hack 2
// assign a_axi_rvalid = a_axi_arvalid;

// hack 3
// assign a_axi_rdata = mem[a_axi_araddr];

always @(posedge clk) begin

	// unhacked :3
	a_axi_rdata <= mem[axi_araddr_buff];		//axi_araddr_buff <= 0; for reset so we still do have data on this line as mem[0]
		// TODO: Test if this change is causing any issues in the simulation 

	// a_axi_rdata = mem[axi_araddr_buff];		//axi_araddr_buff <= 0; for reset so we still do have data on this line as mem[0]
	// hack .. change later asap
	// a_axi_rdata = mem[a_axi_araddr];		//axi_araddr_buff <= 0; for reset so we still do have data on this line as mem[0]
	
	if (rst) begin
		a_axi_arready <= 0;

		// hack 2
		// unhacked :3
		a_axi_rvalid <= 0;
	end else begin
		a_axi_arready <= axi_arready_internal;		// a_axi_arready given current value of axi_arready_internal
		// These are on +ve clk edges and the internals are on -ve clk edges

		// unhacked :3
		a_axi_rvalid <= axi_rvalid_internal;			// while axi_arready_internal value changes for on the same clk edge
		// hack .. change later .. making sure rvalid is 1 after 1 clk cycle of arvalid
		//a_axi_rvalid <= a_axi_arvalid;			

	end
end

// mealy statemachine here mealy vs moore fsm http://electrosofts.com/verilog/fsm.html

always @(negedge clk) begin
	if (rst)
		axi_rvalid_internal <= 1'b0;
	else if (axi_rvalid_internal && a_axi_rready)	// rready =1 from master axi after this AXI Slave had given the master axi rvalid = 1
		axi_rvalid_internal <= 1'b0;		//axi_rvalid_internal
	else if (axi_arready_internal == 0)  // address already stored when it was pulled down to 0
		axi_rvalid_internal <= 1'b1;
end

// two main read signals asserted here for read from Master AXI to Slave AXI here:
//a_axi_arready 
//a_axi_rvalid
// using internal versions for one clk delay
//axi_arready_internal
//axi_rvalid_internal

// but why the 1 clk delay?
// mealy statemachine here mealy vs moore fsm http://electrosofts.com/verilog/fsm.html

always @(negedge clk) begin
	if (rst) begin
		axi_arready_internal <= 1;		// axi_arready_internal is 1 on reset!
		axi_araddr_buff <= 0;

		// when we have valid address from Master then read it and pull down the arready internal to 0.
		// the arready goes to 0 on next clk cycle after this
	end else if (a_axi_arvalid && axi_arready_internal) begin		// when is axi_arready_internal 0? Ans below
		axi_arready_internal <= 0;						// when we have a_axi_arvalid 1 and axi_arready_internal 1
		axi_araddr_buff <= a_axi_araddr;					// we read the address
														// we make axi_arready_internal 0

		// now Master AXI is ready to read data and we have valid read data shown by axi_rvalid_internal
		// so we drive axi_arready_interal back to 1 as we are ready to read a new araddr for new rdata

	end else if (axi_rvalid_internal && a_axi_rready) begin // data has been read at this point and now we are ready to read new araddr
		// axi_rvalid_internal is 1 and a_axi_rready is 1
		axi_arready_internal <= 1'b1;		// we can take in next address
	end
end

/////////////////////////////////////////////////////////////////////// WRITE //////////////////////////////////////////////////


reg [DATA_WIDTH-1:0] write_data;
reg [DATA_WIDTH-1:0] write_data_masked;
reg [2:0] w_state;
	
integer j;
always @(*) begin
	for (j=0; j < (DATA_WIDTH>>3); j=j+1) begin // if datawidth = 32, datawidth >> 3 = 100000 >> 3 = 100 = 4
		write_data_masked[(j<<3)+:8] = axi_wstrb_buff[j] ? axi_wdata_buff[(j<<3)+:8] : write_data[(j<<3)+:8];
		//	for j = 0 : write_data_masked[(0<<3)+:8] = axi_wstrb_buff[0] ? axi_wdata_buff[(0<<3)+:8] : write_data[(0<<3)+:8];
			// 0 << 3 = 0 -> write_data_masked[7:0] = axi_wstrb_buff[0] ? axi_wdata_buff[7:0] : write_data[7:0];
		//	for j = 1 : write_data_masked[(1<<3)+:8] = axi_wstrb_buff[1] ? axi_wdata_buff[(1<<3)+:8] : write_data[(1<<3)+:8];
			// 1 << 3 = 8 -> write_data_masked[15:8] = axi_wstrb_buff[1] ? axi_wdata_buff[15:8] : write_data[15:8];
		//	for j = 2 : write_data_masked[(2<<3)+:8] = axi_wstrb_buff[2] ? axi_wdata_buff[(2<<3)+:8] : write_data[(2<<3)+:8];
			// 2 << 3 = 16 -> write_data_masked[23:16] = axi_wstrb_buff[2] ? axi_wdata_buff[23:16] : write_data[23:16];
		//	for j = 3 : write_data_masked[(3<<3)+:8] = axi_wstrb_buff[3] ? axi_wdata_buff[(3<<3)+:8] : write_data[(3<<3)+:8];
			// 3 << 3 = 24 -> write_data_masked[31:24] = axi_wstrb_buff[3] ? axi_wdata_buff[31:24] : write_data[31:24];
				// 11 << 3 = 11000 = 24
		// so the strobe is deciding whether we are writing new data to the bram thru axi_wdata_buff using the current
		// a_axi_wdata from Master bus or are we not writing anything to that byte and just write_data <= mem[axi_awaddr_buff];
		// repeating whatever value was there in write_data <= mem[axi_awaddr_buff]; and then writing it there using
		// mem[axi_awaddr_buff] <= write_data_masked;

	end
end

// moore statemachine here mealy vs moore fsm http://electrosofts.com/verilog/fsm.html

always @(posedge clk) begin
	if (rst) 
		a_b_valid <= 0;
	else if (w_state == 3'd4)
		a_b_valid <= 1'b1;		// writing by Master AXI is done!
	else 
		a_b_valid <= 1'b0;
end
	

reg axi_wready_internal;
reg axi_awready_internal;

always @(posedge clk) begin
	a_axi_wready <= axi_wready_internal;		//// This on +ve edge and the others on -ve edge
	a_axi_awready <= axi_awready_internal;
end

// mealy statemachine here mealy vs moore fsm http://electrosofts.com/verilog/fsm.html


always @(negedge clk) begin
	if (rst) begin 
		axi_awaddr_buff <= 0;
		axi_awready_internal	<= 0;
		axi_wdata_buff <= 0;
		axi_wready_internal	<= 0;
		w_state <= 0;	
	end else if (w_state == 0) begin
		axi_wready_internal	<= 1;		// updated same clk cycle
		axi_awready_internal	<= 1;
		if (a_axi_awvalid) begin
			axi_awaddr_buff <= a_axi_awaddr;
			axi_awready_internal	<= 0;		// axi_awready_internal back to 0 after we get address
			w_state <= 3'd1;
			if (a_axi_wvalid) begin
				axi_wdata_buff <=  a_axi_wdata;
				axi_wstrb_buff <= a_axi_wstrb;
				axi_wready_internal	<= 0;		// axi_wready_internal back to 0 after we get wdata
				w_state <= 3'd2;
			end
		end	// no default else?
	end else if (w_state == 3'd1) begin
		if (a_axi_wvalid) begin
			axi_wdata_buff <=  a_axi_wdata;
			axi_wstrb_buff <= a_axi_wstrb;
			axi_wready_internal	<= 0;
			w_state <= 3'd2;
		end		
	end else if (w_state == 3'd2) begin
		write_data <= mem[axi_awaddr_buff];		// if wstrb is 0 for this byte then write the 
		w_state <= 3'd3;						// same mem back at this address again
	end else if (w_state == 3'd3) begin
		mem[axi_awaddr_buff] <= write_data_masked; //write data either new or the old one depending
								// on the wstrb value in the memory here
		w_state <= 3'd4;
	end else if (w_state == 3'd4) begin
		if (a_b_ready) 					// assert a_b_valid to the master AXI // it might give b_resp but we dont need to read it
			w_state <= 3'd0;  // as soon as we get a_b_ready from Master AXI start the state machine and 
					  		// the writing process again
	end
end
endmodule

