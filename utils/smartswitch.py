import json
import math
import os
import sys

# make log2blocks a function of max ID value

config_dir = sys.argv[1] 
build_dir = sys.argv[2]


with open(os.getcwd() + config_dir + "/ss_config.json") as f:
    config = json.load(f)

with open(os.getcwd() + config_dir + "/ss_protocol_map.json") as f:
    protocol_map = json.load(f)

SS = {}
SS["IO"] = {"I": {"clk": 1, "rst": 1}, "O": {}}
SS["Wires"] = {}
SS["Regs"] = {}
SS["MUXs"] = {}
SS["DISLPorts"] = {}
SS["Expr"] = []
    
blocks = list(config["IDs"].keys())
log2blocks = math.ceil(math.log2(len(blocks)))

# Define module IOs
for block in blocks:
    interfaces = config["Interfaces"][block]
    for interface in interfaces:
        name = block + "_" + str(interface["ID"]) + "_"
        direction = interface["Direction"]
        protocol = protocol_map[interface["Type"]]
        for signal in protocol["Signals"].keys():
            SS["IO"][protocol["Signals"][signal]["Direction"][direction]][name + signal ] = protocol["Signals"][signal]["Size"]


# Define DISL ports
for block in blocks:
    interfaces = config["Interfaces"][block]
    for interface in interfaces:
        name = block + "_" + str(interface["ID"]) + "_"
        protocol = protocol_map[interface["Type"]]
        direction = interface["Direction"]
        groups = interface["Groups"]
        ports = protocol[direction]
        oports = ports["oPorts"]
        iports = ports["iPorts"]
        for port in oports:
            frame_size = 0
            for f in port["frame"]:
                if f in protocol["Signals"].keys():
                    frame_size += protocol["Signals"][f]["Size"]
                else:
                    frame_size += ports["Signals"][f]
            port_name = name + port["type"]
            SS["DISLPorts"][port_name] = {"Config": {"Type": "o"}, "IOMap":{"clk":"clk", "rst":"rst"}}
            SS["DISLPorts"][port_name]["Config"]["NodeName"] = name[:-1]
            SS["DISLPorts"][port_name]["Config"]["PortName"] = "_" + port["type"]
            SS["DISLPorts"][port_name]["Config"]["ADDR_SIZE"] = log2blocks
            SS["DISLPorts"][port_name]["Config"]["FRAME_SIZE"] = frame_size
            SS["DISLPorts"][port_name]["Config"]["Groups"] = []
            if port["frame"]:
                SS["DISLPorts"][port_name]["IOMap"]["iframe"] = "{" 
                for f in port["frame"]:
                    SS["DISLPorts"][port_name]["IOMap"]["iframe"] += (name+f+",")
                SS["DISLPorts"][port_name]["IOMap"]["iframe"]= SS["DISLPorts"][port_name]["IOMap"]["iframe"][:-1] + "}" 
            else:
                SS["DISLPorts"][port_name]["IOMap"]["iframe"] = "" 
            SS["DISLPorts"][port_name]["IOMap"]["iaddr"] = ""
            SS["DISLPorts"][port_name]["IOMap"]["ivalid"] = "" if not port["valid"] else name + port["valid"]
            SS["DISLPorts"][port_name]["IOMap"]["oready"] = "" if not port["ready"] else name + port["ready"]
            for num in range(groups):
                 SS["DISLPorts"][port_name]["IOMap"]["g" + str(num) + "iaddress_map"] = ""
                 SS["DISLPorts"][port_name]["IOMap"]["g" + str(num) + "oframes"] = ""
                 SS["DISLPorts"][port_name]["IOMap"]["g" + str(num) + "ovalid"] = ""
                 SS["DISLPorts"][port_name]["IOMap"]["g" + str(num) + "iack"] = ""
        for port in iports:
            frame_size = 0
            for f in port["frame"]:
                if f in protocol["Signals"].keys():
                    frame_size += protocol["Signals"][f]["Size"]
                else:
                    frame_size += ports["Signals"][f]
            port_name = name + port["type"]
            SS["DISLPorts"][port_name] = {"Config": {"Type": "i"}, "IOMap":{"clk":"clk", "rst":"rst"}}
            SS["DISLPorts"][port_name]["Config"]["NodeName"] = name[:-1]
            SS["DISLPorts"][port_name]["Config"]["PortName"] = "_" + port["type"]
            SS["DISLPorts"][port_name]["Config"]["ADDR_SIZE"] = log2blocks
            SS["DISLPorts"][port_name]["Config"]["FRAME_SIZE"] = frame_size
            SS["DISLPorts"][port_name]["Config"]["Groups"] = []
            if port["frame"]:
                SS["DISLPorts"][port_name]["IOMap"]["oframe"] = "{" 
                for f in port["frame"]:
                    SS["DISLPorts"][port_name]["IOMap"]["oframe"] += (name+f+",")
                SS["DISLPorts"][port_name]["IOMap"]["oframe"]= SS["DISLPorts"][port_name]["IOMap"]["oframe"][:-1] + "}" 
            else:
                SS["DISLPorts"][port_name]["IOMap"]["oframe"] = "" 
            SS["DISLPorts"][port_name]["IOMap"]["oaddr"] = ""
            SS["DISLPorts"][port_name]["IOMap"]["ovalid"] = "" if not port["valid"] else name + port["valid"]
            SS["DISLPorts"][port_name]["IOMap"]["iready"] = "" if not port["ready"] else name + port["ready"]
            for num in range(groups):
                 SS["DISLPorts"][port_name]["IOMap"]["g" + str(num) + "iaddress_map"] = ""
                 SS["DISLPorts"][port_name]["IOMap"]["g" + str(num) + "iframes"] = ""
                 SS["DISLPorts"][port_name]["IOMap"]["g" + str(num) + "ivalid"] = ""
                 SS["DISLPorts"][port_name]["IOMap"]["g" + str(num) + "oack"] = ""


