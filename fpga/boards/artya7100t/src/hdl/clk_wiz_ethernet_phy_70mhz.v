// 70 MHz variant of clk_wiz_ethernet_phy.
//
// Identical in structure to the 100 MHz version; only the system-clock output
// differs. It exists because the memory path (softcore -> bus arbiter ->
// bram_axi_cachecontroller_v2) needs ~10.15 ns of combinational settling and
// gets only HALF a clock, the cache controller being negedge-triggered. At
// 100 MHz that is a 5 ns budget and the design misses by ~5.3 ns; at 50 MHz the
// half-period is 10 ns and the design closes.
//
// The 25 MHz PHY reference output is unchanged -- 100 Mbit MII takes its own
// phy_rx_clk / phy_tx_clk from the PHY, so the system clock is free to move.
module clk_wiz_ethernet_phy_70mhz(
	input clk,
	output clk_70_mhz_out,
	output clk_25_mhz_out
	);

	clk_wiz_4 ethernet_phy_clock_generator_70mhz (
		.clk_in1(clk),                       // input 100 MHz board oscillator
		.clk_out2_70MHz(clk_70_mhz_out),     // system clock: cpu, memory subsystem, NIC
		.clk_out1_25Mhz(clk_25_mhz_out)      // 25 MHz reference out to the ethernet PHY
	);

endmodule
