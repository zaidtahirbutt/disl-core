# Cooldown support to be added


import json
import sys
import os

config_dir = sys.argv[1] 
build_dir = sys.argv[2]

with open(os.getcwd() + config_dir + "/interrupt.json") as f:
	config = json.load(f)


code = []
code.append("module interrupt(\n")
for sink in config.keys():
	# Generate AXIMM interface for the sink to read handler FSM status, active interrupts etc
	code.append(f"\tinput [31:0] {sink}_axi_araddr,\n")
	code.append(f"\tinput {sink}_axi_arvalid,\n")
	code.append(f"\toutput reg {sink}_axi_arready,\n")
	code.append(f"\tinput [31:0] {sink}_axi_awaddr,\n")
	code.append(f"\tinput {sink}_axi_awvalid,\n")
	code.append(f"\toutput {sink}_axi_awready,\n")
	code.append(f"\toutput [31:0] {sink}_axi_rdata,\n")
	code.append(f"\toutput reg {sink}_axi_rvalid,\n")
	code.append(f"\tinput {sink}_axi_rready,\n")
	code.append(f"\tinput [31:0] {sink}_axi_wdata,\n")
	code.append(f"\tinput [3:0] {sink}_axi_wstrb,\n")
	code.append(f"\tinput {sink}_axi_wvalid,\n")
	code.append(f"\toutput {sink}_axi_wready,\n")
	code.append(f"\tinput {sink}_b_ready,\n")
	code.append(f"\toutput reg {sink}_b_valid,\n")
	code.append(f"\toutput [1:0] {sink}_b_response,\n")
	# Generate interrupt signals from handler to sink
	code.append(f"\toutput reg b_{sink}_irq,\n")
	code.append(f"\tinput b_{sink}_processing,\n")
	# Generate interrupt signals from sink to handler. Each source-sink pair has its own I/O, even if the same source supplies to multiple sinks (due to the processing signal)
	for source in config[sink]["Sources"]:
		code.append(f"\tinput a_{source}_{sink}_irq,\n")
		code.append(f"\toutput a_{source}_{sink}_processing,\n")

	code.append(f"\tinput {sink}_rst,\n")

code.append("\tinput clk);\n\n")


