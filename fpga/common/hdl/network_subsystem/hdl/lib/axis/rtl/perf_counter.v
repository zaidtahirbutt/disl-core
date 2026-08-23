`timescale 1ns / 1ps
// `include "panic_define.v"

module perf_counter #
(

    // Will send rxpkts of this len for throughput cal
    parameter RX_PKT_LEN_FOR_THROUGHPUT_CAL = 1024,

    // will use 3+1 rxpkts for throughput cal.. 1 rxpkt out of these will separately be used to trigger the
    // start of throughput calculation
    parameter TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL = 3,
    parameter COUNTER_BIT_WIDTH = 32,
    parameter VEBPF_PERF_MEASURE = 1,
        // make this 0 if measuring performance of riscv filtering
    parameter SIMULATION = 1

)
(
    input  wire                       clk,
    input  wire                       rst,

    // will read this pulse (rxpkt_filtering_done) 4 times, this will be HIGH for 1 clk only, will send 4 rxpkts of lengths of 1024 bytes 
    // after 1 rxpkt is filtered, rxpkt_filtering_done gets HIGH which will start our perf_counter and it will continue counting till 3 more
    // pulses of rxpkt_filtering_done are received and throughput calculation will be DONE and its flag performance_calculation_done flag
    // will become HIGH so that our ILA can show us the throughput at thoughput output in form of the perf_counter value so we dont have to make
    // extra hw circuits for multiplications and divisons for throughput calculation, we will do that on calculator.
    //  the total throughput for VeBPF filtering will be:  
        // "THROUGHPUT = of traffic %f Mbps = 3 (total rxpkts) x (1024 x 8 bits) x 83/100 (for sim) MHz sysclk / perf_counter" 
        // "THROUGHPUT = of traffic %f Mbps = 3 (total rxpkts) x (1024 x 8 bits) / (perf_counter x (1/(83 or 100 MHz)) IS TOTAL TIME TAKEN TO PROCESS THREE rxpkts of lengths mentioned in numerator" 

    input  wire                                 rxpkt_filtering_done_in,
    output  reg                                 perf_measure_done_out,
    output  reg [COUNTER_BIT_WIDTH-1:0]         perf_counter_out

);

reg [3:0] total_rxpkts_filtered_reg;
reg start_counting_flag_reg;
reg display_flag_reg;

