import subprocess
import time
import os
import numpy as np
import matplotlib.pyplot as plt
from jtag import JTAG
from utils import *

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
img = capture_RAW_image(jtag_)
img = capture_RAW_image(jtag_)
while True:
    try:
        img = capture_RAW_image(jtag_)
        try:
            decoded_img = decodeRGB565Image(img, img_height, img_width, flip)
            write_numpy_image(decoded_img, image_file)
            counters = img[-19:-3]
            runtime = counters[12] + ((counters[13] & 0xff) << 8) + ((counters[14] & 0xff) << 16) + (
                    (counters[15] & 0xff) << 24)
            capture_timer = counters[0] + ((counters[1] & 0xff) << 8) + ((counters[2] & 0xff) << 16) + (
                    (counters[3] & 0xff) << 24)
            process_timer = counters[4] + ((counters[5] & 0xff) << 8) + ((counters[6] & 0xff) << 16) + (
                    (counters[7] & 0xff) << 24)
            transmit_timer = counters[8] + ((counters[9] & 0xff) << 8) + ((counters[10] & 0xff) << 16) + (
                    (counters[11] & 0xff) << 24)


            # Print runtime and frame rate
            runtime_s = runtime/1000000
            print(f"Runtime (s): {runtime_s:.2f}")
            frame_rate = 1000000/runtime
            print(f"Frame Rate (frames/s): {frame_rate:.2f}")

            # Plot stacked bar chart
            setup_time = runtime - (capture_timer + process_timer + transmit_timer)
            setup_percent = (setup_time * 100 / runtime)
            capture_percent = (capture_timer * 100 / runtime)
            process_percent = (process_timer * 100 / runtime)
            transmit_percent = (transmit_timer * 100 / runtime)
            plt.figure(figsize=(12, 12))
            labels = ["Setup", "Capture", "Process", "Transmit"]
            values = [setup_percent, capture_percent, process_percent, transmit_percent]
            plt.pie(values, labels=[None]*len(labels), startangle=140)
            plt.annotate(f"Frame Rate: {frame_rate:.2f} frames/s", xy=(0.5, -0.08), xycoords='axes fraction', fontweight='bold', fontsize=40, ha='center')
            plt.annotate(f"Runtime: {runtime_s:.2f} s", xy=(0.5, -0.01), xycoords='axes fraction', fontweight='bold', fontsize=40, ha='center')
            plt.legend(labels, loc="upper center", bbox_to_anchor=(0.9, 1.0), prop={'weight': 'bold','size': 35})
            plt.savefig(plot_file, bbox_inches='tight', dpi=300)
            plt.close()

        except Exception as e:
            print(f"Error processing image: {e}")
    except KeyboardInterrupt:
        break

jtag_.free_dev()