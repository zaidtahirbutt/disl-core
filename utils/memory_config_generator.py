import json
import math
import sys
import itertools 
import os

def readfile(filename):   
    with open(filename) as f:
        file = json.load(f)
    return file


if (len(sys.argv) == 2):
    try:
        parameter_dict = readfile(f"./tests/{sys.argv[1]}/config/parameter_dict.json")
    except:
        parameter_dict = readfile("./subsystems/memory_subsystem/config/parameter_dict.json")
    try:
        controller_parameters = readfile(f"./tests/{sys.argv[1]}/config/controller_parameters.json")
    except:
        controller_parameters = readfile("./subsystems/memory_subsystem/config/controller_parameters.json")
    try:
        command_format = readfile(f"./tests/{sys.argv[1]}/config/command_format.json")
    except:
        command_format = readfile("./subsystems/memory_subsystem/config/command_format.json")
    try:
        default_commands = readfile(f"./tests/{sys.argv[1]}/config/default_commands.json")
    except:
        default_commands = readfile("./subsystems/memory_subsystem/config/default_commands.json")
    try:
        macro_format = readfile(f"./tests/{sys.argv[1]}/config/macro_format.json")
    except:
        macro_format = readfile("./subsystems/memory_subsystem/config/macro_format.json")
    try:
        default_macros = readfile(f"./tests/{sys.argv[1]}/config/default_macros.json")
    except:
        default_macros = readfile("./subsystems/memory_subsystem/config/default_macros.json")
    try:
        default_runtime_rules = readfile(f"./tests/{sys.argv[1]}/config/default_runtime_rules.json")
    except:
        default_runtime_rules = readfile("./subsystems/memory_subsystem/config/default_runtime_rules.json")
    try:
        default_refresh_rules = readfile(f"./tests/{sys.argv[1]}/config/default_refresh_rules.json")
    except:
        default_refresh_rules = readfile("./subsystems/memory_subsystem/config/default_refresh_rules.json")
    try:
        default_arbitration_policy = readfile(f"./tests/{sys.argv[1]}/config/default_arbitration_policy.json")
    except:
        default_arbitration_policy = readfile("./subsystems/memory_subsystem/config/default_arbitration_policy.json")
    try:
        dev_cmd_bit_encoding = readfile(f"../tests/{sys.argv[1]}/config/dev_cmd_bit_encoding.json")
    except:
        dev_cmd_bit_encoding = readfile("./subsystems/memory_subsystem/config/dev_cmd_bit_encoding.json")
    try:
        timing = readfile(f"./tests/{sys.argv[1]}/config/timing.json")
    except:
        timing = readfile("./subsystems/memory_subsystem/config/timing.json")
    try:
        perftuner_parameters = readfile(f"./tests/{sys.argv[1]}/config/perftuner_parameters.json")
    except:
        perftuner_parameters = readfile("./subsystems/memory_subsystem/config/perftuner_parameters.json")
else:
    parameter_dict = readfile("./subsystems/memory_subsystem/config/parameter_dict.json")
    controller_parameters = readfile("./subsystems/memory_subsystem/config/controller_parameters.json")
    command_format = readfile("./subsystems/memory_subsystem/config/command_format.json")
    default_commands = readfile("./subsystems/memory_subsystem/config/default_commands.json")
    macro_format = readfile("./subsystems/memory_subsystem/config/macro_format.json")
    default_macros = readfile("./subsystems/memory_subsystem/config/default_macros.json")
    default_runtime_rules = readfile("./subsystems/memory_subsystem/config/default_runtime_rules.json")
    default_refresh_rules = readfile("./subsystems/memory_subsystem/config/default_refresh_rules.json")
    default_arbitration_policy = readfile("./subsystems/memory_subsystem/config/default_arbitration_policy.json")
    dev_cmd_bit_encoding = readfile("./subsystems/memory_subsystem/config/dev_cmd_bit_encoding.json")
    timing = readfile("./subsystems/memory_subsystem/config/timing.json")
    perftuner_parameters = readfile("./subsystems/memory_subsystem/config/perftuner_parameters.json")



#################################################################################################################################################

verilog_header = []

verilog_header.append("parameter DEV_CLK = " + str(int(1000000/controller_parameters["tCK"])) + ";")
verilog_header.append("parameter UI_CLK = " + str(int(1000000/(controller_parameters["CLOCK_RATIO"] * controller_parameters["tCK"]))) + ";")
verilog_header.append("parameter SLOT_BITS = " + str(int(math.log2(controller_parameters["CLOCK_RATIO"]))) + ";")
verilog_header.append("parameter NUM_SLOTS = " + str(controller_parameters["CLOCK_RATIO"]) + ";")