for sink in config.keys():
	num_sources = str(len(config[sink]["Sources"]))
	cooldown = config[sink]["Cooldown"]
	code.append("//////////////// Code for " + sink + " ////////////////\n")
	code.append(f"\tassign {sink}_b_response = 0;\n\n")

	code.append(f"\talways @(posedge clk) begin\n")
	code.append(f"\t	if ({sink}_rst)\n")
	code.append(f"\t		{sink}_b_valid <= 0;\n")
	code.append(f"\t	else if ({sink}_axi_wvalid && {sink}_axi_wready)\n")
	code.append(f"\t		{sink}_b_valid <= 1;\n")
	code.append(f"\t	else if ({sink}_b_valid && {sink}_b_ready)\n")
	code.append(f"\t		{sink}_b_valid <= 0;\n")
	code.append(f"\tend   \n\n")

	code.append(f"\twire [{num_sources}-1:0] a_{sink}_irq;\n")
	code.append(f"\treg [{num_sources}-1:0] a_{sink}_processing;\n")

	list_irq = []
	list_processing = []
	for source in config[sink]["Sources"]:
		list_irq.append(f"a_{source}_{sink}_irq")
		list_processing.append(f"a_{source}_{sink}_processing")

	code.append("\tassign a_" + sink + "_irq = {" + ",".join(list_irq) + "};\n")
	code.append("\tassign {" + ",".join(list_processing) + "} = a_" + sink + "_processing;\n")

	code.append(f"\treg [{num_sources}-1:0] {sink}_next_irq;\n")
	code.append(f"\treg [{num_sources}-1:0]	{sink}_current_irq;\n")
	code.append(f"\treg [7:0] {sink}_handler_state;\n")
	code.append(f"\t\n")
	code.append(f"\t\n")
	code.append(f"\talways @(posedge clk) begin\n")
	code.append(f"\t	if ({sink}_rst) begin\n")
	code.append(f"\t		{sink}_handler_state <= 0;\n")
	code.append(f"\t		{sink}_current_irq <= 0;\n")
	code.append(f"\t		b_{sink}_irq <= 0;\n")
	code.append(f"\t		a_{sink}_processing <= 0;\n")
	code.append(f"\t		\n")
	code.append(f"\t	end else if (({sink}_handler_state == 0) && (a_{sink}_irq) && (!b_{sink}_processing)) begin\n")
	code.append(f"\t		{sink}_handler_state <= 1;\n")
	code.append(f"\t		{sink}_current_irq <= {sink}_next_irq;\n")
	code.append(f"\t		b_{sink}_irq <= 1'b1;\n")
	code.append(f"\t		a_{sink}_processing <= {sink}_next_irq;\n")
	code.append(f"\t	\n")
	code.append(f"\t	end else if ({sink}_handler_state == 8'd1) begin\n")
	code.append(f"\t		{sink}_handler_state <= 2;\n")
	code.append(f"\t		b_{sink}_irq <= 1'b0;\n")
	code.append(f"\t\n")
	code.append(f"\t	end else if ({sink}_handler_state == 8'd2) begin\n")
	code.append(f"\t		if (b_{sink}_processing) begin\n")
	code.append(f"\t			{sink}_handler_state <= 3;\n")
	code.append(f"\t			b_{sink}_irq <= 0;\n")
	code.append(f"\t		end\n")
	code.append(f"\t		\n")		
	code.append(f"\t	end else if ({sink}_handler_state == 8'd3) begin\n")
	code.append(f"\t		if (!b_{sink}_processing) begin\n")
	code.append(f"\t			if ({str(1 if cooldown else 0)})\n")
	code.append(f"\t				{sink}_handler_state <= 4;\n")
	code.append(f"\t			else \n")
	code.append(f"\t				{sink}_handler_state <= 0;\n")
	code.append(f"\t			a_{sink}_processing <= 0;\n")
	code.append(f"\t			{sink}_current_irq <= 0;\n")
	code.append(f"\t		end\n")
	code.append(f"\t	end else if ({sink}_handler_state > 8'd3 && {sink}_handler_state <= 8'd{str(3 + cooldown)}) begin\n")
	code.append(f"\t		if ({sink}_handler_state == 8'd{str(3 + cooldown)}) \n")
	code.append(f"\t			{sink}_handler_state <= 0;\n")
	code.append(f"\t		else \n")
	code.append(f"\t			{sink}_handler_state <= {sink}_handler_state + 8'd1;\n")
	code.append(f"\t	end\n")
	code.append(f"\tend\n\n")
	
	# currently only priority arbitration is supported
	if config[sink]["Arbitration"] == "Priority":
		code.append(f"\tinteger {sink}_i;\n")
		code.append(f"\talways @(*) begin\n")
		code.append(f"\t	{sink}_next_irq = 0;\n")
		code.append(f"\t	for ({sink}_i=0; {sink}_i<{num_sources};{sink}_i={sink}_i+1) begin\n")
		code.append(f"\t		{sink}_next_irq = a_{sink}_irq[{sink}_i]? (1 << {sink}_i) : {sink}_next_irq; \n")
		code.append(f"\t	end\n")
		code.append(f"\tend\n\n")
	
	code.append(f"\tassign  {sink}_axi_awready = 1;\n")
	code.append(f"\tassign  {sink}_axi_wready = 1;\n")
	code.append("\tassign " + sink + "_axi_rdata = {" + str(32- len(config[sink]["Sources"]) ) + "'d0," + sink + "_current_irq};\n\n")
	
	code.append(f"\talways @(posedge clk) begin\n")
	code.append(f"\t	if ({sink}_rst) begin\n")
	code.append(f"\t		{sink}_axi_arready <= 1;\n")
	code.append(f"\t		{sink}_axi_rvalid <= 0;\n")
	code.append(f"\t	end else if ({sink}_axi_arready && {sink}_axi_arvalid) begin\n")
	code.append(f"\t		{sink}_axi_arready <= 0;\n")
	code.append(f"\t		{sink}_axi_rvalid <= 1;\n")
	code.append(f"\t	end else if ({sink}_axi_rready && {sink}_axi_rvalid) begin\n")
	code.append(f"\t		{sink}_axi_arready <= 1;\n")
	code.append(f"\t		{sink}_axi_rvalid <= 0;\n")
	code.append(f"\t	end\n")
	code.append(f"\tend\n\n\n")
code.append("endmodule")


with open(os.getcwd() + build_dir + "/interrupt.v",'w') as f:
	f.writelines(code)