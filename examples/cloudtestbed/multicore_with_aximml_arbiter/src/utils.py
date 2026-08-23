from jtag import JTAG
from uart import DEVICE
import time
import os
import toml

def config_load(filename):
    with open(filename) as f:
        if ".tml" in filename:
            return toml.load(f)
        else:
            return json.load(f)

def parameters_load(filename):
    params = {}
    with open(filename) as f:
        for line in f:
            line.strip()
            if (line):
                param = line.split(' ')[1]
                value = line.split(' ')[3].split(";")[0]
                params[param] = value
    return params



def reset_hardware(jtag_):
    jtag_.control_write({"0_31": 3, "32_63": 0, "64_95": 0})
    time.sleep(1)
    jtag_.control_write({"0_31": 0, "32_63": 0, "64_95": 0})
    time.sleep(1)

def reset_softcores(jtag_):
    jtag_.control_write({"0_31": 2, "32_63": 0, "64_95": 0})
    time.sleep(0.1)

def start_softcores(jtag_):
    jtag_.control_write({"0_31": 0, "32_63": 0, "64_95": 0})
    time.sleep(0.1)

def program_core(uart, toolchain, cpu_id, origin):
    os.system("make all CROSS=" + toolchain + " CPU_NAME=" + str(cpu_id))
    program = []
    address = []   
    counter = 0;              
    with open(str(cpu_id) + ".hex") as file:
        for line in file:
            if "@" in line: 
                counter = int(line.split('@')[1],16)
            else:
                nl_rm_line =  line.split('\n')[0];  
                nl_rm_line =  nl_rm_line.split(' ');   
                if len(nl_rm_line) == 0: continue
                words = int(len(nl_rm_line)/4)
                for i in range(words):
                    program.append(nl_rm_line[4*i+3] + nl_rm_line[4*i+2] + nl_rm_line[4*i+1] + nl_rm_line[4*i])
                    address.append(counter + origin)
                    counter = counter + 4;      
    for i in range(len(program)):
        x = address[i]
        x1 = [(x&255)]
        x2 = [((x>>8)&255)]
        x3 = [((x>>16)&255)]
        x4 = [((x>>24)&255)]
        uart.uart_write(x1)
        uart.uart_write(x2)
        uart.uart_write(x3)
        uart.uart_write(x4)
        x = int(program[i],16)
        x1 = [(x&255)]
        x2 = [((x>>8)&255)]
        x3 = [((x>>16)&255)]
        x4 = [((x>>24)&255)]
        uart.uart_write(x1)
        uart.uart_write(x2)
        uart.uart_write(x3)
        uart.uart_write(x4)
        time.sleep(0.001)
    time.sleep(0.1)