always@(posedge clk) begin

    if(rst) begin

        perf_measure_done_out <= 0;
        perf_counter_out <= 0;
        total_rxpkts_filtered_reg <= 0;
        display_flag_reg <= 0;

    end else begin

        // 1st rxpkt filtered
        if (rxpkt_filtering_done_in) begin

            total_rxpkts_filtered_reg <= total_rxpkts_filtered_reg + 1;

            // start counting..
            start_counting_flag_reg <= 1;
            
        end

        // 1st rxpkt is used to trigger perf_counter
        if (total_rxpkts_filtered_reg < (TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL+1)) begin 

            // increment counter
            if (start_counting_flag_reg) begin
                perf_counter_out <= perf_counter_out + 1;
            end

        end else begin
            
            perf_counter_out <= perf_counter_out;
            perf_measure_done_out <= 1;

            // so that it displays once
            if (!perf_measure_done_out && (!display_flag_reg)) begin

                if (SIMULATION) begin

                    if (VEBPF_PERF_MEASURE) begin

                        // measuring with 100 MHz sys clk   
                        
                        // $display("- VeBPF filtering Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (1024 * 8)) * 100 )/ perf_counter_out)); 
                        //- VeBPF filtering Throughput: 74.000000 Mbps 
                        // when I calculated the throughput of input rxpkts through the PHYs, it was 74.2 Mbps :O by including the delay between rx_dvs while looking at
                        // perf_counter_out between two rxpkt rx_dv

                        // measuring with 83.33 MHz sys clk            

                        // so let me use rxpkts of length 1500 bytes and see the throughput I get using VeBPF filtering
                        // $display("- VeBPF filtering 1500 bytes rxpkts Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (1500 * 8)) * 83.33 )/ perf_counter_out));
                        // - VeBPF filtering Throughput: 98.741977 Mbps 
                        // Real input throughput = 98.74 Mbps

                        // so let me use rxpkts of length 1024 bytes and see the throughput I get using VeBPF filtering
                        // $display("- VeBPF filtering 1024 bytes rxpkts Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (1024 * 8)) * 83.33 )/ perf_counter_out)); 
                        // - VeBPF filtering Throughput: 98.169698 Mbps
                        // Real throughput using rx_dv of input rxpkts = 98.17 Mbps.. 

                        // so let me use rxpkts of length 512 bytes and see the throughput I get using VeBPF filtering
                        // $display("- VeBPF filtering 512 bytes rxpkts Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (512 * 8)) * 83.33 )/ perf_counter_out));
                        // - VeBPF filtering Throughput: 96.408911 Mbps 
                        // Real input throughput = 96.41 Mbps

                        // so let me use rxpkts of length 256 bytes and see the throughput I get using VeBPF filtering
                        // $display("- VeBPF filtering 256 bytes rxpkts Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (256 * 8)) * 83.33 )/ perf_counter_out));
                        // - VeBPF filtering Throughput: 93.07 Mbps 
                        // Real input throughput = 93.10 Mbps

                        // so let me use rxpkts of length 128 bytes and see the throughput I get using VeBPF filtering
                        // $display("- VeBPF filtering 128 bytes rxpkts  Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (128 * 8)) * 83.33 )/ perf_counter_out));
                        // - VeBPF filtering Throughput: 87.04 Mbps 
                        // Real input throughput = 87.04 Mbps

                        // so let me use rxpkts of length 64 bytes and see the throughput I get using VeBPF filtering
                        // $display("- VeBPF filtering 64 bytes rxpkts Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (64 * 8)) * 83.33 )/ perf_counter_out));
                        // - VeBPF filtering Throughput: 77.05 Mbps 
                        // Real input throughput = 77.15 Mbps

                    end else begin

                        // measuring with 83.33 MHz sys clk

                        // so let me use rxpkts of length 1500 bytes and see the throughput I get using RISCV filtering
                        // $display("- RISCV filtering 1500 bytes rxpkts Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (1500 * 8)) * 83.33 )/ perf_counter_out));
                        // - RISCV filtering Throughput: 16.96 Mbps 
                        // Real input throughput = 98.74 Mbps
                        // 26 Jan 2024 updated experiments with riscv c code that reads rxpkt hdrs only 
                            // - RISCV filtering 1500 bytes rxpkts Throughput: 98.745227 Mbps
                            // Real input throughput = 98.74 Mbps

                        // so let me use rxpkts of length 1024 bytes and see the throughput I get using RISCV filtering
                        // $display("- RISCV filtering 1024 bytes rxpkts Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (1024 * 8)) * 83.33 )/ perf_counter_out)); 
                        // - RISCV filtering Throughput: 16.71 Mbps
                        // Real throughput using rx_dv of input rxpkts = 98.17 Mbps..
                        // 26 Jan 2024 updated experiments with riscv c code that reads rxpkt hdrs only 
                            // - RISCV filtering 1024 bytes rxpkts Throughput: 98.155583 Mbps 
                            // Real throughput using rx_dv of input rxpkts = 98.17 Mbps..


                        // so let me use rxpkts of length 512 bytes and see the throughput I get using RISCV filtering
                        // $display("- RISCV filtering 512 bytes rxpkts Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (512 * 8)) * 83.33 )/ perf_counter_out));
                        // - RISCV filtering Throughput: 15.956228 Mbps 
                        // Real input throughput = 96.41 Mbps
                        // 26 Jan 2024 updated experiments with riscv c code that reads rxpkt hdrs only
                            // - RISCV filtering 512 bytes rxpkts Throughput: 57.674836 Mbps
                            // Real input throughput = 96.41 Mbps


                        // so let me use rxpkts of length 256 bytes and see the throughput I get using RISCV filtering
                        // $display("- RISCV filtering 256 bytes rxpkts  Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (256 * 8)) * 83.33 )/ perf_counter_out));
                        // - RISCV filtering Throughput: 14.65 Mbps 
                        // Real input throughput = 93.10 Mbps
                        // 26 Jan 2024 updated experiments with riscv c code that reads rxpkt hdrs only
                            // - RISCV filtering 256 bytes rxpkts  Throughput: 32.647591 Mbps 
                            // Real input throughput = 93.10 Mbps

                        // so let me use rxpkts of length 128 bytes and see the throughput I get using RISCV filtering
                        // $display("- RISCV filtering 128 bytes rxpkts Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (128 * 8)) * 83.33 )/ perf_counter_out));
                        // - RISCV filtering Throughput: 12.59 Mbps 
                        // Real input throughput = 87.04 Mbps  
                        // 26 Jan 2024 updated experiments with riscv c code that reads rxpkt hdrs only
                            // - RISCV filtering 128 bytes rxpkts Throughput: 16.679030 Mbps
                            // Real input throughput = 87.04 Mbps

                        // so let me use rxpkts of length 64 bytes and see the throughput I get using RISCV filtering
                        // $display("- RISCV filtering 64 bytes rxpkts Throughput: %f Mbps " , (((TOTAL_RX_PKTS_FOR_THROUGHPUT_CAL * (64 * 8)) * 83.33 )/ perf_counter_out));
                        // - RISCV filtering Throughput: 9.82 Mbps 
                        // Real input throughput = 77.15 Mbps
                        // 26 Jan 2024 updated experiments with riscv c code that reads rxpkt hdrs only
                            // - RISCV filtering 64 bytes rxpkts Throughput: 9.75 Mbps
                            // Real input throughput = 77.15 Mbps
                    end

                end 

                display_flag_reg <= 1; 
            end

        end  
    
    end

end

endmodule
