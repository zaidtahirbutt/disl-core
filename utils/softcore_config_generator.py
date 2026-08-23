import json
import sys 
import os

def readfile(filename):   
    with open(filename) as f:
        file = json.load(f)
    return file

if (len(sys.argv) == 2):
    try:
        memory_map = readfile(f"./tests/{sys.argv[1]}/config/memory_map.json")
    except:
        memory_map = readfile("./subsystems/softcore_subsystem/riscv32i/config/memory_map.json")
else:
    memory_map = readfile("./subsystems/softcore_subsystem/riscv32i/config/memory_map.json")

verilog_header = []

for k in memory_map.keys():
    verilog_header.append("parameter " + k + "_START_ADDRESS = 32'h" + memory_map[k][0] + ";")
    verilog_header.append("parameter " + k + "_END_ADDRESS = 32'h" + memory_map[k][1] + ";")

        
with open(f'./build/{sys.argv[1]}/build/softcore_subsystem_config.vh', 'w') as f:
    for line in verilog_header:
        f.write("%s\n" % line)
        

 
address_map_header = []
for k in memory_map.keys():
    address_map_header.append("#define  " + k + "  0x" + memory_map[k][0])


        
with open(f'./build/{sys.argv[1]}/build/address_map.h', 'w') as f:
    for line in address_map_header:
        f.write("%s\n" % line)
