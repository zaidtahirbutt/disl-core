`timescale 1ps/1ps
module tb_top;
	
    parameter SIZE = 6768;//6372;//6768;
    reg clk_i;
    reg rst_i;
    initial clk_i = 0;
    initial rst_i = 1;
    always #10 clk_i = ~clk_i;
    always #30000 rst_i = 0;

    reg [7:0] mem [0:SIZE-1];
    initial $readmemh("jpeg.hex", mem);
    
    reg [15:0] rgb565[0:320*240 - 1];
    reg [31:0] write_counter;
    initial write_counter = 0;
    reg [31:0] read_counter;
    initial read_counter  = 0;
    wire read_valid = rst_i? 0 : (read_counter < SIZE);
    wire [31:0] mem_word = (read_counter < SIZE) ? {mem[3 + read_counter], mem[2 + read_counter ], mem[1 + read_counter],mem[read_counter]} : 
                            {mem[3 + SIZE], mem[2 + SIZE ], mem[1 + SIZE],mem[SIZE]};
    wire last = 0;//mem_word[31:16] == 8'hd9ff;
    wire accept;
    wire valid;
    wire [15:0] width;
    wire [15:0] height;
    wire [15:0] pixel_x;
    wire [15:0] pixel_y;
    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;
    wire idle;

    always @(posedge clk_i) begin
        if (!rst_i && accept && read_valid) begin
            read_counter <= (read_counter < SIZE) ? read_counter + 4 : read_counter;
        end
        
        if (valid) begin
         write_counter <= write_counter + 1;
         rgb565[pixel_y*320 + pixel_x] <= {r[7:3], g[7:2], b[7:3]};
        end
    end
    
    integer fp, i;
    initial begin
    @(posedge read_valid)
    @(negedge read_valid)
    #10000
    fp = $fopen("rgb.hex");
    for (i = 0; i < 320*240; i = i + 1)
        $fdisplayh(fp, rgb565[i]);
    $fclose(fp);
    end
    
jpeg_core
#(
      .SUPPORT_WRITABLE_DHT(0), .GRAYSCALE(1)
)
 uut (
    // Inputs
     .clk_i(clk_i)
    ,.rst_i(rst_i)
    ,.inport_valid_i(read_valid)
    ,.inport_data_i(mem_word)
    ,.inport_strb_i(4'hF)
    ,.inport_last_i(last)
    ,.outport_accept_i(1)
    ,.inport_accept_o(accept)
    ,.outport_valid_o(valid)
    ,.outport_width_o(width)
    ,.outport_height_o(height)
    ,.outport_pixel_x_o(pixel_x)
    ,.outport_pixel_y_o(pixel_y)
    ,.outport_pixel_r_o(r)
    ,.outport_pixel_g_o(g)
    ,.outport_pixel_b_o(b)
    ,.idle_o(idle)
);
 

endmodule
