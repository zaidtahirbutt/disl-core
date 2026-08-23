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

def program_core(jtag_, cpu_id, origin):
    os.system("make all CPU_NAME=" + str(cpu_id))
    jtag_.program_softcore(str(cpu_id) + ".hex", origin, 0)
    time.sleep(0.1)