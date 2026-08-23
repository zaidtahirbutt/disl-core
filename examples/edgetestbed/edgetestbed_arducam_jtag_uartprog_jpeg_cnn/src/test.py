from jtag import JTAG
import subprocess
import time
from utils import *
import plotext as plt

bin_file = './edgetestbed_arducam_jtag_uartprog_jpeg_cnn/edgetestbed_arducam_jtag_uartprog_jpeg_cnn.runs/impl_1/top.bin'
firmware = 'cpu_firmware.hex'
image_file = '../out.jpeg'
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
print("Starting image capture")
flip = 0
freq = 12000000
img_width = 320
img_height = 240
count = 0
while 1:
    img = capture_RAW_image(jtag_)
    print("CNN output: " + str(img[:3]))
    try:
        img = decodeBinaryImage(img[3:], img_height, img_width, flip)
        write_numpy_image(img, image_file)
    except:
        continue
jtag_.free_dev()