# Define Groups for each port
for dislport in SS["DISLPorts"]:
    block = dislport.split("_")[0]
    interface_id = int(dislport.split("_")[1])
    policy = config["Arbitration"][block]
    groups = 0
    direction = ""
    interfaces = config["Interfaces"][block]
    for interface in interfaces:
        if interface["ID"] == interface_id:
            groups = interface["Groups"]
            direction = interface["Direction"]
            break
    for g in range(groups):
        size = 0
        for conn in config["Connectivity"]:
            port = conn[direction]
            if (port["Component"] == block) and (port["ID"]==interface_id) and (port["Group"]==g):
                size += 1
        SS["DISLPorts"][dislport]["Config"]["Groups"].append({"Size": size, "Policy": "\"" + policy + "\""})


# Connect all Sources to wires - assume one source can connect to one sink at a time
# also assume the order of connectivity listing is the address order
for block in blocks:
    interfaces = config["Interfaces"][block]
    for interface in interfaces:
        if interface["Direction"] == "Sink": continue
        interface_id = interface["ID"]
        protocol = protocol_map[interface["Type"]]
        direction = interface["Direction"]
        groups = interface["Groups"]
        for g in range(groups):
            sinks = []
            for conn in config["Connectivity"]:
                port = conn["Source"]
                if (port["Component"] == block) and (port["ID"]==interface_id) and (port["Group"]==g):
                    sinks.append(conn["Sink"])
            address_map = []
            for sink in sinks:
                address_map.append(config["IDs"][sink["Component"]])
            address_map.reverse()
            address_map_str = "{" +   ",".join([(str(log2blocks) + "'d" + str(x)) for x in address_map]) + "}"
            for dislport in SS["DISLPorts"]:
                if SS["DISLPorts"][dislport]["Config"]["NodeName"] == (block + "_" + str(interface_id)):
                    SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "iaddress_map"] = address_map_str
                    if SS["DISLPorts"][dislport]["Config"]["Type"] == 'o': 
                        frame_wire_name = dislport + "_" + "g" + str(g) + "oframes"
                        frame_wire_size = SS["DISLPorts"][dislport]["Config"]["FRAME_SIZE"]
                        valid_wire_name = dislport + "_" + "g" + str(g) + "ovalid"
                        ready_wire_name = dislport + "_" + "g" + str(g) + "iack"
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "oframes"] = frame_wire_name
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "ovalid"] =  valid_wire_name
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "iack"] =  ready_wire_name
                        SS['Wires'][frame_wire_name] = frame_wire_size * SS["DISLPorts"][dislport]["Config"]["Groups"][g]["Size"]
                        SS['Wires'][valid_wire_name] = SS["DISLPorts"][dislport]["Config"]["Groups"][g]["Size"]
                        SS['Wires'][ready_wire_name] = SS["DISLPorts"][dislport]["Config"]["Groups"][g]["Size"]
                    else: 
                        frame_wire_name = dislport + "_" + "g" + str(g) + "iframes"
                        frame_wire_size = SS["DISLPorts"][dislport]["Config"]["FRAME_SIZE"]
                        valid_wire_name = dislport + "_" + "g" + str(g) + "ivalid"
                        ready_wire_name = dislport + "_" + "g" + str(g) + "oack"
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "iframes"] = frame_wire_name
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "ivalid"] =  valid_wire_name
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "oack"] =  ready_wire_name
                        SS['Wires'][frame_wire_name] = frame_wire_size * SS["DISLPorts"][dislport]["Config"]["Groups"][g]["Size"]
                        SS['Wires'][valid_wire_name] = SS["DISLPorts"][dislport]["Config"]["Groups"][g]["Size"]
                        SS['Wires'][ready_wire_name] = SS["DISLPorts"][dislport]["Config"]["Groups"][g]["Size"]


