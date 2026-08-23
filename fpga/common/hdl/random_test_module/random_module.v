module random_module 
(

    input clk,
    input rst,
    input [3:0] four_bit_in,
    output [3:0] four_bit_out
   
);



    random_submodule
    rand_sub_inst(
        
        .clk(clk),
        .rst(rst),
        .sub_four_bit_in(four_bit_in),
        .sub_four_bit_out(four_bit_out)

    );



endmodule


