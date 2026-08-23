/*

Copyright (c) 2014-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * FPGA core logic
 */
module eth_nic_1g_rgmmi #
(
    parameter TARGET = "XILINX",//"GENERIC",
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_ADDRESS_WIDTH = 32,
    parameter VEBPF_PROG_ADDRESS_WIDTH = 12,  // for VeBPF depth parameter MEMORY_DEPTH = 2**ADDRESS_SIZE;  // 2**12 = 4096
    parameter VEBPF_PROG_DATA_WIDTH = 64,
    parameter VEBPF_PROG_DATA_BYTES = 8,
    parameter SIMULATION = 0,
    parameter NUMBER_OF_VEBPF = 1,  // number of VeBPF core
    parameter MAX_NUMBER_OF_VEBPF = 16,
    parameter VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX = 64,  // default
    parameter VEBPF_PROG_ADDRESS_WIDTH_REDUCED = 9
)
(
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    input  wire       clk,
    input  wire       clk90,
    input  wire       rst,

    /*
     * GPIO
     */
    // input  wire       btnu,
    // input  wire       btnl,
    // input  wire       btnd,
    // input  wire       btnr,
    // input  wire       btnc,
    // input  wire [7:0] sw,
    // output wire [7:0] led,
    input  wire [3:0] sw,
    output wire [3:0] led,

    /*
     * Ethernet: 1000BASE-T RGMII
     */
    input  wire       phy_rx_clk,
    input  wire [3:0] phy_rxd,
    input  wire       phy_rx_ctl,
    output wire       phy_tx_clk,
    output wire [3:0] phy_txd,
    output wire       phy_tx_ctl,
    output wire       phy_reset_n,
    input  wire       phy_int_n,
    input  wire       phy_pme_n,

    /*
     *  AXI4 S ports 
    */

    input  wire [AXI_ADDRESS_WIDTH - 1:0]             s_eth_axi_araddr,
    input  wire                    s_eth_axi_arvalid,
    output wire                    s_eth_axi_arready,

    input  wire [AXI_ADDRESS_WIDTH - 1:0]             s_eth_axi_awaddr,
    input  wire                    s_eth_axi_awvalid,
    output wire                    s_eth_axi_awready,

    output wire [31:0]             s_eth_axi_rdata,
    output wire                    s_eth_axi_rvalid,
    input  wire                    s_eth_axi_rready,

    input  wire [31:0]             s_eth_axi_wdata,
    input  wire [3:0]              s_eth_axi_wstrb,  
    input  wire                    s_eth_axi_wvalid,
    output wire                    s_eth_axi_wready,

    input  wire                   s_eth_b_ready,
    output wire                   s_eth_b_valid,
    output wire [1:0]             s_eth_b_response,

    /*
     *  AXI4 M ports 
    */

    output  wire [AXI_ADDRESS_WIDTH - 1:0]             m_eth_axi_araddr,
    output  wire                    m_eth_axi_arvalid,
    input   wire                    m_eth_axi_arready,

    output  wire [AXI_ADDRESS_WIDTH - 1:0]             m_eth_axi_awaddr,
    output  wire                    m_eth_axi_awvalid,
    input   wire                    m_eth_axi_awready,

    input   wire [31:0]             m_eth_axi_rdata,
    input   wire                    m_eth_axi_rvalid,
    output  wire                    m_eth_axi_rready,

    output  wire [31:0]             m_eth_axi_wdata,
    output  wire [3:0]              m_eth_axi_wstrb,  
    output  wire                    m_eth_axi_wvalid,
    input   wire                    m_eth_axi_wready,

    output  wire                   m_eth_b_ready,
    input   wire                   m_eth_b_valid,
    input   wire [1:0]             m_eth_b_response,

    // Memory write req
    // output wire                    eth_mem_write,
    output wire                     eth_mem_write_req,
    input  wire                     eth_mem_write_grant,

    // interrupt ports
    output wire                   o_rx_int, 
    output wire                   o_tx_int,

    // VeBPF prog mem ports
    input  wire [VEBPF_PROG_ADDRESS_WIDTH-1:0]               VeBPF_prog_addr_in,
    input  wire [VEBPF_PROG_DATA_WIDTH-1:0]                  VeBPF_prog_data_in,
    input  wire                                              VeBPF_prog_write_enable_in,
    input  wire                                              VeBPF_prog_reset_in,               // separate reset for the prog mem of VeBPF
    input  wire                                              VeBPF_prog_busy_in,                // the progloader is busy writing to VeBPF prog mem
    input  wire                                              VeBPF_prog_done_in,                // VeBPF prog has been completed 
    input  wire                                              VeBPF_next_rule_switch_flag_in,                
    input  wire                                              VeBPF_all_rules_done_switch_flag_in,                 

    /*
     * UART: 115200 bps, 8N1
    //  */
    input  wire       uart_rxd,
    output wire       uart_txd
);

// AXI between MAC and Ethernet modules
wire [7:0] rx_axis_tdata;
wire rx_axis_tvalid;
wire rx_axis_tready;
wire rx_axis_tlast;
wire rx_axis_tuser;

wire [7:0] tx_axis_tdata;
wire tx_axis_tvalid;
wire tx_axis_tready;
wire tx_axis_tlast;
wire tx_axis_tuser;

// Ethernet frame between Ethernet modules and UDP stack
wire rx_eth_hdr_ready;
wire rx_eth_hdr_valid;
wire [47:0] rx_eth_dest_mac;
wire [47:0] rx_eth_src_mac;
wire [15:0] rx_eth_type;
wire [7:0] rx_eth_payload_axis_tdata;
wire rx_eth_payload_axis_tvalid;
wire rx_eth_payload_axis_tready;
wire rx_eth_payload_axis_tlast;
wire rx_eth_payload_axis_tuser;

wire tx_eth_hdr_ready;
wire tx_eth_hdr_valid;
wire [47:0] tx_eth_dest_mac;
wire [47:0] tx_eth_src_mac;
wire [15:0] tx_eth_type;
wire [7:0] tx_eth_payload_axis_tdata;
wire tx_eth_payload_axis_tvalid;
wire tx_eth_payload_axis_tready;
wire tx_eth_payload_axis_tlast;
wire tx_eth_payload_axis_tuser;

// IP frame connections
wire rx_ip_hdr_valid;
wire rx_ip_hdr_ready;
wire [47:0] rx_ip_eth_dest_mac;
wire [47:0] rx_ip_eth_src_mac;
wire [15:0] rx_ip_eth_type;
wire [3:0] rx_ip_version;
wire [3:0] rx_ip_ihl;
wire [5:0] rx_ip_dscp;
wire [1:0] rx_ip_ecn;
wire [15:0] rx_ip_length;
wire [15:0] rx_ip_identification;
wire [2:0] rx_ip_flags;
wire [12:0] rx_ip_fragment_offset;
wire [7:0] rx_ip_ttl;
wire [7:0] rx_ip_protocol;
wire [15:0] rx_ip_header_checksum;
wire [31:0] rx_ip_source_ip;
wire [31:0] rx_ip_dest_ip;
wire [7:0] rx_ip_payload_axis_tdata;
wire rx_ip_payload_axis_tvalid;
wire rx_ip_payload_axis_tready;
wire rx_ip_payload_axis_tlast;
wire rx_ip_payload_axis_tuser;

wire tx_ip_hdr_valid;
wire tx_ip_hdr_ready;
wire [5:0] tx_ip_dscp;
wire [1:0] tx_ip_ecn;
wire [15:0] tx_ip_length;
wire [7:0] tx_ip_ttl;
wire [7:0] tx_ip_protocol;
wire [31:0] tx_ip_source_ip;
wire [31:0] tx_ip_dest_ip;
wire [7:0] tx_ip_payload_axis_tdata;
wire tx_ip_payload_axis_tvalid;
wire tx_ip_payload_axis_tready;
wire tx_ip_payload_axis_tlast;
wire tx_ip_payload_axis_tuser;

// UDP frame connections
wire rx_udp_hdr_valid;
wire rx_udp_hdr_ready;
wire [47:0] rx_udp_eth_dest_mac;
wire [47:0] rx_udp_eth_src_mac;
wire [15:0] rx_udp_eth_type;
wire [3:0] rx_udp_ip_version;
wire [3:0] rx_udp_ip_ihl;
wire [5:0] rx_udp_ip_dscp;
wire [1:0] rx_udp_ip_ecn;
wire [15:0] rx_udp_ip_length;
wire [15:0] rx_udp_ip_identification;
wire [2:0] rx_udp_ip_flags;
wire [12:0] rx_udp_ip_fragment_offset;
wire [7:0] rx_udp_ip_ttl;
wire [7:0] rx_udp_ip_protocol;
wire [15:0] rx_udp_ip_header_checksum;
wire [31:0] rx_udp_ip_source_ip;
wire [31:0] rx_udp_ip_dest_ip;
wire [15:0] rx_udp_source_port;
wire [15:0] rx_udp_dest_port;
wire [15:0] rx_udp_length;
wire [15:0] rx_udp_checksum;
wire [7:0] rx_udp_payload_axis_tdata;
wire rx_udp_payload_axis_tvalid;
wire rx_udp_payload_axis_tready;
wire rx_udp_payload_axis_tlast;
wire rx_udp_payload_axis_tuser;

wire tx_udp_hdr_valid;
wire tx_udp_hdr_ready;
wire [5:0] tx_udp_ip_dscp;
wire [1:0] tx_udp_ip_ecn;
wire [7:0] tx_udp_ip_ttl;
wire [31:0] tx_udp_ip_source_ip;
wire [31:0] tx_udp_ip_dest_ip;
wire [15:0] tx_udp_source_port;
wire [15:0] tx_udp_dest_port;
wire [15:0] tx_udp_length;
wire [15:0] tx_udp_checksum;
wire [7:0] tx_udp_payload_axis_tdata;
wire tx_udp_payload_axis_tvalid;
wire tx_udp_payload_axis_tready;
wire tx_udp_payload_axis_tlast;
wire tx_udp_payload_axis_tuser;