# Connect all sinks to wires - assume one source can connect to one sink at a time
# Also assume each sink is connected to a single interface of any given source 
for block in blocks:
    interfaces = config["Interfaces"][block]
    blockID = config["IDs"][block]
    for interface in interfaces:
        if interface["Direction"] == "Source": continue
        interface_id = interface["ID"]
        protocol = protocol_map[interface["Type"]]
        direction = interface["Direction"]
        groups = interface["Groups"]
        for g in range(groups):
            sources = []
            for conn in config["Connectivity"]:
                port = conn["Sink"]
                if (port["Component"] == block) and (port["ID"]==interface_id) and (port["Group"]==g):
                    sources.append(conn["Source"])
            sources.reverse()
            address_map = []
            for source in sources:
                address_map.append(config["IDs"][source["Component"]])
            address_map_str = "{" +   ",".join([(str(log2blocks) + "'d" + str(x)) for x in address_map]) + "}"
            for dislport in SS["DISLPorts"]:
                if SS["DISLPorts"][dislport]["Config"]["NodeName"] == (block + "_" + str(interface_id)):
                    SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "iaddress_map"] = address_map_str
                    if SS["DISLPorts"][dislport]["Config"]["Type"] == 'o':
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "oframes"] = "{"
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "ovalid"] = "{"
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "iack"] = "{"
                    else:
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "iframes"] = "{"
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "ivalid"] = "{"
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "oack"] = "{"
            for source in sources:
                for dislport in SS["DISLPorts"]:
                    if SS["DISLPorts"][dislport]["Config"]["NodeName"] == (source["Component"] + "_" + str(source["ID"])):
                        for g2 in range(len(SS["DISLPorts"][dislport]["Config"]["Groups"])):
                            source_addr_map = SS["DISLPorts"][dislport]["IOMap"]["g" + str(g2) + "iaddress_map"].split(",")
                            source_addr_map_ints = []
                            for addr in source_addr_map:
                                source_addr_map_ints.append(int(addr.split("'d")[1].split("}")[0]))
                            if blockID not in source_addr_map_ints:
                                continue
                            source_addr_map_ints.reverse()
                            index = source_addr_map_ints.index(blockID)
                            sinkdislport = block + "_" + str(interface_id) + SS["DISLPorts"][dislport]["Config"]["PortName"]
                            if SS["DISLPorts"][sinkdislport]["Config"]["Type"] == 'o':
                                frame_wire_name = dislport + "_" + "g" + str(g2) + "iframes"
                                frame_wire_size = SS["DISLPorts"][dislport]["Config"]["FRAME_SIZE"]
                                valid_wire_name = dislport + "_" + "g" + str(g2) + "ivalid"
                                ready_wire_name = dislport + "_" + "g" + str(g2) + "oack"
                                SS["DISLPorts"][sinkdislport]["IOMap"]["g" + str(g) + "oframes"] += frame_wire_name + "[" + str(index*frame_wire_size) + "+:" + str(frame_wire_size) + "],"
                                SS["DISLPorts"][sinkdislport]["IOMap"]["g" + str(g) + "ovalid"] +=  valid_wire_name + "[" + str(index) + "],"
                                SS["DISLPorts"][sinkdislport]["IOMap"]["g" + str(g) + "iack"] +=  ready_wire_name + "[" + str(index) + "],"
                            else:
                                frame_wire_name = dislport + "_" + "g" + str(g2) + "oframes"
                                frame_wire_size = SS["DISLPorts"][dislport]["Config"]["FRAME_SIZE"]
                                valid_wire_name = dislport + "_" + "g" + str(g2) + "ovalid"
                                ready_wire_name = dislport + "_" + "g" + str(g2) + "iack"
                                SS["DISLPorts"][sinkdislport]["IOMap"]["g" + str(g) + "iframes"] += frame_wire_name + "[" + str(index*frame_wire_size) + "+:" + str(frame_wire_size) + "],"
                                SS["DISLPorts"][sinkdislport]["IOMap"]["g" + str(g) + "ivalid"] +=  valid_wire_name + "[" + str(index) + "],"
                                SS["DISLPorts"][sinkdislport]["IOMap"]["g" + str(g) + "oack"] +=  ready_wire_name + "[" + str(index) + "],"
            for dislport in SS["DISLPorts"]:
                if SS["DISLPorts"][dislport]["Config"]["NodeName"] == (block + "_" + str(interface_id)):
                    if SS["DISLPorts"][dislport]["Config"]["Type"] == 'o':
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "oframes"] = SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "oframes"][:-1] + "}"
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "ovalid"] = SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "ovalid"][:-1] + "}"
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "iack"] = SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "iack"][:-1] + "}"
                    else:
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "iframes"] = SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "iframes"][:-1] + "}"
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "ivalid"] = SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "ivalid"][:-1] + "}"
                        SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "oack"] = SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "oack"][:-1] + "}"



