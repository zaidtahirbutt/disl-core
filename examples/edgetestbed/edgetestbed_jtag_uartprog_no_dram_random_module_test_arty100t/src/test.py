# this didn't work.. used test.py in folder test_3 

'''
from jtag import JTAG
import subprocess
import time
from utils import *
import sys
import toml


with open("configure_options.tml") as f:
    config_options = toml.load(f)

bin_file = f'./{config_options["exmaple"]}/{config_options["exmaple"]}.runs/impl_1/top.bin'
print(f'bin_file path = {bin_file}')
firmware = 'cpu_firmware.hex'
# image_file = 'out.jpeg'


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
# print("Starting temperature capture")
try:
    while (1):
        sret = jtag_.ftdi_.dev.uart_read()
        if sret:
            print(sret,end='')
        time.sleep(0.01)
except:
    jtag_.free_dev()
'''