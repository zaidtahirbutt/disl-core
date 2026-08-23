from jtag import JTAG
from uart import DEVICE
from utils import *
import array
import time

CPU_TYPE = "picorv32_hydra_axi"
MEMORY_BUS_ARBITER = "cache_arbiter"

MAX_MEMORY_SIZE = 2147483648
INSTRUCTION_MEMORY_SIZE = 1024*1024 #bytes
SHARED_MEMORY_SIZE = 1024*1024 #bytes
STACK_SIZE = 1024*1024

print("Loading system configuration")
system = config_load('system.tml')

print("Getting a list of softcores")
cpus = []
for inst in system["INSTANTIATIONS"].keys():
    if system["INSTANTIATIONS"][inst]["MODULE"] == CPU_TYPE:
        cpus.append(inst)
num_cpus = len(cpus)
assert num_cpus > 0, f"No valid softcores of type '{CPU_TYPE}' found in the design"
print("Found " + str(num_cpus) + " softcores in the design")


print("Configuring host JTAG and UART connections")
jtag_ = JTAG(idVendor=0x0403, idProduct=0x6014, log=1)
uart = DEVICE(idVendor=0x0403, idProduct=0x6001)
uart.uart_configure()

print("Reconfiguring the device")
jtag_.program("./" + system["DESCRIPTION"]["NAME"] + "/" + system["DESCRIPTION"]["NAME"] + ".runs/impl_1/top.bin")

print("Starting the design bring-up sequence")
timer = time.time()

print("Doing a full hardware reset")
reset_hardware(jtag_)

print("Holding all softcores in reset/halt state")
reset_softcores(jtag_)

for i in range(len(cpus)):
    print("Updating memory map table for softcore: cpu" + str(i))
    mmap = [[INSTRUCTION_MEMORY_SIZE,0,0,1],
            [SHARED_MEMORY_SIZE + INSTRUCTION_MEMORY_SIZE,INSTRUCTION_MEMORY_SIZE,INSTRUCTION_MEMORY_SIZE,0],
            [MAX_MEMORY_SIZE,MAX_MEMORY_SIZE - (STACK_SIZE),MAX_MEMORY_SIZE - ((i+1)*STACK_SIZE),0]]
    update_memory_map(jtag_, i, mmap, 1)

print("Programming softcores")
program_core(jtag_, cpus[0], 0)

print("Initializing shared memory")
for i in range(2*num_cpus):
    jtag_.axi_write(INSTRUCTION_MEMORY_SIZE+i,  0)

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