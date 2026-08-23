from jtag import JTAG
import subprocess
import time
from utils import *
import matplotlib.pyplot as plt

bin_file = 'top.bin'
firmware = 'cpu_firmware.hex'
image_file = '../../utils/gui/static/out.jpeg'
plot_file = '../../utils/gui/static/perf4.jpeg'


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

flip = 0
freq = 12000000
img_width = 320
img_height = 240
count = 0
while 1:
    try:
        img = capture_RAW_image(jtag_)
        try:
            counters = img[-19:-3]
            img = img[len(img) - 3 - 16 - ((img_height*img_width)>>3):]
            img = decodeBinaryImage(img, img_height, img_width, flip)
            capture_counter = counters[0] + ((counters[1]&0xff) << 8) + ((counters[2]&0xff) << 16) + ((counters[3]&0xff) << 24)
            process_counter = counters[4] + ((counters[5]&0xff) << 8) + ((counters[6]&0xff) << 16) + ((counters[7]&0xff) << 24)
            transmit_counter = counters[8] + ((counters[9]&0xff) << 8) + ((counters[10]&0xff) << 16) + ((counters[11]&0xff) << 24)
            runtime = counters[12] + ((counters[13]&0xff) << 8) + ((counters[14]&0xff) << 16) + ((counters[15]&0xff) << 24)
            capture_time = (capture_counter/freq)*1000000
            process_time = (process_counter/freq)*1000000
            transmit_time = (transmit_counter/freq)*1000000
            process_time = process_time - capture_time - transmit_time
            runtime_s = runtime/1000000
            print(f"Runtime (s): {runtime_s:.2f}")
            frame_rate = 1000000/runtime
            print(f"Frame Rate (frames/s): {frame_rate:.2f}")
            setup_time = runtime - capture_time - process_time - transmit_time
            setup = (setup_time*100/runtime)
            capture = (capture_time*100/runtime)
            process = (process_time*100/runtime)
            transmit = (transmit_time*100/runtime)
            labels = ["Setup", "Capture", "Process", "Transmit"]
            values = [setup, capture, process, transmit]
            plt.figure(figsize=(12, 12))
            plt.pie(values, labels=[None]*len(labels), startangle=140)
            plt.annotate(f"Frame Rate: {frame_rate:.2f} frames/s", xy=(0.5, -0.08), xycoords='axes fraction', fontweight='bold', fontsize=40, ha='center')
            plt.annotate(f"Runtime: {runtime_s:.2f} s", xy=(0.5, -0.01), xycoords='axes fraction', fontweight='bold', fontsize=40, ha='center')
            plt.legend(labels, loc="upper center", bbox_to_anchor=(0.9, 1.0), prop={'weight': 'bold','size': 35})
            plt.savefig(plot_file, bbox_inches='tight', dpi=300)
            plt.close()
            write_numpy_image(img, image_file)
        except Exception as e:
            print(f"Error processing image: {e}")
    except KeyboardInterrupt:
        break
jtag_.free_dev()
