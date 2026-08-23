# Copyright (c) 2020 Alex Forencich
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
# COCOTB_HDL_TIMEUNIT = 1ps
COCOTB_HDL_TIMEPRECISION = 1ps

# DUT      = fpga_core
DUT      = top
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)

# PROJECT_NAME = edgetestbed_a100T4_sim
# PROJECT_NAME = edgetestbed_a100T5_sim
# PROJECT_NAME = edgetestbed_a100T6_sim
# PROJECT_NAME = edgetestbed_a100T7_sim
# PROJECT_NAME = edgetestbed_a100T8_sim
# PROJECT_NAME = edgetestbed_a100T9_sim
# PROJECT_NAME = edgetestbed_a100T10_sim
# PROJECT_NAME = edgetestbed_a100T11_sim
# PROJECT_NAME = edgetestbed_a100T13_sim
# PROJECT_NAME = edgetestbed_a100T14_sim_FROM_CODES1server_ExperimentalStuff
# PROJECT_NAME = edgetestbed_a100T15_sim_FROM_CODES1server_ExperimentalStuff
# PROJECT_NAME = edgetestbed_a100T16_sim_FROM_CODES1server_ExperimentalStuff
# PROJECT_NAME = edgetestbed_a100T17_sim_FROM_CODES1server_ExperimentalStuff
# PROJECT_NAME = edgetestbed_a100T18_sim_FROM_CODES1server_ExperimentalStuff
# PROJECT_NAME = edgetestbed_a100T19_sim_FROM_CODES1server_ExperimentalStuff
# PROJECT_NAME = edgetestbed_a100T20_sim_FROM_CODES1server_ExperimentalStuff
# PROJECT_NAME = edgetestbed_a100T21_sim
# PROJECT_NAME = edgetestbed_a100T22_sim
# PROJECT_NAME = edgetestbed_a100T23_sim
# PROJECT_NAME = edgetestbed_a100T24_sim
# PROJECT_NAME = edgetestbed_a100T25_sim
# PROJECT_NAME = edgetestbed_a100T26_sim
# PROJECT_NAME = edgetestbed_a100T27_sim
# PROJECT_NAME = edgetestbed_a100T28_sim_converted_to_syn_sim
# PROJECT_NAME = edgetestbed_a100T29_pgmLoader_cocotbsim_simv2
PROJECT_NAME = edgetestbed_a100T30_cocotbsim_sim


BUILD_DIR = ../../../../build/$(PROJECT_NAME)/build/
SMARTSWITCH_DIR = ../../../smartswitch_subsystem/hdl/
SOFTCORE_DIR = ../../../softcore_subsystem/riscv32i/hdl/
XILINX_UNISIM_DIR = /home/zaidtahir/XilinxUnisimLibrary/verilog/src/unisims/