wire [7:0] rx_fifo_udp_payload_axis_tdata;
wire rx_fifo_udp_payload_axis_tvalid;
wire rx_fifo_udp_payload_axis_tready;
wire rx_fifo_udp_payload_axis_tlast;
wire rx_fifo_udp_payload_axis_tuser;

wire [7:0] tx_fifo_udp_payload_axis_tdata;
wire tx_fifo_udp_payload_axis_tvalid;
wire tx_fifo_udp_payload_axis_tready;
wire tx_fifo_udp_payload_axis_tlast;
wire tx_fifo_udp_payload_axis_tuser;

// RX ethernet packets fifo outputs
wire [7:0] rx_output_fifo_eth_packet_axis_tdata;
wire rx_output_fifo_eth_packet_axis_tvalid;
wire rx_output_fifo_eth_packet_axis_tready;
wire rx_output_fifo_eth_packet_axis_tlast;
wire rx_output_fifo_eth_packet_axis_tuser;
wire rx_output_fifo_eth_packet_axis_status_overflow;
wire rx_output_fifo_eth_packet_axis_status_bad_frame;
wire rx_output_fifo_eth_packet_axis_status_good_frame;
reg rx_output_fifo_eth_packet_axis_tready_reg;

// TX ethernet packets fifo wires
wire [7:0] tx_output_fifo_eth_packet_axis_tdata;
wire tx_output_fifo_eth_packet_axis_tvalid;
wire tx_output_fifo_eth_packet_axis_tready;
wire tx_output_fifo_eth_packet_axis_tlast;
wire tx_output_fifo_eth_packet_axis_tuser;
wire tx_output_fifo_eth_packet_axis_status_overflow;
wire tx_output_fifo_eth_packet_axis_status_bad_frame;
wire tx_output_fifo_eth_packet_axis_status_good_frame;

// Configuration
// Alinx CAAD server :3 
wire [47:0] local_mac   = 48'h02_00_00_00_00_00;
wire [31:0] local_ip    = {8'd128, 8'd197, 8'd176,   8'd139};
wire [31:0] gateway_ip  = {8'd128, 8'd197, 8'd176,   8'd1};
wire [31:0] subnet_mask = {8'd255, 8'd255, 8'd255, 8'd0};
// wire [47:0] local_mac   = 48'h02_00_00_00_00_00;
// wire [31:0] local_ip    = {8'd192, 8'd168, 8'd1,   8'd128};
// wire [31:0] gateway_ip  = {8'd192, 8'd168, 8'd1,   8'd1};
// wire [31:0] subnet_mask = {8'd255, 8'd255, 8'd255, 8'd0};

// IP ports not used
assign rx_ip_hdr_ready = 1;
assign rx_ip_payload_axis_tready = 1;

assign tx_ip_hdr_valid = 0;
assign tx_ip_dscp = 0;
assign tx_ip_ecn = 0;
assign tx_ip_length = 0;
assign tx_ip_ttl = 0;
assign tx_ip_protocol = 0;
assign tx_ip_source_ip = 0;
assign tx_ip_dest_ip = 0;
assign tx_ip_payload_axis_tdata = 0;
assign tx_ip_payload_axis_tvalid = 0;
assign tx_ip_payload_axis_tlast = 0;
assign tx_ip_payload_axis_tuser = 0;

// Loop back UDP
wire match_cond = rx_udp_dest_port == 1234;
wire no_match = !match_cond;

reg match_cond_reg = 0;
reg no_match_reg = 0;

always @(posedge clk) begin
    if (rst) begin
        match_cond_reg <= 0;
        no_match_reg <= 0;
    end else begin
        if (rx_udp_payload_axis_tvalid) begin
            if ((!match_cond_reg && !no_match_reg) ||
                (rx_udp_payload_axis_tvalid && rx_udp_payload_axis_tready && rx_udp_payload_axis_tlast)) begin
                match_cond_reg <= match_cond;
                no_match_reg <= no_match;
            end
        end else begin
            match_cond_reg <= 0;
            no_match_reg <= 0;
        end
    end
end

assign tx_udp_hdr_valid = rx_udp_hdr_valid && match_cond;
assign rx_udp_hdr_ready = (tx_eth_hdr_ready && match_cond) || no_match;
assign tx_udp_ip_dscp = 0;
assign tx_udp_ip_ecn = 0;
assign tx_udp_ip_ttl = 64;
assign tx_udp_ip_source_ip = local_ip;
assign tx_udp_ip_dest_ip = rx_udp_ip_source_ip;
assign tx_udp_source_port = rx_udp_dest_port;
assign tx_udp_dest_port = rx_udp_source_port;
assign tx_udp_length = rx_udp_length;
assign tx_udp_checksum = 0;

assign tx_udp_payload_axis_tdata = tx_fifo_udp_payload_axis_tdata;
assign tx_udp_payload_axis_tvalid = tx_fifo_udp_payload_axis_tvalid;
assign tx_fifo_udp_payload_axis_tready = tx_udp_payload_axis_tready;
assign tx_udp_payload_axis_tlast = tx_fifo_udp_payload_axis_tlast;
assign tx_udp_payload_axis_tuser = tx_fifo_udp_payload_axis_tuser;

