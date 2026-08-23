from jtag import JTAG
import time

jtag_ = JTAG(0x0403, 0x6010)
jtag_.ftdi_.dev.uart_configure()
#jtag_.program('./edgetestbed_jtag_no_dram/edgetestbed_jtag_no_dram.runs/impl_1/top.bin')
jtag_.control_write({"0_31": 3, "32_63": 0, "64_95": 0})
time.sleep(0.1)
jtag_.control_write({"0_31": 2, "32_63": 0, "64_95": 0})
time.sleep(0.1)


arr_size = 100

def read(i):
    global jtag_
    d = jtag_.axi_read(4*i)
    return d

def write(i,d):
    global jtag_
    jtag_.axi_write(4*i,d)
    return

def bubble_sort(arr_size):
    for i in range(arr_size - 1):
        for j in range(0, arr_size - i - 1):
            a = read(j)
            b = read(j+1)
            if a > b:
                write(j, b)
                write(j + 1, a)


arr = list(range(arr_size))
arr.reverse()
print("Writing: ", end='\n\t')
print(arr)
for i in range(arr_size): write(i, arr[i]) 
 
print("Reading before bubble sort: ", end='\n\t')
print([read(i) for i in range(arr_size)])

print("Sorting\n")
bubble_sort(arr_size)

print("Reading after bubble sort: ", end='\n\t')
print([read(i) for i in range(arr_size)])