for param in controller_parameters["PORT_SIZES"].keys():
    if controller_parameters["PORT_SIZES"][param] == -1:
        verilog_header.append("parameter " + param + " = " + str(parameter_dict[param]["Value"]) + ";")
    else:
        verilog_header.append("parameter " + param + " = " + str(controller_parameters["PORT_SIZES"][param]) + ";")

verilog_header.append("parameter CONFIGURATION_ADDR_BITS = " + str(controller_parameters["CONFIGURATION_ADDR_BUS_SIZE"]) + ";")
verilog_header.append("parameter CONFIGURATION_DATA_BITS = " + str(controller_parameters["CONFIGURATION_DATA_BUS_SIZE"]) + ";")
verilog_header.append("parameter CONFIGURATION_SEL_BITS = " + str(controller_parameters["CONFIGURATION_MEMORY_SELECT_BITS"]) + ";")

verilog_header.append("parameter RUNTIME_ADDR_BITS = " + str(controller_parameters["RUNTIME_ADDR_BUS_SIZE"]) + ";")
verilog_header.append("parameter RUNTIME_MASK_BITS = " + str(controller_parameters["RUNTIME_DATAMASK_BUS_SIZE"]) + ";")
verilog_header.append("parameter RUNTIME_DATA_BITS = " + str(controller_parameters["RUNTIME_DATA_BUS_SIZE"]) + ";")

verilog_header.append("parameter RUNTIME_RULES_BITS = " +  str(int(math.log2(controller_parameters["NUM_RUNTIME_RULES"]))) + ";")
verilog_header.append("parameter REFRESH_RULES_BITS = " +  str(int(math.log2(controller_parameters["NUM_REFRESH_RULES"]))) + ";")
verilog_header.append("parameter MACRO_COUNT_BITS = " + str(macro_format["MACRO_COUNT_BITS"]) + ";")
verilog_header.append("parameter COMMAND_WORD = " + str(command_format["COMMAND_SIZE"]) + ";")

for memory in controller_parameters["CONFIGURATION_MEMORIES"].keys():
    verilog_header.append("wire [" + str(controller_parameters["CONFIGURATION_MEMORY_SELECT_BITS"]-1)  + ":0] ADDR_" + memory + " = " + str(controller_parameters["CONFIGURATION_MEMORY_SELECT_BITS"]) + "'d" + str(controller_parameters["CONFIGURATION_MEMORIES"][memory]) + ";")

verilog_header.append("parameter BURST_SIZE = " + str(controller_parameters["BURST_SIZE"]) + ";")
verilog_header.append("parameter BURST_BITS = " + str(int(math.log2(controller_parameters["BURST_SIZE"]))) + ";")
verilog_header.append("parameter TIMER_BITS = " + str(timing["TIMER_INDEX_BITS"]) + ";")
verilog_header.append("parameter MACRO_WORD = " + str(macro_format["MACRO_COUNT_BITS"] + macro_format["MAXIMUM_COMMANDS_PER_MACRO"]*(command_format["COMMAND_SIZE"] + int(math.log2(controller_parameters["CLOCK_RATIO"])) + timing["TIMER_INDEX_BITS"]) ) + ";")
    
for param in dev_cmd_bit_encoding["ENCODING"].keys():
    verilog_header.append("parameter CMD_" + param + " = 4'b" + str('{0:04b}'.format(dev_cmd_bit_encoding["ENCODING"][param])) + ";")

for param in timing["COMMAND_TIMERS"].keys():
    verilog_header.append("wire [" + str(timing["TIMER_INDEX_BITS"]-1) + ":0] TIMER_" + param + " = " + str(timing["TIMER_INDEX_BITS"]) + "'d" + str(timing["COMMAND_TIMERS"][param]) + ";")
    
for param in timing["BASE_TIMERS_RESET"].keys():
    verilog_header.append("parameter TIMER_" + param + "_RESET  = " + str(timing["BASE_TIMERS_RESET"][param]) + ";")

verilog_header.append("parameter MAX_REFRESH_DEBT = " + str(timing["MAX_REFRESH_DEBT"]) + ";")
verilog_header.append("parameter ADDRESS_FORMAT_RESET = " + str(controller_parameters["DEFAULT_ADDRESS_FORMAT"]) + ";")

verilog_header.append("parameter CACHE_SIZE = " + str(controller_parameters["CACHE_SIZE"]) + ";")
verilog_header.append("parameter CACHE_SET_SIZE = " + str(controller_parameters["CACHE_SET_SIZE"]) + ";")
verilog_header.append("parameter DEFAULT_CACHE_POLICY = " + str(controller_parameters["DEFAULT_CACHE_POLICY"]) + ";")
verilog_header.append("parameter CACHE_LINE_SIZE = " + str(controller_parameters["CACHE_LINE_SIZE"]) + ";")
verilog_header.append("parameter UI_DATA_WIDTH = " + str(controller_parameters["UI_DATA_WIDTH"]) + ";")
verilog_header.append("parameter ENABLE_PERFTUNER = " + str(controller_parameters["ENABLE_PERFTUNER"]) + ";")
verilog_header.append("parameter SIMULATION = " + str(controller_parameters["SIMULATION"]) + ";")

