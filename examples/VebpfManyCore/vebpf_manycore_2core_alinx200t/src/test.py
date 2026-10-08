from jtag import JTAG
import subprocess
import time
from utils import *
import plotext as plt
import sys
import keyboard


bin_file = './top.bin'
firmware = './cpu_firmware.hex'
# firmware = './cpu_firmware.hex'
# image_file = '../out.jpeg'

# print(f"firmware = {firmware} \n")

# with open(firmware) as file:
#     print(f"file = {file} \n")
#     # sys.exit("Exiting sys.exit()")   
#     for line in file:
#         print(f"line = {line} \n")    
#         sys.exit("Exiting sys.exit()")

print("Initializing FTDI connection")
start = time.time()
jtag_ = JTAG(0x0403, 0x6010)
print("Done - Initializing FTDI connection took " + str(time.time()-start) + " seconds")

print("Configuring the UART")
start = time.time()
jtag_.ftdi_.dev.uart_configure(baudrate=921600)
print("Done - Configuring the UART took " + str(time.time()-start) + " seconds")

# jtag_.program(bin_file) doesn't work on VB ... gets stuck... Program bit file with Vivado.. Exit it.. Detach USB from VBOX.. Add it back and then 
# run this python script to upload the riscv hex file, otherwise the USB is busy.. 



# print("Reconfiguring the FPGA")
# start = time.time()
# jtag_.program(bin_file)
# print("Done - Reconfiguring the FPGA took " + str(time.time()-start) + " seconds")


print("Programming the softcore")
start = time.time()
program_softcore(jtag_,firmware)
print("Done - Programming the softcore took " + str(time.time()-start) + " seconds")

# print("Starting image capture")
# flip = 0
# freq = 12000000
# img_width = 320
# img_height = 240
# count = 0
# while 1:
#     img = capture_RAW_image(jtag_)
#     print("CNN output: " + str(img[:3]))
#     try:
#         img = decodeBinaryImage(img[3:], img_height, img_width, flip)
#         write_numpy_image(img, image_file)
#     except:
#         

try:
    while (1):
        sret = jtag_.ftdi_.dev.uart_read()
        if sret:
            print(sret,end='')

        if keyboard.is_pressed('q'):
            print("Q pressed Exiting...")
            break
        time.sleep(0.01)
except:
    jtag_.free_dev()

jtag_.free_dev()
print("jtag freed - FIN")