assign rx_fifo_udp_payload_axis_tdata = rx_udp_payload_axis_tdata;
assign rx_fifo_udp_payload_axis_tvalid = rx_udp_payload_axis_tvalid && match_cond_reg;
assign rx_udp_payload_axis_tready = (rx_fifo_udp_payload_axis_tready && match_cond_reg) || no_match_reg;
assign rx_fifo_udp_payload_axis_tlast = rx_udp_payload_axis_tlast;
assign rx_fifo_udp_payload_axis_tuser = rx_udp_payload_axis_tuser;

// Place first payload byte onto LEDs
reg valid_last = 0;
reg [7:0] led_reg = 0;

always @(posedge clk) begin
    if (rst) begin
        led_reg <= 0;
    end else begin
        if (tx_udp_payload_axis_tvalid) begin
            if (!valid_last) begin
                led_reg <= tx_udp_payload_axis_tdata;
                valid_last <= 1'b1;
            end
            if (tx_udp_payload_axis_tlast) begin
                valid_last <= 1'b0;
            end
        end
    end
end

//assign led = sw;
assign led = led_reg;
assign phy_reset_n = !rst;

assign uart_txd = 0;

eth_mac_1g_rgmii_fifo #(
    .TARGET(TARGET),
    .IODDR_STYLE("IODDR"),
    .CLOCK_INPUT_STYLE("BUFR"),
    .USE_CLK90("TRUE"),
    .ENABLE_PADDING(1),
    .MIN_FRAME_LENGTH(64),
    .TX_FIFO_DEPTH(4096),
    .TX_FRAME_FIFO(1),
    .RX_FIFO_DEPTH(4096),
    .RX_FRAME_FIFO(1)
)
eth_mac_inst (
    .gtx_clk(clk),
    .gtx_clk90(clk90),
    .gtx_rst(rst),
    .logic_clk(clk),
    .logic_rst(rst),

    .tx_axis_tdata(tx_axis_tdata),
    .tx_axis_tvalid(tx_axis_tvalid),
    .tx_axis_tready(tx_axis_tready),
    .tx_axis_tlast(tx_axis_tlast),
    .tx_axis_tuser(tx_axis_tuser),

    .rx_axis_tdata(rx_axis_tdata),
    .rx_axis_tvalid(rx_axis_tvalid),
    .rx_axis_tready(rx_axis_tready),
    .rx_axis_tlast(rx_axis_tlast),
    .rx_axis_tuser(rx_axis_tuser),

    .rgmii_rx_clk(phy_rx_clk),
    .rgmii_rxd(phy_rxd),
    .rgmii_rx_ctl(phy_rx_ctl),
    .rgmii_tx_clk(phy_tx_clk),
    .rgmii_txd(phy_txd),
    .rgmii_tx_ctl(phy_tx_ctl),

    .tx_fifo_overflow(),
    .tx_fifo_bad_frame(),
    .tx_fifo_good_frame(),
    .rx_error_bad_frame(),
    .rx_error_bad_fcs(),
    .rx_fifo_overflow(),
    .rx_fifo_bad_frame(),
    .rx_fifo_good_frame(),
    .speed(),

    .ifg_delay(12)
);

// eth_axis_rx
// eth_axis_rx_inst (
//     .clk(clk),
//     .rst(rst),
//     // AXI input
//     .s_axis_tdata(rx_axis_tdata),
//     .s_axis_tvalid(rx_axis_tvalid),
//     .s_axis_tready(rx_axis_tready),
//     .s_axis_tlast(rx_axis_tlast),
//     .s_axis_tuser(rx_axis_tuser),
//     // Ethernet frame output
//     .m_eth_hdr_valid(rx_eth_hdr_valid),
//     .m_eth_hdr_ready(rx_eth_hdr_ready),
//     .m_eth_dest_mac(rx_eth_dest_mac),
//     .m_eth_src_mac(rx_eth_src_mac),
//     .m_eth_type(rx_eth_type),
//     .m_eth_payload_axis_tdata(rx_eth_payload_axis_tdata),
//     .m_eth_payload_axis_tvalid(rx_eth_payload_axis_tvalid),
//     .m_eth_payload_axis_tready(rx_eth_payload_axis_tready),
//     .m_eth_payload_axis_tlast(rx_eth_payload_axis_tlast),
//     .m_eth_payload_axis_tuser(rx_eth_payload_axis_tuser),
//     // Status signals
//     .busy(),
//     .error_header_early_termination()
// );

