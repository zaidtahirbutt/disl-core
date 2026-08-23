from jtag import JTAG
import json
import time
import psutil
import subprocess

jtag_ = JTAG(0x0403, 0x6010)
jtag_.ftdi_.dev.uart_configure()
jtag_.program('./edgetestbed_arducam_jtag_no_dram/edgetestbed_arducam_jtag_no_dram.runs/impl_1/top.bin')
jtag_.control_write({"0_31": 3, "32_63": 0, "64_95": 0})
time.sleep(0.1)
jtag_.control_write({"0_31": 2, "32_63": 0, "64_95": 0})
time.sleep(0.1)
jtag_.program_softcore("cpu_firmware.hex", 0)
time.sleep(0.1)
jtag_.control_write({"0_31": 0, "32_63": 0, "64_95": 0}) 
viewer = ''
#while (1):
img = []
prev = -1
count = 0
exit()
while(0):
    #c = jtag_.axi_read(0)
    #if count == 0:
    c = jtag_.axi_read(0)
    print(c)
    sret = jtag_.ftdi_.dev.uart_read()
    print(sret,end='')
    count = (count+1) if count < 5 else 0
    time.sleep(0.1)
#exit()
while(1):
    #sret = jtag_.ftdi_.dev.uart_read()
    #print(sret,end='')
    c = jtag_.axi_read(0)
    #print(c)
    #jtag_.axi_write(0,1)
    if ((c & 0xff) == 0xd8) and (prev == 0xff):
        img.append(prev)
        img.append(c)
    elif ((c & 0xff) == 0xd9) and (prev == 0xff):
        with open("out.jpg",'wb') as f:
            f.write(bytearray(img))
        img = []
        if (not viewer):
            viewer = subprocess.Popen(['eog', 'out.jpg'])
    elif len(img):
        img.append(c)
    if len(img) > 1000000:
        print("Error")
        break
    prev = c
jtag_.free_dev()
