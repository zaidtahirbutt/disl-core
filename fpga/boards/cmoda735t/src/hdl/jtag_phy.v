module jtag_phy(
	output tap_reset,
	output tap_idle,
	output tap_capture,
	output tap_update,
	output bscan_tck,
	output bscan_tdi,
	input bscan_tdo,
	output data_valid
);
parameter JTAG_USER_REG_ID = 4;
wire shift;
wire sel;
assign data_valid = shift&sel;

BSCANE2 #(
    .JTAG_CHAIN(JTAG_USER_REG_ID) // Value for USER command.
)
bse2_inst (
    .CAPTURE(tap_capture), // 1-bit output: CAPTURE output from TAP controller.
    .DRCK(), // 1-bit output: Gated TCK output. When SEL is asserted, DRCK toggles when CAPTURE or SHIFT are asserted.
    .RESET(tap_reset), // 1-bit output: Reset output for TAP controller.
    .RUNTEST(tap_idle), // 1-bit output: Output asserted when TAP controller is in Run Test/Idle state.
    .SEL(sel), // 1-bit output: USER instruction active output.
    .SHIFT(shift), // 1-bit output: SHIFT output from TAP controller.
    .TCK(bscan_tck), // 1-bit output: Test Clock output. Fabric connection to TAP Clock pin.
    .TDI(bscan_tdi), // 1-bit output: Test Data Input (TDI) output from TAP controller.
    .TMS(bascan_tms), // 1-bit output: Test Mode Select output. Fabric connection to TAP.
    .UPDATE(tap_update), // 1-bit output: UPDATE output from TAP controller
    .TDO(bscan_tdo) // 1-bit input: Test Data Output (TDO) input for USER function.
);
endmodule