verilog_header.append("parameter PERF_BITS = " + str(perftuner_parameters["PERF_BITS"]) + ";")
verilog_header.append("parameter AUTO_PRECHARGE_IDLE_ROW_EN_RESET = " + str(perftuner_parameters["AUTO_PRECHARGE_IDLE_ROW_EN_RESET"]) + ";")
verilog_header.append("parameter AUTO_PRECHARGE_IDLE_ROW_LIMIT_RESET = " + str(perftuner_parameters["AUTO_PRECHARGE_IDLE_ROW_LIMIT_RESET"]) + ";")
verilog_header.append("parameter AUTO_ACTIVATE_IDLE_BANK_EN_RESET = " + str(perftuner_parameters["AUTO_ACTIVATE_IDLE_BANK_EN_RESET"]) + ";")
verilog_header.append("parameter AP_BIT_RESET = " + str(perftuner_parameters["AP_BIT_RESET"]) + ";")
verilog_header.append("parameter TRANSACTION_DELAY = " + str(perftuner_parameters["TRANSACTION_DELAY"]) + ";")
        
        
with open(f'./build/{sys.argv[1]}/build/memory_subsystem_config.vh', 'w') as f:
    for line in verilog_header:
        f.write("%s\n" % line)
        

#################################################################################################################################################
os.system("mkdir -p ./subsystems/memory_subsystem/hex")

    
init_arbiter_rules = []

banks = 0;

if controller_parameters["PORT_SIZES"]["BA_BITS"] == -1:
    banks = 2**(parameter_dict["BA_BITS"]["Value"])
else:
    banks = 2**(controller_parameters["PORT_SIZES"]["BA_BITS"])
    
if (default_arbitration_policy["SCHEME"] == 'roundrobin'):
    for request in range (2**banks):
        for last_granted in range (banks):

            if (request == 0):
                init_arbiter_rules.append(last_granted)
            else:
                base = last_granted+1
                for i in range(banks):
                    if (base >= banks):
                        base = 0
                    if (request & (1 << base)):
                        init_arbiter_rules.append(base)
                        break
                    else:
                        base = base + 1


if (default_arbitration_policy["SCHEME"] == 'sticky'):
    for request in range (2**banks):
        for last_granted in range (banks):

            if (request == 0):
                init_arbiter_rules.append(last_granted)
            else:
                if (request & (1 << last_granted)):
                    init_arbiter_rules.append(last_granted)
                else:         
                    base = last_granted+1
                    for i in range(banks):
                        if (base >= banks):
                            base = 0
                        if (request & (1 << base)):
                            init_arbiter_rules.append(base)
                            break
                        else:
                            base = base + 1
                        
with open('./subsystems/memory_subsystem/hex/init_arbiter_rules.hex', 'w') as f:
    for bank in init_arbiter_rules:
        f.write(format(bank, 'x'))
        f.write("\n")
        

#################################################################################################################################################

init_command_db = []

for command in default_commands.keys():
    command_value = 0
    for attr in default_commands[command].keys():
        command_value = command_value + command_format[attr][str(default_commands[command][attr])]
    init_command_db.append(command_value)
    

#################################################################################################################################################

init_refresh_rules = []
for command in default_refresh_rules["COMMANDS"]:
    command_value = init_command_db[list(default_commands.keys()).index(command)]
    init_refresh_rules.append(command_value)


digits = math.ceil(command_format["COMMAND_SIZE"]/4)

with open('./subsystems/memory_subsystem/hex/init_refresh_rules.hex', 'w') as f:
    for command in init_refresh_rules:
        f.write(str(format(command ,'x')).zfill(digits))
        f.write("\n")
        
#################################################################################################################################################       

init_macro_db = []

slot_bits = int(math.log2(controller_parameters["CLOCK_RATIO"]))
timer_bits = timing["TIMER_INDEX_BITS"]
command_bits = command_format["COMMAND_SIZE"]
max_commands = macro_format["MAXIMUM_COMMANDS_PER_MACRO"]


macro_word = macro_format["MACRO_COUNT_BITS"] + max_commands*(slot_bits+timer_bits+command_bits)
digits = math.ceil(macro_word/4)

