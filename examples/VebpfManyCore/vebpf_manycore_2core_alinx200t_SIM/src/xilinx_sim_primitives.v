// Behavioural models of the Xilinx primitives this design instantiates.
//
// WHY THIS FILE EXISTS
// --------------------
// The alinx_ax7a200t clocking chain uses IBUFGDS, BUFG and MMCME2_BASE. Those
// are hard primitives: Vivado knows them, Icarus does not, and this repo ships
// no unisim library. Without models the simulation cannot elaborate at all --
// which is why there was no alinx simulation example before.
//
// SIMULATION ONLY. This file lives in the _SIM example's src/ and is never part
// of a synthesis build, where Vivado supplies the real primitives. The models
// are functional, not timing-accurate: no jitter, no duty-cycle distortion, no
// lock time beyond a fixed delay.
`timescale 1ps/1ps

// Differential input buffer: the FPGA resolves I/IB to one single-ended clock.
module IBUFGDS #(
    parameter DIFF_TERM  = "FALSE",
    parameter IBUF_LOW_PWR = "TRUE",
    parameter IOSTANDARD = "DEFAULT"
) (
    output O,
    input  I,
    input  IB
);
    assign O = I;   // IB is the complement and carries no extra information here
endmodule

// Global clock buffer: a routing resource, functionally a wire.
module BUFG (
    output O,
    input  I
);
    assign O = I;
endmodule

// Mixed-Mode Clock Manager, base variant.
//
// Derives each output from the MEASURED input period rather than from a
// hardcoded frequency, so it stays correct if the testbench changes the input
// clock:
//     Fvco     = Fin * CLKFBOUT_MULT_F / DIVCLK_DIVIDE
//     Fclkout<n> = Fvco / CLKOUT<n>_DIVIDE
// Phase shift is applied as a fraction of the output period.
module MMCME2_BASE #(
    parameter BANDWIDTH = "OPTIMIZED",
    parameter real CLKFBOUT_MULT_F = 5.0,
    parameter real CLKFBOUT_PHASE  = 0.0,
    parameter real CLKIN1_PERIOD   = 5.0,
    parameter DIVCLK_DIVIDE        = 1,
    parameter real CLKOUT0_DIVIDE_F = 8.0,
    parameter CLKOUT1_DIVIDE = 8,  parameter CLKOUT2_DIVIDE = 5,
    parameter CLKOUT3_DIVIDE = 1,  parameter CLKOUT4_DIVIDE = 1,
    parameter CLKOUT5_DIVIDE = 1,  parameter CLKOUT6_DIVIDE = 1,
    parameter real CLKOUT0_DUTY_CYCLE = 0.5, parameter real CLKOUT1_DUTY_CYCLE = 0.5,
    parameter real CLKOUT2_DUTY_CYCLE = 0.5, parameter real CLKOUT3_DUTY_CYCLE = 0.5,
    parameter real CLKOUT4_DUTY_CYCLE = 0.5, parameter real CLKOUT5_DUTY_CYCLE = 0.5,
    parameter real CLKOUT6_DUTY_CYCLE = 0.5,
    parameter real CLKOUT0_PHASE = 0.0, parameter real CLKOUT1_PHASE = 0.0,
    parameter real CLKOUT2_PHASE = 0.0, parameter real CLKOUT3_PHASE = 0.0,
    parameter real CLKOUT4_PHASE = 0.0, parameter real CLKOUT5_PHASE = 0.0,
    parameter real CLKOUT6_PHASE = 0.0,
    parameter real REF_JITTER1 = 0.010,
    parameter STARTUP_WAIT = "FALSE",
    parameter CLKOUT4_CASCADE = "FALSE"
) (
    output reg CLKOUT0 = 0, output CLKOUT0B,
    output reg CLKOUT1 = 0, output CLKOUT1B,
    output reg CLKOUT2 = 0, output CLKOUT2B,
    output reg CLKOUT3 = 0, output CLKOUT3B,
    output reg CLKOUT4 = 0,
    output reg CLKOUT5 = 0,
    output reg CLKOUT6 = 0,
    output reg CLKFBOUT = 0, output CLKFBOUTB,
    output reg LOCKED = 0,
    input  CLKIN1,
    input  PWRDWN,
    input  RST,
    input  CLKFBIN
);
    assign CLKOUT0B = ~CLKOUT0;
    assign CLKOUT1B = ~CLKOUT1;
    assign CLKOUT2B = ~CLKOUT2;
    assign CLKOUT3B = ~CLKOUT3;
    assign CLKFBOUTB = ~CLKFBOUT;

    // Measure the input period from two consecutive rising edges.
    time t_prev = 0, clkin_period = 0;
    always @(posedge CLKIN1) begin
        if (t_prev != 0 && clkin_period == 0)
            clkin_period = $time - t_prev;
        t_prev = $time;
    end

    real vco_period;
    // half-period of each output, in ps
    real h0, h1, h2, hfb;

    initial begin
        // wait until the input period is known, then start the outputs
        wait (clkin_period != 0);
        vco_period = (clkin_period * DIVCLK_DIVIDE) / CLKFBOUT_MULT_F;
        h0  = (vco_period * CLKOUT0_DIVIDE_F) / 2.0;
        h1  = (vco_period * CLKOUT1_DIVIDE)   / 2.0;
        h2  = (vco_period * CLKOUT2_DIVIDE)   / 2.0;
        hfb = (vco_period * 1)                / 2.0;
        // LOCKED after a few input cycles, as the real part does
        #(clkin_period * 20) LOCKED = 1'b1;
    end

    // Each output runs independently once the periods are known.
    always begin
        wait (h0 > 0); #(h0) CLKOUT0 = ~CLKOUT0;
    end
    always begin
        // CLKOUT1_PHASE of 90 degrees => quarter-period initial offset
        wait (h1 > 0);
        if (CLKOUT1 === 1'b0 && $time == 0) #(h1 * CLKOUT1_PHASE / 180.0);
        #(h1) CLKOUT1 = ~CLKOUT1;
    end
    always begin
        wait (h2 > 0); #(h2) CLKOUT2 = ~CLKOUT2;
    end
    always begin
        wait (hfb > 0); #(hfb) CLKFBOUT = ~CLKFBOUT;
    end

    always @(posedge RST) begin
        LOCKED = 1'b0;
        @(negedge RST);
        #(clkin_period * 20) LOCKED = 1'b1;
    end
endmodule
