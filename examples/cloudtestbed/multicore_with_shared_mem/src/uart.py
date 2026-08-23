import usb.core
import usb.util
import array 

class DEVICE:
    def __init__ (self, idVendor ,idProduct):
        self.dev = usb.core.find(idVendor=idVendor, idProduct=idProduct)
        if self.dev is None:
            raise ValueError('Our device is not connected')
        for i in range(2):
            if self.dev.is_kernel_driver_active(i):
                reattach = True
                self.dev.detach_kernel_driver(i)
        self.cfg = self.dev.get_active_configuration()
        self.uart_intfc = self.cfg[(0,0)]
        self.uart_ep_wr = (usb.util.find_descriptor(self.uart_intfc, custom_match=lambda e: not (e.bEndpointAddress & 0x80))).bEndpointAddress
        self.uart_ep_rd = (usb.util.find_descriptor(self.uart_intfc, custom_match=lambda e: (e.bEndpointAddress & 0x80))).bEndpointAddress
        # Commands from: ftdi_sio.h.
        self.FTDI_SIO_RESET_REQUEST_TYPE = 0x40
        self.FTDI_SIO_SET_BAUDRATE_REQUEST_TYPE = 0x40
        self.FTDI_SIO_SET_DATA_REQUEST_TYPE = 0x40
        self.FTDI_SIO_SET_FLOW_CTRL_REQUEST_TYPE = 0x40
        self.FTDI_SIO_SET_MODEM_CTRL_REQUEST_TYPE = 0x40
        self.FTDI_SIO_GET_LATENCY_TIMER_REQUEST_TYPE = 0xC0
        self.FTDI_SIO_SET_LATENCY_TIMER_REQUEST_TYPE = 0x40
        self.FTDI_SIO_SET_EVENT_CHAR_REQUEST_TYPE = 0x40
        self.FTDI_SIO_GET_MODEM_STATUS_REQUEST_TYPE = 0xc0
        self.FTDI_SIO_SET_BITMODE_REQUEST_TYPE = 0x40
        self.FTDI_SIO_READ_EEPROM_REQUEST_TYPE = 0xc0
        # Requests
        self.FTDI_SIO_RESET = 0
        self.FTDI_SIO_MODEM_CTRL = 1
        self.FTDI_SIO_SET_FLOW_CTRL = 2
        self.FTDI_SET_BAUD_RATE = 3
        self.FTDI_SIO_SET_DATA = 4
        # Channels
        self.CHANNEL_A = 0
        # Values
        self.FTDI_SIO_RESET_PURGE_RX = 0
        self.FTDI_SIO_RESET_PURGE_TX = 0
        self.FTDI_SIO_SET_DATA_STOP_BITS_1 = 0x0 << 11
        self.FTDI_SIO_SET_DATA_PARITY_NONE = 0x0 << 8
        self.FTDI_BASECLOCK = 120000000
        self.FTDI_SIO_DISABLE_FLOW_CTRL = 0x0
        self.FTDI_SIO_RTS_CTS_HS  = (0x1 << 8)
        self.FTDI_SIO_DTR_DSR_HS  = (0x2 << 8)
        self.FTDI_SIO_XON_XOFF_HS = (0x4 << 8)
        self.XOFF = 0x13
        self.XON = 0x11
        self.FTDI_FLOW_CONTROL = {"NONE": 0, "RTS/CTS": 1, "DTR/DSR": 2, "XON/XOFF": 4}
        
    def control(self, bmRequestType, bmRequest, wValue, wIndex, packet):
        return self.dev.ctrl_transfer(bmRequestType, bmRequest, wValue, wIndex, packet)
        
        
    def uart_configure(self, data_size=8, baudrate=1000000, flowcontrol="XON/XOFF"):
        divfrac = [ 0, 3, 2, 4, 1, 5, 6, 7 ]
        divisor3 = round((8 * self.FTDI_BASECLOCK)/(10 * baudrate))
        divisor = divisor3 >> 3
        divisor |= divfrac[divisor3 & 0x7] << 14
        if (divisor == 1):
            divisor = 0
        elif (divisor == 0x4001):
            divisor = 1
        FTDI_BAUD_DIVISOR = 3#divisor
        self.control(self.FTDI_SIO_RESET_REQUEST_TYPE, self.FTDI_SIO_RESET, 
                                0, 
                                ((0x00) << 8) | self.CHANNEL_A, 0)
        self.control(self.FTDI_SIO_SET_DATA_REQUEST_TYPE, self.FTDI_SIO_SET_DATA, 
                                data_size | self.FTDI_SIO_SET_DATA_STOP_BITS_1 | self.FTDI_SIO_SET_DATA_PARITY_NONE, 
                                ((0x00) << 8) | self.CHANNEL_A, 0)
        self.control(self.FTDI_SIO_SET_BAUDRATE_REQUEST_TYPE, self.FTDI_SET_BAUD_RATE, FTDI_BAUD_DIVISOR, 
                                ((0x00) << 8) | self.CHANNEL_A, 0)
        self.control(self.FTDI_SIO_SET_FLOW_CTRL_REQUEST_TYPE, self.FTDI_SIO_SET_FLOW_CTRL,   
                                ((self.XOFF) << 8) | self.XON, ((self.FTDI_FLOW_CONTROL[flowcontrol]) << 8) | self.CHANNEL_A, 0)
        
    def uart_write(self, msg=[], timeout=100):
        self.dev.write(self.uart_ep_wr, msg, timeout)
        
    def uart_read(self, is_str=1, timeout=100):
        buf = array.array('b',[0]*512)
        size = self.dev.read(self.uart_ep_rd, buf, timeout)
        if size == 2:
            return ''
        if is_str:
            return ''.join([chr(x&0xff) for x in buf[2:size]])
        else:
            return buf[2:size]

    def free_dev(self):
        self.dev.reset()
        self.dev.attach_kernel_driver(0)
        usb.util.dispose_resources(self.dev)