# Add iaddr and oaddr connections using Muxes and module ports

# group scheme
# if Groups > 1, add group sel to module inputs

#iaddr scheme
# Groups = 1, Size = 1 -> hardwire iaddr to address of connected block
# Groups = 1, Size > 1 -> add iaddr to module inputs 
#oaddr scheme
# Groups = 1, Size = 1 -> add oaddr to module outputs
# Groups = 1, Size > 1 -> add oaddr to module outputs 


#iaddr scheme
# Groups > 1, Size = 1 -> create mux with hardwired inputs and group sel as select
# Groups > 1, Size > 1 -> add iaddr to module inputs 
#oaddr scheme
# Groups > 1, Size = 1 -> add oaddr to module outputs
# Groups > 1, Size > 1 -> add oaddr to module outputs 


for block in blocks:
    interfaces = config["Interfaces"][block]
    blockID = config["IDs"][block]
    for interface in interfaces:
        interface_id = interface["ID"]
        groups = interface["Groups"]
        sel_name = "0"
        if groups > 1:
            log2groups = math.ceil(math.log2(groups))
            sel_name = block + "_" + str(interface_id) + "_group_select"
            SS["IO"]["I"][sel_name] = log2groups
        for dislport in SS["DISLPorts"]:
            if SS["DISLPorts"][dislport]["Config"]["NodeName"] == (block + "_" + str(interface_id)):
                SS["DISLPorts"][dislport]["IOMap"]["select"] = sel_name
                if SS["DISLPorts"][dislport]["Config"]["Type"] == 'i':
                            addr_name = dislport + "_" + "oaddr"
                            SS["IO"]["O"][addr_name] =  SS["DISLPorts"][dislport]["Config"]["ADDR_SIZE"]
                            SS["DISLPorts"][dislport]["IOMap"]["oaddr"] = addr_name
                elif (groups == 1):
                    size = SS["DISLPorts"][dislport]["Config"]["Groups"][0]["Size"]
                    if (size == 1):
                        addr_name = SS["DISLPorts"][dislport]["IOMap"]["g0iaddress_map"]
                        SS["DISLPorts"][dislport]["IOMap"]["iaddr"] = addr_name
                    else:
                        addr_name = dislport + "_" + "iaddr"
                        SS["IO"]["I"][addr_name] =  SS["DISLPorts"][dislport]["Config"]["ADDR_SIZE"]
                        SS["DISLPorts"][dislport]["IOMap"]["iaddr"] = addr_name
                elif (groups > 1):
                    s = 1
                    for g in range(groups):
                        size = SS["DISLPorts"][dislport]["Config"]["Groups"][g]["Size"]
                        if size > 1:
                            s = size 
                            break
                    if s == 1: 
                        addr_name = dislport + "_" + "addrmux"
                        SS["Wires"][addr_name] =  SS["DISLPorts"][dislport]["Config"]["ADDR_SIZE"]
                        inputs = []
                        mux = {"SIZE":  SS["DISLPorts"][dislport]["Config"]["ADDR_SIZE"], "sel": sel_name, "o": addr_name, "i": [] }
                        for g in range(groups):
                            mux["i"].append(SS["DISLPorts"][dislport]["IOMap"]["g" + str(g) + "iaddress_map"])
                        SS["DISLPorts"][dislport]["IOMap"]["iaddr"] = addr_name
                        SS["MUXs"][addr_name] = mux
                    else:
                        addr_name = dislport + "_" + "iaddr"
                        SS["IO"]["I"][addr_name] =  SS["DISLPorts"][dislport]["Config"]["ADDR_SIZE"]
                        SS["DISLPorts"][dislport]["IOMap"]["iaddr"] = addr_name