// eth_axis_tx
// eth_axis_tx_inst (
//     .clk(clk),
//     .rst(rst),
//     // Ethernet frame input
//     .s_eth_hdr_valid(tx_eth_hdr_valid),
//     .s_eth_hdr_ready(tx_eth_hdr_ready),
//     .s_eth_dest_mac(tx_eth_dest_mac),
//     .s_eth_src_mac(tx_eth_src_mac),
//     .s_eth_type(tx_eth_type),
//     .s_eth_payload_axis_tdata(tx_eth_payload_axis_tdata),
//     .s_eth_payload_axis_tvalid(tx_eth_payload_axis_tvalid),
//     .s_eth_payload_axis_tready(tx_eth_payload_axis_tready),
//     .s_eth_payload_axis_tlast(tx_eth_payload_axis_tlast),
//     .s_eth_payload_axis_tuser(tx_eth_payload_axis_tuser),
//     // AXI output
//     .m_axis_tdata(tx_axis_tdata),
//     .m_axis_tvalid(tx_axis_tvalid),
//     .m_axis_tready(tx_axis_tready),
//     .m_axis_tlast(tx_axis_tlast),
//     .m_axis_tuser(tx_axis_tuser),
//     // Status signals
//     .busy()
// );

// udp_complete
// udp_complete_inst (
//     .clk(clk),
//     .rst(rst),
//     // Ethernet frame input
//     .s_eth_hdr_valid(rx_eth_hdr_valid),
//     .s_eth_hdr_ready(rx_eth_hdr_ready),
//     .s_eth_dest_mac(rx_eth_dest_mac),
//     .s_eth_src_mac(rx_eth_src_mac),
//     .s_eth_type(rx_eth_type),
//     .s_eth_payload_axis_tdata(rx_eth_payload_axis_tdata),
//     .s_eth_payload_axis_tvalid(rx_eth_payload_axis_tvalid),
//     .s_eth_payload_axis_tready(rx_eth_payload_axis_tready),
//     .s_eth_payload_axis_tlast(rx_eth_payload_axis_tlast),
//     .s_eth_payload_axis_tuser(rx_eth_payload_axis_tuser),
//     // Ethernet frame output
//     .m_eth_hdr_valid(tx_eth_hdr_valid),
//     .m_eth_hdr_ready(tx_eth_hdr_ready),
//     .m_eth_dest_mac(tx_eth_dest_mac),
//     .m_eth_src_mac(tx_eth_src_mac),
//     .m_eth_type(tx_eth_type),
//     .m_eth_payload_axis_tdata(tx_eth_payload_axis_tdata),
//     .m_eth_payload_axis_tvalid(tx_eth_payload_axis_tvalid),
//     .m_eth_payload_axis_tready(tx_eth_payload_axis_tready),
//     .m_eth_payload_axis_tlast(tx_eth_payload_axis_tlast),
//     .m_eth_payload_axis_tuser(tx_eth_payload_axis_tuser),
//     // IP frame input
//     .s_ip_hdr_valid(tx_ip_hdr_valid),
//     .s_ip_hdr_ready(tx_ip_hdr_ready),
//     .s_ip_dscp(tx_ip_dscp),
//     .s_ip_ecn(tx_ip_ecn),
//     .s_ip_length(tx_ip_length),
//     .s_ip_ttl(tx_ip_ttl),
//     .s_ip_protocol(tx_ip_protocol),
//     .s_ip_source_ip(tx_ip_source_ip),
//     .s_ip_dest_ip(tx_ip_dest_ip),
//     .s_ip_payload_axis_tdata(tx_ip_payload_axis_tdata),
//     .s_ip_payload_axis_tvalid(tx_ip_payload_axis_tvalid),
//     .s_ip_payload_axis_tready(tx_ip_payload_axis_tready),
//     .s_ip_payload_axis_tlast(tx_ip_payload_axis_tlast),
//     .s_ip_payload_axis_tuser(tx_ip_payload_axis_tuser),
//     // IP frame output
//     .m_ip_hdr_valid(rx_ip_hdr_valid),
//     .m_ip_hdr_ready(rx_ip_hdr_ready),
//     .m_ip_eth_dest_mac(rx_ip_eth_dest_mac),
//     .m_ip_eth_src_mac(rx_ip_eth_src_mac),
//     .m_ip_eth_type(rx_ip_eth_type),
//     .m_ip_version(rx_ip_version),
//     .m_ip_ihl(rx_ip_ihl),
//     .m_ip_dscp(rx_ip_dscp),
//     .m_ip_ecn(rx_ip_ecn),
//     .m_ip_length(rx_ip_length),
//     .m_ip_identification(rx_ip_identification),
//     .m_ip_flags(rx_ip_flags),
//     .m_ip_fragment_offset(rx_ip_fragment_offset),
//     .m_ip_ttl(rx_ip_ttl),
//     .m_ip_protocol(rx_ip_protocol),
//     .m_ip_header_checksum(rx_ip_header_checksum),
//     .m_ip_source_ip(rx_ip_source_ip),
//     .m_ip_dest_ip(rx_ip_dest_ip),
//     .m_ip_payload_axis_tdata(rx_ip_payload_axis_tdata),
//     .m_ip_payload_axis_tvalid(rx_ip_payload_axis_tvalid),
//     .m_ip_payload_axis_tready(rx_ip_payload_axis_tready),
//     .m_ip_payload_axis_tlast(rx_ip_payload_axis_tlast),
//     .m_ip_payload_axis_tuser(rx_ip_payload_axis_tuser),
//     // UDP frame input
//     .s_udp_hdr_valid(tx_udp_hdr_valid),
//     .s_udp_hdr_ready(tx_udp_hdr_ready),
//     .s_udp_ip_dscp(tx_udp_ip_dscp),
//     .s_udp_ip_ecn(tx_udp_ip_ecn),
//     .s_udp_ip_ttl(tx_udp_ip_ttl),
//     .s_udp_ip_source_ip(tx_udp_ip_source_ip),
//     .s_udp_ip_dest_ip(tx_udp_ip_dest_ip),
//     .s_udp_source_port(tx_udp_source_port),
//     .s_udp_dest_port(tx_udp_dest_port),
//     .s_udp_length(tx_udp_length),
//     .s_udp_checksum(tx_udp_checksum),
//     .s_udp_payload_axis_tdata(tx_udp_payload_axis_tdata),
//     .s_udp_payload_axis_tvalid(tx_udp_payload_axis_tvalid),
//     .s_udp_payload_axis_tready(tx_udp_payload_axis_tready),
//     .s_udp_payload_axis_tlast(tx_udp_payload_axis_tlast),
//     .s_udp_payload_axis_tuser(tx_udp_payload_axis_tuser),
//     // UDP frame output
//     .m_udp_hdr_valid(rx_udp_hdr_valid),
//     .m_udp_hdr_ready(rx_udp_hdr_ready),
//     .m_udp_eth_dest_mac(rx_udp_eth_dest_mac),
//     .m_udp_eth_src_mac(rx_udp_eth_src_mac),
//     .m_udp_eth_type(rx_udp_eth_type),
//     .m_udp_ip_version(rx_udp_ip_version),
//     .m_udp_ip_ihl(rx_udp_ip_ihl),
//     .m_udp_ip_dscp(rx_udp_ip_dscp),
//     .m_udp_ip_ecn(rx_udp_ip_ecn),
//     .m_udp_ip_length(rx_udp_ip_length),
//     .m_udp_ip_identification(rx_udp_ip_identification),
//     .m_udp_ip_flags(rx_udp_ip_flags),
//     .m_udp_ip_fragment_offset(rx_udp_ip_fragment_offset),
//     .m_udp_ip_ttl(rx_udp_ip_ttl),
//     .m_udp_ip_protocol(rx_udp_ip_protocol),
//     .m_udp_ip_header_checksum(rx_udp_ip_header_checksum),
//     .m_udp_ip_source_ip(rx_udp_ip_source_ip),
//     .m_udp_ip_dest_ip(rx_udp_ip_dest_ip),
//     .m_udp_source_port(rx_udp_source_port),
//     .m_udp_dest_port(rx_udp_dest_port),
//     .m_udp_length(rx_udp_length),
//     .m_udp_checksum(rx_udp_checksum),
//     .m_udp_payload_axis_tdata(rx_udp_payload_axis_tdata),
//     .m_udp_payload_axis_tvalid(rx_udp_payload_axis_tvalid),
//     .m_udp_payload_axis_tready(rx_udp_payload_axis_tready),
//     .m_udp_payload_axis_tlast(rx_udp_payload_axis_tlast),
//     .m_udp_payload_axis_tuser(rx_udp_payload_axis_tuser),
//     // Status signals
//     .ip_rx_busy(),
//     .ip_tx_busy(),
//     .udp_rx_busy(),
//     .udp_tx_busy(),
//     .ip_rx_error_header_early_termination(),
//     .ip_rx_error_payload_early_termination(),
//     .ip_rx_error_invalid_header(),
//     .ip_rx_error_invalid_checksum(),
//     .ip_tx_error_payload_early_termination(),
//     .ip_tx_error_arp_failed(),
//     .udp_rx_error_header_early_termination(),
//     .udp_rx_error_payload_early_termination(),
//     .udp_tx_error_payload_early_termination(),
//     // Configuration
//     .local_mac(local_mac),
//     .local_ip(local_ip),
//     .gateway_ip(gateway_ip),
//     .subnet_mask(subnet_mask),
//     .clear_arp_cache(0)
// );

