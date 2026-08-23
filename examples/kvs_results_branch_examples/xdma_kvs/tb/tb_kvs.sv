/*******************************************************************************
- Simulate the KVS module as a standalone module.
*******************************************************************************/
`timescale 1ns/1ns

module tb_kvs();
// Parameters
parameter LISTEN_PORT    = 16'd44000;
// parameter HASH_WIDTH  = 16;
// parameter KEY_WIDTH   = 32;
parameter VALUE_SIZE     = 16;
parameter MEM_ADDR_WIDTH = 10;

// Internal signals
logic clk;
logic rst;
logic [63:0] cycle_count;
// Configuration interface (AXI-lite) for the kvs module
logic [31:0] s_axil_awaddr;
logic        s_axil_awvalid;
logic        s_axil_awready;
logic [31:0] s_axil_wdata;
logic [3 :0] s_axil_wstrb;
logic        s_axil_wvalid;
logic        s_axil_wready;
logic [1 :0] s_axil_bresp;
logic        s_axil_bvalid;
logic        s_axil_bready;
logic [31:0] s_axil_araddr;
logic        s_axil_arvalid;
logic        s_axil_arready;
logic [31:0] s_axil_rdata;
logic [1 :0] s_axil_rresp;
logic        s_axil_rvalid;
logic        s_axil_rready;
// AXI-lite master interface for memory accesses by the KVS module
logic [31:0] m_axil_awaddr;
logic        m_axil_awvalid;
logic        m_axil_awready;
logic [31:0] m_axil_wdata;
logic [3 :0] m_axil_wstrb;
logic        m_axil_wvalid;
logic        m_axil_wready;
logic [1 :0] m_axil_bresp;
logic        m_axil_bvalid;
logic        m_axil_bready;
logic [31:0] m_axil_araddr;
logic        m_axil_arvalid;
logic        m_axil_arready;
logic [31:0] m_axil_rdata;
logic [1 :0] m_axil_rresp;
logic        m_axil_rvalid;
logic        m_axil_rready;


// Define tasks
// Write request on AXI-lite configuration interface
task axi_lite_write;
  input logic [31:0] axi_address;
  input logic [31:0] axi_wdata;
  input logic [3 :0] axi_wstrb;
  begin
    @(posedge clk)begin
      s_axil_awvalid <= 1'b1;
      s_axil_awaddr  <= axi_address;
      s_axil_wvalid  <= 1'b1;
      s_axil_wdata   <= axi_wdata;
      s_axil_wstrb   <= axi_wstrb;
    end
    wait(s_axil_awvalid & s_axil_awready & s_axil_wvalid & s_axil_wready);
    @(posedge clk)begin
      s_axil_awvalid <= 1'b0;
      s_axil_awaddr  <= 32'd0;
      s_axil_wvalid  <= 1'b0;
      s_axil_wdata   <= 32'd0;
      s_axil_wstrb   <= 4'b0000;
    end
    wait(s_axil_bready & s_axil_bvalid);
    if(s_axil_bresp != 2'b00)begin
      $display("KVS configuration interface write error!\n");
      $stop;
    end
    else begin
      $display("KVS configuration interface write success. Address:%h, Data:%h, wstrb:%b\n", axi_address, axi_wdata, axi_wstrb);
    end
  end
endtask


// Read request on AXI-lite configuration interface
task axi_lite_read;
  input logic [31:0] axi_address;
  input logic [31:0] expected_rdata;
  begin
    @(posedge clk)begin
      s_axil_arvalid <= 1'b1;
      s_axil_araddr  <= axi_address;
    end
    wait(s_axil_arvalid & s_axil_arready);
    @(posedge clk)begin
      s_axil_arvalid <= 1'b0;
      s_axil_araddr  <= 32'd0;
    end
    wait(s_axil_rready & s_axil_rvalid);
    if((s_axil_rdata != expected_rdata) | (s_axil_rresp != 2'b00))begin
      $display("AXI lite config. interface read error! Address:%h Expected:%h, Received:%h\n", axi_address, expected_rdata, s_axil_rdata);
      $stop;
    end
    else begin
      $display("AXI lite config. interface read success. Address:%h, Data:%h\n", axi_address, s_axil_rdata);
    end
  end
endtask



// Instantiate the KVS module
kvs #(
  .LISTEN_PORT(LISTEN_PORT),
  .HASH_WIDTH(16),
  .KEY_WIDTH(32),
  .VALUE_WIDTH(32),
  .VALUE_SIZE(VALUE_SIZE)
) DUT (
  .clk(clk),
  .rst(rst),
  // Configuration interface (AXI-lite)
  .s_axil_awaddr(s_axil_awaddr),
  .s_axil_awvalid(s_axil_awvalid),
  .s_axil_awready(s_axil_awready),
  .s_axil_wdata(s_axil_wdata),
  .s_axil_wstrb(s_axil_wstrb),
  .s_axil_wvalid(s_axil_wvalid),
  .s_axil_wready(s_axil_wready),
  .s_axil_bresp(s_axil_bresp),
  .s_axil_bvalid(s_axil_bvalid),
  .s_axil_bready(s_axil_bready),
  .s_axil_araddr(s_axil_araddr),
  .s_axil_arvalid(s_axil_arvalid),
  .s_axil_arready(s_axil_arready),
  .s_axil_rdata(s_axil_rdata),
  .s_axil_rresp(s_axil_rresp),
  .s_axil_rvalid(s_axil_rvalid),
  .s_axil_rready(s_axil_rready),
  // AXI-lite master interface for memory accesses by the KVS module
  .m_axil_awaddr(m_axil_awaddr),
  .m_axil_awvalid(m_axil_awvalid),
  .m_axil_awready(m_axil_awready),
  .m_axil_wdata(m_axil_wdata),
  .m_axil_wstrb(m_axil_wstrb),
  .m_axil_wvalid(m_axil_wvalid),
  .m_axil_wready(m_axil_wready),
  .m_axil_bresp(m_axil_bresp),
  .m_axil_bvalid(m_axil_bvalid),
  .m_axil_bready(m_axil_bready),
  .m_axil_araddr(m_axil_araddr),
  .m_axil_arvalid(m_axil_arvalid),
  .m_axil_arready(m_axil_arready),
  .m_axil_rdata(m_axil_rdata),
  .m_axil_rresp(m_axil_rresp),
  .m_axil_rvalid(m_axil_rvalid),
  .m_axil_rready(m_axil_rready)
);

assign m_axil_rresp = 2'b00;


// Instantiate the BRAM AXI module
bram_axi#(
  .ADDR_WIDTH(MEM_ADDR_WIDTH),
  .DATA_WIDTH(32),
  .INITIALIZE(1),
  .INIT_FILE("./test_full.hex")
) mem_inst (
  .clk(clk),
  .rst(rst),
  .mem_axi_araddr(m_axil_araddr >> 2),
  .mem_axi_arvalid(m_axil_arvalid),
  .mem_axi_arready(m_axil_arready),
  .mem_axi_awaddr(m_axil_awaddr >> 2),
  .mem_axi_awvalid(m_axil_awvalid),
  .mem_axi_awready(m_axil_awready),
  .mem_axi_rdata(m_axil_rdata),
  .mem_axi_rvalid(m_axil_rvalid),
  .mem_axi_rready(m_axil_rready),
  .mem_axi_wdata(m_axil_wdata),
  .mem_axi_wstrb(m_axil_wstrb),
  .mem_axi_wvalid(m_axil_wvalid),
  .mem_axi_wready(m_axil_wready),
  .mem_b_ready(m_axil_bready),
  .mem_b_valid(m_axil_bvalid),
  .mem_b_response(m_axil_bresp)
);




// Clock and reset generation
always #5 clk = !clk;

initial begin
  clk   = 0;
  rst = 0;
  repeat(5) @(posedge clk);
  @(posedge clk)
    rst = 1;
  repeat(10) @(posedge clk);
    rst = 0;
end

// Cycle counter
always @(posedge clk)begin
  if(rst)
    cycle_count <= 64'd0;
  else
    cycle_count <= cycle_count + 1;
end


// Monitor axil master interface
logic rd_in_progress, wr_in_progress;
always @(negedge clk)begin
  if(rst)
    rd_in_progress <= 1'b0;
  else begin
    if(m_axil_arready & m_axil_arvalid & !rd_in_progress)begin
      $display("Memory read in progress. Address:%h ...\n", m_axil_araddr);
      rd_in_progress <= 1'b1;
    end
    else if(rd_in_progress & m_axil_rvalid & m_axil_rready)begin
      $display("Memory read complete. Address:%h, Data:%h ...\n", m_axil_araddr, m_axil_rdata);
      rd_in_progress <= 1'b0;
    end
  end
end

always @(negedge clk)begin
  if(rst)
    wr_in_progress <= 1'b0;
  else begin
    if(m_axil_awready & m_axil_awvalid & m_axil_wready & m_axil_wvalid & !wr_in_progress)begin
      $display("Memory write in progress. Address:%h, Data:%h, wstrb:%b ...\n", m_axil_awaddr, m_axil_wdata, m_axil_wstrb);
      wr_in_progress <= 1'b1;
    end
    else if(wr_in_progress & m_axil_bready & m_axil_bvalid)begin
      $display("Write complete.\n");
      wr_in_progress <= 1'b0;
    end
  end
end


// Configuration interface
initial begin
  s_axil_awaddr  <= 32'd0;
  s_axil_awvalid <= 1'b0;
  s_axil_wdata   <= 32'd0;
  s_axil_wstrb   <= 4'd0;
  s_axil_wvalid  <= 1'b0;
  s_axil_rready  <= 1'b1;
  s_axil_bready  <= 1'b1;
  s_axil_araddr  <= 32'd0;
  s_axil_arvalid <= 1'b0;
  wait(rst == 1);
  wait(rst == 0);
  repeat(5) @(posedge clk);
  // configuration interface write test
  axi_lite_write(32'h8, 32'h11111111, 4'b0101);
  repeat(5) @(posedge clk);
  axi_lite_read(32'd8, 32'h00110011);
  // Configure the KVS module
  axi_lite_write(32'h8, 32'h0, 4'b1111);
  axi_lite_write(32'hC, 32'h120, 4'b1111);
  repeat(5) @(posedge clk);
  // Read CSRs
  axi_lite_read(32'h0, 32'h0);
  axi_lite_read(32'h4, 32'h0);
  axi_lite_read(32'h8, 32'h0);
  axi_lite_read(32'hc, 32'h120);
  axi_lite_read(32'h10, 32'h0);

  repeat(5) @(posedge clk);
  // Write to command register
  axi_lite_write(32'h4, 32'h1, 4'b0001);
  wait(DUT.kvs_csr.kvs_csr_struct.status == 32'h6); 
  // Configure KVS module for the second packet
  axi_lite_write(32'h8, 32'h6c, 4'b1111);
  axi_lite_write(32'hC, 32'h170, 4'b1111);
  // Write to command register
  axi_lite_write(32'h4, 32'h1, 4'b0001);
  wait(DUT.kvs_csr.kvs_csr_struct.status == 32'h1); 
  wait(DUT.kvs_csr.kvs_csr_struct.status == 32'h6); 

  repeat(3) @(posedge clk);
  axi_lite_write(32'h8, 32'hC0, 4'b1111);
  axi_lite_write(32'hC, 32'h1d0, 4'b1111);
  // Write to command register
  axi_lite_write(32'h4, 32'h1, 4'b0001);
  wait(DUT.kvs_csr.kvs_csr_struct.status == 32'h1); 
  wait(DUT.kvs_csr.kvs_csr_struct.status == 32'h6); 

  repeat(2) @(posedge clk);
  axi_lite_write(32'h8, 32'h220, 4'b1111);
  axi_lite_write(32'hC, 32'h290, 4'b1111);
  // Update kvs memory content to force a collision
  DUT.key_store.mem[46912] = 33'h1444888aa;
  // Write to command register
  axi_lite_write(32'h4, 32'h1, 4'b0001);
  wait(DUT.kvs_csr.kvs_csr_struct.status == 32'h1); 
  wait(DUT.kvs_csr.kvs_csr_struct.status == 32'h6); 

  $display("Test complete!\n");
end




endmodule
