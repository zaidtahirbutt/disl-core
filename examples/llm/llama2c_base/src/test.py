from jtag import JTAG
import subprocess
import time
from utils import *

bin_file = './llama2c_base/llama2c_base.runs/impl_1/top.bin'
firmware = 'cpu_firmware.hex'


print("Initializing FTDI connection")
jtag_ = JTAG(0x0403, 0x6010)
print("Configuring the UART")
jtag_.ftdi_.dev.uart_configure(baudrate=921600)
print("Reconfiguring the FPGA")
jtag_.program(bin_file)
print("Done")
print("Programming the softcore")
program_softcore(jtag_,firmware)
print("Done")
time.sleep(0.01)
# program_sdcard(jtag_, 'stories15M.bin')
# program_sdcard(jtag_, 'tokenizer.bin')
print("Starting terminal capture")

try:
    while (1):
        sret = jtag_.ftdi_.dev.uart_read()
        if sret:
            print(sret,end='')
        time.sleep(0.01)
except:
    print("Error: Stopping hardware and exiting")
    jtag_.control_write({"0_31": 3, "32_63": 0, "64_95": 0})
    jtag_.free_dev()

try:
    jtag_.free_dev()
except:
    exit()
