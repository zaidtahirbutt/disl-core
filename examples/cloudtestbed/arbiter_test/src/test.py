from jtag import JTAG
from uart import DEVICE
import array
import time

print("Configure JTAG and UART")
jtag_ = JTAG(idVendor=0x0403, idProduct=0x6014)
uart = DEVICE(idVendor=0x0403, idProduct=0x6001)
uart.uart_configure()
print("Done")

print("Reconfiguring device")
jtag_.program('./arbiter_test/arbiter_test.runs/impl_1/top.bin')
print("Done")

print("Resetting hardware")
jtag_.control_write({"0_31": 3, "32_63": 0, "64_95": 0})
time.sleep(1)
jtag_.control_write({"0_31": 0, "32_63": 0, "64_95": 0})
print("Done")

print("Programming softcore")
program = []
address = []
counter = 0;
with open("cpu_firmware.hex") as file:
    for line in file:
        if "@" in line: 
            counter = int(line.split('@')[1],16)
        else:
            nl_rm_line =  line.split('\n')[0];  
            nl_rm_line =  nl_rm_line.split(' ');   
            if len(nl_rm_line) == 0: continue
            words = int(len(nl_rm_line)/4)
            for i in range(words):
                program.append(nl_rm_line[4*i+3] + nl_rm_line[4*i+2] + nl_rm_line[4*i+1] + nl_rm_line[4*i])
                address.append(counter)
                counter = counter + 4;       
for i in range(len(program)):
    x = address[i]
    x1 = [(x&255)]
    x2 = [((x>>8)&255)]
    x3 = [((x>>16)&255)]
    x4 = [((x>>24)&255)]
    uart.uart_write(x1)
    uart.uart_write(x2)
    uart.uart_write(x3)
    uart.uart_write(x4)
    x = int(program[i],16)
    x1 = [(x&255)]
    x2 = [((x>>8)&255)]
    x3 = [((x>>16)&255)]
    x4 = [((x>>24)&255)]
    uart.uart_write(x1)
    uart.uart_write(x2)
    uart.uart_write(x3)
    uart.uart_write(x4)
    time.sleep(0.001)
time.sleep(0.1)
jtag_.control_write({"0_31": 2, "32_63": 0, "64_95": 0})
time.sleep(0.1)
jtag_.control_write({"0_31": 0, "32_63": 0, "64_95": 0})
print("Done")

print("Starting terminal capture")
try:
    while (1):
        sret = uart.uart_read()
        if sret:
            print(sret,end='')
        time.sleep(0.01)
except:
    print("Error: exiting")
    jtag_.free_dev()
    uart.free_dev()

try:
    jtag_.free_dev()
    uart.free_dev()
except:
    exit()