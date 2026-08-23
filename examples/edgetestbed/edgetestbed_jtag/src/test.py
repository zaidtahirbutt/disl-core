from jtag import JTAG
import array
import time
import toml

with open("configure_options.tml") as f:
    config_options = toml.load(f)

board = config_options["board"]
baudrate = 921600

assert board in ["nexysvideo", "arty7a35t"], "Invalid board"

if board == "nexysvideo":
    jtag_ = JTAG(ftdi_chip_type="FT2232C", mpsse_channel="B")
    jtag_.ftdi_.dev.uart_configure(ftdi_chip_type="FT232",baudrate=baudrate,baseclock=48000000)
else:    
    jtag_ = JTAG(ftdi_chip_type="FT2232H", mpsse_channel="A")
    jtag_.ftdi_.dev.uart_configure(ftdi_chip_type="FT2232H",baudrate=baudrate,baseclock=12000000)

try:
    print("Reconfiguring device")
    start = time.time()
    jtag_.program('./edgetestbed_jtag/edgetestbed_jtag.runs/impl_1/top.bin')
    print("Done - reconfiguration took " + str(time.time()-start) + " seconds")

    print("Programming device")
    start = time.time()
    jtag_.program_softcore("cpu_firmware.hex",1)
    print("Done - programming took " + str(time.time()-start) + " seconds")

    print("Starting terminal capture")

    while (1):
        sret = jtag_.ftdi_.dev.uart_read()
        if sret:
            print(sret,end='')
        time.sleep(0.01)
except:
    print("Error: exiting")
    jtag_.free_dev()

try:
    jtag_.free_dev()
except:
    exit()
