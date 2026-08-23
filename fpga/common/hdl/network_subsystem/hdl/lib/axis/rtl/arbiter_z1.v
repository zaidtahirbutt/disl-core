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

`timescale 1ns / 1ps

/*
 * Arbiter module
 */
module arbiter_z1 #
    
(   // PORTS should be > 1
    parameter PORTS = 4,
    // arbitration type: "PRIORITY" or "ROUND_ROBIN"
    parameter TYPE = "PRIORITY",
    // block type: "NONE", "REQUEST", "ACKNOWLEDGE"
    parameter BLOCK = "NONE",
    // LSB priority: "LOW", "HIGH"
    parameter LSB_PRIORITY = "LOW"


    /*

        .PORTS(S_COUNT),  // 2
        .TYPE(ARB_TYPE),
        .BLOCK("ACKNOWLEDGE"),
        .LSB_PRIORITY(LSB_PRIORITY)

        //// arbitration type: "PRIORITY" or "ROUND_ROBIN"
        // parameter ARB_TYPE = "PRIORITY",
        // // LSB priority: "LOW", "HIGH"
        // parameter LSB_PRIORITY = "HIGH"

    */

)
(
    input  wire                     clk,
    input  wire                     rst,

    input  wire [PORTS-1:0]         request, // request becomes b'10 at 1.646
    input  wire [PORTS-1:0]         acknowledge,
    // acknowledge becomes b'10 from b'00 at 1.650 us cx now grant = b'10 at 1.650 us

    output wire [PORTS-1:0]         grant,  // here output is grant b'10 at 1.650 us 
    output wire                     grant_valid, // here output is grant_valid_reg 1 at 1.650 us
    output wire [$clog2(PORTS)-1:0] grant_encoded  // here output is grant_encoded_reg 1 at 1.650 us
);

/*

    assign request = s_axis_tvalid & ~grant;  // bitwise!! :3
    // s_axis_tvalid becomes b'10 at 1.650 us
    // grant becomes b'10 at 1.650 us

*/

reg [PORTS-1:0] grant_reg = 0, grant_next;
reg grant_valid_reg = 0, grant_valid_next;
reg [$clog2(PORTS)-1:0] grant_encoded_reg = 0, grant_encoded_next;

assign grant_valid = grant_valid_reg;
assign grant = grant_reg;
assign grant_encoded = grant_encoded_reg;

wire request_valid;
wire [$clog2(PORTS)-1:0] request_index;
wire [PORTS-1:0] request_mask;

priority_encoder_z1 #(
    .WIDTH(PORTS),  // 2 
    .LSB_PRIORITY(LSB_PRIORITY)  // HIGH
)
priority_encoder_inst (
    .input_unencoded(request), // request becomes b'10 at 1.646 us 
    .output_valid(request_valid),  // 1 at 1.646 us
    .output_encoded(request_index),  // 1 at 1.646 us
    .output_unencoded(request_mask)  // b'10 at 1.646 us
);

reg [PORTS-1:0] mask_reg = 0, mask_next;

wire masked_request_valid;
wire [$clog2(PORTS)-1:0] masked_request_index;
wire [PORTS-1:0] masked_request_mask;

priority_encoder_z1 #(
    .WIDTH(PORTS),
    .LSB_PRIORITY(LSB_PRIORITY)
)
priority_encoder_masked (
    .input_unencoded(request & mask_reg),  // maybe input has to be sent in a certain way for round robin arb
    .output_valid(masked_request_valid),
    .output_encoded(masked_request_index),
    .output_unencoded(masked_request_mask)
);

always @* begin
    grant_next = 0;
    grant_valid_next = 0;
    grant_encoded_next = 0;
    mask_next = mask_reg;

    if (BLOCK == "REQUEST" && grant_reg & request) begin
        // granted request still asserted; hold it
        grant_valid_next = grant_valid_reg;
        grant_next = grant_reg;
        grant_encoded_next = grant_encoded_reg;
    end else if (BLOCK == "ACKNOWLEDGE" && grant_valid && !(grant_reg & acknowledge)) begin
        // granted request not yet acknowledged; hold it

        //// acknowledge becomes b'10 from b'00 at 1.650 us cx now grant = b'10 at 1.650 us
            // this means grant has been acknowledged and doesnt enter this and hence
            // pulls down grants to 0

        grant_valid_next = grant_valid_reg;
        grant_next = grant_reg;
        grant_encoded_next = grant_encoded_reg;
    end else if (request_valid) begin
        if (TYPE == "PRIORITY") begin
            grant_valid_next = 1; // 1 at 1.646 us
            grant_next = request_mask;  // here output is b'10 at 1.646 us
            grant_encoded_next = request_index;  // 1 at 1.646 us
        end else if (TYPE == "ROUND_ROBIN") begin  // deosnt enter below
            if (masked_request_valid) begin  // masked_request_valid = 0 at 1.650 us
                grant_valid_next = 1;
                grant_next = masked_request_mask;  // but not round robin
                grant_encoded_next = masked_request_index;
                if (LSB_PRIORITY == "LOW") begin
                    mask_next = {PORTS{1'b1}} >> (PORTS - masked_request_index);
                end else begin
                    mask_next = {PORTS{1'b1}} << (masked_request_index + 1);
                end
            end else begin
                grant_valid_next = 1;
                grant_next = request_mask;  // request_mask = b'10
                grant_encoded_next = request_index;  // 1 at 1.646 us
                if (LSB_PRIORITY == "LOW") begin
                    mask_next = {PORTS{1'b1}} >> (PORTS - request_index);
                end else begin
                    mask_next = {PORTS{1'b1}} << (request_index + 1);
                end
            end
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        grant_reg <= 0;
        grant_valid_reg <= 0;
        grant_encoded_reg <= 0;
        mask_reg <= 0;
    end else begin
        grant_reg <= grant_next;  // here output is grant_reg b'10 at 1.650 us 
        grant_valid_reg <= grant_valid_next;  // here output is grant_valid_reg 1 at 1.650 us 
        grant_encoded_reg <= grant_encoded_next;  // here output is grant_encoded_reg 1 at 1.650 us
        mask_reg <= mask_next;  // 00 isnt used
    end
end

endmodule