for block in blocks:
    interfaces = config["Interfaces"][block]
    for interface in interfaces:
        name = block + "_" + str(interface["ID"]) + "_"
        protocol = protocol_map[interface["Type"]]
        ports = protocol[interface["Direction"]]
        if "Signals"  in ports.keys():
            for signal in ports["Signals"].keys():
                SS['Wires'][name + signal] = ports["Signals"][signal]
        if "Regs"  in ports.keys():
            for reg in ports["Regs"].keys():
                SS['Regs'][name + reg] = ports["Regs"][reg]
        if "Expr" not in ports.keys(): continue
        for expr in ports["Expr"]:
            code = ""
            for frag in expr:
                if "Signals"  in ports.keys():
                    if frag in ports["Signals"].keys():
                        code += name+frag
                        code += " "
                        continue
                if "Regs" in ports.keys():
                    if frag in ports["Regs"].keys():
                        code += name+frag
                        code += " "
                        continue
                if frag in protocol["Signals"].keys():
                    code += name+frag
                    code += " "
                    continue
                code += frag
                code += " "
            SS["Expr"].append(code)




configs = []
for dislport in SS["DISLPorts"]:
    configs.append(SS["DISLPorts"][dislport]["Config"])

for config in configs:
    modulename = f"""DISL{config["Type"]}Port_{config["NodeName"]}{config["PortName"]}""";
    num_groups = len(config["Groups"])
    
    if (config["Type"] == "i"):
        with open(os.getcwd()  + build_dir +"/" + modulename + ".v",'w') as f:
            f.write("/*\n")
            f.write("Automatically generated file - Do not modify!\n")
            f.write("Generated using: cd <smart_switch_repo_dir>/tests/<test> && python ../../smart_switch/generator/port.py\n")
            f.write("*/\n\n\n")
            f.write(f"module {modulename}(\n")
            f.write("clk,\n")
            f.write("rst,\n")
            f.write("select,\n\n") 

            for g in range(num_groups):
                f.write(f"g{g}iaddress_map,\n")
                f.write(f"g{g}iframes,\n")
                f.write(f"g{g}ivalid,\n")
                f.write(f"g{g}oack,\n\n")

            f.write("oframe,\n")
            f.write("oaddr,\n")
            f.write("ovalid,\n")
            f.write("iready\n")
            f.write(");\n\n")


            for g in range(num_groups):
                f.write(f"""parameter GROUP{g}SIZE = {config["Groups"][g]["Size"]};\n""")
                f.write(f"""parameter GROUP{g}ARBPOLICY = {config["Groups"][g]["Policy"]};\n""")

            f.write(f"""parameter ADDR_SIZE = {config["ADDR_SIZE"]};\n""")
            f.write(f"""parameter FRAME_SIZE = {config["FRAME_SIZE"]};\n\n""")


            f.write("input clk;\n")
            f.write("input rst;\n")
            if math.ceil(math.log2(num_groups)) > 1:
                f.write(f"input [{math.ceil(math.log2(num_groups))-1}:0] select;\n\n")
            else:
                f.write(f"input [0:0] select;\n\n")


            for g in range(num_groups):
                f.write(f"input [(GROUP{g}SIZE*ADDR_SIZE)-1:0] g{g}iaddress_map;\n")
                f.write(f"input [(GROUP{g}SIZE*FRAME_SIZE)-1:0] g{g}iframes;\n")
                f.write(f"input [GROUP{g}SIZE-1:0] g{g}ivalid;\n")
                f.write(f"output [GROUP{g}SIZE-1:0] g{g}oack;\n\n")

            f.write("output reg [FRAME_SIZE-1:0] oframe;\n")
            f.write("output reg [ADDR_SIZE-1:0] oaddr;\n")
            f.write("output reg ovalid;\n")
            f.write("input iready;\n\n")

            for g in range(num_groups):
                f.write(f"wire [FRAME_SIZE-1:0] g{g}oframe;\n")
                f.write(f"wire [ADDR_SIZE-1:0] g{g}oaddr;\n")
                f.write(f"wire g{g}ovalid;\n")


            f.write("always @(*) begin\n")
            for g in range(num_groups):
                if (g):
                    f.write(f"  end else if (select == {g}) begin\n")
                else:
                    f.write(f"  if (select == {g}) begin\n")
                f.write(f"      oframe = g{g}oframe;\n")
                f.write(f"      oaddr = g{g}oaddr;\n")
                f.write(f"      ovalid = g{g}ovalid;\n")
                    
                    
            f.write(f"  end else begin\n")
            f.write("       oframe = 0;\n");
            f.write("       oaddr = 0;\n");
            f.write("       ovalid = 0;\n");
            f.write("   end\n")
            f.write("end\n\n")


            f.write("generate\n") 
            for g in range(num_groups):
                f.write(f"if (GROUP{g}SIZE == 1) begin\n")
                f.write(f"  assign g{g}oframe = g{g}iframes;\n")
                f.write(f"  assign g{g}oaddr = g{g}iaddress_map;\n")
                f.write(f"  assign g{g}ovalid = g{g}ivalid;\n")
                f.write(f"  assign g{g}oack = (select == {g}) ? iready : 0;\n")

                f.write(f"end else if (GROUP{g}SIZE) begin\n")
                f.write(f"  wire [GROUP{g}SIZE-1:0] g{g}sel;\n")
                f.write(f"  {modulename}_{g}_Arbiter  Group{g}Arbitration(\n")
                f.write(f"  .clk(clk),\n")
                f.write(f"  .rst(rst),\n")
                f.write(f"  .stall(iready==0),\n")
                f.write(f"  .request(g{g}ivalid),\n")
                f.write(f"  .select(g{g}sel)\n")
                f.write(f"  );\n")
                f.write(f"  OHEMux  #(.REGISTERED(0), .NUM_INPUTS(GROUP{g}SIZE), .DATA_SIZE(FRAME_SIZE))    Group{g}FrameMux(\n")
                f.write(f"  .clk(clk),\n")
                f.write(f"  .rst(rst),\n")
                f.write(f"  .sel(g{g}sel),\n")
                f.write(f"  .in(g{g}iframes),\n")
                f.write(f"  .out(g{g}oframe)\n")
                f.write(f"  );\n")
                f.write(f"  OHEMux  #(.REGISTERED(0), .NUM_INPUTS(GROUP{g}SIZE), .DATA_SIZE(ADDR_SIZE)) Group{g}AddrMux(\n")
                f.write(f"  .clk(clk),\n")
                f.write(f"  .rst(rst),\n")
                f.write(f"  .sel(g{g}sel),\n")
                f.write(f"  .in(g{g}iaddress_map),\n")
                f.write(f"  .out(g{g}oaddr)\n")
                f.write(f"  );\n")
                f.write(f"  OHEMux  #(.REGISTERED(0), .NUM_INPUTS(GROUP{g}SIZE), .DATA_SIZE(1)) Group{g}ValidMux(\n")
                f.write(f"  .clk(clk),\n")
                f.write(f"  .rst(rst),\n")
                f.write(f"  .sel(g{g}sel),\n")
                f.write(f"  .in(g{g}ivalid),\n")
                f.write(f"  .out(g{g}ovalid)\n")
                f.write(f"  );\n")
                f.write(f"  OHEDemux #(.NUM_OUTPUTS(GROUP{g}SIZE), .DATA_SIZE(1)) Group{g}ReadyDeMux(\n")
                f.write(f"  .clk(clk),\n")
                f.write(f"  .rst(rst),\n")
                f.write(f"  .sel(g{g}sel),\n")
                f.write(f"  .in((select == {g}) ? iready : 0),\n")
                f.write(f"  .out(g{g}oack)\n")
                f.write(f"  );\n")

                f.write(f"end   else begin\n")
                f.write(f"  assign g{g}oframe = 0;\n")
                f.write(f"  assign g{g}oaddr = 0;\n")
                f.write(f"  assign g{g}ovalid = 0;\n")
                f.write(f"end\n\n")

            f.write("endgenerate\n")
            f.write("endmodule\n\n\n")

            for g in range(num_groups):
                gsize = config["Groups"][g]["Size"]
                f.write(f"module {modulename}_{g}_Arbiter(\n")
                f.write(f"  input clk,\n")
                f.write(f"  input rst,\n")
                f.write(f"  input stall,\n")
                f.write(f"  input [{gsize-1}:0] request,\n")
                f.write(f"  output reg [{gsize-1}:0] select\n")
                f.write(f"  );\n\n")
                f.write(f" always @(*) begin\n")
                f.write(f"   if (rst)\n")
                f.write(f"     select = 0;\n")
                for s in range(gsize):
                    f.write(f" else if (request[{s}]) \n")
                    f.write(f"      select = (1 << {s}); \n")
                f.write(f" else\n")
                f.write(f"     select = 0;\n")
                f.write(f" end\n")
                f.write("endmodule\n")

    else:
        with open(os.getcwd()  + build_dir +"/" + modulename + ".v",'w') as f:
            f.write("/*\n")
            f.write("Automatically generated file - Do not modify!\n")
            f.write("Generated using: cd <smart_switch_repo_dir>/tests/<test> && python ../../smart_switch/generator/port.py\n")
            f.write("*/\n\n\n")
            f.write(f"module {modulename}(\n")
            f.write("clk,\n")
            f.write("rst,\n")
            f.write("select,\n\n") 

            for g in range(num_groups):
                f.write(f"g{g}iaddress_map,\n")
                f.write(f"g{g}oframes,\n")
                f.write(f"g{g}ovalid,\n")
                f.write(f"g{g}iack,\n\n")

            f.write("iframe,\n")
            f.write("iaddr,\n")
            f.write("ivalid,\n")
            f.write("oready\n")
            f.write(");\n\n")


            for g in range(num_groups):
                f.write(f"""parameter GROUP{g}SIZE = {config["Groups"][g]["Size"]};\n""")

            f.write(f"""parameter ADDR_SIZE = {config["ADDR_SIZE"]};\n""")
            f.write(f"""parameter FRAME_SIZE = {config["FRAME_SIZE"]};\n\n""")


            f.write("input clk;\n")
            f.write("input rst;\n")
            if math.ceil(math.log2(num_groups)) > 1:
                f.write(f"input [{math.ceil(math.log2(num_groups))-1}:0] select;\n\n")
            else:
                f.write(f"input [0:0] select;\n\n")


            for g in range(num_groups):
                f.write(f"input [(GROUP{g}SIZE*ADDR_SIZE)-1:0] g{g}iaddress_map;\n")
                f.write(f"output [(GROUP{g}SIZE*FRAME_SIZE)-1:0] g{g}oframes;\n")
                f.write(f"output [GROUP{g}SIZE-1:0] g{g}ovalid;\n")
                f.write(f"input [GROUP{g}SIZE-1:0] g{g}iack;\n\n")

            f.write("input [FRAME_SIZE-1:0] iframe;\n")
            f.write("input [ADDR_SIZE-1:0] iaddr;\n")
            f.write("input ivalid;\n")
            f.write("output reg  oready;\n\n")

            for g in range(num_groups):
                f.write(f"wire g{g}oack;\n")


            f.write("always @(*) begin\n")
            for g in range(num_groups):
                if (g):
                    f.write(f"  end else if (select == {g}) begin\n")
                else:
                    f.write(f"  if (select == {g}) begin\n")
                f.write(f"      oready = g{g}oack;\n")
                    
                    
            f.write(f"  end else begin\n")
            f.write("       oready = 0;\n");
            f.write("   end\n")
            f.write("end\n\n")


            f.write("generate\n") 
            for g in range(num_groups):
                f.write(f"if (GROUP{g}SIZE == 1) begin\n")
                f.write(f"  assign g{g}oframes = iframe;\n")
                f.write(f"  assign g{g}ovalid = ((select == {g}) && (iaddr == g{g}iaddress_map)) ? ivalid : 0;\n")
                f.write(f"  assign g{g}oack = (select == {g}) ? g{g}iack : 0;\n")

                f.write(f"end else if (GROUP{g}SIZE) begin\n")
                f.write(f"  reg [GROUP{g}SIZE-1:0] g{g}sel;\n")
                f.write(f"integer i{g};\n")
                f.write(f"always @(*) begin\n")
                f.write(f"for (i{g}=0;i{g}<GROUP{g}SIZE;i{g}=i{g}+1)\n")
                f.write(f"g{g}sel[i{g}] = (iaddr == g{g}iaddress_map[i{g}*ADDR_SIZE+:ADDR_SIZE]) ? 1'b1 : 1'b0; \n")
                f.write(f"end\n")

                f.write(f"OHEDemux #(.NUM_OUTPUTS(GROUP{g}SIZE), .DATA_SIZE(FRAME_SIZE)) Group{g}FrameDeMux(\n")
                f.write(f".clk(clk),\n")
                f.write(f".rst(rst),\n")
                f.write(f".sel(g{g}sel),\n")
                f.write(f".in(iframe),\n")
                f.write(f".out(g{g}oframes)\n")
                f.write(f");\n")
                f.write(f"OHEDemux #(.NUM_OUTPUTS(GROUP{g}SIZE), .DATA_SIZE(1)) Group{g}ValidDeMux(\n")
                f.write(f".clk(clk),\n")
                f.write(f".rst(rst),\n")
                f.write(f".sel(g{g}sel),\n")
                f.write(f".in((select == {g}) ? ivalid : 0),\n")
                f.write(f".out(g{g}ovalid)\n")
                f.write(f");\n")
                f.write(f"OHEMux    #(.REGISTERED(0), .NUM_INPUTS(GROUP{g}SIZE), .DATA_SIZE(1)) Group{g}AckMux(\n")
                f.write(f".clk(clk),\n")
                f.write(f".rst(rst),\n")
                f.write(f".sel(g{g}sel),\n")
                f.write(f".in((select == {g}) ? g{g}iack : 0),\n")
                f.write(f".out(g{g}oack)\n")
                f.write(f");\n")


                f.write(f"end   else begin\n")
                f.write(f"  assign g{g}oframes = 0;\n")
                f.write(f"  assign g{g}ovalid= 0;\n")
                f.write(f"  assign g{g}oack = 0;\n")
                f.write(f"end\n\n")

            f.write("endgenerate\n")
            f.write("endmodule\n")