// axis_fifo #(
//     .DEPTH(8192),
//     .DATA_WIDTH(8),
//     .KEEP_ENABLE(0),
//     .ID_ENABLE(0),
//     .DEST_ENABLE(0),
//     .USER_ENABLE(1),
//     .USER_WIDTH(1),
//     .FRAME_FIFO(0)
// )
// udp_payload_fifo (
//     .clk(clk),
//     .rst(rst),

//     // AXI input
//     .s_axis_tdata(rx_fifo_udp_payload_axis_tdata),
//     .s_axis_tkeep(0),
//     .s_axis_tvalid(rx_fifo_udp_payload_axis_tvalid),
//     .s_axis_tready(rx_fifo_udp_payload_axis_tready),
//     .s_axis_tlast(rx_fifo_udp_payload_axis_tlast),
//     .s_axis_tid(0),
//     .s_axis_tdest(0),
//     .s_axis_tuser(rx_fifo_udp_payload_axis_tuser),

//     // AXI output
//     .m_axis_tdata(tx_fifo_udp_payload_axis_tdata),
//     .m_axis_tkeep(),
//     .m_axis_tvalid(tx_fifo_udp_payload_axis_tvalid),
//     .m_axis_tready(tx_fifo_udp_payload_axis_tready),
//     .m_axis_tlast(tx_fifo_udp_payload_axis_tlast),
//     .m_axis_tid(),
//     .m_axis_tdest(),
//     .m_axis_tuser(tx_fifo_udp_payload_axis_tuser),

