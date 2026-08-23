// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
// `default_nettype none

/*
 * AXIS to AXI4- eth_fifo_axis_to_bram_axi
 */
module eth_fifo_axis_to_bram_axi #
(
    //     // Propagate tkeep signal
    //     // FIFO depth in words
    //     // KEEP_WIDTH words per cycle if KEEP_ENABLE set    
           // Rounded up to nearest power of 2 cycles
    //     parameter DEPTH = 4096,
        
    // RX-TX-packet BRAM DEPTH
    parameter RX_TX_PKT_BRAM_DEPTH = 512,
    
    // Width of AXI stream interfaces in bits
    parameter DATA_WIDTH = 8,
    
    //rv processor data width    
    parameter RV_DATA_WIDTH = 32,  // data width of rv

    parameter MEM_WORD_WIDTH = 32,
    parameter BYTE_WIDTH = 8,

    // Swap the 4 byte word MSBs and LSBs (for RV word reading)
    parameter ENDIAN_SWAP = 1,

    //     // Propagate tkeep signal
    //     // If disabled, tkeep assumed to be 1'b1
    //     parameter KEEP_ENABLE = (DATA_WIDTH>8),
        // tkeep signal width (words per cycle)
    parameter KEEP_WIDTH = ((DATA_WIDTH+7)/8),
    //     // Propagate tlast signal
    //     parameter LAST_ENABLE = 1,
    //     // Propagate tid signal
    //     parameter ID_ENABLE = 0,
        // tid signal width
    parameter ID_WIDTH = 8,
    //     // Propagate tdest signal
    //     parameter DEST_ENABLE = 0,
    // tdest signal width
    parameter DEST_WIDTH = 8,
    //     // Propagate tuser signal
    //     parameter USER_ENABLE = 1,
    // tuser signal width
    parameter USER_WIDTH = 1,
    //     // number of output pipeline registers
    //     parameter PIPELINE_OUTPUT = 2,
    //     // Frame FIFO mode - operate on frames instead of cycles
    //     // When set, m_axis_tvalid will not be deasserted within a frame
    //     // Requires LAST_ENABLE set
    //     parameter FRAME_FIFO = 0,
    //     // tuser value for bad frame marker
    //     parameter USER_BAD_FRAME_VALUE = 1'b1,
    //     // tuser mask for bad frame marker
    //     parameter USER_BAD_FRAME_MASK = 1'b1,
    //     // Drop frames larger than FIFO
    //     // Requires FRAME_FIFO set
    //     parameter DROP_OVERSIZE_FRAME = FRAME_FIFO,
    //     // Drop frames marked bad
    //     // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    //     parameter DROP_BAD_FRAME = 0,
    //     // Drop incoming frames when full
    //     // When set, s_axis_tready is always asserted
    //     // Requires FRAME_FIFO and DROP_OVERSIZE_FRAME set
    //     parameter DROP_WHEN_FULL = 0

    parameter VEBPF_PROG_ADDRESS_WIDTH = 12,  // 10 bit wide means 1024 in depth // for VeBPF depth parameter MEMORY_DEPTH = 2**ADDRESS_SIZE;  // 2**12 = 4096
    parameter VEBPF_PROG_ADDRESS_WIDTH_REDUCED = 9,  // keep this less than 12 atm .. need to test in simulation what breaks at 12 
    parameter VEBPF_PROG_DATA_WIDTH = 64,
    parameter VEBPF_PROG_DATA_BYTES = 8,
    
    // parameter NUMBER_OF_VEBPF = 2, // testing with 2 VeBPFs now //1,
    
    // parameter NUMBER_OF_VEBPF = 6,
    
    parameter NUMBER_OF_VEBPF = 1,
    
    // parameter NUMBER_OF_VEBPF = 12,
        // This is the max num of VeBPFs fort arty100T design
    
    //parameter NUMBER_OF_VEBPF = 14,
        // # ERROR: [DRC UTLZ-1] Resource utilization: LUT as Logic over-utilized in Top Level Design (This design requires more LUT as 
        // # Logic cells than are available in the target device. This design requires 76726 of such cell types but only 63400 compatible
        // # ERROR: [DRC UTLZ-1] Resource utilization: LUT as Logic over-utilized in Top Level Design (This design requires more LUT as 
        // # Logic cells than are available in the target device. This design requires 76726 of such cell types but only 63400 compatible  
    
    //parameter NUMBER_OF_VEBPF = 16,
        // checking max resource usage -> Error!
        // # ERROR: [DRC UTLZ-1] Resource utilization: LUT as Logic over-utilized in Top Level Design (This design requires more LUT as 
        // # Logic cells than are available in the target device. This design requires 76726 of such cell types but only 63400 compatible 
        // # ERROR: [DRC UTLZ-1] Resource utilization: Slice LUTs over-utilized in Top Level Design (This design requires more Slice LUTs cells than are 
        // # available in the target device. This design requires 81010 of such cell types but only 63400 compatible sites are available in the target device.
        
    // parameter NUMBER_OF_VEBPF = 8,
        // got a bug when num of VeBPFs > total rules as follows:
            // // resetting run rule reqs to 0
                // VeBPF_rules_selector_run_rule_req_array_next = 0; 
                    // bug resolved in a100T24 project when num of VeBPF > num of total rules// resetting run rule reqs to 0
                // VeBPF_rules_selector_run_rule_req_array_next = 0; 
                    // bug resolved in a100T24 project when num of VeBPF > num of total rules
    // now will check then num of VeBPFs == num of rules
    // parameter NUMBER_OF_VEBPF = 5, 
        // works fine
    parameter MAX_NUMBER_OF_VEBPF = 16,
    parameter BITS_NEDED_FOR_NUMBER_OF_VEBPF = $clog2(MAX_NUMBER_OF_VEBPF), // = 4 //4,  // lets say our max number of VeBPFs are 16 (from idx 0-15)
    
    // keep VEBPF_MAX_NUM_OF_RULES/VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX in powers of 2 
    // so that we don't need to use multiply operations for rd wr ptrs and we can just to bitshifts
    // converting this to a parameter
    parameter VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX = 64,  // default
        // means 64 VEBPF rules can be uploaded..
    
    parameter TOTAL_DESTINATIONS_FOR_VEBPF_RESULTS = 6,  // the VeBPF results can be either 1 till TOTAL_DESTINATIONS_FOR_VEBPF_RESULTS
    parameter SIMULATION = 0,
    parameter TX_PKT_DATAPATH_GEN = 1,
    parameter RX_PKT_DATAPATH_GEN = 1
)
(
    input  wire                             clk,
    input  wire                             rst,

    /*
     * AXI STREAM input from ethernet fifo being stored to ther BRAM here for the RV processor to read from
     */
    input  wire [DATA_WIDTH-1:0]            s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]            s_axis_tkeep,
    input  wire                             s_axis_tvalid,
    output wire                             s_axis_tready,
    input  wire                             s_axis_tlast,
    input  wire [ID_WIDTH-1:0]              s_axis_tid,
    input  wire [DEST_WIDTH-1:0]            s_axis_tdest,
    input  wire [USER_WIDTH-1:0]            s_axis_tuser,  // 1 bit

    /*
     * AXI STREAM OUTPUT  for sending our tx_pkts
     */
    output  wire [DATA_WIDTH-1:0]            m_axis_tdata,
    output  wire [KEEP_WIDTH-1:0]            m_axis_tkeep,
    output  wire                             m_axis_tvalid,
    input   wire                             m_axis_tready,
    output  wire                             m_axis_tlast,
    output  reg [ID_WIDTH-1:0]              m_axis_tid,
    output  reg [DEST_WIDTH-1:0]            m_axis_tdest,
    output  reg [USER_WIDTH-1:0]            m_axis_tuser,  // 1 bit

    /*
     *  AXI4 s ports (RV connections and others potentially)
        Initially rv will just read stuff from here and potentially write ctrl reg values
        for example resetting or clearing BRAM packet etc
     */
    input wire [31:0]                       axi_araddr,
    input           wire                    axi_arvalid,
    output          reg                     axi_arready,

    input wire  [31:0]                      axi_awaddr,
    input           wire                    axi_awvalid,
    output          reg                     axi_awready,

    output          reg [31:0]              axi_rdata,
    output          reg                     axi_rvalid,
    input           wire                    axi_rready,

    input wire  [31:0]                      axi_wdata,
    input wire  [3:0]                       axi_wstrb,  
    // this is a bit level command so 32 is converted to bits which is 100000 then >> 3 = 100 = 4 so axi_wstrb = 4-1:0 = 3:0
    input           wire                    axi_wvalid,
    output          reg                     axi_wready,

    input           wire                    b_ready,
    output          reg                     b_valid,
    output wire     [1:0]                   b_response,

    /*
     *  AXI4 M ports: These ports connect to DDR through a grant module through the SmartSwitch 
    */

    output  wire [31:0]             m_eth_bram_axi_araddr,
    output  wire                    m_eth_bram_axi_arvalid,
    input   wire                    m_eth_bram_axi_arready,

    output  wire [31:0]             m_eth_bram_axi_awaddr,
    output  wire                    m_eth_bram_axi_awvalid,
    input   wire                    m_eth_bram_axi_awready,

    input   wire [31:0]             m_eth_bram_axi_rdata,
    input   wire                    m_eth_bram_axi_rvalid,
    output  wire                    m_eth_bram_axi_rready,

    output  wire [31:0]             m_eth_bram_axi_wdata,
    output  wire [3:0]              m_eth_bram_axi_wstrb,  
    output  wire                    m_eth_bram_axi_wvalid,
    input   wire                    m_eth_bram_axi_wready,

    output  wire                    m_eth_bram_axi_b_ready,
    input   wire                    m_eth_bram_axi_b_valid,
    input   wire [1:0]              m_eth_bram_axi_b_response,

    // Memory write req
    // output wire                    eth_mem_write,
    output wire                     eth_mem_write_req,
    input  wire                     eth_mem_write_grant,

    // VeBPF related ports
    input  wire [VEBPF_PROG_ADDRESS_WIDTH-1:0]               VeBPF_prog_addr_in,
    input  wire [VEBPF_PROG_DATA_WIDTH-1:0]                  VeBPF_prog_data_in,
    input  wire                                              VeBPF_prog_write_enable_in,
    input  wire                                              VeBPF_prog_reset_in,               // separate reset for the prog mem of VeBPF
    input  wire                                              VeBPF_prog_busy_in,                // the progloader is busy writing to VeBPF prog mem
    input  wire                                              VeBPF_prog_done_in,                // VeBPF prog has been completed 
    input wire                                               VeBPF_next_rule_switch_flag_in,
    input wire                                               VeBPF_all_rules_done_switch_flag_in,
    output wire                                              VeBPF_rules_scheduler_error_flag,
    // interrupt ports
    output          wire                    o_rx_int, 
    output          wire                    o_tx_int, 
        // read about these in zipversa picorv core. These go to the interrupt request_arb_vebpf_selector_in irq input of the picorv
            // irq of the picorv is a 32 bit wire, we can put these two signals o_rx_int, o_tx_int at the end of that. I believe these will send interrupts to the
            // picorv and that might make the mem reads and write for the ethernet rx and tx faster. We could test this out in rvcore in edgetestbed aswell.

    //debug bus
    output          wire    [31:0]                      o_debug


);  // needed to have , instead of ; at the end of input output ports cx theyre being declared and instantiated at the same time


// ********************************************************************************************************************************************************************
// ***************************************** TX_PKT_DMA FSM -> START *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

// tx_pkt TX "x" Error and its solution mentioned below
    /*

    • VIP discovery while working on tx pipeline.. 
        ○ I was getting Cocotb Mii Sink errors that it is receiving "x" whereas it can only receive 0 or 1..
        ○ SOLUTION to prob above:
            § I initialized the cache BRAM to 0 
            § I had to introduce delays in the BRAM cache module (bram_axi_cachecontroller.v) since I was making the cache BRAM to 0 hence after that I load the riscv intr memory in it... 
                and then after that we read it.. 
            § So what I think was happening was that when I was tx-ing tx_pkts in my riscv c code and sending the memory addresses and tx_pkt lengths to desc_table_tx in network subsystem.. 
                and since the cache BRAM memory was not initialized to 0.. hence when I was reading full words and when the last word was not fully written in memory (either 3 or 2 or 1 out of the 4 bytes of a word were written with tx_pkt data), then the remaining bytes were uninitialized and had the value of "x" and when the network subsystem read that memory address, it read those uninitialized words which were sent out as "x" bytes and hence Cocotb Mii.Sink tx was giving an error of "x" .. but it should not have since that "x" byte shouldn't have been sent since I am sending tx_pkt data out byte by byte and only the "populated" bytes should have been tx-ed out... some error there probably..
                □ Some other solutions that couldve been used..
                    i) OR the 4 byte word in network subsystem with 4 bytes of 0's so that any "x" in the  4 byte word becomes "0"
                    ii) in the riscv c code I could have populated the last remaning bytes of the last word that were uninitialized in case of when the tx_pkt length is not a multiple of 4, 
                        I could have written 0 to that while writing the tx_pkt to that memory bin..

    */


localparam [3:0]
    TX_PKT_DMA_STATE_IDLE = 0,
    TX_PKT_DMA_START_READING = 1,
    TX_PKT_DMA_ADDR_AND_DATA_READ = 2,
    TX_PKT_DMA_ADDR_DATA_READ_RESP_WAIT = 3,
    TX_PKT_DMA_WAIT_MEM_BUS_GRANT = 4,
    TX_PKT_DMA_UPDATE_DESC_TABLE_AND_TX_BRAM = 5,
    TX_PKT_DMA_WAIT_FOR_ACK_FROM_TX_TRANSMIT_FSM = 6;
    // TX_PKT_DMA_READ_DONE = ;


localparam FIFO_DEPTH_ADDR_WDITH_TX_PKT = 2;  // can be different from RX_PKT  

localparam TX_PKT_DESC_TABLE_DEPTH = 2**FIFO_DEPTH_ADDR_WDITH_TX_PKT;

reg [3:0] tx_dma_state_reg = TX_PKT_DMA_STATE_IDLE, tx_dma_state_next;

// this statment below infers a BRAM
(* ramstyle = "no_rw_check" *)
reg [RV_DATA_WIDTH-1:0] tx_mem1[RX_TX_PKT_BRAM_DEPTH-1:0]; // 512 x 32 bits = 2048 bytes = 2KB which is the max packet size
reg [RV_DATA_WIDTH-1:0] tx_mem2[RX_TX_PKT_BRAM_DEPTH-1:0]; // 512 x 32 bits = 2048 bytes = 2KB which is the max packet size
    // pipelining two BRAMs to pipeline (parallize) the process/transfer of txpkt from TX_PKT_DMA to TX_PKT_DISTRIBUTOR


// make this HIGH for req Mem bus grant to read TX PKTS from DDR
reg eth_mem_read_tx_pkt_req_reg, eth_mem_read_tx_pkt_req_next;

//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [MEM_ADDR_WIDTH-1:0] desc_table_tx_pkt_start_mem_addr[TX_PKT_DESC_TABLE_DEPTH-1:0];
reg desc_table_tx_pkt_start_mem_addr_rd_ptr_en_reg = 0, desc_table_tx_pkt_start_mem_addr_rd_ptr_en_next;
reg desc_table_tx_pkt_start_mem_addr_wr_ptr_en_reg = 0, desc_table_tx_pkt_start_mem_addr_wr_ptr_en_next, desc_table_tx_pkt_start_mem_addr_wr_ptr_en = 0;

//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [15:0] desc_table_tx_pkt_len[TX_PKT_DESC_TABLE_DEPTH-1:0];

//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [15:0] desc_table_tx_pkt_len_words[TX_PKT_DESC_TABLE_DEPTH-1:0];
// same enables for both byte and word rx pkt length
reg desc_table_tx_pkt_len_rd_ptr_en_reg = 0, desc_table_tx_pkt_len_rd_ptr_en_next;
reg desc_table_tx_pkt_len_wr_ptr_en_reg = 0, desc_table_tx_pkt_len_wr_ptr_en_next, desc_table_tx_pkt_len_wr_ptr_en = 0;


//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg desc_table_tx_pkt_avail[TX_PKT_DESC_TABLE_DEPTH-1:0];
reg desc_table_tx_pkt_avail_en = 0;
reg desc_table_tx_pkt_avail_reg, desc_table_tx_pkt_avail_next;

// reg to pass on desc_table_tx_pkt_avail fifo value at the rd ptr (and other desc table values below) 
reg desc_table_tx_pkt_avail_rd_ptr_reg = 0;

// this desc table entry goes 1 when the TX_PKT_DMA transfers the tx_pkt corresponding to the rd_ptr of TX_PKT_DMA FSM to the BRAM for transmission
// when this entry goes 1, the avail entry is overwritten by 0 and the desc table rd_ptr is incremented
reg desc_table_tx_pkt_transfer_done[TX_PKT_DESC_TABLE_DEPTH-1:0];
reg desc_table_tx_pkt_transfer_done_en = 0;
reg desc_table_tx_pkt_transfer_done_reg, desc_table_tx_pkt_transfer_done_next;

// reg to pass on desc_table_tx_pkt_transfer_done_rd_ptr_reg fifo value at the rd ptr
reg desc_table_tx_pkt_transfer_done_rd_ptr_reg = 0, desc_table_tx_pkt_transfer_done_rd_ptr_next;

reg desc_table_wr_ptr_update_flag_reg;

// reading pointer for the fifos that hold information about the tx pkts being written to and read from the memory
// These are the fifo consumer pointers (16 bits)
reg [FIFO_DEPTH_ADDR_WDITH_TX_PKT:0] rd_fifo_ptr_tx_pkt_reg = 0, rd_fifo_ptr_tx_pkt_next;  
// Not subtracting 1 from FIFO_DEPTH_ADDR_WDITH will make rd ptr width 1 more than FIFO_DEPTH_ADDR_WDITH, the reason
// for that is to compare the MSBs between read and write pointers for comparing rollover of the fifo to check
// if the fifo is full or empty :3
    // FIFO_DEPTH_ADDR_WDITH-1:0 is used for indexing.. MSBit is used for rollover detection

// writing pointer for the fifos that hold information about the tx pkts being written to and read from the memory
// These are the fifo producer pointers (16 bits)
reg [FIFO_DEPTH_ADDR_WDITH_TX_PKT:0] wr_fifo_ptr_tx_pkt_reg = 0, wr_fifo_ptr_tx_pkt_next;
    // FIFO_DEPTH_ADDR_WDITH-1:0 is used for indexing.. MSBit is used for rollover detection

// Ctrl signal to increment the rd fifo ptr from this module
reg rd_fifo_ptr_increment_tx_pkt_reg = 0, rd_fifo_ptr_increment_tx_pkt_next;

// This reg only goes high if rd_fifo_ptr_tx_pkt_reg hasnt caught up to wr_fifo_ptr_tx_pkt_reg
// this way rv softcore will avoid comparing rd and wr ptrs and doing additional read of wr pointers
// Ctrl signal (not from a fifo but from comparison of rd and wr ptrs)
reg rd_fifo_ptr_tx_pkt_valid_reg = 0, rd_fifo_ptr_tx_pkt_valid_next;

// overflow flag
reg rd_fifo_ptr_tx_pkt_overflow_reg = 0, rd_fifo_ptr_tx_pkt_overflow_next;


// some error flags
reg desc_table_tx_pkt_error_reg = 0, desc_table_tx_pkt_error_next;

// ctrl word indicating that the current tx pkt pointed to by the desc_table_tx_pkt_mem_addr_reg & and fifo pointer rd_fifo_ptr_tx_pkt_reg[SIZE-1:0]
// 
reg desc_table_tx_pkt_read_done_clr_reg = 0, desc_table_tx_pkt_read_done_clr_next;

// desc table fifo is full 
// full when first MSB different but rest same  // to take account of the rollover affect of ring buffer (1 extra addr bit to keep track of that)
wire desc_table_tx_pkt_full; // = wr_fifo_ptr_tx_pkt_reg == (rd_fifo_ptr_tx_pkt_reg ^ {1'b1, {FIFO_DEPTH_ADDR_WDITH{1'b0}}});
assign desc_table_tx_pkt_full = wr_fifo_ptr_tx_pkt_reg == (rd_fifo_ptr_tx_pkt_reg ^ {1'b1, {FIFO_DEPTH_ADDR_WDITH{1'b0}}});
    // for full condition lets imageine wr_fifo_ptr_tx_pkt_reg = 1000..000 and rd_fifo_ptr_tx_pkt_reg = 000..000 ..
    // this means that wr ptr has rolled over and now is equal to rd ptr, hence the desc table fifo is full now, which
    // is depicted by this XOR equation
    // Similarly the wr ptr rolls from 111..111 to 000...000 and rd ptr is at 1000..000 .. this equation would again tell us that the fifo is full
    // if wr == rd ptr then fifo is empty
    // that is why we declare rd and wr ptrs with width fifodepth+1 and use fifodepth only when reading or writing to fifos and use fifodepth+1
    // width of rd and wr ptrs when raising full or empty flags :3

// desc table fifo is empty when pointers match exactly
wire desc_table_tx_pkt_empty; // = wr_fifo_ptr_tx_pkt_reg == rd_fifo_ptr_tx_pkt_reg;
assign desc_table_tx_pkt_empty = wr_fifo_ptr_tx_pkt_reg == rd_fifo_ptr_tx_pkt_reg;

// replacing rd_fifo_ptr with desc_table for desc table related registers

// the starting memory address of the current tx pkt being transferred to memory
reg [MEM_ADDR_WIDTH-1:0] desc_table_tx_pkt_start_mem_addr_reg = 0, desc_table_tx_pkt_start_mem_addr_next;
reg desc_table_tx_pkt_start_mem_addr_en = 0;

// register for starting mem addr of tx pkt according to current rd ptr
reg [MEM_ADDR_WIDTH-1:0] desc_table_tx_pkt_start_mem_addr_rd_ptr_reg = 0;


// length of the current tx pkt being written to the memory (in bytes)
reg [15:0] desc_table_tx_pkt_len_reg = 0, desc_table_tx_pkt_len_next;

// register for length (bytes) of the current tx pkt according to current rd ptr 
reg [15:0] desc_table_tx_pkt_len_rd_ptr_reg = 0;

// length of the current tx pkt being being written to the memory (in words)
reg [15:0] desc_table_tx_pkt_len_words_reg = 0, desc_table_tx_pkt_len_words_next;

// register for length (words) of the current tx pkt according to current rd ptr 
reg [15:0] desc_table_tx_pkt_len_words_rd_ptr_reg = 0;

reg [31:0] eth_word_coming_from_mem_for_tx_pkt_dma_reg, eth_word_coming_from_mem_for_tx_pkt_dma_next; // register for transferring tx pkt word to memory
// ptr register to read tx pkts from tx_mem and transfer them to memory
reg [9:0] tx_pkt_word_wr_ptr_reg = 0; //, tx_pkt_word_wr_ptr_next;// tx_TX_PKT_BRAM_DEPTH = 512 (words), = 2048 bytes 
reg [9:0] tx_pkt_word_wr_ptr_next = 0; 
reg tx_pkt_word_wr_ptr_en = 0;

// if this is 0 then tx_pkt_mem1 is selected otherwise tx_pkt_mem2 is selected to write on
reg tx_pkt_bram_select_reg, tx_pkt_bram_select_next;
reg tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_reg, tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_next;
reg tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_reg, tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_next;


// ctrl signal to incremenr the wr_ptr for the tx_pkt fifos
reg wr_fifo_ptr_tx_pkt_inc_reg = 0;

reg [31:0] tx_pkt_current_available_memory_reg;
reg tx_pkt_current_available_memory_flag_reg;

reg [31:0] eth_word_addr_going_to_mem_for_tx_pkt_dma_reg, eth_word_addr_going_to_mem_for_tx_pkt_dma_next;

// reading AXI-4 connected to DDR
reg [31:0] m_eth_bram_axi_araddr_reg, m_eth_bram_axi_araddr_next;
reg        m_eth_bram_axi_arvalid_reg, m_eth_bram_axi_arvalid_next; 
reg        m_eth_bram_axi_rready_reg, m_eth_bram_axi_rready_next;

assign m_eth_bram_axi_araddr = m_eth_bram_axi_araddr_reg;
assign m_eth_bram_axi_arvalid = m_eth_bram_axi_arvalid_reg;
assign m_eth_bram_axi_rready = m_eth_bram_axi_rready_reg;


// CSR_tx supporting regs
reg [15:0] tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_reg, tx_pkt_wr_ptr_desc_table_tx_pkt_len_reg;
reg tx_pkt_wr_ptr_desc_table_tx_pkt_len_en_reg;
reg tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_en_reg;
reg [31:0] tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_reg;
reg tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_en_reg;
// need to write desc_table_tx_pkt_avail bit after all tx_pkt meta_data has been written to desc_table_tx
reg [31:0] tx_pkt_wr_ptr_desc_table_tx_pkt_avail_reg;
reg tx_pkt_wr_ptr_desc_table_tx_pkt_avail_en_reg;

// I don't need to read and then write to "desc_table_tx_pkt_transfer_done" cx FIFO FULL will tell the riscv that 
// if the wr_ptr has reached the rd_ptr or not, hence by looking at FIFO FULL flag it will be made sure that rd_ptr desc_table_tx
// values aren't overwritten

integer i_tx, i_tx2;
// initial block for intializing BRAMs with 0 for simulation so that RISC-V doesn't show ambigous behavour as it was showing according to 
// my stackoverflow post below
initial begin 

    // found the bug in my code that why wasn't the if condition as follows working;
        // if((NET_RX_FIFO_EMPTY(net_csr1) == 0) && (NET_RX_PKT_AVAIL(net_csr1)) && (NET_RX_PKT_VeBPF_VALID(net_csr1) == 1))
    // https://stackoverflow.com/questions/77748512/multiple-conditions-using-define-macro-functions-in-if-condition-is-not-working?noredirect=1#comment137070901_77748512
    // the bug was as mentioned in my comment on the stackoverflow question of mine:
        /*
            @PeterCordes you were correct, there was some other problem in my simulation. Including or excluding the 
            "define macro functions" in the if-condition did not make a difference and worked both ways after I found the bug today. 
            The bug was that in my FPGA hw rtl, I was not initializing the registers to zero and RISCV was reading "don't cares 0xXX" 
            when reading those registers, causing the ambiguity in the if-condition. Thanks for the directions and it was reassuring 
            that you were confident in your answer. What should I do with my question here now? –
        */

    if (SIMULATION) begin

        for (i_tx = 0; i_tx < TX_PKT_DESC_TABLE_DEPTH; i_tx = i_tx+1) begin  // resetting desc table entries to 0 // hopefully this line of code doesnt give any errors while synthesizing
            desc_table_tx_pkt_len[i_tx] <= 0;
            desc_table_tx_pkt_len_words[i_tx] <= 0;
            desc_table_tx_pkt_start_mem_addr[i_tx] <= 0;
            desc_table_tx_pkt_avail[i_tx] <= 0;
            desc_table_tx_pkt_transfer_done[i_tx] <= 0;
        end

        for (i_tx2 = 0; i_tx2 < RX_TX_PKT_BRAM_DEPTH; i_tx2 = i_tx2+1) begin  
            tx_mem1[RX_TX_PKT_BRAM_DEPTH] <= 0;
            tx_mem2[RX_TX_PKT_BRAM_DEPTH] <= 0;
        end

    end

end

// Sequential part of the TX_PKT_DMA FSM
always @(posedge clk) begin
     
    if (rst) begin
        

        tx_dma_state_reg <= TX_PKT_DMA_STATE_IDLE;
        eth_mem_read_tx_pkt_req_reg <= 0;

        m_eth_bram_axi_araddr_reg <= 0;
        m_eth_bram_axi_arvalid_reg <= 0;
        m_eth_bram_axi_rready_reg <= 1;

        desc_table_tx_pkt_start_mem_addr_rd_ptr_en_reg <= 0; 
        desc_table_tx_pkt_start_mem_addr_wr_ptr_en_reg <= 0;
        desc_table_tx_pkt_len_rd_ptr_en_reg <= 0;
        desc_table_tx_pkt_len_wr_ptr_en_reg <= 0;
        desc_table_tx_pkt_avail_reg <= 0;
        rd_fifo_ptr_tx_pkt_reg <= 0;
        // wr_fifo_ptr_tx_pkt_reg <= 0;
            /*
                shifting it to relevant FSM                
                ERROR: [DRC MDRV-1] Multiple Driver Nets: Net eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_next[0] has multiple drivers: eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_reg_inst__1/O, and eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_next_reg[0]/Q.

            */
        rd_fifo_ptr_increment_tx_pkt_reg <= 0;
        rd_fifo_ptr_tx_pkt_valid_reg <= 0;
        rd_fifo_ptr_tx_pkt_overflow_reg <= 0;
        desc_table_tx_pkt_error_reg <= 0;
        desc_table_tx_pkt_read_done_clr_reg <= 0;
        desc_table_tx_pkt_len_reg <= 0;
        desc_table_tx_pkt_len_words_reg <= 0;
        tx_pkt_word_wr_ptr_reg <= 0;

        // only reg (no _next)
        desc_table_tx_pkt_avail_rd_ptr_reg <= 0;
        desc_table_tx_pkt_start_mem_addr_rd_ptr_reg <= 0;
        desc_table_tx_pkt_len_rd_ptr_reg <= 0;
        desc_table_tx_pkt_len_words_rd_ptr_reg <= 0;
        
        eth_word_coming_from_mem_for_tx_pkt_dma_reg <= 0;
        eth_word_addr_going_to_mem_for_tx_pkt_dma_reg <= 0;
        tx_pkt_bram_select_reg <= 0;
        tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_reg <= 0;
        tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_reg <= 0;

    end else begin 

        tx_dma_state_reg <= tx_dma_state_next;
        eth_mem_read_tx_pkt_req_reg <= eth_mem_read_tx_pkt_req_next;

        m_eth_bram_axi_araddr_reg <= m_eth_bram_axi_araddr_next;
        m_eth_bram_axi_arvalid_reg <= m_eth_bram_axi_arvalid_next;
        m_eth_bram_axi_rready_reg <= m_eth_bram_axi_rready_next;

        desc_table_tx_pkt_start_mem_addr_rd_ptr_en_reg <= desc_table_tx_pkt_start_mem_addr_rd_ptr_en_next; 
        desc_table_tx_pkt_start_mem_addr_wr_ptr_en_reg <= desc_table_tx_pkt_start_mem_addr_wr_ptr_en_next;
        desc_table_tx_pkt_len_rd_ptr_en_reg <= desc_table_tx_pkt_len_rd_ptr_en_next;
        desc_table_tx_pkt_len_wr_ptr_en_reg <= desc_table_tx_pkt_len_wr_ptr_en_next;
        desc_table_tx_pkt_avail_reg <= desc_table_tx_pkt_avail_next;
        rd_fifo_ptr_tx_pkt_reg <= rd_fifo_ptr_tx_pkt_next;
        // wr_fifo_ptr_tx_pkt_reg <= wr_fifo_ptr_tx_pkt_next;
            /*
                shifting it to relevant FSM                
                ERROR: [DRC MDRV-1] Multiple Driver Nets: Net eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_next[0] has multiple drivers: eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_reg_inst__1/O, and eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_next_reg[0]/Q.

            */
        rd_fifo_ptr_increment_tx_pkt_reg <= rd_fifo_ptr_increment_tx_pkt_next;
        rd_fifo_ptr_tx_pkt_valid_reg <= rd_fifo_ptr_tx_pkt_valid_next;
        rd_fifo_ptr_tx_pkt_overflow_reg <= rd_fifo_ptr_tx_pkt_overflow_next;
        desc_table_tx_pkt_error_reg <= desc_table_tx_pkt_error_next;
        desc_table_tx_pkt_read_done_clr_reg <= desc_table_tx_pkt_read_done_clr_next;
        desc_table_tx_pkt_len_reg <= desc_table_tx_pkt_len_next;
        desc_table_tx_pkt_len_words_reg <= desc_table_tx_pkt_len_words_next;
        tx_pkt_word_wr_ptr_reg <= tx_pkt_word_wr_ptr_next;


        // will have to be allocated later

        // reading the desc_table_tx_pkt_avail using rd_ptr rd_fifo_ptr_tx_pkt_reg
        if (desc_table_tx_pkt_avail_en) begin 

            desc_table_tx_pkt_avail_rd_ptr_reg <= desc_table_tx_pkt_avail[rd_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]];
            desc_table_tx_pkt_len_rd_ptr_reg <= desc_table_tx_pkt_len[rd_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]];
            desc_table_tx_pkt_len_words_rd_ptr_reg <= desc_table_tx_pkt_len_words[rd_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]];
            desc_table_tx_pkt_start_mem_addr_rd_ptr_reg <= desc_table_tx_pkt_start_mem_addr[rd_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]];

        end

        if (tx_pkt_wr_ptr_desc_table_tx_pkt_len_en_reg) begin

            // csr9_tx1 is for writing tx_pkt length in bytes by riscv
            // desc_table_tx_pkt_len[wr_fifo_ptr_tx_pkt_reg] <= csr9_tx1;
            desc_table_tx_pkt_len[wr_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]] <= csr9_tx1;

        end  


        if (tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_en_reg) begin

            // csr10_tx1 is for writing tx_pkt length in words by riscv
            // desc_table_tx_pkt_len_words[wr_fifo_ptr_tx_pkt_reg] <= csr10_tx1;
            desc_table_tx_pkt_len_words[wr_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]] <= csr10_tx1;

        end 

        if (tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_en_reg) begin 

            // csr11_tx1 is for writing the start mem address for the tx_pkt at wr_ptr by riscv
            // desc_table_tx_pkt_start_mem_addr[wr_fifo_ptr_tx_pkt_reg] <= csr11_tx1;
            desc_table_tx_pkt_start_mem_addr[wr_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]] <= csr11_tx1;

        end 


        if (tx_pkt_wr_ptr_desc_table_tx_pkt_avail_en_reg) begin
        
            // csr12_tx1 is for writing the tx_pkt available bit for the tx_pkt at wr_ptr by riscv
            // desc_table_tx_pkt_avail[wr_fifo_ptr_tx_pkt_reg] <= csr12_tx1[0];
            desc_table_tx_pkt_avail[wr_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]] <= csr12_tx1[0];

        end 


        if (desc_table_tx_pkt_transfer_done_en) begin
            
            // desc_table_tx_pkt_transfer_done[rd_fifo_ptr_tx_pkt_reg] <= desc_table_tx_pkt_transfer_done_next;
            desc_table_tx_pkt_transfer_done[rd_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]] <= desc_table_tx_pkt_transfer_done_next;

            // clearing the available bit after the this tx_pkt pointed to by rd_fifo_ptr_tx_pkt_reg
            // has been transferred from memory to bram 
            // desc_table_tx_pkt_avail[rd_fifo_ptr_tx_pkt_reg] <= !desc_table_tx_pkt_transfer_done_next;
            desc_table_tx_pkt_avail[rd_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]] <= !desc_table_tx_pkt_transfer_done_next;

        end

        eth_word_coming_from_mem_for_tx_pkt_dma_reg <= eth_word_coming_from_mem_for_tx_pkt_dma_next;
        eth_word_addr_going_to_mem_for_tx_pkt_dma_reg <= eth_word_addr_going_to_mem_for_tx_pkt_dma_next;

        tx_pkt_bram_select_reg <= tx_pkt_bram_select_next;
        
        // writing the tx_pkt word from memory to tx_pkt bram
        // selecting which tx_pkt bram to write to 
        if (!tx_pkt_bram_select_reg) begin

            if (tx_pkt_word_wr_ptr_en) begin

                tx_mem1[tx_pkt_word_wr_ptr_reg] <= eth_word_coming_from_mem_for_tx_pkt_dma_next;

            end 

        end else if (tx_pkt_bram_select_reg) begin 

            if (tx_pkt_word_wr_ptr_en) begin

                tx_mem2[tx_pkt_word_wr_ptr_reg] <= eth_word_coming_from_mem_for_tx_pkt_dma_next;

            end

        end

        tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_reg <= tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_next;
        tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_reg <= tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_next;         
        

    end 




end

// Combinational part of the TX_PKT_DMA FSM
always @(*) begin
    
    tx_dma_state_next = tx_dma_state_reg;
    eth_mem_read_tx_pkt_req_next = eth_mem_read_tx_pkt_req_reg;

    m_eth_bram_axi_araddr_next = m_eth_bram_axi_araddr_reg;
    m_eth_bram_axi_arvalid_next = m_eth_bram_axi_arvalid_reg;
    m_eth_bram_axi_rready_next = m_eth_bram_axi_rready_reg;

    desc_table_tx_pkt_start_mem_addr_rd_ptr_en_next = desc_table_tx_pkt_start_mem_addr_rd_ptr_en_reg;
    desc_table_tx_pkt_start_mem_addr_wr_ptr_en_next = desc_table_tx_pkt_start_mem_addr_wr_ptr_en_reg;
    desc_table_tx_pkt_len_rd_ptr_en_next = desc_table_tx_pkt_len_rd_ptr_en_reg;
    desc_table_tx_pkt_len_wr_ptr_en_next = desc_table_tx_pkt_len_wr_ptr_en_reg;
    desc_table_tx_pkt_avail_next = desc_table_tx_pkt_avail_reg;
    rd_fifo_ptr_tx_pkt_next = rd_fifo_ptr_tx_pkt_reg;
    // wr_fifo_ptr_tx_pkt_next = wr_fifo_ptr_tx_pkt_reg;
        /*
            shifting it to relevant FSM                
            ERROR: [DRC MDRV-1] Multiple Driver Nets: Net eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_next[0] has multiple drivers: eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_reg_inst__1/O, and eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_next_reg[0]/Q.

        */
    rd_fifo_ptr_increment_tx_pkt_next = rd_fifo_ptr_increment_tx_pkt_reg;
    rd_fifo_ptr_tx_pkt_valid_next = rd_fifo_ptr_tx_pkt_valid_reg;
    rd_fifo_ptr_tx_pkt_overflow_next = rd_fifo_ptr_tx_pkt_overflow_reg;
    desc_table_tx_pkt_error_next = desc_table_tx_pkt_error_reg;
    desc_table_tx_pkt_read_done_clr_next = desc_table_tx_pkt_read_done_clr_reg;
    desc_table_tx_pkt_len_next = desc_table_tx_pkt_len_reg;
    desc_table_tx_pkt_len_words_next = desc_table_tx_pkt_len_words_reg;
    tx_pkt_word_wr_ptr_next = tx_pkt_word_wr_ptr_reg;

    eth_word_coming_from_mem_for_tx_pkt_dma_next = eth_word_coming_from_mem_for_tx_pkt_dma_reg;
    eth_word_addr_going_to_mem_for_tx_pkt_dma_next = eth_word_addr_going_to_mem_for_tx_pkt_dma_reg;


    desc_table_tx_pkt_start_mem_addr_wr_ptr_en = 0;
    desc_table_tx_pkt_len_wr_ptr_en = 0;
    desc_table_tx_pkt_avail_en = 0;
    desc_table_tx_pkt_start_mem_addr_en = 0;
    tx_pkt_word_wr_ptr_en = 0;

    // Start at 0, when this reg is 0 then tx_pkt_bram1 is written to, when this reg is 1 then tx_pkt_bram2 is written
    tx_pkt_bram_select_next = tx_pkt_bram_select_reg; 

    desc_table_tx_pkt_transfer_done_en = 0;
    desc_table_tx_pkt_transfer_done_next = 0;

    tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_next = tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_reg;
    tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_next = tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_reg;

    tx_pkt_transmit_tx_pkt_len_rd_ptr_next = tx_pkt_transmit_tx_pkt_len_rd_ptr_reg;
        // was giving error when it was in other fsm cx it was being assigned in parallel

    case (tx_dma_state_reg)

        TX_PKT_DMA_STATE_IDLE: begin 

            tx_dma_state_next = TX_PKT_DMA_STATE_IDLE;

            // check if there is a valid tx_pkt available in desc_table_tx_pkt 

            // making en HIGH to read desc tabel at the rd ptr rd_fifo_ptr_tx_pkt_reg
            desc_table_tx_pkt_avail_en = 1;
                // TODO: pull this down after reading the tx_pkt from mem has been completed

            // sill start writing tx_pkt BRAM at idx 0
            tx_pkt_word_wr_ptr_next = 0; 

            // if there is a valid tx_pkt available in memory
            if (desc_table_tx_pkt_avail_rd_ptr_reg && (!desc_table_tx_pkt_empty)) begin

                
                tx_dma_state_next = TX_PKT_DMA_WAIT_MEM_BUS_GRANT;

                // request for memory bus grant to be able to read tx_pkt from memory
                eth_mem_read_tx_pkt_req_next = 1;
                

            end

        end

        TX_PKT_DMA_WAIT_MEM_BUS_GRANT: begin 

            tx_dma_state_next = TX_PKT_DMA_WAIT_MEM_BUS_GRANT;

            if (eth_mem_write_grant) begin

                tx_dma_state_next = TX_PKT_DMA_START_READING;
            
            end 

        end 

        TX_PKT_DMA_START_READING: begin

            tx_dma_state_next = TX_PKT_DMA_ADDR_AND_DATA_READ;

            // setting reading address for starting address of tx_pkt in memory
            // it has to be byte addressed and each byte address reads a 4 byte word
            // In the C code we make sure to 4 byte align the tx_pkt in memory but we need 
            // to still have measures for the case where tx_pkt isn't 4 byte aligned in memory

            eth_word_addr_going_to_mem_for_tx_pkt_dma_next = desc_table_tx_pkt_start_mem_addr_rd_ptr_reg;


        end

        TX_PKT_DMA_ADDR_AND_DATA_READ: begin

            tx_dma_state_next = TX_PKT_DMA_ADDR_AND_DATA_READ;

            m_eth_bram_axi_araddr_next = eth_word_addr_going_to_mem_for_tx_pkt_dma_reg;
            m_eth_bram_axi_arvalid_next = 1;
            
            // maybe do this in the next state :3
            m_eth_bram_axi_rready_next = 1;


            // wait for slave axi endpoint (the memory controller) to be ready to receive the reading addr m_eth_bram_axi_araddr
            // so that it can provide us with the read data m_eth_bram_axi_rdata 
            if (m_eth_bram_axi_arready) begin 

                tx_dma_state_next = TX_PKT_DMA_ADDR_DATA_READ_RESP_WAIT;

            end 


        end

        TX_PKT_DMA_ADDR_DATA_READ_RESP_WAIT: begin 

            tx_dma_state_next = TX_PKT_DMA_ADDR_DATA_READ_RESP_WAIT;

            // the slave axi endpoint (the memory controller) has provided us with valid read data m_eth_bram_axi_rdata
                // will take a few clock cycles to fetch data thats why I'm expecting rvalid to come after a few clks
            if (m_eth_bram_axi_rvalid) begin

                // disable the arvalid and rready signals
                m_eth_bram_axi_arvalid_next = 0;
                m_eth_bram_axi_rready_next = 0; 

                // tx_pkt read data 
                eth_word_coming_from_mem_for_tx_pkt_dma_next = m_eth_bram_axi_rdata;
                
                // Write this tx_pkt word to tx_pkt bram based on the bram selected at ptr tx_pkt_word_wr_ptr_reg
                tx_pkt_word_wr_ptr_en = 1;

                // compare the lengths of the tx_pkt written and based on that we will either read next word or the tx_pkt has been completely read
                
                // adding 1 to tx_pkt_word_wr_ptr_reg since it starts indexing for tx_pkt bram at 0 whereas the tx_pkt_len starts at 1
                if ((tx_pkt_word_wr_ptr_reg + 1) <= desc_table_tx_pkt_len_words_rd_ptr_reg) begin 

                    tx_dma_state_next = TX_PKT_DMA_ADDR_AND_DATA_READ;
                    eth_word_addr_going_to_mem_for_tx_pkt_dma_next = eth_word_addr_going_to_mem_for_tx_pkt_dma_reg + 4;
                        // TODO: IMP!! Implement this following concept in the C library:
                        // what to do if the address is rolling over the upper limit of the address? Should there be a flag for that from sw side? or 
                        // should the sw make sure that only tx_pkt are written to memory without rolling over the upper limit and lets say the 
                        // tx_pkt is written close to upper limit (rollover limit), the sw would rather start writing the next tx_pkt at the
                        // base tx_pkt mem address rather than rolling over the over limit!!!

                    // increment the tx_pkt_word_wr_ptr_reg for writing the next tx_pkt word to tx_pkt bram
                    tx_pkt_word_wr_ptr_next = tx_pkt_word_wr_ptr_reg + 1;

                end else begin
                    
                    // clear the values in the tx_pkt desc_table to let the RISCV know that the tx_pkt has been read
                    tx_dma_state_next = TX_PKT_DMA_UPDATE_DESC_TABLE_AND_TX_BRAM;
                    
                    // if available bit is being cleared by the riscv
                    // if (tx_pkt_wr_ptr_desc_table_tx_pkt_avail_en_reg) begin 

                    // end
                        // Don't need this since avialble bit won't be cleared by riscv, it will be cleared by TX_PKT_DMA
                        // riscv will just have to update the avail bit in desc_table_tx to 1 .. and it will be update at
                        // wr_ptr where as the avail bit cleared by TX_PKT_DMA will be cleared at rd_ptr so we don't need to 
                        // worry about them colliding AND the wr_ptr when updating the avail bit and rd_ptr won't be equal 
                        // while wr_ptr is updating the avail bit using riscv, hence there is no collision hazard that
                        // wr_ptr and rd_ptr will be updating the same avail bit

                    // Stop reading desc_table_tx_pkt at rd_fifo_ptr_tx_pkt_reg
                    desc_table_tx_pkt_avail_en = 0;

                    // pull down request for memory bus grant after completion of reading tx_pkt from memory
                    eth_mem_read_tx_pkt_req_next = 0;

                    // reset tx_pkt_word_wr_ptr_reg to 0 after writing of tx_pkt to bram is complete
                    tx_pkt_word_wr_ptr_next = 0;
                    
                end
                
            end 

        end

        TX_PKT_DMA_UPDATE_DESC_TABLE_AND_TX_BRAM: begin 

            tx_dma_state_next = TX_PKT_DMA_WAIT_FOR_ACK_FROM_TX_TRANSMIT_FSM;

            // desc_table_tx_pkt_transfer_done desc_table_tx_pkt entry is made HIGH at rd_fifo_ptr_tx_pkt_reg 
            // desc_table_tx_pkt_avail is also cleared at ptr rd_fifo_ptr_tx_pkt_reg
            desc_table_tx_pkt_transfer_done_en = 1;
            desc_table_tx_pkt_transfer_done_next = 1;

            // increment rd_fifo_ptr_tx_pkt_reg of desc_table_tx_pkt
            rd_fifo_ptr_tx_pkt_next = rd_fifo_ptr_tx_pkt_reg + 1;

            // handing over the current tx_pkt len that was transferred from mem to bram here
            tx_pkt_transmit_tx_pkt_len_rd_ptr_next = desc_table_tx_pkt_len_rd_ptr_reg;
            tx_pkt_transmit_tx_pkt_len_words_rd_ptr_next = desc_table_tx_pkt_len_words_rd_ptr_reg;
            // 1

            // select the other tx_pkt_mem for writing the next tx_pkt
            tx_pkt_bram_select_next = !(tx_pkt_bram_select_reg);

            // communicating that which tx_pkt_mem bram has the available tx_pkt for transmission
            tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_next = !tx_pkt_bram_select_reg;
                // TODO: Clear error here.. there was no ! here before..
                
            tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_next = tx_pkt_bram_select_reg;

        end   

        TX_PKT_DMA_WAIT_FOR_ACK_FROM_TX_TRANSMIT_FSM: begin 

            tx_dma_state_next = TX_PKT_DMA_WAIT_FOR_ACK_FROM_TX_TRANSMIT_FSM;

            if (tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_reg && tx_pkt_transmit_reading_tx_mem1_flag_reg) begin
                
                tx_dma_state_next = TX_PKT_DMA_STATE_IDLE;

                tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_next = 0;

            end else if (tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_reg && tx_pkt_transmit_reading_tx_mem2_flag_reg) begin 

                tx_dma_state_next = TX_PKT_DMA_STATE_IDLE;

                tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_next = 0;

            end 

        end 


    endcase

end


// ********************************************************************************************************************************************************************
// ***************************************** TX_PKT_DMA FSM -> END *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************


// ********************************************************************************************************************************************************************
// ***************************************** TX_PKT_TRANSMIT FSM -> START *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

localparam [3:0]
    TX_PKT_TRANSMIT_STATE_IDLE = 0,
    TX_PKT_TRANSMIT_STATE_TRANSMIT_TX_PKT = 1,
    TX_PKT_TRANSMIT_STATE_TX_COMPLETE = 2;


    

reg [3:0] tx_pkt_transmit_state_reg = TX_PKT_TRANSMIT_STATE_IDLE, tx_pkt_transmit_state_next;

// register for length (bytes) of the current tx pkt according to current rd ptr 
reg [15:0] tx_pkt_transmit_tx_pkt_len_rd_ptr_reg = 0, tx_pkt_transmit_tx_pkt_len_rd_ptr_next;

// register for length (words) of the current tx pkt according to current rd ptr 
reg [15:0] tx_pkt_transmit_tx_pkt_len_words_rd_ptr_reg = 0, tx_pkt_transmit_tx_pkt_len_words_rd_ptr_next;

// reg tx_pkt_transmit_busy_transmitting_flag_reg, tx_pkt_transmit_busy_transmitting_flag_next;
reg tx_pkt_transmit_reading_tx_mem1_flag_reg, tx_pkt_transmit_reading_tx_mem1_flag_next;
reg tx_pkt_transmit_reading_tx_mem2_flag_reg, tx_pkt_transmit_reading_tx_mem2_flag_next;

reg [9:0] tx_pkt_transmit_tx_mem_rd_ptr_reg, tx_pkt_transmit_tx_mem_rd_ptr_next;
reg tx_pkt_transmit_tx_mem_rd_ptr_en;
// reg tx_pkt_transmit_tx_mem_select;
reg tx_pkt_transmit_tx_mem_select_reg, tx_pkt_transmit_tx_mem_select_next;

reg [MEM_WORD_WIDTH-1:0] tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_reg, tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_next;
reg [1:0] word_to_byte_ptr_reg = 0, word_to_byte_ptr_next;

reg [BYTE_WIDTH-1:0] tx_pkt_transmit_tx_byte_out_reg, tx_pkt_transmit_tx_byte_out_next;
reg tx_pkt_transmit_tx_byte_out_valid_reg, tx_pkt_transmit_tx_byte_out_valid_next;
reg tx_pkt_transmit_tx_byte_out_last_reg, tx_pkt_transmit_tx_byte_out_last_next;

reg [10:0] tx_pkt_bytes_output_counter_reg, tx_pkt_bytes_output_counter_next;

reg tx_pkt_transmission_complete_flag;

// m_axis_tdata
// m_axis_tvalid
// m_axis_tready
// m_axis_tlast

// seq part of fsm
always @ (posedge clk) begin 


    if (rst) begin

        tx_pkt_transmit_state_reg <= TX_PKT_TRANSMIT_STATE_IDLE;
        tx_pkt_transmit_tx_pkt_len_rd_ptr_reg <= 0;
        tx_pkt_transmit_tx_pkt_len_words_rd_ptr_reg <= 0;

        // tx_pkt_transmit_busy_transmitting_flag_reg <= 0;
        tx_pkt_transmit_reading_tx_mem1_flag_reg <= 0;
        tx_pkt_transmit_reading_tx_mem2_flag_reg <= 0;
        tx_pkt_transmit_tx_mem_rd_ptr_reg <= 0;

        tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_reg <= 0;
        word_to_byte_ptr_reg <= 0;
        tx_pkt_transmit_tx_byte_out_reg <= 0;
        // tx_pkt_transmit_tx_byte_out_valid_reg <= 0;
        // tx_pkt_transmit_tx_byte_out_last_reg <= 0;

        tx_pkt_bytes_output_counter_reg <= 0;

        tx_pkt_transmit_tx_mem_select_reg <= 0;

    end else begin 

        tx_pkt_transmit_state_reg <= tx_pkt_transmit_state_next;
        tx_pkt_transmit_tx_pkt_len_rd_ptr_reg <= tx_pkt_transmit_tx_pkt_len_rd_ptr_next;
        tx_pkt_transmit_tx_pkt_len_words_rd_ptr_reg <= tx_pkt_transmit_tx_pkt_len_words_rd_ptr_next;

        // tx_pkt_transmit_busy_transmitting_flag_reg <= tx_pkt_transmit_busy_transmitting_flag_next;

        tx_pkt_transmit_reading_tx_mem1_flag_reg <= tx_pkt_transmit_reading_tx_mem1_flag_next;
        tx_pkt_transmit_reading_tx_mem2_flag_reg <= tx_pkt_transmit_reading_tx_mem2_flag_next;
        tx_pkt_transmit_tx_mem_rd_ptr_reg <= tx_pkt_transmit_tx_mem_rd_ptr_next;

        // tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_reg <= tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_next;
        word_to_byte_ptr_reg <= word_to_byte_ptr_next;
        tx_pkt_transmit_tx_byte_out_reg <= tx_pkt_transmit_tx_byte_out_next;
        // tx_pkt_transmit_tx_byte_out_valid_reg <= tx_pkt_transmit_tx_byte_out_valid_next;
        // tx_pkt_transmit_tx_byte_out_last_reg <= tx_pkt_transmit_tx_byte_out_last_next;

        tx_pkt_bytes_output_counter_reg <= tx_pkt_bytes_output_counter_next;

        tx_pkt_transmit_tx_mem_select_reg <= tx_pkt_transmit_tx_mem_select_next;

        // tx_pkt_transmit_tx_mem_select_next = 0.. read tx_mem1
        if (!tx_pkt_transmit_tx_mem_select_next) begin 

            if (tx_pkt_transmit_tx_mem_rd_ptr_en) begin 
            
                tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_reg <= tx_mem1[tx_pkt_transmit_tx_mem_rd_ptr_next];

            end

        // tx_pkt_transmit_tx_mem_select = 1.. read tx_mem1
        end else begin
            
            if (tx_pkt_transmit_tx_mem_rd_ptr_en) begin
            
                tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_reg <= tx_mem2[tx_pkt_transmit_tx_mem_rd_ptr_next];

            end

        end

    end 


end

assign m_axis_tdata = tx_pkt_transmit_tx_byte_out_next;
assign m_axis_tvalid = tx_pkt_transmit_tx_byte_out_valid_next;
assign m_axis_tlast = tx_pkt_transmit_tx_byte_out_last_next;

// comb part of fsm
always @(*) begin 

    tx_pkt_transmit_state_next = tx_pkt_transmit_state_reg;
    // tx_pkt_transmit_tx_pkt_len_rd_ptr_next = tx_pkt_transmit_tx_pkt_len_rd_ptr_reg;
        // giving error here cx its being allocated values in parallel.. here and the other FSM.. so moving this to other FSM
    tx_pkt_transmit_tx_pkt_len_words_rd_ptr_next = tx_pkt_transmit_tx_pkt_len_words_rd_ptr_reg;

    // tx_pkt_transmit_busy_transmitting_flag_next = tx_pkt_transmit_busy_transmitting_flag_reg;

    tx_pkt_transmit_reading_tx_mem1_flag_next = tx_pkt_transmit_reading_tx_mem1_flag_reg;
    tx_pkt_transmit_reading_tx_mem2_flag_next = tx_pkt_transmit_reading_tx_mem2_flag_reg;

    tx_pkt_transmit_tx_mem_rd_ptr_next = tx_pkt_transmit_tx_mem_rd_ptr_reg;

    tx_pkt_transmit_tx_mem_rd_ptr_en = 0;
    // tx_pkt_transmit_tx_mem_select = 0;
    tx_pkt_transmit_tx_mem_select_next = tx_pkt_transmit_tx_mem_select_reg;

    // tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_next = tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_reg;
    word_to_byte_ptr_next = word_to_byte_ptr_reg;
    tx_pkt_transmit_tx_byte_out_next = tx_pkt_transmit_tx_byte_out_reg;
    tx_pkt_transmit_tx_byte_out_valid_next = 0;
    tx_pkt_transmit_tx_byte_out_last_next = 0;

    tx_pkt_bytes_output_counter_next = tx_pkt_bytes_output_counter_reg;

    tx_pkt_transmission_complete_flag = 0;

    case (tx_pkt_transmit_state_reg)

        TX_PKT_TRANSMIT_STATE_IDLE: begin

            tx_pkt_transmit_state_next = TX_PKT_TRANSMIT_STATE_IDLE;

            tx_pkt_transmit_reading_tx_mem1_flag_next = 0;
            tx_pkt_transmit_reading_tx_mem2_flag_next = 0;

            tx_pkt_transmit_tx_mem_rd_ptr_en = 1;
            
            // reset rd_ptr to 0
            tx_pkt_transmit_tx_mem_rd_ptr_next = 0;

            // reset byte counter to 0
            tx_pkt_bytes_output_counter_next = 0;

            // reset word to byte ptr to 0
            word_to_byte_ptr_next = 0;

            // if a tx_pkt is available in the bram
            if (tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_reg || tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_reg) begin

                if (tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_reg) begin

                    tx_pkt_transmit_state_next = TX_PKT_TRANSMIT_STATE_TRANSMIT_TX_PKT;

                    // notify tx_pkt_dma that tx_mem1 is being read
                    tx_pkt_transmit_reading_tx_mem1_flag_next = 1;

                    // select tx_mem1
                    tx_pkt_transmit_tx_mem_select_next = 0; 

                end else if (tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_reg) begin

                    tx_pkt_transmit_state_next = TX_PKT_TRANSMIT_STATE_TRANSMIT_TX_PKT; 

                    // notify tx_pkt_dma that tx_mem2 is being read
                    tx_pkt_transmit_reading_tx_mem2_flag_next = 1;

                    // select tx_mem2
                    tx_pkt_transmit_tx_mem_select_next = 1;

                end 


            end 

        end

        TX_PKT_TRANSMIT_STATE_TRANSMIT_TX_PKT: begin

            tx_pkt_transmit_state_next = TX_PKT_TRANSMIT_STATE_TRANSMIT_TX_PKT;

            tx_pkt_transmit_tx_mem_rd_ptr_en = 1;

            // reset tx_mem flags
            tx_pkt_transmit_reading_tx_mem1_flag_next = 0;
            tx_pkt_transmit_reading_tx_mem2_flag_next = 0;

            
            // tx_pkt fifo is ready to take in tx_pkt byte for transmission, otherwise wait for it in this state
            if (m_axis_tready) begin

                // count tansmitted tx_pkt bytes 
                tx_pkt_bytes_output_counter_next = tx_pkt_bytes_output_counter_reg + 1;

                // tx_pkt byte being transmitted during this clk cycke is VALID.
                tx_pkt_transmit_tx_byte_out_valid_next = 1;

                // increment ptr to read each byte of the 4 byte word
                word_to_byte_ptr_next = word_to_byte_ptr_reg + 1; 

                if (word_to_byte_ptr_reg == 0) begin 

                    tx_pkt_transmit_tx_byte_out_next =  tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_reg[0 +: BYTE_WIDTH];

                end else if (word_to_byte_ptr_reg == 1) begin

                    tx_pkt_transmit_tx_byte_out_next =  tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_reg[BYTE_WIDTH +: BYTE_WIDTH];

                end else if (word_to_byte_ptr_reg == 2) begin

                    tx_pkt_transmit_tx_byte_out_next =  tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_reg[(2*BYTE_WIDTH) +: BYTE_WIDTH]; 

                end else if (word_to_byte_ptr_reg == 3) begin

                    tx_pkt_transmit_tx_byte_out_next =  tx_pkt_transmit_tx_mem_curr_rd_ptr_data_word_reg[(3*BYTE_WIDTH) +: BYTE_WIDTH];

                    // increment this rd_ptr_next on the transmission of the 4th byte so it loads the next word during transmission of the 4th byte
                    tx_pkt_transmit_tx_mem_rd_ptr_next = tx_pkt_transmit_tx_mem_rd_ptr_reg + 1; 

                end


                if (tx_pkt_bytes_output_counter_next == tx_pkt_transmit_tx_pkt_len_rd_ptr_reg) begin 

                    // last byte tx_pkt transmitted.. raise flag and move to completion state
                    tx_pkt_transmit_state_next = TX_PKT_TRANSMIT_STATE_TX_COMPLETE;
                    tx_pkt_transmit_tx_byte_out_last_next = 1;

                end 


            end

        end

        TX_PKT_TRANSMIT_STATE_TX_COMPLETE: begin 

            // reset flags here
            tx_pkt_transmit_state_next = TX_PKT_TRANSMIT_STATE_IDLE;

            // reset tx_mem reading flags
            tx_pkt_transmit_tx_mem_select_next = 0;

            tx_pkt_transmission_complete_flag = 1;

        end             

    endcase 

end 

// // TODO: remove this below
// if (ENDIAN_SWAP) begin
//     if (byte_to_word_ptr_reg == 2'd0) begin
//         mem_data_word_next = {24'b0,s_axis_tdata};  
//     end else if (byte_to_word_ptr_reg == 2'd1) begin
//         mem_data_word_next = mem_data_word_reg | {16'b0,s_axis_tdata, 8'd0};
//     end else if(byte_to_word_ptr_reg == 2'd2) begin
//         mem_data_word_next = mem_data_word_reg | {8'b0,s_axis_tdata, 16'd0};
//     end else if(byte_to_word_ptr_reg == 2'd3) begin // byte_to_word_ptr_reg will reset to 0 after this
//         mem_data_word_next = mem_data_word_reg | {s_axis_tdata, 24'd0};
//         increment_rx_pkt_word_addr_next = 1'b1;
//         // rx_pkt_len_words_counter_next = rx_pkt_len_words_counter_reg + 1;
//     end 
// end 



// ********************************************************************************************************************************************************************
// ***************************************** TX_PKT_TRANSMIT FSM -> END *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************



// this statment below infers a BRAM
(* ramstyle = "no_rw_check" *)
reg [RV_DATA_WIDTH-1:0] rx_mem[RX_TX_PKT_BRAM_DEPTH-1:0]; // 512 x 32 bits = 2048 bytes = 2KB which is the max packet size
// reg [RV_DATA_WIDTH-1:0] rx_mem[1023:0]; // 512 x 32 bits = 2048 bytes = 2KB which is the max packet size
// reg [RV_DATA_WIDTH-1:0] tx_mem[RX_TX_PKT_BRAM_DEPTH-1:0]; // 512 x 32 bits = 2048 bytes = 2KB which is the max packet size

// register telling if there is a valid eth packet in rx_mem (will need to of these signals 
//if I am storing two eth packets so that while one packet is read the other is written, saving clk cycles)
// reg    rx_pkt_avail_reg;

// reg goes HIGH while data is being transferred from eth fifo to here
reg    rx_pkt_busy;

// there is an error in the received rx pkt (equated to axis usr signal)
reg    rx_pkt_error;

// reg for rx pkt len. Will padd the BRAM with 0s if 4 byte boundry isnt satisfied (pkt len not a multiple of 4), 
// although only the total bytes of the pkt will be read. Even if zeros arent padded for the 4 byte boundry, it shouldnt be
// a problem since we wont be reading those bytes anyway. 
reg [11:0]  rx_pkt_len; // 12 bit rx pkt len goes to 4096. If rx pkt is greater than 2048 we have an error? :3

// for reading rx pkts from BRAM using 4byte word addressing
reg [8:0]  rx_pkt_bram_memaddr; // 9bit cx rv uses word address

// wire for transferring 4 byte rx pkt data word to rv core
wire [31:0] rx_pkt_data_word;  // might need to flip the MSBs and LSBs like zipversa DISL edgetestbed
// need reg if we are assigning values in a precedural block


// reg for transferring signal out
reg s_axis_tready_reg, s_axis_tready_next;
assign s_axis_tready = s_axis_tready_reg;

// state register
localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_TRANSFER_ETH_PKT_IN_BRAM = 3'd1,
    STATE_TRANSFER_ETH_PKT_IN_BRAM_TRANSIENT = 3'd5,
    STATE_BRAM_RX_PKT_AVAIL = 3'd2, 
    STATE_RX_PKT_READING = 3'd3,
    STATE_VEBPF_RX_PKT_HDR_BRAM_FIFO_FULL = 3'd4;

localparam  MAW = 9;

reg [2:0] state_reg = STATE_IDLE, state_next;


reg read_eth_pkt_reg = 1'b1, read_eth_pkt_next;
// reg transfer_in_save = 1'b0;
reg transfer_in_save_reg = 1'b0, transfer_in_save_next;
reg [1:0] byte_to_word_ptr_reg = 0, byte_to_word_ptr_next; // max value is 3 min value is 0
reg [11:0] rx_pkt_len_counter_reg = 0, rx_pkt_len_counter_next;
reg [11:0] rx_pkt_len_counter_temp_reg = 0, rx_pkt_len_counter_temp_next;
reg [RV_DATA_WIDTH-1:0] mem_data_word_reg = 0, mem_data_word_next;
reg [9:0] rx_pkt_len_words_counter_reg = 0, rx_pkt_len_words_counter_next; // 1024 words in case of an error pkt len
// reg [9:0] rx_pkt_len_counter_words_temp_reg = 0; 
reg [9:0] rx_pkt_hdr_len_bytes_counter_reg = 0, rx_pkt_hdr_len_bytes_counter_next; // 1024 words in case of an error pkt len
reg increment_rx_pkt_word_addr_reg = 1'b0, increment_rx_pkt_word_addr_next, increment_rx_pkt_word_addr_reg_reg;
reg rx_pkt_avail_bram_reg = 1'b0, rx_pkt_avail_bram_next; // ctrl reg to check if rx pkt is available in rx bram
reg eth_pkt_len_error_reg = 1'b0, eth_pkt_len_error_next;
reg test_signal = 1'b0;
reg state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_reg, state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_next;

////////////////////////////////////////////////////////////////////////////////////
// Network Subsystem Memory Access Signals  //
////////////////////////////////////////////////////////////////////////////////////

localparam MEM_ADDR_WIDTH = 32; 

// localparam FIFO_DEPTH_ADDR_WDITH = 6;  // should be able to fit max size rx pkts in the allocated memory
    // depth will be 64 (2^6)
// localparam FIFO_DEPTH_ADDR_WDITH = 3;  // should be able to fit max size rx pkts in the allocated memory
    // depth will be 8 (2^3)
localparam FIFO_DEPTH_ADDR_WDITH = 2;  // should be able to fit max size rx pkts in the allocated memory
    // decreasing depth to check for rollover condition
    // depth will be 4 (2^2)
// localparam FIFO_DEPTH_ADDR_WDITH = 1;  // should be able to fit max size rx pkts in the allocated memory
    // TODO -> done: testing with reduced depth for total rxpkts
    // depth will be only 2 pkts now

localparam RX_PKT_DESC_TABLE_DEPTH = 2**FIFO_DEPTH_ADDR_WDITH; //atm RX_PKT_DESC_TABLE_DEPTH = 4 (2^2)

// 2^6 = 64; // 64 i.e. 64 pkts = 1514 (excluding 4 crc bytes) bytes per pkt x 64 pkts (fifo depth) 
// = 94 KB almost .. but pkts can be of min len of 64 bytes so mem utilized = 60 bytes x 64 pkts (fifo depth) = 3.75 KB and 
// so I should use higher depth later on so more pkts of smaller size can be stored or less pkts of larger size stored
// the fsm will keep track of how much mem has been utilized and will only write rx pkts to memory if the memory for it is available
// according to the mem already utilized after writing rx pkts to memory and out of those rx pkts only those memory sizes
// will be counted towards used memory which have not been read yet. The FSM will have one reg of used mem length and it will
// add and subtract rx pkt memory that are written to and read from memory.

localparam RX_PKT_DESC_TABLE_DEPTH_BITS_WIDTH = FIFO_DEPTH_ADDR_WDITH;

// base memory addr for saving rx pkts in DRAM, set by rv softcore (32 bit DRAM address)
// ****** VIP, The base rx pkt mem addr needs to be 4 byte aligned
reg [MEM_ADDR_WIDTH-1:0] rx_pkt_mem_base_addr_reg = 0, rx_pkt_mem_base_addr_next;


// flag to see if this address is available.. written by the rv softcore
reg rx_pkt_mem_base_addr_avail_reg = 0, rx_pkt_mem_base_addr_avail_next;

// allocated memory size for saving rx pkts in DRAM, set by rv softcore (in bytes)
reg [31:0] rx_pkt_alloc_mem_size_reg = 0, rx_pkt_alloc_mem_size_next;
// (in words: 4 bytes)
// reg [31:0] rx_pkt_alloc_mem_words_size_reg = 0, rx_pkt_alloc_mem_words_size_next;
wire [31:0] rx_pkt_alloc_mem_words_size; 

// flag to see if mem length is available.. written by the rv softcore
reg rx_pkt_alloc_mem_size_avail_reg = 0, rx_pkt_alloc_mem_size_avail_next;

// reading pointer for the fifos that hold information about the rx pkts being written to and read from the memory
// These are the fifo consumer pointers (16 bits)
reg [FIFO_DEPTH_ADDR_WDITH:0] rd_fifo_ptr_rx_pkt_reg = 0, rd_fifo_ptr_rx_pkt_next;  
// Not subtracting 1 from FIFO_DEPTH_ADDR_WDITH will make rd ptr width 1 more than FIFO_DEPTH_ADDR_WDITH, the reason
// for that is to compare the MSBs between read and write pointers for comparing rollover of the fifo to check
// if the fifo is full or empty :3
    // FIFO_DEPTH_ADDR_WDITH-1:0 is used for indexing.. MSBit is used for rollover detection

// writing pointer for the fifos that hold information about the rx pkts being written to and read from the memory
// These are the fifo producer pointers (16 bits)
reg [FIFO_DEPTH_ADDR_WDITH:0] wr_fifo_ptr_rx_pkt_reg = 0, wr_fifo_ptr_rx_pkt_next;
    // FIFO_DEPTH_ADDR_WDITH-1:0 is used for indexing.. MSBit is used for rollover detection

// Ctrl signal to increment the rd fifo ptr from this module
reg rd_fifo_ptr_increment_rx_pkt_reg = 0, rd_fifo_ptr_increment_rx_pkt_next;

// This reg only goes high if rd_fifo_ptr_rx_pkt_reg hasnt caught up to wr_fifo_ptr_rx_pkt_reg
// this way rv softcore will avoid comparing rd and wr ptrs and doing additional read of wr pointers
// Ctrl signal (not from a fifo but from comparison of rd and wr ptrs)
reg rd_fifo_ptr_rx_pkt_valid_reg = 0, rd_fifo_ptr_rx_pkt_valid_next;

// overflow flag
reg rd_fifo_ptr_rx_pkt_overflow_reg = 0, rd_fifo_ptr_rx_pkt_overflow_next;

// As per the rd_fifo_ptr, is the rx pkt avialble in mem to be read by the rv softcore or not. 
// This reg will have a value of 1 if rx pkt is available in mem to be read, and will have a value of 0
// if the rx pkt is unavailble or has already been read and the rv softcore has written a 0 for the fifo
// entry here.
    // The FSM for this rx_pkt_avail fifo will write a 1 as soon as the rx pkt is written to mem by this Network Subsystem
    // using the wr_fifo_ptr_rx_pkt_reg.
    // When the rv core finds a 1 here, it will send a clear to make this value 0 (wether that clear means overwriting this or 
    // having another register that will go to 0 causing this entry to go to 0)

// reg desc_table_rx_pkt_avail_reg = 0, desc_table_rx_pkt_avail_next;

// This completion register going to 1 indicates that the rx pkt pointed to by rd_fifo_ptr in the fifo 
// containing its mem addr and length, has been read by the rv softcore.
// the wr_fifo_ptr write fifo pointer will update the value of rx pkt cpl fifo to 0 after writing the rx pkt to mem
reg desc_table_rx_pkt_cpl_reg = 0, desc_table_rx_pkt_cpl_next;

// some error flags
reg desc_table_rx_pkt_error_reg = 0, desc_table_rx_pkt_error_next;

// ctrl word indicating that the current rx pkt pointed to by the desc_table_rx_pkt_mem_addr_reg & and fifo pointer rd_fifo_ptr_rx_pkt_reg[SIZE-1:0]
// 
reg desc_table_rx_pkt_read_done_clr_reg = 0, desc_table_rx_pkt_read_done_clr_next;

// desc table fifo is full 
// full when first MSB different but rest same  // to take account of the rollover affect of ring buffer (1 extra addr bit to keep track of that)
wire desc_table_rx_pkt_full; // = wr_fifo_ptr_rx_pkt_reg == (rd_fifo_ptr_rx_pkt_reg ^ {1'b1, {FIFO_DEPTH_ADDR_WDITH{1'b0}}});
assign desc_table_rx_pkt_full = wr_fifo_ptr_rx_pkt_reg == (rd_fifo_ptr_rx_pkt_reg ^ {1'b1, {FIFO_DEPTH_ADDR_WDITH{1'b0}}});
    // for full condition lets imageine wr_fifo_ptr_rx_pkt_reg = 1000..000 and rd_fifo_ptr_rx_pkt_reg = 000..000 ..
    // this means that wr ptr has rolled over and now is equal to rd ptr, hence the desc table fifo is full now, which
    // is depicted by this XOR equation
    // Similarly the wr ptr rolls from 111..111 to 000...000 and rd ptr is at 1000..000 .. this equation would again tell us that the fifo is full
    // if wr == rd ptr then fifo is empty
    // that is why we declare rd and wr ptrs with width fifodepth+1 and use fifodepth only when reading or writing to fifos and use fifodepth+1
    // width of rd and wr ptrs when raising full or empty flags :3

// desc table fifo is empty when pointers match exactly
wire desc_table_rx_pkt_empty; // = wr_fifo_ptr_rx_pkt_reg == rd_fifo_ptr_rx_pkt_reg;
assign desc_table_rx_pkt_empty = wr_fifo_ptr_rx_pkt_reg == rd_fifo_ptr_rx_pkt_reg;

// replacing rd_fifo_ptr with desc_table for desc table related registers

// the starting memory address of the current rx pkt being transferred to memory
reg [MEM_ADDR_WIDTH-1:0] desc_table_rx_pkt_start_mem_addr_reg = 0, desc_table_rx_pkt_start_mem_addr_next;
reg desc_table_rx_pkt_start_mem_addr_en = 0;

// register for starting mem addr of rx pkt according to current rd ptr
reg [MEM_ADDR_WIDTH-1:0] desc_table_rx_pkt_start_mem_addr_rd_ptr_reg = 0;


// length of the current rx pkt being written to the memory (in bytes)
reg [15:0] desc_table_rx_pkt_len_reg = 0, desc_table_rx_pkt_len_next;

// register for length (bytes) of the current rx pkt according to current rd ptr 
reg [15:0] desc_table_rx_pkt_len_rd_ptr_reg = 0;

// length of the current rx pkt being being written to the memory (in words)
reg [15:0] desc_table_rx_pkt_len_words_reg = 0, desc_table_rx_pkt_len_words_next;

// register for length (words) of the current rx pkt according to current rd ptr 
reg [15:0] desc_table_rx_pkt_len_words_rd_ptr_reg = 0;

// the total memory used by rx pkts in memory that havent been read yet (in bytes)
reg [31:0] total_mem_used_rx_pkts_reg = 0, total_mem_used_rx_pkts_next;
// in words (4 bytes)
reg [31:0] total_mem_words_used_rx_pkts_reg = 0, total_mem_words_used_rx_pkts_next;

// the rx pkt meta data descriptor table fifos  // look at their details in the comments above

// (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
// (* ramstyle = "no_rw_check" *)

// Commenting this below out for a100T14_syn prj
//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [MEM_ADDR_WIDTH-1:0] desc_table_rx_pkt_start_mem_addr[RX_PKT_DESC_TABLE_DEPTH-1:0];
    // making these distributed ramx cx min BRAM mem of e.g., 4K wont be utilized effectively by these BRAMs

reg desc_table_rx_pkt_start_mem_addr_rd_ptr_en_reg = 0, desc_table_rx_pkt_start_mem_addr_rd_ptr_en_next;
reg desc_table_rx_pkt_start_mem_addr_wr_ptr_en_reg = 0, desc_table_rx_pkt_start_mem_addr_wr_ptr_en_next, desc_table_rx_pkt_start_mem_addr_wr_ptr_en = 0; 

// (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
// (* ramstyle = "no_rw_check" *)

// Commenting this below out for a100T14_syn prj
//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [15:0] desc_table_rx_pkt_len[RX_PKT_DESC_TABLE_DEPTH-1:0];

// Commenting this below out for a100T14_syn prj
//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [15:0] desc_table_rx_pkt_len_words[RX_PKT_DESC_TABLE_DEPTH-1:0];

// same enables for both byte and word rx pkt length
reg desc_table_rx_pkt_len_rd_ptr_en_reg = 0, desc_table_rx_pkt_len_rd_ptr_en_next;
reg desc_table_rx_pkt_len_wr_ptr_en_reg = 0, desc_table_rx_pkt_len_wr_ptr_en_next, desc_table_rx_pkt_len_wr_ptr_en = 0; // making a third entry as desc_table_rx_pkt_len_wr_ptr_en so it can be used in combinational circuit directly

// (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
// (* ramstyle = "no_rw_check" *)

// Commenting this below out for a100T14_syn prj
//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg desc_table_rx_pkt_avail[RX_PKT_DESC_TABLE_DEPTH-1:0];

reg desc_table_rx_pkt_avail_en = 0;
reg desc_table_rx_pkt_avail_next;

// reg to pass on desc_table_rx_pkt_avail fifo value at the rd ptr (and other desc table values below) 
reg desc_table_rx_pkt_avail_rd_ptr_reg = 0;


reg [VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH - 1:0] desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination_rd_ptr_reg;
// reg [2:0] desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination_rd_ptr_reg;


reg desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit_rd_ptr_reg;
reg desc_table_VeBPF_rx_pkt_hdr_processing_done_result_dropRxPkt_bit_rd_ptr_reg;
reg desc_table_VeBPF_rx_pkt_hdr_processed_done_valid_rd_ptr_reg;

// reg to clear rx pkt avail fifo entry through MMIO
    // ctrl signal to clear the rx pkt avail bit according to the rd ptr cx the rx pkt has been successfully read
reg desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg = 0, desc_table_rx_pkt_avail_overwrite_rd_ptr_en_next;
reg desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_reg = 0, desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_next;


// reg desc_table_rx_pkt_avail_rd_ptr_en_reg = 0, desc_table_rx_pkt_avail_rd_ptr_en_next;
// reg desc_table_rx_pkt_avail_wr_ptr_en_reg = 0, desc_table_rx_pkt_avail_wr_ptr_en_next;

// (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
// (* ramstyle = "no_rw_check" *)
// reg desc_table_rx_pkt_cpl[RX_PKT_DESC_TABLE_DEPTH-1:0];

// reg desc_table_rx_pkt_cpl_rd_ptr_en_reg = 0, desc_table_rx_pkt_cpl_rd_ptr_en_next;
// reg desc_table_rx_pkt_cpl_wr_ptr_en_reg = 0, desc_table_rx_pkt_cpl_wr_ptr_en_next;

// (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
// (* ramstyle = "no_rw_check" *) 
// reg desc_table_rx_pkt_error[RX_PKT_DESC_TABLE_DEPTH-1:0];

// reg desc_table_rx_pkt_error_rd_ptr_en_reg = 0, desc_table_rx_pkt_error_rd_ptr_en_next;
// reg desc_table_rx_pkt_error_wr_ptr_en_reg = 0, desc_table_rx_pkt_error_wr_ptr_en_next;

reg [31:0] eth_word_going_to_mem_reg; // register for transferring rx pkt word to memory
// ptr register to read rx pkts from rx_mem and transfer them to memory
// reg [RX_TX_PKT_BRAM_DEPTH-1:0] rx_pkt_word_ptr_reg = 0, rx_pkt_word_ptr_next;// RX_TX_PKT_BRAM_DEPTH = 512 (words), = 2048 bytes 
    // INCORRECT ... too wide... the width^2 should have been RX_TX_PKT_BRAM_DEPTH
// reg [15:0] rx_pkt_word_ptr_reg = 0, rx_pkt_word_ptr_next;// RX_TX_PKT_BRAM_DEPTH = 512 (words), = 2048 bytes 
reg [9:0] rx_pkt_word_ptr_reg = 0; //, rx_pkt_word_ptr_next;// RX_TX_PKT_BRAM_DEPTH = 512 (words), = 2048 bytes 
reg [9:0] rx_pkt_word_ptr_next = 0; 
reg rx_pkt_word_ptr_en = 0;

// reg [15:0] rx_pkt_word_ptr2_reg = 0;
// reg [15:0] rx_pkt_word_ptr2_next = 0;
// reg rx_pkt_word_ptr_en2_reg = 0;
// reg rx_pkt_word_ptr_en2_next = 0;

// I can have two diff enables for reading one desc table fifo, e.g., desc_table_rx_pkt_cpl, the write cpl enable will write a 0 to the cpl desc table 
// location pointed by wr ptr while read cpl enable will write a 1 to cpl desc table fifo pointed to by rd ptr
// Just rememebered the desc table fifos will need to be in a clk block inorder to be inferred as a bram
// but here the rams will be infered as distributed as depicted by the keywords (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
// the reason being that we need to access these rams (read them) outside the clk in the comb block of our fsm.
// we can write these rams in the clk block so that we know whats  being written at what time (clk + enable) and that we can give intial values to the rams

reg eth_mem_write_req_reg = 0, eth_mem_write_req_next;

// only for rx_pkt DMA
//assign eth_mem_write_req = eth_mem_write_req_reg;

// for both rx_pkt and tx_pkt DMA
assign eth_mem_write_req = eth_mem_write_req_reg || eth_mem_read_tx_pkt_req_reg;



/////////////////// registers for m axi FSM  ////////////////////////

// memory address available flag from softcore
reg mem_addr_avail_reg = 0, mem_addr_avail_next;

// memory address to write to DRAM
reg [31:0] ddr_mem_addr; 

// memory write by network subsystem to mem flag
reg mem_write_comp_reg = 0, mem_write_comp_next;

// busy writing to memory
reg mem_write_busy_reg = 0, mem_write_busy_next;



// network subsystem memory writing csr1 register

// csr1 gives rx pkt len and rx status words
wire [31:0] csr1;  // = {30'b0, mem_write_comp_reg, mem_addr_avail_reg};

assign csr1 = {   // 16'bits R
                  desc_table_rx_pkt_len_rd_ptr_reg,

                  // 1 bit padding + 5 bits extra dest bits = 6 bits
                  // 1'bit1 padding
                  1'b0,
                  // 5'bits extra for rxpkt destination in the CSR register
                  desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination_rd_ptr_reg[7:3],

                  // 5 bits padding + 1 bit dropRxPkt bit = 6 bits
                  // 5'bits padding
                  // {5{1'b0}},
                  // 1'bit dropRxPkt bit
                  // desc_table_VeBPF_rx_pkt_hdr_processing_done_result_dropRxPkt_bit_rd_ptr_reg,

                  //5 bits VeBPF csr registers
                  desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination_rd_ptr_reg[2:0],  // 3 bit  // 3 lower bits of the whole reg atm
                  desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit_rd_ptr_reg,  // 1 bit
                  desc_table_VeBPF_rx_pkt_hdr_processed_done_valid_rd_ptr_reg,  // 1 bit
                  // 2'bits W // need to be written to/updated by the MMIO 
                  rd_ptr_rx_pkt_fifo_inc_reg, desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_reg,
                  // 3'bits R // need to be read by MMIO 
                  desc_table_rx_pkt_avail_rd_ptr_reg, desc_table_rx_pkt_full, desc_table_rx_pkt_empty};

    // will add half full and full etc flags here so that the softcore when to "throttle" the reading network pkts
    // First read if desc table is empty.

// csr2 gives the rx pkt start mem addrs
// 32'bits W
    // R means read by the subsystem on the other side (such as softcore) and W means write, by the AXI Master 
wire [31:0] csr2;

assign csr2 = desc_table_rx_pkt_start_mem_addr_rd_ptr_reg;

// csr3 is for storing the starting mem addr for the heap mem allocated (by softcore possibly)
    // comment from c file: write the 4 byte memory ptr address of this allocated memory (starting heap address cx its dynamic allocation) to network subsystem
// 32'bits W
wire [31:0] csr3;
assign csr3 = rx_pkt_mem_base_addr_reg;

// csr4 is for storing the allocated size for the rx pkts in memory
// 32'bits W
wire [31:0] csr4;
assign csr4 = rx_pkt_alloc_mem_size_reg;

// csr5_tx1 is for reading if DESC_TABLE_TX is FULL. 
    // csr5_tx1 is also for writing the increment wr_ptr bit..
        // which will raise flag to network subsystem that memory address range for tx_pkts has been allocated and network subsystem is good to start tx of tx_pkts. 
        // and that the network subsystem is "armed" to starting tx-ing tx_pkts 
        // like what's happening in csr1.. when the fifo isn't empty anymore the network subsystem will start transmitting the tx_pkts..
wire [31:0] csr5_tx1;
assign csr5_tx1 = { 
                    // 29 bits of padding 
                    {29{1'b0}},
                    // 1 bit desc_table_tx_pkt EMPTY flag
                    desc_table_tx_pkt_empty,
                    // 1 bit flag for incrementing the wr_ptr in network subsystem (by riscv softcore)
                    wr_fifo_ptr_tx_pkt_inc_reg,
                    // 1 bit desc_table_tx_pkt FULL flag
                    desc_table_tx_pkt_full
                        
                    };

// csr6_tx1 is for writing the total riscv allocated DDR available tx memory (bytes) for debugging pruposes
wire [31:0] csr6_tx1;
assign csr6_tx1  = tx_pkt_current_available_memory_reg;

// csr7_tx1 is for reading the wr_fifo_ptr_tx_pkt_reg by rsicv
wire [31:0] csr7_tx1;
assign csr7_tx1 = {{(32 - FIFO_DEPTH_ADDR_WDITH_TX_PKT){1'b0}}, wr_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]};
// assign csr7_tx1 = {0, wr_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]};

    
// csr8_tx1 is for reading the rd_fifo_ptr_tx_pkt_reg by riscv
wire [31:0] csr8_tx1;
assign csr8_tx1 = {{(32 - FIFO_DEPTH_ADDR_WDITH_TX_PKT){1'b0}}, rd_fifo_ptr_tx_pkt_reg[FIFO_DEPTH_ADDR_WDITH_TX_PKT-1:0]};

// csr9_tx1 is for writing tx_pkt length in bytes by riscv
wire [31:0] csr9_tx1;
assign csr9_tx1 = {{16{1'b0}}, tx_pkt_wr_ptr_desc_table_tx_pkt_len_reg};


// csr10_tx1 is for writing tx_pkt length in words by riscv
wire [31:0] csr10_tx1;
assign csr10_tx1 = {{16{1'b0}}, tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_reg};


// csr11_tx1 is for writing the start mem address for the tx_pkt at wr_ptr by riscv
wire [31:0] csr11_tx1;
assign csr11_tx1 = tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_reg;


// csr12_tx1 is for writing the tx_pkt available bit for the tx_pkt at wr_ptr by riscv
wire [31:0] csr12_tx1;
assign csr12_tx1 = {{31{1'b0}}, tx_pkt_wr_ptr_desc_table_tx_pkt_avail_reg[0]};


// csr13_tx1 is for writing "tx_pkt_calculated_start_mem_addr_prev_wr_ptr" to network subsystem for debugging pruposes
reg [31:0] csr13_tx1_reg;
wire [31:0] csr13_tx1;
assign csr13_tx1 = csr13_tx1_reg;


// csr14_tx1 is for writing "tx_pkt_calculated_start_mem_addr_curr_rd_ptr" to network subsystem for debugging pruposes
reg [31:0] csr14_tx1_reg;
wire [31:0] csr14_tx1;
assign csr14_tx1 = csr14_tx1_reg;


// csr15_tx1 is for writing "tx_pkt_upper_limit_mem_addr" to network subsystem for debugging pruposes
reg [31:0] csr15_tx1_reg;
wire [31:0] csr15_tx1;
assign csr15_tx1 = csr15_tx1_reg;


// csr16_tx1 is for writing "tx_pkt_calculated_start_mem_addr_prev_wr_ptr_delta" to network subsystem for debugging pruposes
reg [31:0] csr16_tx1_reg;
wire [31:0] csr16_tx1;
assign csr16_tx1 = csr16_tx1_reg;


// csr17_tx1 is for writing "tx_pkt_start_mem_addr" to network subsystem for debugging pruposes
reg [31:0] csr17_tx1_reg;
wire [31:0] csr17_tx1;
assign csr17_tx1 = csr17_tx1_reg;


// csr18_tx1 is for writing "tx_pkt_calculated_start_mem_addr_curr_wr_ptr" to network subsystem for debugging pruposes
reg [31:0] csr18_tx1_reg;
wire [31:0] csr18_tx1;
assign csr18_tx1 = csr18_tx1_reg;


// csr19_tx1 is for writing "" to network subsystem for debugging pruposes
reg [31:0] csr19_tx1_reg;
wire [31:0] csr19_tx1;
assign csr19_tx1 = csr19_tx1_reg;


// csr20_tx1 is for writing "tx_pkt_calculated_start_mem_addr_curr_rd_ptr_delta" to network subsystem for debugging pruposes
reg [31:0] csr20_tx1_reg;
wire [31:0] csr20_tx1;
assign csr20_tx1 = csr20_tx1_reg;

/*
    // CSR_tx supporting regs
    reg [15:0] tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_reg, tx_pkt_wr_ptr_desc_table_tx_pkt_len_reg;
    reg tx_pkt_wr_ptr_desc_table_tx_pkt_len_en_reg;
    reg [31:0] tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_reg;
    reg tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_en_reg;
    // need to write desc_table_tx_pkt_avail bit after all tx_pkt meta_data has been written to desc_table_tx
    reg tx_pkt_wr_ptr_desc_table_tx_pkt_avail_reg;
    reg tx_pkt_wr_ptr_desc_table_tx_pkt_avail_en_reg;

    // I don't need to read and then write to "desc_table_tx_pkt_transfer_done" cx FIFO FULL will tell the riscv that 
    // if the wr_ptr has reached the rd_ptr or not, hence by looking at FIFO FULL flag it will be made sure that rd_ptr desc_table_tx
    // values aren't overwritten

*/

// ctrl signal to incremenr the rd_ptr for the rx_pkt fifos
reg rd_ptr_rx_pkt_fifo_inc_reg = 0;


// flag to check if memory address is being written from rv softcore 
wire net_mem_addr;

// flag to check if net mem csr1 is being read or written from the rv softcore
wire net_mem_csr1;

// flag to check if net rx pkt allocated size is being read or written from the softcore
wire net_alloc_mem_size;

// flags indicating which csrs were accessed by the master axi endpoint (softcore)
wire net_csr1;
wire net_csr2;
wire net_csr3;
wire net_csr4;
wire net_csr5_tx1;
wire net_csr6_tx1;
wire net_csr7_tx1;
wire net_csr8_tx1;
wire net_csr9_tx1;
wire net_csr10_tx1;
wire net_csr11_tx1;
wire net_csr12_tx1;
wire net_csr13_tx1;
wire net_csr14_tx1;
wire net_csr15_tx1;
wire net_csr16_tx1;
wire net_csr17_tx1;
wire net_csr18_tx1;
wire net_csr19_tx1;
wire net_csr20_tx1;

localparam [7:0]
    MEM_WRITE_STATE_IDLE = 8'd0,
    MEM_WRITE_START_WRITE = 8'd1,
    MEM_WRITE_ADDR_DATA_WRITE = 8'd2,
    MEM_WRITE_AW_W_RESP_WAIT = 8'd3,
    MEM_WRITE_ADDR_WRITE = 8'd4, 
    MEM_WRITE_DATA_WRITE = 8'd5,
    MEM_WRITE_B_RESP_WAIT = 8'd6,
    MEM_CLEAR_RX_PKT_BRAM = 8'd7,
    MEM_WAIT_UPDATE_DESC_TABLE_WR_PTR = 8'd8,
    MEM_WRITE_DONE = 8'd9,
    MEM_WRITE_WAIT_MEM_BUS_GRANT = 8'd20;

reg [7:0] mem_state_reg = MEM_WRITE_STATE_IDLE, mem_state_next;
    // update state reg width if the parameters are updated

// writing
reg [31:0] m_eth_bram_axi_awaddr_reg, m_eth_bram_axi_awaddr_next;
reg [31:0] m_eth_bram_axi_wdata_reg, m_eth_bram_axi_wdata_next;
reg        m_eth_bram_axi_awvalid_reg, m_eth_bram_axi_awvalid_next; 
reg        m_eth_bram_axi_wvalid_reg, m_eth_bram_axi_wvalid_next;
reg [3:0]  m_eth_bram_axi_wstrb_reg, m_eth_bram_axi_wstrb_next;
reg        m_eth_bram_axi_b_ready_reg, m_eth_bram_axi_b_ready_next;
reg        eth_mem_write_reg, eth_mem_write_next;



// new variable defs
reg rx_clear_en_reg = 0, rx_clear_en_next;
reg rx_clear_ctrl_reg = 0, rx_clear_ctrl_next;
reg [31:0] last_mem_wr_addr_reg = 0, last_mem_wr_addr_next;
reg [31:0] eth_addr_word_going_to_mem_reg = 0, eth_addr_word_going_to_mem_next;
wire eth_mem_write;
reg update_total_mem_used_en;

assign m_eth_bram_axi_awaddr = m_eth_bram_axi_awaddr_reg;
assign m_eth_bram_axi_wdata = m_eth_bram_axi_wdata_reg;
assign m_eth_bram_axi_awvalid = m_eth_bram_axi_awvalid_reg;
assign m_eth_bram_axi_wvalid = m_eth_bram_axi_wvalid_reg;
assign m_eth_bram_axi_wstrb = m_eth_bram_axi_wstrb_reg;
assign m_eth_bram_axi_b_ready = m_eth_bram_axi_b_ready_reg;
assign eth_mem_write = eth_mem_write_reg;



// allocated mem size for rx pkts in memory in words (4 bytes)
// see why +1, in mem write FSM where desc_table_rx_pkt_len_words_next is being modified
// TODO rx_pkt_alloc_mem_size_reg
assign rx_pkt_alloc_mem_words_size = (rx_pkt_alloc_mem_size_reg[1:0] > 0) ? (rx_pkt_alloc_mem_size_reg >> 2) + 1 : (rx_pkt_alloc_mem_size_reg >> 2);

// integer j;

// initial begin

//     // #900_000  // wait 900 us
//     #3_000_000  // wait 3000 us
//     $display("desc_table_rx_pkt_avail[i] value are as follows:");

//     for (j=0; j <= (RX_PKT_DESC_TABLE_DEPTH - 1); j=j+1) begin
//         $display("%d:%h \n",j,desc_table_rx_pkt_avail[j]);    
//     end
// end

initial begin 

    // found the bug in my code that why wasn't the if condition as follows working;
        // if((NET_RX_FIFO_EMPTY(net_csr1) == 0) && (NET_RX_PKT_AVAIL(net_csr1)) && (NET_RX_PKT_VeBPF_VALID(net_csr1) == 1))
    // https://stackoverflow.com/questions/77748512/multiple-conditions-using-define-macro-functions-in-if-condition-is-not-working?noredirect=1#comment137070901_77748512
    // the bug was as mentioned in my comment on the stackoverflow question of mine:
        /*
            @PeterCordes you were correct, there was some other problem in my simulation. Including or excluding the 
            "define macro functions" in the if-condition did not make a difference and worked both ways after I found the bug today. 
            The bug was that in my FPGA hw rtl, I was not initializing the registers to zero and RISCV was reading "don't cares 0xXX" 
            when reading those registers, causing the ambiguity in the if-condition. Thanks for the directions and it was reassuring 
            that you were confident in your answer. What should I do with my question here now? –
        */

    if (SIMULATION) begin

        for (i = 0; i < RX_PKT_DESC_TABLE_DEPTH; i = i+1) begin  // resetting desc table entries to 0 // hopefully this line of code doesnt give any errors while synthesizing
            desc_table_rx_pkt_len[i] <= 0;
            desc_table_rx_pkt_len_words[i] <= 0;
            desc_table_rx_pkt_start_mem_addr[i] <= 0;
            desc_table_rx_pkt_avail[i] <= 0;
        end

    end

end

integer i;

// Seq part of Mem write FSM
always @(posedge clk) begin
    if(rst) begin

        mem_state_reg <= MEM_WRITE_STATE_IDLE;
        m_eth_bram_axi_awaddr_reg <= 0;
        m_eth_bram_axi_awvalid_reg <= 0;
        m_eth_bram_axi_wdata_reg <= 0;
        m_eth_bram_axi_wvalid_reg <= 0;
        m_eth_bram_axi_wstrb_reg <= 0;
        m_eth_bram_axi_b_ready_reg <= 1;  // default value of bready here is 1
        eth_mem_write_reg <= 0;
        mem_write_busy_reg <= 0;
        mem_write_comp_reg <= 0;

        // m_eth_bram_axi_araddr_reg <= 0;
        // m_eth_bram_axi_arvalid_reg <= 0;
        // m_eth_bram_axi_rready_reg <= 1;

        desc_table_rx_pkt_len_reg <= 0;
        desc_table_rx_pkt_len_words_reg <= 0;
        desc_table_rx_pkt_len_wr_ptr_en_reg <= 0;

        wr_fifo_ptr_rx_pkt_reg <= 0;

        // NEED TO COMMENT OUT ALL MEMORY INITIALIZATIONS TO 0 BECAUSE THEY WERE CAUSING INSANE AMOUNT OF EXTRA WIRE CONNECTIONS making it IMPOSSIBLE
        // for the PLACE AND ROUTE TOOL TO ROUTE ALL THE WIRES AND IMPLEMENT THE BITSTREAM (FAILED IN THE IMPLEMENTATION AND BITSTREAM GEN STAGE)
        // Was causing a lot of congestion of wires due to the extra connections due to 0 initializations
//        for (i = 0; i < RX_PKT_DESC_TABLE_DEPTH; i = i+1) begin  // resetting desc table entries to 0 // hopefully this line of code doesnt give any errors while synthesizing
//            desc_table_rx_pkt_len[i] <= 0;
//            desc_table_rx_pkt_len_words[i] <= 0;
//            desc_table_rx_pkt_start_mem_addr[i] <= 0;

//            desc_table_rx_pkt_avail[i] <= 0;
//        end

        eth_word_going_to_mem_reg <= 0;
        rx_pkt_word_ptr_reg <= 0;
        // rx_pkt_word_ptr2_reg <= 0;
        // rx_pkt_word_ptr_en2_reg <= 0;

        rx_clear_ctrl_reg <= 0;
        rx_clear_en_reg <= 0;

        total_mem_used_rx_pkts_reg <= 0;
        total_mem_words_used_rx_pkts_reg <= 0;

        // rx_pkt_alloc_mem_words_size_reg <= 0;
        desc_table_rx_pkt_start_mem_addr_reg <= 0;

        last_mem_wr_addr_reg <= 0;
        eth_addr_word_going_to_mem_reg <= 0;

        eth_mem_write_req_reg <= 0;

        // ringbuffer fifo read pointer
        // rd_fifo_ptr_rx_pkt_reg <= 0;

        desc_table_rx_pkt_start_mem_addr_rd_ptr_reg <= 0;
        desc_table_rx_pkt_len_rd_ptr_reg <= 0;
        desc_table_rx_pkt_len_words_rd_ptr_reg <= 0;
        desc_table_rx_pkt_avail_rd_ptr_reg <= 0;
        desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination_rd_ptr_reg <= 0;
        desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit_rd_ptr_reg <= 0;
        desc_table_VeBPF_rx_pkt_hdr_processing_done_result_dropRxPkt_bit_rd_ptr_reg <= 0;
        desc_table_VeBPF_rx_pkt_hdr_processed_done_valid_rd_ptr_reg <= 0;

        // desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg <= 0;
        // desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_reg <= 0;

        rd_ptr_rx_pkt_fifo_inc_reg <= 0;

    end else begin
        
        mem_state_reg <= mem_state_next;
        m_eth_bram_axi_awaddr_reg <= m_eth_bram_axi_awaddr_next;
        m_eth_bram_axi_awvalid_reg <= m_eth_bram_axi_awvalid_next;
        m_eth_bram_axi_wdata_reg <= m_eth_bram_axi_wdata_next;
        m_eth_bram_axi_wvalid_reg <= m_eth_bram_axi_wvalid_next;
        m_eth_bram_axi_wstrb_reg <= m_eth_bram_axi_wstrb_next;
        m_eth_bram_axi_b_ready_next <= m_eth_bram_axi_b_ready_reg;
        eth_mem_write_reg <= eth_mem_write_next;
        mem_write_busy_reg <= mem_write_busy_next;
        mem_write_comp_reg <= mem_write_comp_next;

        desc_table_rx_pkt_len_reg <= desc_table_rx_pkt_len_next;
        desc_table_rx_pkt_len_words_reg <= desc_table_rx_pkt_len_words_next;
        desc_table_rx_pkt_len_wr_ptr_en_reg <= desc_table_rx_pkt_len_wr_ptr_en_next;

        wr_fifo_ptr_rx_pkt_reg <= wr_fifo_ptr_rx_pkt_next;

        // if (desc_table_rx_pkt_len_wr_ptr_en_reg) begin  // writing to desc table pkt len fifos
        if (desc_table_rx_pkt_len_wr_ptr_en_next) begin  // replacing _regs with _next
            
            desc_table_rx_pkt_len[wr_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= desc_table_rx_pkt_len_next;
            desc_table_rx_pkt_len_words[wr_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= desc_table_rx_pkt_len_words_next; // TODO: uncomment
            
            // doesn't get updated in time
            // // calculating how much memory has been used up till now while writing rx pkts to mem
            // total_mem_used_rx_pkts_reg <= total_mem_used_rx_pkts_reg + desc_table_rx_pkt_len_next;
            // total_mem_words_used_rx_pkts_reg <= total_mem_words_used_rx_pkts_reg + desc_table_rx_pkt_len_words_next;  

        end

        if (update_total_mem_used_en) begin

            // calculating how much memory has been used up till now while writing rx pkts to mem
            total_mem_used_rx_pkts_reg <= total_mem_used_rx_pkts_reg + desc_table_rx_pkt_len_reg;
            total_mem_words_used_rx_pkts_reg <= total_mem_words_used_rx_pkts_reg + desc_table_rx_pkt_len_words_reg;  

        end 

        rx_pkt_word_ptr_reg <= rx_pkt_word_ptr_next;
        // rx_pkt_word_ptr2_reg <= rx_pkt_word_ptr2_next;
        // rx_pkt_word_ptr_en2_reg <= rx_pkt_word_ptr_en2_next;


        if(rx_pkt_word_ptr_en) begin
            // want this reg to retain its value for other states so its a DFF
            // eth_word_going_to_mem_reg <= rx_mem[rx_pkt_word_ptr_next]; // replaced reg with next // keeing rx_mem inside seq block so it stays a BRAM
                // error here... rx_pkt_word_ptr_next starts writing at idx = 1
                    // not error here any longer since rx_pkt_word_ptr starts writing at idx = 0 during reception 
            eth_word_going_to_mem_reg <= rx_mem[rx_pkt_word_ptr_next];
            
        end 

        rx_clear_en_reg <= rx_clear_en_next;
        rx_clear_ctrl_reg <= rx_clear_ctrl_next;

        // if (rx_clear_en_reg) begin
        if (rx_clear_en_next) begin
            // rx_clear <= rx_clear || rx_clear_ctrl_reg;  // this will next 1 extra clk cycle from update of rx_clear_ctrl_reg // tested this
            rx_clear <= rx_clear || rx_clear_ctrl_next;  // this will 1 clk cycle less than if regs were used instead of next
        end else if (!rx_pkt_avail_bram_next) begin  // replaced next here as well
            rx_clear <= 0;
        end

        // if (rx_pkt_alloc_mem_size_reg[1:0] > 0) begin  // see why in FSM below where desc_table_rx_pkt_len_words_next is being modified
        //     rx_pkt_alloc_mem_words_size_reg <= (rx_pkt_alloc_mem_size_reg >> 2) + 1;  // rx_pkt_alloc_mem_size_reg is yet to be initialized
        // end else begin
        //    rx_pkt_alloc_mem_words_size_reg <= (rx_pkt_alloc_mem_size_reg >> 2);  // rx_pkt_alloc_mem_size_reg is yet to be initialized 
        // end

        desc_table_rx_pkt_start_mem_addr_reg <= desc_table_rx_pkt_start_mem_addr_next;
        last_mem_wr_addr_reg <= last_mem_wr_addr_next;
        eth_addr_word_going_to_mem_reg <= eth_addr_word_going_to_mem_next;

        if(desc_table_rx_pkt_start_mem_addr_en) begin  // look at test1 debugging example
            desc_table_rx_pkt_start_mem_addr[wr_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= desc_table_rx_pkt_start_mem_addr_next;
        end

        eth_mem_write_req_reg <= eth_mem_write_req_next;

        // wont need to read from and write to the same address in the simultaneously 
        // fifo cx we will be checking full and empty conditions before rd and wr ptr increments
        // so if we get buggy values when rd and wr pointer are same then its a non issue
        // this will be a DFF so it will retain its value while enable is HIGH and write is being done     
        if(!desc_table_rx_pkt_start_mem_addr_en) begin
          desc_table_rx_pkt_start_mem_addr_rd_ptr_reg <= desc_table_rx_pkt_start_mem_addr[rd_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]];
        end 

        if(!desc_table_rx_pkt_len_wr_ptr_en_next) begin
            desc_table_rx_pkt_len_rd_ptr_reg <= desc_table_rx_pkt_len[rd_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]];
            desc_table_rx_pkt_len_words_rd_ptr_reg <= desc_table_rx_pkt_len_words[rd_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]];
        end

        // updating availability of rx pkts in the fifo after they have been written to memory
        if(desc_table_rx_pkt_avail_en) begin

            desc_table_rx_pkt_avail[wr_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= desc_table_rx_pkt_avail_next;

        end else if (desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg && (!desc_table_rx_pkt_len_wr_ptr_en_next)) begin
            // only enters this when desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg == 1 and during that we make
            // desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_reg = 0 which is negated and it writes a 0 to rx pkt avail fifo

            // clear rx pkt avail entry accor to rd ptr as per MMIO command
            // only executes when there is enable "desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg"
            desc_table_rx_pkt_avail[rd_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= (!desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_reg);
        
            // Adding logic to decrement the total memory used as the chosen rd ptr rx pkt is cleared (its len is decremented)
            total_mem_used_rx_pkts_reg <= total_mem_used_rx_pkts_reg - desc_table_rx_pkt_len_rd_ptr_reg;
                // desc_table_rx_pkt_len_rd_ptr_reg is selected by the rd ptr of the particular rx pkt chosen by rd ptr
                // and after this the rd ptr is incremented. 

            total_mem_words_used_rx_pkts_reg <= total_mem_words_used_rx_pkts_reg - desc_table_rx_pkt_len_words_rd_ptr_reg;
                // added capability of decreasing total words used after they are read by riscv 

            // commenting this line below and putting it in the if else block below since we aren't interested in desc_table_rx_pkt_avail_en signal for it
            // and we do need the else statement of the ifelse block below    
        
            // // Adding desc table entry for "desc_table_VeBPF_rx_pkt_hdr_processed_done_valid" for clearing this bit
            // desc_table_VeBPF_rx_pkt_hdr_processed_done_valid[rd_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= (!desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_reg);  

        end

        // writing and clearing VeBPF related desc table entries 
        if (desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg) begin

             // Adding desc table entry for "desc_table_VeBPF_rx_pkt_hdr_processed_done_valid" for clearing this bit
            desc_table_VeBPF_rx_pkt_hdr_processed_done_valid[rd_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= (!desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_reg);  
        
        // end else if ((!desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg) && (desc_table_VeBPF_en_wr_reg)) begin
        end else if ((!desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg) && (desc_table_VeBPF_en_wr_next)) begin
            // updating _reg here to _next because _reg can conflict with !desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg 

            desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination[
                                wr_ptr_decs_table_VeBPF_result_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= desc_table_VeBPF_r0_next;
                                // desc_table_VeBPF_r0_reg;
            
            desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit[
                                wr_ptr_decs_table_VeBPF_result_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= desc_table_VeBPF_error_next;
                                // desc_table_VeBPF_error_reg;
            
            desc_table_VeBPF_rx_pkt_hdr_processing_done_result_dropRxPkt_bit[
                                wr_ptr_decs_table_VeBPF_result_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= desc_table_VeBPF_dropRxPkt_next;
                                // desc_table_VeBPF_dropRxPkt_reg;
            
            desc_table_VeBPF_rx_pkt_hdr_processed_done_valid[
                            wr_ptr_decs_table_VeBPF_result_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= desc_table_VeBPF_valid_next;
                            // desc_table_VeBPF_valid_reg;

        end        
        
        // not necessary to have this if cond but have it here to observe the behviour 
        if(!desc_table_rx_pkt_avail_en) begin
            desc_table_rx_pkt_avail_rd_ptr_reg <= desc_table_rx_pkt_avail[rd_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]];
            desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination_rd_ptr_reg <= desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination[rd_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]];
            
            desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit_rd_ptr_reg <= desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit[rd_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]];
            desc_table_VeBPF_rx_pkt_hdr_processing_done_result_dropRxPkt_bit_rd_ptr_reg <= desc_table_VeBPF_rx_pkt_hdr_processing_done_result_dropRxPkt_bit[rd_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]];
            
            desc_table_VeBPF_rx_pkt_hdr_processed_done_valid_rd_ptr_reg <= desc_table_VeBPF_rx_pkt_hdr_processed_done_valid[rd_fifo_ptr_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]];
        end

        // // make sure rd_fifo_ptr_rx_pkt_reg is HIGH for only 1 clk cycle
        // if(rd_ptr_rx_pkt_fifo_inc_reg) begin
        //     rd_fifo_ptr_rx_pkt_reg <= rd_fifo_ptr_rx_pkt_reg + 1;
        // end
            // rd pointer is being incremented in the rdptr increment FSM, so this was causing the optimizer to give out error

    end
end

// Comb part of Mem write FSM
always @* begin
    mem_state_next =  MEM_WRITE_STATE_IDLE; // if next state isnt mentioned in a state, I have noticed in simulation that state_reg goes to IDLE
        // TODO: mem_state_next should be mem_state_reg right
    m_eth_bram_axi_awaddr_next = m_eth_bram_axi_awaddr_reg;
    m_eth_bram_axi_awvalid_next = m_eth_bram_axi_awvalid_reg;
    m_eth_bram_axi_wdata_next = m_eth_bram_axi_wdata_reg;
    m_eth_bram_axi_wvalid_next = m_eth_bram_axi_wvalid_reg;
    m_eth_bram_axi_wstrb_next = m_eth_bram_axi_wstrb_reg;
    m_eth_bram_axi_b_ready_next = m_eth_bram_axi_b_ready_reg;
    eth_mem_write_next = eth_mem_write_reg;
    mem_write_busy_next = mem_write_busy_reg;
    mem_write_comp_next = mem_write_comp_reg;

    desc_table_rx_pkt_len_next = desc_table_rx_pkt_len_reg;
    desc_table_rx_pkt_len_words_next = desc_table_rx_pkt_len_words_reg;

    // desc_table_rx_pkt_len_wr_ptr_en = 0;
    // desc_table_rx_pkt_len_wr_ptr_en_next = desc_table_rx_pkt_len_wr_ptr_en_reg;
    desc_table_rx_pkt_len_wr_ptr_en_next = 0;  // normally pull down this value to 0 unless stated otherwise
    rx_clear_en_next = 0;  // default 0
    rx_clear_ctrl_next = 0;  // default 0

    // not pulling down wr_fifo_ptr_rx_pkt_next to 0 in idle state
    wr_fifo_ptr_rx_pkt_next = wr_fifo_ptr_rx_pkt_reg;  

    rx_pkt_word_ptr_next = rx_pkt_word_ptr_reg;  // TODO: uncomment
    rx_pkt_word_ptr_en = 0; 

    // rx_pkt_word_ptr2_next = rx_pkt_word_ptr2_reg;
    // rx_pkt_word_ptr_en2_next = rx_pkt_word_ptr_en2_reg;

    desc_table_rx_pkt_start_mem_addr_next = desc_table_rx_pkt_start_mem_addr_reg;  // using regs here cx I need to save the memory long term
    
    if (rx_pkt_mem_base_addr_recvd_flag_reg) begin

        last_mem_wr_addr_next = rx_pkt_mem_base_addr_reg;
        
    end else begin 

        last_mem_wr_addr_next = last_mem_wr_addr_reg;

    end 

    eth_addr_word_going_to_mem_next = eth_addr_word_going_to_mem_reg;

    desc_table_rx_pkt_start_mem_addr_en = 0;

    eth_mem_write_req_next = eth_mem_write_req_reg;

    desc_table_rx_pkt_avail_en = 0;
    desc_table_rx_pkt_avail_next = 0;

    update_total_mem_used_en = 0;

    case(mem_state_reg)
        MEM_WRITE_STATE_IDLE: begin

            m_eth_bram_axi_awaddr_next = 0;
            m_eth_bram_axi_awvalid_next = 0;
            m_eth_bram_axi_wdata_next = 0;
            m_eth_bram_axi_wvalid_next = 0;
            m_eth_bram_axi_wstrb_next = 0;
            m_eth_bram_axi_b_ready_next = 1;

            eth_mem_write_next = 0;
            mem_write_busy_next = 0;

            desc_table_rx_pkt_len_next = 0;  // cant be pulled down to 0 in default values block since its value is being used in other states
            desc_table_rx_pkt_len_words_next = 0;
            // desc_table_rx_pkt_len_wr_ptr_en_next = 0;  // already pulled down to 0 in default values block
            rx_pkt_word_ptr_next = 0;
            // rx_pkt_word_ptr2_next = 0;
            // rx_pkt_word_ptr_en2_next = 0;

            mem_state_next = MEM_WRITE_STATE_IDLE;

            if(rx_pkt_mem_base_addr_avail_reg && rx_pkt_alloc_mem_size_avail_reg 
                && (!desc_table_rx_pkt_full) && rx_pkt_avail_bram_reg
                && ((total_mem_words_used_rx_pkts_reg + 512) < rx_pkt_alloc_mem_words_size)) begin  // TODO rx_pkt_alloc_mem_words_size
                // checking to see if softcore has made the rx pkt base mem addr available and its size
                // and checking if the desc table has space to write more pkts to memory and
                // if an rx pkt is available to be written to the memory
                // adding 512 (4 byte words) to total_mem_words_used_rx_pkts_reg is for checking
                // that there is roughly the size of 1 more eth pkt avialable in memory to be stored

                desc_table_rx_pkt_len_next = rx_pkt_len_counter_reg;  // writing rx pkt length in bytes to the desc table
                
                // if len in bytes not a multiple of 4 then 1 extra word is there which is not accounted to by rx_pkt_len_words_counter_reg
                // because its index starts at 00 since it is used to write to rx pkt bram
                    // rx_pkt_len_words_counter_reg // can use this for len in terms of words, add + 1 for total words
                
                
                // if (rx_pkt_len_counter_reg[1:0] > 0) begin   

                //     desc_table_rx_pkt_len_words_next = rx_pkt_len_words_counter_reg + 1; // writing rx pkt length in words to the desc table
                //         // adding 1 cx rx_pkt_len_words_counter_reg is a ptr and is 1 less than total len
                
                // end else if (rx_pkt_len_counter_reg[1:0] == 0) begin
                
                //     desc_table_rx_pkt_len_words_next = rx_pkt_len_words_counter_reg + 1;
                //     // desc_table_rx_pkt_len_words_next = rx_pkt_len_words_counter_reg;  // ERROR
                //         // THIS was incorrect... desc_table_rx_pkt_len_words_next should have total words..e.g., if last ptr was 14, then total words = 15..
                //         // rx_pkt_len_counter_reg[1:0] > 0 condition is incremented twice .. once by flag and then by this + 1 
                //     // desc_table_rx_pkt_len_words_next = rx_pkt_len_words_counter_reg + 1;
                //     // Adding 1 here as well ... its the same principle as for the VeBPF data loading.. needed to add 1 cx the rx_pkt_len_words_counter_reg 
                //     // starts from 0 ... while for rx_pkt_len_counter_reg[1:0] > 0 we are adding 1 as well but its actually adding 2 there..,
                //     // cx we have increment word reg = 1 for that case as well..

                // end
                
                desc_table_rx_pkt_len_words_next = rx_pkt_len_words_counter_reg + 1;  // replaces the above ifelse cond block

                // desc_table_rx_pkt_len_words_next = rx_pkt_len_counter_words_temp_reg;
                // desc_table_rx_pkt_len_words_next = rx_pkt_len_words_counter_reg + 1;
                // desc_table_rx_pkt_len_words_next = rx_pkt_len_words_counter_reg + 3;
                // desc_table_rx_pkt_len_words_next = (rx_pkt_len_counter_reg >> 2) + 1;
                // desc_table_rx_pkt_len_words_next = (rx_pkt_len_counter_reg >> 2);
                // desc_table_rx_pkt_len_words_next = rx_pkt_len_words_counter_reg;
                // desc_table_rx_pkt_len_words_next = rx_pkt_len_words_counter_reg + 2;
                // desc_table_rx_pkt_len_words_next = rx_pkt_len_words_counter_reg + 10;

                // will load the rx pkt lens in one clk cycle here and then will be transferred to the desc table in the next to next clk cycle
                desc_table_rx_pkt_len_wr_ptr_en_next = 1;  
                
                // take mem control 
                eth_mem_write_next = 1;

                // THIS IS THE ROLLOVER CONDITION FOR MEM ADDR FOR WRITING RX PKTS TO DDR MEMORY 
                    // the total_mem_words_used_rx_pkts_reg reg doesnt get updated with the pkt len of the newly detected rx pkt, 
                    // but stores the pkt len of the previous rx pkts
                    // checking this condition in idle state so that we dont need to check it while writing a rx pkt to memory
                    // last_mem_wr_addr_reg captures the mem addr of end of last rx pkt written to memory
                        // THIS IS THE ROLLOVER CONDITION FOR MEM ADDR FOR WRITING RX PKTS TO DDR MEMORY 
                if((last_mem_wr_addr_reg + 2048) < (rx_pkt_mem_base_addr_reg + rx_pkt_alloc_mem_size_reg)) begin
                    // this if cond is tied with the if cond above if (total_mem_words_used_rx_pkts_reg + 512) < rx_pkt_alloc_mem_words_size)
                        // most prob won't even enter the else statement below due to the if condition enclosing this ifelse condition
                        
                    // << 2 is vip cx our mem addr right now is 32 bits, i.e., it is addressing in bytes not words, thats why we are converting
                    // word addr into byte addr by << 2.
                    // ERROR HERE... When riscv reads rxpkts, it increments the rdptr, that increment decrements total_mem_words_used_rx_pkts_reg
                    // which causes the next incoming rxpkts to overwrite the previously written rxpkts since total_mem_words_used_rx_pkts_reg stays
                    // the same or decrements since riscv is decrementing the total_mem_words_used_rx_pkts_reg by incrementing the rxpkts at a certain
                    // rate, depending on your algorithm. So the soltion here is to use last_mem_wr_addr_reg in place of total_mem_words_used_rx_pkts_reg << 2
                    // and add 4 since after last address we want to write next 4byte word to an address 4 bytes ahead of it

                    // desc_table_rx_pkt_start_mem_addr_next = rx_pkt_mem_base_addr_reg + (total_mem_words_used_rx_pkts_reg << 2); 
                    
                    // added rx_pkt_mem_base_addr_reg to last_mem_wr_addr_reg when it was allocated
                    // Error in above lines resolved here 
                    desc_table_rx_pkt_start_mem_addr_next = 4 + last_mem_wr_addr_reg; 
                        // start addr for 1st rxpkt would be rx_pkt_mem_base_addr_reg (starting at the base addr)
                    // TODO -> done (I believe): VIP! .... Decrease total_mem_words_used_rx_pkts_reg each time a rxpkt is read and CLEARED by the riscv !!!!!!!!!!!!!!!!
                        // desc_table_rx_pkt_start_mem_addr_next will be saved using total_mem_words_used_rx_pkts_reg for the prev rxpkt cx we are 
                        // calculating START address of current rxpkt
                        // in sync block we have:
                            // if (rx_pkt_mem_base_addr_recvd_flag_reg) begi
                            //     last_mem_wr_addr_next = rx_pkt_mem_base_addr_reg;

                    // need to save start mem addr of each rx pkt in the desc table thats why en is 1
                    desc_table_rx_pkt_start_mem_addr_en = 1;  // forgot to add this

                end else begin

                    // ROLLED OVER 
                    desc_table_rx_pkt_start_mem_addr_next = rx_pkt_mem_base_addr_reg;
                    desc_table_rx_pkt_start_mem_addr_en = 1;
                   
                    // last_mem_wr_addr_next = 0;  // forgot to add this
                        // this will automatically get updated at the end of rx pkt write to mem to base addr + rx pkt word size - 1
                    
                    //  desc_table_rx_pkt_full is false hence that means we would have space in the starting addresses 
                    // last_mem_wr_addr after this else condition write will be rx_pkt_mem_base_addr_reg and will not enter this else condition again until
                    // the memory is fully written again
                    // will keep storing these rx pkt start mem addr locations in desc table so it doesnt matter even if a few mem locations are missed
                end

                // calculate whatever the mem addr of the eth word being written to mem needs to be at the start of writing the rx pkt
                // update this in some other state as the fsm goes thru the words of a selected rx pkt being written to mem
                // eth_addr_word_going_to_mem_reg will have the starting mem addr saved and will just keep adding the word ptr to it until 
                // mem write is done
                    // rx_pkt_mem_base_addr_reg is already loaded since it was made available
                eth_addr_word_going_to_mem_next = desc_table_rx_pkt_start_mem_addr_next;  // equating the next comb reg
                
                // mem_state_next = MEM_WRITE_START_WRITE;
                eth_mem_write_req_next = 1;
                mem_state_next = MEM_WRITE_WAIT_MEM_BUS_GRANT;

            end
        end

        MEM_WRITE_WAIT_MEM_BUS_GRANT: begin
            mem_state_next = MEM_WRITE_WAIT_MEM_BUS_GRANT;
            if(eth_mem_write_grant) begin
                mem_state_next = MEM_WRITE_START_WRITE;
            end

        end 

        MEM_WRITE_START_WRITE: begin
            mem_write_busy_next = 1;
            // load first word, rest will be loaded in the bresp state where rx_pkt_word_ptr_next = 0 in IDLE state
            rx_pkt_word_ptr_en = 1;  
            mem_state_next = MEM_WRITE_ADDR_DATA_WRITE;
        end

        MEM_WRITE_ADDR_DATA_WRITE: begin

            // rx_pkt_word_ptr_next = rx_pkt_word_ptr_reg + 1; 
            // rx_pkt_word_ptr_en = 1;

            m_eth_bram_axi_awaddr_next = eth_addr_word_going_to_mem_reg;
            m_eth_bram_axi_awvalid_next = 1;
            m_eth_bram_axi_wdata_next = eth_word_going_to_mem_reg;
            m_eth_bram_axi_wvalid_next = 1;
            m_eth_bram_axi_wstrb_next = 4'b1111;
            mem_state_next = MEM_WRITE_AW_W_RESP_WAIT;
        end

        MEM_WRITE_AW_W_RESP_WAIT: begin
            mem_state_next = MEM_WRITE_AW_W_RESP_WAIT;
            if(m_eth_bram_axi_awvalid & m_eth_bram_axi_awready & m_eth_bram_axi_wvalid & m_eth_bram_axi_wready) begin
                m_eth_bram_axi_awaddr_next = 0;
                m_eth_bram_axi_awvalid_next = 0;
                m_eth_bram_axi_wdata_next = 32'h00000000;
                m_eth_bram_axi_wvalid_next = 0;
                m_eth_bram_axi_wstrb_next = 4'b0000;
                mem_state_next = MEM_WRITE_B_RESP_WAIT;
            end else if (m_eth_bram_axi_wvalid & m_eth_bram_axi_wready) begin
                m_eth_bram_axi_wdata_next = 32'h00000000;
                m_eth_bram_axi_wvalid_next = 0;
                m_eth_bram_axi_wstrb_next = 4'b0;
                mem_state_next = MEM_WRITE_ADDR_WRITE;
            end else if (m_eth_bram_axi_awvalid & m_eth_bram_axi_awready) begin
                m_eth_bram_axi_awaddr_next = 0;
                m_eth_bram_axi_awvalid_next = 0;
                mem_state_next = MEM_WRITE_DATA_WRITE;
            end
        end

        MEM_WRITE_ADDR_WRITE: begin
            mem_state_next = MEM_WRITE_ADDR_WRITE;
            if(m_eth_bram_axi_awvalid & m_eth_bram_axi_awready) begin
                m_eth_bram_axi_awaddr_next = 0;
                m_eth_bram_axi_awvalid_next = 0;
                mem_state_next = MEM_WRITE_B_RESP_WAIT;
            end
        end 

        MEM_WRITE_DATA_WRITE: begin
            mem_state_next = MEM_WRITE_DATA_WRITE;
            if(m_eth_bram_axi_wvalid & m_eth_bram_axi_wready) begin
                m_eth_bram_axi_wdata_next = 32'h00000000;
                m_eth_bram_axi_wvalid_next = 0;
                m_eth_bram_axi_wstrb_next = 4'b0;
                mem_state_next = MEM_WRITE_B_RESP_WAIT;
            end 
        end 

        MEM_WRITE_B_RESP_WAIT: begin
            mem_state_next = MEM_WRITE_B_RESP_WAIT;
            if(m_eth_bram_axi_b_ready & m_eth_bram_axi_b_valid) begin // m_eth_bram_axi_b_resp = 2'b00
                // as soon as b_valid is received move to the next cycle of writing the rx pkt word to mem or write done (done writing this rx pkt)
                // without "-1" is WRONG (after desc_table_rx_pkt_len_words_reg assignment was updated in the idle state)  -> 
                // since word count starts from 0, this will always have a value of total words - 1
                
                // rx_pkt_word_ptr_next = rx_pkt_word_ptr_reg + 1;  

                // TODO: Experimenting
                // if(rx_pkt_word_ptr_reg < (desc_table_rx_pkt_len_words_reg - 1)) begin  // minus 1 here cx rx_pkt_word_ptr_reg ptr starts at 0 instead of 1
                    // orig
                // if((rx_pkt_word_ptr_reg+1) < (desc_table_rx_pkt_len_words_reg)) begin
                    // experimental

                if((rx_pkt_word_ptr_reg) < (rx_pkt_len_words_counter_reg)) begin
                    // okay so I guess the riscv c code hex file was causing the simulation to get stuck.. cx this setting is running smoothly with the 412 payload
                    // udp rxpkt now which was causing issues,,.. but this time the c code sim file is diff... 
                    // "2023_4_7_edgetestbed_a100T13_sim_multiRxPkt_AND_VeBPF_result_reads_fromMem_sim.hex" was causing the problem.. 
                    // "2023_4_16_edgetestbed_a100T14_sim_multiRxPkt_AND_VeBPF_result_reads_fromMem_v4_sim.hex" is working smoothly
                    // // without any hangups...
                    //     # I tested this again with the problem causing hex file and it was getting stuck.. but it got unstuck when I commented out
                    //     # await tb.mii_phy.rx.wait() line in the test_top.py file... which means there is a relation of riscv softcore with this
                    //     # await tb.mii_phy.rx.wait() courotine? .. Guess I don't need to spend too much time on this and move on...

                // if((rx_pkt_word_ptr2_reg) < (rx_pkt_len_words_counter_reg)) begin
                // if((rx_pkt_word_ptr_reg) < (rx_pkt_len_words_counter_reg + 1)) begin
                // if((rx_pkt_word_ptr_reg + 1) < rx_pkt_len_words_counter_reg) begin  // works now :o
                // if(rx_pkt_word_ptr_reg < rx_pkt_len_words_counter_next) begin  // works now :o
                // if((rx_pkt_word_ptr_next - 1) < rx_pkt_len_words_counter_next) begin  // works now :o
                // if(rx_pkt_word_ptr_next < rx_pkt_len_words_counter_next) begin  // works now :o
                // if((rx_pkt_word_ptr_reg) < (120)) begin
                // if((rx_pkt_word_ptr_reg) < (139)) begin
                // if((rx_pkt_word_ptr_reg) < (138)) begin  // THIS IS CAUSING THE SIM TO GET STUCK... But why..
                    // was related to test_top.py # payload2 = bytes([x % 256 for x in range(512)])  # works
                    // with the settings of test_frames_array.append(arp_frame) test_frames_array.append(test_frame2) test_frames_array.append(test_frame)
                    // this is in synthesized design
                // if((rx_pkt_word_ptr_reg) < (140)) begin 
                // if((rx_pkt_word_ptr_reg) < (136)) begin 
                    // experimental

                    // increment the word ptr so next word gets loaded for the next cycle of transferring the next rx pkt word to memory
                    rx_pkt_word_ptr_next = rx_pkt_word_ptr_reg + 1;  // when total words is 75 .. This will increment till 74, so 0 - 74 is 75 words
                    rx_pkt_word_ptr_en = 1;  // load rx pkt word for the next cycle
                        // TODO -> done: Found bug here.. The first rxpkt word is written twice for the first 2 addresses
                            // changing the rd ptr in rx_mem from rx_pkt_word_ptr_reg to rx_pkt_word_ptr_next
                   
                    eth_addr_word_going_to_mem_next = eth_addr_word_going_to_mem_reg + 32'd4;  // add 4 since we are incrementing to the next word addr (4 bytes i.e., 1 word)
                    // rx_pkt_word_ptr2_next = rx_pkt_word_ptr2_reg + 1;
                    // rx_pkt_word_ptr_en2_next = rx_pkt_word_ptr_en2_reg + 1; 

                    mem_state_next = MEM_WRITE_ADDR_DATA_WRITE; 
                end else begin
                    // // experimental
                    // if(rx_pkt_word_ptr_next < rx_pkt_len_words_counter_reg) begin
                    //     rx_pkt_word_ptr_next = rx_pkt_word_ptr_reg + 1;  // when total words is 75 .. This will increment till 74, so 0 - 74 is 75 words
                    //     rx_pkt_word_ptr_en = 1;  // load rx pkt word for the next cycle
                    //     eth_addr_word_going_to_mem_next = eth_addr_word_going_to_mem_reg + 32'd4;  // add 4 since we are incrementing to the next word addr (4 bytes i.e., 1 word)

                    //     mem_state_next = MEM_WRITE_ADDR_DATA_WRITE; 
                    // end else begin 
                    //     mem_write_busy_next = 0;
                    //     mem_write_comp_next = 1;    // change this later.. Right now for 1 write to mem make this 1 and keep it there
                    //     last_mem_wr_addr_next = eth_addr_word_going_to_mem_reg;  // whatever the last write addr to mem was save it 
                    //     // WRONG below
                    //     // last_mem_wr_addr_next = last_mem_wr_addr_reg + eth_addr_word_going_to_mem_reg;  
                    //         // e.g., 74 + 0 , so new last_mem_wr_addr_reg after 1 clk is 74 which really is the last mem addr that was written to for the rx pkt

                    //     // notifying the availibility of this rx pkt in memory 
                    //     desc_table_rx_pkt_avail_en = 1;
                    //     desc_table_rx_pkt_avail_next = 1;

                    //     // deassert mem control 
                    //     eth_mem_write_next = 0;
                    //     eth_mem_write_req_next = 0;
                    //     mem_state_next = MEM_CLEAR_RX_PKT_BRAM;
                    // end

                    // orig
                // end else if ((rx_pkt_word_ptr_reg) >= (rx_pkt_len_words_counter_reg)) begin
                    mem_write_busy_next = 0;
                    mem_write_comp_next = 1;    // change this later.. Right now for 1 write to mem make this 1 and keep it there
                    last_mem_wr_addr_next = eth_addr_word_going_to_mem_reg;  // whatever the last write addr to mem was save it 
                    // WRONG below
                    // last_mem_wr_addr_next = last_mem_wr_addr_reg + eth_addr_word_going_to_mem_reg;  
                        // e.g., 74 + 0 , so new last_mem_wr_addr_reg after 1 clk is 74 which really is the last mem addr that was written to for the rx pkt

                    // notifying the availibility of this rx pkt in memory 
                    desc_table_rx_pkt_avail_en = 1;
                    desc_table_rx_pkt_avail_next = 1;

                    // deassert mem control 
                    eth_mem_write_next = 0;
                    eth_mem_write_req_next = 0;
                    mem_state_next = MEM_CLEAR_RX_PKT_BRAM;
                end                
            end
        end


        MEM_CLEAR_RX_PKT_BRAM: begin
            // sending clear signals to clear the rx pkt bram and causing it to start loading the next rx pkt if it is available and to rest its FSM to idle so it waits for a new rx pkt
            rx_clear_en_next = 1;
            rx_clear_ctrl_next = 1;            
            mem_state_next = MEM_WAIT_UPDATE_DESC_TABLE_WR_PTR;
        end        

        // wait in this state until there is room in the desc table to store more rx pkt desc data
        MEM_WAIT_UPDATE_DESC_TABLE_WR_PTR: begin
            mem_state_next = MEM_WAIT_UPDATE_DESC_TABLE_WR_PTR;
            if(!desc_table_rx_pkt_full) begin
                wr_fifo_ptr_rx_pkt_next = wr_fifo_ptr_rx_pkt_reg + 1; 
                    // might increment for the last time which will cause the desc_table_rx_pkt_full to be True
                    // but then the FSM will stay stuck in idle state until a read is made and desc_table_rx_pkt_full
                    // becomes FALSE again, that is why we need enables to write into fifos otherwise even when desc table
                    // is full as in this last cycle when wr ptr increments, the fifo at that ptr idx will be over written
                mem_state_next = MEM_WRITE_DONE;
            end
        end

        MEM_WRITE_DONE: begin
            mem_state_next = MEM_WRITE_STATE_IDLE;
            
            // update total memory used registers
            update_total_mem_used_en = 1;


            // mem_state_next = MEM_WRITE_DONE;
            
            // eth_mem_write_next = 0;
                // experimental. Only giving 1 clk cycle to rv to read the next inst between rx pkt writing to mem
                // since rv need 2 cycles for complete read, want to see if the rv gets stuck cx only addr is written in 1 clk cycle to bram
                // so will the bram give the read valid to rv after the 3 rx pkts are written to mem?
                    // what if during this time the network subsystem wants to READ something from mem. What will become of the arvalid signal 
                    // that was sent to bram during this? Will it get discarded? will def get overwritten by netwrok subsystem.
                        // how to deal with this?
                            // (Proposed solution): 
                            // make sure a at least 2 or 3 clk cycles are given to rv core whenever control is taken and then given back to rv core.
                            // give N number of clk cycles to rv core where N = X and X is the number of clk cycles needed to read or write to mem, so that 
                            // the mem doesnt give the arready to the rv softcore for the next mem read if N is greater than X.


        end

    endcase 
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// RISCV MMIO Axi Reading FSM
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////

reg [31:0] axi_araddr_buff;
reg        axi_arready_internal;
reg [31:0] axi_rdata_buff;
reg [3:0]  axi_rvalid_internal;
reg [2:0]  r_state;
reg        read_flag;

// Mealy FSM
// AXI READING FSM output logics
always @(posedge clk)
begin
    if (rst)
    begin
        axi_arready <= 0;
        axi_rvalid <= 0;
    end else
    begin
        axi_arready <= axi_arready_internal;
        axi_rvalid <= axi_rvalid_internal;
    end
end

// Axi Reading FSM comb logic for next state of state "r_state"
// and outputs
  // FSM can be only in 1 state at a time
//always @(posedge clk)  // NEW ADDITION to make reads faster. Lets see the results. Gets one clk slower. Takes on clk to update axi_arready_internal after arvalid and then one more clk to update axi_arready
// will first read the rx ctrl register (in the c code) to see if there is a valid rx pkt available
    // only then will proceed with reading the rx pkt. So don't need to worry about reading rx pkt
    // when it hasnt been received here.

// Also will write 1 to rx_clear reg, after full pkt is read, which will cause the 
    // module to clear the rx pkt by reading a new rx pkt in bram
always @(negedge clk)
begin
    if (rst)
    begin
        axi_araddr_buff <= 0;
        axi_arready_internal <= 0;
        axi_rdata_buff <= 0;
        axi_rvalid_internal <= 0;
        read_flag <= 0;
        r_state <= 0;
    end else if (r_state == 0)
    begin
        axi_arready_internal <= 1;  // stays 1 cx the arvalid is 0 when rv is no accessing. 
        axi_rvalid_internal <= 0;
        read_flag <= 0;
        axi_araddr_buff <= 0;

        if (axi_arvalid)
        begin
            axi_arready_internal <= 0;
            axi_araddr_buff <= axi_araddr;
            read_flag <= 1;
            r_state <= 3'd1;
        end
    end else if (r_state == 3'd1)  // one add clk cycle here. can be removed for optimization as per simulation (might not work in hw)
    begin
        axi_rvalid_internal <= 1;  // this was the correction needed to make the SS work and correct according to AXI4
            // maybe this line wasnt here before and was int r_state = 2?
            // AXI doc
                // A source is not permitted to wait until READY is asserted before asserting VALID
                // A destination is permitted to wait for VALID to be asserted before asserting the corresponding READY.
                // If READY is asserted, it is permitted to deassert READY before VALID is asserted.
        if (axi_rready)  begin// rready is always 1 from rv. If this isnt 1, this FSM will stay stuck in this state
            // and rx_clear won't be cleared due the the araddr from rx pkt reading making netselb HIGH due to its
            // address being stored in ar_addr_buf from the previous state
            // axi_rvalid_internal <= 1;   // on the next pos clk edge the rdata will be latched onto the output wire rdata and axi_rvalid will be turned HIGH
            r_state <= 3'd2;
        end
    end else if (r_state == 3'd2) begin
        if (!axi_rready)  begin  // done reading // received rvalid
            r_state <= 3'd0;
        end 
    end 
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// RISCV MMIO Axi Writing FSM
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////

reg [31:0] axi_awaddr_buff;
reg        axi_awready_internal;
reg [31:0] axi_wdata_buff;
reg [3:0]  axi_wstrb_buff;
reg        axi_wready_internal;
reg [2:0]  w_state;
reg        write_flag;

wire            wr_ctrl;
wire    [2:0]   wr_addr;
wire    [31:0]  wr_data;
wire    [3:0]   wr_sel;     

// AXI Writing FSM output logic for b_valid. Moore FSM?
always @(posedge clk)
begin
    if (rst)
        b_valid <= 0;
    else if (w_state == 3'd2)  // before w_state is made 0 on next negedge clk, thats why posedge clk here
        b_valid <= 1;
    else 
        b_valid <= 0;
end

assign b_response = 2'b00; // dont need this. Pull it down to zero.

// Axi Writing FSM Output Logic
always @(posedge clk)
begin
    axi_awready <= axi_awready_internal;
    axi_wready  <= axi_wready_internal;
end


// Mealy FSM
// Axi Writing FSM comb logic for next state of state "w_state"
// and outputs
  // FSM can be only in 1 state at a time
always @(negedge clk)
begin
    if (rst) 
    begin
        axi_awaddr_buff <= 0;
        axi_awready_internal <= 0;
        axi_wready_internal <= 0;
        axi_wdata_buff <= 0;
        write_flag <= 0;
        w_state <= 0;
    end else if(w_state == 0) 
    begin
        axi_awready_internal <= 1; // vs doing axi_wdata_next and giving it to axi_wdata_reg like corundum // that would need 1 more clk cycle?
        axi_wready_internal <= 1;
        write_flag <= 0;  // wont collide with assignment to 1 // write_flag will go to 1 when we have both awaddr and wdata
        axi_awaddr_buff <= 0;  // added!!!
        axi_wdata_buff <= 0;   // added!!!
        axi_wstrb_buff <= 0;   // added!!!
        if (axi_awvalid)
        begin
            axi_awaddr_buff <= axi_awaddr;
            axi_awready_internal <= 0;  //  already read the address
            w_state <= 3'd1;
            if (axi_wvalid)
            begin
                axi_wdata_buff <= axi_wdata;
                axi_wready_internal <= 0;   // read the data 
                axi_wstrb_buff <= axi_wstrb;
                write_flag <= 1; 
                w_state <= 3'd2;
            end
        end
    end else if (w_state == 3'd1)
    begin
        // axi_wdata_buff <= 0;   // added!!!
            // need this default for STATE = 0 the IDLE state!! 
                // keep wdata buff value stored till IDLE state
                // keep awdata buff value stored till IDLE state
                // keep axi_wstrb_buff value stored till IDLE state
        if (axi_wvalid)
        begin
            axi_wdata_buff <= axi_wdata;  // vs doing axi_wdata_next and giving it to axi_wdata_reg like corundum // that would need 1 more clk cycle?
            axi_wready_internal <= 0;
            axi_wstrb_buff <= axi_wstrb;
            write_flag <= 1;  // will make wr_ctrl and write_to_txmem go to 1 on negedge clk and their values will be used in the incoming posedge clk and after that in the next negedge clk the write_flag will be pulled down to 0
            w_state <= 3'd2;
        end
    end else if (w_state == 3'd2)
    begin
        if (b_ready)  
        begin                               
            w_state <= 3'd0;
            //write_flag <= 0;
        end
        // write_flag <= 0;  // get this outside the if cond above
    end
end

wire netb_sel;  // netb_sel is for rx and tx packets reception and transmission, its address range is from // 0x800000 - 0x800fff
wire net1_sel;  // net1_sel is for ctrl register its address range is from // 0x500000 - 0x50001f, from c code /&net1->n_txcmd =>  0x00500004. Read Write both. 
    
//assign netb_sel = ((wb_addr[22:18] &  5'h1f) ==  5'h08);
// chopping off last two bits of the input addresses (read and write both)
wire [29:0] axi_araddr_twobits_del;  // lower two bits chopped off for araddr
//assign axi_araddr_twobits_del = axi_araddr[31:2];
assign axi_araddr_twobits_del = axi_araddr_buff[31:2];  // using axi_araddr_buff for operation because it contains the araddr we obtained after axi handshake in axi read FSM

wire [29:0] axi_awaddr_twobits_del;  // lower two bits chopped off for awaddr
//assign axi_awaddr_twobits_del = axi_awaddr[31:2];

assign axi_awaddr_twobits_del = axi_awaddr_buff[31:2];  // using axi_awaddr_buff for operation because it contains the awaddr we obtained after axi handshake in axi write FSM

assign netb_sel = ((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h08) || ((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h08);  // for txpkt its awaddr and for rxpkt its araddr, hence OR-ing
// As seen below the 2 addressing bits removed _netbrx[21] = 1 would cause (axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h08) making netb_sel = 1
// _netbrx = 0x00800000 = 1000 0000 0000 0000 0000 0000 
    // _netbrx[23] = 1 // with 2 addressing bits removed _netbrx[21] = 1
        // if 512 words (2048 bytes , i.e., from 0 till 2047) of pkt are read, then 
            // _netbrx byte address would be (+2047 (0x7FF) words) = 0x008001FF = 1000 0000 0000 0111 1111 1111
                // The above address with 2 LSB addressing bits removed for word addressing = 10 0000 0000 0001 1111 1111
                    // The above address _netbrx[21] & _netbrx[8:0] = 1

// As seen below the 2 addressing bits removed _nettrx[21] = 1 would cause (axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h08) making netb_sel = 1
// The tx pkt byte address is _netbtx = 0x00800800 = 1000 0000 0000 1000 0000 0000, _netbtx[23] & _netbtx[11] = 1
// 2 bits removed _netbtx[21] & _netbtx[9] = 1
    // the tx pkt byte address for max byte len 2048 is (+2047 (0x7ff)) -> _netbtx = 0x00800FFF =  1000 0000 0000 1111 1111 1111, _netbtx[23] & _netbtx[11:0] = 1
    // with two bits removed word addressubg is _netbtx[21] & _netbtx[9:0] = 1



assign net1_sel = ((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h05) || ((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h05) ; // 0x500000 - 0x50001f // its for reading and writing tx, rx, mac ctrl regs and rx state value registers 
// As seen below the 2 addressing bits removed _net1[20] & _net1[18] = 1 would cause (axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h05)
    // for accessing CSRs
        // ENETPACKET *const _net1 = 0x00500000 = 0101 0000 0000 0000 0000 0000
            // _net1[22] & _net1[20] = 1 // with 2 addressing bits removed _net1[20] & _net1[18] = 1
/* 
typedef struct ENETPACKET_S {
    unsigned    n_rxcmd, n_txcmd;
    uint64_t    n_mac;  // 8 bytes unsigned or 64 bit
    unsigned    n_rxmiss, n_rxerr, n_rxcrc, n_txcol;
} ENETPACKET;

*/

// assignment of memory access flag (if any of the 4 csrs were being accessed by master axi (softcore))

// needed to add && (axi_araddr_twobits_del[1] == 0) cx csr1 and csr3 flags were going HIGH at the same time
// assign net_csr1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 0)) || 
//                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below: 
    // csr1 gives rx pkt len and rx status words // detailed desc below in block comments
    // csr1 addr is:
        // 0x20900000 after addr is normalized, 0x00900000 =  0000 0000 1001 0000 0000 0000 0000 0000  // _net_csrs->csr1[23] & _net_csrs>csr1[20] = 1
        // two LSB bits removed, _net_csrs>csr1[21] & _net_csrs>csr1[18] = 1 & _net_csrs>csr1[0] = 0
            // from verilog assign net_mem_addr = (axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[0] == 0)

// needed to add && (axi_araddr_twobits_del[1] == 0) cx csr1 and csr3 flags were going HIGH at the same time
// needed to add && (axi_araddr_twobits_del[2] == 0) since we added 4 more csrs and we need to differentiate between them
assign net_csr1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 0)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below: 
    // csr1 gives rx pkt len and rx status words // detailed desc below in block comments
    // csr1 addr is:
        // 0x20900000 after addr is normalized, 0x00900000 =  0000 0000 1001 0000 0000 0000 0000 0000 
        // _net_csrs->csr1[23] & _net_csrs>csr1[20] = 1 & _net_csrs>csr1[6] = 0 & _net_csrs>csr1[5] = 0
        // two LSB bits removed, _net_csrs>csr1[21] & _net_csrs>csr1[18] = 1 & _net_csrs>csr1[4] = 0  & _net_csrs>csr1[3] = 0 & _net_csrs>csr1[0] = 0




// assign net_csr2 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 1)) || 
//                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below: 
    // csr2 gives the rx pkt start mem addrs
    // csr2 addr is: 
        // 0x20900004 after addr is normalized, 0x00900004 =  0000 0000 1001 0000 0000 0000 0000 0100  // _net_csrs>csr2[23] & _net_csrs>csr2[20] & _net_csrs>csr2[2] = 1
            // with 2 LSB bits removed,  _net_csrs>csr2[21] & _net_csrs>csr2[18] & _net_csrs>csr2[0] = 1
                // from verilog it will be  start mem addr flag something = 
                // (((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[0] == 1))

// needed to add && (axi_araddr_twobits_del[2] == 0) since we added 4 more csrs and we need to differentiate between them
assign net_csr2 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 1)) || 
                   (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below:
    // csr2 gives the rx pkt start mem addrs
    // csr2 addr is: 
        // 0x20900004 after addr is normalized, 0x00900004 =  0000 0000 1001 0000 0000 0000 0000 0100  
        // _net_csrs>csr2[23] & _net_csrs>csr2[20] & _net_csrs>csr2[6] = 0 & _net_csrs>csr2[5] = 0 & _net_csrs>csr2[2] = 1
        // with 2 LSB bits removed,  _net_csrs>csr2[21] & _net_csrs>csr2[18] & _net_csrs>csr2[4] = 0 & _net_csrs>csr2[3] = 0  & _net_csrs>csr2[0] = 1



// assign net_csr3 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 0)) || 
//                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below: 
    // csr3 is for storing the starting mem addr for the heap mem allocated (by softcore possibly)
    // csr3 addr is: 
        // 0x20900004 after addr is normalized, 0x00900008 =  0000 0000 1001 0000 0000 0000 0000 1000  // _net_csrs>csr3[23] & _net_csrs>csr3[20] & _net_csrs>csr3[3] = 1
            // with 2 LSB bits removed,  _net_csrs>csr3[21] & _net_csrs>csr3[18] & _net_csrs>csr3[1] = 1
                // from verilog it will be  start mem addr flag something = 
                // (((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[1] == 1))

// needed to add && (axi_araddr_twobits_del[2] == 0) since we added 4 more csrs and we need to differentiate between them
assign net_csr3 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 0)) || 
                   (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below:
    // csr3 is for storing the starting mem addr for the heap mem allocated (by softcore possibly)
    // csr3 addr is: 
        // 0x20900004 after addr is normalized, 0x00900008 =  0000 0000 1001 0000 0000 0000 0000 1000  
        // _net_csrs>csr3[23] & _net_csrs>csr3[20] & _net_csrs>csr3[6] = 0 & _net_csrs>csr3[5] = 0 & _net_csrs>csr3[3] = 1
        // with 2 LSB bits removed,  _net_csrs>csr3[21] & _net_csrs>csr3[18] & _net_csrs>csr3[4] = 0 & _net_csrs>csr3[3] = 0  & _net_csrs>csr3[1] = 1



// assign net_csr4 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 1)) || 
//                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below: 
    // csr4 is for storing the allocated size for the rx pkts in memory
    // csr4 addr is: 
        // 0x2090000C after addr is normalized, 0x0090000C =  0000 0000 1001 0000 0000 0000 0000 1100  // _net_csrs>csr4[23] & _net_csrs>csr4[20] & _net_csrs>csr4[3] = 1 & _net_csrs>csr4[2] = 1
            // with 2 LSB bits removed,  _net_csrs>csr3[21] & _net_csrs>csr3[18] & _net_csrs>csr3[1] = 1 & _net_csrs>csr3[0] = 1
                // from verilog it will be  start mem addr flag something = 
                // (((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 1))

// needed to add && (axi_araddr_twobits_del[2] == 0) since we added 4 more csrs and we need to differentiate between them
assign net_csr4 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 1)) || 
                   (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below:
    // csr4 is for storing the allocated size for the rx pkts in memory
    // csr4 addr is: 
        // 0x2090000C after addr is normalized, 0x0090000C =  0000 0000 1001 0000 0000 0000 0000 1100  
        // _net_csrs>csr3[23] & _net_csrs>csr3[20] & _net_csrs>csr3[6] = 0 & _net_csrs>csr3[5] = 0 & _net_csrs>csr3[3] = 1
        // with 2 LSB bits removed,  _net_csrs>csr3[21] & _net_csrs>csr3[18] & _net_csrs>csr3[4] = 0 & _net_csrs>csr3[3] = 0  & _net_csrs>csr3[1] = 1



// needed to add && (axi_araddr_twobits_del[2] == 1) since we added 4 more csrs and we need to differentiate between them
assign net_csr5_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 1) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 0)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 1) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below:
    // csr5_tx1 is for reading if DESC_TABLE_TX is FULL. 
    // csr5_tx1 is also for writing the increment wr_ptr bit..
    // csr5_tx1 addr is: 
        // 0x20900010 after addr is normalized, 0x00900010 =  0000 0000 1001 0000 0000 0000 0001 0000  
        // _net_csrs>csr5[23] & _net_csrs>csr5[20] & _net_csrs>csr5_tx1[6] = 0 & _net_csrs>csr5[5] = 0 & _net_csrs>csr5[4] = 1
        // with 2 LSB bits removed,  _net_csrs>csr5[21] & _net_csrs>csr5[18] & _net_csrs>csr5_tx1[4] = 0 & _net_csrs>csr5[3] = 0  & _net_csrs>csr5[2] = 1



// needed to add && (axi_araddr_twobits_del[2] == 1) since we added 4 more csrs and we need to differentiate between them
assign net_csr6_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 1) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 1)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 1) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below:
    // csr6_tx1 is for writing the total available tx memory (bytes) for debugging pruposes
    // csr6_tx1 addr is: 
        // 0x20900014 after addr is normalized, 0x00900014 =  0000 0000 1001 0000 0000 0000 0001 0100  
        // _net_csrs>csr6[23] & _net_csrs>csr6[20] & _net_csrs>csr6_tx1[6] = 0 & _net_csrs>csr6[5] = 0 & _net_csrs>csr6[4] = 1 & _net_csrs>csr6[2] = 1
        // with 2 LSB bits removed,  _net_csrs>csr6[21] & _net_csrs>csr6[18] & _net_csrs>csr6_tx1[4] = 0 & _net_csrs>csr6[3] = 0  & _net_csrs>csr6[2] = 1 & _net_csrs>csr6[0] = 1



// needed to add && (axi_araddr_twobits_del[2] == 1) since we added 4 more csrs and we need to differentiate between them
assign net_csr7_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 1) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 0)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 1) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below:
    // csr7_tx1 is for reading the wr_fifo_ptr_tx_pkt_reg
    // csr7_tx1 addr is: 
        // 0x20900018 after addr is normalized, 0x0090000C =  0000 0000 1001 0000 0000 0000 0001 1000  
        // _net_csrs>csr7[23] & _net_csrs>csr7[20] & _net_csrs>csr7_tx1[6] = 0 & _net_csrs>csr7[5] = 0 & _net_csrs>csr7[4] = 1 & _net_csrs>csr7[3] = 1
        // with 2 LSB bits removed,  _net_csrs>csr7[21] & _net_csrs>csr7[18] & _net_csrs>csr7_tx1[4] = 0 & _net_csrs>csr7[3] = 0  & _net_csrs>csr7[2] = 1 & _net_csrs>csr7[1] = 1



// needed to add && (axi_araddr_twobits_del[2] == 1) since we added 4 more csrs and we need to differentiate between them
assign net_csr8_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 1) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 1)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 1) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below:
    // csr8_tx1 is for reading the rd_fifo_ptr_tx_pkt_reg
    // csr8_tx1 addr is: 
        // 0x2090001C after addr is normalized, 0x0090001C =  0000 0000 1001 0000 0000 0000 0001 1100  
        // _net_csrs>csr8[23] & _net_csrs>csr8[20] & _net_csrs>csr8_tx1[6] = 0 & _net_csrs>csr8[5] = 0 & _net_csrs>csr8[4] = 1 & _net_csrs>csr8[3] = 1 & _net_csrs>csr8[2] = 1
        // with 2 LSB bits removed,  _net_csrs>csr8[21] & _net_csrs>csr8[18] & _net_csrs>csr8_tx1[4] = 0 & _net_csrs>csr8[3] = 0  & _net_csrs>csr8[2] = 1 & _net_csrs>csr8[1] = 1 & _net_csrs>csr8[0] = 1



// csr9_tx1 is for writing tx_pkt length in bytes by riscv
assign net_csr9_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 1) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 0)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 1) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below:
    // 0x20900020 after addr is normalized, 0x0090001C =  0000 0000 1001 0000 0000 0000 0010 0000  
    // _net_csrs>csr9[23] & _net_csrs>csr9[20] & _net_csrs>csr9_tx1[6] = 0 & _net_csrs>csr9[5] = 1 & _net_csrs>csr9[4] = 0 & _net_csrs>csr9[3] = 0 & _net_csrs>csr9[2] = 0
        // with 2 LSB bits removed,  _net_csrs>csr9[21] & _net_csrs>csr9[18] & _net_csrs>csr9_tx1[4] = 0 & _net_csrs>csr9[3] = 1 & _net_csrs>csr9[2] = 0 & _net_csrs>csr9[1] = 0 & _net_csrs>csr9[0] = 0



// csr10_tx1 is for writing tx_pkt length in words by riscv
assign net_csr10_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 1) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 1)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 1) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below:
        // 0x20900024 after addr is normalized, 0x0090001C =  0000 0000 1001 0000 0000 0000 0010 0100  
        // _net_csrs>csr10[23] & _net_csrs>csr10[20] & _net_csrs>csr10_tx1[6] = 0 & _net_csrs>csr10[5] = 1 & _net_csrs>csr10[4] = 0 & _net_csrs>csr10[3] = 0 & _net_csrs>csr10[2] = 1
        // with 2 LSB bits removed,  _net_csrs>csr10[21] & _net_csrs>csr10[18] & _net_csrs>csr10_tx1[4] = 0 & _net_csrs>csr10[3] = 1 & _net_csrs>csr10[2] = 0 & _net_csrs>csr10[1] = 0 & _net_csrs>csr10[0] = 1



// csr11_tx1 is for writing the start mem address for the tx_pkt at wr_ptr by riscv
assign net_csr11_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 1) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 0)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 1) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below:
        // 0x20900028 after addr is normalized, 0x0090001C =  0000 0000 1001 0000 0000 0000 0010 1000  
        // _net_csrs>csr11[23] & _net_csrs>csr11[20] & _net_csrs>csr11_tx1[6] = 0 & _net_csrs>csr11[5] = 1 & _net_csrs>csr11[4] = 0 & _net_csrs>csr11[3] = 1 & _net_csrs>csr11[2] = 0
        // with 2 LSB bits removed,  _net_csrs>csr11[21] & _net_csrs>csr11[18] & _net_csrs>csr11_tx1[4] = 0 & _net_csrs>csr11[3] = 1 & _net_csrs>csr11[2] = 0 & _net_csrs>csr11[1] = 1 & _net_csrs>csr11[0] = 0

// csr12_tx1 is for writing the tx_pkt available bit for the tx_pkt at wr_ptr by riscv
assign net_csr12_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 1) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 1)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 1) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below:
        // 0x2090002C after addr is normalized, 0x0090001C =  0000 0000 1001 0000 0000 0000 0010 1100  
        // _net_csrs>csr12[23] & _net_csrs>csr12[20] & _net_csrs>csr12[6] = 0 & _net_csrs>csr12[5] = 1 & _net_csrs>csr12[4] = 0 & _net_csrs>csr12[3] = 1 & _net_csrs>csr12[2] = 1
        // with 2 LSB bits removed,  _net_csrs>csr12[21] & _net_csrs>csr12[18] & _net_csrs>csr12_tx1[4] = 0 & _net_csrs>csr12[3] = 1 & _net_csrs>csr12[2] = 0 & _net_csrs>csr12[1] = 1 & _net_csrs>csr12[0] = 1


// csr13_tx1 is for writing "tx_pkt_calculated_start_mem_addr_prev_wr_ptr" to network subsystem for debugging pruposes
assign net_csr13_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 1) && (axi_araddr_twobits_del[2] == 1) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 0)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 1) && (axi_awaddr_twobits_del[2] == 1) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below:
// 0x20900030 after addr is normalized, 0x00900030 =  0000 0000 1001 0000 0000 0000 0011 0000  
    // _net_csrs>csr12[23] & _net_csrs>csr12[20] & _net_csrs>csr12[6] = 0 & _net_csrs>csr12[5] = 1 & _net_csrs>csr12[4] = 1 & _net_csrs>csr12[3] = 0 & _net_csrs>csr12[2] = 0
        // with 2 LSB bits removed,  _net_csrs>csr12[21] & _net_csrs>csr12[18] & _net_csrs>csr12[4] = 0 & _net_csrs>csr12[3] = 1 & _net_csrs>csr12[2] = 1 & _net_csrs>csr12[1] = 0 & _net_csrs>csr12[0] = 0


// csr14_tx1 is for writing "tx_pkt_calculated_start_mem_addr_curr_rd_ptr" to network subsystem for debugging pruposes
assign net_csr14_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 1) && (axi_araddr_twobits_del[2] == 1) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 1)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 1) && (axi_awaddr_twobits_del[2] == 1) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below:
// csr14_tx1 addr is: 
    // 0x20900034 after addr is normalized, 0x00900034 =  0000 0000 1001 0000 0000 0000 0011 0100  
    // _net_csrs>csr12[23] & _net_csrs>csr12[20] & _net_csrs>csr12[6] = 0 & _net_csrs>csr12[5] = 1 & _net_csrs>csr12[4] = 1 & _net_csrs>csr12[3] = 0 & _net_csrs>csr12[2] = 1
        // with 2 LSB bits removed,  _net_csrs>csr12[21] & _net_csrs>csr12[18] & _net_csrs>csr12[4] = 0 & _net_csrs>csr12[3] = 1 & _net_csrs>csr12[2] = 1 & _net_csrs>csr12[1] = 0 & _net_csrs>csr12[0] = 1



// csr15_tx1 is for writing "tx_pkt_upper_limit_mem_addr" to network subsystem for debugging pruposes
assign net_csr15_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 1) && (axi_araddr_twobits_del[2] == 1) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 0)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 1) && (axi_awaddr_twobits_del[2] == 1) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below:
// csr15_tx1 addr is: 
    // 0x20900038 after addr is normalized, 0x00900038 =  0000 0000 1001 0000 0000 0000 0011 1000  
    // _net_csrs>csr12[23] & _net_csrs>csr12[20] & _net_csrs>csr12[6] = 0 & _net_csrs>csr12[5] = 1 & _net_csrs>csr12[4] = 1 & _net_csrs>csr12[3] = 1 & _net_csrs>csr12[2] = 0
        // with 2 LSB bits removed,  _net_csrs>csr12[21] & _net_csrs>csr12[18] & _net_csrs>csr12[4] = 0 & _net_csrs>csr12[3] = 1 & _net_csrs>csr12[2] = 1 & _net_csrs>csr12[1] = 1 & _net_csrs>csr12[0] = 0



// csr16_tx1 is for writing "tx_pkt_calculated_start_mem_addr_prev_wr_ptr_delta" to network subsystem for debugging pruposes
assign net_csr16_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 0) && (axi_araddr_twobits_del[3] == 1) && (axi_araddr_twobits_del[2] == 1) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 1)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 0) && (axi_awaddr_twobits_del[3] == 1) && (axi_awaddr_twobits_del[2] == 1) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below:
// csr16_tx1 addr is: 
    // 0x2090003C after addr is normalized, 0x0090003C =  0000 0000 1001 0000 0000 0000 0011 1100  
    // _net_csrs>csr12[23] & _net_csrs>csr12[20] & _net_csrs>csr12[6] = 0 & _net_csrs>csr12[5] = 1 & _net_csrs>csr12[4] = 1 & _net_csrs>csr12[3] = 1 & _net_csrs>csr12[2] = 1
        // with 2 LSB bits removed,  _net_csrs>csr12[21] & _net_csrs>csr12[18] & _net_csrs>csr12[4] = 0 & _net_csrs>csr12[3] = 1 & _net_csrs>csr12[2] = 1 & _net_csrs>csr12[1] = 1 & _net_csrs>csr12[0] = 1




// csr17_tx1 is for writing "tx_pkt_start_mem_addr" to network subsystem for debugging pruposes
assign net_csr17_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 1) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 0)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 1) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below:
// csr17_tx1 addr is: 
    // 0x20900040 after addr is normalized, 0x00900040 =  0000 0000 1001 0000 0000 0000 0100 0000  
    // _net_csrs>csr12[23] & _net_csrs>csr12[20] & _net_csrs>csr12[6] = 1 & _net_csrs>csr12[5] = 0 & _net_csrs>csr12[4] = 0 & _net_csrs>csr12[3] = 0 & _net_csrs>csr12[2] = 0
        // with 2 LSB bits removed,  _net_csrs>csr12[21] & _net_csrs>csr12[18] & _net_csrs>csr12[4] = 1 & _net_csrs>csr12[3] = 0 & _net_csrs>csr12[2] = 0 & _net_csrs>csr12[1] = 0 & _net_csrs>csr12[0] = 0



// csr18_tx1 is for writing "tx_pkt_calculated_start_mem_addr_curr_wr_ptr" to network subsystem for debugging pruposes
assign net_csr18_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 1) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 0) && (axi_araddr_twobits_del[0] == 1)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 1) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 0) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below:
// csr18_tx1 addr is: 
    // 0x20900044 after addr is normalized, 0x00900044 =  0000 0000 1001 0000 0000 0000 0100 0100  
    // _net_csrs>csr12[23] & _net_csrs>csr12[20] & _net_csrs>csr12[6] = 1 & _net_csrs>csr12[5] = 0 & _net_csrs>csr12[4] = 0 & _net_csrs>csr12[3] = 0 & _net_csrs>csr12[2] = 1
        // with 2 LSB bits removed,  _net_csrs>csr12[21] & _net_csrs>csr12[18] & _net_csrs>csr12[4] = 1 & _net_csrs>csr12[3] = 0 & _net_csrs>csr12[2] = 0 & _net_csrs>csr12[1] = 0 & _net_csrs>csr12[0] = 1



// csr19_tx1 is for writing "" to network subsystem for debugging pruposes
assign net_csr19_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 1) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 0)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 1) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 0)));
// comments from c file below:
// csr19_tx1 addr is: 
    // 0x20900048 after addr is normalized, 0x00900048 =  0000 0000 1001 0000 0000 0000 0100 1000  
    // _net_csrs>csr12[23] & _net_csrs>csr12[20] & _net_csrs>csr12[6] = 1 & _net_csrs>csr12[5] = 0 & _net_csrs>csr12[4] = 0 & _net_csrs>csr12[3] = 1 & _net_csrs>csr12[2] = 0
        // with 2 LSB bits removed,  _net_csrs>csr12[21] & _net_csrs>csr12[18] & _net_csrs>csr12[4] = 1 & _net_csrs>csr12[3] = 0 & _net_csrs>csr12[2] = 0 & _net_csrs>csr12[1] = 1 & _net_csrs>csr12[0] = 0




// csr20_tx1 is for writing "tx_pkt_calculated_start_mem_addr_curr_rd_ptr_delta" to network subsystem for debugging pruposes
assign net_csr20_tx1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[4] == 1) && (axi_araddr_twobits_del[3] == 0) && (axi_araddr_twobits_del[2] == 0) && (axi_araddr_twobits_del[1] == 1) && (axi_araddr_twobits_del[0] == 1)) || 
                    (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[4] == 1) && (axi_awaddr_twobits_del[3] == 0) && (axi_awaddr_twobits_del[2] == 0) && (axi_awaddr_twobits_del[1] == 1) && (axi_awaddr_twobits_del[0] == 1)));
// comments from c file below:
// csr20_tx1 addr is: 
    // 0x2090004C after addr is normalized, 0x0090004C =  0000 0000 1001 0000 0000 0000 0100 1100  
    // _net_csrs>csr12[23] & _net_csrs>csr12[20] & _net_csrs>csr12[6] = 1 & _net_csrs>csr12[5] = 0 & _net_csrs>csr12[4] = 0 & _net_csrs>csr12[3] = 1 & _net_csrs>csr12[2] = 1
        // with 2 LSB bits removed,  _net_csrs>csr12[21] & _net_csrs>csr12[18] & _net_csrs>csr12[4] = 1 & _net_csrs>csr12[3] = 0 & _net_csrs>csr12[2] = 0 & _net_csrs>csr12[1] = 1 & _net_csrs>csr12[0] = 1


// commenting out the mem access flags below
/*
    // mem address is being written to network subsystem from the softcore, it makes this flag net_mem_addr high 
    assign net_mem_addr = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[14] == 0)) || 
                          (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[14] == 0)));
    // static volatile unsigned *const _net_mem_addr = ((unsigned *)(0x20900000)); 
    // after addr is normalized, 0x00900000 =  0000 0000 1001 0000 0000 0000 0000 0000  // _net_mem_addr[23] & _net_mem_addr[20] = 1
        // two LSB bits removed, _net_mem_addr[21] & _net_mem_addr[18] = 1
            // ((axi_araddr_twobits_del[22:18] = 01001, 01001 & 5'h1F = 5'h09) && (axi_araddr_twobits_del[14] == 0))

    // network subsystem memory csr1 reg being accessed flag
        // Address updated in board.h file
    assign net_mem_csr1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[0] == 1)) || 
                          (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[0] == 1)));

    // previous value                   
    // assign net_mem_csr1 = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[14] == 1)) || 
    //                       (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[14] == 1)));

    assign net_alloc_mem_size = ((((axi_araddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_araddr_twobits_del[1] == 1)) || 
                          (((axi_awaddr_twobits_del[22:18] &  5'h1f) ==  5'h09) && (axi_awaddr_twobits_del[1] == 1)));
    // comments from borad.h:
        // 0x20910008 after addr is normalized, 0x00900008 =  0000 0000 1001 0001 0000 0000 0000 1000  // _net_alloc_mem_size[23] & _net_alloc_mem_size[20] & _net_alloc_mem_size[3] = 1
            // with 2 LSB bits removed,  _net_alloc_mem_size[21] & _net_alloc_mem_size[18] & _net_alloc_mem_size[1] = 1  
*/

wire [10:0] modified_reduced_axi_araddr;  // in this we first have our araddr with lower 2 bits chopped off, then we are adding netb_sel to it and we are gonna use it as our main araddr in this code 
//{ (netb_sel), wb_addr[11-2:0] } // the araddr[MAW+1] = netb_sel signal not the address signal
assign modified_reduced_axi_araddr = {(netb_sel), axi_araddr_twobits_del[9:0]}; // looking at 10 bits of word addressing, means 1024 words, i.e, 4096 bytes which is much greater than the max length of a packet that is close to 2KB, hence we wont need to look at addresses beyond this, 

// the awaddr[MAW+1] = netb_sel signal not the address signal
wire [10:0] modified_reduced_axi_awaddr;  // in this we first have our awaddr with lower 2 bits chopped off, then we are adding netb_sel to it and we are gonna use it as our main awaddr in this code 
assign modified_reduced_axi_awaddr = {(netb_sel), axi_awaddr_twobits_del[9:0]}; // looking at 10 bits of word addressing, means 1024 wirds, i.e, 4096 bytes which is much greater than the max length of a packet that is close to 2KB, hence we wont need to look at addresses beyond this                                             

wire bus_enable;
assign bus_enable = (net1_sel) || (netb_sel); 

// axi reading
wire    [8:0]   wb_memaddr;  // [8:0] 9 bits, 512 word addresses 
// reg  [4:0]   caseaddr;
wire    [4:0]   caseaddr;  // so we can use assign
reg     rx_wb_valid;
wire [31:0] w_rx_ctrl; // rx pkt control CSR register to be read by rv core
reg rx_clear = 1'b0;
reg rx_error_reg = 1'b0, rx_error_next; //s_axis_tuser

assign  wb_memaddr = modified_reduced_axi_araddr[8:0]; // // addr len is (MAW-1) i.e. 8:0, 9 bit words, 512 words = 2048 bytes which is greater than max packet len  axi reading. writeback address,  ( wb_memaddr )thats why modified_reduced_axi_araddr is used and not the modified_reduced_axi_awaddr
assign caseaddr = {modified_reduced_axi_araddr[10:9], modified_reduced_axi_araddr[2:0] };
    //assign modified_reduced_axi_araddr = {(netb_sel), axi_araddr_twobits_del[9:0]}; // looking at 10 bits of word addressing, means 1024 words, i.e, 4096 bytes which is much greater than the max length of a packet that is close to 2KB, hence we wont need to look at addresses beyond this, 

// initial begin
//     rx_clear = 1'b0;
// end
assign o_rx_int = rx_pkt_avail_bram_reg;
assign w_rx_ctrl = {
            //16 bits
            12'b0, //12 bits
            rx_pkt_avail_bram_reg&&(!rx_clear), //1bit  //(rx_valid)&&(rx_broadcast)&&(!rx_clear)
            (rx_error_reg & eth_pkt_len_error_reg), (rx_error_reg & eth_pkt_len_error_reg), (rx_error_reg& eth_pkt_len_error_reg), // 3 bits  // rx_crcerr & len error, rx_err, rx_miss,
            //16 bits
            (!rx_pkt_avail_bram_reg), (rx_pkt_avail_bram_reg)&&(!rx_clear), //2bits //rx_busy, (rx_valid)&&(!rx_clear),
            2'b0, //2bits
            rx_pkt_len_counter_reg  //12 bit // rx_pkt_len_words_counter_reg // can use this for len in terms of words, add + 1 for total words
        };

// need to keep rxmem and txmem in always clk so it is inferred as bram?



////////////////////////////////////////////////////////////////
//
// S axi_reading
//
////////////////////////////////////////////////////////////////

always @(posedge clk) begin

    if (rst) begin

        axi_rdata <= 0;

    end else begin 

        if (read_flag) begin  // will only read rx bram if the rv reads the rx ctrl reg and confirms that there is a valid rx pkt available
            if(net_csr1) begin
                axi_rdata <= csr1;
            end else if (net_csr2) begin
                axi_rdata <= csr2;
            end else if (net_csr3) begin
                axi_rdata <= csr3;
            end else if (net_csr4) begin
                axi_rdata <= csr4;
            end else if (net_csr5_tx1) begin
                axi_rdata <= csr5_tx1;
            end else if (net_csr7_tx1) begin
                axi_rdata <= csr7_tx1;
            end else if (net_csr8_tx1) begin
                axi_rdata <= csr8_tx1;
            end else begin
                axi_rdata <= 32'b0;
            end
        end

    end

end

////////////////////////////////////////////////////////////////
//
// S axi_writing & // FSM for clearing rx pkt avail fifos and incrementing rd_rxpkt_ptr
//
////////////////////////////////////////////////////////////////

// assign wr_ctrl = (write_flag) && (modified_reduced_axi_awaddr[MAW+1:MAW] == 2'b00); // MAW = 9 para replaced
assign wr_ctrl = (net1_sel) && (write_flag) && (modified_reduced_axi_awaddr[MAW+1:MAW] == 2'b00); // MAW = 9 para replaced
// wr_ctrl should be HIGH when writing to tx or rx CSR registers so ANDing net1_sel to make sure that the 
// rx and tx CSRs are being written to

assign wr_addr  = modified_reduced_axi_awaddr[2:0];
assign wr_data = axi_wdata_buff;  // the buffered from the FSM
assign wr_sel = axi_wstrb_buff;

reg             desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_flag_reg = 0;
reg             rd_fifo_ptr_rx_pkt_inc_flag_reg = 0;
reg             rd_fifo_ptr_rx_pkt_inc_flag_missed_reg = 0, rd_fifo_ptr_rx_pkt_inc_flag_missed_next;

reg  [3:0]      write_fsm_state_reg = 0, write_fsm_state_next;

localparam [3:0]
    WRITE_FSM_STATE_IDLE = 4'd0,
    WRITE_FSM_RX_PKT_AVAIL_CLR = 4'd1,
    WRITE_FSM_RX_PKT_RD_PTR_INC = 4'd2,
    WRITE_FSM_RX_PKT_RD_PTR_AVAIL_CLR_DONE = 4'd3,
    WRITE_FSM_WAIT_RX_PKT_FIFO_AVAIL_UPDATE = 4'd4;

// FSM for clearing rx pkt avail fifos and incrementing rd_rxpkt_ptr
    // Seq part
always @(posedge clk) begin
    if(rst) begin

        write_fsm_state_reg <= WRITE_FSM_STATE_IDLE;

        desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg <= 0;
        desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_reg <= 0;

        // ringbuffer fifo read pointer
        rd_fifo_ptr_rx_pkt_reg <= 0; 

        // flag to check if incrementing rd pointer happened when write fsm was in some other state than STATE_IDLE
        rd_fifo_ptr_rx_pkt_inc_flag_missed_reg <= 0;
        
    end else begin

        write_fsm_state_reg <= write_fsm_state_next;

        desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg <= desc_table_rx_pkt_avail_overwrite_rd_ptr_en_next;
        desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_reg <= desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_next;
        
        // ringbuffer fifo read pointer
        rd_fifo_ptr_rx_pkt_reg <= rd_fifo_ptr_rx_pkt_next;

        rd_fifo_ptr_rx_pkt_inc_flag_missed_reg <= rd_fifo_ptr_rx_pkt_inc_flag_missed_next;
    end

end

// FSM for clearing rx pkt avail fifos and incrementing rd_rxpkt_ptr
    // Comb part
always @* begin
    
    // default state
    write_fsm_state_next = WRITE_FSM_STATE_IDLE; 

    desc_table_rx_pkt_avail_overwrite_rd_ptr_en_next = 0;
    desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_next = 0;

    rd_fifo_ptr_rx_pkt_next = rd_fifo_ptr_rx_pkt_reg; // to save its value

    rd_fifo_ptr_rx_pkt_inc_flag_missed_next = rd_fifo_ptr_rx_pkt_inc_flag_missed_reg;

    case(write_fsm_state_reg)
        
        WRITE_FSM_STATE_IDLE: begin
            write_fsm_state_next = WRITE_FSM_STATE_IDLE;

            if(desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_flag_reg) begin
                write_fsm_state_next = WRITE_FSM_RX_PKT_AVAIL_CLR;
            end else if (rd_fifo_ptr_rx_pkt_inc_flag_reg) begin
                write_fsm_state_next = WRITE_FSM_RX_PKT_RD_PTR_INC;
            end else if(rd_fifo_ptr_rx_pkt_inc_flag_missed_next) begin
                write_fsm_state_next = WRITE_FSM_STATE_IDLE;
                rd_fifo_ptr_rx_pkt_inc_flag_missed_next = 0;

                // inc the rd ptr cx its inc was missed because it was in someother state than STATE_IDLE
                rd_fifo_ptr_rx_pkt_next = rd_fifo_ptr_rx_pkt_reg + 1;
            end
        end

        WRITE_FSM_RX_PKT_AVAIL_CLR: begin            
            //if(desc_table_rx_pkt_avail_en) begin  // if the rx pkt mem writing fsm is busy updating the avail fifo, wait till its done
            if(desc_table_rx_pkt_avail_en || desc_table_rx_pkt_len_wr_ptr_en_next || update_total_mem_used_en) begin  
                // desc_table_rx_pkt_avail_en means if the rx pkt mem writing fsm is busy updating the avail fifo, wait till its done
                // desc_table_rx_pkt_len_wr_ptr_en_next means the rx pkt mem writing is busy for 1 clk updating the total mem used 
                // and desc_table_rx_pkt_len desc table entries
                write_fsm_state_next = WRITE_FSM_WAIT_RX_PKT_FIFO_AVAIL_UPDATE;
            end else begin
                write_fsm_state_next = WRITE_FSM_RX_PKT_RD_PTR_AVAIL_CLR_DONE;  // done clearing
                desc_table_rx_pkt_avail_overwrite_rd_ptr_en_next = 1;
                desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_next = 1; 
            end

            // if rd ptr inc happened when THIS AXI-write fsm was in someother state than STATE_IDLE
            if(rd_fifo_ptr_rx_pkt_inc_flag_reg) begin 
                rd_fifo_ptr_rx_pkt_inc_flag_missed_next = 1;
            end
        end 

        WRITE_FSM_WAIT_RX_PKT_FIFO_AVAIL_UPDATE: begin 
            write_fsm_state_next = WRITE_FSM_WAIT_RX_PKT_FIFO_AVAIL_UPDATE;

            // if(!desc_table_rx_pkt_avail_en) begin
            // if ((!desc_table_rx_pkt_avail_en) || (!desc_table_rx_pkt_len_wr_ptr_en_next)) begin
                
                // shouldn't we use "&&" instead of "||" here cx we need both of these flags to be 0?

            if ((!desc_table_rx_pkt_avail_en) && (!desc_table_rx_pkt_len_wr_ptr_en_next) && (!update_total_mem_used_en)) begin
                write_fsm_state_next = WRITE_FSM_RX_PKT_RD_PTR_AVAIL_CLR_DONE;  // done clearing
                desc_table_rx_pkt_avail_overwrite_rd_ptr_en_next = 1;
                desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_next = 1; 
            end

            // if rd ptr inc happened when the write fsm was in someother state than STATE_IDLE
            if(rd_fifo_ptr_rx_pkt_inc_flag_reg) begin 
                rd_fifo_ptr_rx_pkt_inc_flag_missed_next = 1;
            end
        end

        WRITE_FSM_RX_PKT_RD_PTR_AVAIL_CLR_DONE: begin
            write_fsm_state_next = WRITE_FSM_RX_PKT_RD_PTR_AVAIL_CLR_DONE;

            if(!desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_flag_reg) begin  // the write to clear the rd ptr rx pkt avail register is complete
                write_fsm_state_next = WRITE_FSM_STATE_IDLE;
            end

            // if rd ptr inc happened when the write fsm was in someother state than STATE_IDLE
            if(rd_fifo_ptr_rx_pkt_inc_flag_reg) begin 
                rd_fifo_ptr_rx_pkt_inc_flag_missed_next = 1;
            end
        end 

        WRITE_FSM_RX_PKT_RD_PTR_INC: begin
            write_fsm_state_next = WRITE_FSM_RX_PKT_RD_PTR_INC;

            if(!rd_fifo_ptr_rx_pkt_inc_flag_reg) begin  // write was completed, checking for zero so that we dont have to worry about multiple adds
                rd_fifo_ptr_rx_pkt_next = rd_fifo_ptr_rx_pkt_reg + 1;
                write_fsm_state_next = WRITE_FSM_STATE_IDLE;
            end
        end 

    endcase
end




// ******************* IMP below ********************************
    // I can have a state machine here and delay the write response (bvalid)till this state machine is back to ide state, but that would be
    // req for complex tasks
// **************************************************************

reg rx_pkt_mem_base_addr_recvd_flag_reg;
always @(posedge clk) begin

    if(rst) begin  // rst cond is must as axi spec and overall as well
        
        // rx_clear <= 1'b0;
        mem_addr_avail_reg <= 1'b0;
        ddr_mem_addr <= 32'b0;
        rx_pkt_mem_base_addr_avail_reg <= 0;
        rx_pkt_alloc_mem_size_avail_reg <= 0;
        rx_pkt_alloc_mem_size_reg <= 0;
        rx_pkt_mem_base_addr_reg <= 0;

        desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_flag_reg <= 0;
        rd_fifo_ptr_rx_pkt_inc_flag_reg <= 0;

        rx_pkt_mem_base_addr_recvd_flag_reg <= 0;

        tx_pkt_current_available_memory_reg <= 0; 
        tx_pkt_current_available_memory_flag_reg <= 0;

        wr_fifo_ptr_tx_pkt_inc_reg <= 0;

        tx_pkt_wr_ptr_desc_table_tx_pkt_len_reg <= 0;
        tx_pkt_wr_ptr_desc_table_tx_pkt_len_en_reg <= 0;

        tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_reg <= 0;
        tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_en_reg <= 0;
        
        tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_reg <= 0;
        tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_en_reg <= 0;

        tx_pkt_wr_ptr_desc_table_tx_pkt_avail_reg <= 0;
        tx_pkt_wr_ptr_desc_table_tx_pkt_avail_en_reg <= 0;

        csr13_tx1_reg <= 0; 
        csr14_tx1_reg <= 0;
        csr15_tx1_reg <= 0;
        csr16_tx1_reg <= 0;
        csr17_tx1_reg <= 0;
        csr18_tx1_reg <= 0;
        csr19_tx1_reg <= 0;
        csr20_tx1_reg <= 0;


    end else begin

        // RX Control

        // wr_addr==3'b000 because busy bit cannot be written to (i.e., when net_selb is 1)
        /* rx clear control shifted to the mem write FSM
            if ((wr_ctrl)&&(wr_addr==3'b000)) begin // writing rx ctrl regs // RX command register
                
                if (wr_sel[1]) begin
                    rx_clear <= rx_clear || (wr_data[14]);  // ENET_RXCLR = 0x004000 = 0100 0000 0000 0000 in pkt.c, also same address for reading rx pkt available
                end

                // assuiming that rv core wr_ctrl and wr_addr will go to 0 after this access. double check it as well.

            // clear the rx_clear bit when there is no rx pkt available 
            end else if (!rx_pkt_avail_bram_reg) begin 
                rx_clear <= 1'b0;
            end
        */
        
        // rx avail rd ptr clear flag is 0 always unless it is otherwise made 1 in the if conditions below
        desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_flag_reg <= 0;
        rd_fifo_ptr_rx_pkt_inc_flag_reg <= 0;
        rx_pkt_mem_base_addr_recvd_flag_reg <= 0;

        tx_pkt_current_available_memory_flag_reg <= 0;
        wr_fifo_ptr_tx_pkt_inc_reg <= 0;

        // default value of en is 0 unless a write comes in
        tx_pkt_wr_ptr_desc_table_tx_pkt_len_en_reg <= 0;
        tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_en_reg <= 0;
        tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_en_reg <= 0;

        tx_pkt_wr_ptr_desc_table_tx_pkt_avail_reg <= 0;
        tx_pkt_wr_ptr_desc_table_tx_pkt_avail_en_reg <= 0;

        // if(net_mem_addr & write_flag) begin
        if(net_csr3 & write_flag) begin
            if(axi_wstrb_buff[0]) begin
                rx_pkt_mem_base_addr_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                rx_pkt_mem_base_addr_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                rx_pkt_mem_base_addr_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                rx_pkt_mem_base_addr_reg[31:24] <= axi_wdata_buff[31:24];
            end

            rx_pkt_mem_base_addr_avail_reg <= 1;
            rx_pkt_mem_base_addr_recvd_flag_reg <= 1;

            if(!mem_write_busy_reg) begin 
                mem_addr_avail_reg <= 1;
                // rx_pkt_mem_base_addr_avail_reg <= 1;
                // rx_pkt_alloc_mem_size_avail_reg <= 1;
                // rx_pkt_alloc_mem_size_reg <= 32'b 0100_0000_0000_0000;  // = d16384 = h0x4000 = 2^14
            end else begin
                mem_addr_avail_reg <= 0;
            end     

        // end else if(net_alloc_mem_size & write_flag) begin  // having if else instead of 2 ifs cx two writes at different addresses in parallel not possible
        end else if(net_csr4 & write_flag) begin  // having if else instead of 2 ifs cx two writes at different addresses in parallel not possible
            if(axi_wstrb_buff[0]) begin
                rx_pkt_alloc_mem_size_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                rx_pkt_alloc_mem_size_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                rx_pkt_alloc_mem_size_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                rx_pkt_alloc_mem_size_reg[31:24] <= axi_wdata_buff[31:24];
            end

            rx_pkt_alloc_mem_size_avail_reg <= 1;
        end else if(net_csr1 & write_flag) begin

            if(axi_wstrb_buff[0]) begin

                if(axi_wdata_buff[7:0] == 8'h08) begin

                    desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_flag_reg <= 1;
                    
                end else if(axi_wdata_buff[7:0] == 8'h10) begin

                    rd_fifo_ptr_rx_pkt_inc_flag_reg <= 1;

                end
            end
        end else if(net_csr6_tx1 & write_flag) begin

            // csr6_tx1 is for writing the total riscv allocated DDR available tx memory (bytes) for debugging pruposes
            if(axi_wstrb_buff[0]) begin
                tx_pkt_current_available_memory_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                tx_pkt_current_available_memory_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                tx_pkt_current_available_memory_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                tx_pkt_current_available_memory_reg[31:24] <= axi_wdata_buff[31:24];
            end

            tx_pkt_current_available_memory_flag_reg <= 1;

        end else if(net_csr5_tx1 & write_flag) begin

            if(axi_wstrb_buff[0]) begin

                // means req to increment:
                    // 1 bit flag for incrementing the wr_ptr in network subsystem (by riscv softcore)
                    // wr_fifo_ptr_tx_pkt_inc_reg,     
                if(axi_wdata_buff[7:0] == 8'h02) begin

                    wr_fifo_ptr_tx_pkt_inc_reg <= 1;
                    
                end 

            end

        end else if(net_csr9_tx1 & write_flag) begin

            // csr9_tx1 is for writing tx_pkt length in bytes by riscv
            if(axi_wstrb_buff[0]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_len_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_len_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                // ERROR out of range of prefix
                // tx_pkt_wr_ptr_desc_table_tx_pkt_len_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                // ERROR out of range of prefix
                // tx_pkt_wr_ptr_desc_table_tx_pkt_len_reg[31:24] <= axi_wdata_buff[31:24];
            end

            tx_pkt_wr_ptr_desc_table_tx_pkt_len_en_reg <= 1;

        end else if(net_csr10_tx1 & write_flag) begin

            // csr10_tx1 is for writing tx_pkt length in words by riscv
            if(axi_wstrb_buff[0]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                // ERROR out of range of prefix
                // tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                // ERROR out of range of prefix
                // tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_reg[31:24] <= axi_wdata_buff[31:24];
            end

            tx_pkt_wr_ptr_desc_table_tx_pkt_len_words_en_reg <= 1;


        end else if(net_csr11_tx1 & write_flag) begin

            // csr11_tx1 is for writing the start mem address for the tx_pkt at wr_ptr by riscv
            if(axi_wstrb_buff[0]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_reg[31:24] <= axi_wdata_buff[31:24];
            end

            tx_pkt_wr_ptr_desc_table_tx_pkt_start_mem_addr_en_reg <= 1;


        end else if(net_csr12_tx1 & write_flag) begin

            // csr12_tx1 is for writing the tx_pkt available bit for the tx_pkt at wr_ptr by riscv
            if(axi_wstrb_buff[0]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_avail_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_avail_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_avail_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                tx_pkt_wr_ptr_desc_table_tx_pkt_avail_reg[31:24] <= axi_wdata_buff[31:24];
            end

            tx_pkt_wr_ptr_desc_table_tx_pkt_avail_en_reg <= 1;


        end else if(net_csr13_tx1 & write_flag) begin

            if(axi_wstrb_buff[0]) begin
                csr13_tx1_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                csr13_tx1_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                csr13_tx1_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                csr13_tx1_reg[31:24] <= axi_wdata_buff[31:24];
            end


        end else if(net_csr14_tx1 & write_flag) begin

            if(axi_wstrb_buff[0]) begin
                csr14_tx1_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                csr14_tx1_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                csr14_tx1_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                csr14_tx1_reg[31:24] <= axi_wdata_buff[31:24];
            end

        end else if(net_csr15_tx1 & write_flag) begin

            if(axi_wstrb_buff[0]) begin
                csr15_tx1_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                csr15_tx1_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                csr15_tx1_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                csr15_tx1_reg[31:24] <= axi_wdata_buff[31:24];
            end

        end else if(net_csr16_tx1 & write_flag) begin

            if(axi_wstrb_buff[0]) begin
                csr16_tx1_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                csr16_tx1_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                csr16_tx1_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                csr16_tx1_reg[31:24] <= axi_wdata_buff[31:24];
            end

        end else if(net_csr17_tx1 & write_flag) begin

            if(axi_wstrb_buff[0]) begin
                csr17_tx1_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                csr17_tx1_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                csr17_tx1_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                csr17_tx1_reg[31:24] <= axi_wdata_buff[31:24];
            end

        end else if(net_csr18_tx1 & write_flag) begin

            if(axi_wstrb_buff[0]) begin
                csr18_tx1_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                csr18_tx1_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                csr18_tx1_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                csr18_tx1_reg[31:24] <= axi_wdata_buff[31:24];
            end

        end else if(net_csr19_tx1 & write_flag) begin        

            if(axi_wstrb_buff[0]) begin
                csr19_tx1_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                csr19_tx1_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                csr19_tx1_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                csr19_tx1_reg[31:24] <= axi_wdata_buff[31:24];
            end

        end else if(net_csr20_tx1 & write_flag) begin

            if(axi_wstrb_buff[0]) begin
                csr20_tx1_reg[7:0] <= axi_wdata_buff[7:0];
            end 

            if(axi_wstrb_buff[1]) begin
                csr20_tx1_reg[15:8] <= axi_wdata_buff[15:8];
            end 

            if(axi_wstrb_buff[2]) begin
                csr20_tx1_reg[23:16] <= axi_wdata_buff[23:16];
            end 

            if(axi_wstrb_buff[3]) begin
                csr20_tx1_reg[31:24] <= axi_wdata_buff[31:24];
            end

        end 

    end
end


// ********************************************************************************************************************************************************************
// ***************************************** TX_PKT_CSR FSM -> START **************************************************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************
reg  [3:0]      tx_pkt_csr_state_reg = 0, tx_pkt_csr_state_next;


localparam [3:0]
    TX_PKT_CSR_STATE_IDLE = 4'd0,
    TX_PKT_CSR_WR_PTR_INC = 4'd1;

always @(posedge clk) begin
    
    if (rst) begin
        
        tx_pkt_csr_state_reg <= 0;
        wr_fifo_ptr_tx_pkt_reg <= 0;

    end else begin
        
        tx_pkt_csr_state_reg <= tx_pkt_csr_state_next;
        wr_fifo_ptr_tx_pkt_reg <= wr_fifo_ptr_tx_pkt_next;

    end

end

always @(*) begin 

 tx_pkt_csr_state_next = tx_pkt_csr_state_reg;

 wr_fifo_ptr_tx_pkt_next = wr_fifo_ptr_tx_pkt_reg;
     /*
         shifting it to relevant FSM ==> (TX_PKT_CSR FSM)               
         ERROR: [DRC MDRV-1] Multiple Driver Nets: Net eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_next[0] has multiple drivers: eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_reg_inst__1/O, and eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_next_reg[0]/Q.

     */

 case(tx_pkt_csr_state_reg)

    TX_PKT_CSR_STATE_IDLE: begin 

        tx_pkt_csr_state_next = TX_PKT_CSR_STATE_IDLE;

        if (wr_fifo_ptr_tx_pkt_inc_reg) begin 

            tx_pkt_csr_state_next = TX_PKT_CSR_WR_PTR_INC;

        end  

    end 

    TX_PKT_CSR_WR_PTR_INC: begin 

        tx_pkt_csr_state_next = TX_PKT_CSR_WR_PTR_INC;

        // write was completed, checking for zero so that we dont have to worry about multiple adds
        if (!wr_fifo_ptr_tx_pkt_inc_reg) begin 

            tx_pkt_csr_state_next = TX_PKT_CSR_STATE_IDLE;

            wr_fifo_ptr_tx_pkt_next = wr_fifo_ptr_tx_pkt_reg + 1;
                /*  
                    // error wont show up since I shifted the ptr to this FSM
                    ERROR: [DRC MDRV-1] Multiple Driver Nets: Net eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_next[0] has multiple drivers: eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_reg_inst__1/O, and eth_network_interface_controller/eth_fifo_to_bram/wr_fifo_ptr_tx_pkt_next_reg[0]/Q.
                */



        end 

    end 

 endcase

end 



// ********************************************************************************************************************************************************************
// ***************************************** TX_PKT_CSR FSM -> END **************************************************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************


// FSM to transfer chosen data to memory subsystem using the mem addr provided by the softcore


// ********************************************************************************************************************************************************************
// ***************************************** RX PKT WRITING TO BRAM FSM -> START *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

// imp comment from test bench for rxpkt len
/*    # Size of arp_frame = %d bytes 60  .. = 15 words (60 bytes)
        # in wireshark the ARP len is 42.. its cx its on the same laptop because min eth packet len is 64 (60 + 4 byte crc)
            #So, arp stands for "Address Resolution Protocol", and 42 is the number of bytes comprising this ARP packet. 
            # And since 42 is less than the minimum number of bytes for an Ethernet frame, it also means that you were capturing on the same machine 
            #that sent the ARP request, in this case, 192.168.1.33.
                # for my eth module min packet len is 60 cx 4 byte crc is stripped off


        # Size of pkt_test_frame = 62 bytes 
            # I think raw frames have SFD and preamble and CRC as well
                # len of raw pkt_test_frame =74 
                    # Preamble 7 byte + SFD 1 byte + pkt_test_frame 62 bytes + CRC 4 bytes
                        # my etherner modules strips off Preamble SFD and CRC = 12 bytes
                            # so ARP frame = 42 bytes means? just counted it in wireshark, it shows 
                            # 42 bytes without Preabmle and SFD and most prob CRC
*/

// STATE_IDLE = 3'd0,
// STATE_TRANSFER_ETH_PKT_IN_BRAM = 3'd1,
// STATE_BRAM_RX_PKT_AVAIL = 3'd2, 
// STATE_RX_PKT_READING = 3'd3,
// STATE_VEBPF_RX_PKT_HDR_BRAM_FIFO_FULL = 3'd4;

// FSM to transfer one eth packet from eth axis fifo to the rx_bram here and store the packet in form of
// 4 byte words
    // initially use always* block
    // using always star but I think all the signals changing here depend opon some clk.
    // the question is what happens if signal changes on a negedge, but state_reg will get updated on
    // posedge
// I think I now know why x_next is used with x_reg. They are used When we want to use the reg values in the
// same FSM while changing those reg values in the same FSM
always @* begin  // = used for making comb cirucits as comp to seq circuits made by <=. This block uses comb.

    // default state
    state_next = STATE_IDLE; // TODO ,,, make this state_reg
    s_axis_tready_next = s_axis_tready_reg;
    read_eth_pkt_next = read_eth_pkt_reg;
    byte_to_word_ptr_next = byte_to_word_ptr_reg;
    mem_data_word_next = mem_data_word_reg;
    rx_pkt_len_words_counter_next = rx_pkt_len_words_counter_reg;
    rx_pkt_hdr_len_bytes_counter_next = rx_pkt_hdr_len_bytes_counter_reg;
    increment_rx_pkt_word_addr_next = increment_rx_pkt_word_addr_reg;
    rx_pkt_avail_bram_next = rx_pkt_avail_bram_reg;
    rx_error_next = rx_error_reg;
    transfer_in_save_next = transfer_in_save_reg;
    eth_pkt_len_error_next = eth_pkt_len_error_reg;

    // The absence of this line was causing the whole system to break. The simulation was showing
    // correct results but the hw implementation was showing faults, i.e., the rx pkt len was showing
    // garbage values. 
        // The problem was there because the hdl line below was absent, i.e., there wasn't any default state
        // condition for the rx_pkt_len_counter_next reg, and due to real fpga hw having metastability effects,
        // the FSM might have gone into the default state condition and it didn't find any default state for 
        // "rx_pkt_len_counter_next", and this can happen even during the FSM execution (i.e., when its not 
        // in idle state). So the "rx_pkt_len_counter_next" value instead of being tied to the register 
        // rx_pkt_len_counter_reg during the default FSM metastable state, would get a garbage value.
        // Hence proper coding practices like these (default state conditions).
    rx_pkt_len_counter_next = rx_pkt_len_counter_reg; // wasnt here before!
    rx_pkt_len_counter_temp_next = rx_pkt_len_counter_temp_reg;

    // default reg value
    // s_axis_tready_reg = 1'b0;

    // signals not in any case statements below also executed here"
    // rx_BRAM_empty = (!rx_pkt_avail_reg);

    // mem_data_byte_next = mem_data_byte_reg;
    // transfer_in_byte_next = transfer_in_byte_reg;

    // Write pointer for writing rx pkt hdr word to VeBPF rxpkt hdr bram fifo 
    VeBPF_rx_pkt_hdr_bram_wr_ptr_next = VeBPF_rx_pkt_hdr_bram_wr_ptr_reg;

    max_rx_pkt_hdr_word_size_next = max_rx_pkt_hdr_word_size_reg;

    rx_pkt_is_udp_next = rx_pkt_is_udp_reg;
    rx_pkt_is_tcp_next = rx_pkt_is_tcp_reg;
    rx_pkt_is_ipv4_next = rx_pkt_is_ipv4_reg;

    rx_pkt_etherType_next = rx_pkt_etherType_reg;
    rx_pkt_ipv4Protocol_next = rx_pkt_ipv4Protocol_reg;

    VeBPF_rx_pkt_hdr_data_transfer_en_next = VeBPF_rx_pkt_hdr_data_transfer_en_reg;
    // VeBPF_rx_pkt_hdr_data_transfer_en_next = 0;
        // changing this since we only need the instantaneous value of this en

    // write pointer to write rx pkt hdr size to desc table so that VeBPF data loading
    // FSM knows how much rx pkt hdr words to read from the desc table fifo
    wr_ptr_decs_table_fifo_VeBPF_rx_pkt_next = wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg;

    // enable for writing rxpkt hdr size to its desc table fifo
    desc_table_VeBPF_rx_pkt_hdr_in_words_size_en = 0; // default value is 0

    VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg;
    // VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = rx_pkt_len_words_counter_reg + VeBPF_rx_pkt_hdr_bram_wr_ptr_reg;

    VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next = VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_reg;

    VeBPF_inc_wr_ptr_flag_next = VeBPF_inc_wr_ptr_flag_reg;

    state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_next = state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_reg;

    case (state_reg)
        STATE_IDLE: begin            

            // Logic to start transferring a single eth pkt from eth axis fifo 
            /*
                if(rx_BRAM_empty) begin// rx_BRAM_empty signal goes to 1 as soon as rx pkt data is read from rx BRAM
                    s_axis_tready_next = 1'b1;  // start taking in bytes from eth axis fifo
                end else if (!rx_BRAM_empty) begin
                    s_axis_tready_next = 1'b0;
                end
            */

            // s axis tready goes to eth fifo  and data starts coming in
            // need to make sure there is valid data (s_axis_tvalid) in eth fifo first before we start 
            // filling up the rx BRAM
            /*
                if(s_axis_tready_reg & s_axis_tvalid) begin  
                    state_next = STATE_TRANSFER_ETH_PKT_IN_BRAM; //next state
                end
            */

            // no rx pkt available in rx bram as of yet
            rx_pkt_avail_bram_next = 1'b0;
            transfer_in_save_next = 1'b0;
            read_eth_pkt_next = 1'b1;
            eth_pkt_len_error_next = 1'b0;
            s_axis_tready_next = 1'b0;
            rx_error_next = 1'b0;
            increment_rx_pkt_word_addr_next = 1'b0;
             


            // resetting counters
            byte_to_word_ptr_next = 0;
            rx_pkt_len_counter_next = 0;
            // rx_pkt_len_counter_temp_next = 0;
            rx_pkt_len_words_counter_next = 0;  // this start at 0 since we need to write to bram at the 0th index, thats why we get 1 less than the total word len
            rx_pkt_hdr_len_bytes_counter_next = 0;
            
            // max_rx_pkt_hdr_word_size_next = 0;
            // max_rx_pkt_hdr_word_size_next = MAX_TCP_HDR_SIZE_IN_WORDS; // 34 words
            max_rx_pkt_hdr_word_size_next = MAX_HDR_SIZE_IN_WORDS; // TCP hdr right now but can be changed
                // reset to larger value for the next incoming rx pkt  

            // rx pkt header info for VeBPF rx pkt hdr Bram writing for next incoming rx pkt
            rx_pkt_is_udp_next = 0;
            rx_pkt_is_tcp_next = 0;
            rx_pkt_is_ipv4_next = 0;

            rx_pkt_etherType_next = 0;
            rx_pkt_ipv4Protocol_next = 0;
            VeBPF_rx_pkt_hdr_data_transfer_en_next = 0;

            VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next = 0;

            VeBPF_inc_wr_ptr_flag_next = 0;

            state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_next = 0;

            //BRAM is empty and there is valid data available in eth fifo, go to next state
                //rx_pkt_avail_bram_reg tells if there is a rx pkt in BRAM or is BRAM empty
            // not putting rx_clear here
                // since we want the FSM to read the full packet once it starts reading the pkt
                // from eth fifo. Once its done, then we'll see if rx_clear bit is set or not
                // we will discard the pkt (after reading a full pkt) if the rx_clear bit is set
            if((!rx_pkt_avail_bram_reg) & s_axis_tvalid) begin  

                // Doing this step here so that I have tready HIGH in next clk cycle
                    // and I will get on the next to next clk cycle
                // transferring packets byte by byte and shifting them to 4 byte words from 1 byte eth axis fifo
                
                s_axis_tready_next = 1'b1; // start taking in bytes from eth axis fifo
                    // reads one extra byte from eth fifo so directly changing the wire value combinatorially in the FSM
                        // NOPE. Read comments in axis fifo in windows

                state_next = STATE_TRANSFER_ETH_PKT_IN_BRAM; //next state
                transfer_in_save_next = 1'b1;
                // transfer_in_byte_next = 1; // starting saving the bytes in the next clk cycle and in the next state
            end else begin
                
                state_next = STATE_IDLE;


            end

        end

        // original FSM part below

        STATE_TRANSFER_ETH_PKT_IN_BRAM: begin

            // rx_pkt_avail_bram_reg will be 0 in STATE_IDLE state that will cause rx_clear to go to 0 when this
            // state is active in the FSM. And rx_clear is checked in when s_axis_tlast is HIGH anyway,

            //read_eth_pkt_reg has intial value 1 so it will start with transferring in eth bytes
            if (s_axis_tready && s_axis_tvalid) begin

                // transfer_in_save_next = 1'b1;  // for saving the 0th rx pkt word
                    // already made HIGH from the last state

                if (read_eth_pkt_reg) begin  // initial value is 1

                    // and 2bit word counter counting and mapping 1 byte data to 4 byte word
                    byte_to_word_ptr_next = byte_to_word_ptr_reg + 1;

                    // counter counting the incoming total eth pkt bytes 
                    rx_pkt_len_counter_next = rx_pkt_len_counter_reg + 1; 
                        // for rxpkt # 0, rx_pkt_len_counter_reg will become 1.

                    // default the word addr increment flag to 0
                    increment_rx_pkt_word_addr_next =  1'b0;

                    // do Endian Swap here, since the first byte should come at MSB of the 4 byte word
                        // but the c code of the zipversa required the 1st byte to come at LSB
                            // MemcpyLW(pkt->p_raw, (char *)_netbrx, pkt->p_rawlen);
                                // cx of this function, swapping the endian. so p_raw[0] has MSB of packet which now has been shifted to LSB of word mem_data_word_next
                    
                    // byte going into eBPF memory
                    // mem_data_byte_next = s_axis_tdata;
                    // if (s_axis_tlast) begin
                    //     transfer_in_byte_next = 0;
                    // end else begin
                    //     transfer_in_byte_next = 1;
                    // end

                    // Ethernet Type at rx pkt location 13-14 (idx = 12-13)
                        // Ethernet Type = 0x0800 for ipv4 (2 bytes)
                    if((rx_pkt_len_counter_next == 13) || (rx_pkt_len_counter_next == 14)) begin
                        // since we are using rx_pkt_len_counter_next instead of rx_pkt_len_counter_reg, thats why we are comparing it with 13-14 and not 12-13
                        if (byte_to_word_ptr_reg == 2'd0) begin  // we can use byte_to_word_ptr_next = 1 here but following the convention in the byteswap block below
                            rx_pkt_etherType_next = {s_axis_tdata, 8'd0};
                        end else if (byte_to_word_ptr_reg == 2'd1) begin
                            rx_pkt_etherType_next = rx_pkt_etherType_reg | {8'd0, s_axis_tdata};
                        end
                    
                    end

                    // ipv4 Protocol at rx pkt location 14 (ethernet hdr bytes) + 10 bytes = 24 (idx = 23)
                    if((rx_pkt_len_counter_next == 24)) begin  // since we are using rx_pkt_len_counter_next instead of rx_pkt_len_counter_reg, thats why we are comparing it with 24 and not 23
                        rx_pkt_ipv4Protocol_next = s_axis_tdata;
                    end

                    // max_rx_pkt_hdr_word_size_next will be reset to MAX_TCP_HDR_SIZE_IN_WORDS as soon as a rx pkt is received
                    // it will be changed to MAX_TCP_HDR_SIZE_IN_WORDS or MAX_UDP_HDR_SIZE_IN_WORDS as the rx pkt is being received
                    if((rx_pkt_len_counter_next > 24) && (rx_pkt_etherType_reg == ETHER_TYPE_IPV4) 
                                                        && (rx_pkt_ipv4Protocol_reg == IPV4_PROTOCOL_TCP)) begin
                        max_rx_pkt_hdr_word_size_next = MAX_TCP_HDR_SIZE_IN_WORDS; // 34 words
                    end else if ((rx_pkt_len_counter_next > 24) && (rx_pkt_etherType_reg == ETHER_TYPE_IPV4) 
                                                        && (rx_pkt_ipv4Protocol_reg == IPV4_PROTOCOL_UDP)) begin
                        max_rx_pkt_hdr_word_size_next = MAX_UDP_HDR_SIZE_IN_WORDS; // 21 words
                    end 

                    // ** IMP ** 
                    // What happens if I get a valid rx pkt whose length is lesser than max_rx_pkt_hdr_word_size_reg (134 bytes for tcp hdr and)
                    // and 82 bytes for udp hdr rx pkt.. how would VeBPF process that rx pkt 

                    if(rx_pkt_len_words_counter_reg < max_rx_pkt_hdr_word_size_reg) begin  // not using next here :O
                        // TODO: WHAT HAPPENS when the rxpkt has x words + 1 byte length and it goes out of this state before rx_pkt_len_words_counter_reg is updated?
                            // I should use rx_pkt_len_words_counter_next ?
                                // I think rx_pkt_len_words_counter_reg is correct for "rxpkt has x words + 1 byte length" since after the 1st byte of 
                                // the last word rx_pkt_len_words_counter_reg will increment to correct value 

                        // max pkt hdr word size is rounded up (34 and 21 words for tcp and udp respctively)
                            // so e.g if there are 1.5 words rounded up to 2 words... then this conditional block
                            // will have the enable_next signal HIGH for words counter idx 0 and 1 (which inclues the word # 1 and word # 0.5 after that (word # 2))
                        VeBPF_rx_pkt_hdr_data_transfer_en_next = 1;
                            
                        // calculate rxpkt hdr length in bytes  .. // will still contain extra bytes cx we are using comparison statements for words
                        rx_pkt_hdr_len_bytes_counter_next = rx_pkt_hdr_len_bytes_counter_reg + 1;
                    end else begin
                        VeBPF_rx_pkt_hdr_data_transfer_en_next = 0;
                    end

                    if(rx_pkt_len_words_counter_reg < max_rx_pkt_hdr_word_size_reg) begin
                        // TODO: WHAT HAPPENS when the rxpkt has x words + 1 byte length and it goes out of this state before rx_pkt_len_words_counter_reg is updated? 
                    // condition for VeBPF_rx_pkt_hdr_data_transfer_en_next = 1; 
                    // I.e., the condition where the rx pkt hdr words are being written to VeBPF Bram, hence the wr ptrs only need 
                    // to be incremented during that time

                        // VeBPF write ptr not rolledover 
                        if (!(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_reg)) begin
                            //TODO: after rollover happens, when should I pulldown the rollover flag cx I think it isn't going back down to 0

                            // VeBPF_Bram_wr_ptr calculation
                            VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = rx_pkt_len_words_counter_reg + VeBPF_rx_pkt_hdr_bram_wr_ptr_reg;

                            // Rollover condition for VeBPF_Bram_wr_ptr
                            if ((rx_pkt_len_words_counter_reg + VeBPF_rx_pkt_hdr_bram_wr_ptr_reg) > (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin
                                // maybe the bug is here above.. 2023_11_7_time_11_24_ILA_6_bit_ltx_fileToo bugs
                                    // so ATM the error is that VeBPF_rx_pkt_hdr_bram_wr_ptr_reg is == 136 but its max limit should have been
                                    // (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1) = 135.
                                    // there must be more errors but the first one I found is this,, there are errors causing this error so lets find it.

                                // so maybe in the if statement it should have been
                                // (rx_pkt_len_words_counter_reg - 1) instead of rx_pkt_len_words_counter_reg
                                // cx rx_pkt_len_words_counter_reg represents . NOOO cx rx_pkt_len_words_counter_reg is being used as ptr for
                                // rx_mem BRAM .. so the bug here maybe is .. leme test it on ILA then I can be sure IA


                                // TODO: test with 4 max hdr len pkts (TCP pkts atm) and see the rollover when VeBPF data loading fsm is grounded
                                // VEBPF_RX_PKT_HDR_BRAM_DEPTH = 34 words x 4 rxpkts = 136 words
                                //TODO: // WHAT HAPPENS when the rxpkt has x words + 1 byte length and it goes out of this state before rx_pkt_len_words_counter_reg is updated?

                                // FIRST 1st ROLLOVER for wr pointer for VeBPF rxpkt hdr bram fifo
                                VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = 0;
                                    // this rollover condition is correct cx we are using this _next reg above as the wr ptr for rxpkthdr BRAM
                                VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next = 1; 
                            end
                        
                        end else if (VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_reg) begin
                            
                            // VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg + 1;

                            // AHH found the bug.. Its here below.. bug happens after the rollover.. the words_counter_next increments on the same clk edge as
                            // increment_rx_pkt_word_addr_reg, where as it should increment after 1 clk edge... So fixing it below.. 
                            // Also look for similar bugs in other FSM... I saved a screenshot of the bug in simulation, you'll see after rollover happens,
                            // the alignment of ptrs like VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next & increment_rx_pkt_word_addr_reg 
                            // changes ... so look for bugs after rollover conditions in other fsms .. look at alignment changes of waveforms in simulation..
                            
                            // buggy
                            // VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg 
                            //                                                                     + increment_rx_pkt_word_addr_reg;

                            VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg 
                                                                                                + increment_rx_pkt_word_addr_reg_reg;


                            // if VeBPF Bram wr ptr has rolled over.. the wr ptr will start from 0 and will increment from 0 ...
                            // since the combined wr ptr "VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next" needs to increment after every word, hence
                            // instead of add 1 every clk cycle, we will add increment_rx_pkt_word_addr_reg, which adds after 1 whole word is inputted
                        end

                    end 

                    /*
                    // THIS IS THE OPTIMIZED VERSION OF THE FIRST 1st ROLLOVER CONDITION CODE WRITTEN BELOW THIS
                        // WILL TEST IT OUT AND IMPLEMENT IT LATER
                            // The VEBPF_RX_PKT_HDR_BRAM can take in atleast one whole rxpkt hdr so thats why we arent looking for full condition before rollover here
                    if ((rx_pkt_len_words_counter_reg + VeBPF_rx_pkt_hdr_bram_wr_ptr_reg) > (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin
                        // FIRST 1st ROLLOVER for wr pointer for VeBPF rxpkt hdr bram fifo
                        VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = 0; 
                    end else begin
                        // VeBPF_rxpkt_hdr_bram_fifo writing ptr calculation
                        VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = rx_pkt_len_words_counter_reg + VeBPF_rx_pkt_hdr_bram_wr_ptr_reg;
                    end

                    */

                    // Unoptimized version of FIRST 1st ROLLOVER condition above
                    // // VeBPF_rxpkt_hdr_bram_fifo writing ptr calculation
                    // VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = rx_pkt_len_words_counter_reg + VeBPF_rx_pkt_hdr_bram_wr_ptr_reg;
                    
                    // // FIRST 1st ROLLOVER for wr pointer for VeBPF rxpkt hdr bram fifo
                    // if (VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next > (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin
                    //     VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = 0;  // expensive operation w.r.t it being a combinatorial circuit
                    // end

                    if (ENDIAN_SWAP) begin
                        if (byte_to_word_ptr_reg == 2'd0) begin
                            mem_data_word_next = {24'b0,s_axis_tdata};  
                        end else if (byte_to_word_ptr_reg == 2'd1) begin
                            mem_data_word_next = mem_data_word_reg | {16'b0,s_axis_tdata, 8'd0};
                        end else if(byte_to_word_ptr_reg == 2'd2) begin
                            mem_data_word_next = mem_data_word_reg | {8'b0,s_axis_tdata, 16'd0};
                        end else if(byte_to_word_ptr_reg == 2'd3) begin // byte_to_word_ptr_reg will reset to 0 after this
                            mem_data_word_next = mem_data_word_reg | {s_axis_tdata, 24'd0};
                            increment_rx_pkt_word_addr_next = 1'b1;
                            // rx_pkt_len_words_counter_next = rx_pkt_len_words_counter_reg + 1;
                        end 
                    end else begin
                        if (byte_to_word_ptr_reg == 2'd0) begin
                            mem_data_word_next = {s_axis_tdata, 24'b0};
                        end else if (byte_to_word_ptr_reg == 2'd1) begin
                            mem_data_word_next = mem_data_word_reg | {8'd0, s_axis_tdata, 16'b0};
                        end else if(byte_to_word_ptr_reg == 2'd2) begin
                            mem_data_word_next = mem_data_word_reg | {16'd0, s_axis_tdata, 8'b0};
                        end else if(byte_to_word_ptr_reg == 2'd3) begin // byte_to_word_ptr_reg will reset to 0 after this
                            mem_data_word_next = mem_data_word_reg | {24'd0, s_axis_tdata};
                            increment_rx_pkt_word_addr_next = 1'b1;        
                            // rx_pkt_len_words_counter_next = rx_pkt_len_words_counter_reg + 1;
                        end                 
                    end

                    rx_error_next = rx_error_reg | s_axis_tuser;

                    if (increment_rx_pkt_word_addr_reg) begin // works perfectly fine
                        // increment the word address to write to rx pkt BRAM
                        rx_pkt_len_words_counter_next = rx_pkt_len_words_counter_reg + 1;
                        
                        // wrong .. but correctly calculates "max_rx_pkt_hdr_word_size_next" that has been assigned above
                        // if (VeBPF_rx_pkt_hdr_data_transfer_en_next) begin
                        //     rx_pkt_hdr_len_bytes_counter_next = rx_pkt_hdr_len_bytes_counter_reg + 1;
                        // end
                    
                    end

                    if (s_axis_tlast) begin
                        // read_eth_pkt_next = 1'b0;  // causing to miss last byte to be saved in bram 
                        s_axis_tready_next = 1'b0; // this module isn't ready to take in anymore eth bytes
                                                
                        // now that we have received full rx pkt, we will see if rx_clear bit is set or not
                            // if it is set, we will go back to idle state and reset, else we will proceed
                        if (rx_clear) begin
                            // rx_pkt_avail_bram_next = 1'b0; 
                                // is already 0
                            state_next = STATE_IDLE;
                                // if clear is received .. 
                                        // VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next goes back to 0 + VeBPF_rx_pkt_hdr_bram_wr_ptr_reg
                                        // instead of rx_pkt_len_words_counter_reg + VeBPF_rx_pkt_hdr_bram_wr_ptr_reg .. hence the VeBPF_rxpkt_hdr_bram_fifo
                                        // is written with the correct rx pkt hdr words at the correct ptr locations of "VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next"
                        end else begin
                        
                            // rx_pkt_avail_bram_next = 1'b1; // full rx pkt is available in bram now
                            state_next = STATE_BRAM_RX_PKT_AVAIL;

                            // enable for writing rxpkt hdr size to its desc table fifo
                            desc_table_VeBPF_rx_pkt_hdr_in_words_size_en = 1;

                            // if(rx_pkt_len_counter_reg[1:0] > 0) begin   
                            // if(rx_pkt_len_counter_next[1:0] > 0) begin  // using next here cx we are checking this condition in the same cycle   
                            // ERROR above! (NOT ERROR)
                                // not using "if(rx_pkt_len_counter_reg[1:0] > 0)" was an error.. cx next would make it a multiple of 4 if the reg was e.g, 59..
                            // if(rx_pkt_len_counter_reg[1:0] > 0) begin
                                // TODO: // WHAT HAPPENS when the rxpkt has x words + 1 byte length and it goes out of this state before rx_pkt_len_words_counter_reg is updated?
                                    // TODO -> DONE:
                            /* 
                            if(rx_pkt_len_counter_next[1:0] > 0) begin 
                                // as per simulation I will use rx_pkt_len_counter_next instead of reg for this if else block 
                                // because we need to check the rxpkt len in this state.. we are using the reg version of rxpkt len
                                // in DMA mem write FSM cx the reg gets incremented to its correct value after this state, but we dont
                                // have that luxury here........ 
                                    // but still we are getting one rxpkt word len word less for the ARP pkt... we are getting ARP word len as 14
                                    // but its 15 actually... we are starting the count of words from 0.. for first word our word len is 0 in this state..
                                    // so I guess I can add 1 for both conditions below?

                                // desc_table_VeBPF_rx_pkt_len_total_words_next = rx_pkt_len_words_counter_next + 1; // using next here cx we are checking this condition in the same cycle   
                                // desc_table_VeBPF_rx_pkt_len_total_words_next = rx_pkt_len_words_counter_next + 2; // using next here cx we are checking this condition in the same cycle   
                                desc_table_VeBPF_rx_pkt_len_total_words_next = rx_pkt_len_words_counter_next + 1; // using next here cx we are checking this condition in the same cycle   
                                // TODO: WHAT HAPPENS when the rxpkt has x words + 1 byte length and it goes out of this state before rx_pkt_len_words_counter_reg is updated?
                                    // TODO -> DONE: Adding 1 here and not 2 because rx_pkt_len_words_counter_next already has been incremented by 1
                                    // because of increment_rx_pkt_word_addr_reg being 1 for this condition.. and when we add + 1 so its acutally a +2 here..

                                // writing rx pkt length in words to the desc table
                                // this will take care of the case when e.g., there are 5 bytes of RxPkts, that means there are 2 data words (4 byte words)
                                // So this will give a value of 2 (words) to VeBPF_rx_pkt_len_total_words_reg when there are 5 bytes of RxPkts, otherwise
                                // VeBPF_rx_pkt_len_total_words_reg will be given a value of (1 word) if there are 4 byte of rx_pkt 

                            end else begin
                                // desc_table_VeBPF_rx_pkt_len_total_words_next = rx_pkt_len_words_counter_next;  // ERROR
                                desc_table_VeBPF_rx_pkt_len_total_words_next = rx_pkt_len_words_counter_next + 1;
                                // TODO: WHAT HAPPENS when the rxpkt has x words + 1 byte length and it goes out of this state before rx_pkt_len_words_counter_reg is updated?
                                // TODO -> DONE: Adding 1 here because we don't get increment_rx_pkt_word_addr_reg HIGH value to increment rx_pkt_len_words_counter_next automatically
                                // so this is actually a + 1 and the if condition above is a +2 due to increment_rx_pkt_word_addr_reg being HIGH there..
                                    // gotta check the mem writing FSM if this same error is there when rx_pkt_len_counter_next[1:0] == 0 in a simulation
                            end 
                            */

                            // This replaced the ifelse block above
                            desc_table_VeBPF_rx_pkt_len_total_words_next = rx_pkt_len_words_counter_next + 1;
                                // rx_pkt_len_words_counter_next is the ptr thats why it has 1 value less than total words

                            // THIS is for the condition when rxpkt len less than max_rx_pkt_hdr_word_size_reg (TCP or UDP hdr )
                                // If rollover happened due to this.. It will have already been taken care of in the rollover flag
                                // above
                                    // The meaning of this comment above is that we purposely are following the real len of
                                    // rxpkt if the rxpkt len is less than tcp or udp rxpkt hdr len, cx the FSM for VeBP_Mem_Write
                                    // which increments the VeBPF rd ptr, need the real len of rxpkt hdr ....                            
                            if (desc_table_VeBPF_rx_pkt_len_total_words_next < max_rx_pkt_hdr_word_size_reg) begin

                                max_rx_pkt_hdr_word_size_next = desc_table_VeBPF_rx_pkt_len_total_words_next;

                                if (byte_to_word_ptr_reg == 0) begin
                                    // this condition is catering for when one byte is receieved and the wrptr has rolled over
                                    // at that point this byte isn't stored in the BRAM and the wrptr doesnt increase after that as well 
                                    // Also not including & wrptr_rollover cond cx even if its not rollingover and desc_table_VeBPF_rx_pkt_len_total_words_next < max_rx_pkt_hdr_word_size_reg
                                    // the last byte/word isn't written .. hence in the transient state we will write the last word and inc the wr ptr


                                    state_next = STATE_TRANSFER_ETH_PKT_IN_BRAM_TRANSIENT;

                                    state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_next = 1;

                                end 

                            end
                        
                        end 

                    end else begin
                        // read_eth_pkt_next = 1'b1; // keep taking in eth bytes until last byte of eth pkt 
                        state_next = STATE_TRANSFER_ETH_PKT_IN_BRAM;
                    end


                    if((rx_pkt_len_words_counter_reg > 512) || (rx_pkt_len_counter_reg > 2048) || (byte_to_word_ptr_reg > 3)) begin
                        eth_pkt_len_error_next = 1'b1;
                    end else begin
                        eth_pkt_len_error_next = 1'b0;
                    end

                // should check for error in s_axis_tuser (this is error bit in ethernet module), and go back to state_idle if there is an error
                end else begin

                     state_next = STATE_TRANSFER_ETH_PKT_IN_BRAM;
                end
                // read_eth_pkt_next = 1'b1;  // keep taking in eth bytes until last byte of eth pkt 

            end else begin

                state_next = STATE_TRANSFER_ETH_PKT_IN_BRAM;
                // if there is no "s_axis_tvalid" i.e., no valid eth pkt data, then stay in this state
                    // and don't increment the counters
                // transfer_in_save = 1'b0;  // using both to see their respective reactions
                
                // default the word addr increment flag to 0
                increment_rx_pkt_word_addr_next = 1'b0;
                
                //read_eth_pkt_next = 1'b0;  

            end     
        end

        STATE_TRANSFER_ETH_PKT_IN_BRAM_TRANSIENT: begin

            state_next = STATE_BRAM_RX_PKT_AVAIL;

            // increment the write ptr
            VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next = VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg + 1;

            // transfer this word to rxpkthdr BRAM
            VeBPF_rx_pkt_hdr_data_transfer_en_next = 1;

            // pulldown flag
            state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_next = 0;

        end 

        STATE_BRAM_RX_PKT_AVAIL: begin
            // FSM in this state will wait for the rv to start reading the rx pkt from
            // the rx bram.

            state_next = STATE_BRAM_RX_PKT_AVAIL; 
                // deeper if statements have higher precedence 

            // Will just mointor the axi arddr and get a certain flag HIGH which will enable the RV
            // to read from the rx mem bram
            transfer_in_save_next = 1'b0;
            read_eth_pkt_next = 1'b0;

            if (!transfer_in_save_reg) begin
                VeBPF_rx_pkt_hdr_data_transfer_en_next = 0;
                    // need this flag to be HIGH for 1 clk cycle only so that correct len of rxpkt_hdr_bytes can be saved 
                    // which get updated to correct value during the 1st clk cycle here and we need to disable this flag
                    // after 1 clk cycle cx the wr_ptr is incrementing after 1st clk cycle and we don't want to overwrite 
                    // unread desc_table values where the wr_ptr is incrementing to.
            end 
            // rx_pkt_avail_bram_next = 1'b1; // full rx pkt is available in bram now
                // moved to VeBPF_inc_wr_ptr_flag_reg
            
            // if (read_flag & (caseaddr[4:3] == 2'b10) & (!rx_clear)) begin  // error here. I had written caseaddr[5:4]
            //     state_next = STATE_RX_PKT_READING;  // stay in the next state till rx_clear is set to 1
            // end else if (rx_clear) begin  // if else precedence, check rx_clear first           

            if ((!VeBPF_inc_wr_ptr_flag_reg)) begin
                VeBPF_inc_wr_ptr_flag_next = 1;
                rx_pkt_avail_bram_next = 1'b1; // full rx pkt is available in bram now

                // increment the desc table VeBPF wr ptr 
                wr_ptr_decs_table_fifo_VeBPF_rx_pkt_next = wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg + 1;
                    // move this to rx pkt writing to bram state (STATE_TRANSFER_ETH_PKT_IN_BRAM), so that the VeBPF FSM can start 
                    // transferring the rxpkt hdr data to VeBPF in parallel and start the VeBPF processing in parallel (Pipelining


                // !! imp: don't need to check VeBPF_rx_pkt_hdr_bram_fifo_FULL flag here cx it won't be checked cx
                // VeBPF_inc_wr_ptr_flag_reg flag will flip after 1 clk cycle and the VeBPF_rx_pkt_hdr_bram_fifo_FULL flag
                // need 1 clk cycle to get updated cx wr ptr wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg updates its reg after 1 clk
                // thats why we are moving checking the VeBPF_rx_pkt_hdr_bram_fifo_FULL flag below after rxpkt avail bit is cleared  

                /*// VeBPF_rxpkt_hdr_bram is not FULL
                    // This is the SECOND 2nd rollover condition for wrptr of rxpkt_hdr_bram_fifo
                if(!VeBPF_rx_pkt_hdr_bram_fifo_FULL) begin
                    // TODO -> DONE: error here
                        // VeBPF_rx_pkt_hdr_bram_fifo_FULL FSM uses reg versions of the wr ptrs. so it means it depends on
                        // value allocated to wr_ptr_decs_table_fifo_VeBPF_rx_pkt_next in the previous cycle
                    
                    // increment the write pointer for the VeBPF rxpkt hdr bram fifo by
                    // the number of rxpkt hdr words written to the VeBPF rxpkt hdr bram fifo, that size of rxpkt_hdr
                    // has been saved in max_rx_pkt_hdr_word_size_reg
                        // but this condition should happen only when VeBPF rxpkt hdr bram fifo is not FULL!*/

                if (!(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_reg)) begin 
                
                    VeBPF_rx_pkt_hdr_bram_wr_ptr_next = VeBPF_rx_pkt_hdr_bram_wr_ptr_reg + max_rx_pkt_hdr_word_size_reg;
                        // WHAT IF RXPKT is less than max rxpkt hdr word size? Need to increment the wr ptr by number of
                        // words written to VeBPF BRAM.
                            // Even if above condition (written in comment) is true........ lets say we still increment
                            // by max rx pkt hdr word size ... WHILE THE ROLLOVER FLAG WAS NOT SET... means that 
                            // the rx pkt was smaller than the max_rx_pkt_hdr_word_size_reg.. but since the rollover flag
                            // was not set, we will check it here that does adding max_rx_pkt_hdr_word_size_reg to wr ptr
                            // cause a rollover.. then we reset the wr ptr to 0 cx it wasn't rolled over while taking in
                            // the rx pkt words... the question here now is ... how will the V rd ptr know this? Lets check 
                                // so the rd ptr chases the max_rx_pkt_hdr_word_size_reg to its full length due to this condition
                                // "VeBPF_rx_pkt_len_words_counter_reg < (VeBPF_rx_pkt_len_total_words_reg)" .... so we cant just
                                // reset the wr ptr to 0 if adding max_rx_pkt_hdr_word_size_reg causes wr ptr to be > VBramDepth
                                    // So I should add the correct lenght of rx pkt words len if its is less than max_rx_pkt_hdr_word_size_reg
                                        // took care of this s_tlast block above
                    
                    // //Rollover condition
                    // // if(VeBPF_rx_pkt_hdr_bram_wr_ptr_reg == (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin
                    // if(VeBPF_rx_pkt_hdr_bram_wr_ptr_reg >= (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin
                    //     // if wr_ptr is at the limit of the bram depth then make wr_ptr_next equal to 0 so in essense
                    //     // the fifo rolls over back to 0 for the wr_ptr
                    //     VeBPF_rx_pkt_hdr_bram_wr_ptr_next = 0;
                    // end
                
                end else if (VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_reg) begin

                    // no this is buggy
                    // VeBPF_rx_pkt_hdr_bram_wr_ptr_next = VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg;

                    // buggy.. dont need the + 1 here... since it was already added after rollover based on the if condition it is in
                        // this isn't buggy
                    VeBPF_rx_pkt_hdr_bram_wr_ptr_next = VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg + 1;
                        // VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg was rolled over to 0 and incremented per word from there
                        // and + 1 to start writing from this position. the next rx pkt hdr

                        // so I thought through this and this allocation is correct.. cx the allocation that we are doing above as follows
                        // VeBPF_rx_pkt_hdr_bram_wr_ptr_next = VeBPF_rx_pkt_hdr_bram_wr_ptr_reg + max_rx_pkt_hdr_word_size_reg
                        // is updating the bram wr ptr after accumulating the value of the rxpkthdr in max_rx_pkt_hdr_word_size_reg,
                        // but we don't need to that for this condition above because we have passed/ROLLED OVER the top/end of the 
                        // bram /ring buffer and we continuously count the rxpkthdr "hdr only" words coming after ROLLING over
                        // so after we are finished receving the rxpkt in the prev state, this reg VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg
                        // has been continuously accumulating the rxpkthdr len values, so we can just add 1 (more word) to the wr ptr VeBPF_rx_pkt_hdr_bram_wr_ptr_next
                        // so that when the next rxpkt is received, it starts uploading into VeBPF_rx_pkt_hdr_bram_wr_ptr_reg + 0 word index location in rxpkthdr BRAM

                        // we will also reset the bram wr ptr roll over flag since the rolling over has reset the value of rxpkthdr wr ptr bram
                        // VeBPF_rx_pkt_hdr_bram_wr_ptr_reg within this if condition above    
                    VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next = 0;

                    // TODO -> done : test this.. dont need this.. sorry NEED to do this, need to add 2 instead of 1 since one addition to ptr is missed
                    // when pktlen is less than UDP hdr len since the increment_rx_pkt_word_addr_reg_reg doesnt get a chance to get added to wr ptr VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg

                    // don't need this below since I made a new state for it and fixed the issue.. The solution below was still buggy
                    // if(state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_reg) begin 

                    //     VeBPF_rx_pkt_hdr_bram_wr_ptr_next = VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg + 2; 

                    //     state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_next = 0;

                    // end 

                end

                /*// VeBPF_rxpkt_hdr_bram is FULL
                end else if (VeBPF_rx_pkt_hdr_bram_fifo_FULL) begin
                    
                    state_next = STATE_VEBPF_RX_PKT_HDR_BRAM_FIFO_FULL;
                    // This will take priority since it comes first?

                end  */

            end  else if (VeBPF_inc_wr_ptr_flag_reg) begin
                // look for clear bit once VeBPF wr ptrs have incremented

                // rx clear bit condition block only available here..
                // If cleared, rx clear will remain 1 until is checked
                // here in this block below.. rx clear will become 0 when 
                // rx_pkt_avail_bram_next becomes 0..
                if (rx_clear) begin
                
                    rx_pkt_avail_bram_next = 1'b0;

                    if(!VeBPF_rx_pkt_hdr_bram_fifo_FULL) begin
            
                        state_next = STATE_IDLE;
                    
                    end else begin
                        
                        state_next = STATE_VEBPF_RX_PKT_HDR_BRAM_FIFO_FULL;    

                    end

                end else begin

                    state_next = STATE_BRAM_RX_PKT_AVAIL;  // stay in the same state

                end

            end

        end 

        STATE_VEBPF_RX_PKT_HDR_BRAM_FIFO_FULL: begin

            if(VeBPF_rx_pkt_hdr_bram_fifo_FULL) begin  // if VeBPF_rxpkt_hdr_bram is still FULL
                // TODO -> DONE: Error here... Increamenting wr ptr when we go back to STATE_BRAM_RX_PKT_AVAIL in 
                // this state and in STATE_BRAM_RX_PKT_AVAIL   
                
                state_next = STATE_VEBPF_RX_PKT_HDR_BRAM_FIFO_FULL;

            end else begin
                
                // wr ptr is incrementing in STATE_BRAM_RX_PKT_AVAIL so I think I don't need to increment the wr ptr here
                // TODO -> DONE: test the statement above in simulation 

                /*// rollover condition check for incrementing write flag
                if (!(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_reg)) begin 
                
                    VeBPF_rx_pkt_hdr_bram_wr_ptr_next = VeBPF_rx_pkt_hdr_bram_wr_ptr_reg + max_rx_pkt_hdr_word_size_reg;
                
                end else if (VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_reg) begin

                    VeBPF_rx_pkt_hdr_bram_wr_ptr_next = VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg + 1;
                        // VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg was rolled over to 0 and incremented per word from there
                        // and + 1 to start writing from this position. the next rx pkt hdr
                end*/
                
                state_next = STATE_IDLE;
                    // need to go to idle state and wait for the next rxpkt cx we have space for it in rxpkthdr bram now
                // state_next = STATE_BRAM_RX_PKT_AVAIL;


            end

        end 

        STATE_RX_PKT_READING: begin

            // here rx_clear will server as the flag to tell the module that reading has been done
            // go back to STATE_IDLE now
                // rv core will write rx_clear = 1'b1 after reading the full packet. rx_clear will go to 1'b0 when rx_pkt_avail_bram_reg becomes 1'b0 in STATE_IDLE

            if(rx_clear) begin  // rx_clear will be reset to 1'b0 when rx_pkt_avail_bram_reg becomes 1'b0 in STATE_IDLE
                rx_pkt_avail_bram_next = 1'b0;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_RX_PKT_READING;
            end
        end 

        // this was causing an error, making the state go back to STATE_IDLE after every next clk tick.
        // There werent any errors after uncommenting this but still will keep this commented since 
        // there was an error in the beginning with this default case included and the corumdum code 
        // isnt using this. Hence we will keep this commented. 
            // so what I found is that I was using two default state conditions. One above state_next = STATE_IDLE; 
            // and one here below.
        // default: begin  
        //     state_next = STATE_IDLE;

        // end
    endcase
end


// Seq logic for the FSM
always @(posedge clk) begin

    if(rst) begin

        state_reg <= STATE_IDLE;
        s_axis_tready_reg <= 1'b0;
        read_eth_pkt_reg <= 1'b1;  // reset value is 1
        byte_to_word_ptr_reg <= 0;
        rx_pkt_len_counter_reg <= 0;
        mem_data_word_reg <= 0;
        rx_pkt_len_words_counter_reg <= 0;
        // rx_pkt_len_counter_words_temp_reg <= 0;
        rx_pkt_hdr_len_bytes_counter_reg <= 0;
        
        increment_rx_pkt_word_addr_reg <= 1'b0;
        increment_rx_pkt_word_addr_reg_reg <= 1'b0;
        
        rx_pkt_avail_bram_reg <= 1'b0;
        rx_error_reg <= 1'b0;
        transfer_in_save_reg <= 1'b0;
        eth_pkt_len_error_reg <= 1'b0;
        // rx_clear <= 1'b0;
        // mem_data_byte_reg <= 0;
        // transfer_in_byte_reg <= 0;

        VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg <= 0;
        VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_reg <= 0;
        VeBPF_inc_wr_ptr_flag_reg <= 0;
        state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_reg <= 0;

    end else begin

        state_reg <= state_next;
        s_axis_tready_reg <= s_axis_tready_next;
        read_eth_pkt_reg <= read_eth_pkt_next;
        byte_to_word_ptr_reg <= byte_to_word_ptr_next;
        rx_pkt_len_counter_reg <= rx_pkt_len_counter_next;
        mem_data_word_reg <= mem_data_word_next;
        rx_pkt_len_words_counter_reg <= rx_pkt_len_words_counter_next;
        // rx_pkt_len_counter_words_temp_reg <= rx_pkt_len_words_counter_reg + 1;
        rx_pkt_hdr_len_bytes_counter_reg <= rx_pkt_hdr_len_bytes_counter_next;

        increment_rx_pkt_word_addr_reg <= increment_rx_pkt_word_addr_next;
        increment_rx_pkt_word_addr_reg_reg <= increment_rx_pkt_word_addr_reg;
            // 1 clk delayed increment_rx_pkt_word_addr_reg

        rx_pkt_avail_bram_reg <= rx_pkt_avail_bram_next;
        rx_error_reg <= rx_error_next;
        transfer_in_save_reg <= transfer_in_save_next;
        eth_pkt_len_error_reg <= eth_pkt_len_error_next;
        // mem_data_byte_reg <= mem_data_byte_next;
        // transfer_in_byte_reg <= transfer_in_byte_next;

        VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg <= VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next;

        VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_reg <= VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next;
        VeBPF_inc_wr_ptr_flag_reg <= VeBPF_inc_wr_ptr_flag_next;
        state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_reg <= state_reg_fsm_pkt_len_less_than_UDP_hdr_flag_next;
        
    end

    // this condition, so that no garbage values are written to rx mem
    // if (read_eth_pkt_reg & transfer_in_save & (!rx_clear)) begin  
    //     rx_mem[rx_pkt_len_words_counter_reg] <= mem_data_word_reg;
    // end

end


// this statment below infers a BRAM
// (* ramstyle = "no_rw_check" *)
// reg [RV_DATA_WIDTH-1:0] VeBPF_rx_mem[RX_TX_PKT_BRAM_DEPTH-1:0]; // 512 x 32 bits = 2048 bytes = 2KB which is the max packet size
    // having multiple brams cx rx_mem is being read elsewhere

integer i2;

always @(posedge clk) begin  // block for reading rx pkts in rx_mem bram

    if (rst) begin

        // NEED TO COMMENT OUT ALL MEMORY INITIALIZATIONS TO 0 BECAUSE THEY WERE CAUSING INSANE AMOUNT OF EXTRA WIRE CONNECTIONS making it IMPOSSIBLE
        // for the PLACE AND ROUTE TOOL TO ROUTE ALL THE WIRES AND IMPLEMENT THE BITSTREAM (FAILED IN THE IMPLEMENTATION AND BITSTREAM GEN STAGE)

        // if (SIMULATION == 1) begin
        //    for (i2 = 0; i2 < RX_TX_PKT_BRAM_DEPTH; i2 = i2 + 1) begin
                
        //        rx_mem[i2] <= 0;
        //        // VeBPF_rx_mem[i2] <= 0;

        //    end
        // end

    end else begin 

        // this condition, so that no garbage values are written to rx mem
        if (read_eth_pkt_reg & transfer_in_save_reg & (!rx_clear)) begin  
            
            rx_mem[rx_pkt_len_words_counter_reg] <= mem_data_word_reg;
                // so I wasn't clear if the rxpkt had x words + 1 byte length, how would
                // "rx_pkt_len_words_counter_reg" cover that.. it wasn't happeneing in the STATE_TRANSFER_ETH_PKT_IN_BRAM state
                // cx 1 more clk cycle was need.. so I noticed that transfer_in_save_reg and read_eth_pkt_reg were valid for 
                // 1 more clk cycle cx their _next counterpart was being pulled down to 0 in the next state of STATE_BRAM_RX_PKT_AVAIL
                // and that required 1 clk cycle for the reg version of transfer_in_save_regand read_eth_pkt_reg to become 0, which
                // gives rx_pkt_len_words_counter_reg 1 clk cycle to update and have the "mem_data_word_reg" rxpkt word written
                // to the correct pointer value.
            
            // dont need this bram for rxpkt for VeBPF anymore
            // VeBPF_rx_mem[rx_pkt_len_words_counter_reg] <= mem_data_word_reg;

            // if(transfer_in_byte_reg) begin
            //     eBPF_1_bram[rx_pkt_len_counter_reg] <= mem_data_byte_next;  // replacing with next since they data was lagging by 1 count
            //     eBPF_2_bram[rx_pkt_len_counter_reg] <= mem_data_byte_next;
            //     eBPF_3_bram[rx_pkt_len_counter_reg] <= mem_data_byte_next;
            //     eBPF_4_bram[rx_pkt_len_counter_reg] <= mem_data_byte_next;
            // end

        end

        if (VeBPF_rx_pkt_hdr_data_transfer_en_next) begin  
        // (INCORRECT) using reg (and not next) cx I need idx 0 for bram writing in the len words counter .. 
        // so using enable reg for that then as well.. but enable reg will become when rx pkt len words counter reg becomes 1 :O
            // (CORRECT1) now using VeBPF_rx_pkt_hdr_data_transfer_en_next instead of reg cx I will have rx_pkt_len_words_counter_reg = 0
            //  (Correction2): The correction1 doesnt apply cx we are using words counter and not len in bytes counter, butt still
            // this expressions seems okay cx it stops loading rxpkt hdrs once rxpkt_len_words counter becomes equal to the rxpkt hdr len in words

            // bram fifo writing
            // VeBPF_rx_pkt_hdr_bram_fifo[rx_pkt_len_words_counter_reg+VeBPF_rx_pkt_hdr_bram_wr_ptr_reg] <= mem_data_word_reg;

            // replacing idices writing to VeBPF rxpkt hdr bram fifo 
            // VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter = rx_pkt_len_words_counter_reg+VeBPF_rx_pkt_hdr_bram_wr_ptr_reg
            
            // bram fifo writing
                // using next instead of reg cx we need the updated poiter value ROLLEDover (if rolledover) in the same clk cycle
            VeBPF_rx_pkt_hdr_bram_fifo[VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next] <= mem_data_word_reg;
            // ideally for the 1st rx pkt hdr word, rx_pkt_len_words_counter_reg should write up till either 0-33 or 0-20 for udp or tcp respectively for next rx pkt hdr
            // VeBPF_rx_pkt_hdr_bram_wr_ptr_reg = 0 for 1st rx pkt hdr word.. VeBPF_rx_pkt_hdr_bram_wr_ptr_reg will become = 34/21 for udp/tcp respectively for the next rx pkt hdr
                // I can see for rxpkts of diff lens, their len & hdr checksum field of IP hdr is diff.. cool

        end

        // update desc_table_VeBPF_rx_pkt_hdr_in_words_size entry
        //if(desc_table_VeBPF_rx_pkt_hdr_in_words_size_en) begin  // incorrect
        if(VeBPF_rx_pkt_hdr_data_transfer_en_next) begin
            // VeBPF_rx_pkt_hdr_data_transfer_en_next stays 1 till state goes to IDLE ... hence the update to max_rx_pkt_hdr_word_size_reg
            // that happens if rx pkt len is < max_rx_pkt_hdr_word_size_reg 
            
            desc_table_VeBPF_rx_pkt_hdr_in_words_size[
                wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= max_rx_pkt_hdr_word_size_next;  // next here for correction 
                    // for smaller packet like ARP to get updated in time for the VeBPF data writing FSM to pick the correct value

                // wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= max_rx_pkt_hdr_word_size_reg;  // correction X INCORRECT
                    // we have a BUG here.. TODO -> DONE: BUG here... -> FIXED
                    // for ARP packet whose whole rx pkt size is coming out to be 14 words .. it is being stored as 14 words here.. instead of UDP or TCP hdr size..
                    // comments in the comb FSM (so it is correct that the real len of rxpkt is being added when its less than either tcp or UDP hdr word len
                    // but its coming out to be 1 less than the total words for ARP rx pkt):   
                        // so the rd ptr chases the max_rx_pkt_hdr_word_size_reg to its full length due to this condition
                        // "VeBPF_rx_pkt_len_words_counter_reg < (VeBPF_rx_pkt_len_total_words_reg)" .... so we cant just
                        // reset the wr ptr to 0 if adding max_rx_pkt_hdr_word_size_reg causes wr ptr to be > VBramDepth
                            // So I should add the correct lenght of rx pkt words len if its is less than max_rx_pkt_hdr_word_size_reg
                                // took care of this s_tlast block above

                // wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= desc_table_VeBPF_rx_pkt_len_total_words_next;  // incorrect
                
                // no need to check full or empty fifo based on the ptr wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg and its rd counterpart cx the
                // DDR rxpkt DMA writing FSM is taking care of that if desc table if full or not, then it will clear the rx pkt avail bit for more rx pkt streaming in this module 
                    // though I might need to check the empty flag of this fifo for the VeBPF FSM when it is writing the rx pkts hdrs to its data memory

                // also for smaller rkt pkts like ARP pkts whose rxpkt size is 14 words (56 bytes)... should be 15 words right? For min rx pkt size req of 60 bytes
                // so even if I am hardcoding the rxpkt hdr size in words for ARP to 21 words as well, then will there be XXXX in memory where data hasn't been written
                // yet and would that cause an error to pop up in the VeBPF calculation? 

            // saving the bytes size
                // redundant fifo but it should have been initially implemented here
            desc_table_VeBPF_rx_pkt_hdr_in_bytes_size[
                wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= rx_pkt_hdr_len_bytes_counter_reg; // correction, changed to reg to reduce extra byte
                // wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= rx_pkt_hdr_len_bytes_counter_next; // incorrect, 1 extra byte being added 
                // wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] <= rx_pkt_len_counter_next; // Incorrect 
                // TODO: comment out for synthesis

            // wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg wr ptr should ideally be checked for if bram FIFO full condition has been reached and it is
            // being checked in this FSM by looking at the flag "VeBPF_rx_pkt_hdr_bram_fifo_FULL", but even if it wasn't check, it wouldnt have mattered
            // cx we have instantiated the "VeBPF_rx_pkt_hdr_bram_fifo" with a depth of desc table depth x max_rx_hdr_len, and the "DDR_WRITING_RXPKTS FSM" 
            // will only take in those numbers of rxpkts that can fit into the desc table here, which would then also fit into the "VeBPF_rx_pkt_hdr_bram_fifo".

            // The subsystem reading the rxpkts and its metadata will only clear the desc table row entry after it sees that the VeBPF has done processing that
            // particular rxpkt and that its VeBPF processing done bit is HIGH, so after that bit is cleared, the "DDR_WRITING_RXPKTS FSM" will increment its rd pointer
            // which will cause more rx pkts to come in if desctable was previously FULL, but that only happens after VeBPF processing done bit is HIGH is checked by
            // the rxpkts reading subsystem which means that the rd pointers for desc table entries of desctable rxpkt len/word len and the rd ptrs for 
            // VeBPF rxpkt hdr bram fifo were incremented cx the VeBPF consumed them, meanining that those fifos were not full anymore as well and hence more rxpkts
            // can be streamed into this module.

        end


    end
end

// ********************************************************************************************************************************************************************
// ***************************************** RX PKT WRITING TO BRAM FSM -> END *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

// ********************************************************************************************************************************************************************
// ***************************************** VeBPF RULES SCHEDULER FSM -> start *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************
    // one use of this FSM and BRAM FIFO for vebpg rules here is that I can initialize the memory inside BRAMs using "mem.init" file
    // in the SYNTHESIZED design.. 
    // I can also use initial block or another "mem2.init" to initialize rules scheduler table BRAMs as well in the SYNTHESIZED design


localparam [3:0]
    VEBPF_RULES_SCHEDULER_FSM_STATE_IDLE = 4'd0,
    VEBPF_RULES_SCHEDULER_FSM_STATE_ERROR = 4'd15,
    VEBPF_RULES_SCHEDULER_FSM_STATE_WRITING_PROG_TO_RULES_FIFO = 4'd1,
    VEBPF_RULES_SCHEDULER_FSM_STATE_WAITING_FOR_NEXT_PROG_WORD = 4'd2,
    VEBPF_RULES_SCHEDULER_FSM_STATE_RULE_WRITING_DONE = 4'd3,
    VEBPF_RULES_SCHEDULER_FSM_STATE_NEXT_RULE_INCOMING = 4'd4,
        // will need a swtich toggle or something to give a sign that another rule is going to get uploaded..
        // so monitor switch toggle or somthing like that here
    VEBPF_RULES_SCHEDULER_FSM_STATE_RULES_LOADED_TO_FIFO_START_UPLOADING_TO_VEBPF = 4'd5,
        // will need to make another FSM to take rules from the rules_fifo and upload them into the VeBPF filter one by one
    VEBPF_RULES_SCHEDULER_FSM_STATE_LOADING_RULES_LEN_FIFO_STRT_PTR = 4'd6,
    VEBPF_RULES_SCHEDULER_FSM_STATE_LOADING_RULES_PGM_DATA = 4'd8,
    VEBPF_RULES_SCHEDULER_FSM_STATE_UPLOADING_RULES_DW_TO_VEBPF_PGM_DATA = 4'd9,
    VEBPF_RULES_SCHEDULER_FSM_STATE_ALL_RULES_UPLOADED_TO_VEBPF = 4'd10,
    VEBPF_RULES_SCHEDULER_FSM_STATE_RESET_COUNTERS_FOR_NEW_RULES_SET = 4'd11;

// okay so when VeBPF_prog_write_enable_in is HIGH we have VeBPF_prog_addr_in and VeBPF_prog_data_in both available..
// but do we need VeBPF_prog_addr_in?? 
// Also both data and address lines have the data latched till the next payload of prog data is fully available..
// but I will still latch the data and address lines as soon as they become vailable


localparam VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH = VEBPF_PROG_ADDRESS_WIDTH; //12;  // for VeBPF depth parameter MEMORY_DEPTH = 2**ADDRESS_SIZE;  // 2**12 = 4096
localparam VEBPF_RULES_FIFO_DEPTH = 2**VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH; // 2^12 = 4096;

(* ramstyle = "no_rw_check" *)
reg [VEBPF_PROG_DATA_WIDTH-1:0] VeBPF_rules_fifo [VEBPF_RULES_FIFO_DEPTH-1:0];  // fifo for storing VeBPF rules
    // 64 bit data width and 4096 depth

// VeBPF RULES SCHEDULER FSM state registers
reg [3:0] VeBPF_rules_scheduler_state_reg, VeBPF_rules_scheduler_state_next;

reg VeBPF_rules_scheduler_fifo_wr_en_reg, VeBPF_rules_scheduler_fifo_wr_en_next;
reg VeBPF_rules_scheduler_fifo_rd_en_reg, VeBPF_rules_scheduler_fifo_rd_en_next;

// pointers for reading and writing to rules fifo
reg [VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH:0] VeBPF_rules_fifo_wr_fifo_ptr_reg = 0, VeBPF_rules_fifo_wr_fifo_ptr_next;
reg [VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH:0] VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_reg = 0, VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_next;

// commenting this out and initializing it with the signals that are used for uploading VeBPF rules to all VeBPFs
// reg [VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH:0] VeBPF_rules_uploader_rules_fifo_rd_ptr_reg = 0, VeBPF_rules_uploader_rules_fifo_rd_ptr_next;
    // Not subtracting 1 from FIFO_DEPTH_ADDR_WDITH will make rd ptr width 1 more than FIFO_DEPTH_ADDR_WDITH, the reason
    // for that is to compare the MSBs between read and write pointers for comparing rollover of the fifo to check
    // if the fifo is full or empty :3
        // FIFO_DEPTH_ADDR_WDITH-1:0 is used for indexing.. MSBit is used for rollover detection

reg VeBPF_rules_scheduler_table_wr_en_reg, VeBPF_rules_scheduler_table_wr_en_next;

// desc table fifo is full 
    // full when first MSB different but rest same  // to take account of the rollover affect of ring buffer (1 extra addr bit to keep track of that)
wire VeBPF_rules_scheduler_fifo_full;
assign VeBPF_rules_scheduler_fifo_full = VeBPF_rules_fifo_wr_fifo_ptr_reg == (VeBPF_rules_uploader_rules_fifo_rd_ptr_reg ^ {1'b1, {VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH{1'b0}}});

// VeBPF rules scheduler TABLE for storing meta-data regarding each rule uploaded to run on VeBPF for filtering the rxpkt 
// The depth of the VeBPF rules scheduler TABLE is ideally the total number of rules uploaded but since we will keep that a variable, hence
// we will have a certain depth of the VeBPF rules scheduler TABLE and it will be filled to the depth equal to the total num of rules uploaded.
// The pointers for reading and writing VeBPF rules scheduler TABLE will reset/rollover once the depth reaches the total num of rules uploaded.

// keep VEBPF_MAX_NUM_OF_RULES/VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX in powers of 2 
// so that we don't need to use multiply operations for rd wr ptrs and we can just to bitshifts
// converting this to a parameter
// localparam VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX = 64;
    // means 64 VEBPF rules can be uploaded..

localparam VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS = $clog2(VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX);
    // 6 bits

// 6 bits atm.. max rules can be 64 .. 0 - 63
reg [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS-1:0] VeBPF_rules_scheduler_total_num_rules_reg, VeBPF_rules_scheduler_total_num_rules_next;

// when VeBPF_rules_scheduler_all_rules_avail_reg bit gets high, that means all rules have been uploaded and are available inthe
// VEBPF RULES SCHEDULER FIFO with their metadata in the VEBPF RULES SCHEDULER TABLE. This bit going HIGH will cause the 
// FSM_VEBPF_RULES_UPLOADER FIFO TO GET ACTIVATED! 
    // FSM_VEBPF_RULES_UPLOADER FSM will upload the rules one by one in the VeBPF for each rxpkt.  

// flag for indicating to the VeBPF RULES UPLOADER FSM that all rules have been uploaded and are available in the VEBPF RULES SCEHDULER FSM
wire VeBPF_rules_scheduler_all_rules_avail_flag;

// *******************  VeBPF RULES SCHEDULER TABLE "columns" below:  *****************************************************************

// Each row represents a different RULE for the VeBPF, and the columns of that row represent the metadata for that rule.

// VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH = 12
reg [VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH-1:0] VeBPF_rules_scheduler_table_fifo_start_ptr [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX-1:0];  // 64 depth


// reg [VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH-1:0] VeBPF_rules_scheduler_table_fifo_end_ptr [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX-1:0];
    // might not need end ptr table column since we have fifo start ptr and rule length. We can just add both to get end ptr.

reg [VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH-1:0] VeBPF_rules_scheduler_table_fifo_rule_length [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX-1:0];  // depth max is 64 atm

reg [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS:0] VeBPF_rules_scheduler_table_wr_ptr_reg, VeBPF_rules_scheduler_table_wr_ptr_next;

// commenting this out and initializing it with the signals that are used for uploading VeBPF rules to all VeBPFs
// reg [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS:0] VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg, VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_next;
    // we have number of rules limit in power of 2s, so once we increase the rd or wr ptrs for the 
    // VeBPF RULES metadata TABLE, the rd and wr ptrs will rollover automatically.  // rollover won't be needed except for indicating FULL condition, that no more rules can be uploaded

wire VeBPF_rules_scheduler_table_full;
assign VeBPF_rules_scheduler_table_full = VeBPF_rules_scheduler_table_wr_ptr_reg == (VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg ^ {1'b1, {VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS{1'b0}}});

// reg VeBPF_rules_scheduler_table_wr_en_reg, VeBPF_rules_scheduler_table_wr_en_next;

// error flag
reg VeBPF_rules_scheduler_error_bit_reg, VeBPF_rules_scheduler_error_bit_next;

reg VeBPF_rules_scheduler_all_rules_uploaded_flag;
reg VeBPF_rules_scheduler_all_rules_uploaded_flag_notification;

assign VeBPF_rules_scheduler_error_flag = VeBPF_rules_scheduler_error_bit_reg;

assign VeBPF_rules_scheduler_all_rules_avail_flag = VeBPF_rules_scheduler_all_rules_uploaded_flag;

reg testing_flag_1_reg, testing_flag_2_reg;

// Seq part of VeBPF RULES SCHEDULER FSM!
always @(posedge clk) begin
    
    if (rst) begin

        VeBPF_rules_scheduler_state_reg <= VEBPF_RULES_SCHEDULER_FSM_STATE_IDLE;
        VeBPF_rules_fifo_wr_fifo_ptr_reg <= 0;
        VeBPF_rules_scheduler_fifo_wr_en_reg <= 0;
        // VeBPF_rules_scheduler_fifo_rd_en_reg <= 0;
        // VeBPF_rules_scheduler_all_rules_avail_reg <= 0;
        VeBPF_prog_data_word_reg <= 0;
        VeBPF_prog_addr_reg <= 0;
        VeBPF_prog_length_reg <= 0;
        VeBPF_rules_scheduler_error_bit_reg <= 0;
        VeBPF_rules_scheduler_table_wr_ptr_reg <= 0;
        // VeBPF_rules_scheduler_table_wr_en_reg <= 0;
        VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_reg <= 0;
        VeBPF_rules_scheduler_total_num_rules_reg <= 0;

        // idx_VeBPF_pgm_reg <= 0;

        // VeBPF_prog_addr_all_rules_uploader_in_reg <= 0;
        VeBPF_prog_data_all_rules_uploader_in_reg <= 0;
        VeBPF_prog_write_enable_all_rules_uploader_in_reg <= 0;
        VeBPF_prog_reset_all_rules_uploader_in_reg <= 1; // activate VeBPF pgm mem reset on next clk
        VeBPF_rules_scheduler_total_num_rules_uploaded_reg <= 0;
        VeBPF_rules_uploader_rules_fifo_rd_ptr_reg <= 0;
        VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg <= 0;

        VeBPF_rules_scheduler_all_rules_uploader_current_prog_length_reg <= 0;
        VeBPF_rules_scheduler_all_rules_uploader_current_prog_start_ptr_reg <= 0;
        VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_reg <= 0;

        VeBPF_rules_scheduler_table_rules_uploader_current_rule_number_rd_ptr_reg <= 0;

        VeBPF_rules_selector_current_rule_start_ptr_reg <= 0;

        testing_flag_1_reg <= 0;
        testing_flag_2_reg <= 0;

    
    end else begin
        
        VeBPF_rules_scheduler_state_reg <= VeBPF_rules_scheduler_state_next;
        VeBPF_rules_fifo_wr_fifo_ptr_reg <= VeBPF_rules_fifo_wr_fifo_ptr_next;
        VeBPF_rules_scheduler_fifo_wr_en_reg <= VeBPF_rules_scheduler_fifo_wr_en_next;
        // VeBPF_rules_scheduler_fifo_rd_en_reg <= VeBPF_rules_scheduler_fifo_rd_en_next;
        // VeBPF_rules_scheduler_all_rules_avail_reg <= VeBPF_rules_scheduler_all_rules_avail_next;
        VeBPF_prog_data_word_reg <= VeBPF_prog_data_word_next;
        VeBPF_prog_addr_reg <= VeBPF_prog_addr_next;
        VeBPF_prog_length_reg <= VeBPF_prog_length_next;
        VeBPF_rules_scheduler_error_bit_reg <= VeBPF_rules_scheduler_error_bit_next;

        if (VeBPF_rules_scheduler_fifo_wr_en_reg) begin
            VeBPF_rules_fifo[VeBPF_rules_fifo_wr_fifo_ptr_reg[VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH-1:0]] <= VeBPF_prog_data_word_reg;
                // MSB of wr ptr is for checking ringbuffer fifo rollover
        end

        VeBPF_rules_scheduler_table_wr_ptr_reg <= VeBPF_rules_scheduler_table_wr_ptr_next;
        // VeBPF_rules_scheduler_table_wr_en_reg <= VeBPF_rules_scheduler_table_wr_en_next;

        if (VeBPF_rules_scheduler_table_wr_en_next) begin 

            VeBPF_rules_scheduler_table_fifo_start_ptr[VeBPF_rules_scheduler_table_wr_ptr_reg[VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS-1:0]] <= VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_reg[VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH-1:0];
                // VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_reg has 1 bit more than the bits req, to check for fifo/table being full. Thats why removie MSb  
                // width of both sides of assignment is VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS-1 & VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH-1 respectively 

            VeBPF_rules_scheduler_table_fifo_rule_length[VeBPF_rules_scheduler_table_wr_ptr_reg[VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS-1:0]] <= VeBPF_prog_length_reg;
                // VeBPF_prog_length_reg is the total len of the prog. So if start idx of prog is and len 
                // is 5, so the last prog idx is 4 (start idx + (len - 1))

            testing_flag_2_reg <= 1;
        end

        VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_reg <= VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_next;

        VeBPF_rules_scheduler_total_num_rules_reg <= VeBPF_rules_scheduler_total_num_rules_next;

        // idx_VeBPF_pgm_reg <= idx_VeBPF_pgm_next;

        // VeBPF_prog_data_all_rules_uploader_in_reg <= VeBPF_prog_addr_all_rules_uploader_in_next;
        // VeBPF_prog_addr_all_rules_uploader_in_reg <= VeBPF_prog_data_all_rules_uploader_in_next;
        VeBPF_prog_write_enable_all_rules_uploader_in_reg <= VeBPF_prog_write_enable_all_rules_uploader_in_next;
        VeBPF_prog_reset_all_rules_uploader_in_reg <= VeBPF_prog_reset_all_rules_uploader_in_next;
        VeBPF_rules_scheduler_total_num_rules_uploaded_reg <= VeBPF_rules_scheduler_total_num_rules_uploaded_next;
        VeBPF_rules_uploader_rules_fifo_rd_ptr_reg <= VeBPF_rules_uploader_rules_fifo_rd_ptr_next;
        VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg <= VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_next;


        if (VeBPF_rules_uploader_rules_fifo_read_en) begin 
            VeBPF_prog_data_all_rules_uploader_in_reg <= VeBPF_rules_fifo[
                            VeBPF_rules_uploader_rules_fifo_rd_ptr_reg[VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH-1:0]];
        end

        if (VeBPF_rules_uploader_rules_scheduler_table_read_en) begin 

            VeBPF_rules_scheduler_all_rules_uploader_current_prog_length_reg <= VeBPF_rules_scheduler_table_fifo_rule_length[
                VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg[VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS-1:0]];

            VeBPF_rules_scheduler_all_rules_uploader_current_prog_start_ptr_reg <= VeBPF_rules_scheduler_table_fifo_start_ptr[
                VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg[VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS-1:0]];

        end 

        // if (VeBPF_rules_selector_rules_scheduler_table_read_en & (!VeBPF_rules_uploader_rules_scheduler_table_read_en)) begin
        if (VeBPF_rules_selector_rules_scheduler_table_read_en) begin
           
            VeBPF_rules_selector_current_rule_start_ptr_reg <= VeBPF_rules_scheduler_table_fifo_start_ptr[
                VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg[VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS-1:0]];
            testing_flag_1_reg <= 1;
        end             


        VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_reg <= VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_next;


    end

end

// VeBPF prog mem ports 
// .VeBPF_prog_addr_in(VeBPF_prog_addr_in),
// .VeBPF_prog_data_in(VeBPF_prog_data_in),
// .VeBPF_prog_write_enable_in(VeBPF_prog_write_enable_in),
// .VeBPF_prog_reset_in(VeBPF_prog_reset_in)                        // separate reset for the prog mem of VeBPF
// .VeBPF_prog_busy_in(VeBPF_prog_busy_in),                      // the progloader is busy writing to VeBPF prog mem
// .VeBPF_prog_done_in(VeBPF_prog_done_in)                      // VeBPF prog has been completed 

// NEW CONTROL PORTS FROM PROG LOADER and GPIO for loading programs
// .VeBPF_next_rule_switch_flag_in
// .VeBPF_all_rules_done_switch_flag_in

reg [VEBPF_PROG_DATA_WIDTH-1:0] VeBPF_prog_data_word_reg, VeBPF_prog_data_word_next;
reg [VEBPF_PROG_ADDRESS_WIDTH-1:0] VeBPF_prog_addr_reg, VeBPF_prog_addr_next;
    // might not need to use prog addr width at all .. will need to store the length of the VeBPF prog 

reg [VEBPF_PROG_ADDRESS_WIDTH-1:0] VeBPF_prog_length_reg, VeBPF_prog_length_next;
    // prog length can be max 4096 or classical eBPF .. but we will be using small progs and multiple of them

// integer i_VeBPF_pgm;
    // use this for for loop to unroll the VeBPF combined global signals

// reg [BITS_NEDED_FOR_NUMBER_OF_VEBPF-1:0] idx_VeBPF_pgm_reg, idx_VeBPF_pgm_next;

// This is the signal for the pgm data for uploading all VeBPF rules to all VeBPFs one by one
reg [VEBPF_PROG_DATA_WIDTH-1:0] VeBPF_prog_data_all_rules_uploader_in_reg; //, VeBPF_prog_data_all_rules_uploader_in_next;
wire [VEBPF_PROG_DATA_WIDTH-1:0] VeBPF_prog_data_all_rules_uploader_in;
assign VeBPF_prog_data_all_rules_uploader_in = VeBPF_prog_data_all_rules_uploader_in_reg;

// This is the signal for address of pgm data for uploading all VeBPF rules to all VeBPFs one by one
// reg [VEBPF_PROG_ADDRESS_WIDTH-1:0] VeBPF_prog_addr_all_rules_uploader_in_reg, VeBPF_prog_addr_all_rules_uploader_in_next;
wire [VEBPF_PROG_ADDRESS_WIDTH-1:0] VeBPF_prog_addr_all_rules_uploader_in;
assign VeBPF_prog_addr_all_rules_uploader_in = VeBPF_rules_uploader_rules_fifo_rd_ptr_reg;

// This is the signal for the pgm write enable for uploading all VeBPF rules to all VeBPFs one by one
reg VeBPF_prog_write_enable_all_rules_uploader_in_reg, VeBPF_prog_write_enable_all_rules_uploader_in_next;
wire VeBPF_prog_write_enable_all_rules_uploader_in;
assign VeBPF_prog_write_enable_all_rules_uploader_in = VeBPF_prog_write_enable_all_rules_uploader_in_reg;

// This is the signal for the pgm reset for uploading all VeBPF rules to all VeBPFs one by one
reg VeBPF_prog_reset_all_rules_uploader_in_reg, VeBPF_prog_reset_all_rules_uploader_in_next;
wire VeBPF_prog_reset_all_rules_uploader_in;
assign VeBPF_prog_reset_all_rules_uploader_in = VeBPF_prog_reset_all_rules_uploader_in_reg;

reg [VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH:0] VeBPF_rules_uploader_rules_fifo_rd_ptr_reg = 0, VeBPF_rules_uploader_rules_fifo_rd_ptr_next;
    // will use this rd ptr to read VeBPF pgm data from rules fifo

// This is the read enable signal.. when it is active the VeBPF_rules_fifo will be read using the rd pointer "VeBPF_rules_uploader_rules_fifo_rd_ptr_reg"
reg VeBPF_rules_uploader_rules_fifo_read_en;
    // use this to read VeBPF pgm data/rules from rules fifo for uploading it into VeBPF pgm memory



reg [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS:0] VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg, VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_next;
    // will use this rd ptr for reading the start ptr and rules length from the respective rules scheduler tables

// This is the read enable signal.. when it is active the VeBPF_rules_scheduler_table will be read using the rd pointer "VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg"
reg VeBPF_rules_uploader_rules_scheduler_table_read_en;
    // use this to read (from rules schedulertable) the start ptr and rule length for uploading a particular rule number from the rules fifo and upload it into 
    // VeBPF pgm mem


// total rules reg becomes 1 on the arrival of first VeBPF rule.. and keeps on incrementing as more rules come in
// VeBPF_rules_scheduler_total_num_rules_next = VeBPF_rules_scheduler_total_num_rules_reg + 1; 
   // will use this reg for comparison of how many rules have been uploading to a particular VeBPF and what are the start ptrs of those rules
   // it is imp to note that VeBPF_rules_scheduler_table_fifo_start_ptr start ptr values will be the same as start ptrs of VeBPF rules
   // located in the VeBPF pgm memories... Hence in the rules selector FSM, it will just need to read these start ptrs and updated ip_next 
   // of each VeBPF with these these start ptrs based on the Rule # selected to run on the selected VeBPF


// 6 bits atm.. max rules can be 64 .. 0 - 63
reg [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS-1:0] VeBPF_rules_scheduler_total_num_rules_uploaded_reg, VeBPF_rules_scheduler_total_num_rules_uploaded_next;

reg [VEBPF_PROG_ADDRESS_WIDTH-1:0] VeBPF_rules_scheduler_all_rules_uploader_current_prog_length_reg;  // in DWs (8 bytes = 1 in prog len)
reg [VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH:0] VeBPF_rules_scheduler_all_rules_uploader_current_prog_start_ptr_reg;
reg [VEBPF_PROG_ADDRESS_WIDTH-1:0] VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_reg, VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_next;  // in DWs (8 bytes = 1 in prog len)
reg [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS:0] VeBPF_rules_scheduler_table_rules_uploader_current_rule_number_rd_ptr_reg, VeBPF_rules_scheduler_table_rules_uploader_current_rule_number_rd_ptr_next;
reg flag_to_upload_fresh_set_of_rules;

// Comb part of VeBPF RULES SCHEDULER FSM!
always @(*) begin

    // default value of state_next (storing the saved value in state_reg if no new value is given to state_next). state_next goes to state_reg on the risingedge clk 
    VeBPF_rules_scheduler_state_next = VeBPF_rules_scheduler_state_reg;
    VeBPF_rules_scheduler_fifo_wr_en_next = VeBPF_rules_scheduler_fifo_wr_en_reg;
    // VeBPF_rules_scheduler_fifo_rd_en_next = VeBPF_rules_scheduler_fifo_rd_en_reg;
    // VeBPF_rules_scheduler_all_rules_avail_next = VeBPF_rules_scheduler_all_rules_avail_reg;
    VeBPF_prog_data_word_next = VeBPF_prog_data_word_reg;
    VeBPF_prog_addr_next = VeBPF_prog_addr_reg;
    VeBPF_prog_length_next = VeBPF_prog_length_reg;
    VeBPF_rules_fifo_wr_fifo_ptr_next = VeBPF_rules_fifo_wr_fifo_ptr_reg;
    VeBPF_rules_scheduler_error_bit_next = VeBPF_rules_scheduler_error_bit_reg;
    VeBPF_rules_scheduler_table_wr_ptr_next = VeBPF_rules_scheduler_table_wr_ptr_reg;
    VeBPF_rules_scheduler_table_wr_en_next = 0;
    VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_next = VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_reg;
    VeBPF_rules_scheduler_all_rules_uploaded_flag = 0;
    VeBPF_rules_scheduler_all_rules_uploaded_flag_notification = 0;
    VeBPF_rules_scheduler_total_num_rules_next = VeBPF_rules_scheduler_total_num_rules_reg;

    // idx_VeBPF_pgm_next = idx_VeBPF_pgm_reg;

    // VeBPF_prog_addr_all_rules_uploader_in_next = VeBPF_prog_addr_all_rules_uploader_in_reg;
    // VeBPF_prog_data_all_rules_uploader_in_next = VeBPF_prog_data_all_rules_uploader_in_reg;
    VeBPF_prog_write_enable_all_rules_uploader_in_next = VeBPF_prog_write_enable_all_rules_uploader_in_reg;
    VeBPF_prog_reset_all_rules_uploader_in_next = VeBPF_prog_reset_all_rules_uploader_in_reg;
    VeBPF_rules_scheduler_total_num_rules_uploaded_next = VeBPF_rules_scheduler_total_num_rules_uploaded_reg;
    VeBPF_rules_uploader_rules_fifo_rd_ptr_next = VeBPF_rules_uploader_rules_fifo_rd_ptr_reg;
    VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_next = VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg;

    // default read enables are 0
    VeBPF_rules_uploader_rules_fifo_read_en = 0;
    VeBPF_rules_uploader_rules_scheduler_table_read_en = 0;

    VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_next = VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_reg;

    VeBPF_rules_scheduler_table_rules_uploader_current_rule_number_rd_ptr_next = VeBPF_rules_scheduler_table_rules_uploader_current_rule_number_rd_ptr_reg;

    flag_to_upload_fresh_set_of_rules = 0;

    case(VeBPF_rules_scheduler_state_reg)

        VEBPF_RULES_SCHEDULER_FSM_STATE_IDLE: begin

            VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_IDLE;
            VeBPF_prog_length_next = 0;

            // storing the VeBPF_rules_fifo_wr_fifo_ptr so we can write this to the VeBPF RULES METADATA TABLE 
            VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_next = VeBPF_rules_fifo_wr_fifo_ptr_reg;

            // we have valid VeBPF prog coming in
            if(VeBPF_prog_write_enable_in) begin 
                // VeBPF_prog_write_enable_in is 1 for only 1 clk cycle
                    // latch the VeBPF prog addr and prog data during this clk cycle

                // Also this write enable in during IDLE state represents the FIRST VeBPF prog word being uploaded.
                
                VeBPF_prog_data_word_next = VeBPF_prog_data_in;
                VeBPF_prog_addr_next = VeBPF_prog_addr_in;
                VeBPF_prog_length_next = VeBPF_prog_length_reg + 1;

                // total rules reg becomes 1 on the arrival of first VeBPF rule.. and keeps on incrementing as more rules come in
                VeBPF_rules_scheduler_total_num_rules_next = VeBPF_rules_scheduler_total_num_rules_reg + 1;

                if (VeBPF_rules_scheduler_fifo_full) begin
                    // if we are trying to upload a VeBPF rule while the RULES FIFO is full, raise an error flag and stop ops. Also check for this cond in other states.
                    // raise error flag and turn red led HIGH on FPGA
                    VeBPF_rules_scheduler_error_bit_next = 1;
                    VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_ERROR;  // system reset will automatically take the state to STATE IDLE

                end else begin

                    VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_WRITING_PROG_TO_RULES_FIFO;
                    // not checking for prog done since we're assuming that VeBPF rule will be greater than length of 1
                    
                end

            end

        end

        VEBPF_RULES_SCHEDULER_FSM_STATE_WRITING_PROG_TO_RULES_FIFO: begin
            
            VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_WRITING_PROG_TO_RULES_FIFO;

            if (VeBPF_rules_scheduler_fifo_full) begin
                // if we are trying to upload a VeBPF rule while the RULES FIFO is full, raise an error flag and stop ops. Also check for this cond in other states.
                // raise error flag and turn red led HIGH on FPGA
                VeBPF_rules_scheduler_error_bit_next = 1;
                VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_ERROR;  // system reset will automatically take the state to STATE IDLE

            end else begin

                // replaced the code block below since as mentioned in the comments, it wasn't required
                VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_WAITING_FOR_NEXT_PROG_WORD;

                // if(!VeBPF_prog_done_in) begin
                //     VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_WAITING_FOR_NEXT_PROG_WORD;
                // end else begin
                //     VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_RULE_WRITING_DONE;
                //     // wont enter this else cond.. can comment this else out
                // end

                // write the VeBPF prog word to the RULES FIFO and increment the write ptr and wait for the next VeBPF prog word
                VeBPF_rules_scheduler_fifo_wr_en_next = 1;
                    // increment the wr ptr in next state cx the current wr ptr will be used to write to RULES FIFO
                        // VeBPF_rules_fifo_wr_fifo_ptr_next = VeBPF_rules_fifo_wr_fifo_ptr_reg + 1;

                    // These signals below stay the same for a few cycles since prog loaders takes multiple cycles to process a single prog data word and its address
                        // VeBPF_prog_data_word_next = VeBPF_prog_data_in;
                        // VeBPF_prog_addr_next = VeBPF_prog_addr_in;
                        // VeBPF_prog_length_next = VeBPF_prog_length_reg + 1;
                            // that is why the fifo write en reg is used in "VEBPF_RULES_SCHEDULER_FSM_STATE_WRITING_PROG_TO_RULES_FIFO"
                            // which relies on the delays in clk in writing 
                            // so it can use the latched values of VeBPF_rules_scheduler_fifo_wr_en_reg,VeBPF_prog_data_word_reg
                            // and VeBPF_prog_length_reg and VeBPF_rules_fifo_wr_fifo_ptr_reg                     
            end 
        end

        VEBPF_RULES_SCHEDULER_FSM_STATE_WAITING_FOR_NEXT_PROG_WORD: begin
            
            VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_WAITING_FOR_NEXT_PROG_WORD;
            
            VeBPF_rules_scheduler_fifo_wr_en_next = 0;

            // VeBPF_prog_write_enable_in gets HIGH for only 1 clk as designed in progloader 
            // while the other prog data word and prog addr stay the same for a lot of clks
            // till the next prog data word is available
                // that is why the fifo write en reg is used in "VEBPF_RULES_SCHEDULER_FSM_STATE_WRITING_PROG_TO_RULES_FIFO"
                // which relies on the delays in clk in writing 
                // so it can use the latched values of VeBPF_rules_scheduler_fifo_wr_en_reg,VeBPF_prog_data_word_reg
                // and VeBPF_prog_length_reg and VeBPF_rules_fifo_wr_fifo_ptr_reg   


            if (VeBPF_prog_write_enable_in) begin
                // VeBPF_prog_write_enable_in gets HIGH for only 1 clk as designed in progloader 

                VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_WRITING_PROG_TO_RULES_FIFO;

                // increment the RULES fifo write ptr for the next VeBPF prog word
                VeBPF_rules_fifo_wr_fifo_ptr_next = VeBPF_rules_fifo_wr_fifo_ptr_reg + 1;

                VeBPF_prog_data_word_next = VeBPF_prog_data_in;
                VeBPF_prog_addr_next = VeBPF_prog_addr_in;
                VeBPF_prog_length_next = VeBPF_prog_length_reg + 1;

            end else if (VeBPF_prog_done_in) begin
                
                VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_WAITING_FOR_NEXT_PROG_WORD;
                // VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_RULE_WRITING_DONE;

                // Store the current VeBPF RULE metadata to RULE metadata TABLE
                    // we have number of rules limit in power of 2s, so once we increase the rd or wr ptrs for the 
                    // VeBPF RULES metadata TABLE, the rd and wr ptrs will rollover automatically.

                // increment the RULES fifo write ptr for the next VeBPF prog word
                    // increment the write ptr for the next incoming rule if any
                VeBPF_rules_fifo_wr_fifo_ptr_next = VeBPF_rules_fifo_wr_fifo_ptr_reg + 1;

                // updating VeBPF RULES METADATA TABLE
                VeBPF_rules_scheduler_table_wr_en_next = 1;
                    // default value is 0
                
                // incrementing the rules scheduler TABLE write pointer for writing the metadata details for the next VeBPF rule prog
                VeBPF_rules_scheduler_table_wr_ptr_next = VeBPF_rules_scheduler_table_wr_ptr_reg + 1;

                // also have a regitser here that counts the total number of rules uploaded

                // switiching to automatic uploading all VeBPF rules from a single file without manual switch toggling
                // Check for next rule flag or all VeBPF rules uploaded flag 
                if (VeBPF_next_rule_switch_flag_in) begin
                    VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_IDLE;
                        // go to state IDLE and wait for VeBPF prog word avail flag to write to RULES fifo                  
                end else if (VeBPF_all_rules_done_switch_flag_in) begin
                    VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_RULES_LOADED_TO_FIFO_START_UPLOADING_TO_VEBPF;
                    
                end


                // check for total rules exceeding the upper limit of number of rules allowed
                if (VeBPF_rules_scheduler_table_wr_ptr_reg >= VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX) begin  // max depth is 64 atm .. 0 - 63 idx .. 64 rules can be uploaded
                    
                    VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_ERROR; // system reset will automatically take the state to STATE IDLE
                    VeBPF_rules_scheduler_error_bit_next = 1;

                    // this if cond will have priority since it is nested deeper


                end
            
            end

        end 
        
        // switiching to automatic uploading all VeBPF rules from a single file without manual switch toggling
        // VEBPF_RULES_SCHEDULER_FSM_STATE_RULE_WRITING_DONE: begin

        //     VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_RULE_WRITING_DONE;

        //     // wait for switch flip to check if there is another rule
        //         // if there is go to state IDLE and wait for the next VeBPF rule! 
        //     if (VeBPF_next_rule_switch_flag_in) begin
        //         VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_IDLE;
        //             // go to state IDLE and wait for VeBPF prog word avail flag to write to RULES fifo 
            
        //     // wait for a diff switch to check that all VEBPF RULES have been uploaded                    
        //     end else if (VeBPF_all_rules_done_switch_flag_in) begin
        //         VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_RULES_LOADED_TO_FIFO_START_UPLOADING_TO_VEBPF;
                
        //     end

        // end

        VEBPF_RULES_SCHEDULER_FSM_STATE_ERROR: begin

            VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_ERROR;
            VeBPF_rules_scheduler_error_bit_next = 1;

        end

        VEBPF_RULES_SCHEDULER_FSM_STATE_RULES_LOADED_TO_FIFO_START_UPLOADING_TO_VEBPF: begin 
            
            VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_RULES_LOADED_TO_FIFO_START_UPLOADING_TO_VEBPF;

            // VeBPF_rules_scheduler_total_num_rules_uploaded_reg starts at 0 and will be incremented by 1 after
            // the current VeBPF rule has been completely uploaded
            if (VeBPF_rules_scheduler_total_num_rules_uploaded_reg < VeBPF_rules_scheduler_total_num_rules_reg) begin

                VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_LOADING_RULES_LEN_FIFO_STRT_PTR;

                // start uploading all rules 1 by 1 into all VeBPFs pgm mems

                // following rd ptr be start with the values of 0 due to reset state so we dont need to reassign it to 0
                    // VeBPF_rules_uploader_rules_fifo_rd_ptr_reg
                    // VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg

                // VeBPF_rules_uploader_rules_fifo_read_en = 1;
                    // VeBPF_rules_uploader_rules_fifo_rd_ptr_reg rd ptr will be used
                    // VeBPF_prog_data_all_rules_uploader_in_reg will be loaded with prog data in next cycle

                VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_next = 1;
                    // reset VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_reg to 1 so we can keep track of how 
                    // much of the current rule we have uploaded to VeBPFs   

                VeBPF_rules_uploader_rules_scheduler_table_read_en = 1;
                    // VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg rd ptr will be used
                    // "VeBPF_rules_scheduler_all_rules_uploader_current_prog_length_reg" 
                        // will be loaded with current VeBPF rule length in the next cycle 
                    // "VeBPF_rules_scheduler_all_rules_uploader_current_prog_start_ptr_reg"
                        // will be loaded with rules fifo start ptr to read the current VeBPF rule in next clk cycle

                VeBPF_prog_reset_all_rules_uploader_in_next = 0; // deactivate VeBPF pgm mem reset on next clk
                

                // VeBPF_rules_scheduler_total_num_rules_reg;
                // VeBPF_prog_addr_all_rules_uploader_in_reg;
                // VeBPF_prog_write_enable_all_rules_uploader_in_reg;
                // VeBPF_prog_reset_all_rules_uploader_in_reg;
                // VeBPF_rules_scheduler_total_num_rules_uploaded_reg;
                // VeBPF_rules_uploader_rules_fifo_rd_ptr_reg;
                // VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg;
                // VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_reg

            end else begin

                VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_ALL_RULES_UPLOADED_TO_VEBPF;
                VeBPF_rules_scheduler_all_rules_uploaded_flag_notification = 1;
                    // will get HIGH for 1 clk
                
            end



        end

        VEBPF_RULES_SCHEDULER_FSM_STATE_LOADING_RULES_LEN_FIFO_STRT_PTR: begin
            // Imp note below!
            // I have 2 options here: There is a 3rd option as well!
                // 1) I can use for loop in a always(*) block (meaning this fsm) and increment an index lets say n2, and access that 
                // index of VeBPF depending upon the value of n2 I can have an if condition inside the for loop just like cache.v
                // and I can program the VeBPFs this way, i.e.,:
                    // for (i = 0; i < NUM_OF_VEBPFs; i++) begin
                        // if (i = n2) begin
                            // VeBPF_inst_prog_reset_in_combined_global[i] = VeBPF_rules_scheduler_prog_reset_in_reg;
                                // and having a default value of VeBPF_inst_prog_reset_in_combined_global = 0 under always(*) like in cache.v
                        // end
                    // end
                // 2) I can use the "panic_scheduller.v" approach and have a separate fsm for each VeBPF for uploading all VeBPF rules to all VeBPFs
                // using a generate block and genvar n3 under it I can connect to each signal of pgm mem of VeBPF like this VeBPF_inst_prog_reset_in_combined_global[n3]
                // and each fsm will read all VeBPF rules from fifo (these fsms can wait for the prev one to finish programming its VeBPF), and will program 
                // its idx numbered VeBPF n3 will all the VeBPF rules..
                // I will start with approach 1 here and if it fails I can move to approach 2.
                // 3) Use same wire to program all VeBPF pgm memories together since all of them need the same rules, i.e., all rules.
                    // I will use approach # 3 above.

                // starting with idx_VeBPF_pgm_reg = 0 after reset
                
                // don't need the if else block below since it was meant for approach # 1 mentiond in comments above
                // if (idx_VeBPF_pgm_reg < NUMBER_OF_VEBPF) begin
                //     VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_UPLOADING_RULES_TO_VEBPFS_RD_RULES_FIFO;                     

                // end else begin 
                //     VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_UPLOADING_RULES_TO_VEBPFS_DONE;

                // end 

            VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_LOADING_RULES_PGM_DATA;

            VeBPF_rules_uploader_rules_fifo_rd_ptr_next = VeBPF_rules_scheduler_all_rules_uploader_current_prog_start_ptr_reg;
                // VeBPF_prog_addr_all_rules_uploader_in will have same value as VeBPF_rules_uploader_rules_fifo_rd_ptr_reg

        end

        VEBPF_RULES_SCHEDULER_FSM_STATE_LOADING_RULES_PGM_DATA: begin 

            VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_UPLOADING_RULES_DW_TO_VEBPF_PGM_DATA;

            VeBPF_rules_uploader_rules_fifo_read_en = 1;
                // VeBPF_rules_uploader_rules_fifo_rd_ptr_reg rd ptr will be used
                // VeBPF_prog_data_all_rules_uploader_in_reg will be loaded with prog data in next cycle

            VeBPF_prog_write_enable_all_rules_uploader_in_next = 1; // activate VeBPF pgm mem write enable

        end

        VEBPF_RULES_SCHEDULER_FSM_STATE_UPLOADING_RULES_DW_TO_VEBPF_PGM_DATA: begin 

            // VeBPF_prog_write_enable_all_rules_uploader_in_reg is 1 in this state
            // VeBPF_prog_data_all_rules_uploader_in_reg has data pointed to by VeBPF_rules_uploader_rules_fifo_rd_ptr_reg is 1 in this state
            // VeBPF_prog_addr_all_rules_uploader_in has value of VeBPF_rules_uploader_rules_fifo_rd_ptr_reg

            VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_UPLOADING_RULES_DW_TO_VEBPF_PGM_DATA;

            VeBPF_prog_write_enable_all_rules_uploader_in_next = 0; // deactivate VeBPF pgm mem write enable

            if (VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_reg < VeBPF_rules_scheduler_all_rules_uploader_current_prog_length_reg) begin

                // go to state for uploading the current rule's next pgm DW
                // where we raise the VeBPF pgm mem write enable next to 1
                VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_LOADING_RULES_PGM_DATA;

                // increment the current prog len counter
                VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_next = VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_reg + 1;

                // increment rules fifo rd ptr for current rule's next pgm mem DW
                VeBPF_rules_uploader_rules_fifo_rd_ptr_next = VeBPF_rules_uploader_rules_fifo_rd_ptr_reg + 1;

                // increment rules scheduler table rd ptr.. NOPE.. do that for the next rule, not the current rule
                // VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_next = VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg + 1;

            end else begin

                // increment next rule rd ptrs and total rules uploaded (to VeBPF) and go to the next state
                // where it will be checked if total rules uploaded < total rules reg

                VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_RULES_LOADED_TO_FIFO_START_UPLOADING_TO_VEBPF;

                // increment the rules scheduler table rd ptr for reading meta data of next rule
                VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_next = VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_reg + 1;

                // increment the total num of rules uploaded to VeBPFs pgm mem 
                VeBPF_rules_scheduler_total_num_rules_uploaded_next = VeBPF_rules_scheduler_total_num_rules_uploaded_reg + 1;
                

            end

        end

        VEBPF_RULES_SCHEDULER_FSM_STATE_ALL_RULES_UPLOADED_TO_VEBPF: begin 

            VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_ALL_RULES_UPLOADED_TO_VEBPF;

            VeBPF_rules_scheduler_all_rules_uploaded_flag = 1;

            // TODO: Check for switch to see if we want to upload a fresh set of rules, Then reset all counters, ptrs and metadata stuff to 0 
            // not here but in the state after all VeBPF rules have been uploaded to all VeBPF pgm mems
            if (flag_to_upload_fresh_set_of_rules) begin

                VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_RESET_COUNTERS_FOR_NEW_RULES_SET;

            end


        end

        VEBPF_RULES_SCHEDULER_FSM_STATE_RESET_COUNTERS_FOR_NEW_RULES_SET: begin 

            VeBPF_rules_scheduler_state_next = VEBPF_RULES_SCHEDULER_FSM_STATE_IDLE;

            // reset all signals as in seq rst block

            VeBPF_rules_fifo_wr_fifo_ptr_next = 0;
            VeBPF_rules_scheduler_fifo_wr_en_next = 0;
            // VeBPF_rules_scheduler_fifo_rd_en_next = 0;
            // VeBPF_rules_scheduler_all_rules_avail_next = 0;
            VeBPF_prog_data_word_next = 0;
            VeBPF_prog_addr_next = 0;
            VeBPF_prog_length_next = 0;
            VeBPF_rules_scheduler_error_bit_next = 0;
            VeBPF_rules_scheduler_table_wr_ptr_next = 0;
            // VeBPF_rules_scheduler_table_wr_en_next = 0;
            VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_next = 0;
            VeBPF_rules_scheduler_total_num_rules_next = 0;

            // idx_VeBPF_pgm_next = 0;

            // VeBPF_prog_addr_all_rules_uploader_in_next = 0;
            // VeBPF_prog_data_all_rules_uploader_in_next = 0;
            VeBPF_prog_write_enable_all_rules_uploader_in_next = 0;
            VeBPF_prog_reset_all_rules_uploader_in_next = 1; // activate VeBPF pgm mem reset on next clk
            VeBPF_rules_scheduler_total_num_rules_uploaded_next = 0;
            VeBPF_rules_uploader_rules_fifo_rd_ptr_next = 0;
            VeBPF_rules_uploader_rules_scheduler_table_rd_ptr_next = 0;

            // VeBPF_rules_scheduler_all_rules_uploader_current_prog_length_next = 0;
            // VeBPF_rules_scheduler_all_rules_uploader_current_prog_start_ptr_next = 0;
            VeBPF_rules_scheduler_all_rules_uploader_current_prog_len_counter_next = 0;

            VeBPF_rules_scheduler_table_rules_uploader_current_rule_number_rd_ptr_next = 0;

        end     

    endcase     

end


// need to add a reg to store total # RULES
    // VeBPF_rules_scheduler_total_num_rules_reg


// ********************************************************************************************************************************************************************
// ***************************************** VeBPF RULES SCHEDULER FSM -> END *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ********************************************************************************************************************************************************************
// ***************************************** VeBPF RULES Selector FSM -> START *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************
localparam [3:0]
    VEBPF_RULES_SELECTOR_FSM_STATE_IDLE = 4'd0,
    VEBPF_RULES_SELECTOR_FSM_STATE_VEBPF_ARBITRATION_REQUEST = 4'd1,
    VEBPF_RULES_SELECTOR_FSM_STATE_LOAD_SELECTED_RULE_START_PTR = 4'd2,
    VEBPF_RULES_SELECTOR_FSM_STATE_UPDATE_IP_NEXT_TO_SELECTED_RULE_IN_VEBPF = 4'd3,
    VEBPF_RULES_SELECTOR_FSM_STATE_UPDATE_IP_NEXT_TO_SELECTED_RULE_IN_VEBPF_DONE = 4'd4,
    VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_VEBPF_RESULTS = 4'd5,
    VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_NEXT_RX_PKT_HDR = 4'd6;


// VeBPF RULES SELECTOR FSM state registers
reg [3:0] VeBPF_rules_selector_state_reg, VeBPF_rules_selector_state_next;
reg [NUMBER_OF_VEBPF - 1:0] VeBPF_available_array_reg, VeBPF_available_array_next;

wire [NUMBER_OF_VEBPF - 1:0] VeBPF_combined_rule_selector_result_tracker_available_array;

// bitwise &
assign VeBPF_combined_rule_selector_result_tracker_available_array = VeBPF_result_tracker_available_array_reg;
// assign VeBPF_combined_rule_selector_result_tracker_available_array = VeBPF_available_array_reg | VeBPF_result_tracker_available_array_reg;
// assign VeBPF_combined_rule_selector_result_tracker_available_array = ~VeBPF_result_tracker_run_VeBPF_in_reg;
// assign VeBPF_combined_rule_selector_result_tracker_available_array = VeBPF_available_array_reg;
// assign VeBPF_combined_rule_selector_result_tracker_available_array = VeBPF_available_array_reg & VeBPF_result_tracker_available_array_reg;
// assign VeBPF_combined_rule_selector_result_tracker_available_array = VeBPF_available_array_reg & VeBPF_result_tracker_available_array_reg;
    // dont need VeBPF_available_array_reg here since the rule selector fsm can not track each separate VeBPF
    // since this fsm is busy tracking the rules being uploaded and run
    // result tracker fsm is what truly tracks avalaibility of VeBPFs, so we're gona use that!

// array for storing VeBPF index values for arbitration, e.g., at idx 0 value will be 0, at idx 3 value will be 3
// reg [BITS_NEDED_FOR_NUMBER_OF_VEBPF - 1:0] VeBPF_rules_selector_idx_array_reg [NUMBER_OF_VEBPF - 1:0];

reg [BITS_NEDED_FOR_NUMBER_OF_VEBPF - 1:0] VeBPF_id_selected;
reg [BITS_NEDED_FOR_NUMBER_OF_VEBPF - 1:0] VeBPF_id_selected_last_saved_reg, VeBPF_id_selected_last_saved_next;

// S_COUNT = NUM_OF_VEBPF

// localparam ARB_TYPE = "PRIORITY";
// localparam LSB_PRIORITY = "HIGH";
// localparam S_COUNT = NUMBER_OF_VEBPF;


// // vebpf selector arbitrer signals
// wire [S_COUNT - 1:0] request_arb_vebpf_selector_in;
// wire [S_COUNT - 1:0] acknowledge_arb_vebpf_selector_in;
// wire [S_COUNT - 1:0] grant_arb_vebpf_selector_out;
// wire grant_valid_arb_vebpf_selector_out;

// flag for activating VeBPF selection request
reg [NUMBER_OF_VEBPF - 1:0] request_arb_vebpf_selector_in_activation_flag;

// assign request_arb_vebpf_selector_in = ((VeBPF_available_array_reg & ~grant_arb_vebpf_selector_out) & request_arb_vebpf_selector_in_activation_flag);
// assign request_arb_vebpf_selector_in = ((VeBPF_result_tracker_available_array_reg
                                        // & ~grant_arb_vebpf_selector_out) & request_arb_vebpf_selector_in_activation_flag); 
// assign request_arb_vebpf_selector_in = ((VeBPF_combined_rule_selector_result_tracker_available_array 
                                        // & ~grant_arb_vebpf_selector_out) & request_arb_vebpf_selector_in_activation_flag);

// assign request_arb_vebpf_selector_in = (({1'b0, VeBPF_result_tracker_available_array_reg} 
//                                         & (~grant_arb_vebpf_selector_out)) & {1'b0, request_arb_vebpf_selector_in_activation_flag});


assign request_arb_vebpf_selector_in = (({1'b0, VeBPF_combined_rule_selector_result_tracker_available_array} 
                                        & (~grant_arb_vebpf_selector_out)) & {1'b0, request_arb_vebpf_selector_in_activation_flag});




// assign acknowledge_arb_vebpf_selector_in = grant_arb_vebpf_selector_out;
// assign acknowledge_arb_vebpf_selector_in = grant_arb_vebpf_selector_out & VeBPF_result_tracker_available_array_reg;
// assign acknowledge_arb_vebpf_selector_in = grant_arb_vebpf_selector_out & (VeBPF_available_array_reg | VeBPF_result_tracker_available_array_reg);

assign acknowledge_arb_vebpf_selector_in = grant_arb_vebpf_selector_out & {1'b0, VeBPF_result_tracker_available_array_reg};

// assign acknowledge_arb_vebpf_selector_in = grant_arb_vebpf_selector_out & {1'b0, VeBPF_available_array_reg};
// assign acknowledge_arb_vebpf_selector_in = grant_arb_vebpf_selector_out & VeBPF_available_array_reg;
    // dont need VeBPF_available_array_reg here since the rule selector fsm can not track each separate VeBPF
    // since this fsm is busy tracking the rules being uploaded and run
    // result tracker fsm is what truly tracks avalaibility of VeBPFs, so we're gona use that!

// 6 bits atm.. max rules can be 64 .. 0 - 63
// VeBPF_rules_selector_total_rules_uploaded_reg is for keeping track of how many rules have been tested 
// and ran on a chosen rxpkt
reg [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS-1:0] VeBPF_rules_selector_total_rules_uploaded_reg, VeBPF_rules_selector_total_rules_uploaded_next;

reg [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS:0] VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg, VeBPF_rules_selector_rules_scheduler_table_rd_ptr_next;

reg VeBPF_rules_selector_rules_scheduler_table_read_en;

// array to store which VEBPF is running which RULE.. at idx of VEBPPF selected "VeBPF_id_selected", we will save
// RULE num being run for 1st Rule, the rule num will be the index "0", for 2nd rule the rule num will be 1..
// basically the rd pointer for schedular table "VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg"
reg [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS-1:0] rules_selected_for_VeBPF_array [NUMBER_OF_VEBPF - 1:0];
reg rules_selected_for_VeBPF_array_wr_en;
wire [VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX_TOTAL_BITS-1:0] rule_number_id_currently_selected_for_VeBPF;

// same as the rules_selector 
assign rule_number_id_currently_selected_for_VeBPF = VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg;

integer i_VeBPF_avail;
 
reg [VEBPF_RULES_FIFO_DEPTH_ADDRESS_WIDTH-1:0] VeBPF_rules_selector_current_rule_start_ptr_reg;

reg [VEBPF_PROG_ADDRESS_WIDTH-1:0] VeBPF_ip_next_rule_rules_selector_in_reg, VeBPF_ip_next_rule_rules_selector_in_next;
wire [VEBPF_PROG_ADDRESS_WIDTH-1:0] VeBPF_ip_next_rule_rules_selector_in;
assign VeBPF_ip_next_rule_rules_selector_in = VeBPF_ip_next_rule_rules_selector_in_reg;

reg [NUMBER_OF_VEBPF - 1:0] VeBPF_run_next_selected_rule_en_rules_selector_in_reg, VeBPF_run_next_selected_rule_en_rules_selector_in_next;
wire [NUMBER_OF_VEBPF - 1:0] VeBPF_run_next_selected_rule_en_rules_selector_in;
assign VeBPF_run_next_selected_rule_en_rules_selector_in = VeBPF_run_next_selected_rule_en_rules_selector_in_reg;

// run rule req array for rule selector FSM that the result tracker FSM will recieve and acknowledge
reg [NUMBER_OF_VEBPF - 1:0] VeBPF_rules_selector_run_rule_req_array_reg, VeBPF_rules_selector_run_rule_req_array_next;

reg VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag;

reg VeBPF_rule_selector_and_result_tracker_rxpkt_error_flag_reg, VeBPF_rule_selector_and_result_tracker_rxpkt_error_flag_next;

reg VeBPF_rule_selector_waiting_for_next_rxpkt_flag_reg, VeBPF_rule_selector_waiting_for_next_rxpkt_flag_next;

localparam ARB_TYPE = "PRIORITY";
localparam LSB_PRIORITY = "HIGH";
localparam BLOCK_TYPE = "ACKNOWLEDGE";

// if (NUMBER_OF_VEBPF == 1) begin 
//     localparam S_COUNT = NUMBER_OF_VEBPF + 1;
// end else begin
//     localparam S_COUNT = NUMBER_OF_VEBPF; 
// end
localparam S_COUNT = NUMBER_OF_VEBPF + 1;
// localparam S_COUNT;
// if (NUMBER_OF_VEBPF == 1) begin 
//     S_COUNT = NUMBER_OF_VEBPF + 1;
// end else begin
//     S_COUNT = NUMBER_OF_VEBPF; 
// end

// vebpf selector arbitrer signals
wire [S_COUNT - 1:0] request_arb_vebpf_selector_in;
wire [S_COUNT - 1:0] acknowledge_arb_vebpf_selector_in;
wire [S_COUNT - 1:0] grant_arb_vebpf_selector_out;
wire grant_valid_arb_vebpf_selector_out;

wire [$clog2(S_COUNT) - 1:0] grant_encoded_arb_vebpf_selector_out;

// assign grant_arb_vebpf_selector_out = request_arb_vebpf_selector_in;


// arbiter instance
arbiter_z1 #(  // S_COUNT should be > 1
    .PORTS(S_COUNT),  // S_COUNT = NUMBER_OF_VEBPF
    // arbitration type: "PRIORITY" or "ROUND_ROBIN"
    .TYPE(ARB_TYPE),
    // block type: "NONE", "REQUEST", "ACKNOWLEDGE"
    .BLOCK(BLOCK_TYPE),
    // LSB priority: "LOW", "HIGH"
    .LSB_PRIORITY(LSB_PRIORITY)

    // arbitration type: "PRIORITY" or "ROUND_ROBIN"
    // parameter ARB_TYPE = "PRIORITY",
    // // LSB priority: "LOW", "HIGH"
    // parameter LSB_PRIORITY = "HIGH"
)
vebpf_selector_arb_inst (
    .clk(clk),
    .rst(rst),
    .request(request_arb_vebpf_selector_in),                 //input wire [S_COUNT-1:0] request_arb_vebpf_selector_in; // request_arb_vebpf_selector_in becomes b'10 at 1.646
    // assign request_arb_vebpf_selector_in = s_axis_tvalid & ~grant_arb_vebpf_selector_out;  // bitwise!! :3
        // request_arb_vebpf_selector_in becomes b'10 at 1.646 cx s_axis_tvalid[1] becoms 1 and ~grant_arb_vebpf_selector_out = b'11 cx grant_arb_vebpf_selector_out = b'00 initially
        // s_axis_tvalid becomes b'10 at 1.646 us and stays at this value till 1.654 us (2 clks) but since
        // request_arb_vebpf_selector_in is s_axis_tvalid & with ~grant_arb_vebpf_selector_out, request_arb_vebpf_selector_in becomes b'00 after 1 clk cycle at 1.650 us, that is why 
        // &-ing with ~grant_arb_vebpf_selector_out is vital
        // grant_arb_vebpf_selector_out becomes b'10 at 1.650 us
    
    .acknowledge(acknowledge_arb_vebpf_selector_in),         //input wire [S_COUNT-1:0] acknowledge_arb_vebpf_selector_in
    // acknowledge_arb_vebpf_selector_in becomes b'10 from b'00 at 1.650 us cx now grant_arb_vebpf_selector_out = b'10 at 1.650 us
        // I believe acknowledge_arb_vebpf_selector_in is required by arbitrer, when the arbitrer receives 
        // acknowledge_arb_vebpf_selector_in then it moves on to grant_arb_vebpf_selector_outing the next request_arb_vebpf_selector_in, but then I believe 
        // the previous request_arb_vebpf_selector_in should become LOW then, otherwise the prev request_arb_vebpf_selector_in would
        // be given the grant_arb_vebpf_selector_out again cx it would be at the HIGHER priority position
    // assign acknowledge_arb_vebpf_selector_in = grant_arb_vebpf_selector_out & s_axis_tvalid & s_axis_tready & s_axis_tlast;  // tlast means that whole pkt has passed so ack it
        // acknowledge_arb_vebpf_selector_in becomes b'10 from b'00 at 1.650 us cx now grant_arb_vebpf_selector_out = b'10 at 1.650 us
        // s_axis_tvalid[1] becoms 1 at 1.646 us
        // s_axis_tready becomes b'10 at 1.650 us cx its value depends on grant_valid_arb_vebpf_selector_out and grant_encoded_arb_vebpf_selector_out
        // also ack need tready to be 1 for it to be 1, since ack means that grant_arb_vebpf_selector_out has been received
        // which is only possible when tready is 1 for that grant_arb_vebpf_selector_out
            // s_axis_tready is output (tready means that current module is ready to take in data)
            // s_axis_tvalid is input (valid data is incoming) 
    // assign s_axis_tready = (m_axis_tready_int_reg && grant_valid_arb_vebpf_selector_out) << grant_encoded_arb_vebpf_selector_out;
        // s_axis_tready is output
        // m_axis_tready_int_reg = 1 initially
        // grant_encoded_arb_vebpf_selector_out is 1 at 1.650 us
        // grant_encoded_arb_vebpf_selector_out is 1 when grant_arb_vebpf_selector_out is 10 and grant_encoded_arb_vebpf_selector_out is 0 when grant_arb_vebpf_selector_out is 01 
        // grant_valid_arb_vebpf_selector_out is 1 at 1.650 us

    .grant(grant_arb_vebpf_selector_out),                    //output wire [S_COUNT-1:0] grant_arb_vebpf_selector_out;  // .S_COUNT(2),
    // here output is grant_arb_vebpf_selector_out b'10 at 1.650 us

    .grant_valid(grant_valid_arb_vebpf_selector_out),       //output wire grant_valid_arb_vebpf_selector_out;
    // here output is grant_valid_arb_vebpf_selector_out_reg 1 at 1.650 us

    .grant_encoded(grant_encoded_arb_vebpf_selector_out)       //output grant_encoded_arb_vebpf_selector_out 1 bit
    // here output is grant_encoded_arb_vebpf_selector_out_reg 1 at 1.650 us
);

// generate

//     if (NUMBER_OF_VEBPF == 1) begin

//         assign grant_arb_vebpf_selector_out = request_arb_vebpf_selector_in;

//     end else if (NUMBER_OF_VEBPF > 1) begin

//         // localparam ARB_TYPE = "PRIORITY";
//         // localparam LSB_PRIORITY = "HIGH";
//         // // localparam S_COUNT = NUMBER_OF_VEBPF;

//         wire [$clog2(S_COUNT) - 1:0] grant_encoded_arb_vebpf_selector_out;


//         // arbiter instance
//         arbiter_z1 #(  // S_COUNT should be > 1
//             .PORTS(S_COUNT),  // S_COUNT = NUMBER_OF_VEBPF
//             // arbitration type: "PRIORITY" or "ROUND_ROBIN"
//             .TYPE(ARB_TYPE),
//             // block type: "NONE", "request_arb_vebpf_selector_in", "acknowledge_arb_vebpf_selector_in"
//             .BLOCK("acknowledge_arb_vebpf_selector_in"),
//             // LSB priority: "LOW", "HIGH"
//             .LSB_PRIORITY(LSB_PRIORITY)

//             // arbitration type: "PRIORITY" or "ROUND_ROBIN"
//             // parameter ARB_TYPE = "PRIORITY",
//             // // LSB priority: "LOW", "HIGH"
//             // parameter LSB_PRIORITY = "HIGH"
//         )
//         vebpf_selector_arb_inst (
//             .clk(clk),
//             .rst(rst),
//             .request(request_arb_vebpf_selector_in),                 //input wire [S_COUNT-1:0] request_arb_vebpf_selector_in; // request_arb_vebpf_selector_in becomes b'10 at 1.646
//             // assign request_arb_vebpf_selector_in = s_axis_tvalid & ~grant_arb_vebpf_selector_out;  // bitwise!! :3
//                 // request_arb_vebpf_selector_in becomes b'10 at 1.646 cx s_axis_tvalid[1] becoms 1 and ~grant_arb_vebpf_selector_out = b'11 cx grant_arb_vebpf_selector_out = b'00 initially
//                 // s_axis_tvalid becomes b'10 at 1.646 us and stays at this value till 1.654 us (2 clks) but since
//                 // request_arb_vebpf_selector_in is s_axis_tvalid & with ~grant_arb_vebpf_selector_out, request_arb_vebpf_selector_in becomes b'00 after 1 clk cycle at 1.650 us, that is why 
//                 // &-ing with ~grant_arb_vebpf_selector_out is vital
//                 // grant_arb_vebpf_selector_out becomes b'10 at 1.650 us
            
//             .acknowledge(acknowledge_arb_vebpf_selector_in),         //input wire [S_COUNT-1:0] acknowledge_arb_vebpf_selector_in
//             // acknowledge_arb_vebpf_selector_in becomes b'10 from b'00 at 1.650 us cx now grant_arb_vebpf_selector_out = b'10 at 1.650 us
//                 // I believe acknowledge_arb_vebpf_selector_in is required by arbitrer, when the arbitrer receives 
//                 // acknowledge_arb_vebpf_selector_in then it moves on to grant_arb_vebpf_selector_outing the next request_arb_vebpf_selector_in, but then I believe 
//                 // the previous request_arb_vebpf_selector_in should become LOW then, otherwise the prev request_arb_vebpf_selector_in would
//                 // be given the grant_arb_vebpf_selector_out again cx it would be at the HIGHER priority position
//             // assign acknowledge_arb_vebpf_selector_in = grant_arb_vebpf_selector_out & s_axis_tvalid & s_axis_tready & s_axis_tlast;  // tlast means that whole pkt has passed so ack it
//                 // acknowledge_arb_vebpf_selector_in becomes b'10 from b'00 at 1.650 us cx now grant_arb_vebpf_selector_out = b'10 at 1.650 us
//                 // s_axis_tvalid[1] becoms 1 at 1.646 us
//                 // s_axis_tready becomes b'10 at 1.650 us cx its value depends on grant_valid_arb_vebpf_selector_out and grant_encoded_arb_vebpf_selector_out
//                 // also ack need tready to be 1 for it to be 1, since ack means that grant_arb_vebpf_selector_out has been received
//                 // which is only possible when tready is 1 for that grant_arb_vebpf_selector_out
//                     // s_axis_tready is output (tready means that current module is ready to take in data)
//                     // s_axis_tvalid is input (valid data is incoming) 
//             // assign s_axis_tready = (m_axis_tready_int_reg && grant_valid_arb_vebpf_selector_out) << grant_encoded_arb_vebpf_selector_out;
//                 // s_axis_tready is output
//                 // m_axis_tready_int_reg = 1 initially
//                 // grant_encoded_arb_vebpf_selector_out is 1 at 1.650 us
//                 // grant_encoded_arb_vebpf_selector_out is 1 when grant_arb_vebpf_selector_out is 10 and grant_encoded_arb_vebpf_selector_out is 0 when grant_arb_vebpf_selector_out is 01 
//                 // grant_valid_arb_vebpf_selector_out is 1 at 1.650 us

//             .grant(grant_arb_vebpf_selector_out),                    //output wire [S_COUNT-1:0] grant_arb_vebpf_selector_out;  // .S_COUNT(2),
//             // here output is grant_arb_vebpf_selector_out b'10 at 1.650 us

//             .grant_valid(grant_valid_arb_vebpf_selector_out),       //output wire grant_valid_arb_vebpf_selector_out;
//             // here output is grant_valid_arb_vebpf_selector_out_reg 1 at 1.650 us

//             .grant_encoded(grant_encoded_arb_vebpf_selector_out)       //output grant_encoded_arb_vebpf_selector_out 1 bit
//             // here output is grant_encoded_arb_vebpf_selector_out_reg 1 at 1.650 us
//         );

//     end

// endgenerate

// Seq part of VeBPF RULES SELECTOR FSM!
always @(posedge clk) begin

    if (rst) begin
        
        VeBPF_rules_selector_state_reg <= VEBPF_RULES_SELECTOR_FSM_STATE_IDLE;

        // reset all available VeBPFs to 1 since all VeBPFs are available at the start
            // https://docs.xilinx.com/r/en-US/ug901-vivado-synthesis/Assigning-an-Initial-Value-to-a-Register
        // for (i_VeBPF_avail = 0; i_VeBPF_avail < NUMBER_OF_VEBPF; i_VeBPF_avail = i_VeBPF_avail + 1) begin
        //     // VeBPF_available_array_reg[i_VeBPF_avail] <= 1;  // got replaced with better logic below
        //     VeBPF_rules_selector_idx_array_reg[i_VeBPF_avail] <= i_VeBPF_avail;
                    // dont need this cx VeBPF_id_selected = i_VeBPF_id_select
        // end

        // VeBPF_available_array_reg <= {NUMBER_OF_VEBPF{1'b1}};

        VeBPF_rules_selector_total_rules_uploaded_reg <= 0;

        VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg <= 0;

        // VeBPF_rules_selector_current_rule_start_ptr_reg <= 0;

        VeBPF_ip_next_rule_rules_selector_in_reg <= 0;

        VeBPF_run_next_selected_rule_en_rules_selector_in_reg <= 0;

        VeBPF_rules_selector_run_rule_req_array_reg <= 0;

        VeBPF_id_selected_last_saved_reg <= 0;

        VeBPF_rule_selector_and_result_tracker_rxpkt_error_flag_reg <= 0;

        VeBPF_rule_selector_waiting_for_next_rxpkt_flag_reg <= 0;

        // VeBPF_rule_selector_reset_flag_Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot_reg <= 0;


    end else begin
        
        // VeBPF_available_array_reg <= VeBPF_available_array_next;

        VeBPF_rules_selector_state_reg <= VeBPF_rules_selector_state_next;

        VeBPF_rules_selector_total_rules_uploaded_reg <= VeBPF_rules_selector_total_rules_uploaded_next;

        VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg <= VeBPF_rules_selector_rules_scheduler_table_rd_ptr_next;

        // rules_selected_for_VeBPF_array_wr_en is HIGH when correct (non-incremented value) of rd ptr i.e., rule num id 
        if (rules_selected_for_VeBPF_array_wr_en) begin

            rules_selected_for_VeBPF_array[VeBPF_id_selected] <= rule_number_id_currently_selected_for_VeBPF;

        end

        VeBPF_ip_next_rule_rules_selector_in_reg <= VeBPF_ip_next_rule_rules_selector_in_next;

        VeBPF_run_next_selected_rule_en_rules_selector_in_reg <= VeBPF_run_next_selected_rule_en_rules_selector_in_next;

        VeBPF_rules_selector_run_rule_req_array_reg <= VeBPF_rules_selector_run_rule_req_array_next; 

        VeBPF_id_selected_last_saved_reg <= VeBPF_id_selected_last_saved_next;
        
        VeBPF_rule_selector_and_result_tracker_rxpkt_error_flag_reg <= VeBPF_rule_selector_and_result_tracker_rxpkt_error_flag_next;

        VeBPF_rule_selector_waiting_for_next_rxpkt_flag_reg <= VeBPF_rule_selector_waiting_for_next_rxpkt_flag_next;

        // VeBPF_rule_selector_reset_flag_Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot_reg <= VeBPF_rule_selector_reset_flag_Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot_next;

    end

end

integer i_VeBPF_id_select;

// Comb block for stuff other than VeBPF RULES SELECTOR FSM
always @(*) begin

    VeBPF_id_selected = 0; // default value
        // this default value isn't showing up in simulation instead XXX is showing up
        // since nothing was assigned in for loop outside the if condition
            // I believe since this is a @(*) block, nothing here is changing at the start,
            // hence VeBPF_id_selected wasn't assigned a value until grant_arb_vebpf_selector_out changed

    for (i_VeBPF_id_select = 0; i_VeBPF_id_select < NUMBER_OF_VEBPF; i_VeBPF_id_select = i_VeBPF_id_select + 1) begin 

        // if a certain VeBPF was available and it was given the grant signal, this cond would become True
        if (grant_arb_vebpf_selector_out[i_VeBPF_id_select]) begin

            // VeBPF_id_selected will stay the same till the next VeBPF is selected after arbitration
            // VeBPF_id_selected = VeBPF_rules_selector_idx_array_reg[i_VeBPF_id_select];  
                // can also be, VeBPF_id_selected = i_VeBPF_id_select
                    // let me try then 

            VeBPF_id_selected = i_VeBPF_id_select; 

        end 

    end 

end

// Comb part of VeBPF RULES SELECTOR FSM!
always @(*) begin

    VeBPF_rules_selector_state_next = VeBPF_rules_selector_state_reg;

    request_arb_vebpf_selector_in_activation_flag = {NUMBER_OF_VEBPF{1'b0}};

    VeBPF_available_array_next = VeBPF_available_array_reg;

    VeBPF_rules_selector_total_rules_uploaded_next = VeBPF_rules_selector_total_rules_uploaded_reg;

    VeBPF_rules_selector_rules_scheduler_table_rd_ptr_next = VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg;

    VeBPF_rules_selector_rules_scheduler_table_read_en = 0;

    VeBPF_ip_next_rule_rules_selector_in_next = VeBPF_ip_next_rule_rules_selector_in_reg;

    VeBPF_run_next_selected_rule_en_rules_selector_in_next = VeBPF_run_next_selected_rule_en_rules_selector_in_reg;

    VeBPF_rules_selector_run_rule_req_array_next = VeBPF_rules_selector_run_rule_req_array_reg;

    VeBPF_id_selected_last_saved_next = VeBPF_id_selected_last_saved_reg;

    VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag = 0;

    VeBPF_rule_selector_and_result_tracker_rxpkt_error_flag_next = VeBPF_rule_selector_and_result_tracker_rxpkt_error_flag_reg;

    // VeBPF_rule_selector_reset_flag_Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot_next = VeBPF_rule_selector_reset_flag_Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot_reg;

    rules_selected_for_VeBPF_array_wr_en = 0;

    VeBPF_rule_selector_waiting_for_next_rxpkt_flag_next = VeBPF_rule_selector_waiting_for_next_rxpkt_flag_reg;

    // check if a valid result has been received by the RESULT EVALUATOR FSM
    if (VeBPF_result_evaluator_stop_VeBPF_processing_flag_reg) begin

        VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_NEXT_RX_PKT_HDR;

        // 2) raise a flag that processing/filtering of the current rxpkthdr has been completed
        // so that VeBPF_data_loading_done_flag_reg becomes 0 in the next clk cycle
        VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag = 1;

        // checking if there was any error flag in any of the rule results of the filtered rxpkt
        VeBPF_rule_selector_and_result_tracker_rxpkt_error_flag_next = VeBPF_result_tracker_rxpkt_error_flag_reg;

    end else begin

        case (VeBPF_rules_selector_state_reg)

            VEBPF_RULES_SELECTOR_FSM_STATE_IDLE: begin

                VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_IDLE;

                VeBPF_rule_selector_waiting_for_next_rxpkt_flag_next = 0;

                // VeBPF_rule_selector_reset_flag_Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot_next = 0;

                // first of all we check if there is a rxpkthdr available in all VeBPFs data mems to process/filter
                if (VeBPF_data_loading_done_flag_reg) begin

                    // then we check if all rules have been uploaded into all VeBPFs pgm mems
                    if (VeBPF_rules_scheduler_all_rules_uploaded_flag) begin

                        // then we check if the total rules uploaded/run on the VeBPF is less than total rules uploaded/required to be run
                        // for the current rxpkt
                            // TODO -> DONE (in other fsm): also add a flag here that checks if any result gave an error or "skip other rules" result
                            // then skip this if cond  block and go to else so that next RxPktHdr can be uploaded to all VeBPFs
                        if (VeBPF_rules_selector_total_rules_uploaded_reg < VeBPF_rules_scheduler_total_num_rules_uploaded_reg) begin
                        // if (VeBPF_rules_selector_total_rules_uploaded_reg <= VeBPF_rules_scheduler_total_num_rules_uploaded_reg) begin
                        // if (VeBPF_rules_selector_total_rules_uploaded_reg < VeBPF_rules_scheduler_total_num_rules_uploaded_reg) begin
                            // DONE: this should be <= instead of <.. nah < was correct
                            // uploading (i.e., changing ip of VeBPF pgm mem) the 1st rule at the start after rst.
                            // so even if VeBPF_rules_scheduler_total_num_rules_uploaded_reg = 1, this cond will be run
                            // increment this VeBPF_rules_selector_total_rules_uploaded_reg after the rule run signal has been 
                            // sent to rules tracker FSM and acknowledged.

                            // TODO: set conditions and counter resets if new set of VeBPF rules are uploaded when
                            // VeBPF_rules_selector_state_reg is not in IDLE state
                                // or can I just RESET the network subsystem for uploading a fresh set of VeBPF rules?
                            
                            VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_VEBPF_ARBITRATION_REQUEST;

                        // in the else condition of this if block we check that if total rules uploaded/run
                        // on the VeBPFs get equal to the total rules uploaded/required to be run OR a certain result of a certain rule 
                        // requires the other rules to be skipped (other RULES aren't required to be checked anymore), we move to
                        // state STORING VEBPF RESULTS where we:
                            // 1) increment the wr_ptr_desc_table_rx_pkt_result for storing the N (N = max Rules) results of the next rx pkt 
                            // 2) raise a flag that processing/filtering of the current rxpkthdr has been completed, so VeBPF data loading FSM 
                            // that is waiting for this flag can proceed to loading the next rxpkthdr data in all VeBPF data mems, while  
                            // pulling down VeBPF_data_loading_done_flag_reg and this same flag after going to 0 will cause this Rules Selector FSM
                            // to go into IDLE state and wait for the next rxpkthdr data to be "done" loading into all VeBPFs data mems, i.e.,
                            // the same VeBPF_data_loading_done_flag_reg going to 1.
                        
                        
                        end else begin

                            // if VeBPF_rules_selector_total_rules_uploaded_reg == VeBPF_rules_scheduler_total_num_rules_uploaded_reg, then wait 
                            // for that last rule to be finished processing by one of the VeBPFs

                            // wait for VeBPFs to finish processig all RULES
                            VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_VEBPF_RESULTS;

                         

                        // end else begin

                        //     // VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_IDLE;
                            
                        //     // check if VeBPFs have FINISHED processing ALL RULES
                        //     if (&(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg)) begin
                        //     // if (&(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_next)) begin
                        //     // if (&(Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot[(VeBPF_rules_scheduler_total_num_rules_uploaded_reg-1):0])) begin
                        //       // cant do index slicing using a variable reg as it can't be synthesized
                        //         VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_NEXT_RX_PKT_HDR;

                        //         // 2) raise a flag that processing/filtering of the current rxpkthdr has been completed
                        //         // so that VeBPF_data_loading_done_flag_reg becomes 0 in the next clk cycle
                        //         VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag = 1;
                        //             // 1) increment the wr_ptr_desc_table_rx_pkt_result for storing the N (N = max Rules) results of the next rx pkt 
                        //                 // This point above is happening in the vebpf data loading FSM when it receives this flag 
                        //                 // VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag

                        //         // checking if there was any error flag in any of the rule results of the filtered rxpkt
                        //         VeBPF_rule_selector_and_result_tracker_rxpkt_error_flag_next = VeBPF_result_tracker_rxpkt_error_flag_reg;

                        //         // reset all bits of Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot
                        //         // VeBPF_rule_selector_reset_flag_Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot_next = 1;

                        //     end else begin

                        //         // wait for VeBPFs to finish processig all RULES
                        //         VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_VEBPF_RESULTS; 


                        //     end 

                        
                        // end

                        end 

                    end 

                end   

            end


            VEBPF_RULES_SELECTOR_FSM_STATE_VEBPF_ARBITRATION_REQUEST: begin 

                VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_VEBPF_ARBITRATION_REQUEST;

                // req to get an available VeBPF activated
                request_arb_vebpf_selector_in_activation_flag = {NUMBER_OF_VEBPF{1'b1}};

                // initially after rst VeBPF_available_array_reg is all 1s, so all VeBPFs are available,
                // but they will become unavailable as soon as a VeBPF rule is selected to run on that VeBPF

                // grant for a specific VeBPF # is receveid in grant_arb_vebpf_selector_out
                // and its idx is VeBPF_id_selected

                // VeBPF_available_array_next = VeBPF_result_tracker_available_array_reg;

                // if grant for any of the VeBPFs got HIGH
                if (grant_arb_vebpf_selector_out) begin

                    // if (VeBPF_rules_selector_total_rules_uploaded_reg >= VeBPF_rules_scheduler_total_num_rules_uploaded_reg) begin

                    //     VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_VEBPF_RESULTS;

                    // end else begin

                    // the above if condition is commented out cx its been taken care of in idle state 

                    // grant was received for VeBPF_id_selected indexed VeBPF,
                    // make that particular indexed VeBPF unavailable in the next clk cycle cx the _reg version is 
                    // used in the assign req statement
                    // VeBPF_available_array_next[VeBPF_id_selected] = 0;

                    // save VeBPF_id_selected in the reg VeBPF_id_selected_last_saved_reg since it will be
                    // 0 after we pull down request_arb_vebpf_selector_in_activation_flag in this cycle
                    VeBPF_id_selected_last_saved_next = VeBPF_id_selected;

                    // deactivate the grant request
                    request_arb_vebpf_selector_in_activation_flag = {NUMBER_OF_VEBPF{1'b0}};

                    // saving which VeBPF is running which rule currently (in rules_selected_for_VeBPF_array) by making this wr en HIGH
                    rules_selected_for_VeBPF_array_wr_en = 1;

                    VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_LOAD_SELECTED_RULE_START_PTR;

                
                end

                // end  

            end

            VEBPF_RULES_SELECTOR_FSM_STATE_LOAD_SELECTED_RULE_START_PTR: begin 

                // VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_LOAD_SELECTED_RULE_START_PTR;

                // if rules scheduler FSM isn't reading from same memory, which shouldn't be possible but just for safety
                // and there can be 2 read ports anyway (but not 2 read and 1 write port cx total ports can be 2)
                // if (!VeBPF_rules_uploader_rules_scheduler_table_read_en) begin 
                    // TODO -> DONE : remove this if cond above because it shouldnt be possible anyway
                
                // read rules scheduler table meta data for start ptr = ip_next for the selected rule
                // based on value of VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg
                VeBPF_rules_selector_rules_scheduler_table_read_en = 1;

                // increment VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg to next rule
                // note that rd ptr always starts at 0, i.e., the 1st rule idx and will move toward total_rules - 1 index
                VeBPF_rules_selector_rules_scheduler_table_rd_ptr_next = VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg + 1;

                VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_UPDATE_IP_NEXT_TO_SELECTED_RULE_IN_VEBPF;

                // end

            end

            VEBPF_RULES_SELECTOR_FSM_STATE_UPDATE_IP_NEXT_TO_SELECTED_RULE_IN_VEBPF: begin

                VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_UPDATE_IP_NEXT_TO_SELECTED_RULE_IN_VEBPF_DONE;

                // reprogram the VeBPF that was granted the turn to be reprogrammed by arbitrer at id = VeBPF_id_selected_last_saved_reg
                VeBPF_run_next_selected_rule_en_rules_selector_in_next[VeBPF_id_selected_last_saved_reg] = 1;

                // update ip_next for reprogramming the VeBPF
                VeBPF_ip_next_rule_rules_selector_in_next = VeBPF_rules_selector_current_rule_start_ptr_reg;
                    // 1 clk to update VeBPF_rules_selector_current_rule_start_ptr_reg

                // increment the total rules uploaded reg here since the VeBPF has been reprogrammed in this state
                // and this uploaded VeBPF rule will be run on the selected (VeBPF_id_selected_last_saved_reg) VeBPF
                // in the next state
                VeBPF_rules_selector_total_rules_uploaded_next = VeBPF_rules_selector_total_rules_uploaded_reg + 1;


            end

            VEBPF_RULES_SELECTOR_FSM_STATE_UPDATE_IP_NEXT_TO_SELECTED_RULE_IN_VEBPF_DONE: begin 

                VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_UPDATE_IP_NEXT_TO_SELECTED_RULE_IN_VEBPF_DONE;

                // pull down enable and ip_next_rule

                // VeBPF_run_next_selected_rule_en_rules_selector_in_next[VeBPF_id_selected_last_saved_reg] = 0;
                // VeBPF_ip_next_rule_rules_selector_in_next = 0;
                    // cannot pull these down cx if they are pulled down while VeBPF is in reset state,
                    // the ip_next will be reset to 0.
                    // so these will be pulled down after reset for the VeBPF has be deactivated

                // req result tracker fsm to run the rule on the selected VeBPF at id VeBPF_id_selected_last_saved_reg
                VeBPF_rules_selector_run_rule_req_array_next[VeBPF_id_selected_last_saved_reg] = 1;

                // ack received from result tracker fsm that the selected rule for VeBPF at id VeBPF_id_selected_last_saved_reg has been run
                if (VeBPF_result_tracker_run_rule_ack_array_reg[VeBPF_id_selected_last_saved_reg]) begin
                    
                    VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_IDLE;
                        // upload and run next rule :) ..look at notes again
                        // rd_ptr already updated for that.. and total rules uploaded also incremented

                    // pull down run rule req since result tracker fsm is now running the chosen rule at the selected 
                    // VeBPF at id VeBPF_id_selected_last_saved_reg
                    VeBPF_rules_selector_run_rule_req_array_next[VeBPF_id_selected_last_saved_reg] = 0;

                    // after ack from result tracker fsm is received for VeBPF_id_selected_last_saved_reg, then we can 
                    // pull down the ip_next and run_next_selected_rule_en signals because the reset has
                    // been deactivated for that VeBPF at id VeBPF_id_selected_last_saved_reg and we don't need to 
                    // keep value of these signals high so that they dont get reset by the active reset 

                    // pull down run_next_selected_rule_en and ip_next_rule
                        // we are able to pull these down because the chosen VeBPF would already have been updated
                        // with the new ip_next and would have started running the new Rule since reset got deactivated
                        // in this cycle
                    VeBPF_run_next_selected_rule_en_rules_selector_in_next[VeBPF_id_selected_last_saved_reg] = 0;
                    VeBPF_ip_next_rule_rules_selector_in_next = 0;
                        // these enables are 0 and on the next clk cycle while reset is deactivated on this clk cycle
                        // since reset is already deactivated on this cycle, the VeBPF will start running the selected
                        // rule at ip_next that was updated in previous state and now in the next clk cycle
                        // ip_next and run_next_selected_rule_en are pulled down that don't matter 

                end 

            end

            VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_VEBPF_RESULTS: begin

                // wait for VeBPFs to finish processig all RULES
                VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_VEBPF_RESULTS;

                // check if VeBPFs have FINISHED processing ALL RULES or a valid result has been received by the RESULT EVALUATOR FSM
                if ((&(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg)) || VeBPF_result_evaluator_stop_VeBPF_processing_flag_reg) begin
                // check if VeBPFs have FINISHED processing ALL RULES
                // if (&(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg)) begin
                // if (&(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_next)) begin
                // if (&(Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot[(VeBPF_rules_scheduler_total_num_rules_uploaded_reg-1):0])) begin
                  // cant do index slicing using a variable reg as it can't be synthesized

                    VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_NEXT_RX_PKT_HDR;

                    // 2) raise a flag that processing/filtering of the current rxpkthdr has been completed
                    // so that VeBPF_data_loading_done_flag_reg becomes 0 in the next clk cycle
                    VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag = 1;
                        // 1) increment the wr_ptr_desc_table_rx_pkt_result for storing the N (N = max Rules) results of the next rx pkt 
                            // This point above is happening in the vebpf data loading FSM when it receives this flag 
                            // VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag

                    // checking if there was any error flag in any of the rule results of the filtered rxpkt
                    VeBPF_rule_selector_and_result_tracker_rxpkt_error_flag_next = VeBPF_result_tracker_rxpkt_error_flag_reg;

                    // reset all bits of Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot
                    // VeBPF_rule_selector_reset_flag_Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot_next = 1;

                end 


            end
     
            // Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg is depending upon this state
            // for updating itself.. It will not update itself if VeBPF_rules_selector_state_reg is in this state..
            // the reason for this is that if we have obtained a correct result, we no longer want to update the 
            // Reduction array, otherwise it would started getting counting results of the current rxpkt for the next rxpkts
            VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_NEXT_RX_PKT_HDR: begin

                VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_NEXT_RX_PKT_HDR;

                VeBPF_rule_selector_waiting_for_next_rxpkt_flag_next = 1;

                // resetting counter, rdptr registers

                VeBPF_rules_selector_total_rules_uploaded_next = 0;

                VeBPF_rules_selector_rules_scheduler_table_rd_ptr_next = 0;

                // resetting run rule reqs to 0
                VeBPF_rules_selector_run_rule_req_array_next = 0; 
                    // bug resolved in a100T24 project when num of VeBPF > num of total rules

                // waiting for the next rx pkt hdr to be uploaded in all VeBPFs data memo
                if (VeBPF_data_loading_done_flag_reg) begin 

                    VeBPF_rules_selector_state_next = VEBPF_RULES_SELECTOR_FSM_STATE_IDLE;

                end 


            end


        endcase

    end


end

// ********************************************************************************************************************************************************************
// ***************************************** VeBPF RULES Selector FSM -> END *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ********************************************************************************************************************************************************************
// ***************************************** VeBPF Result Evaluator FSM -> START *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

// this is a short FSM for evaluating the results given out by VeBPF CPUs. Lower rule ID result will be prioritized and processing will stop once a
// legitimate result is obtained whether that is a valid destination or drop packet result, otherwise processing will keep on going if we are 
// receiving IDK result

// possible values for result:
// parameter TOTAL_DESTINATIONS_FOR_VEBPF_RESULTS = 6,  // the VeBPF results can be either 1 till TOTAL_DESTINATIONS_FOR_VEBPF_RESULTS
// Result of 255 means  I Don't Know (IDK)
// Result of 254 means  Drop Packet
// Result of 253 means  Error
// not choosing 0 as an option cx most prob it will be default value of result upon reset

localparam VEBPF_RESULT_ERROR = 253;
localparam VEBPF_RESULT_DROP_PKT = 254;
localparam VEBPF_RESULT_DONT_CARE_KEEP_PROCESSING = 1;
localparam WAIT_FOR_ALL_VEBPFS_TO_FINISH = 0; //1; //0;  // testing with value 1 for DONT care results 
    // if this parameter is 1 then the result eval fsm will wait for all VeBPFs to finish processing until the final result is submitted

localparam [3:0]
    VEBPF_RESULT_EVALUATOR_FSM_STATE_RESULT_RECEPTION = 4'd0;
    // VEBPF_RESULT_EVALUATOR_FSM_STATE_WAITING_FOR_REST_OF_VEBPFS_TO_FINISH = 4'd1;
    // VEBPF_RESULT_TRACKER_FSM_STATE_RESET_REGISTERS_FOR_NEXT_RX_PKT = 4'd2;

// VeBPF RESULT TRACKER FSM state registers
reg [3:0] VeBPF_result_evaluator_state_reg, VeBPF_result_evaluator_state_next;

// reg for storing the final result
reg [VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH -1:0] VeBPF_result_evaluator_final_result_reg, VeBPF_result_evaluator_final_result_next;

reg VeBPF_result_evaluator_final_result_error_flag_reg, VeBPF_result_evaluator_final_result_error_flag_next;
reg VeBPF_result_evaluator_transfer_to_descTable_final_result_error_flag_reg, 
VeBPF_result_evaluator_transfer_to_descTable_final_result_error_flag_next;

reg VeBPF_result_evaluator_final_result_pkt_drop_flag_reg, VeBPF_result_evaluator_final_result_pkt_drop_flag_next;
reg VeBPF_result_evaluator_transfer_to_descTable_final_result_pkt_drop_flag_reg, 
VeBPF_result_evaluator_transfer_to_descTable_final_result_pkt_drop_flag_next;

reg VeBPF_result_evaluator_result_matched_flag_reg, VeBPF_result_evaluator_result_matched_flag_next;
reg VeBPF_result_evaluator_stop_VeBPF_processing_flag_reg, VeBPF_result_evaluator_stop_VeBPF_processing_flag_next;
reg [VEBPF_MAX_NUM_OF_RULES_TOTAL_BITS -1:0] VeBPF_result_evaluator_prev_selected_result_id_number_reg, 
VeBPF_result_evaluator_prev_selected_result_id_number_next;

reg [BITS_NEDED_FOR_NUMBER_OF_VEBPF - 1:0] VeBPF_result_evaluator_VeBPF_halt_counter_reg, VeBPF_result_evaluator_VeBPF_halt_counter_next;


integer i_result_evaluator;


always @(posedge clk) begin

    if (rst) begin

        VeBPF_result_evaluator_state_reg <= VEBPF_RESULT_EVALUATOR_FSM_STATE_RESULT_RECEPTION;
        VeBPF_result_evaluator_final_result_reg <= 0;
        VeBPF_result_evaluator_final_result_error_flag_reg <= 0;
        VeBPF_result_evaluator_result_matched_flag_reg <= 0;
        VeBPF_result_evaluator_stop_VeBPF_processing_flag_reg <= 0;
        VeBPF_result_evaluator_final_result_pkt_drop_flag_reg <= 0;
        VeBPF_result_evaluator_prev_selected_result_id_number_reg <= 0;
        VeBPF_result_evaluator_transfer_to_descTable_final_result_error_flag_reg <= 0;
        VeBPF_result_evaluator_transfer_to_descTable_final_result_pkt_drop_flag_reg <= 0;
        VeBPF_result_evaluator_VeBPF_halt_counter_reg <= 0;

    end else begin
        
        VeBPF_result_evaluator_state_reg <= VeBPF_result_evaluator_state_next;
        VeBPF_result_evaluator_final_result_reg <= VeBPF_result_evaluator_final_result_next;
        VeBPF_result_evaluator_final_result_error_flag_reg <= VeBPF_result_evaluator_final_result_error_flag_next;
        VeBPF_result_evaluator_result_matched_flag_reg <= VeBPF_result_evaluator_result_matched_flag_next;
        VeBPF_result_evaluator_stop_VeBPF_processing_flag_reg <= VeBPF_result_evaluator_stop_VeBPF_processing_flag_next;
        VeBPF_result_evaluator_final_result_pkt_drop_flag_reg <= VeBPF_result_evaluator_final_result_pkt_drop_flag_next;
        VeBPF_result_evaluator_prev_selected_result_id_number_reg <= VeBPF_result_evaluator_prev_selected_result_id_number_next;
        VeBPF_result_evaluator_transfer_to_descTable_final_result_error_flag_reg <= VeBPF_result_evaluator_transfer_to_descTable_final_result_error_flag_next;
        VeBPF_result_evaluator_transfer_to_descTable_final_result_pkt_drop_flag_reg <= VeBPF_result_evaluator_transfer_to_descTable_final_result_pkt_drop_flag_next;
        VeBPF_result_evaluator_VeBPF_halt_counter_reg <= VeBPF_result_evaluator_VeBPF_halt_counter_next;

    end

end

always @(*) begin

    VeBPF_result_evaluator_state_next = VeBPF_result_evaluator_state_reg;
    VeBPF_result_evaluator_final_result_next = VeBPF_result_evaluator_final_result_reg;
    VeBPF_result_evaluator_final_result_error_flag_next = VeBPF_result_evaluator_final_result_error_flag_reg;
    VeBPF_result_evaluator_result_matched_flag_next = VeBPF_result_evaluator_result_matched_flag_reg;
    VeBPF_result_evaluator_stop_VeBPF_processing_flag_next = VeBPF_result_evaluator_stop_VeBPF_processing_flag_reg;
    VeBPF_result_evaluator_final_result_pkt_drop_flag_next = VeBPF_result_evaluator_final_result_pkt_drop_flag_reg;
    VeBPF_result_evaluator_prev_selected_result_id_number_next = VeBPF_result_evaluator_prev_selected_result_id_number_reg;
    VeBPF_result_evaluator_transfer_to_descTable_final_result_error_flag_next = VeBPF_result_evaluator_transfer_to_descTable_final_result_error_flag_reg;
    VeBPF_result_evaluator_transfer_to_descTable_final_result_pkt_drop_flag_next = VeBPF_result_evaluator_transfer_to_descTable_final_result_pkt_drop_flag_reg;
    VeBPF_result_evaluator_VeBPF_halt_counter_next = VeBPF_result_evaluator_VeBPF_halt_counter_reg;

    // Reset flags for the next rxpkt processing
    if (VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag) begin

        VeBPF_result_evaluator_final_result_error_flag_next = 0;
        VeBPF_result_evaluator_transfer_to_descTable_final_result_error_flag_next = VeBPF_result_evaluator_final_result_error_flag_reg;
            // save the error flag to transfer it to the descTable

        VeBPF_result_evaluator_final_result_pkt_drop_flag_next = 0;
        VeBPF_result_evaluator_transfer_to_descTable_final_result_pkt_drop_flag_next = VeBPF_result_evaluator_final_result_pkt_drop_flag_reg;
            // save the pkt drop flag to transfer it to the descTable

        VeBPF_result_evaluator_result_matched_flag_next = 0;
        VeBPF_result_evaluator_stop_VeBPF_processing_flag_next = 0;
        VeBPF_result_evaluator_prev_selected_result_id_number_next = 0;

        VeBPF_result_evaluator_VeBPF_halt_counter_next = 0;

    end else begin
        
        case (VeBPF_result_evaluator_state_reg)


            VEBPF_RESULT_EVALUATOR_FSM_STATE_RESULT_RECEPTION: begin

                VeBPF_result_evaluator_state_next = VEBPF_RESULT_EVALUATOR_FSM_STATE_RESULT_RECEPTION;

                // if we haven't reached a state where the flag for stopping the VeBPF process was raised, meaning that the result is final
                // AND our rule selector isn't waiting for the next rxpkt (because flag for stopping rxpkt gets reset)
                if ((!VeBPF_result_evaluator_stop_VeBPF_processing_flag_reg) && (!VeBPF_rule_selector_waiting_for_next_rxpkt_flag_reg) ) begin

                    // if there is a flag to store VeBPF results
                    if (VeBPF_result_tracker_result_array_wr_flag_reg) begin

                        // store the current rule_id number in previous rule_id register, 
                        // the "VeBPF_result_evaluator_prev_selected_result_id_number_reg" will become the previous rule_id on the next clk
                        VeBPF_result_evaluator_prev_selected_result_id_number_next = VeBPF_result_tracker_current_selected_result_id_number_reg;

                        // if there wasn't an error while processing the rule
                        if (!VeBPF_result_tracker_rxpkt_error_flag_reg) begin

                            // no error for result_evaluator flag
                            VeBPF_result_evaluator_final_result_error_flag_next = 0;

                            // if the result says to drop packet then we stop all processing and drop the packet
                            if (VeBPF_result_tracker_current_selected_result_reg == VEBPF_RESULT_DROP_PKT) begin 

                                // store the result
                                VeBPF_result_evaluator_final_result_next = VeBPF_result_tracker_current_selected_result_reg;
                                    // Result should be VEBPF_RESULT_DROP_PKT = 254 programmed in the pgm mem for drop pkt condition

                                // raise flag for packet drop
                                VeBPF_result_evaluator_final_result_pkt_drop_flag_next = 1;

                                // raise flag for stoppage of VeBPF processing
                                VeBPF_result_evaluator_stop_VeBPF_processing_flag_next = 1;
                            
                            // if there is a DONT care result as the first non-valid non-buggy result, don't do anything, unless total eBPF rules run are equal to total eBPF rules uploaded,
                            // total eBPF rules run by the VeBPF CPUs are equal to the total eBPF rules uploaded, and we haven't received a valid result yet, then just save the
                            // dont care result into the final VeBPF CPUs filtering result register and raise flag for stopping the VeBPF processing
                            end else if ((VeBPF_result_tracker_current_selected_result_reg == VEBPF_RESULT_DONT_CARE_KEEP_PROCESSING) && (VeBPF_result_evaluator_VeBPF_halt_counter_reg == 0)) begin
                                                                
                                // if (VeBPF_rules_selector_total_rules_uploaded_reg == VeBPF_rules_scheduler_total_num_rules_uploaded_reg) begin 
                                    // these rules get uploaded even before all of them are processed.. so I need to look at rule_id here as well..
                                
                                // using this flag as a debug probe here
                                VeBPF_result_evaluator_result_matched_flag_next = 1;

                                // making sure current result_id number is the last eBPF rule that was run
                                    // we have an error here.. will solve it in the morning    .. need to AND the if statment here with this comment below:
                                        // check if VeBPFs have FINISHED processing ALL RULES or a valid result has been received by the RESULT EVALUATOR FSM
                                        // if ((&(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg)) || VeBPF_result_evaluator_stop_VeBPF_processing_flag_reg) begin
                                        // check if VeBPFs have FINISHED processing ALL RULES         
                                            // will make a new project and save these changes in the new project
                                                // debugging the error in network subsystem that all results that are dont care except for the 
                                                // 1st result but it arrives after the last rule result so it doesnt get registered                   
                                // if ((VeBPF_rules_selector_total_rules_uploaded_reg == VeBPF_rules_scheduler_total_num_rules_uploaded_reg)
                                //         && (VeBPF_result_tracker_current_selected_result_id_number_reg == (VeBPF_rules_scheduler_total_num_rules_uploaded_reg - 1)) ) begin 

                                // if ((VeBPF_rules_selector_total_rules_uploaded_reg == VeBPF_rules_scheduler_total_num_rules_uploaded_reg)
                                //         && (VeBPF_result_tracker_current_selected_result_id_number_reg == (VeBPF_rules_scheduler_total_num_rules_uploaded_reg - 1))
                                //         &&  (&(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg))) begin 

                                // The if-condition above is also INCORRECT since it is not necessary that the last/current run rule has rule_id = VeBPF_rules_scheduler_total_num_rules_uploaded_reg - 1
                                // since lets say we have 5 rules total and rule_id3 finish after rule_id4 and all rules give DONT_CARE result, but in this case
                                // we will get a errouneus result. 
                                    // Hence we need to remve the condition "VeBPF_result_tracker_current_selected_result_id_number_reg == (VeBPF_rules_scheduler_total_num_rules_uploaded_reg - 1)"
                                // also do I need the condition "VeBPF_rules_selector_total_rules_uploaded_reg == VeBPF_rules_scheduler_total_num_rules_uploaded_reg"?
                                    // I guess I can for better code readibility..... since only using "(&(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg))"
                                    // would've done the job anyway..

                                // checking if all rules were run and all had DONT CARE results, otherwise eBPF_result_evaluator_VeBPF_halt_counter_reg != 0
                                // and this condition wouldn't get executed
                                    // bug in the if-statement logic below is buggy since Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg
                                    // gets updated one cycle AFTER VeBPF_result_tracker_result_array_wr_flag_reg 1 clk cycle later after pulse had passed
                                // if ((VeBPF_rules_selector_total_rules_uploaded_reg == VeBPF_rules_scheduler_total_num_rules_uploaded_reg)
                                //         &&  (&(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg))) begin
                                // using Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_next solved the issue above
                                if ((VeBPF_rules_selector_total_rules_uploaded_reg == VeBPF_rules_scheduler_total_num_rules_uploaded_reg)
                                        &&  (&(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_next))) begin 
 

                                    // raise flag for stoppage of VeBPF processing for packet drop
                                    VeBPF_result_evaluator_stop_VeBPF_processing_flag_next = 1;

                                    // store the result
                                    VeBPF_result_evaluator_final_result_next = VeBPF_result_tracker_current_selected_result_reg;

                                end


                            // if the result isn't to drop packets or if there is a DONT care result, then save the result and rule_id and wait for rest of the VeBPF cpus to finsih processing
                            // if there are other VeBPF that are left processing results
                            end else begin 

                                // counting how many VeBPF Halts have we received when we receive a valid result
                                VeBPF_result_evaluator_VeBPF_halt_counter_next = VeBPF_result_evaluator_VeBPF_halt_counter_reg + 1;

                                // not using this for loop atm.. just raising a flag if results match.. might use this later for routing rxpkts 
                                // for (i_result_evaluator = 1; i_result_evaluator <= TOTAL_DESTINATIONS_FOR_VEBPF_RESULTS; i_result_evaluator = i_result_evaluator + 1) begin

                                //     // lower id destinations would come first but I needed to prioritize lower rule id no?
                                //         // yep lower id rule should be preferred since it was run before higher id rule

                                //     // check to see if the result of VeBPF processing was one of the possible results/destinations
                                //     if (VeBPF_result_tracker_current_selected_result_reg == i_result_evaluator) begin 
     
                                //         VeBPF_result_evaluator_result_matched_flag_next = 1;
                                //     end

                                // end 

                                // if this parameter is 1 then the result eval fsm will wait for all VeBPFs to finish processing until the final result is submitted
                                if (WAIT_FOR_ALL_VEBPFS_TO_FINISH) begin 

                                    // check if other VeBPFs have finished processing the rules
                                    if(VeBPF_result_evaluator_VeBPF_halt_counter_next >= NUMBER_OF_VEBPF) begin
                                    // if(&VeBPF_halt_combined_global) begin

                                        // raise flag for stoppage of VeBPF processing for packet drop
                                        VeBPF_result_evaluator_stop_VeBPF_processing_flag_next = 1;

                                        // store the result IF IT IS NOT A DONT CARE RESULT!
                                        if (VeBPF_result_tracker_current_selected_result_reg != VEBPF_RESULT_DONT_CARE_KEEP_PROCESSING) begin
                                            
                                            // store the result 
                                            VeBPF_result_evaluator_final_result_next = VeBPF_result_tracker_current_selected_result_reg;

                                        end

                                        // if the current rule id is less than or equal to the prev rule id, overwrite the result with this new lower rule_id result
                                        // the equal to condition is only possible for the 1st rule where both current and prev are 0
                                        // if (VeBPF_result_tracker_current_selected_result_id_number_reg <= VeBPF_result_evaluator_prev_selected_result_id_number_reg) begin

                                        //     // store the result IF IT IS NOT A DONT CARE RESULT!
                                        //     if (VeBPF_result_tracker_current_selected_result_reg != VEBPF_RESULT_DONT_CARE_KEEP_PROCESSING) begin
                                                
                                        //         // store the result 
                                        //         VeBPF_result_evaluator_final_result_next = VeBPF_result_tracker_current_selected_result_reg;

                                        //     end
                                        // end

                                    end else begin

                                        // if the current rule id is less than or equal to the prev rule id, overwrite the result with this new lower rule_id result
                                        // the equal to condition is only possible for the 1st rule where both current and prev are 0
                                        // if (VeBPF_result_tracker_current_selected_result_id_number_reg <= VeBPF_result_evaluator_prev_selected_result_id_number_reg) begin
                                            // this condition isn't valid anymore since we have the ifelse condition involving dont care result.. so not saving the results
                                            // with priority for lower rules id anymore.. will need to design a prority array and stuff for that functionality 


                                        // store the result IF IT IS NOT A DONT CARE RESULT!
                                        if (VeBPF_result_tracker_current_selected_result_reg != VEBPF_RESULT_DONT_CARE_KEEP_PROCESSING) begin
                                            
                                            // store the result 
                                            VeBPF_result_evaluator_final_result_next = VeBPF_result_tracker_current_selected_result_reg;

                                        end

                                        // end 

                                    end

                                end else begin 

                                    // raise flag for stoppage of VeBPF processing for packet drop
                                    VeBPF_result_evaluator_stop_VeBPF_processing_flag_next = 1;
                                    
                                    // I dont need to put in the condition:
                                        // store the result IF IT IS NOT A DONT CARE RESULT!
                                        // if (VeBPF_result_tracker_current_selected_result_reg != VEBPF_RESULT_DONT_CARE_KEEP_PROCESSING) begin
                                    // since we are not WAIT_FOR_ALL_VEBPFS_TO_FINISH here and if its the first valid result and it is DONTCARE 
                                    // then it would be ignored by the if condition of the DONT CARE result (unless it is the last eBPF rule evaluated)
                                    // and all eBPF rules resulted in DONT CARES, in that case DONT CARE result would be saved, apart from that
                                    // if the VeBPF result is VALID and we dont have to wait for results from other VEBPF CPUs, so we will just 
                                    // save that result and stop the processing.

                                    // store the result
                                    VeBPF_result_evaluator_final_result_next = VeBPF_result_tracker_current_selected_result_reg;

                                end  

                            end 

                             
                        end else begin 

                            // store the result
                            VeBPF_result_evaluator_final_result_next = VeBPF_result_tracker_current_selected_result_reg;
                                // Result should be VEBPF_RESULT_ERROR = 253 but that can't be programmed in the pgm mem as output for 
                                // error condition, hence, the Result Tracker FSM takes care of that.

                            VeBPF_result_evaluator_final_result_error_flag_next = 1;

                            // raise flag for stoppage of VeBPF processing for packet drop due to error
                            VeBPF_result_evaluator_stop_VeBPF_processing_flag_next = 1;

                        end 

                    end

                end

            end

            // Don't need this state atm, but keeping it here if it is needed in the future
            // VEBPF_RESULT_EVALUATOR_FSM_STATE_WAITING_FOR_REST_OF_VEBPFS_TO_FINISH: begin

            //     VeBPF_result_evaluator_state_next = VEBPF_RESULT_EVALUATOR_FSM_STATE_WAITING_FOR_REST_OF_VEBPFS_TO_FINISH;

            //     // waiting till all VeBPFs have finsihed processing
            //     if(&VeBPF_halt_combined_global) begin

            //         VeBPF_result_evaluator_state_next = VEBPF_RESULT_EVALUATOR_FSM_STATE_RESULT_RECEPTION;

            //         // raise flag for stoppage of VeBPF processing for packet drop
            //         VeBPF_result_evaluator_stop_VeBPF_processing_flag_next = 1;

            //         // track if any result gave an error

            //         // can also track if any incoming result has a lower rule id than the previous stored one and it can override that result here

            //     end

            // end 

        endcase 

    end

    

end



// ********************************************************************************************************************************************************************
// ***************************************** VeBPF Result Evaluator FSM -> END *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ********************************************************************************************************************************************************************
// ***************************************** VeBPF Result Tracker FSM -> START *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

// keep VEBPF_MAX_NUM_OF_RULES/VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX in powers of 2 
// so that we don't need to use multiply operations for rd wr ptrs and we can just to bitshifts
localparam VEBPF_MAX_NUM_OF_RULES = VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX;

localparam VEBPF_MAX_NUM_OF_RULES_TOTAL_BITS = $clog2(VEBPF_MAX_NUM_OF_RULES);

localparam [3:0]
    VEBPF_RESULT_TRACKER_FSM_STATE_RESULT_TRACKING = 4'd0,
    VEBPF_RESULT_TRACKER_FSM_STATE_RESULT_STORING = 4'd1,
    VEBPF_RESULT_TRACKER_FSM_STATE_RESET_REGISTERS_FOR_NEXT_RX_PKT = 4'd2;

// VeBPF RESULT TRACKER FSM state registers
reg [3:0] VeBPF_result_tracker_state_reg, VeBPF_result_tracker_state_next;


// run rule req ack array for result tracker FSM that the result tracker FSM will recieve and acknowledge
reg [NUMBER_OF_VEBPF - 1:0] VeBPF_result_tracker_run_rule_ack_array_reg, VeBPF_result_tracker_run_rule_ack_array_next;
reg [NUMBER_OF_VEBPF - 1:0] VeBPF_result_tracker_run_flag_reg, VeBPF_result_tracker_run_flag_next;


/*
// uncomment this for testing in simulation if you want to store all results

// global reults array for the VeBPF output is VEBPF_MAX_NUM_OF_RULES deep
// the global results array is for results of multiple rules for single Rxpkt

reg [VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH -1 :0] Global_VeBPF_Result_Array [VEBPF_MAX_NUM_OF_RULES - 1:0];

*/

// I dont need total bits req to respresent total rules here below as width. I need total rules as bit width since I am doing one hot encoding of wether
// the rule has been processed or not, so changing the bit width to that
// reg [VEBPF_MAX_NUM_OF_RULES - 1:0] Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot;
// reg [VEBPF_MAX_NUM_OF_RULES_TOTAL_BITS - 1:0] Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot;


// same logic of bit width as above for Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot
reg [VEBPF_MAX_NUM_OF_RULES - 1:0] Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg, Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_next;


// reg VeBPF_rule_selector_reset_flag_Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot_reg, VeBPF_rule_selector_reset_flag_Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot_next;

// the desc table Global VeBPF result array is for the results for multiple rules for
// all the RxPktHdr's that can be uploaded to the RxPktHdrBram that the VeBPFs need
// to filter.. hence we don't need another FULL flag since we will be looking at the
// FULL flag for the desc table...
// Using VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH so that this array doesnt take up a lot of FPGA resources since its
// depth a lot

/*
    // uncomment this for testing in simulation if you want to store all results
reg [VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH -1 :0] desc_table_Global_VeBPF_Result_Array [(RX_PKT_DESC_TABLE_DEPTH*VEBPF_MAX_NUM_OF_RULES)-1:0];

*/
    // each RxPkt needs VEBPF_MAX_NUM_OF_RULES bins for storing all the rules results and RX_PKT_DESC_TABLE_DEPTH means
    // the total RxPkts that can be stored "handled" without the riscv or any other subsystem incrementing the rdptr of the desc table
    // (i.e., reading the desc table)..

localparam DESC_TABLE_GLOBAL_VEBPF_RESULTS_ARRAY_PTR_BITS_WDITH = RX_PKT_DESC_TABLE_DEPTH_BITS_WIDTH + VEBPF_MAX_NUM_OF_RULES_TOTAL_BITS;
    // need to add the bits wdith instead of multiplication as being done for the depth of desc_table_Global_VeBPF_Result_Array using depth
    // e.g., RX_PKT_DESC_TABLE_DEPTH = 4 means RX_PKT_DESC_TABLE_DEPTH_BITS_WIDTH = 2 & 
    // VEBPF_MAX_NUM_OF_RULES_TOTAL_BITS = 4 means VEBPF_MAX_NUM_OF_RULES_TOTAL_BITS_BITS_WIDTH = 2
    // DESC_TABLE_GLOBAL_VEBPF_RESULTS_ARRAY total depth = 4 x 4 = 16 &
    // DESC_TABLE_GLOBAL_VEBPF_RESULTS_ARRAY_PTR_BITS_WDITH = 2 + 2 = 4 bits needed to index 16 bins


// 1 extra bit for rollover detection if checking FULL flag for this array is necessary
// will use comb logic to calculate these rd wr ptrs cx they will be the sum of 2 other ptrs changing at diff places
// reg [DESC_TABLE_GLOBAL_VEBPF_RESULTS_ARRAY_PTR_BITS_WDITH:0] wr_ptr_desc_table_Global_VeBPF_Result_Array;
    // not using this in syn design

// reg [DESC_TABLE_GLOBAL_VEBPF_RESULTS_ARRAY_PTR_BITS_WDITH:0] rd_ptr_desc_table_Global_VeBPF_Result_Array;
    // not using this in syn design

reg VeBPF_result_tracker_result_array_wr_flag_reg, VeBPF_result_tracker_result_array_wr_flag_next;
reg [VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH -1:0] VeBPF_result_tracker_current_selected_result_reg, VeBPF_result_tracker_current_selected_result_next;
reg [VEBPF_MAX_NUM_OF_RULES_TOTAL_BITS -1:0] VeBPF_result_tracker_current_selected_result_id_number_reg, VeBPF_result_tracker_current_selected_result_id_number_next;
reg [NUMBER_OF_VEBPF - 1:0] VeBPF_result_tracker_available_array_reg, VeBPF_result_tracker_available_array_next;


reg [NUMBER_OF_VEBPF - 1:0] VeBPF_result_tracker_run_VeBPF_in_reg, VeBPF_result_tracker_run_VeBPF_in_next;

assign VeBPF_reset_n_combined_global = VeBPF_result_tracker_run_VeBPF_in_reg;
    // BTW in VeBPF 
        // assign reset_n_int = (reset_n | csr_ctl[0]);
            // so its a different csr bit from the bit used for VeBPF data loading FSM 
    // also reset_n is being ACTIVATED in rxpkthdr VeBPF data loading FSM 
    // comments from rxpkthdr VeBPF data loading FSM
        // .rst((!reset_n_int) ^ (csr_ctl[1])), 
        // VeBPF_csr_ctl_next[1] = 1 to get access to VeBPF data memory and overwite its reset and 0 to give access back to VeBPF
        // while VeBPF_reset_n_next = 0; // reset is active (can load data memory in VeBPF now)
            // rst(1 ^ 1) = rst(0)  // rst is deactivated
        // when running VeBPF cpu VeBPF_reset_n_next = 1 and VeBPF_csr_ctl_next[1] = 0 which means:
            // rst(0 ^ 0) = rst(0)  // rst is deactivated
        // what happens on rst(1 ^ 0) = rst(1) // rst activated .. value of VeBPF rst is used
        // what happens on rst(0 ^ 1) = rst(1) // rst activated .. value of VeBPF rst is 
        // not used but is still active even though csr_ctl[1] = 1.. so for using csr_ctl[1]
        // VeBPF rst should be active (reset_n_int = 0)

// flag to see if there was an error in any result of the rules for the filtered rxpkt
reg VeBPF_result_tracker_rxpkt_error_flag_reg, VeBPF_result_tracker_rxpkt_error_flag_next;



// Imp signals for this FSM:
    // VeBPF_reset_n_combined_global
    // VeBPF_halt_combined_global
    // VeBPF_error_combined_global


// Seq part of VeBPF Result Tracker FSM
always @(posedge clk) begin

    if (rst) begin

        VeBPF_result_tracker_state_reg <= VEBPF_RESULT_TRACKER_FSM_STATE_RESULT_TRACKING;
        VeBPF_result_tracker_run_rule_ack_array_reg <= 0;
        VeBPF_result_tracker_run_flag_reg <= 0;
        VeBPF_result_tracker_result_array_wr_flag_reg <= 0;
        VeBPF_result_tracker_run_VeBPF_in_reg <= 0;
        
        // all VeBPFs are available on system rst
        VeBPF_result_tracker_available_array_reg <= {NUMBER_OF_VEBPF{1'b1}};

        VeBPF_result_tracker_rxpkt_error_flag_reg <= 0;

        // Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot <= 0;

        // since it is a one hot vector we will make all bits 1
        Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg <= {VEBPF_MAX_NUM_OF_RULES{1'b1}};

        VeBPF_result_tracker_current_selected_result_reg <= 0;

        VeBPF_result_tracker_current_selected_result_id_number_reg <= 0;


    end else begin 

        VeBPF_result_tracker_state_reg <= VeBPF_result_tracker_state_next;
        VeBPF_result_tracker_run_rule_ack_array_reg <= VeBPF_result_tracker_run_rule_ack_array_next;
        VeBPF_result_tracker_run_flag_reg <= VeBPF_result_tracker_run_flag_next;
        VeBPF_result_tracker_result_array_wr_flag_reg <= VeBPF_result_tracker_result_array_wr_flag_next;
        VeBPF_result_tracker_current_selected_result_reg <= VeBPF_result_tracker_current_selected_result_next;
        VeBPF_result_tracker_current_selected_result_id_number_reg <= VeBPF_result_tracker_current_selected_result_id_number_next;


        // uncomment this below for testing in simulation if you want to store all results

        /*

        // storing the selected result below
        if (VeBPF_result_tracker_result_array_wr_flag_reg) begin 

            // TODO: Comment this result array below (while doing synthesis) cx we need the combined one desc_table_Global_VeBPF_Result_Array
            Global_VeBPF_Result_Array[VeBPF_result_tracker_current_selected_result_id_number_reg] <= VeBPF_result_tracker_current_selected_result_reg;

            // Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot[VeBPF_result_tracker_current_selected_result_id_number_reg] <= 1;

            // TODO: Comment this result array below (while doing synthesis), dont need this any more
            desc_table_Global_VeBPF_Result_Array[wr_ptr_desc_table_Global_VeBPF_Result_Array[
                                        DESC_TABLE_GLOBAL_VEBPF_RESULTS_ARRAY_PTR_BITS_WDITH-1:0]] <= VeBPF_result_tracker_current_selected_result_reg;
                // I sent 4 + 4 rxpkts when desc table depth = 4, so the wrptr here wr_ptr_desc_table_Global_VeBPF_Result_Array
                // did rollover back to 0 after 4 rxpkts.. full further check rollover conditions during stress testing simulations

        end

        */

        // if (VeBPF_rule_selector_reset_flag_Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot_reg) begin 

        //     // reset all the bits of Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot for next rxpkt
        //     Global_VeBPF_Result_Array_rules_processing_done_results_valid_one_hot <= 0;

        // end 

        VeBPF_result_tracker_run_VeBPF_in_reg <= VeBPF_result_tracker_run_VeBPF_in_next;
        VeBPF_result_tracker_available_array_reg <= VeBPF_result_tracker_available_array_next;
        VeBPF_result_tracker_rxpkt_error_flag_reg <= VeBPF_result_tracker_rxpkt_error_flag_next;

        Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg <= Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_next;

    end

end

integer i_result_tacker;
integer i_result_tacker_2;

// Comb logic for common variables
always @(*) begin

    // not using this in syn design atm
    // wr_ptr_desc_table_Global_VeBPF_Result_Array = (wr_ptr_decs_table_VeBPF_result_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0] << (VEBPF_MAX_NUM_OF_RULES_TOTAL_BITS)) +
                                                    // VeBPF_result_tracker_current_selected_result_id_number_reg;
        // left shifting by VEBPF_MAX_NUM_OF_RULES_TOTAL_BITS so that for the next rxpkt we skip all the bins that were allocated for the prev rxpkt
        // lets say VEBPF_MAX_NUM_OF_RULES = 64 and VEBPF_MAX_NUM_OF_RULES_TOTAL_BITS = 6, so for wr_ptr_decs_table_VeBPF_result_rx_pkt_reg = 0,
        // the wrptr = 0 + VeBPF_result_tracker_current_selected_result_id_number_reg and for wr_ptr_decs_table_VeBPF_result_rx_pkt_reg = 1,
        // the wrptr = 1 << 6 + VeBPF_result_tracker_current_selected_result_id_number_reg => wrptr = 64 + VeBPF_result_tracker_current_selected_result_id_number_reg 

    Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_next = Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg;

    // this if statement is to initialize the Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_next selected indicex to 0
    if (VeBPF_rules_scheduler_all_rules_uploaded_flag_notification) begin

        // go through the fulll array
        for (i_result_tacker_2 = 0; i_result_tacker_2 < VEBPF_MAX_NUM_OF_RULES; i_result_tacker_2 = i_result_tacker_2 + 1) begin 

            // now I can look at a variable register instead of the error of doing bitslicing using a variable register
            // cx only a constant can be used for that cx we are synthesizing hardware here instead of bitslicing in software 
            if (i_result_tacker_2 < VeBPF_rules_scheduler_total_num_rules_uploaded_reg) begin 

                // reset those bits to 0 that correspond to the rules being processed for the new rxpkt
                Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_next[i_result_tacker_2] = 0;

            end 

        end 

    end else if (VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag) begin

        // go through the fulll array
        for (i_result_tacker_2 = 0; i_result_tacker_2 < VEBPF_MAX_NUM_OF_RULES; i_result_tacker_2 = i_result_tacker_2 + 1) begin 

            // now I can look at a variable register instead of the error of doing bitslicing using a variable register
            // cx only a constant can be used for that cx we are synthesizing hardware here instead of bitslicing in software 
            if (i_result_tacker_2 < VeBPF_rules_scheduler_total_num_rules_uploaded_reg) begin 

                // reset those bits to 0 that correspond to the rules being processed for the new rxpkt
                Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_next[i_result_tacker_2] = 0;

            end 

        end


    // if VeBPF has an output result
    // end else if (VeBPF_result_tracker_result_array_wr_flag_reg) begin
    
    // Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg is depending upon this state
    // for updating itself.. It will not update itself if VeBPF_rules_selector_state_reg is in this state..
    // the reason for this is that if we have obtained a correct result, we no longer want to update the 
    // Reduction array, otherwise it would started getting counting results of the current rxpkt for the next rxpkts
    // VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_NEXT_RX_PKT_HDR: begin
    end else if (VeBPF_result_tracker_result_array_wr_flag_reg && (VeBPF_rules_selector_state_reg != VEBPF_RULES_SELECTOR_FSM_STATE_WAITING_FOR_NEXT_RX_PKT_HDR)) begin

        // go through the fulll array
        for (i_result_tacker_2 = 0; i_result_tacker_2 < VEBPF_MAX_NUM_OF_RULES; i_result_tacker_2 = i_result_tacker_2 + 1) begin 

            // now I can look at a variable register instead of the error of doing bitslicing using a variable register
            // cx only a constant can be used for that cx we are synthesizing hardware here instead of bitslicing in software 
            if (i_result_tacker_2 < VeBPF_rules_scheduler_total_num_rules_uploaded_reg) begin 

                // using VeBPF_result_tracker_current_selected_result_id_number_reg as idx since it is the idx when
                // VeBPF_result_tracker_result_array_wr_flag_reg flag is raised
                Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_next[
                                                VeBPF_result_tracker_current_selected_result_id_number_reg] = 1;

            end 

        end 

    end 
        
end


// Comments From Result Evaluator FSM.
    // possible values for result:
    // parameter TOTAL_DESTINATIONS_FOR_VEBPF_RESULTS = 6,  // the VeBPF results can be either 1 till TOTAL_DESTINATIONS_FOR_VEBPF_RESULTS
    // Result of 255 means  I Don't Know (IDK)
    // Result of 254 means  Drop Packet
    // Result of 253 means  Error
    // not choosing 0 as an option cx most prob it will be default value of result upon reset


// Comb part of VeBPF Result Tracker FSM
always @(*) begin

    VeBPF_result_tracker_state_next = VeBPF_result_tracker_state_reg;
    VeBPF_result_tracker_run_rule_ack_array_next = VeBPF_result_tracker_run_rule_ack_array_reg;
    VeBPF_result_tracker_run_flag_next = VeBPF_result_tracker_run_flag_reg;
    VeBPF_result_tracker_result_array_wr_flag_next = VeBPF_result_tracker_result_array_wr_flag_reg;
    VeBPF_result_tracker_current_selected_result_next = VeBPF_result_tracker_current_selected_result_reg;
    VeBPF_result_tracker_current_selected_result_id_number_next = VeBPF_result_tracker_current_selected_result_id_number_reg;

    // making this a reg so we wont have to keep track of each bit throughout multiple states of this FSM
    VeBPF_result_tracker_run_VeBPF_in_next = VeBPF_result_tracker_run_VeBPF_in_reg;

    VeBPF_result_tracker_available_array_next = VeBPF_result_tracker_available_array_reg;

    VeBPF_result_tracker_rxpkt_error_flag_next = VeBPF_result_tracker_rxpkt_error_flag_reg; 
    

    case (VeBPF_result_tracker_state_reg)

        VEBPF_RESULT_TRACKER_FSM_STATE_RESULT_TRACKING: begin 

            VeBPF_result_tracker_state_next = VEBPF_RESULT_TRACKER_FSM_STATE_RESULT_TRACKING;

            if (VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag) begin 

                VeBPF_result_tracker_state_next = VEBPF_RESULT_TRACKER_FSM_STATE_RESET_REGISTERS_FOR_NEXT_RX_PKT; 

            end 

            // tracking and updating everything in parallel in this for loop.
            // results will be stored sequentially though with higher priority for the if conditions that come first as 
            // per Verilog standards
            // Comment here about using case statement for this FSM for better readability 
            // cx only always @(*) with ifelse coud have been used
                // so basically I can write the same FSM without the case statements but the case statements 
                // make things clearer.. so the same
            // imagine the for loop unrolled, VeBPF_result_tracker_state_next is the same for all the unrolled if blocks
            // and which ever ifelse block is activated based on priority of ifelse, then that value of VeBPF_result_tracker_state_next
            // is assigned.. same for variables like VeBPF_result_tracker_current_selected_result_id_number_next, same reg is used for
            // all ifelse blocks
            for (i_result_tacker = 0; i_result_tacker < NUMBER_OF_VEBPF; i_result_tacker = i_result_tacker + 1) begin

                // reset active on VeBPF 
                VeBPF_result_tracker_run_VeBPF_in_next[i_result_tacker] = 0;

                // if run rule req is received and the run rule ack is 0, i.e., this id VeBPF is not currently running a rule
                if (VeBPF_rules_selector_run_rule_req_array_reg[i_result_tacker] & (!VeBPF_result_tracker_run_rule_ack_array_reg[i_result_tacker])) begin

                    // make that idx bit for ack array 1 that 
                    VeBPF_result_tracker_run_rule_ack_array_next[i_result_tacker] = 1;

                    // make that idx VeBPF unavailable for running other rules
                    VeBPF_result_tracker_available_array_next[i_result_tacker] = 0;

                    // run the selected VeBPF in the next cycle, 
                    // reset deactivated
                    VeBPF_result_tracker_run_VeBPF_in_next[i_result_tacker] = 1;

                end


                // Once run req ack is given for a particular id, this if block will run independent of wether the if block above this one 
                // is active or not since these 2 if blocks are on the same level (not nested).
                if (VeBPF_result_tracker_run_rule_ack_array_reg[i_result_tacker]) begin

                    // run flag to keep track of if a certain VeBPF has been run
                    VeBPF_result_tracker_run_flag_next[i_result_tacker] = 1;
                        // looking at VeBPF_result_tracker_run_VeBPF_in_reg[i_result_tacker] so that we have 1 additional clk until
                        // VeBPF_result_tracker_run_flag_reg gets HIGH so reset is deactivated for 1 clk and "VeBPF halt" is reset now
                            // we have 1 additional clk now after this new if cond VeBPF_result_tracker_run_rule_ack_array_reg[i_result_tacker]

                    // keeping reset deactivated, otherwise it would go to reset state again 
                    VeBPF_result_tracker_run_VeBPF_in_next[i_result_tacker] = 1;

                    if (VeBPF_result_tracker_run_flag_reg[i_result_tacker]) begin 

                        // halt has been pulled down by this clk cycle as reset was given 2 cycles ago
                        if (VeBPF_halt_combined_global[i_result_tacker]) begin

                            VeBPF_result_tracker_state_next = VEBPF_RESULT_TRACKER_FSM_STATE_RESULT_STORING;

                            // make i_result_tacker bit for ack array 0 
                            VeBPF_result_tracker_run_rule_ack_array_next[i_result_tacker] = 0;

                            // make this idx i_result_tacker VeBPF available for running other rules
                            VeBPF_result_tracker_available_array_next[i_result_tacker] = 1;

                            // stop running the selected VeBPF in the next cycle, 
                            // reset activated
                            VeBPF_result_tracker_run_VeBPF_in_next[i_result_tacker] = 0;

                            // run flag to keep track of if a certain VeBPF has been run
                            VeBPF_result_tracker_run_flag_next[i_result_tacker] = 0;

                            // if there wasn't any error in the result 
                            if (!VeBPF_error_combined_global[i_result_tacker]) begin 

                                // store result on next clk cycle

                                VeBPF_result_tracker_result_array_wr_flag_next = 1;

                                VeBPF_result_tracker_current_selected_result_next = VeBPF_r0_combined_global[
                                        i_result_tacker*VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH +: VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH];

                                VeBPF_result_tracker_current_selected_result_id_number_next = rules_selected_for_VeBPF_array[i_result_tacker];
                                    // we can read rules_selected_for_VeBPF_array[i_result_tacker] asynchronously
                                    // because it doesn't require that much memory

                            end else begin

                                // updating error values as per:
                                // Comments From Result Evaluator FSM.
                                    // possible values for result:
                                    // parameter TOTAL_DESTINATIONS_FOR_VEBPF_RESULTS = 6,  // the VeBPF results can be either 1 till TOTAL_DESTINATIONS_FOR_VEBPF_RESULTS
                                    // Result of 255 means  I Don't Know (IDK)
                                    // Result of 254 means  Drop Packet
                                    // Result of 253 means  Error
                                    // not choosing 0 as an option cx most prob it will be default value of result upon reset

                                // store error result on next clk cycle
                                VeBPF_result_tracker_result_array_wr_flag_next = 1;

                                VeBPF_result_tracker_current_selected_result_next = VEBPF_RESULT_ERROR;  
                                // VeBPF_result_tracker_current_selected_result_next = 5;  
                                    // 5 in result means there was an error
                                        // not anymore 


                                VeBPF_result_tracker_current_selected_result_id_number_next = rules_selected_for_VeBPF_array[i_result_tacker];

                                // we need a global flag for this particular rxpkt incidating that there was an error
                                // while processing one of the results, then we can look into the results and search
                                // for which rule result had the value x (which right now is 5) indicating an error
                                VeBPF_result_tracker_rxpkt_error_flag_next = 1;
                                    // raise the error flag for this current rxpkt 

                            end 

                        end 

                    end

                end 

            end 

        end

        VEBPF_RESULT_TRACKER_FSM_STATE_RESULT_STORING: begin 

            VeBPF_result_tracker_state_next = VEBPF_RESULT_TRACKER_FSM_STATE_RESULT_TRACKING;

            // pulling down result storing variables after they have been stored in this cycle
            VeBPF_result_tracker_result_array_wr_flag_next = 0;
            VeBPF_result_tracker_current_selected_result_next = 0;
            VeBPF_result_tracker_current_selected_result_id_number_next = 0;
            // VeBPF_result_tracker_available_array_next = 1;

            // if filtering done flag is recieved in result storing state move to reset registers state
            if (VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag) begin 

                VeBPF_result_tracker_state_next = VEBPF_RESULT_TRACKER_FSM_STATE_RESET_REGISTERS_FOR_NEXT_RX_PKT; 

            end

        end

        VEBPF_RESULT_TRACKER_FSM_STATE_RESET_REGISTERS_FOR_NEXT_RX_PKT: begin

            // go back to result tracking state once the registers have been reset-ed 
            VeBPF_result_tracker_state_next = VEBPF_RESULT_TRACKER_FSM_STATE_RESULT_TRACKING;

            VeBPF_result_tracker_rxpkt_error_flag_next = 0;
                // reset the error flag for this next rxpkt 


        end

    endcase
    
end


// ********************************************************************************************************************************************************************
// ***************************************** VeBPF Result Tracker FSM -> END *****************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// ********************************************************************************************************************************************************************
// ***************************************** VeBPF RXPKTHDR BRAM FULL OR EMPTY CHECKING FSM -> START *************************************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************


localparam MAX_TCP_HDR_SIZE = 134;  // to make 134 bytes a multiple of 4 (since our bram data width is 4 bytes), we do (134 + 2)/ 4 = 34 words 
localparam MAX_TCP_HDR_SIZE_IN_WORDS = ((MAX_TCP_HDR_SIZE+2)/4); // 34 words
localparam MAX_UDP_HDR_SIZE = 82; 
localparam MAX_UDP_HDR_SIZE_IN_WORDS = (MAX_UDP_HDR_SIZE+2)/4;  // 82+2 / 4 = 21 words
localparam MAX_HDR_SIZE = MAX_TCP_HDR_SIZE;  // 134 bytes
localparam MAX_HDR_SIZE_IN_WORDS = MAX_TCP_HDR_SIZE_IN_WORDS;  // 34 words
// localparam VEBPF_RD_WR_PTR_WIDTH = $clog2((((MAX_TCP_HDR_SIZE+2)/4) * RX_PKT_DESC_TABLE_DEPTH)); 
localparam VEBPF_RD_WR_PTR_WIDTH = $clog2((((MAX_HDR_SIZE+2)/4) * RX_PKT_DESC_TABLE_DEPTH));
    // RX_PKT_DESC_TABLE_DEPTH = 4 atm
        // VEBPF_RD_WR_PTR_WIDTH = clog2(((134+2)/4) x 4) = clog2((34) x 4) = clog2(136) = 8
    // 34 words x 64 (depth atm) = 2176 words
    // clog2(2176) = 12 .. 12 bits = 4096 addresses 
localparam VEBPF_RX_PKT_HDR_BRAM_DEPTH = (MAX_HDR_SIZE_IN_WORDS * RX_PKT_DESC_TABLE_DEPTH);
// VEBPF_RX_PKT_HDR_BRAM_DEPTH = 34 words x 4 rxpkts = 136 words
// localparam VEBPF_RX_PKT_HDR_BRAM_DEPTH = (((MAX_TCP_HDR_SIZE+2)/4) * RX_PKT_DESC_TABLE_DEPTH);

localparam ETHER_TYPE_IPV4 = 16'h0800;
localparam IPV4_PROTOCOL_TCP = 8'h06;
localparam IPV4_PROTOCOL_UDP = 8'h11;

// Commenting this below out for a100T14_syn prj

//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH -1:0] desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination[RX_PKT_DESC_TABLE_DEPTH-1:0];
    // no longer limited to 3 bits

// reg [2:0] desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination[RX_PKT_DESC_TABLE_DEPTH-1:0];
    // 3 bit destination for desc table as of now.. 0-7 destination as of now.. This can be incremented to however many.. 
    // we can send the result of r0 output register of VeBPF directly to the attached subsystems as well.

// Commenting this below out for a100T14_syn prj
//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit[RX_PKT_DESC_TABLE_DEPTH-1:0]; 

reg desc_table_VeBPF_rx_pkt_hdr_processing_done_result_dropRxPkt_bit[RX_PKT_DESC_TABLE_DEPTH-1:0]; 

// Write pointer for writing to the desc table entry related to VeBPF Processing RESULT like rx pkt destination/error_bit/valid
reg [FIFO_DEPTH_ADDR_WDITH:0] wr_ptr_decs_table_VeBPF_result_rx_pkt_reg = 0, wr_ptr_decs_table_VeBPF_result_rx_pkt_next;



// this statment below infers a BRAM
(* ramstyle = "no_rw_check" *)
reg [RV_DATA_WIDTH-1:0] VeBPF_rx_pkt_hdr_bram_fifo[VEBPF_RX_PKT_HDR_BRAM_DEPTH-1:0]; 
// reg [RV_DATA_WIDTH-1:0] VeBPF_rx_pkt_hdr_bram_fifo[(((MAX_TCP_HDR_SIZE+2)/4) * RX_PKT_DESC_TABLE_DEPTH)-1:0]; 
    // 34 words x 64 (depth atm) = 2176 words = 8704 bytes = 8.5 KBi

// Commenting this below out for a100T14_syn prj
//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg desc_table_VeBPF_rx_pkt_hdr_processed_done_valid[RX_PKT_DESC_TABLE_DEPTH-1:0];  // 
    // making these distributed ramx cx min BRAM mem of e.g., 4K wont be utilized effectively by these BRAMs
// This ring buffer is for the desc table. This bit being 1 means that this desc table rx pkt hdr has been successfully processed by the VeBPF. 
// wether that processing lead to a known rx pkt or unkown, that result will be stored in a separate Queue.
    // RX_PKT_DESC_TABLE_DEPTH means total rx pkts that can be taken in currently for writing to DRAM while their metadata is kept in desc table and not cleared by riscv or any other subsystem/module

// Commenting this below out for a100T14_syn prj
//(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
reg [7:0] desc_table_VeBPF_rx_pkt_hdr_in_words_size[RX_PKT_DESC_TABLE_DEPTH-1:0]; // ... 1 byte width means max hdr size = 255... our max hdr = 134 + 2 
reg [10:0] desc_table_VeBPF_rx_pkt_hdr_in_bytes_size[RX_PKT_DESC_TABLE_DEPTH-1:0]; // ... 1 byte width means max hdr size = 255... our max hdr = 134 + 2 
    // this queue is to store the hdr size of the rx pkt being read by the VeBPF filer according to the VeBPF rd ptr
    // This desc table entry is for any FSM reading the rx_pkt (The VeBPF dataloading/processing FSM, etc),
    // so that FSM can readd/load those number of words/bytes into the VeBPF or anyother data memory

reg desc_table_VeBPF_rx_pkt_hdr_in_words_size_en;  // enable for writing rxpkt hdr size to its desc table fifo
reg [9:0] desc_table_VeBPF_rx_pkt_len_total_words_reg, desc_table_VeBPF_rx_pkt_len_total_words_next;


// rd pointer to read rxpkt hdr from the VeBPF rx pkt hdr bram fifo!!!
// incremented by VeBPF data mem writing FSM
reg [VEBPF_RD_WR_PTR_WIDTH:0] VeBPF_rx_pkt_hdr_bram_rd_ptr_reg, VeBPF_rx_pkt_hdr_bram_rd_ptr_next;
// reg [VEBPF_RD_WR_PTR_WIDTH-1:0] VeBPF_rx_pkt_hdr_bram_rd_ptr_reg, VeBPF_rx_pkt_hdr_bram_rd_ptr_next;

// write pointer for writing RxPkt headers to VeBPF_rx_pkt_hdr_bram_fifo
// incremented by main rx pkt writing FSM
reg [VEBPF_RD_WR_PTR_WIDTH:0] VeBPF_rx_pkt_hdr_bram_wr_ptr_reg, VeBPF_rx_pkt_hdr_bram_wr_ptr_next;
// reg [VEBPF_RD_WR_PTR_WIDTH-1:0] VeBPF_rx_pkt_hdr_bram_wr_ptr_reg, VeBPF_rx_pkt_hdr_bram_wr_ptr_next;

// combined VeBPF rxpkt hdr bram fifo wr/rd ptrs
reg [VEBPF_RD_WR_PTR_WIDTH:0] VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg, VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next;
reg [VEBPF_RD_WR_PTR_WIDTH:0] VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_reg, VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next;
reg VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_next, VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_reg;
reg VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next, VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_reg;
reg VeBPF_inc_wr_ptr_flag_next, VeBPF_inc_wr_ptr_flag_reg;

// imp notes for rd and wr ptrs from the DDR DMA FSM at the top of this module
    // // desc table fifo is full 
    // // full when first MSB different but rest same  // to take account of the rollover affect of ring buffer (1 extra addr bit to keep track of that)
    // wire desc_table_rx_pkt_full; // = wr_fifo_ptr_rx_pkt_reg == (rd_fifo_ptr_rx_pkt_reg ^ {1'b1, {FIFO_DEPTH_ADDR_WDITH{1'b0}}});
    // assign desc_table_rx_pkt_full = wr_fifo_ptr_rx_pkt_reg == (rd_fifo_ptr_rx_pkt_reg ^ {1'b1, {FIFO_DEPTH_ADDR_WDITH{1'b0}}});
    //     // for full condition lets imageine wr_fifo_ptr_rx_pkt_reg = 1000..000 and rd_fifo_ptr_rx_pkt_reg = 000..000 ..
    //     // this means that wr ptr has rolled over and now is equal to rd ptr, hence the desc table fifo is full now, which
    //     // is depicted by this XOR equation
    //     // Similarly the wr ptr rolls from 111..111 to 000...000 and rd ptr is at 1000..000 .. this equation would again tell us that the fifo is full
    //     // if wr == rd ptr then fifo is empty
    //     // that is why we declare rd and wr ptrs with width fifodepth+1 and use fifodepth only when reading or writing to fifos and use fifodepth+1
    //     // width of rd and wr ptrs when raising full or empty flags :3

    // // desc table fifo is empty when pointers match exactly
    // wire desc_table_rx_pkt_empty; // = wr_fifo_ptr_rx_pkt_reg == rd_fifo_ptr_rx_pkt_reg;
    // assign desc_table_rx_pkt_empty = wr_fifo_ptr_rx_pkt_reg == rd_fifo_ptr_rx_pkt_reg;

// might not need to use this FSM since the VeBPF_rx_pkt_hdr_bram_rd_ptr will be incremented by VeBPF_data_mem_writing_FSM
// and VeBPF_rx_pkt_hdr_bram_wr_ptr_reg will be incremented by main rx pkt reading FSM 
// reg [3:0] VeBPF_rx_pkt_hdr_writing_FSM_state_reg, VeBPF_rx_pkt_hdr_writing_FSM_state_next; 

reg [7:0] max_rx_pkt_hdr_word_size_reg, max_rx_pkt_hdr_word_size_next;  // either 34 or 21 words for TCP or UDP
reg rx_pkt_is_udp_reg, rx_pkt_is_udp_next;
reg rx_pkt_is_tcp_reg, rx_pkt_is_tcp_next;
reg rx_pkt_is_ipv4_reg, rx_pkt_is_ipv4_next;

reg [15:0] rx_pkt_etherType_reg, rx_pkt_etherType_next;
reg [7:0] rx_pkt_ipv4Protocol_reg, rx_pkt_ipv4Protocol_next;
reg VeBPF_rx_pkt_hdr_data_transfer_en_reg, VeBPF_rx_pkt_hdr_data_transfer_en_next;

// Write pointer for writing to the desc table entry related to VeBPF stuff like rx pkt len from main rxpkt sink fsm
reg [FIFO_DEPTH_ADDR_WDITH:0] wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg = 0, wr_ptr_decs_table_fifo_VeBPF_rx_pkt_next;
    // FIFO_DEPTH_ADDR_WDITH-1:0 is used for indexing.. MSBit is used for rollover detection

// Read pointer for reading the desc table entry related to VeBPF stuff like rx pkt len from desc table and writing it to VeBPF data mem
reg [FIFO_DEPTH_ADDR_WDITH:0] rd_ptr_decs_table_fifo_VeBPF_rx_pkt_reg = 0, rd_ptr_decs_table_fifo_VeBPF_rx_pkt_next;
    // FIFO_DEPTH_ADDR_WDITH-1:0 is used for indexing.. MSBit is used for rollover detection

// Emptry flag related to desc table entry for these pointers wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg/rd_ptr_decs_table_fifo_VeBPF_rx_pkt_reg
// desc table fifo VeBPF ptrs EMPTY flag, is empty when pointers match exactly
wire desc_table_VeBPF_rx_pkt_hdr_fifo_EMPTY;
assign desc_table_VeBPF_rx_pkt_hdr_fifo_EMPTY = rd_ptr_decs_table_fifo_VeBPF_rx_pkt_reg == wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg;

// Wires and Regs for FULL and EMPTY conditions for wr_ptr for VeBPF_rx_pkt_hdr_bram_fifo
reg signed [VEBPF_RD_WR_PTR_WIDTH+1:0] VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW;  // signed for comparing if DELTA LOW is negative or not
    // 1 bit for sign.. parameterize the width of these 
reg [VEBPF_RD_WR_PTR_WIDTH:0] VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_HIGH, VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_COMB;

// Full flag for the VeBPF rx pkt hdr bram fifo
reg VeBPF_rx_pkt_hdr_bram_fifo_FULL_next;
wire VeBPF_rx_pkt_hdr_bram_fifo_FULL;
assign VeBPF_rx_pkt_hdr_bram_fifo_FULL = VeBPF_rx_pkt_hdr_bram_fifo_FULL_next;

// Empty flag for the VeBPF rx pkt hdr bram fifo
reg VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next;
wire VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_FLAG;
assign VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_FLAG = VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next;

// Combinational block for FULL and EMPTY conditions for VeBPF_rx_pkt_hdr_bram_fifo
always @* begin

    // default condition
    VeBPF_rx_pkt_hdr_bram_fifo_FULL_next = 0;
    VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next = 1;  // default is empty

    // default conditions for DELTAs
    VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW = 0;
    VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_HIGH = 0;
    VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_COMB = 0;

    // definitions of DELTA LOW, HIGH, COMB after studying the simulation (cx I forgot the defs after I developed the code some time ago xP)
    // our rxpkthdr bram FIFO grows downwards with a max depth of VEBPF_RX_PKT_HDR_BRAM_DEPTH

    // VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW: This SIGNED register keeps track of how much distance does the wr ptr have with the lowest/deepest limit in 
    // the rxpkthdr bram fifo.. if wrptr > rdptr then that lowest/deepest limit is the bottom of the fifo, otherwise if rdptr > wrptr then 
    // lowest/deepest limit of the fifo is the distance between rdptr and (wrptr + MAX_HDR_SIZE_IN_WORDS) 

    // VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_HIGH: This reg keeps track of how much more space do we have for packet writing in the fifo,
    // it also checks if that space is atleast enough so that along with DELTA_LOW, DELTA_HIGH can add up to be MAX_HDR_SIZE_IN_WORDS atleast
    // meaning at least 1 more rxpkthdr can fit in the rxpkthdr BRAM fifo..

    // VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_COMB: This register is just a comparison/combination of DELTA_HIGH and DELTA_LOW

    // VeBPF_rx_pkt_hdr_bram_fifo FULL CONDITION CHECK

    // here we are checking if wr ptr is infront of rd ptr for rxpkthdr bram fifo 
    if(VeBPF_rx_pkt_hdr_bram_wr_ptr_reg > VeBPF_rx_pkt_hdr_bram_rd_ptr_reg) begin
        
        // debugging notes:
            // 2023_11_7_time_11_24_ILA_6_bit_ltx_fileToo
                // This ILA file has the bug I was searching for ,, The eth_network_interface_controller/eth_fifo_to_bram/VeBPF_rx_pkt_hdr_bram_wr_ptr_reg = 136
                // eth_network_interface_controller/eth_fifo_to_bram/VeBPF_rx_pkt_hdr_bram_rd_ptr_reg = 1
                // eth_network_interface_controller/eth_fifo_to_bram/VeBPF_rx_pkt_hdr_bram_fifo_FULL_next = 1
                // eth_network_interface_controller/eth_fifo_to_bram/VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW = 7FF = 0111 1111 1111  = -1 (used 2s compliment to decimal conversion) https://calculator-online.net/twos-complement-calculator/

                // VeBPF_rx_pkt_hdr_bram_wr_ptr_reg+MAX_HDR_SIZE_IN_WORDS = 136 + 34 = 170 WHERE VEBPF_RX_PKT_HDR_BRAM_DEPTH = 34 words x 4 rxpkts = 136 words 
                    // VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW = (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1) - VeBPF_rx_pkt_hdr_bram_wr_ptr_reg;          
                        // VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW = (136 -1) - 136 = -1;
                            // but VeBPF_rx_pkt_hdr_bram_wr_ptr_reg ptr should not be able to reach 136 in the current settings of 4 rxpkt depth of desctable
                            // and VEBPF_RX_PKT_HDR_BRAM_DEPTH = 34 words x 4 rxpkts = 136 words ...

                // so ATM the error is that VeBPF_rx_pkt_hdr_bram_wr_ptr_reg is == 136 but its max limit should have been
                // (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1) = 135.
                // there must be more errors but the first one I found is this,, there are errors causing this error so lets find it.       

        if ((VeBPF_rx_pkt_hdr_bram_wr_ptr_reg+MAX_HDR_SIZE_IN_WORDS) > (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin

            // distance of wr ptr from end of FIFO
            VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW = (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1) - VeBPF_rx_pkt_hdr_bram_wr_ptr_reg;
                // this shouldn't be negative since VeBPF_rx_pkt_hdr_bram_wr_ptr_reg will always be <= VEBPF_RX_PKT_HDR_BRAM_DEPTH
                    // 2023_11_7_time_11_24_ILA_6_bit_ltx_fileToo notes has VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW = -1 
                    // since VeBPF_rx_pkt_hdr_bram_wr_ptr_reg is WRONGlY = 136 since the max value should have been 135 = (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)

            // distance between "distance of wr ptr from end of FIFO" and MAX_HDR_SIZE_IN_WORDS
            VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_HIGH = MAX_HDR_SIZE_IN_WORDS - VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW;
                // 2023_11_7_time_11_24_ILA_6_bit_ltx_fileToo notes: 
                    // VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_HIGH = 34 - (-1) = 35 as in ILA_6

            // how far is the rd ptr from DELTA HIGH
            if(VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_HIGH >= (VeBPF_rx_pkt_hdr_bram_rd_ptr_reg -1)) begin  //how far is the rd ptr from DELTA HIGH
                // 2023_11_7_time_11_24_ILA_6_bit_ltx_fileToo notes: 
                    // 35 >=  ((VeBPF_rx_pkt_hdr_bram_rd_ptr_reg = 1) - 1)
                        // VeBPF_rx_pkt_hdr_bram_fifo_FULL_next = 1;               
                VeBPF_rx_pkt_hdr_bram_fifo_FULL_next = 1;
            end else begin
                VeBPF_rx_pkt_hdr_bram_fifo_FULL_next = 0;
            end

        end else if ((VeBPF_rx_pkt_hdr_bram_wr_ptr_reg+MAX_HDR_SIZE_IN_WORDS) <= (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin

            VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW = (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1) - (VeBPF_rx_pkt_hdr_bram_wr_ptr_reg+MAX_HDR_SIZE_IN_WORDS);
            VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_HIGH = VeBPF_rx_pkt_hdr_bram_rd_ptr_reg; // 0 i.e., start idx of bram // VeBPF_rx_pkt_hdr_bram_rd_ptr_reg - 0;  
            VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_COMB = VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW + VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_HIGH;

            if(VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_COMB <= MAX_HDR_SIZE_IN_WORDS) begin
                VeBPF_rx_pkt_hdr_bram_fifo_FULL_next = 1;
            end else begin
                VeBPF_rx_pkt_hdr_bram_fifo_FULL_next = 0;
            end

        end

    end else if (VeBPF_rx_pkt_hdr_bram_rd_ptr_reg > VeBPF_rx_pkt_hdr_bram_wr_ptr_reg) begin

        VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW = VeBPF_rx_pkt_hdr_bram_rd_ptr_reg - (VeBPF_rx_pkt_hdr_bram_wr_ptr_reg+MAX_HDR_SIZE_IN_WORDS);
        
        if (VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW <= 0) begin  // DELTA LOW is a signed reg
            VeBPF_rx_pkt_hdr_bram_fifo_FULL_next = 1;
        end else begin
            VeBPF_rx_pkt_hdr_bram_fifo_FULL_next = 0;
        end

    end

    // VeBPF_rx_pkt_hdr_bram_fifo EMPTY CONDITION CHECK
    if (VeBPF_rx_pkt_hdr_bram_wr_ptr_reg == VeBPF_rx_pkt_hdr_bram_rd_ptr_reg) begin
        VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next = 1;
    end else begin
        VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next = 0;
    end

end

integer i3;
integer i4;

initial begin

    // found the bug in my code that why wasn't the if condition as follows working;
        // if((NET_RX_FIFO_EMPTY(net_csr1) == 0) && (NET_RX_PKT_AVAIL(net_csr1)) && (NET_RX_PKT_VeBPF_VALID(net_csr1) == 1))
    // https://stackoverflow.com/questions/77748512/multiple-conditions-using-define-macro-functions-in-if-condition-is-not-working?noredirect=1#comment137070901_77748512
    // the bug was as mentioned in my comment on the stackoverflow question of mine:
        /*
            @PeterCordes you were correct, there was some other problem in my simulation. Including or excluding the 
            "define macro functions" in the if-condition did not make a difference and worked both ways after I found the bug today. 
            The bug was that in my FPGA hw rtl, I was not initializing the registers to zero and RISCV was reading "don't cares 0xXX" 
            when reading those registers, causing the ambiguity in the if-condition. Thanks for the directions and it was reassuring 
            that you were confident in your answer. What should I do with my question here now? –
        */
    
    if (SIMULATION) begin
        for (i4 = 0; i4 < RX_PKT_DESC_TABLE_DEPTH; i4 = i4 + 1) begin
            
            desc_table_VeBPF_rx_pkt_hdr_in_words_size[i4] <= 0;
            desc_table_VeBPF_rx_pkt_hdr_in_bytes_size[i4] <= 0;
            desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination[i4] <= 0;
            desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit[i4] <= 0;
            desc_table_VeBPF_rx_pkt_hdr_processed_done_valid[i4] <= 0;

        end
    end


end

// Seq block for FULL and EMPTY conditions for VeBPF_rx_pkt_hdr_bram_fifo and some other stuff I dont remember :3
always @(posedge clk) begin
    if(rst) begin

    // NEED TO COMMENT OUT ALL MEMORY INITIALIZATIONS TO 0 BECAUSE THEY WERE CAUSING INSANE AMOUNT OF EXTRA WIRE CONNECTIONS making it IMPOSSIBLE
    // for the PLACE AND ROUTE TOOL TO ROUTE ALL THE WIRES AND IMPLEMENT THE BITSTREAM (FAILED IN THE IMPLEMENTATION AND BITSTREAM GEN STAGE)

        // if (SIMULATION) begin
        //     for (i3 = 0; i3 < VEBPF_RX_PKT_HDR_BRAM_DEPTH; i3 = i3 + 1) begin
            
        //         VeBPF_rx_pkt_hdr_bram_fifo[i3] <= 0;

        //     end
        // end 
       
        // if (SIMULATION) begin
        //     for (i4 = 0; i4 < RX_PKT_DESC_TABLE_DEPTH; i4 = i4 + 1) begin
                
        //         desc_table_VeBPF_rx_pkt_hdr_in_words_size[i4] <= 0;
        //         desc_table_VeBPF_rx_pkt_hdr_in_bytes_size[i4] <= 0;
        //         desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination[i4] <= 0;
        //         desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit[i4] <= 0;
        //         desc_table_VeBPF_rx_pkt_hdr_processed_done_valid[i4] <= 0;

        //     end
        // end

        VeBPF_rx_pkt_hdr_bram_rd_ptr_reg <= 0; 
        VeBPF_rx_pkt_hdr_bram_wr_ptr_reg <= 0;

        max_rx_pkt_hdr_word_size_reg <= 0;

        rx_pkt_is_udp_reg <= 0;
        rx_pkt_is_tcp_reg <= 0;
        rx_pkt_is_ipv4_reg <= 0;

        rx_pkt_etherType_reg <= 0;
        rx_pkt_ipv4Protocol_reg <= 0;
        VeBPF_rx_pkt_hdr_data_transfer_en_reg <= 0;

        wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg <= 0;
        rd_ptr_decs_table_fifo_VeBPF_rx_pkt_reg <= 0;
        desc_table_VeBPF_rx_pkt_len_total_words_reg <= 0;

        wr_ptr_decs_table_VeBPF_result_rx_pkt_reg <= 0;

        VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_reg <= 0;
            
    end else begin
    
        VeBPF_rx_pkt_hdr_bram_rd_ptr_reg <= VeBPF_rx_pkt_hdr_bram_rd_ptr_next;
        VeBPF_rx_pkt_hdr_bram_wr_ptr_reg <= VeBPF_rx_pkt_hdr_bram_wr_ptr_next;

        max_rx_pkt_hdr_word_size_reg <= max_rx_pkt_hdr_word_size_next;

        rx_pkt_is_udp_reg <= rx_pkt_is_udp_next;
        rx_pkt_is_tcp_reg <= rx_pkt_is_tcp_next;
        rx_pkt_is_ipv4_reg <= rx_pkt_is_ipv4_next;

        rx_pkt_etherType_reg <= rx_pkt_etherType_next;
        rx_pkt_ipv4Protocol_reg <= rx_pkt_ipv4Protocol_next;
        VeBPF_rx_pkt_hdr_data_transfer_en_reg <= VeBPF_rx_pkt_hdr_data_transfer_en_next;

        wr_ptr_decs_table_fifo_VeBPF_rx_pkt_reg <= wr_ptr_decs_table_fifo_VeBPF_rx_pkt_next;
        rd_ptr_decs_table_fifo_VeBPF_rx_pkt_reg <= rd_ptr_decs_table_fifo_VeBPF_rx_pkt_next;

        wr_ptr_decs_table_VeBPF_result_rx_pkt_reg <= wr_ptr_decs_table_VeBPF_result_rx_pkt_next;

        desc_table_VeBPF_rx_pkt_len_total_words_reg <= desc_table_VeBPF_rx_pkt_len_total_words_next;

        VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_reg <= VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next;
        
    end

end 

// ********************************************************************************************************************************************************************
// ***************************************** VeBPF RXPKTHDR BRAM FULL OR EMPTY CHECKING FSM -> END *************************************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// Decalre the comb part in the FSMs that are using them  
// always @(*) begin

//     VeBPF_rx_pkt_hdr_bram_rd_ptr_next = VeBPF_rx_pkt_hdr_bram_rd_ptr_reg;
//     VeBPF_rx_pkt_hdr_bram_wr_ptr_next = VeBPF_rx_pkt_hdr_bram_wr_ptr_reg;
    
// end


// ********************************************************************************************************************************************************************
// ***************************************** VeBPF_data_mem_writing_FSM -> START *************************************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

// Re-WRITING this FSM so it loads the RxPktHdrs into VeBPF datamemory and loads the RxPktHdr word-len into VeBPF R1 register
    /*
        I'll be using 1D array that is widened to include signals for multiple VEBPFs as comp to 1 VEBPF .. T
        he reason for this is that I think 2D arrays like e.g., x bit wide and #VeBPFs deep would take a lot more resources
        than x-bit wide * # VeBPFs ... cx PANIC peeps used 1D arrays widened instead of using 2D array that were deeper.. and 2D arrays 
        took insane amount of resources when I used them as distributed LUT RAMS for pgm memory of VEBPFs

    */

    // https://stackoverflow.com/questions/50848947/verilog-assigning-a-named-generate-loops-wire-inside-a-for-loop
    /*
            • https://verificationacademy.com/forums/systemverilog/accessing-generate-block-hierarchy
            In order to reference an instance created inside a generate-for loop, you must use a constant or another genvar variable. That is because GENERATE_HEADER is not an array, it is part of a hierarchical scope name. So you could do
            
            virtual some_interface some_interface_arr[0:2];
            generate 
            for (i=0;i<3;i++)
            initial some_interface_arr[i]=testbench.GENERATE_HEADER[i].some_interface_inst;
            end
            endgenerate
            
        If you are using UVM/OVM you should be setting these interfaces in the config_db directly instead of assigning them to a local virtual interface array.        

    */

// ********************** Writing RxPkt to VeBPF data mem *************************
localparam [3:0]
    VEBPF_DATA_W_STATE_IDLE = 4'd0,
    //VEBPF_DATA_W_RXPKT_AVAIL = 4'd1,
    VEBPF_DATA_W_DATAMEM_LOAD_RXPKT_DW = 4'd2,
    VEBPF_DATA_W_DATAMEM_ACK_WAIT = 4'd3,
    VEBPF_DATA_W_COMPLETE_AND_CPU_START = 4'd4,
    VEBPF_PROCESSING = 4'd5,
    VEBPF_PROCESSING_DONE_DESCTABLE_FULL_AND_WR_PTRS_EQUAL = 4'd10,
    VEBPF_PROCESSING_DONE_RESULTS_WR_DESC_TABLE = 4'd6,
    VEBPF_LOAD_NEXT_RX_PKT_HDR = 4'd7,
    VEBPF_DATA_W_COMPLETE_WAIT_FOR_VEBPF_PROC_COMPLETION = 4'd8,
    VEBPF_DATA_W_TESTING_STATE_WAITING = 4'd9;
        // deactivate reset in the state VEBPF_DATA_W_COMPLETE_AND_CPU_START which will start VEBPF CPU PROCESSING 
    // maybe a separate FSM for VEBPF PROCESSING
        // VEBPF_CPU_PROCESSING = 4'd5
        // VEBPF_CPU_HALT_DONE = 4'd6
        // VEBPF_CPU_HALT_ERROR = 4'd7
            // reset the data.adr and csr_r1
                // If(self.hbpf.halt | ~self.hbpf.reset_n,
                //     If(self.hbpf.halt,
                //         # hBPF finished processing of packet
                //         # reset for next packet
                //         self.hbpf.data.adr.eq(0),
                //         self.hbpf.csr_r1.storage.eq(0)
                //     ),

// state, next_state    
reg [3:0] VeBPF_data_w_state_reg, VeBPF_data_w_state_next;

// counter for offset for loading rxpkt hdr words into VeBPF data memory w.r.t the rd pointer for the rxpkt hdr bram fifo
reg [9:0] VeBPF_rx_pkt_len_words_counter_reg, VeBPF_rx_pkt_len_words_counter_next;

reg [9:0] VeBPF_rx_pkt_len_total_words_reg, VeBPF_rx_pkt_len_total_words_next;

reg [31:0] VeBPF_rx_mem_data_word_reg;

reg VeBPF_rx_mem_data_word_en;

reg VeBPF_data_w_dw_complete_flag_reg, VeBPF_data_w_dw_complete_flag_next;

reg [9:0] VeBPF_RdPtr_desc_table_rx_pkt_len_words_reg;
reg [11:0] VeBPF_RdPtr_desc_table_rx_pkt_len_bytes_reg;

reg [VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH - 1:0] desc_table_VeBPF_r0_reg, desc_table_VeBPF_r0_next;
// reg [2:0] desc_table_VeBPF_r0_reg, desc_table_VeBPF_r0_next;

reg desc_table_VeBPF_error_reg, desc_table_VeBPF_error_next;
reg desc_table_VeBPF_dropRxPkt_reg, desc_table_VeBPF_dropRxPkt_next;
reg desc_table_VeBPF_valid_reg, desc_table_VeBPF_valid_next;
reg desc_table_VeBPF_en_wr_reg, desc_table_VeBPF_en_wr_next;

reg [2:0] VeBPF_r0_reg, VeBPF_r0_next; 
reg VeBPF_error_reg, VeBPF_error_next;

reg [VEBPF_REG_DATA_WIDTH -1 :0] VeBPF_r1_reg, VeBPF_r1_next;
reg [7:0] VeBPF_csr_ctl_reg, VeBPF_csr_ctl_next;  
reg VeBPF_reset_n_reg, VeBPF_reset_n_next;

reg VeBPF_data_mem_write_MSB_LSB_word_flag_reg, VeBPF_data_mem_write_MSB_LSB_word_flag_next;
reg [VEBPF_MEM_DATA_WIDTH - 1:0] VeBPF_data_mem_64bit_wdata_reg, VeBPF_data_mem_64bit_wdata_next;
reg [3:0] VeBPF_data_mem_ww_reg, VeBPF_data_mem_ww_next;
reg VeBPF_data_mem_we_reg, VeBPF_data_mem_we_next; 
reg [VEBPF_MEM_DATA_AW - 1:0] VeBPF_data_mem_adr_reg, VeBPF_data_mem_adr_next;
reg VeBPF_data_mem_stb_reg, VeBPF_data_mem_stb_next;

reg VeBPF_data_loading_done_flag_reg, VeBPF_data_loading_done_flag_next;

reg VeBPF_result_loading_done_flag_reg, VeBPF_result_loading_done_flag_next;

// flag for checking if all VeBPF rules have been uploaded into all VeBPF filters or not
wire flag_all_VeBPF_rules_uploaded_to_all_VeBPFs;  
assign flag_all_VeBPF_rules_uploaded_to_all_VeBPFs = VeBPF_rules_scheduler_all_rules_uploaded_flag;

reg [7:0] testing_counter_reg, testing_counter_next;

reg rxpkt_filtering_done;

// // Wires and Regs for fifo rollover conditions for rd_ptr for VeBPF_rx_pkt_hdr_bram_fifo
// reg signed [VEBPF_RD_WR_PTR_WIDTH+1:0] VeBPF_rx_pkt_bram_fifo_rd_ptr_DELTA_LOW;  // signed for comparing if DELTA LOW is negative or not
//     // 1 bit for sign.. parameterize the width of these 
// reg [VEBPF_RD_WR_PTR_WIDTH:0] VeBPF_rx_pkt_bram_fifo_rd_ptr_DELTA_HIGH, VeBPF_rx_pkt_bram_fifo_rd_ptr_DELTA_COMB;

// FSM for loading rxpkt into data memory of VeBPF
    // Seq part
always @(posedge clk) begin
    if(rst) begin
        
        VeBPF_data_w_state_reg <= VEBPF_DATA_W_STATE_IDLE;

        VeBPF_data_mem_we_reg <= 0; 
        VeBPF_rx_pkt_len_words_counter_reg <= 0;
        VeBPF_data_mem_write_MSB_LSB_word_flag_reg <= 0;
        VeBPF_data_mem_ww_reg <= 0;
        VeBPF_data_mem_64bit_wdata_reg <= 0;
        VeBPF_rx_pkt_len_total_words_reg <= 0;

        VeBPF_reset_n_reg <= 0;  // reset is active here (active low)

        VeBPF_data_mem_stb_reg <= 0;

        VeBPF_data_mem_adr_reg <= 0; 

        VeBPF_r1_reg <= 0;

        VeBPF_rx_mem_data_word_reg <= 0;

        VeBPF_data_w_dw_complete_flag_reg <= 0;

        VeBPF_csr_ctl_reg <= 0;

        VeBPF_RdPtr_desc_table_rx_pkt_len_words_reg <= 0;
        VeBPF_RdPtr_desc_table_rx_pkt_len_bytes_reg <= 0;

        VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_reg <= 0;

        desc_table_VeBPF_r0_reg <= 0;
        desc_table_VeBPF_error_reg <= 0;
        desc_table_VeBPF_dropRxPkt_reg <= 0;
        // desc_table_VeBPF_valid_reg <= 0;
        // desc_table_VeBPF_en_wr_reg <= 0;

        VeBPF_r0_reg <= 0;
        VeBPF_error_reg <= 0;

        VeBPF_data_loading_done_flag_reg <= 0;

        VeBPF_result_loading_done_flag_reg <= 0;

        testing_counter_reg <= 0;


    end else begin

        VeBPF_data_w_state_reg <= VeBPF_data_w_state_next;
        // VeBPF_data_w_state_reg <= VEBPF_DATA_W_STATE_IDLE;
                // TODO -> DONE: remove the constant state allocation above after testing BRAM full flags

        VeBPF_rx_pkt_len_total_words_reg <= VeBPF_rx_pkt_len_total_words_next;
        VeBPF_data_mem_64bit_wdata_reg <= VeBPF_data_mem_64bit_wdata_next;
        VeBPF_data_mem_ww_reg <= VeBPF_data_mem_ww_next;
        VeBPF_data_mem_write_MSB_LSB_word_flag_reg <= VeBPF_data_mem_write_MSB_LSB_word_flag_next;
        VeBPF_rx_pkt_len_words_counter_reg <= VeBPF_rx_pkt_len_words_counter_next;
        VeBPF_data_mem_we_reg <= VeBPF_data_mem_we_next; 

        VeBPF_reset_n_reg <= VeBPF_reset_n_next;

        VeBPF_data_mem_stb_reg <= VeBPF_data_mem_stb_next;

        VeBPF_data_mem_adr_reg <= VeBPF_data_mem_adr_next;

        VeBPF_r1_reg <= VeBPF_r1_next;

        VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_reg <= VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_next;

        if (VeBPF_rx_mem_data_word_en) begin
            // VeBPF_rx_mem_data_word_reg <= VeBPF_rx_mem[VeBPF_rx_pkt_len_words_counter_reg];
            // VeBPF_rx_mem_data_word_reg <= VeBPF_rx_mem[VeBPF_rx_pkt_len_words_counter_next];
                // replaced VeBPF_rx_pkt_len_words_counter_reg with VeBPF_rx_pkt_len_words_counter_next

            // Reading the RxPkt hdr data from VeBPF rx pkt hdr bram fifo using counter VeBPF_rx_pkt_len_words_counter_next and
            // the rd pointer VeBPF_rx_pkt_hdr_bram_rd_ptr_reg that increments rxpkt hdr word len according to the 
            // rxpkt hdr word len stored in desc table fifo
            
            // VeBPF_rx_mem_data_word_reg <= VeBPF_rx_pkt_hdr_bram_fifo[VeBPF_rx_pkt_len_words_counter_next+VeBPF_rx_pkt_hdr_bram_rd_ptr_reg];
            
            VeBPF_rx_mem_data_word_reg <= VeBPF_rx_pkt_hdr_bram_fifo[VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next];
            // VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next = VeBPF_rx_pkt_len_words_counter_next+VeBPF_rx_pkt_hdr_bram_rd_ptr_reg
        end

        VeBPF_data_w_dw_complete_flag_reg <= VeBPF_data_w_dw_complete_flag_next;

        VeBPF_csr_ctl_reg <= VeBPF_csr_ctl_next;

        // reading rxpkt hdr size in words & bytes from desc table using pointer read pointer rd_ptr_decs_table_fifo_VeBPF_rx_pkt_reg
        // VeBPF_RdPtr_desc_table_rx_pkt_len_words_reg <= desc_table_VeBPF_rx_pkt_hdr_in_words_size[
        //                                                 rd_ptr_decs_table_fifo_VeBPF_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]];
        // VeBPF_RdPtr_desc_table_rx_pkt_len_bytes_reg <= desc_table_VeBPF_rx_pkt_hdr_in_bytes_size[
        //                                                 rd_ptr_decs_table_fifo_VeBPF_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]];

        // replacing rd_ptr_decs_table_fifo_VeBPF_rx_pkt_reg with rd_ptr_decs_table_fifo_VeBPF_rx_pkt_next so the correct desc_table_VeBPF_rx_pkt_hdr_in_words_size gets loaded 
        // before state VEBPF_DATA_W_DATAMEM_LOAD_RXPKT_DW = 4'd2, during state IDLE after 1st rxpkthdr is processed and rd ptr is incremented during the last state
        VeBPF_RdPtr_desc_table_rx_pkt_len_words_reg <= desc_table_VeBPF_rx_pkt_hdr_in_words_size[
                                                        rd_ptr_decs_table_fifo_VeBPF_rx_pkt_next[FIFO_DEPTH_ADDR_WDITH-1:0]];
        VeBPF_RdPtr_desc_table_rx_pkt_len_bytes_reg <= desc_table_VeBPF_rx_pkt_hdr_in_bytes_size[
                                                        rd_ptr_decs_table_fifo_VeBPF_rx_pkt_next[FIFO_DEPTH_ADDR_WDITH-1:0]];

        desc_table_VeBPF_r0_reg <= desc_table_VeBPF_r0_next;
        desc_table_VeBPF_error_reg <= desc_table_VeBPF_error_next;
        desc_table_VeBPF_dropRxPkt_reg <= desc_table_VeBPF_dropRxPkt_next;
        // desc_table_VeBPF_valid_reg <= desc_table_VeBPF_valid_next;
        // desc_table_VeBPF_en_wr_reg <= desc_table_VeBPF_en_wr_next;

        VeBPF_r0_reg <= VeBPF_r0_next;
        VeBPF_error_reg <= VeBPF_error_next;

        VeBPF_data_loading_done_flag_reg <= VeBPF_data_loading_done_flag_next;
        
        VeBPF_result_loading_done_flag_reg <= VeBPF_result_loading_done_flag_next;

        testing_counter_reg <= testing_counter_next;

    end

end


// FSM or loading rxpkt into data memory of VeBPF
    // Comb part
    // TODO: make conditions for resetting rxpkthdr fifo rd ptr to its prev starting idle state value
    // and other such counter values to their initial conditions at idle state IFFFF VeBPF Rules Scheduler
    // Uploader FSM was given a flag for uploading a fresh set of rules.
always @* begin
    
    // default state
    VeBPF_data_w_state_next = VeBPF_data_w_state_reg; 

    
    VeBPF_rx_pkt_len_total_words_next = VeBPF_rx_pkt_len_total_words_reg;
    VeBPF_data_mem_64bit_wdata_next = VeBPF_data_mem_64bit_wdata_reg;
    VeBPF_data_mem_ww_next = VeBPF_data_mem_ww_reg;
    VeBPF_data_mem_write_MSB_LSB_word_flag_next = VeBPF_data_mem_write_MSB_LSB_word_flag_reg;
    VeBPF_rx_pkt_len_words_counter_next = VeBPF_rx_pkt_len_words_counter_reg;
    VeBPF_data_mem_we_next = VeBPF_data_mem_we_reg;

    VeBPF_reset_n_next = VeBPF_reset_n_reg;

    VeBPF_data_mem_stb_next = VeBPF_data_mem_stb_reg;

    VeBPF_data_mem_adr_next = VeBPF_data_mem_adr_reg;

    VeBPF_r1_next = VeBPF_r1_reg;  // // VeBPF R1 register equated to rx_pkt hdr len in bytes

    VeBPF_data_w_dw_complete_flag_next = VeBPF_data_w_dw_complete_flag_reg;

    VeBPF_csr_ctl_next = VeBPF_csr_ctl_reg;

    VeBPF_rx_mem_data_word_en = 0;

    // rd pointer to read rxpkt hdr from the VeBPF rx pkt hdr bram fifo!!!
    VeBPF_rx_pkt_hdr_bram_rd_ptr_next = VeBPF_rx_pkt_hdr_bram_rd_ptr_reg;

    // rd pointer for reading the rxpkt hdr len in bytes/word from desc table for the VeBPF dataprocessing/loading FSM
    rd_ptr_decs_table_fifo_VeBPF_rx_pkt_next = rd_ptr_decs_table_fifo_VeBPF_rx_pkt_reg;

    // Write pointer for writing to the desc table entry related to VeBPF Processing RESULT like rx pkt destination/error_bit/valid
        // no rd ptr required.. the desc table entry will be read by the subsystem reading the rxpkts and rxpkt metadata
    wr_ptr_decs_table_VeBPF_result_rx_pkt_next = wr_ptr_decs_table_VeBPF_result_rx_pkt_reg;

    // // default conditions for rd_ptr deltas
    // VeBPF_rx_pkt_bram_fifo_rd_ptr_DELTA_LOW = 0;
    // VeBPF_rx_pkt_bram_fifo_rd_ptr_DELTA_HIGH = 0;
    // VeBPF_rx_pkt_bram_fifo_rd_ptr_DELTA_COMB = 0;

    // combined VeBPF rxpkt hdr bram fifo rd ptr
    VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next = VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_reg;

    VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_next = VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_reg;

    desc_table_VeBPF_r0_next = desc_table_VeBPF_r0_reg;
    desc_table_VeBPF_error_next = desc_table_VeBPF_error_reg; 
    desc_table_VeBPF_dropRxPkt_next = desc_table_VeBPF_dropRxPkt_reg; 
    // desc_table_VeBPF_valid_next = desc_table_VeBPF_valid_reg;
    desc_table_VeBPF_valid_next = 0;
    desc_table_VeBPF_en_wr_next = 0;  // by default this is 0

    VeBPF_r0_next = VeBPF_r0_reg;
    VeBPF_error_next = VeBPF_error_reg;

    VeBPF_data_loading_done_flag_next = VeBPF_data_loading_done_flag_reg; // need to save the prev value 
    // VeBPF_data_loading_done_flag_next = 0;  // default is 0
        // avoid using _next with comb regs that don't register/save their previous values

    VeBPF_result_loading_done_flag_next = VeBPF_result_loading_done_flag_reg;

    testing_counter_next = testing_counter_reg;

    rxpkt_filtering_done = 0;

    case(VeBPF_data_w_state_reg)

        VEBPF_DATA_W_STATE_IDLE: begin

            VeBPF_data_w_state_next = VEBPF_DATA_W_STATE_IDLE;

            VeBPF_rx_pkt_len_total_words_next = 0;
            VeBPF_data_mem_64bit_wdata_next = 0;
            VeBPF_data_mem_ww_next = 0;
            VeBPF_data_mem_write_MSB_LSB_word_flag_next = 0;

            VeBPF_rx_pkt_len_words_counter_next = 0;
                // VeBPF_rx_pkt_len_words_counter_next = 0 will load the first rxpkt mem word into VeBPF_rx_mem_data_word_reg

            VeBPF_data_mem_we_next = 0;
            
            // reset is active (can load data memory in VeBPF now)
            VeBPF_reset_n_next = 0; 

            VeBPF_data_mem_stb_next = 0;
            VeBPF_data_mem_adr_next = 0;
            VeBPF_r1_next = 0;

            VeBPF_data_w_dw_complete_flag_next = VeBPF_data_w_dw_complete_flag_reg;

            VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_next = 0;

            // also add another if condition that if VeBPF has been programmed or not

            // if(rx_pkt_avail_bram_reg) begin 
            // if(!desc_table_VeBPF_rx_pkt_hdr_fifo_EMPTY) begin // rx pkt hdr available in desc table rxpkt hdr fifo columns
            if((!desc_table_VeBPF_rx_pkt_hdr_fifo_EMPTY) & flag_all_VeBPF_rules_uploaded_to_all_VeBPFs) begin 
                // rx pkt hdr available in desc table rxpkt hdr fifo columns and checking if all VeBPF rules have been uploaded into all VeBPF filters or not
                
                // Should the flag "VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_FLAG" also be checked?
                // 

                // if(rx_pkt_len_words_counter_reg > 0) begin
                if(VeBPF_RdPtr_desc_table_rx_pkt_len_words_reg > 0) begin  // rxpkt len of available rx pkt is greater than 0 :3
                    
                    VeBPF_data_w_state_next = VEBPF_DATA_W_DATAMEM_LOAD_RXPKT_DW;

                    // VeBPF_r1_next = rx_pkt_len_counter_reg; // VeBPF R1 register equated to rx_pkt len in bytes
                    VeBPF_r1_next = VeBPF_RdPtr_desc_table_rx_pkt_len_bytes_reg; // VeBPF R1 register equated to rx_pkt hdr len in bytes

                    // VeBPF_rx_pkt_len_words_counter_next is counter for offset for loading rxpkt hdr words into VeBPF data memory w.r.t the rd pointer for the rxpkt hdr bram fifo
                    if(VeBPF_rx_pkt_len_words_counter_next == 0) begin  // load rxpkt word located at index = 0 into register VeBPF_rx_mem_data_word_reg
                        
                        VeBPF_rx_mem_data_word_en = 1;

                        // Combinbed Read Pointer for reading data from rxpkt hdr bram fifo
                        VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next = VeBPF_rx_pkt_len_words_counter_next 
                                                                                            + VeBPF_rx_pkt_hdr_bram_rd_ptr_reg;
                        // FIRST 1st ROLLOVER for rd ptr for VeBPF rxpkt hdr bram fifo
                            // VeBPF_rx_pkt_len_words_counter_next is 0 anyway.
                        // if (VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next > (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin
                        if ((VeBPF_rx_pkt_len_words_counter_next + VeBPF_rx_pkt_hdr_bram_rd_ptr_reg) > (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin
                            VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next = 0;
                            VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_next = 1;
                                // VeBPF BRAM rd ptr has been rolled over.. Flag set for it
                        end

                    end

                    // if(rx_pkt_len_counter_reg[1:0] > 0) begin   
                        
                    //     VeBPF_rx_pkt_len_total_words_next = rx_pkt_len_words_counter_reg + 1; 
                    //     // writing rx pkt length in words to the desc table
                    //     // this will take care of the case when e.g., there are 5 bytes of RxPkts, that means there are 2 data words (4 byte words)
                    //     // So this will give a value of 2 (words) to VeBPF_rx_pkt_len_total_words_reg when there are 5 bytes of RxPkts, otherwise
                    //     // VeBPF_rx_pkt_len_total_words_reg will be given a value of (1 word) if there are 4 byte of rx_pkt 

                    // end else begin
                    //     VeBPF_rx_pkt_len_total_words_next = rx_pkt_len_words_counter_reg;
                    // end

                    // This condition above already taken care of in the main rxpkt sink FSM of assigning rrxpkt hdr word len (corrected word len) to the desc table
                    VeBPF_rx_pkt_len_total_words_next = VeBPF_RdPtr_desc_table_rx_pkt_len_words_reg;


                end else begin
                    VeBPF_data_w_state_next = VEBPF_DATA_W_STATE_IDLE;
                end


            end

        end

        VEBPF_DATA_W_DATAMEM_LOAD_RXPKT_DW: begin

            VeBPF_data_w_state_next = VEBPF_DATA_W_DATAMEM_LOAD_RXPKT_DW;

            VeBPF_data_mem_we_next = 0;     // write enable
            VeBPF_data_mem_ww_next = 0;     // write_width
            VeBPF_data_mem_stb_next = 0;    // write_strobe
            VeBPF_data_mem_adr_next = 0;    // write_address

            // if (VeBPF_rx_pkt_len_words_counter_reg < (VeBPF_rx_pkt_len_total_words_reg - 1)) begin  
            if (VeBPF_rx_pkt_len_words_counter_reg < (VeBPF_rx_pkt_len_total_words_reg)) begin  
            // needed to comment out the " - 1" in the line above because we are writing 8 byte double words, other wise last word was being missed when
            // word length was 75 (including the idx = 0 word) 
                // Note to ponder on // if rxpkt len is 5bytes rx_pkt_len_words_counter_reg = 1, if rxpkt len is 4bytes rx_pkt_len_words_counter_reg = 1
                    
                VeBPF_rx_pkt_len_words_counter_next = VeBPF_rx_pkt_len_words_counter_reg + 1;
                // VeBPF_rx_pkt_len_words_counter_next will be used to preload the rxpkt word into reg on next clk cycle

                VeBPF_rx_mem_data_word_en = 1;  // load rxpkt word located into register VeBPF_rx_mem_data_word_reg

                if ((!VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_reg)) begin // VeBPF Bram rd ptr flag not set.. rd ptr not rolled over yet

                    // This combined RdPtr VeBPF declared here again due to en being = 1 here agin
                    // Combinbed Read Pointer for reading data from rxpkt hdr bram fifo
                    VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next = VeBPF_rx_pkt_len_words_counter_next 
                                                                                        + VeBPF_rx_pkt_hdr_bram_rd_ptr_reg;

                    // rollover condition mentioned here again due to combined RdPtr VeBPF declared here again due to en being = 1 here agin
                    // FIRST 1st ROLLOVER for rd ptr for VeBPF rxpkt hdr bram fifo 
                    // if (VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next > (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin
                    if ((VeBPF_rx_pkt_len_words_counter_next + VeBPF_rx_pkt_hdr_bram_rd_ptr_reg) > (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin
                        // why does wr ptr version have regs here instead of next as follows:
                            // Rollover condition for VeBPF_Bram_wr_ptr
                            // if ((rx_pkt_len_words_counter_reg + VeBPF_rx_pkt_hdr_bram_wr_ptr_reg) > (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin

                        VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next = 0;
                        VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_next = 1;
                            // VeBPF BRAM rd ptr has been rolled over.. Flag set for it
                    end
                
                end else if (VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_reg) begin
                
                    VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next = VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_reg + 1;
                    // VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_reg will now keep track of the rolled over VeBPF Bram rd ptr location
                    // and if the V rd ptr was rolled over, this var will keep track of its location and the V rd ptr will be assigned this variable
                    // (VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_reg). If no rollover occurs then V rd ptr will simply be
                    // = V_rd_ptr + rxpkt_hdr_word_len

                end

                // If the rxpkt len words counter becomes equal to total rxpkt word len
                // if (VeBPF_rx_pkt_len_words_counter_next == (VeBPF_rx_pkt_len_total_words_reg - 1)) begin

                // commenting this out below and writing it outside the enclosing if condition with corrections
                if (VeBPF_rx_pkt_len_words_counter_next == (VeBPF_rx_pkt_len_total_words_reg)) begin
                    // I think this is fine since counting starts from 0, so if counter_next has reached len_total_words_reg, even on the second
                    // iteration of this state, it means that the req len of rxpkt have been uploaded.. take example of hdr size = 20.. 
                    // the rxpkts from 0 - 19 have already been uploaded

                    // easier to read would have been following version
                    // if (VeBPF_rx_pkt_len_words_counter_reg == (VeBPF_rx_pkt_len_total_words_reg - 1)) begin

                    // needed to comment out the " - 1" in the line above because we are writing 8 byte double words, other wise last word was being missed when
                    // word length was 75 (including the idx = 0 word)
                        // I believe the reason for the above condition is that we are using _next for comparison instead of reg, thats why -1 was removed
     
                    VeBPF_data_w_dw_complete_flag_next = 1;  // rxpkt completely written to VeBPF data mem
                                        
     
                end

            end


            // if (VeBPF_rx_pkt_len_words_counter_next >= (VeBPF_rx_pkt_len_total_words_reg)) begin
                
            //     if (VeBPF_data_mem_write_MSB_LSB_word_flag_next) begin
            //         // reason for this condition is that if the last word is on the second cycle of this state
            //         // then its data would get loaded on the next visit of this state.. So hence we delay the activation 
            //         // of this completion flag..
            //             // just think if the rxpkthdr len was 20 instead of 21 (even number is the key here)

            //         VeBPF_data_w_dw_complete_flag_next = 1; 
            
            //     end 
            // end 
            
            VeBPF_data_mem_write_MSB_LSB_word_flag_next = ~(VeBPF_data_mem_write_MSB_LSB_word_flag_reg); // this flag start with 0 upon reset 

                
            if(!(VeBPF_data_mem_write_MSB_LSB_word_flag_reg)) begin  // enters this for LSB writing of 64bit data word
                
                VeBPF_data_mem_64bit_wdata_next = {{32{1'b0}} ,VeBPF_rx_mem_data_word_reg};  // 64bit word
                     // VeBPF_rx_pkt_len_words_counter_next = 0 will load the first rxpkt mem word into VeBPF_rx_mem_data_word_reg
                        // first word already loaded into VeBPF_rx_mem_data_word_reg, during this clk cycle
                        // VeBPF_rx_pkt_len_words_counter_next = 1 will load the next rxpkt word (at idx = 1) 
                        // into VeBPF_rx_mem_data_word_reg at the next clk cycle when VeBPF_data_mem_write_MSB_LSB_word_flag_reg
                        // becomes 1 and VeBPF_rx_mem_data_word_reg is concatenated to MSB word

            end else begin
                

                VeBPF_data_mem_64bit_wdata_next = VeBPF_data_mem_64bit_wdata_reg |
                    {VeBPF_rx_mem_data_word_reg, {32{1'b0}}};  // 64bit word

                // TODO - done (this was buggy after thinkin about this from sim): test the code below later and comment out the block above
                // if (!VeBPF_data_w_dw_complete_flag_reg) begin
                    
                //     VeBPF_data_mem_64bit_wdata_next = VeBPF_data_mem_64bit_wdata_reg |
                //         {VeBPF_rx_mem_data_word_reg, {32{1'b0}}};  // 64bit word

                // end else begin

                //     // so that we dont get garbage memory
                //     VeBPF_data_mem_64bit_wdata_next = VeBPF_data_mem_64bit_wdata_reg;

                // end 

                // VeBPF related signals

                VeBPF_csr_ctl_next[1] = 1;
                    // .rst((!reset_n_int) ^ (csr_ctl[1])), 
                    // VeBPF_csr_ctl_next[1] = 1 to get access to VeBPF data memory and overwite its reset and 0 to give access back to VeBPF
                    // while VeBPF_reset_n_next = 0; // reset is active (can load data memory in VeBPF now)
                        // rst(1 ^ 1) = rst(0)  // rst is deactivated
                    // when running VeBPF cpu VeBPF_reset_n_next = 1 and VeBPF_csr_ctl_next[1] = 0 which means:
                        // rst(0 ^ 0) = rst(0)  // rst is deactivated
                    // what happens on rst(1 ^ 0) = rst(1) // rst activated .. value of VeBPF rst is used
                    // what happens on rst(0 ^ 1) = rst(1) // rst activated .. value of VeBPF rst is 
                    // not used but is still active even though csr_ctl[1] = 1.. so for using csr_ctl[1]
                    // VeBPF rst should be active (reset_n_int = 0)

                VeBPF_data_mem_we_next = 1;     // write enable
                VeBPF_data_mem_ww_next = 8;     // write_width
                VeBPF_data_mem_stb_next = 1;    // write_strobe
                // write_address 
                VeBPF_data_mem_adr_next = (VeBPF_rx_pkt_len_words_counter_reg - 1) << 2; // dw aligned
                // multiplied by 4 ( << 2 ) for converting word addressing to byte addressing  
                    // 2 words written for each 64 bit dw .. so its byte address would be 2 x 4 = 8 bytes 

                // (VeBPF_rx_pkt_len_words_counter_reg - 1) minus is being done because this expression occurs on
                // the 2nd clk cycle, and after the 1st clk cycle, VeBPF_rx_pkt_len_words_counter_reg becomes odd
                // cx of addition of 1 into it.

                // VeBPF_data_mem_adr_next is 4 byte aligned cx of multiplication by 4 above, but thats not required 
                // cx data is stored in form of byte aligned

                VeBPF_data_w_state_next = VEBPF_DATA_W_DATAMEM_ACK_WAIT;
                
            end

        end

        VEBPF_DATA_W_DATAMEM_ACK_WAIT: begin

            VeBPF_data_w_state_next = VEBPF_DATA_W_DATAMEM_ACK_WAIT;

            // if(VeBPF_data_mem_ack_output_port) begin
            if(&(VeBPF_data_mem_ack_output_port_combined_global)) begin
                // making sure all VeBPFs have acknowledge_arb_vebpf_selector_ind memory write

                VeBPF_data_mem_we_next = 0;     // write enable
                VeBPF_data_mem_ww_next = 0;     // write_width
                VeBPF_data_mem_stb_next = 0;    // write_strobe
                VeBPF_data_mem_adr_next = 0;    // data mem address

                // deeper if else statements have priority but for a particular ifelse of same depth, the higher one has priority
                if(VeBPF_data_w_dw_complete_flag_reg) begin  
                    VeBPF_data_w_dw_complete_flag_next = 0;
                    VeBPF_csr_ctl_next[1] = 0;  
                        // .rst((!reset_n_int) ^ (csr_ctl[1])),
                        // VeBPF_csr_ctl_next[1] = 1 to get access to VeBPF data memory and overwite its reset while reset is ACTIVE and 
                        // make VeBPF_csr_ctl_next[1] = 0 to give access to VeBPF data memory back to VeBPF while reset is ACTIVE

                    // vebpf data loading complete flag high
                    VeBPF_data_loading_done_flag_next = 1;
                    
                    VeBPF_data_w_state_next = VEBPF_DATA_W_COMPLETE_WAIT_FOR_VEBPF_PROC_COMPLETION;
                    // VeBPF_data_w_state_next = VEBPF_DATA_W_COMPLETE_AND_CPU_START;
                end else begin
                    VeBPF_data_w_state_next = VEBPF_DATA_W_DATAMEM_LOAD_RXPKT_DW;
                end 
            end

        end

        VEBPF_DATA_W_COMPLETE_WAIT_FOR_VEBPF_PROC_COMPLETION: begin 

            VeBPF_data_w_state_next = VEBPF_DATA_W_COMPLETE_WAIT_FOR_VEBPF_PROC_COMPLETION;            

            // wait for vebpf processing complete signal to go back to idle state and load next rxpkt hdr
            // also look at state VEBPF_LOAD_NEXT_RX_PKT_HDR where wr ptr for desc table is being incremented.. increment that here if you need to
            // upon VeBPF processing completion

            // TODO -> DONE: write logic in this FSM for next rxpkthdr upload into VeBPF data mem and updating results desc table and incrementing the 
            // rdptr of desc table for next rxpkthdr data

            // VeBPF processing/filtering for current rxpkt has been completed flag
            if (VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag) begin

                // go to result writing state where desc table is updated, might have to wait a clk cycle there  
                // VeBPF_data_w_state_next = VEBPF_PROCESSING_DONE_RESULTS_WR_DESC_TABLE;
                
                // for detailed comments look at comments at the bottom under the comment "// Imp debug notes on 28 Nov 2023:"
                    // in short we don't want to overwite the results of desc table at idx 0 when wrptr_desc is 4 (desc table depth of 4)
                if ((desc_table_rx_pkt_full) && (wr_ptr_decs_table_VeBPF_result_rx_pkt_reg == wr_fifo_ptr_rx_pkt_reg)) begin

                    VeBPF_data_w_state_next = VEBPF_PROCESSING_DONE_DESCTABLE_FULL_AND_WR_PTRS_EQUAL;

                end else begin

                    VeBPF_data_w_state_next = VEBPF_PROCESSING_DONE_RESULTS_WR_DESC_TABLE;

                end 


                // reset vebpf data loading complete flag
                VeBPF_data_loading_done_flag_next = 0;

            end


        end

        VEBPF_PROCESSING_DONE_DESCTABLE_FULL_AND_WR_PTRS_EQUAL: begin

            VeBPF_data_w_state_next = VEBPF_PROCESSING_DONE_DESCTABLE_FULL_AND_WR_PTRS_EQUAL;

            // if ((!desc_table_rx_pkt_full) || (wr_ptr_decs_table_VeBPF_result_rx_pkt_reg != wr_fifo_ptr_rx_pkt_reg)) begin
            if ((!desc_table_rx_pkt_full)) begin

                VeBPF_data_w_state_next = VEBPF_PROCESSING_DONE_RESULTS_WR_DESC_TABLE;

            end 

        end 

        // ***************************** FSM STATE Below Skipped *************************
        // VEBPF_DATA_W_COMPLETE_AND_CPU_START: begin

        //     VeBPF_data_w_state_next = VEBPF_DATA_W_COMPLETE_AND_CPU_START;

        //     VeBPF_reset_n_next = 1; // reset is de-activated (rx pkt data loaded into memory in VeBPF now, now run the VeBPF cpu)
        //         // when running VeBPF cpu VeBPF_reset_n_next = 1 and VeBPF_csr_ctl_next[1] = 0 which means:
        //             // rst(0 ^ 0) = rst(0)  // rst is deactivated
                    
        //     // note that program mem hasn't been loaded into VeBPF yet. Will check first if rxpkt has been loaded properly into VeBPF
        //     // also can change the data memory of VeBPF to load the data word bytes in 1 clk cycle to decrease the latency of loading rxpkt into data mem  

        //     if(VeBPF_reset_n_reg) begin // VeBPF reset deactivated 

        //         VeBPF_data_w_state_next = VEBPF_PROCESSING;

        //     end

        // end

        // ***************************** FSM STATE Below Skipped *************************
        // VEBPF_PROCESSING: begin

        //     VeBPF_data_w_state_next = VEBPF_PROCESSING;

        //     if(VeBPF_halt) begin // VeBPF has finihsed processing the rxpkt

        //         // go to state where results are written to the desc table
        //         VeBPF_data_w_state_next = VEBPF_PROCESSING_DONE_RESULTS_WR_DESC_TABLE;
        //         VeBPF_reset_n_next = 0;  // Activate the reset to VeBPF

        //         // since we are giving the VeBPF CPU a reset here, better save its output here
        //         VeBPF_r0_next = VeBPF_r0[2:0];
        //         VeBPF_error_next = VeBPF_error;


        //     end

        // end

        VEBPF_PROCESSING_DONE_RESULTS_WR_DESC_TABLE: begin

            // stay in same state
            VeBPF_data_w_state_next = VEBPF_PROCESSING_DONE_RESULTS_WR_DESC_TABLE;

            // if desc table avail and VeBPF valid entries aren't being cleared at the moment, then write to desc table entries here
            // although both writes using wr ptr and rd ptr can happen happen in parallel cx both ptrs are pointing at diff locations
            // cx otherwise the desc table would be EMPTY or FULL.. but just for good measure we will wait till the rxpkt avail and VeBPF 
            // valid bits are cleared first, pointed to by desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg flag
                // so this is basically from WRITE FSM that is dealing with incrementing rd ptr from riscv and clearing the
                // desc table available bit using the riscv that is pointed to by rd ptr
            if (!desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg) begin


                // this if cond below will process the 1 extra rxpkt that wasn't uplaoded to memory while desc table was full,
                // but won't upload the results to the desc table until that desc table entry is read first by the riscv or anyother subsystem

                // saving the results when wrptr here goes at 3 but wr_fifo_ptr is at 4 and desc table full flag is HIGH
                if (!VeBPF_result_loading_done_flag_reg) begin

                    // disable dataloading flag
                    VeBPF_result_loading_done_flag_next = 1;

                    // writing VeBPF processing results to the rxpkt descriptor table        
                    desc_table_VeBPF_r0_next = VeBPF_result_evaluator_final_result_reg;
                    desc_table_VeBPF_error_next = VeBPF_result_evaluator_transfer_to_descTable_final_result_error_flag_reg;
                    desc_table_VeBPF_dropRxPkt_next = VeBPF_result_evaluator_transfer_to_descTable_final_result_pkt_drop_flag_reg;
                    desc_table_VeBPF_valid_next = 1;
                    desc_table_VeBPF_en_wr_next = 1;

                end

                // this was the bug!!!! I was overwriting the result of 1 extra rxpkt while doing testing of a100T22 prj on 11-22-2023
                if ((!desc_table_rx_pkt_full) && (VeBPF_result_loading_done_flag_reg)) begin

                    // go to VEBPF_LOAD_NEXT_RX_PKT_HDR to update ptrs to load rxpkt hdr of the next rxpkt 
                    VeBPF_data_w_state_next = VEBPF_LOAD_NEXT_RX_PKT_HDR;

                    // reset the flag!
                    VeBPF_result_loading_done_flag_next = 0;

                    // // writing VeBPF processing results to the rxpkt descriptor table        
                    // desc_table_VeBPF_r0_next = VeBPF_result_evaluator_final_result_reg;
                    // desc_table_VeBPF_error_next = VeBPF_result_evaluator_transfer_to_descTable_final_result_error_flag_reg;
                    // desc_table_VeBPF_dropRxPkt_next = VeBPF_result_evaluator_transfer_to_descTable_final_result_pkt_drop_flag_reg;
                    // desc_table_VeBPF_valid_next = 1;
                    // desc_table_VeBPF_en_wr_next = 1;

                    // desc_table_VeBPF_r0_next = VeBPF_r0_reg;
                    // desc_table_VeBPF_error_next = VeBPF_error_reg;
                    // desc_table_VeBPF_error_next = VeBPF_rule_selector_and_result_tracker_rxpkt_error_flag_reg;

                    /*

                    // rxpkt destination desc table entry .. using 3 LSB bits of VeBPF r0 register
                    desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination[
                        wr_ptr_decs_table_VeBPF_result_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] = VeBPF_r0[2:0];

                    // rxpkt error bit desc table entry... error bit should be 0 if there is no error
                    desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit[
                        wr_ptr_decs_table_VeBPF_result_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] = VeBPF_error;
                    
                    // TODO: Experiment ... uncomment or modify for below
                    // desc_table_VeBPF_rx_pkt_hdr_processed_done_valid[
                    // wr_ptr_decs_table_VeBPF_result_rx_pkt_reg[FIFO_DEPTH_ADDR_WDITH-1:0]] = 1;

                    // increment the wr_ptr_decs_table_VeBPF_result_rx_pkt_reg pointer (it will only increment
                    // when there is space in the desc table due to the DDR_RxPktWritingFSM)
                    wr_ptr_decs_table_VeBPF_result_rx_pkt_next = wr_ptr_decs_table_VeBPF_result_rx_pkt_reg + 1;
                        // this wont overshoot the desc table write pointer of MEM WR FSM WR pointer cx that FSM
                        // will only take in rx pkts once it has space in the desc table for it

                    */
                end

            end

        end

        VEBPF_LOAD_NEXT_RX_PKT_HDR: begin

            // // stay in same state
            // VeBPF_data_w_state_next = VEBPF_LOAD_NEXT_RX_PKT_HDR;

            // // if rx_pkt_hdr_bram_fifo is not EMPTY (there is rx pkt hdr available in the bram fifo)
            // if (!VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_FLAG) begin  // or this empty flag can be checked in VeBPF IDLE STATE

            // go to VeBPF IDLE state
            VeBPF_data_w_state_next = VEBPF_DATA_W_STATE_IDLE;
            // VeBPF_data_w_state_next = VEBPF_DATA_W_TESTING_STATE_WAITING;
                // TODO -> DONE : comment this and uncomment the above one after testing is done

            rxpkt_filtering_done = 1;

            // shifted from the previous state.. => incrementing wr_ptr_decs_table_VeBPF_result_rx_pkt_reg
            // only 1 clk cycle in this state so wont be adding multiple times to the same pointer  

            // increment the wr_ptr_decs_table_VeBPF_result_rx_pkt_reg pointer (it will only increment
            // when there is space in the desc table due to the DDR_RxPktWritingFSM)
            wr_ptr_decs_table_VeBPF_result_rx_pkt_next = wr_ptr_decs_table_VeBPF_result_rx_pkt_reg + 1;
                // this wont overshoot the desc table write pointer of MEM WR FSM WR pointer cx that FSM
                // will only take in rx pkts once it has space in the desc table for it

            if (!(VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_reg)) begin
                // "VeBPF_rx_pkt_hdr_bram_rd_ptr_next" is incremented by the rxpkt hdr wordsize len "VeBPF_RdPtr_desc_table_rx_pkt_len_words_reg"
                
                // VeBPF_rx_pkt_hdr_bram_rd_ptr_next = VeBPF_rx_pkt_hdr_bram_rd_ptr_reg + VeBPF_RdPtr_desc_table_rx_pkt_len_words_reg;
                VeBPF_rx_pkt_hdr_bram_rd_ptr_next = VeBPF_rx_pkt_hdr_bram_rd_ptr_reg + VeBPF_rx_pkt_len_total_words_reg;
                    // VeBPF_RdPtr_desc_table_rx_pkt_len_words_reg was the len in words of the current rx pkt that was processed by the VeBPF
                // the VeBPF rd ptr is not being incremented by max rxpkt hdr len.. rather by the number of VeBPF rx pkt hdr words ..
                // so why is the VeBPF wr ptr being incremented by max rx pkt hdr words??
            
            end else if (VeBPF_rx_pkt_hdr_bram_rd_ptr_rollover_flag_reg) begin
                
                // correction
                VeBPF_rx_pkt_hdr_bram_rd_ptr_next = VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_reg;
                    // dont need to increment by 1 cx it has already been incremented from the state load pkt hdr

                // incorrect below
                // VeBPF_rx_pkt_hdr_bram_rd_ptr_next = VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_reg + 1;
                    // if the V rd ptr was rolled over.. VeBPF_rxpkt_hdr_bram_fifo_rdptr_plus_rxpkt_len_words_counter_next was equated to 0 and 
                    // was incremented by 1 till rx pkt word counter was == VeBPF_rx_pkt_len_total_words_reg .... so last value of 
                    // the combined ptr was VeBPF_rx_pkt_hdr_bram_rd_ptr_reg, hence for the next V rd ptr = VeBPF_rx_pkt_hdr_bram_rd_ptr_reg + 1, i.e., 
                    // the next ptr after the last used V comb rd ptr

            end

            /*  Dont need this anymore.. This is buggy
                // Rollover condition for the rxpkt_hdr_bram_fifo for the rd_ptr
                    // if rd_ptr_reg + rx_pkt_len_words_reg
                // 2nd Rollover condition
                if((VeBPF_rx_pkt_hdr_bram_rd_ptr_next) > (VEBPF_RX_PKT_HDR_BRAM_DEPTH -1)) begin
                    
                    VeBPF_rx_pkt_hdr_bram_rd_ptr_next = 0;
                    //VeBPF_rx_pkt_bram_fifo_rd_ptr_DELTA_LOW = (VEBPF_RX_PKT_HDR_BRAM_DEPTH - 1) - (VeBPF_rx_pkt_hdr_bram_rd_ptr_reg + VeBPF_RdPtr_desc_table_rx_pkt_len_words_reg);

                end
            */

            // NEED to CHECK if there is a new RX pkt available?? Will look at that in VeBPF IDLE STATE

            // Also the rd ptr "rd_ptr_decs_table_fifo_VeBPF_rx_pkt_next" for the above mentioned rxpkt hdr wordsize len
            // desc table entry columns "desc_table_VeBPF_rx_pkt_hdr_in_words_size & desc_table_VeBPF_rx_pkt_hdr_in_bytes_size" is also incremented.

            // rd pointer for reading the rxpkt hdr len in bytes/word from desc table for the VeBPF dataprocessing/loading FSM
            rd_ptr_decs_table_fifo_VeBPF_rx_pkt_next = rd_ptr_decs_table_fifo_VeBPF_rx_pkt_reg + 1;

            // end


        end

        // done testing this
        /*VEBPF_DATA_W_TESTING_STATE_WAITING: begin 

                VeBPF_data_w_state_next = VEBPF_DATA_W_TESTING_STATE_WAITING;

                // taking in 4 pkts more
                // if (testing_counter_reg < 4) begin 
                if (testing_counter_reg < 2) begin 

                    VeBPF_data_w_state_next = VEBPF_DATA_W_STATE_IDLE;

                    testing_counter_next = testing_counter_reg + 1;

                end

        end*/

    endcase

    // Notes ... VEBPF_DATA_W_COMPLETE_AND_CPU_START state will turn on the VeBPF cpu, as soon as the result is available
    // HALT signal will become 1 and results will be available in R0 register of VeBPF CPU.
    
    // There will be a Write_VeBPF_result_pointer that will write the results of the VeBPF CPU processing into 
    // the desc table fields of "VeBPF Proc Done" and "VeBPF Rx Pkt Dst"

    // The Write_VeBPF_result_pointer will increment to write the next result as soon as next rx pkt becomes available, and that 
    // will only happen when the desc table is not FULL, either Read pointer for desc table was incremented and rxpkts were consumed
    // or the desc just didn't fill up even if the RdPtr was static.
    // So no need to compate WritePtrs of this FSM with RxPktWritingToDDR FSM, i.e., that Write_VeBPF_result_pointer can not overtake
    // the WrPtr of RxPktWritingToDDR FSM and stuff like that (RdPtr of RxPktWritingToDDR FSM). Same idea for the Wr and Rd Ptrs for
    // filling the VeBPF related desc tables (RxPkt len/wordLen), of not comparing those Ptrs with Ptrs of RxPktWritingToDDR FSM.

    // Next Steps Notes: We will wait after VEBPF_DATA_W_COMPLETE_AND_CPU_START, for the HALT signal, and also have a desc table entry
    // for any errors in the end result of processing of the VeBPF CPU.  
    // As soon as we receive the HALT signal we go to state VEBPF_PROC_DONE_AND_WRITE_RESULT_DESC_TABLE , the results are stored in 
    // the desc table and the Write_VeBPF_result_pointer is incremented. 

    // Then the "VeBPF dataloading and processing FSM" goes to state "VEBPF_LOAD_NEXT_RX_PKT_HDR", where the rd ptr 
    // "VeBPF_rx_pkt_hdr_bram_rd_ptr_next" is incremented by the rxpkt hdr wordsize len "VeBPF_RdPtr_desc_table_rx_pkt_len_words_reg".
    // Also the rd ptr "rd_ptr_decs_table_fifo_VeBPF_rx_pkt_next" for the above mentioned rxpkt hdr wordsize len
    // desc table entry columns "desc_table_VeBPF_rx_pkt_hdr_in_words_size & desc_table_VeBPF_rx_pkt_hdr_in_bytes_size" is also incremented.

    // After the VeBPF_rx_pkt_hdr_bram_rd_ptr_reg has been incremented, the "VeBPF dataloading and processing FSM" will check
    // if the VeBPF_rx_pkt_hdr_bram_fifo bram fifo is not EMPTY (the rd ptr didn't reach the wr ptr and there are more rxpkt hdrs available),
    // This flag will be used to check that "VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_FLAG"

    // Also after incrementing "rd_ptr_decs_table_fifo_VeBPF_rx_pkt_next" for desc_table_VeBPF_rx_pkt_hdr_in_words_size & 
    // desc_table_VeBPF_rx_pkt_hdr_in_bytes_size", it will be checked if that desc table fifo entry is empty using this flag
    // "desc_table_VeBPF_rx_pkt_hdr_fifo_EMPTY"
    
    // So if the VeBPF_rx_pkt_hdr_bram_fifo bram fifo is not EMPTY, then the "VeBPF dataloading and processing FSM" will check if
    // the desc table "desc_table_VeBPF_rx_pkt_hdr_fifo_EMPTY" is not empty, then the next rxpkt hdr lengths and rxpkthdr data word
    // will be loaded into the registers of "VeBPF dataloading and processing FSM" and then the rxpkt hdr will be transferred to 
    // VeBPF data memory the same way and this goes on.

end


// ********************************************************************************************************************************************************************
// ***************************************** VeBPF_data_mem_writing_FSM -> END *************************************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


integer i_var_dump;
integer i_var_dump2;
integer i_var_dump3;
integer i_var_dump4;
integer i_var_dump5;
integer i_var_dump6;
integer i_var_dump7;

// this is the length of the program being read above 
localparam VEBPF_TEST_PROG_LENGTH_FOR_SIMULATION = 9;

// block for dumping 2D data arrays out for simulation waveform      
initial begin
  
  // selecting the already generated top simulation file
  $dumpfile("top.fst");
  
    for (i_var_dump = 0; i_var_dump < VEBPF_RX_PKT_HDR_BRAM_DEPTH; i_var_dump = i_var_dump + 1) begin
        // dumping rxpkt hdr bram fifo data out
        $dumpvars(0, VeBPF_rx_pkt_hdr_bram_fifo[i_var_dump]); 
    end 

    for (i_var_dump2 = 0; i_var_dump2 < RX_PKT_DESC_TABLE_DEPTH; i_var_dump2 = i_var_dump2 + 1) begin
        // dumping rxpkt hdr bram fifo data out
        $dumpvars(0, desc_table_VeBPF_rx_pkt_hdr_in_words_size[i_var_dump2]); 
        $dumpvars(0, desc_table_VeBPF_rx_pkt_hdr_in_bytes_size[i_var_dump2]); 
        $dumpvars(0, desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination[i_var_dump2]); 
        $dumpvars(0, desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit[i_var_dump2]); 
        $dumpvars(0, desc_table_VeBPF_rx_pkt_hdr_processed_done_valid[i_var_dump2]); 
        $dumpvars(0, desc_table_rx_pkt_avail[i_var_dump2]);
        $dumpvars(0, desc_table_rx_pkt_start_mem_addr[i_var_dump2]);
        $dumpvars(0, desc_table_rx_pkt_len[i_var_dump2]);
        $dumpvars(0, desc_table_rx_pkt_len_words[i_var_dump2]);
        
    end 

    for (i_var_dump3 = 0; i_var_dump3 < RX_TX_PKT_BRAM_DEPTH; i_var_dump3 = i_var_dump3 + 1) begin
        $dumpvars(0, rx_mem[i_var_dump3]);
        $dumpvars(0, tx_mem1[i_var_dump3]);
        $dumpvars(0, tx_mem2[i_var_dump3]);
    end
    // When to reset or CLEAR values of desc_table_VeBPF_rx_pkt_hdr_processed_done_valid or other desc_table_VeBPF related values? And how to clear them?
    
    
    // since we are testing 3 RULES
    for (i_var_dump4 = 0; i_var_dump4 < (3*VEBPF_TEST_PROG_LENGTH_FOR_SIMULATION) + 5; i_var_dump4 = i_var_dump4 + 1) begin
        $dumpvars(0, VeBPF_rules_fifo[i_var_dump4]);
    end

    // since we are testing 3 RULES
    for (i_var_dump5 = 0; i_var_dump5 < NUMBER_OF_VEBPF; i_var_dump5 = i_var_dump5 + 1) begin
        $dumpvars(0, rules_selected_for_VeBPF_array[i_var_dump5]);
    end

    for (i_var_dump6 = 0; i_var_dump6 < TX_PKT_DESC_TABLE_DEPTH; i_var_dump6 = i_var_dump6 + 1) begin
        // dumping rxpkt hdr bram fifo data out
        $dumpvars(0, desc_table_tx_pkt_len[i_var_dump6]); 
        $dumpvars(0, desc_table_tx_pkt_len_words[i_var_dump6]); 
        $dumpvars(0, desc_table_tx_pkt_start_mem_addr[i_var_dump6]); 
        $dumpvars(0, desc_table_tx_pkt_avail[i_var_dump6]); 
        $dumpvars(0, desc_table_tx_pkt_transfer_done[i_var_dump6]); 
        
    end 

    // for (i_var_dump6 = 0; i_var_dump6 < VEBPF_MAX_NUM_OF_RULES; i_var_dump6 = i_var_dump6 + 1) begin
    //     $dumpvars(0, Global_VeBPF_Result_Array[i_var_dump6]);
    // end

    // for (i_var_dump7 = 0; i_var_dump7 < (RX_PKT_DESC_TABLE_DEPTH*VEBPF_MAX_NUM_OF_RULES); i_var_dump7 = i_var_dump7 + 1) begin
    //     $dumpvars(0, desc_table_Global_VeBPF_Result_Array[i_var_dump7]);
    // end
    

end


/*
    https://electronics.stackexchange.com/questions/74277/what-is-the-operator-called-in-verilog

    logic [31: 0] a_vect;
    logic [0 :31] b_vect;

    logic [63: 0] dword;
    integer sel;

    a_vect[ 0 +: 8] // == a_vect[ 7 : 0]
    a_vect[15 -: 8] // == a_vect[15 : 8]
    b_vect[ 0 +: 8] // == b_vect[0 : 7]
    b_vect[15 -: 8] // == b_vect[8 :15]

    dword[8*sel +: 8] // variable part-select with fixed width


*/

// ********************************************************************************************************************************************************************
// ***************************************** VeBPFs Instantiations and Connections -> START *************************************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

localparam VEBPF_TICKS_DATA_WIDTH = 64;
localparam VEBPF_REG_DATA_WIDTH = 64;
// using reduced register width for output R0 register so that less register width is used during syn
localparam VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH = 8;  
localparam VEBPF_MEM_DATA_WIDTH = 64;
localparam VEBPF_MEM_DATA_WW = 4;  // Write Width in bytes (number of bytes being written)
localparam VEBPF_MEM_DATA_AW = 11;  // Address width in bits
localparam VEBPF_CSR_CTL_DATA_WIDTH = 8;
localparam VEBPF_CSR_STATUS_DATA_WIDTH = 8;

wire [(VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH*NUMBER_OF_VEBPF) - 1:0] VeBPF_r0_combined_global; // output

// using same value of VeBPF_r1_reg input for all VeBPFs atm
// wire [(VEBPF_PROG_DATA_WIDTH*NUMBER_OF_VEBPF) - 1:0] VeBPF_r1_combined_global; // input

// not using these register inputs to VeBPFs atm
// wire [(VEBPF_PROG_DATA_WIDTH*NUMBER_OF_VEBPF) - 1:0] VeBPF_r2_combined_global; // input
// wire [(VEBPF_PROG_DATA_WIDTH*NUMBER_OF_VEBPF) - 1:0] VeBPF_r3_combined_global; // input
// wire [(VEBPF_PROG_DATA_WIDTH*NUMBER_OF_VEBPF) - 1:0] VeBPF_r4_combined_global; // input
// wire [(VEBPF_PROG_DATA_WIDTH*NUMBER_OF_VEBPF) - 1:0] VeBPF_r5_combined_global; // input

wire [(VEBPF_TICKS_DATA_WIDTH*NUMBER_OF_VEBPF - 1):0] VeBPF_ticks_combined_global; // output
    // might need to track VeBPF ticks in result tracker FSM so that 
    // the FSM doesn't wait too long for VeBPF processing of an rxpkthdr.
    // I can reduce the VEBPF_TICKS_DATA_WIDTH here atleast if I only need to
    // look at a small value of VeBPF ticks because 64 bit width for VeBPF ticks
    // can be a lot when there are multiple VeBPFs on a small FPGA

// wire [(VEBPF_CSR_CTL_DATA_WIDTH*NUMBER_OF_VEBPF) - 1:0] VeBPF_csr_ctl_combined_global;  // input
// wire [(VEBPF_CSR_CTL_DATA_WIDTH*NUMBER_OF_VEBPF) - 1:0] VeBPF_csr_status_combined_global; // output

wire [NUMBER_OF_VEBPF - 1:0] VeBPF_reset_n_combined_global; // input

// VeBPF data mem combined global 
wire [NUMBER_OF_VEBPF - 1:0] VeBPF_data_mem_ack_output_port_combined_global; // output

// look at explanation under "// same as the case with "VeBPF_data_mem_64bit_wdata"" comment, as to why the combined global 
// signals have been commented out below

// wire [(NUMBER_OF_VEBPF*VEBPF_MEM_DATA_WIDTH) - 1:0] VeBPF_data_mem_64bit_wdata_combined_global; // input data mem
// single means all VeBPF wires are being driven by the same wire
wire [VEBPF_MEM_DATA_WIDTH - 1:0] VeBPF_data_mem_64bit_wdata_single_combined_global; // input data mem
assign VeBPF_data_mem_64bit_wdata_single_combined_global = VeBPF_data_mem_64bit_wdata_reg;

// wire [(NUMBER_OF_VEBPF*VEBPF_MEM_DATA_WW) - 1:0] VeBPF_data_mem_ww_combined_global; // input data mem write width in bytes (number of bytes being written)
// single means all VeBPF wires are being driven by the same wire
wire [VEBPF_MEM_DATA_WW - 1:0] VeBPF_data_mem_ww_single_combined_global; // input data mem write width in bytes (number of bytes being written)
assign VeBPF_data_mem_ww_single_combined_global = VeBPF_data_mem_ww_reg;



// wire [NUMBER_OF_VEBPF - 1:0] VeBPF_data_mem_we_combined_global;
wire VeBPF_data_mem_we_single_combined_global;  // input
assign VeBPF_data_mem_we_single_combined_global = VeBPF_data_mem_we_reg;

// wire [(NUMBER_OF_VEBPF*VEBPF_MEM_DATA_AW) - 1:0] VeBPF_data_mem_adr_combined_global;
wire [VEBPF_MEM_DATA_AW - 1:0] VeBPF_data_mem_adr_single_combined_global; // input
assign VeBPF_data_mem_adr_single_combined_global = VeBPF_data_mem_adr_reg;

// wire [NUMBER_OF_VEBPF - 1:0] VeBPF_data_mem_stb_combined_global;
wire VeBPF_data_mem_stb_single_combined_global; // input
assign VeBPF_data_mem_stb_single_combined_global = VeBPF_data_mem_stb_reg;

wire [NUMBER_OF_VEBPF - 1:0] VeBPF_halt_combined_global;  // output
wire [NUMBER_OF_VEBPF - 1:0] VeBPF_error_combined_global;  // output

// combined global signals for VeBPF pgm mem
// wire [(VEBPF_PROG_ADDRESS_WIDTH*NUMBER_OF_VEBPF - 1):0] VeBPF_prog_addr_in_combined_global;
// wire [(VEBPF_PROG_DATA_WIDTH*NUMBER_OF_VEBPF - 1):0] VeBPF_prog_data_in_combined_global;
// wire [NUMBER_OF_VEBPF - 1:0] VeBPF_prog_write_enable_in_combined_global;
// wire [NUMBER_OF_VEBPF - 1:0] VeBPF_prog_reset_in_combined_global;

wire [VEBPF_PROG_ADDRESS_WIDTH - 1:0] VeBPF_prog_addr_in_single_combined_global;  // input, single means all VeBPF wires are being driven by the same wire
assign VeBPF_prog_addr_in_single_combined_global = VeBPF_prog_addr_all_rules_uploader_in;

wire [VEBPF_PROG_DATA_WIDTH - 1:0] VeBPF_prog_data_in_single_combined_global;  // input
assign VeBPF_prog_data_in_single_combined_global = VeBPF_prog_data_all_rules_uploader_in;

wire VeBPF_prog_write_enable_in_single_combined_global;  // input
assign VeBPF_prog_write_enable_in_single_combined_global = VeBPF_prog_write_enable_all_rules_uploader_in;

wire VeBPF_prog_reset_in_single_combined_global;  // input
assign VeBPF_prog_reset_in_single_combined_global = VeBPF_prog_reset_all_rules_uploader_in;

// reprog pgm mem signal (only combined and single+combined)

wire [NUMBER_OF_VEBPF - 1:0] VeBPF_run_next_selected_rule_en_combined_global;
    // different wire will be used for each VeBPF since the particular VeBPF that is available 
    // will be selected according to its index, and that index will be used to enable that 
    // VeBPF using this run next selected rule enable array
assign VeBPF_run_next_selected_rule_en_combined_global = VeBPF_run_next_selected_rule_en_rules_selector_in;


wire [VEBPF_PROG_ADDRESS_WIDTH - 1:0] VeBPF_ip_next_rule_in_single_combined_global;  // input
    // same wire will be used for all VeBPFs (to save resources) since they will be reprogrammed one by one
assign VeBPF_ip_next_rule_in_single_combined_global = VeBPF_ip_next_rule_rules_selector_in;

generate 
    genvar n;

    for (n = 0; n < NUMBER_OF_VEBPF; n = n + 1) begin : VEBPF

        // assigning vales to _combined_global wires
        // assign VeBPF_csr_ctl_combined_global[n*VEBPF_CSR_CTL_DATA_WIDTH +: VEBPF_CSR_CTL_DATA_WIDTH] = VeBPF_csr_ctl_reg; 
            // VeBPF_csr_ctl_reg is coming from the VeBPF data loader FSM
            // or I can just skip this and assign VeBPF_csr_ctl_reg to VeBPF_csr_ctl to reduce number of wired connections! 


        // resetn input
        wire VeBPF_reset_n;
        assign VeBPF_reset_n = VeBPF_reset_n_combined_global[n];
        // assign VeBPF_reset_n = VeBPF_reset_n_reg;
        // direct assignment from VeBPF data loading FSM
        // VeBPF_reset_n_reg might be controlled by multiple FSMs

        // 8 bit input
        wire [VEBPF_CSR_CTL_DATA_WIDTH - 1:0] VeBPF_csr_ctl;  // input (8 bit). csr_ctl[0] for reset ==> assign reset_n_int = (reset_n | csr_ctl[0]);
        // assign VeBPF_csr_ctl = VeBPF_csr_ctl_reg;
        // assign VeBPF_csr_ctl = VeBPF_csr_ctl_combined_global[n*VEBPF_CSR_CTL_DATA_WIDTH +: VEBPF_CSR_CTL_DATA_WIDTH];
            // skipping the assign statement above since I can assign VeBPF_csr_ctl_reg to VeBPF input VeBPF_csr_ctl directly
                // this is because we are uploading the same rxpkthdr data to all VeBPF filters
        assign VeBPF_csr_ctl = VeBPF_csr_ctl_reg;

        // 8 bit output
        wire [VEBPF_CSR_STATUS_DATA_WIDTH - 1:0] VeBPF_csr_status; // output (8 bit). csr_status[0] = reset_n_int; csr_status[1] = halt; csr_status[2] = error; csr_status[7] = debug;
        // assign VeBPF_csr_status_combined_global[n*VEBPF_CSR_CTL_DATA_WIDTH +: VEBPF_CSR_CTL_DATA_WIDTH] = VeBPF_csr_status;
            // dont need VeBPF_csr_status atm in synthesized design so commenting it out to reduce hw uasge 

        // VeBPF Output register // output // 64 bit
        wire [VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH - 1:0] VeBPF_r0;  // reduced reg width
        assign VeBPF_r0_combined_global[n*VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH +: VEBPF_REDUCED_OUTPUT_R0_REG_DATA_WIDTH] = VeBPF_r0;
            // need this assignment since each VeBPF will have a different or same output depending upon the rule its running on the rxpkthdr data
            // can also reduce VeBPF_r0_combined_global data width if I need to look at fewer r0 register bits
            // I can have a separate VEBPF_REG_R0_DATA_WIDTH parameter for VeBPF_r0_combined_global
            // TODO: the above comment

        // VeBPF registers (r1-r5) used for inputting to VeBPF // inputs // 64 bit
        wire [VEBPF_REG_DATA_WIDTH - 1:0] VeBPF_r1;
        // assign VeBPF_r1 = VeBPF_r1_combined_global[n*VEBPF_REG_DATA_WIDTH +: VEBPF_REG_DATA_WIDTH];
        assign VeBPF_r1 = VeBPF_r1_reg;  // VeBPF R1 register equated to rx_pkt hdr len in bytes in VeBPF data loading FSM
                // all VeBPF will have rxpkt len in bytes on their R1 register
                // direct assignment from VeBPF data loading FSM 


        wire [VEBPF_REG_DATA_WIDTH - 1:0] VeBPF_r2;
        // assign VeBPF_r2 = VeBPF_r2_combined_global[n*VEBPF_REG_DATA_WIDTH +: VEBPF_REG_DATA_WIDTH];
            // not using these register inputs to VeBPFs atm

        wire [VEBPF_REG_DATA_WIDTH - 1:0] VeBPF_r3;
        // assign VeBPF_r3 = VeBPF_r3_combined_global[n*VEBPF_REG_DATA_WIDTH +: VEBPF_REG_DATA_WIDTH];


        wire [VEBPF_REG_DATA_WIDTH - 1:0] VeBPF_r4;
        // assign VeBPF_r4 = VeBPF_r4_combined_global[n*VEBPF_REG_DATA_WIDTH +: VEBPF_REG_DATA_WIDTH];

        wire [VEBPF_REG_DATA_WIDTH - 1:0] VeBPF_r5;
        // assign VeBPF_r5 = VeBPF_r5_combined_global[n*VEBPF_REG_DATA_WIDTH +: VEBPF_REG_DATA_WIDTH];

        // VeBPF other r6-r10 registers states //outputs // 64 bit
        wire [VEBPF_REG_DATA_WIDTH - 1:0] VeBPF_r6;
        wire [VEBPF_REG_DATA_WIDTH - 1:0] VeBPF_r7;
        wire [VEBPF_REG_DATA_WIDTH - 1:0] VeBPF_r8;
        wire [VEBPF_REG_DATA_WIDTH - 1:0] VeBPF_r9;
        wire [VEBPF_REG_DATA_WIDTH - 1:0] VeBPF_r10;

        // total ticks taken to process the program // output // 64 bit
        wire [VEBPF_TICKS_DATA_WIDTH - 1:0] VeBPF_ticks;
        assign VeBPF_ticks_combined_global[n*VEBPF_TICKS_DATA_WIDTH +: VEBPF_TICKS_DATA_WIDTH] = VeBPF_ticks;
            // might need to track VeBPF ticks in result tracker FSM so that 
            // the FSM doesn't wait too long for VeBPF processing of an rxpkthdr.
            // I can reduce the VEBPF_TICKS_DATA_WIDTH here atleast if I only need to
            // look at a small value of VeBPF ticks because 64 bit width for VeBPF ticks
            // can be a lot when there are multiple VeBPFs on a small FPGA
            // TODO: the above comment

        // VeBPF data mem stuff

        wire VeBPF_data_mem_ack_output_port;  // output  // 1 bit
        assign VeBPF_data_mem_ack_output_port_combined_global[n] = VeBPF_data_mem_ack_output_port;

        // 64 bit // input
        // already assigned before generate block
        // assign VeBPF_data_mem_64bit_wdata_single_combined_global = VeBPF_data_mem_64bit_wdata_reg;
        wire [VEBPF_MEM_DATA_WIDTH - 1:0] VeBPF_inst_data_mem_64bit_wdata_in;  // 64bit input
        assign VeBPF_inst_data_mem_64bit_wdata_in = VeBPF_data_mem_64bit_wdata_single_combined_global;
        // assign VeBPF_data_mem_64bit_wdata = VeBPF_data_mem_64bit_wdata_reg;
            // since same rxpkt hdr data needs to go to each VeBPF, hence I dont need a combined global wire to carry copies of the same data
            // I can just give each VeBPF data line "VeBPF_data_mem_64bit_wdata" the data line from data loading FSM "VeBPF_data_mem_64bit_wdata_reg".
            // direct assignment from VeBPF data loading FSM

        wire [VEBPF_MEM_DATA_WW - 1:0] VeBPF_inst_data_mem_ww_in; // 4bit input (number of bytes being written)
        assign VeBPF_inst_data_mem_ww_in = VeBPF_data_mem_ww_single_combined_global;
        // assign VeBPF_data_mem_ww = VeBPF_data_mem_ww_reg;
            // same as the case with "VeBPF_data_mem_64bit_wdata"
            // direct assignment from VeBPF data loading FSM

        wire VeBPF_inst_data_mem_we_in;  // input (write enable)
        assign VeBPF_inst_data_mem_we_in = VeBPF_data_mem_we_single_combined_global;
        // assign VeBPF_data_mem_we = VeBPF_data_mem_we_reg;
            // same as the case with "VeBPF_data_mem_64bit_wdata"
            // direct assignment from VeBPF data loading FSM

        wire [VEBPF_MEM_DATA_AW - 1:0] VeBPF_inst_data_mem_adr_in;  // input
        assign VeBPF_inst_data_mem_adr_in = VeBPF_data_mem_adr_single_combined_global;
        // assign VeBPF_data_mem_adr = VeBPF_data_mem_adr_reg;
            // same as the case with "VeBPF_data_mem_64bit_wdata"
            // direct assignment from VeBPF data loading FSM

        wire VeBPF_inst_data_mem_stb_in; // input
        assign VeBPF_inst_data_mem_stb_in = VeBPF_data_mem_stb_single_combined_global;
        // assign VeBPF_data_mem_stb = VeBPF_data_mem_stb_reg;
            // same as the case with "VeBPF_data_mem_64bit_wdata"
            // direct assignment from VeBPF data loading FSM

        wire VeBPF_halt, VeBPF_error;  // output
        assign VeBPF_halt_combined_global[n] = VeBPF_halt;
        assign VeBPF_error_combined_global[n] = VeBPF_error;

        // pgm mem signals
        
        wire [VEBPF_PROG_ADDRESS_WIDTH-1:0] VeBPF_inst_prog_addr_in;
        assign VeBPF_inst_prog_addr_in = VeBPF_prog_addr_in_single_combined_global;
        
        wire [VEBPF_PROG_DATA_WIDTH-1:0] VeBPF_inst_prog_data_in;
        assign VeBPF_inst_prog_data_in = VeBPF_prog_data_in_single_combined_global;

        wire VeBPF_inst_prog_write_enable_in;
        assign VeBPF_inst_prog_write_enable_in = VeBPF_prog_write_enable_in_single_combined_global;

        wire VeBPF_inst_prog_reset_in;
        assign VeBPF_inst_prog_reset_in = VeBPF_prog_reset_in_single_combined_global;

        // reprog pgm mem signals
        wire VeBPF_inst_run_next_selected_rule_en_in;
        assign VeBPF_inst_run_next_selected_rule_en_in = VeBPF_run_next_selected_rule_en_combined_global[n]; 

        wire [VEBPF_PROG_ADDRESS_WIDTH-1:0] VeBPF_inst_ip_next_rule_in;
        assign VeBPF_inst_ip_next_rule_in = VeBPF_ip_next_rule_in_single_combined_global;


        cpu #(
            .SIMULATION(SIMULATION),
            .VEBPF_PROG_ADDRESS_WIDTH(VEBPF_PROG_ADDRESS_WIDTH),
            .VEBPF_PROG_ADDRESS_WIDTH_REDUCED(VEBPF_PROG_ADDRESS_WIDTH_REDUCED) // This control the real depth of pgm mem
        )
        VeBPF(
            .clk(clk),         // input
            .reset_n(VeBPF_reset_n),     // input
            .halt(VeBPF_halt),
            .error(VeBPF_error),
            .csr_ctl(VeBPF_csr_ctl),     // input (8 bit). csr_ctl[0] for reset ==> assign reset_n_int = (reset_n | csr_ctl[0]);
            .csr_status(VeBPF_csr_status),  // output (8 bit). csr_status[0] = reset_n_int; csr_status[1] = halt; csr_status[2] = error; csr_status[7] = debug;
            .r0(VeBPF_r0),          // output (64 bit). All registers are 64bit (64bit cpu)
            .r1(VeBPF_r1),          // input (64 bit). 
            .r2(VeBPF_r2),          // input (64 bit).
            .r3(VeBPF_r3),          // input (64 bit).
            .r4(VeBPF_r4),          // input (64 bit).
            .r5(VeBPF_r5),          // input (64 bit).
            .r6(VeBPF_r6),          // output (64 bit).
            .r7(VeBPF_r7),          // output (64 bit).
            .r8(VeBPF_r8),          // output (64 bit).
            .r9(VeBPF_r9),          // output (64 bit).
            .r10(VeBPF_r10),         // output (64 bit).
            .ticks(VeBPF_ticks),       // output (64 bit).
            
            // VeBPF data mem ports
                // Comments for rst of data mem for VeBPF data memory
                    // .rst((!reset_n_int) ^ (csr_ctl[1])),
                    // VeBPF_csr_ctl_next[1] = 1 to get access to VeBPF data memory and overwite its reset and 0 to give access back to VeBPF
                    // while VeBPF_reset_n_next = 0; // reset is active (can load data memory in VeBPF now)
                        // rst(1 ^ 1) = rst(0)  // rst is deactivated
                    // when running VeBPF cpu VeBPF_reset_n_next = 1 and VeBPF_csr_ctl_next[1] = 0 which means:
                        // rst(0 ^ 0) = rst(0)  // rst is deactivated
            .data_mem_ack_output_port(VeBPF_data_mem_ack_output_port),  // output 
            .data_mem_write_64bit_input_port(VeBPF_inst_data_mem_64bit_wdata_in),  // input (64 bit).
            .data_mem_dataBytesWrittenWidth_ww_input_port(VeBPF_inst_data_mem_ww_in),  // input (4 bit). (number of bytes being written)
            .data_mem_we_input_port(VeBPF_inst_data_mem_we_in),  // input (write enable)
            .data_mem_adr_input_port(VeBPF_inst_data_mem_adr_in), // input (11 bit)
            .data_mem_stb_input_port(VeBPF_inst_data_mem_stb_in),  // input
            
            // VeBPF prog mem ports 
            .VeBPF_prog_addr_in(VeBPF_inst_prog_addr_in),  // adding _inst (instance) in the signal name to differentiate it from the parent module ios
            .VeBPF_prog_data_in(VeBPF_inst_prog_data_in),
            .VeBPF_prog_write_enable_in(VeBPF_inst_prog_write_enable_in),
            .VeBPF_prog_reset_in(VeBPF_inst_prog_reset_in),                        // separate reset for the prog mem of VeBPF
            // .VeBPF_prog_busy_in(VeBPF_prog_busy_in),                      // the progloader is busy writing to VeBPF prog mem
            // .VeBPF_prog_done_in(VeBPF_prog_done_in)                      // VeBPF prog has been completed 
            
            // Running next selected RULE
            .run_next_selected_rule_en(VeBPF_inst_run_next_selected_rule_en_in),
                // if you wnat to change ip_next while VeBPF cpu is in reset state,
                // you need to keep "run_next_selected_rule_en" HIGH throughout the 
                // duration that reset is ACTIVE 
            .ip_next_rule(VeBPF_inst_ip_next_rule_in)
        );
    
    end 

endgenerate

// ********************************************************************************************************************************************************************
// ***************************************** VeBPFs Instantiations and Connections -> END *************************************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************


// Throughput measurement for VeBPF firewall filtering

wire [31:0] perf_counter;
wire perf_measure_done;

perf_counter #(

    .SIMULATION(SIMULATION)
)
perf_counter_inst1 (
    // will read this pulse (rxpkt_filtering_done) 4 times, this will be HIGH for 1 clk only, will send 4 rxpkts of lengths of 1024 bytes 
    // after 1 rxpkt is filtered, rxpkt_filtering_done gets HIGH which will start our perf_counter and it will continue counting till 3 more
    // pulses of rxpkt_filtering_done are received and throughput calculation will be DONE and its flag performance_calculation_done flag
    // will become HIGH so that our ILA can show us the throughput at thoughput output in form of the perf_counter value so we dont have to make
    // extra hw circuits for multiplications and divisons for throughput calculation, we will do that on calculator.
    //  the total throughput for VeBPF filtering will be:  
        // "THROUGHPUT = of traffic %f Mbps = 3 (total rxpkts) x (1024 x 8 bits) x 83/100 (for sim) MHz sysclk / perf_counter" 
        // "THROUGHPUT = of traffic %f Mbps = 3 (total rxpkts) x (1024 x 8 bits) / (perf_counter x (1/(83 or 100 MHz)) IS TOTAL TIME TAKEN TO PROCESS THREE rxpkts of lengths mentioned in numerator" 

        // now changing the sys clk to 100 MHz from 125 MHz AND reducing inter pkt distance to 200 ns, we have VeBPF filtering Throughput: 98.000000 Mbps 
        // and manual calculation of rxpkts through rx_dvs is 98.08 MHz

        // now changing clk to 83.3 MHz

    .clk(clk),
    .rst(rst),
    .rxpkt_filtering_done_in(rxpkt_filtering_done),
    .perf_measure_done_out(perf_measure_done),
    .perf_counter_out(perf_counter)




);

// Throughput measurement for riscv firewall filtering

wire [31:0] perf_counter2;
wire perf_measure2_done;

// we will filter 4 rxpkts using riscv
perf_counter #(

    // pulling this down for riscv throughput measurement
    .VEBPF_PERF_MEASURE(0),
    .SIMULATION(SIMULATION)

)
perf_counter_inst2 (

    .clk(clk),
    .rst(rst),
    .rxpkt_filtering_done_in(desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg),
    .perf_measure_done_out(perf_measure2_done),
    .perf_counter_out(perf_counter2)


);

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ***************************************** ILA instantiations *******************************************************************************************************
// ********************************************************************************************************************************************************************
// ********************************************************************************************************************************************************************

generate

    if(SIMULATION == 0) begin


    // read_flag  // 1 bit
    // net_csr7_tx1 // 1 bit 
    // csr7_tx1  // 32 bit
    // net_csr8_tx1  // 1 bit
    // csr8_tx1  // 32 bits

    // wr_fifo_ptr_tx_pkt_next  // 3 bits
    // wr_fifo_ptr_tx_pkt_reg   // 3 bits
    // tx_dma_state_reg  // 4 bits
    // tx_dma_state_next  // 4 bits
    // desc_table_tx_pkt_avail_rd_ptr_reg  // 1 bit
    // desc_table_tx_pkt_empty  // 1 bit 
    // tx_pkt_csr_state_reg  //4 bits
    // tx_pkt_csr_state_next  // 4 bits 
    // wr_fifo_ptr_tx_pkt_inc_reg  // 1 bit
    // net_csr5_tx1  // 1 bit
    // write_flag  // 1 bit
    // axi_wstrb_buff  // 4 bit
    // axi_wdata_buff  // 32 bit

    // tx_pkt_transmit_state_reg  // 4 bits
    // tx_pkt_transmit_state_next // 4 bits


    // rd_fifo_ptr_tx_pkt_reg // 3 bits
    // rd_fifo_ptr_tx_pkt_next  // 3 bits
    // desc_table_tx_pkt_full   // 1 bit
    // desc_table_tx_pkt_avail_en  // 1 bit
    // desc_table_tx_pkt_avail_rd_ptr_reg  // 1 bit
    // desc_table_tx_pkt_len_rd_ptr_reg  // 16 bit
    // desc_table_tx_pkt_len_words_rd_ptr_reg  // 16 bit
    // desc_table_tx_pkt_start_mem_addr_rd_ptr_reg  // 32 bit

    // eth_mem_write_grant  // 1 bit
    // eth_mem_write_req_reg  // 1 bit
    // eth_mem_write_req  // 1 bit
    // eth_mem_read_tx_pkt_req_next  // 1 bit
    // desc_table_tx_pkt_transfer_done_en  // 1 bit
    // desc_table_tx_pkt_transfer_done_next  // 1 bit
    // tx_pkt_wr_ptr_desc_table_tx_pkt_avail_en_reg  // 1 bit
    // csr12_tx1[0]  // 1 bit


    // 1) the problem right now is that after the tx pipeline is taking control of mem bus and handing the control back to
    // riscv, the riscv isn't continuing running the code back where it left off from... I have to check the mem bus grant module..
    // most prob I'll have to instantiate an ILA inside the mem grant module and check riscv signals and network subsystem handoff

    // 2) the second problem is that the "desc_table_tx_pkt_avail_rd_ptr_reg" is already 1 before 1 was written to it at wrptr = 0.
    

    // Using ILA to debug  txpipeline 
    // ila_9 ILA_DEBUG_v2 (
        
    //    .clk(clk),  // 1 bit
    //    .probe0({desc_table_tx_pkt_empty, desc_table_tx_pkt_avail_rd_ptr_reg, tx_dma_state_reg, wr_fifo_ptr_tx_pkt_reg, wr_fifo_ptr_tx_pkt_next}),  // 12 bits // used = 1 + 1 + 4 + 3 + 3 = 12 bits
    //    .probe1({tx_dma_state_next, tx_pkt_csr_state_reg, tx_pkt_csr_state_next}),    // 12 bits // used = 4 + 4 + 4 = 12 bits 
    //    .probe2({wr_fifo_ptr_tx_pkt_inc_reg, net_csr5_tx1, write_flag, axi_wstrb_buff}),   // 12 bit // used = 1 + 1 + 1 + 4
    //    .probe3({tx_pkt_transmit_state_reg, tx_pkt_transmit_state_next}),  // 12 bit // used = 4 + 4 = 8
    //    .probe4({rd_fifo_ptr_tx_pkt_reg, rd_fifo_ptr_tx_pkt_next, desc_table_tx_pkt_full, desc_table_tx_pkt_avail_en, desc_table_tx_pkt_avail_rd_ptr_reg}),  // 12 bit // used = 3+3+1+1+1 = 9
    //    .probe5(read_flag),    // 1 bit    
    //    .probe6(net_csr7_tx1),    // 1 bit

    //    .probe7({desc_table_tx_pkt_len_rd_ptr_reg, desc_table_tx_pkt_len_words_rd_ptr_reg}),  // 64 bits // used = 16+16 = 32

    //    .probe8(VeBPF_rules_scheduler_state_reg),  // 4 bit    
    //    .probe9(VeBPF_result_tracker_state_reg),  // 4 bit 
    //    .probe10(state_reg),  // 3 bit
    //    .probe11({perf_measure_done, perf_measure2_done}),  // 2 bit atm Throughput FLAGS
    //    .probe12(net_csr8_tx1),  // 2 bit atm
    //    .probe13({eth_mem_write_grant, eth_mem_write_req_reg, eth_mem_write_req, eth_mem_read_tx_pkt_req_next,
    //     desc_table_tx_pkt_transfer_done_en, desc_table_tx_pkt_transfer_done_next, tx_pkt_wr_ptr_desc_table_tx_pkt_avail_en_reg, csr12_tx1[0]}),  // 8 bit // used = 1*8 = 8 bits
    //    .probe14(axi_wdata_buff),  // 32 bit  used = 32
    //    .probe15(VeBPF_data_w_state_reg),  // 4 bits
    //    .probe16(VeBPF_result_evaluator_result_matched_flag_next),  // 1 bit
    //    .probe17({desc_table_tx_pkt_start_mem_addr_rd_ptr_reg, axi_rdata}), // 64 bits  // used = 64
    //    .probe18({csr8_tx1,csr7_tx1}), // 64 bits
    //    .probe19(VeBPF_result_tracker_result_array_wr_flag_reg),  // 1 bit 
    //    .probe20({testing_flag_1_reg, testing_flag_2_reg, rx_pkt_len_words_counter_reg}),  // 1 + 1 + 10 bits = 12 bits
    //    .probe21(VeBPF_rules_selector_state_reg),  // 8 bit
    //    .probe22(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next),  // 10 bit
    //    .probe23(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next),  // 1 bit
    //    .probe24(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg),  // 10 bit
    //    .probe25(axi_rvalid),  // 1 bit
    //    .probe26(desc_table_tx_pkt_len_rd_ptr_reg), // 16 bit
    //    .probe27(VeBPF_result_evaluator_stop_VeBPF_processing_flag_next),  // 1 bit
    //    .probe28({perf_counter, perf_counter2}),  // 64 bits  Throughput counters
    //    .probe29({tx_pkt_transmit_tx_pkt_len_rd_ptr_next, desc_table_tx_pkt_avail_en,
    //                 tx_pkt_bytes_output_counter_next, tx_pkt_transmit_tx_pkt_len_rd_ptr_reg,
    //                 tx_pkt_transmit_tx_byte_out_last_next, tx_pkt_transmit_tx_mem_select_next}),  // 16 + 1 + 11 + 16 + 2 = 46 bits
    //    .probe30({m_axis_tdata, m_axis_tvalid, m_axis_tlast, word_to_byte_ptr_next, tx_pkt_dma_tx_pkt_avail_in_tx_mem1_flag_reg, tx_pkt_dma_tx_pkt_avail_in_tx_mem2_flag_reg,
    //                 tx_pkt_transmit_tx_mem_rd_ptr_en, tx_pkt_transmit_tx_mem_select_next, tx_pkt_transmission_complete_flag})
    //                     // 41 bits .. total 64 bits
                
    // );

    // desc_table_tx_pkt_avail_en
    // desc_table_tx_pkt_len_rd_ptr_reg  // 16 bits DONE
    // tx_pkt_transmit_tx_pkt_len_rd_ptr_next   // 16 bits
    // tx_pkt_bytes_output_counter_next  // 11 bits
    // tx_pkt_transmit_tx_pkt_len_rd_ptr_reg // 16 bits
    // tx_pkt_transmit_tx_byte_out_last_next
    // tx_pkt_transmit_tx_mem_select_next
        // total bits = 62 bits

    // assign csr1 = {   // 16'bits R
    //                   desc_table_rx_pkt_len_rd_ptr_reg,
    //                   // 5'bits padding
    //                   {5{1'b0}},
    //                   // 1'bit dropRxPkt bit
    //                   desc_table_VeBPF_rx_pkt_hdr_processing_done_result_dropRxPkt_bit_rd_ptr_reg,
    //                   //5 bits VeBPF csr registers
    //                   desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination_rd_ptr_reg[2:0],  // 3 bit  // 3 lower bits of the whole reg atm
    //                   desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit_rd_ptr_reg,  // 1 bit
    //                   desc_table_VeBPF_rx_pkt_hdr_processed_done_valid_rd_ptr_reg,  // 1 bit
    //                   // 2'bits W // need to be written to/updated by the MMIO 
    //                   rd_ptr_rx_pkt_fifo_inc_reg, desc_table_rx_pkt_avail_overwrite_rd_ptr_clear_reg,
    //                   // 3'bits R // need to be read by MMIO 
    //                   desc_table_rx_pkt_avail_rd_ptr_reg, desc_table_rx_pkt_full, desc_table_rx_pkt_empty};

    // Imp debug notes on 28 Nov 2023:
        // 003C 00A6 cars1 value debug
            // this value of csr1 and VeBPF data write fsm state == 6 showed me the bug of VeBPF data write fsm overwiting
            // the result of desc table at idx 0 cx wr_desc table idx was b'100 = 4 and rd_fifo_ptr was at b'00
            // but the VeBPF data write fsm state was not checking BEFORE VeBPF data write fsm state == 6, i.e., VeBPF result writing to desc table state,
            // if the desc table was FULL, i.e., wr_fifo_ptr[FIFO_DEPTH - 1:0] == rd_fifo_ptr[FIFO_DEPTH -1:0] when MSB are not the same (using the XOR method).
            // So now I will check before going to VeBPF data write fsm state == 6 that if the desc table is FULL ANDDDDDD && wr_fifo_ptr == wr_ptr_desc_table.
            // The reason for doing this "&&" instead of just checking if the desc table is FULL is that we just have one more rx pkt in the rxpkthdr BRAM available
            // for processing by the VeBPF CPUs, so lets say wr_fifo_ptr == 4 and desc table is FULL now while wr_ptr_desc_table is at == 01, then if 
            // we freeze the VeBPF data write fsm just based on desc table full flag, we will be wasting the oppertunity to process further available rxpkthdrs
            // till wr_ptr_desc_table == 4 (TILL this.. when this happens DO NOT save the RESULTS ...wait for desc table full flag to get LOW so that we don't overwrite
            // results of idx b'00 with results of b'100 even before rdptr reads the idx 00).
                // and we can't just stop at VeBPF data write fsm state == 6 and wait if desc table is full and when that flag deactivates, then we save the processed VeBPF results,
                // the problem with this is that lets say wr_fifo_ptr is at b'100 and wr_ptr_desc_table is b'11 and desc table is full, so we wont be able to save the results of the
                // rxpkt that was at wr_ptr_desc_table == b'11


        // 02CE 0084 cars1 value debug


    // Using ILA to measure throughput performance
    /*ila_9 ILA_DEBUG_v2 (
        
       .clk(clk),  // 1 bit
       .probe0(VeBPF_result_tracker_current_selected_result_reg),  // 12 bits // actual width is 9 bits
       .probe1(VeBPF_result_evaluator_state_reg),    // 12 bits // actual width is 9 bits
       .probe2(desc_table_VeBPF_en_wr_next),   // 12 bit // actual width is 10 bits
       .probe3(desc_table_VeBPF_r0_next),  // 12 bit // actual width is 10 bits
       .probe4(wr_ptr_decs_table_VeBPF_result_rx_pkt_reg),  // 12 bit // actual width is 10 bits
       .probe5(VeBPF_rx_pkt_hdr_bram_fifo_FULL_next),    // 1 bit    
       .probe6(VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next),    // 1 bit

       .probe7({VeBPF_prog_addr_in, VeBPF_prog_write_enable_in, VeBPF_prog_reset_in, VeBPF_prog_busy_in, 
                    VeBPF_prog_done_in, VeBPF_next_rule_switch_flag_in, VeBPF_all_rules_done_switch_flag_in, 
                    VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_reg, VeBPF_prog_length_reg, 
                    VeBPF_rules_fifo_wr_fifo_ptr_reg, VeBPF_rules_scheduler_table_wr_en_next, VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_reg, 
                    VeBPF_rules_scheduler_table_wr_ptr_reg, VeBPF_rules_scheduler_fifo_wr_en_reg}),  // 12 + 1 + 1 + 1 + 1 +1 + 1 +  6 + 12 + 12 + 1 +  12 + 1 + 1 = 63 bits

       .probe8(VeBPF_rules_scheduler_state_reg),  // 4 bit    
       .probe9(VeBPF_result_tracker_state_reg),  // 4 bit 
       .probe10(state_reg),  // 3 bit
       .probe11({perf_measure_done, perf_measure2_done}),  // 2 bit atm Throughput FLAGS
       .probe12(VeBPF_halt_combined_global),  // 2 bit atm
       .probe13(mem_state_reg),  // 8 bit
       .probe14(csr1),  // 32 bit
       .probe15(VeBPF_data_w_state_reg),  // 4 bits
       .probe16(VeBPF_result_evaluator_result_matched_flag_next),  // 1 bit
       .probe17(VeBPF_prog_data_word_reg), // 64 bits  //(wr_fifo_ptr_rx_pkt_reg),  
       .probe18(VeBPF_prog_data_in), // 64 bits
       .probe19(VeBPF_result_tracker_result_array_wr_flag_reg),  // 1 bit 
       .probe20({testing_flag_1_reg, testing_flag_2_reg, rx_pkt_len_words_counter_reg}),  // 1 + 1 + 10 bits = 12 bits
       .probe21(VeBPF_rules_selector_state_reg),  // 8 bit
       .probe22(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next),  // 10 bit
       .probe23(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next),  // 1 bit
       .probe24(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg),  // 10 bit
       .probe25(VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag),  // 1 bit
       .probe26(VeBPF_r0_combined_global), // 16 bit
       .probe27(VeBPF_result_evaluator_stop_VeBPF_processing_flag_next),  // 1 bit
       .probe28({perf_counter, perf_counter2}),  // 64 bits  Throughput counters
       .probe29({VeBPF_result_evaluator_final_result_next, VeBPF_result_tracker_current_selected_result_id_number_reg, 
                        VeBPF_rules_scheduler_total_num_rules_uploaded_reg, 
                        VeBPF_rules_selector_total_rules_uploaded_reg, VeBPF_result_evaluator_VeBPF_halt_counter_reg}),  // 8 + 6 + 6 + 6 + 4 bits = 30 bits
       .probe30({VeBPF_rules_uploader_rules_scheduler_table_read_en, VeBPF_rules_selector_rules_scheduler_table_read_en, 
                    VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg, VeBPF_run_next_selected_rule_en_rules_selector_in_next,
                        VeBPF_ip_next_rule_rules_selector_in_next, VeBPF_rules_selector_current_rule_start_ptr_reg, VeBPF_id_selected_last_saved_reg,
                        VeBPF_ip_next_rule_in_single_combined_global, VeBPF_run_next_selected_rule_en_combined_global})
                // 1 + 1 + 6 + 2 + 12 + 13 + 6 + 12 + 2 = 54 bits
    );*/
        
        
    // // debugging Result Evaluator and Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg fsm
    // ila_9 ILA_DEBUG_v1 (
        
    //    .clk(clk),  // 1 bit
    //    .probe0(VeBPF_result_tracker_current_selected_result_reg),  // 12 bits // actual width is 9 bits
    //    .probe1(VeBPF_result_evaluator_state_reg),    // 12 bits // actual width is 9 bits
    //    .probe2(desc_table_VeBPF_en_wr_next),   // 12 bit // actual width is 10 bits
    //    .probe3(desc_table_VeBPF_r0_next),  // 12 bit // actual width is 10 bits
    //    .probe4(wr_ptr_decs_table_VeBPF_result_rx_pkt_reg),  // 12 bit // actual width is 10 bits
    //    .probe5(VeBPF_rx_pkt_hdr_bram_fifo_FULL_next),    // 1 bit    
    //    .probe6(VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next),    // 1 bit

    //    .probe7({VeBPF_prog_addr_in, VeBPF_prog_write_enable_in, VeBPF_prog_reset_in, VeBPF_prog_busy_in, 
    //                 VeBPF_prog_done_in, VeBPF_next_rule_switch_flag_in, VeBPF_all_rules_done_switch_flag_in, 
    //                 VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_reg, VeBPF_prog_length_reg, 
    //                 VeBPF_rules_fifo_wr_fifo_ptr_reg, VeBPF_rules_scheduler_table_wr_en_next, VeBPF_rules_fifo_prev_rule_start_wr_fifo_ptr_reg, 
    //                 VeBPF_rules_scheduler_table_wr_ptr_reg, VeBPF_rules_scheduler_fifo_wr_en_reg}),  // 12 + 1 + 1 + 1 + 1 +1 + 1 +  6 + 12 + 12 + 1 +  12 + 1 + 1 = 63 bits

    //    .probe8(VeBPF_rules_scheduler_state_reg),  // 4 bit    
    //    .probe9(VeBPF_result_tracker_state_reg),  // 4 bit 
    //    .probe10(state_reg),  // 3 bit
    //    .probe11(VeBPF_error_combined_global),  // 2 bit atm
    //    .probe12(VeBPF_halt_combined_global),  // 2 bit atm
    //    .probe13(mem_state_reg),  // 8 bit
    //    .probe14(csr1),  // 32 bit
    //    .probe15(VeBPF_data_w_state_reg),  // 4 bits
    //    .probe16(VeBPF_result_evaluator_result_matched_flag_next),  // 1 bit
    //    .probe17(VeBPF_prog_data_word_reg), // 64 bits  //(wr_fifo_ptr_rx_pkt_reg),  
    //    .probe18(VeBPF_prog_data_in), // 64 bits
    //    .probe19(VeBPF_result_tracker_result_array_wr_flag_reg),  // 1 bit 
    //    .probe20({testing_flag_1_reg, testing_flag_2_reg, rx_pkt_len_words_counter_reg}),  // 1 + 1 + 10 bits = 12 bits
    //    .probe21(VeBPF_rules_selector_state_reg),  // 8 bit
    //    .probe22(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next),  // 10 bit
    //    .probe23(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next),  // 1 bit
    //    .probe24(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg),  // 10 bit
    //    .probe25(VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag),  // 1 bit
    //    .probe26(VeBPF_r0_combined_global), // 16 bit
    //    .probe27(VeBPF_result_evaluator_stop_VeBPF_processing_flag_next),  // 1 bit
    //    .probe28(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg),  // 64 bits
    //    .probe29({VeBPF_result_evaluator_final_result_next, VeBPF_result_tracker_current_selected_result_id_number_reg, 
    //                     VeBPF_rules_scheduler_total_num_rules_uploaded_reg, 
    //                     VeBPF_rules_selector_total_rules_uploaded_reg, VeBPF_result_evaluator_VeBPF_halt_counter_reg}),  // 8 + 6 + 6 + 6 + 4 bits = 30 bits
    //    .probe30({VeBPF_rules_uploader_rules_scheduler_table_read_en, VeBPF_rules_selector_rules_scheduler_table_read_en, 
    //                 VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg, VeBPF_run_next_selected_rule_en_rules_selector_in_next,
    //                     VeBPF_ip_next_rule_rules_selector_in_next, VeBPF_rules_selector_current_rule_start_ptr_reg, VeBPF_id_selected_last_saved_reg,
    //                     VeBPF_ip_next_rule_in_single_combined_global, VeBPF_run_next_selected_rule_en_combined_global})
    //             // 1 + 1 + 6 + 2 + 12 + 13 + 6 + 12 + 2 = 54 bits
    // );


    // debugging Result Evaluator and Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg fsm
    // ila_8 ILA_DEBUG (
        
    //    .clk(clk),  // 1 bit
    //    .probe0(VeBPF_result_tracker_current_selected_result_reg),  // 12 bits // actual width is 9 bits
    //    .probe1(VeBPF_result_evaluator_state_reg),    // 12 bits // actual width is 9 bits
    //    .probe2(desc_table_VeBPF_en_wr_next),   // 12 bit // actual width is 10 bits
    //    .probe3(desc_table_VeBPF_r0_next),  // 12 bit // actual width is 10 bits
    //    .probe4(wr_ptr_decs_table_VeBPF_result_rx_pkt_reg),  // 12 bit // actual width is 10 bits
    //    .probe5(VeBPF_rx_pkt_hdr_bram_fifo_FULL_next),    // 1 bit    
    //    .probe6(VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next),    // 1 bit
    //    .probe7(VeBPF_data_w_state_reg),  // 4 bit
    //    .probe8(VeBPF_rules_scheduler_state_reg),  // 4 bit    
    //    .probe9(VeBPF_result_tracker_state_reg),  // 4 bit 
    //    .probe10(state_reg),  // 3 bit
    //    .probe11(VeBPF_error_combined_global),  // 2 bit atm
    //    .probe12(VeBPF_halt_combined_global),  // 2 bit atm
    //    .probe13(mem_state_reg),  // 8 bit
    //    .probe14(csr1),  // 32 bit
    //    .probe15(csr1[0]),  // 1 bit
    //    .probe16(VeBPF_result_evaluator_result_matched_flag_next),  // 1 bit
    //    .probe17(wr_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe18(rd_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe19(VeBPF_result_tracker_result_array_wr_flag_reg),  // 1 bit 
    //    .probe20(rx_pkt_len_words_counter_reg),  // 10 bit
    //    .probe21(VeBPF_rules_selector_state_reg),  // 8 bit
    //    .probe22(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next),  // 10 bit
    //    .probe23(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next),  // 1 bit
    //    .probe24(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg),  // 10 bit
    //    .probe25(VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag),  // 1 bit
    //    .probe26(VeBPF_r0_combined_global), // 16 bit
    //    .probe27(VeBPF_result_evaluator_stop_VeBPF_processing_flag_next),  // 1 bit
    //    .probe28(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg),  // 64 bits
    //    .probe29({VeBPF_result_evaluator_final_result_next, VeBPF_result_tracker_current_selected_result_id_number_reg, 
    //                     VeBPF_rules_scheduler_total_num_rules_uploaded_reg, 
    //                     VeBPF_rules_selector_total_rules_uploaded_reg, VeBPF_result_evaluator_VeBPF_halt_counter_reg}),  // 8 + 6 + 6 + 6 + 4 bits = 30 bits
    //    .probe30({VeBPF_rules_uploader_rules_scheduler_table_read_en, VeBPF_rules_selector_rules_scheduler_table_read_en, 
    //                 VeBPF_rules_selector_rules_scheduler_table_rd_ptr_reg, VeBPF_run_next_selected_rule_en_rules_selector_in_next,
    //                     VeBPF_ip_next_rule_rules_selector_in_next, VeBPF_rules_selector_current_rule_start_ptr_reg, VeBPF_id_selected_last_saved_reg,
    //                     VeBPF_ip_next_rule_in_single_combined_global, VeBPF_run_next_selected_rule_en_combined_global})
    //             // 1 + 1 + 6 + 2 + 12 + 13 + 6 + 12 + 2 = 54 bits
    // );  


    // // debugging Result Evaluator and Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg fsm
    // ila_8 ILA_DEBUG (
        
    //    .clk(clk),  // 1 bit
    //    .probe0(VeBPF_result_tracker_current_selected_result_reg),  // 12 bits // actual width is 9 bits
    //    .probe1(VeBPF_result_evaluator_state_reg),    // 12 bits // actual width is 9 bits
    //    .probe2(desc_table_VeBPF_en_wr_next),   // 12 bit // actual width is 10 bits
    //    .probe3(desc_table_VeBPF_r0_next),  // 12 bit // actual width is 10 bits
    //    .probe4(wr_ptr_decs_table_VeBPF_result_rx_pkt_reg),  // 12 bit // actual width is 10 bits
    //    .probe5(VeBPF_rx_pkt_hdr_bram_fifo_FULL_next),    // 1 bit    
    //    .probe6(VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next),    // 1 bit
    //    .probe7(VeBPF_data_w_state_reg),  // 4 bit
    //    .probe8(VeBPF_rules_scheduler_state_reg),  // 4 bit    
    //    .probe9(VeBPF_result_tracker_state_reg),  // 4 bit 
    //    .probe10(state_reg),  // 3 bit
    //    .probe11(VeBPF_error_combined_global),  // 2 bit atm
    //    .probe12(VeBPF_halt_combined_global),  // 2 bit atm
    //    .probe13(mem_state_reg),  // 8 bit
    //    .probe14(csr1),  // 32 bit
    //    .probe15(csr1[0]),  // 1 bit
    //    .probe16(VeBPF_result_evaluator_result_matched_flag_next),  // 1 bit
    //    .probe17(wr_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe18(rd_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe19(VeBPF_result_tracker_result_array_wr_flag_reg),  // 1 bit 
    //    .probe20(rx_pkt_len_words_counter_reg),  // 10 bit
    //    .probe21(VeBPF_rules_selector_state_reg),  // 8 bit
    //    .probe22(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next),  // 10 bit
    //    .probe23(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next),  // 1 bit
    //    .probe24(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg),  // 10 bit
    //    .probe25(VeBPF_rules_selector_filtering_curr_rx_pkt_completed_flag),  // 1 bit
    //    .probe26(VeBPF_r0_combined_global), // 16 bit
    //    .probe27(VeBPF_result_evaluator_stop_VeBPF_processing_flag_next),  // 1 bit
    //    .probe28(Reduction_array_for_Global_VeBPF_Result_Array_rules_done_results_valid_one_hot_reg),  // 64 bits
    //    .probe29({VeBPF_result_evaluator_final_result_next, VeBPF_result_tracker_current_selected_result_id_number_reg, 
    //                     VeBPF_rules_scheduler_total_num_rules_uploaded_reg, 
    //                     VeBPF_rules_selector_total_rules_uploaded_reg, VeBPF_result_evaluator_VeBPF_halt_counter_reg})  // 8 + 6 + 6 + 6 + 4 bits = 30 bits
    // );


    // // debugging VeBOF data write fsm
    // ila_8 ILA_DEBUG (
        
    //    .clk(clk),  // 1 bit
    //    .probe0(VeBPF_result_tracker_current_selected_result_reg),  // 12 bits // actual width is 9 bits
    //    .probe1(VeBPF_result_evaluator_state_reg),    // 12 bits // actual width is 9 bits
    //    .probe2(desc_table_VeBPF_en_wr_next),   // 12 bit // actual width is 10 bits
    //    .probe3(desc_table_VeBPF_r0_next),  // 12 bit // actual width is 10 bits
    //    .probe4(wr_ptr_decs_table_VeBPF_result_rx_pkt_reg),  // 12 bit // actual width is 10 bits
    //    .probe5(VeBPF_rx_pkt_hdr_bram_fifo_FULL_next),    // 1 bit    
    //    .probe6(VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next),    // 1 bit
    //    .probe7(VeBPF_data_w_state_reg),  // 4 bit
    //    .probe8(VeBPF_rules_scheduler_state_reg),  // 4 bit    
    //    .probe9(VeBPF_result_tracker_state_reg),  // 4 bit 
    //    .probe10(state_reg),  // 3 bit
    //    .probe11(VeBPF_error_combined_global),  // 2 bit atm
    //    .probe12(VeBPF_halt_combined_global),  // 2 bit atm
    //    .probe13(mem_state_reg),  // 8 bit
    //    .probe14(csr1),  // 32 bit
    //    .probe15(csr1[0]),  // 1 bit
    //    .probe16(csr1[1]),  // 1 bit
    //    .probe17(wr_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe18(rd_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe19(VeBPF_result_tracker_result_array_wr_flag_reg),  // 1 bit 
    //    .probe20(rx_pkt_len_words_counter_reg),  // 10 bit
    //    .probe21(VeBPF_rules_selector_state_reg),  // 8 bit
    //    .probe22(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next),  // 10 bit
    //    .probe23(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next),  // 1 bit
    //    .probe24(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg),  // 10 bit
    //    .probe25(desc_table_VeBPF_valid_next),  // 1 bit
    //    .probe26(VeBPF_r0_combined_global), // 16 bit
    //    .probe27(VeBPF_result_evaluator_stop_VeBPF_processing_flag_next)  // 1 bit

    // ); 
    
    // // debugging VeBOF data write fsm
    // ila_7 ILA_DEBUG (
        
    //    .clk(clk),  // 1 bit
    //    .probe0(VeBPF_rx_pkt_hdr_bram_wr_ptr_reg),  // 12 bits // actual width is 9 bits
    //    .probe1(VeBPF_rx_pkt_hdr_bram_rd_ptr_reg),    // 12 bits // actual width is 9 bits
    //    .probe2(desc_table_VeBPF_en_wr_next),   // 12 bit // actual width is 10 bits
    //    .probe3(desc_table_VeBPF_r0_next),  // 12 bit // actual width is 10 bits
    //    .probe4(wr_ptr_decs_table_VeBPF_result_rx_pkt_reg),  // 12 bit // actual width is 10 bits
    //    .probe5(VeBPF_rx_pkt_hdr_bram_fifo_FULL_next),    // 1 bit    
    //    .probe6(VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next),    // 1 bit
    //    .probe7(VeBPF_data_w_state_reg),  // 4 bit
    //    .probe8(VeBPF_rules_selector_state_reg),  // 4 bit    
    //    .probe9(VeBPF_result_tracker_state_reg),  // 4 bit 
    //    .probe10(state_reg),  // 3 bit
    //    .probe11(VeBPF_error_combined_global),  // 2 bit atm
    //    .probe12(VeBPF_halt_combined_global),  // 2 bit atm
    //    .probe13(mem_state_reg),  // 8 bit
    //    .probe14(csr1),  // 32 bit
    //    .probe15(csr1[0]),  // 1 bit
    //    .probe16(csr1[1]),  // 1 bit
    //    .probe17(wr_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe18(rd_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe19(desc_table_rx_pkt_avail_overwrite_rd_ptr_en_reg),  // 1 bit 
    //    .probe20(rx_pkt_len_words_counter_reg),  // 10 bit
    //    .probe21(max_rx_pkt_hdr_word_size_reg),  // 8 bit
    //    .probe22(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next),  // 10 bit
    //    .probe23(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next),  // 1 bit
    //    .probe24(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg),  // 10 bit
    //    .probe25(desc_table_VeBPF_valid_next),  // 1 bit
    //    .probe26(total_mem_words_used_rx_pkts_reg)  // 32 bit

    // );


    // // // degubbing VeBPF_rx_pkt_hdr_bram_fifo_FULL_next and state_reg FSM
    // ila_7 ILA_DEBUG (
        
    //    .clk(clk),  // 1 bit
    //    .probe0(VeBPF_rx_pkt_hdr_bram_wr_ptr_reg),  // 12 bits // actual width is 9 bits
    //    .probe1(VeBPF_rx_pkt_hdr_bram_rd_ptr_reg),    // 12 bits // actual width is 9 bits
    //    .probe2(VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW),   // 12 bit // actual width is 10 bits
    //    .probe3(VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_HIGH),  // 12 bit // actual width is 10 bits
    //    .probe4(VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_COMB),  // 12 bit // actual width is 10 bits
    //    .probe5(VeBPF_rx_pkt_hdr_bram_fifo_FULL_next),    // 1 bit    
    //    .probe6(VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next),    // 1 bit
    //    .probe7(VeBPF_data_w_state_reg),  // 4 bit
    //    .probe8(VeBPF_rules_selector_state_reg),  // 4 bit    
    //    .probe9(VeBPF_result_tracker_state_reg),  // 4 bit 
    //    .probe10(state_reg),  // 3 bit
    //    .probe11(VeBPF_halt_combined_global),  // 2 bit atm
    //    .probe12(VeBPF_reset_n_combined_global),  // 2 bit atm
    //    .probe13(mem_state_reg),  // 8 bit
    //    .probe14(csr1),  // 32 bit
    //    .probe15(csr1[0]),  // 1 bit
    //    .probe16(csr1[1]),  // 1 bit
    //    .probe17(wr_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe18(rd_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe19(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_reg),  // 1 bit 
    //    .probe20(rx_pkt_len_words_counter_reg),  // 10 bit
    //    .probe21(max_rx_pkt_hdr_word_size_reg),  // 8 bit
    //    .probe22(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_next),  // 10 bit
    //    .probe23(VeBPF_rx_pkt_hdr_bram_wr_ptr_rollover_flag_next),  // 1 bit
    //    .probe24(VeBPF_rxpkt_hdr_bram_fifo_wrptr_plus_rxpkt_len_words_counter_reg),  // 10 bit
    //    .probe25(increment_rx_pkt_word_addr_reg),  // 1 bit
    //    .probe26(total_mem_words_used_rx_pkts_reg)  // 32 bit

    // );

    // // degubbing VeBPF_rx_pkt_hdr_bram_fifo_FULL_next
    // ila_6 ILA_DEBUG (
        
    //    .clk(clk),  // 1 bit
    //    .probe0(VeBPF_rx_pkt_hdr_bram_wr_ptr_reg),  // 12 bits // actual width is 9 bits
    //    .probe1(VeBPF_rx_pkt_hdr_bram_rd_ptr_reg),    // 12 bits // actual width is 9 bits
    //    .probe2(VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_LOW),   // 12 bit // actual width is 10 bits
    //    .probe3(VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_HIGH),  // 12 bit // actual width is 10 bits
    //    .probe4(VeBPF_rx_pkt_bram_fifo_wr_ptr_DELTA_COMB),  // 12 bit // actual width is 10 bits
    //    .probe5(VeBPF_rx_pkt_hdr_bram_fifo_FULL_next),    // 1 bit    
    //    .probe6(VeBPF_rx_pkt_hdr_bram_fifo_EMPTY_next),    // 1 bit
    //    .probe7(VeBPF_data_w_state_reg),  // 4 bit
    //    .probe8(VeBPF_rules_selector_state_reg),  // 4 bit    
    //    .probe9(VeBPF_result_tracker_state_reg),  // 4 bit 
    //    .probe10(state_reg),  // 3 bit
    //    .probe11(VeBPF_halt_combined_global),  // 2 bit atm
    //    .probe12(VeBPF_reset_n_combined_global),  // 2 bit atm
    //    .probe13(mem_state_reg),  // 8 bit
    //    .probe14(csr1),  // 32 bit
    //    .probe15(csr1[0]),  // 1 bit
    //    .probe16(csr1[1]),  // 1 bit
    //    .probe17(wr_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe18(rd_fifo_ptr_rx_pkt_reg)  // 3 bit atm

    // );


    // ila_5 ILA_DEBUG (
        
    //    .clk(clk),  // 1 bit
    //    .probe0(mem_state_reg),  // 8 bit
    //    .probe1(wr_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe2(rd_fifo_ptr_rx_pkt_reg),  // 3 bit atm

    //    // mem_state_reg FSM signals below

    //    .probe3(rx_pkt_mem_base_addr_avail_reg),  // 1 bit
    //    .probe4(rx_pkt_alloc_mem_size_avail_reg),  // 1 bit
    //    .probe5(desc_table_rx_pkt_full),  // 1 bit
    //    .probe6(rx_pkt_avail_bram_reg),  // 1 bit
    //    .probe7(rx_pkt_avail_bram_reg),  // 1 bit
    //    .probe8(total_mem_words_used_rx_pkts_reg),  // 32 bit
    //    .probe9(rx_pkt_alloc_mem_words_size),  // 32 bit
    //    .probe10(last_mem_wr_addr_reg),  // 32 bit
    //    .probe11(rx_pkt_mem_base_addr_reg),  // 32 bit
    //    .probe12(rx_pkt_alloc_mem_size_reg),  // 32 bit
    //    .probe13(rx_pkt_alloc_mem_size_reg)  // 32 bit

    // );

    // ila_4 ILA_DEBUG (
        
    //    .clk(clk),  // 1 bit
    //    .probe0(VeBPF_prog_addr_in),  // 12 bits
    //    .probe1(VeBPF_prog_data_in),    // 64 bits
    //    .probe2(VeBPF_prog_write_enable_in),   // 1 bit
    //    .probe3(VeBPF_prog_reset_in),      // 1 bit
    //    .probe4(VeBPF_prog_busy_in),   // 1 bit
    //    .probe5(VeBPF_prog_done_in),    // 1 bit    
    //    .probe6(VeBPF_next_rule_switch_flag_in),    // 1 bit
    //    .probe7(VeBPF_all_rules_done_switch_flag_in), // 1 bit
    //    .probe8(VeBPF_rules_scheduler_state_reg),   // 4 bit
    //    .probe9(VeBPF_data_w_state_reg),  // 4 bit
    //    .probe10(VeBPF_rules_selector_state_reg),  // 4 bit    
    //    .probe11(VeBPF_result_tracker_state_reg),  // 4 bit 
    //    .probe12(state_reg),  // 3 bit
    //    .probe13(VeBPF_halt_combined_global),  // 2 bit atm
    //    .probe14(VeBPF_reset_n_combined_global),  // 2 bit atm
    //    .probe15(mem_state_reg),  // 8 bit
    //    .probe16(csr1),  // 32 bit
    //    .probe17(csr1[0]),  // 1 bit
    //    .probe18(csr1[1]),  // 1 bit
    //    .probe19(wr_fifo_ptr_rx_pkt_reg),  // 3 bit atm
    //    .probe20(rd_fifo_ptr_rx_pkt_reg)  // 3 bit atm

    // );



    // ila_3 ILA_DEBUG (
        
    //    .clk(clk),  // 1 bit
    //    .probe0(VeBPF_prog_addr_in),  // 12 bits
    //    .probe1(VeBPF_prog_data_in),    // 64 bits
    //    .probe2(VeBPF_prog_write_enable_in),   // 1 bit
    //    .probe3(VeBPF_prog_reset_in),      // 1 bit
    //    .probe4(VeBPF_prog_busy_in),   // 1 bit
    //    .probe5(VeBPF_prog_done_in),    // 1 bit    
    //    .probe6(VeBPF_next_rule_switch_flag_in),    // 1 bit
    //    .probe7(VeBPF_all_rules_done_switch_flag_in), // 1 bit
    //    .probe8(VeBPF_rules_scheduler_state_reg),   // 4 bit
    //    .probe9(VeBPF_data_w_state_reg),  // 4 bit
    //    .probe10(VeBPF_rules_selector_state_reg),  // 4 bit    
    //    .probe11(VeBPF_result_tracker_state_reg),  // 4 bit 
    //    .probe12(state_reg),  // 3 bit
    //    .probe13(VeBPF_halt_combined_global),  // 2 bit atm
    //    .probe14(VeBPF_reset_n_combined_global),  // 2 bit atm
    //    .probe15(mem_state_reg)  // 8 bit

    // );

    // ila_2 ILA_DEBUG (
        
    //    .clk(clk),  // 1 bit
    //    .probe0(VeBPF_reset_n_reg),  // 1 bit
    //    .probe1(VeBPF_halt),    // 1 bit
    //    .probe2(VeBPF_error),   // 1 bit
    //    .probe3(VeBPF_r0),      // 64 bit
    //    .probe4(VeBPF_ticks),   // 64 bit
    //    .probe5(desc_table_VeBPF_r0_reg),    // 3 bit    
    //    .probe6(desc_table_VeBPF_error_reg),    // 1 bit
    //    .probe7(desc_table_VeBPF_valid_reg), // 1 bit
    //    .probe8(desc_table_VeBPF_en_wr_reg),   // 1 bit
    //    .probe9(VeBPF_data_w_state_reg),  // 4 bit
    //    .probe10(VeBPF_data_mem_ack_output_port),  // 1 bit output    
    //    .probe11(VeBPF_data_mem_64bit_wdata),  // 64 bit input (64 bit). 
    //    .probe12(VeBPF_data_mem_ww),  // 4 bit input (4 bit). (number of bytes being written)
    //    .probe13(VeBPF_data_mem_we),  // 1 bit input.(write enable)
    //    .probe14(VeBPF_data_mem_adr),  // 11 bit input (11 bit).
    //    .probe15(VeBPF_data_mem_stb),  // 1 bit input.
    //    .probe16(desc_table_rx_pkt_avail_rd_ptr_reg)  // 1 bit 
    //    //.probe17(dummy_wire)

    // );


 // generate
     
 //    if(SIMULATION == 0) begin
        
// ila_1 ILA_DEBUG (
    
//    .clk(clk),  // 1 bit
//    .probe0(VeBPF_reset_n_reg),  // 1 bit
//    .probe1(VeBPF_halt),    // 1 bit
//    .probe2(VeBPF_error),   // 1 bit
//    .probe3(VeBPF_r0),      // 64 bit
//    .probe4(VeBPF_ticks),   // 64 bit
//    .probe5(VeBPF_prog_addr_in),    //12 bit    
//    .probe6(VeBPF_prog_data_in),    // 64 bit
//    .probe7(VeBPF_prog_write_enable_in), // 1 bit
//    .probe8(VeBPF_prog_reset_in),   // 1 bit
//    .probe9(VeBPF_data_w_state_reg),  // 4 bit
//    .probe10(VeBPF_data_mem_ack_output_port),  // 1 bit output    
//    .probe11(VeBPF_data_mem_64bit_wdata),  // 64 bit input (64 bit). 
//    .probe12(VeBPF_data_mem_ww),  // 4 bit input (4 bit). (number of bytes being written)
//    .probe13(VeBPF_data_mem_we),  // 1 bit input.(write enable)
//    .probe14(VeBPF_data_mem_adr),  // 11 bit input (11 bit).
//    .probe15(VeBPF_data_mem_stb),  // 1 bit input.
//    .probe16(desc_table_rx_pkt_avail_rd_ptr_reg)  // 1 bit 
//    //.probe17(dummy_wire)

//    // input clk;
//    // input [0:0]probe0;
//    // input [0:0]probe1;
//    // input [0:0]probe2;
//    // input [63:0]probe3;
//    // input [63:0]probe4;
//    // input [11:0]probe5;
//    // input [63:0]probe6;
//    // input [0:0]probe7;
//    // input [0:0]probe8;
//    // input [3:0]probe9;
//    // input [0:0]probe10;
//    // input [63:0]probe11;
//    // input [3:0]probe12;
//    // input [0:0]probe13;
//    // input [10:0]probe14;
//    // input [0:0]probe15;
//    // input [0:0]probe16;
// );


    end

 // endgenerate

endgenerate


endmodule

`resetall