with open(os.getcwd() + build_dir +"/smartswitch.v", "w") as f:
    f.write("/*\n")
    f.write("Automatically generated file - Do not modify!\n")
    f.write("Generated using: cd <smart_switch_repo_dir>/tests/<test> && python ../../smart_switch/generator/instantiate.py\n")
    f.write("*/\n\n\n")
    f.write("module smart_switch( \n")
    for i in SS["IO"]["I"]:
        f.write(f"""input [{SS["IO"]["I"][i]-1}:0] {i},\n""")
    last_output = list(SS["IO"]["O"].keys())[-1]
    for o in SS["IO"]["O"]:
        if o == last_output:
            f.write(f"""output [{SS["IO"]["O"][o]-1}:0] {o});\n\n\n""")
        else:
            f.write(f"""output [{SS["IO"]["O"][o]-1}:0] {o},\n""")


    for wire in SS["Wires"]:
        f.write(f"""wire [{SS["Wires"][wire]-1}:0] {wire};\n""")
    f.write("\n\n")

    for reg in SS["Regs"]:
        f.write(f"""reg [{SS["Regs"][reg]-1}:0] {reg};\n""")
    f.write("\n\n")

    for mux in SS["MUXs"]:
        num_inputs = len(SS["MUXs"][mux]["i"])
        size = SS["MUXs"][mux]["SIZE"]
        inputs = SS["MUXs"][mux]["i"]
        inputs.reverse()
        inputs_str = ",".join(inputs)
        inputs_str = "{" + inputs_str + "}"
        f.write(f"""SimpleMux #(.SIZE({size}), .INPUTS({num_inputs}), .SEL({SS["IO"]["I"][SS["MUXs"][mux]["sel"]]})) uut_{mux} (.s({SS["MUXs"][mux]["sel"]}), .o({mux}), .i({inputs_str}));\n""")
    f.write("\n\n")

    for expr in SS["Expr"]:
        f.write(f"""{expr}\n""")
    f.write("\n\n")


    for dislport in SS["DISLPorts"]:
        config = SS["DISLPorts"][dislport]["Config"]
        modulename = f"""DISL{config["Type"]}Port_{config["NodeName"]}{config["PortName"]}""";
        instname = "uut_" + modulename
        last_port = list(SS["DISLPorts"][dislport]["IOMap"].keys())[-1]
        f.write(f"""  {modulename} {instname} (""")
        for port in SS["DISLPorts"][dislport]["IOMap"]:
            if (last_port == port):
                f.write(f""".{port}({SS["DISLPorts"][dislport]["IOMap"][port]}));\n""")
            else:
                f.write(f""".{port}({SS["DISLPorts"][dislport]["IOMap"][port]}),""")

    f.write("\n\nendmodule\n\n")


    f.write("""/*""")
    f.write("\n")
    f.write("smart_switch SS(\n")
    for i in SS["IO"]["I"]:
        f.write(f""".{i}(),\n""")
    last_output = list(SS["IO"]["O"].keys())[-1]
    for o in SS["IO"]["O"]:
        if o == last_output:
            f.write(f""".{o}());\n\n""")
        else:
            f.write(f""".{o}(),\n""")
    f.write("""*/""")