//     // Status
//     .status_overflow(),
//     .status_bad_frame(),
//     .status_good_frame()
// );

axis_fifo #(
    .DEPTH(8192),
    .DATA_WIDTH(8),
    .KEEP_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(1),
    .FRAME_FIFO(0)
    )
eth_packets_fifo(
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(rx_axis_tdata),
    .s_axis_tkeep(0),
    .s_axis_tvalid(rx_axis_tvalid),
    .s_axis_tready(rx_axis_tready),
    .s_axis_tlast(rx_axis_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(rx_axis_tuser),

    // AXI output
    .m_axis_tdata(rx_output_fifo_eth_packet_axis_tdata),
    .m_axis_tkeep(),
    .m_axis_tvalid(rx_output_fifo_eth_packet_axis_tvalid),
    .m_axis_tready(rx_output_fifo_eth_packet_axis_tready),
    .m_axis_tlast(rx_output_fifo_eth_packet_axis_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(rx_output_fifo_eth_packet_axis_tuser),

    // Status
    .status_overflow(rx_output_fifo_eth_packet_axis_status_overflow),
    .status_bad_frame(rx_output_fifo_eth_packet_axis_status_bad_frame),
    .status_good_frame(rx_output_fifo_eth_packet_axis_status_good_frame)

    );


axis_fifo #(
    .DEPTH(8192),
    .DATA_WIDTH(8),
    .KEEP_ENABLE(0),
    .ID_ENABLE(0),
    .DEST_ENABLE(0),
    .USER_ENABLE(1),
    .USER_WIDTH(1),
    .FRAME_FIFO(0)
    )
eth_tx_pkts_fifo(
    .clk(clk),
    .rst(rst),

    // AXI input
    .s_axis_tdata(tx_output_fifo_eth_packet_axis_tdata),
    .s_axis_tkeep(0),
    .s_axis_tvalid(tx_output_fifo_eth_packet_axis_tvalid),
    .s_axis_tready(tx_output_fifo_eth_packet_axis_tready),
    .s_axis_tlast(tx_output_fifo_eth_packet_axis_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(tx_output_fifo_eth_packet_axis_tuser),

    // AXI output
    .m_axis_tdata(tx_axis_tdata),
    .m_axis_tkeep(),
    .m_axis_tvalid(tx_axis_tvalid),
    .m_axis_tready(tx_axis_tready),
    .m_axis_tlast(tx_axis_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(tx_axis_tuser)

    // Status
    // .status_overflow(tx_output_fifo_eth_packet_axis_status_overflow),
    // .status_bad_frame(tx_output_fifo_eth_packet_axis_status_bad_frame),
    // .status_good_frame(tx_output_fifo_eth_packet_axis_status_good_frame)

    );


// wires declarations for the eth_fifo_axis_to_bram_axi module
// Ports for Ethernet Network Controller
    // These might come as input and output ports of this module since we plan to use this code in DISL
wire    [31:0]                  ethnet_axi_araddr;
wire                            ethnet_axi_arvalid;
wire                            ethnet_axi_arready;
wire    [31:0]                  ethnet_axi_awaddr;  // full address, lower 2 bits as well (which were removed in zipversa by rv for word addressing)
wire                            ethnet_axi_awvalid;
wire                            ethnet_axi_awready;
wire    [AXI_DATA_WIDTH-1:0]    ethnet_axi_rdata;
wire                            ethnet_axi_rvalid;
wire                            ethnet_axi_rready;
wire    [AXI_DATA_WIDTH-1:0]    ethnet_axi_wdata;
wire    [3:0]                   ethnet_axi_wstrb;
wire                            ethnet_axi_wvalid;
wire                            ethnet_axi_wready;
wire                            ethnet_b_ready;
wire                            ethnet_b_valid;
wire    [1:0]                   ethnet_b_response;
wire    [31:0]                  ethernet_debug_bus;
// interrupts
wire                            eth_rx_intr;
wire                            eth_tx_intr;




// first ver of this module, not using parameters in the instantiation as of now
eth_fifo_axis_to_bram_axi #(
    .SIMULATION(SIMULATION),
    .VEBPF_PROG_ADDRESS_WIDTH(VEBPF_PROG_ADDRESS_WIDTH),  // for pgm mem depth of every VeBPF core
    .NUMBER_OF_VEBPF(NUMBER_OF_VEBPF),  // number of VeBPF cores
    .MAX_NUMBER_OF_VEBPF(MAX_NUMBER_OF_VEBPF),
    .VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX(VEBPF_RULES_SCHEDULER_TABLE_DEPTH_MAX),
    .VEBPF_PROG_ADDRESS_WIDTH_REDUCED(VEBPF_PROG_ADDRESS_WIDTH_REDUCED)
) 
eth_fifo_to_bram(
    //sys clk and reset
    .clk(clk),
    .rst(rst),

    // AXI STREAM input from ethernet fifo being stored to ther BRAM here for the RV processor to read from
    .s_axis_tdata(rx_output_fifo_eth_packet_axis_tdata),  // these signals connected to eth AXIS fifo 
    .s_axis_tkeep(0),
    .s_axis_tvalid(rx_output_fifo_eth_packet_axis_tvalid),
    .s_axis_tready(rx_output_fifo_eth_packet_axis_tready),
    .s_axis_tlast(rx_output_fifo_eth_packet_axis_tlast),
    .s_axis_tid(0),
    .s_axis_tdest(0),
    .s_axis_tuser(rx_output_fifo_eth_packet_axis_tuser),

    // AXI STREAM OUTPUT  for sending our tx_pkts
    .m_axis_tdata(tx_output_fifo_eth_packet_axis_tdata),  // these signals connected to eth AXIS fifo 
    .m_axis_tkeep(),
    .m_axis_tvalid(tx_output_fifo_eth_packet_axis_tvalid),
    .m_axis_tready(tx_output_fifo_eth_packet_axis_tready),
    .m_axis_tlast(tx_output_fifo_eth_packet_axis_tlast),
    .m_axis_tid(),
    .m_axis_tdest(),
    .m_axis_tuser(tx_output_fifo_eth_packet_axis_tuser),

    // AXI4 s ports (RV connections and others potentially)
        // Initially rv will just read stuff from here and potentially write ctrl reg values
        // for example resetting or clearing BRAM packet etc
    .axi_araddr(s_eth_axi_araddr),
    .axi_arvalid(s_eth_axi_arvalid),
    .axi_arready(s_eth_axi_arready),
    .axi_awaddr(s_eth_axi_awaddr),
    .axi_awvalid(s_eth_axi_awvalid),
    .axi_awready(s_eth_axi_awready),
    .axi_rdata(s_eth_axi_rdata),
    .axi_rvalid(s_eth_axi_rvalid),
    .axi_rready(s_eth_axi_rready),
    .axi_wdata(s_eth_axi_wdata),
    .axi_wstrb(s_eth_axi_wstrb),
    .axi_wvalid(s_eth_axi_wvalid),
    .axi_wready(s_eth_axi_wready),
    .b_ready(s_eth_b_ready),
    .b_valid(s_eth_b_valid),
    .b_response(s_eth_b_response),

    // axil m ports
    .m_eth_bram_axi_araddr(m_eth_axi_araddr),
    .m_eth_bram_axi_arvalid(m_eth_axi_arvalid),
    .m_eth_bram_axi_arready(m_eth_axi_arready),
    .m_eth_bram_axi_awaddr(m_eth_axi_awaddr),
    .m_eth_bram_axi_awvalid(m_eth_axi_awvalid),
    .m_eth_bram_axi_awready(m_eth_axi_awready),
    .m_eth_bram_axi_rdata(m_eth_axi_rdata),
    .m_eth_bram_axi_rvalid(m_eth_axi_rvalid),
    .m_eth_bram_axi_rready(m_eth_axi_rready),
    .m_eth_bram_axi_wdata(m_eth_axi_wdata),
    .m_eth_bram_axi_wstrb(m_eth_axi_wstrb),
    .m_eth_bram_axi_wvalid(m_eth_axi_wvalid),
    .m_eth_bram_axi_wready(m_eth_axi_wready),
    .m_eth_bram_axi_b_ready(m_eth_b_ready),
    .m_eth_bram_axi_b_valid(m_eth_b_valid),
    .m_eth_bram_axi_b_response(m_eth_b_response),

    // Memory write select
    // .eth_mem_write(eth_mem_write),
    .eth_mem_write_req(eth_mem_write_req),
    .eth_mem_write_grant(eth_mem_write_grant),

    // VeBPF prog mem ports
    .VeBPF_prog_addr_in(VeBPF_prog_addr_in),
    .VeBPF_prog_data_in(VeBPF_prog_data_in),
    .VeBPF_prog_write_enable_in(VeBPF_prog_write_enable_in),
    .VeBPF_prog_reset_in(VeBPF_prog_reset_in),                        // separate reset for the prog mem of VeBPF
    .VeBPF_prog_busy_in(VeBPF_prog_busy_in),                      // the progloader is busy writing to VeBPF prog mem
    .VeBPF_prog_done_in(VeBPF_prog_done_in),                      // VeBPF prog has been completed
    .VeBPF_next_rule_switch_flag_in(VeBPF_next_rule_switch_flag_in),                      
    .VeBPF_all_rules_done_switch_flag_in(VeBPF_all_rules_done_switch_flag_in),                      

    // interrupt ports
    .o_rx_int(o_rx_int),
    .o_tx_int(o_tx_int),
    
    //debug bus
    .o_debug(ethernet_debug_bus)


    );  


endmodule

`resetall
