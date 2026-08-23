from jtag import JTAG
import subprocess
import time
from utils import *
import plotext as plt

bin_file = 'top.bin'
firmware = 'cpu_firmware.hex'
image_file = '../../utils/gui/static/out.jpeg'
plot_file = '../../utils/gui/static/out.jpeg'


msg = ["Initializing FTDI connection\n", "Configuring the UART\n", "Reconfiguring the FPGA\n", "Programming the softcore\n","Starting image capture"]
create_status_image(plot_file, msg[0:1])
jtag_ = JTAG(0x0403, 0x6010,"artya735t")
create_status_image(plot_file, msg[0:2])
jtag_.ftdi_.dev.uart_configure(baudrate=921600)
create_status_image(plot_file, msg[0:3])
jtag_.program(bin_file)
create_status_image(plot_file, msg[0:4])
program_softcore(jtag_,firmware)
create_status_image(plot_file, msg[0:5])

flip = 0
freq = 12000000
img_width = 320
img_height = 240
count = 0
while 1:
    img = capture_RAW_image(jtag_)
    cnn_output = img[1:3]
    person = 1 if (cnn_output[0] >= cnn_output[1]) else 0
    try:
        img = decodeBinaryImage(img[3:], img_height, img_width, flip, person)
        write_numpy_image(img, image_file)
    except:
        continue
jtag_.free_dev()
