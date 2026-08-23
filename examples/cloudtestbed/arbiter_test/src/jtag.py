from ftdi import FTDI
from ftdi import JTAG_CMD
import time

class JTAG:
    def __init__ (self, idVendor=0x0403, idProduct=0x6014, ftdi_='', jtag_user_reg=4):
        if ftdi_:
            self.ftdi_ = ftdi_
        else:
            self.ftdi_  = FTDI(idVendor, idProduct, "")
        self.jtag_user_reg_mapping = {"1": [0x24,0x49,0x0a] , "2": [0x24,0x49,0x0e], "3": [0x24,0x49,0x8a], "4": [0x24,0x49,0x8e]}
        self.jtag_user_reg = self.jtag_user_reg_mapping[str(jtag_user_reg)]
        self.AXI_READ_ADDRESS_CMD = (1 << 0)
        self.AXI_WRITE_ADDRESS_CMD = (1 << 1)
        self.AXI_READ_DATA_CMD = (1 << 2)
        self.AXI_WRITE_DATA_CMD = (1 << 3)
        self.LOAD_JTAG_READ_DATA_CMD = (1 << 4)
        self.CONTROL_WRITE_CMD = (1 << 5)
    
    def free_dev(self):
        self.ftdi_.free_dev()
        
    def reset(self):
        self.statemove("TAP_RESET")
        
    def idle(self):
        self.statemove("TAP_IDLE")
        
    def statemove(self, state):
        cmd = JTAG_CMD("JTAG_STATEMOVE", {'end_state': state})
        return self.ftdi_.ftdi_execute_queue([cmd])
        
    def irscan_bits(self, num_bits, val):
        cmd = JTAG_CMD("JTAG_SCAN", {'ir_scan': 1, 'num_fields': 1, 'fields': [{'num_bits': num_bits, 'out_value': [val], 'in_value': 0}], 'end_state': 'TAP_IDLE'})
        return self.ftdi_.ftdi_execute_queue([cmd])
        
    def irscan_bits_reset(self, num_bits, val):
        cmd = JTAG_CMD("JTAG_SCAN", {'ir_scan': 1, 'num_fields': 1, 'fields': [{'num_bits': num_bits, 'out_value': [val], 'in_value': 0}], 'end_state': 'TAP_RESET'})
        return self.ftdi_.ftdi_execute_queue([cmd])
        
    def irscan_bits_irpause(self, num_bits, val):
        cmd = JTAG_CMD("JTAG_SCAN", {'ir_scan': 1, 'num_fields': 1, 'fields': [{'num_bits': num_bits, 'out_value': [val], 'in_value': 0}], 'end_state': 'TAP_IRPAUSE'})
        return self.ftdi_.ftdi_execute_queue([cmd])
        
    def irscan_bits_hold(self, num_bits, val):
        cmd = JTAG_CMD("JTAG_SCAN", {'ir_scan': 1, 'num_fields': 1, 'fields': [{'num_bits': num_bits, 'out_value': [val], 'in_value': 0}], 'end_state': 'TAP_IRSHIFT'})
        return self.ftdi_.ftdi_execute_queue([cmd])
        
    def irscan_bytes(self, buf):
        fields = []
        size = len(buf)
        packet_size = self.ftdi_.mpsse_layer.ctx["max_packet_size"] >> 1
        remaining_bytes = size
        transferred  = 0
        while remaining_bytes:
            field = {}
            if remaining_bytes < packet_size:
                field["num_bits"] = (remaining_bytes)*8
                field["out_value"] = buf[transferred:]
                field["in_value"] = 0
                fields.append(field)
                remaining_bytes = 0
            else:
                field["num_bits"] = packet_size*8
                field["out_value"] = buf[transferred:transferred+packet_size]
                field["in_value"] = 0
                remaining_bytes -= packet_size
                transferred += packet_size
                fields.append(field)
        cmd = JTAG_CMD("JTAG_SCAN", {'ir_scan': 1, 'num_fields': len(fields), 'fields': fields, 'end_state': 'TAP_IDLE'})
        return self.ftdi_.ftdi_execute_queue([cmd])

        
    def drscan_bits(self, num_bits, val):
        cmd = JTAG_CMD("JTAG_SCAN",{'ir_scan': 0, 'num_fields': 1, 'fields': [{'num_bits': num_bits, 'out_value': [val], 'in_value': 0}], 'end_state': 'TAP_IDLE'})
        return self.ftdi_.ftdi_execute_queue([cmd])
        
    def drscan_bytes(self, buf):
        fields = []
        size = len(buf)
        packet_size = self.ftdi_.mpsse_layer.ctx["max_packet_size"] >> 1
        remaining_bytes = size
        transferred  = 0
        while remaining_bytes:
            field = {}
            if remaining_bytes < packet_size:
                field["num_bits"] = (remaining_bytes)*8
                field["out_value"] = buf[transferred:]
                field["in_value"] = 0
                fields.append(field)
                remaining_bytes = 0
            else:
                field["num_bits"] = packet_size*8
                field["out_value"] = buf[transferred:transferred+packet_size]
                field["in_value"] = 0
                remaining_bytes -= packet_size
                transferred += packet_size
                fields.append(field)
        cmd = JTAG_CMD("JTAG_SCAN", {'ir_scan': 0, 'num_fields': len(fields), 'fields': fields, 'end_state': 'TAP_IDLE'})
        return self.ftdi_.ftdi_execute_queue([cmd])

       
    def drscan_bytes_read(self,buf):
        fields = []
        size = len(buf)
        packet_size = self.ftdi_.mpsse_layer.ctx["max_packet_size"] >> 1
        remaining_bytes = size
        transferred  = 0
        while remaining_bytes:
            field = {}
            if remaining_bytes < packet_size:
                field["num_bits"] = remaining_bytes*8
                field["out_value"] = buf[transferred:]
                field["in_value"] = 1
                fields.append(field)
                remaining_bytes = 0
            else:
                field["num_bits"] = packet_size*8
                field["out_value"] = buf[transferred:transferred+packet_size]
                field["in_value"] = 1
                remaining_bytes -= packet_size
                transferred += packet_size
                fields.append(field)
        cmd = JTAG_CMD("JTAG_SCAN", {'ir_scan': 0, 'num_fields': len(fields), 'fields': fields, 'end_state': 'TAP_DRPAUSE'})
        ret = self.ftdi_.ftdi_execute_queue([cmd])
        self.statemove("TAP_IDLE")
        return  ret
        
    def control_write(self, control):
        self.irscan_bytes(self.jtag_user_reg)
        self.drscan_bytes([(control["0_31"]>>0)&255,(control["0_31"]>>8)&255,(control["0_31"]>>16)&255,(control["0_31"]>>24)&255,
                (control["32_63"]>>0)&255,(control["32_63"]>>8)&255,(control["32_63"]>>16)&255,(control["32_63"]>>24)&255,
                 (control["64_95"]>>0)&255,(control["64_95"]>>8)&255,(control["64_95"]>>16)&255,(control["64_95"]>>24)&255,self.CONTROL_WRITE_CMD])

    def program(self, file):
        CFG_IN = [0x24, 0x49, 0x16] #CFG_IN_SLR1
        JPROGRAM = [0xCB , 0xB2, 0x2C]
        JSTART = [0x0C, 0xC3, 0x30]
        self.reset()
        self.idle()
        self.irscan_bytes(JPROGRAM)
        self.irscan_bytes(CFG_IN)
        with open(file,'rb') as f:
            binary = f.read()
        binary = [int('{:08b}'.format(x)[::-1], 2) for x in binary]  
        #tx = "4b:03:03:19:01:00:24:49:1b:06:16:4b:02:03"
        #self.ftdi_.dev.mpsse_write([int(x,16) for x in tx.split(":")],100)
        self.drscan_bytes(binary)
        self.irscan_bytes(JSTART)
        for i in range(2000):
            self.idle()
        self.reset()
        self.reset()
        return