VERILOG_SOURCES += ../../hdl/eth_nic_100m_mmi.v
VERILOG_SOURCES += ../../../../tests/$(PROJECT_NAME)/hdl/$(DUT).v
VERILOG_SOURCES += ../../../memory_subsystem/hdl/bram_axi_cachecontroller.v
VERILOG_SOURCES += ../../../memory_subsystem/hdl/softcore_memory_bus_grant.v
VERILOG_SOURCES += ../../../programmer_subsystem/hdl/progloader_axi.v
VERILOG_SOURCES += $(wildcard $(BUILD_DIR)/*.v)
VERILOG_SOURCES += $(wildcard $(BUILD_DIR)/*.vh)
VERILOG_SOURCES += $(wildcard $(SMARTSWITCH_DIR)/*.v)
VERILOG_SOURCES += $(wildcard $(SOFTCORE_DIR)/*.v)  # recursively add files
# VERILOG_SOURCES += $(wildcard $(XILINX_UNISIM_DIR)/*.v)  # recursively add files
# VERILOG_SOURCES += /home/zaidtahir/XilinxUnisimLibrary/verilog/src/unisims/BUFG.v
# VERILOG_SOURCES += /home/zaidtahir/XilinxUnisimLibrary/verilog/src/unisims//BUFIO.v
# VERILOG_SOURCES += /home/zaidtahir/XilinxUnisimLibrary/verilog/src/unisims//BUFR.v
# VERILOG_SOURCES += /home/zaidtahir/XilinxUnisimLibrary/verilog/src/glbl.v

# $(info $$VERILOG_SOURCES is [${VERILOG_SOURCES}])  # print stuff

# $(error error is nothing)  # break out of makefile

VERILOG_SOURCES += ../../hdl/lib/eth/rtl/eth_mac_mii_fifo.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/eth_mac_mii.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/ssio_sdr_in.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/mii_phy_if.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/eth_mac_1g.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/axis_gmii_rx.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/axis_gmii_tx.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/lfsr.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/eth_axis_rx.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/eth_axis_tx.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/udp_complete.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/udp_checksum_gen.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/udp.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/udp_ip_rx.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/udp_ip_tx.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/ip_complete.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/ip.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/ip_eth_rx.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/ip_eth_tx.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/ip_arb_mux.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/arp.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/arp_cache.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/arp_eth_rx.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/arp_eth_tx.v
VERILOG_SOURCES += ../../hdl/lib/eth/rtl/eth_arb_mux.v
VERILOG_SOURCES += ../../hdl/lib/axis/rtl/arbiter.v
VERILOG_SOURCES += ../../hdl/lib/axis/rtl/priority_encoder.v
VERILOG_SOURCES += ../../hdl/lib/axis/rtl/axis_fifo.v
VERILOG_SOURCES += ../../hdl/lib/axis/rtl/axis_async_fifo.v
VERILOG_SOURCES += ../../hdl/lib/axis/rtl/axis_async_fifo_adapter.v
VERILOG_SOURCES += ../../hdl/lib/axis/rtl/eth_fifo_axis_to_bram_axi.v
VERILOG_SOURCES += ../../hdl/lib/axis/rtl/perf_counter.v
VERILOG_SOURCES += ../../hdl/lib/axis/rtl/arbiter_z1.v
VERILOG_SOURCES += ../../hdl/lib/axis/rtl/priority_encoder_z1.v

VeBPF = cpu
VeBPF_Path = VeBPF/DISL_FPGA_eBPF/DISL_Verilog_eBPF

# Adding VeBPF files
VERILOG_SOURCES += ../../$(VeBPF_Path)/$(VeBPF).v
VERILOG_SOURCES += ../../$(VeBPF_Path)/divider.v
VERILOG_SOURCES += ../../$(VeBPF_Path)/call_handler.v
VERILOG_SOURCES += ../../$(VeBPF_Path)/shifter.v
# VERILOG_SOURCES += ../../$(VeBPF_Path)/ram_module_v1.v
# VERILOG_SOURCES += ../../$(VeBPF_Path)/ram_module_v2.v
VERILOG_SOURCES += ../../$(VeBPF_Path)/ram_module_v3.v
VERILOG_SOURCES += ../../$(VeBPF_Path)/ram64_memory_v1.v
VERILOG_SOURCES += ../../$(VeBPF_Path)/ram64_memory_v3.v
# VERILOG_SOURCES += ../../$(VeBPF_Path)/iverilog_dump.v
# VERILOG_SOURCES += ../../$(VeBPF_Path)/iverilog_dump_sv.sv

# module parameters
#export PARAM_A ?= value

ifeq ($(SIM), icarus)
	PLUSARGS += -fst
# 	PLUSARGS += -fst -pfileline=1
	# no change with this 
	
# 	PLUSARGS += -fst -d

#	COMPILE_ARGS += -P $(TOPLEVEL).A=$(PARAM_A)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

#	COMPILE_ARGS += -GA=$(PARAM_A)

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif
endif

# run make using the following flags for cocotb debugging
# make WAVES=1 COCOTB_SCHEDULER_DEBUG=1 COCOTB_ENABLE_PROFILING=1 COCOTB_LOG_LEVEL=DEBUG

# run make to generate waveforms only using following:
# make WAVES=1 

# if simulation file is not being updated or generated, I ran the following that solved that issue:
# make clean



# press "Ctrl+c" during simulation of icarus verilog console debugging and use commands like "cont", "finish", "step" etc
# finish: This finished the simulation causing the waveform to be generated which I am currently using to debug my FSMs although that 
# simulation waveform is limited till the time the cocotb simulation froze up

# COMPILE_ARGS += COCOTB_SCHEDULER_DEBUG

# COCOTB_LOG_LEVEL=DEBUG 
# COCOTB_SCHEDULER_DEBUG=1 

# COMPILE_ARGS += $(COCOTB_LOG_LEVEL)
# COMPILE_ARGS += $(COCOTB_SCHEDULER_DEBUG)

# PLUSARGS += $(COCOTB_LOG_LEVEL)
# PLUSARGS += $(COCOTB_SCHEDULER_DEBUG)

include $(shell cocotb-config --makefiles)/Makefile.sim

iverilog_dump.v:
	echo 'module iverilog_dump();' > $@
	echo 'initial begin' >> $@
	echo '    $$dumpfile("$(TOPLEVEL).fst");' >> $@
	echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	echo 'end' >> $@
	echo 'endmodule' >> $@

clean::
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst
