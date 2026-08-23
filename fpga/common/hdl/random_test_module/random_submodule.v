module random_submodule (

    input clk,
    input rst,
    input [3:0] sub_four_bit_in,
    output [3:0] sub_four_bit_out
   
);


assign sub_four_bit_out = sub_four_bit_out_reg;


reg [3:0] sub_four_bit_out_reg;

always @(posedge clk) begin

    if (rst) begin 

        sub_four_bit_out_reg <= 0;

    end else begin

        sub_four_bit_out_reg <= sub_four_bit_in; 

    end

end


endmodule