for macro in default_macros.keys():
        default_macros[macro]["COMMAND_VALUES"] = []
        for command in default_macros[macro]["COMMANDS"]:
            command_value = init_command_db[list(default_commands.keys()).index(command)]
            default_macros[macro]["COMMAND_VALUES"].append(command_value)
        command_values = list(default_macros[macro]["COMMAND_VALUES"])
        command_slots = list(default_macros[macro]["COMMAND_SLOTS"])
        command_timers = list(default_macros[macro]["COMMAND_TIMERS"])
        
        values = []
        
        for (value, slot, timer) in zip(command_values, command_slots, command_timers):
            values.append(slot + (2**slot_bits)*timing["COMMAND_TIMERS"][timer] + (2**(slot_bits+timer_bits))*value)
        
        value = len(values)*(2**(max_commands*(slot_bits+timer_bits+command_bits)))
        
        for i in range(len(values)):
            value = value + (2**(i*(slot_bits+timer_bits+command_bits)))*values[i]
        

        init_macro_db.append(value)

init_runtime_rules = []
for macro in default_runtime_rules["MACROS"]:
    init_runtime_rules.append(init_macro_db[list(default_macros.keys()).index(macro)])
    

with open('./subsystems/memory_subsystem/hex/init_runtime_rules.hex', 'w') as f:
    for macro in init_runtime_rules:
        f.write(str(format( macro  ,'x')).zfill(digits))
        f.write("\n")  

#################################################################################################################################################   


online_configuration = []

addr_bits = controller_parameters["CONFIGURATION_ADDR_BUS_SIZE"]
data_bits = controller_parameters["CONFIGURATION_DATA_BUS_SIZE"]
sel_bits = controller_parameters["CONFIGURATION_MEMORY_SELECT_BITS"]

digits = math.ceil((addr_bits+data_bits)/4)

    

base = controller_parameters["CONFIGURATION_MEMORIES"]["RUNTIME_RULES_3"] * (2**(addr_bits-sel_bits))
for i in range(len(init_runtime_rules)):
    macro = init_runtime_rules[i]
    macro = (macro >> 96) & ((2**32) - 1)
    addr = (base + i)*(2**data_bits)
    online_configuration.append(addr+macro)


base = controller_parameters["CONFIGURATION_MEMORIES"]["RUNTIME_RULES_2"] * (2**(addr_bits-sel_bits))
for i in range(len(init_runtime_rules)):
    macro = init_runtime_rules[i]
    macro = (macro >> 64) & ((2**32) - 1)
    addr = (base + i)*(2**data_bits)
    online_configuration.append(addr+macro)


base = controller_parameters["CONFIGURATION_MEMORIES"]["RUNTIME_RULES_1"] * (2**(addr_bits-sel_bits))
for i in range(len(init_runtime_rules)):
    macro = init_runtime_rules[i]
    macro = (macro >> 32) & ((2**32) - 1)
    addr = (base + i)*(2**data_bits)
    online_configuration.append(addr+macro)


base = controller_parameters["CONFIGURATION_MEMORIES"]["RUNTIME_RULES_0"] * (2**(addr_bits-sel_bits))
for i in range(len(init_runtime_rules)):
    macro = init_runtime_rules[i]
    macro = (macro >> 0) & ((2**32) - 1)
    addr = (base + i)*(2**data_bits)
    online_configuration.append(addr+macro)
    

base = controller_parameters["CONFIGURATION_MEMORIES"]["REFRESH_RULES"] * (2**(addr_bits-sel_bits))
for i in range(len(init_refresh_rules)):
    command = init_refresh_rules[i]
    addr = (base + i)*(2**data_bits)
    online_configuration.append(addr+command)
    
base = controller_parameters["CONFIGURATION_MEMORIES"]["TIMERS"] * (2**(addr_bits-sel_bits))     
base_timers = list(timing["BASE_TIMERS_RESET"].keys())   
for i in range(len(base_timers)):
    timer_reset = timing["BASE_TIMERS_RESET"][base_timers[i]]
    addr = (base + i)*(2**data_bits)
    online_configuration.append(addr+timer_reset)
    
base = controller_parameters["CONFIGURATION_MEMORIES"]["ADDRESS_FORMAT"] * (2**(addr_bits-sel_bits))    
online_configuration.append(base*(2**data_bits) + controller_parameters["DEFAULT_ADDRESS_FORMAT"])
    
base = controller_parameters["CONFIGURATION_MEMORIES"]["REFRESH_DEBT"] * (2**(addr_bits-sel_bits))    
online_configuration.append(base*(2**data_bits) + timing["MAX_REFRESH_DEBT"])

with open('./subsystems/memory_subsystem/hex/online_configuration.hex', 'w') as f:
    for config in online_configuration:
        f.write(str(format( config  ,'x')).zfill(digits))
        f.write("\n")
 
