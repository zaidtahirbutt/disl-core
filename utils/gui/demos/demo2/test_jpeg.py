from jtag import JTAG
import subprocess
import time
from utils import *
import plotext as plt
import os

bin_file = 'top.bin'
firmware = 'cpu_firmware.hex'
image_file = '../../utils/gui/static/out.jpeg'
plot_file = '../../utils/gui/static/perf.jpeg'

msg = ["Initializing FTDI connection\n", "Configuring the UART\n", "Reconfiguring the FPGA\n", "Programming the softcore\n","Starting image capture"]
create_status_image(plot_file, msg[0:1])
jtag_ = JTAG(0x0403, 0x6010,"cmoda735t")
create_status_image(plot_file, msg[0:2])
jtag_.ftdi_.dev.uart_configure(baudrate=921600)
create_status_image(plot_file, msg[0:3])
jtag_.program(bin_file)
create_status_image(plot_file, msg[0:4])
program_softcore(jtag_,firmware)
create_status_image(plot_file, msg[0:5])

img_width = 320
img_height = 240
bytes_per_pixel = 2
offset = 0
flip = 0
viewer = ''
img = capture_JPEG_image(jtag_)
img = capture_JPEG_image(jtag_)
while 1:
    try:
        start = time.time()
        img = capture_JPEG_image(jtag_)
        stop = time.time()
        runtime_s = stop-start
        frame_rate = 1/runtime_s
        create_status_image(plot_file, [ f"Runtime: {runtime_s:.2f} s", f"Frame Rate: {frame_rate:.2f} frames/s"])
        try:
            write_jpeg_image(img, image_file)
        except:
            print("Invalid image")
    except:
        break
jtag_.free_dev()
