from jtag import JTAG
from uart import DEVICE
from utils import *
import array
import time

CPU_TYPE = "picorv32_hydra_axi"
MEMORY_BUS_ARBITER = "cache_arbiter"

print("Configuring host JTAG and UART connections")
jtag_ = JTAG(idVendor=0x0403, idProduct=0x6014)
uart = DEVICE(idVendor=0x0403, idProduct=0x6001)
uart.uart_configure()

print("Loading system configuration")
system = config_load('system.tml')


print("Reconfiguring the device")
jtag_.program("./" + system["DESCRIPTION"]["NAME"] + "/" + system["DESCRIPTION"]["NAME"] + ".runs/impl_1/top.bin")


print("Resetting hardware")
reset_hardware(jtag_)

print("Getting a list of softcores")
cpus = []
for inst in system["INSTANTIATIONS"].keys():
    if system["INSTANTIATIONS"][inst]["MODULE"] == CPU_TYPE:
        cpus.append(inst)
num_cpus = len(cpus)
assert num_cpus > 0, f"No valid softcores of type '{CPU_TYPE}' found in the design"
print("Found " + str(num_cpus) + " softcores in the design")

print("Reading evaluated hardware parameters")
params = parameters_load('parameters.vh')
assert len(params.keys()), "Parameter dictionary is empty"

print("Getting memory regions for each softcore")
assert MEMORY_BUS_ARBITER in system["INSTANTIATIONS"].keys(), "Design does not have a valid memory bus arbiter"
offsets = []
for i in range(len(cpus)):
    cpu = cpus[i]
    group = system["INTERCONNECT"]["DYNAMIC"]["MODULE:" + cpu + ":mem"]["GROUPS"][0]
    assert group["INTERCONNECT_TYPE"] == "ONE_TO_MANY", "Current support is limited to ONE_TO_MANY softcore connections"
    address_map = group["ADDRESS_MAP"]
    arbiter_port = ""
    for m in address_map:
        if "cache_arbiter" in m.split(" ")[1]:
            arbiter_port = m.split(" ")[1].split(":")[-1] 
    assert arbiter_port, f"Could not find a valid memory bus connection for {cpu}"
    offset = params["PARAMETER_" + MEMORY_BUS_ARBITER.upper() + "_" + arbiter_port.upper() + "_ADDRESS_OFFSET"]
    offsets.append(int(offset))

print("Resetting softcores")
reset_softcores(jtag_)

for i in range(len(cpus)):
    print("Programming softcore: " + cpus[i])
    program_core(uart, "/opt/riscv/xpack-riscv-none-embed-gcc-10.2.0-1.2/bin/riscv-none-embed-", cpus[i], offsets[i])

print("Starting softcores")
start_softcores(jtag_)

print("Starting terminal capture")
try:
    while (1):
        sret = uart.uart_read()
        if sret:
            print(sret,end='')
        time.sleep(0.01)
except:
    print("Error: Stopping hardware and exiting")
    jtag_.control_write({"0_31": 3, "32_63": 0, "64_95": 0})
    jtag_.free_dev()
    uart.free_dev()

try:
    jtag_.free_dev()
    uart.free_dev()
except:
    exit()