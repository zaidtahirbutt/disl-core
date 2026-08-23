from jtag import JTAG
import subprocess
import time
from utils import *

bin_file = './edgetestbed_arducam_jtag_uartprog/edgetestbed_arducam_jtag_uartprog.runs/impl_1/top.bin'
firmware = 'cpu_firmware.hex'
image_file = 'out.jpeg'


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
img_width = 320
img_height = 240
bytes_per_pixel = 2
offset = 0
flip = 0
viewer = ''
while 1:
    try:
        #img = capture_JPEG_image(jtag_)
        img = capture_RAW_image(jtag_)
        #img2 = capture_RAW_image(jtag_)
        try:
            #write_jpeg_image(img, image_file)
            #if len(img) > len(img2):
            decoded_img = decodeRGB565Image(img, img_height, img_width, flip)
                #decoded_img2 = decodeBinaryImage(img2, img_height, img_width, flip)
            #else:
                #decoded_img = decodeRGB565Image(img2, img_height, img_width, flip)
                #decoded_img2 = decodeBinaryImage(img, img_height, img_width, flip)
            #for x in range (0,img_height):
            #    for y in range (0,img_width):
            #        pixel = decoded_img2[x,y]
            #        decoded_img[x,y,0] = 255 if not pixel else decoded_img[x,y,0]
            #        decoded_img[x,y,1] = 0 if not pixel else decoded_img[x,y,1] 
            #        decoded_img[x,y,2] = 0 if not pixel else decoded_img[x,y,2]
            write_numpy_image(decoded_img, image_file)
            if (not viewer):
                viewer = subprocess.Popen(['eog', image_file])
        except:
            print("Invalid image")
    except:
        break
jtag_.free_dev()
