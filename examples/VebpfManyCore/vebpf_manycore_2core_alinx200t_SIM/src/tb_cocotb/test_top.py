"""

Copyright (c) 2023 ZAID TAHIR
Email: zaid.butt.tahir@gmai.com 

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

"""

import logging
import os
import sys
from scapy.all import *
# import glob

from scapy.layers.l2 import Ether, ARP
from scapy.layers.inet import IP, UDP, TCP

import cocotb_test.simulator

import cocotb
from cocotb.log import SimLog
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.triggers import Timer, Edge

from cocotbext.eth import GmiiFrame, RgmiiPhy

# test_sim includes
# add search paths seen from project root folder
# (used for vscode test integration)
# sys.path.insert(0, '../source')
# sys.path.insert(0, '../tools/ubpf')

# add search paths when run from inside test folder
# (used when running test directly)
# sys.path.insert(0, '../../VeBPF/DISL_FPGA_eBPF/source')
# sys.path.insert(0, '../../VeBPF/DISL_FPGA_eBPF/tools/ubpf')

# import unittest
    # the edited unittest_z1 is named as unittest and the original unittest is now unittest_original_version_uncomment_to_use_this cx colour_runner was trying to 
    # import unittest as well.. too many names changes were needed
# import unittest_z1 as unittest
# from '/home/zaidtahir/anaconda3/envs/hbpf_2/lib/python3.7/unittest_z1' import unittest
# from unittest_z1 import *
# from unittest_z1 import unittest as unittest
    # unittest library edited and put in new folder in virt env folder inside python3.7 folder... async and await statements added 
# import colour_runner.runner
# import os
import gc
import re
import tempfile
import struct
import re
import ntpath
# import ubpf.assembler
# import tools.testdata
from datetime import datetime
# from migen import *
# from litedram.frontend.bist import LFSR
# from fpga.ram import *
# from fpga.ram64 import *
# from fpga.cpu import *

# importing os module 
import os 
  
# importing shutil module 
import shutil

import time

PGM_DEPTH = 4096
RX_VEBPF_SIM = 1 #0
RISCV_PROGLOADER_SIM = 0 #1

# class TestFPGA_Sim(unittest.TestCase):
#     dbg_pgm_mem = []
#     test_var1 = []
#     pgm_LE_DW_list_VerilgEbpf = []
#     tb = None  # can use both type of references, self.tb and TestFPGA_Sim.tb
#         # Class variable: Shouldnt be defined in __init__ method if inteded to be used as class variable
#         # https://pynative.com/python-class-variables/#:~:text=of%20Class%20Variables-,What%20is%20an%20Class%20Variable%20in%20Python%3F,all%20instances%20of%20a%20class.
#             # can use both type of references, self.tb and TestFPGA_Sim.tb
#     iteration = 0
#     # iteration = None  # was able to use self.iteration after it was declared as None.. needed to modify it outside the object then?
#         # maybe I used iteration = 0 and not None thats why I could reference it as class variable using self.iteration?
#     # def __init__ (self, tb):
#     #     self.tb = tb


#     # async def initialize_cocotb_tb(self, tb):
#         # self.tb = tb
#         # tb = tb

#     # async def random_stuff_test(self): # ERROR still there # doesnt seem to run # ERROR RESOLVED by adding async # ERROR   Failed to import module test_cpu: 'await' outside async function (test_cpu.py, line 95)        
#     #     print("\n ***************Inside TestFPGA_Sim.random_stuff_test() ############# *******************\n")

#     #     print("Inside TestFPGA_Sim ==> 1 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
#     #     print("Inside TestFPGA_Sim ==> 1 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)

#     #     await RisingEdge(self.tb.dut.clk)
#     #     await RisingEdge(self.tb.dut.clk)

#     #     self.tb.dut.reset_n.setimmediatevalue(1)
#     #     self.tb.dut.csr_ctl.setimmediatevalue(1)

#     #     await RisingEdge(self.tb.dut.clk)
#     #     await RisingEdge(self.tb.dut.clk)

#     #     # print("Inside TestFPGA_Sim ==> 2 self.tb.dut.reset_n.value = ", TestFPGA_Sim.tb.dut.reset_n.value)
#     #     # print("Inside TestFPGA_Sim ==> 2 self.tb.dut.csr_ctl.value = ", TestFPGA_Sim.tb.dut.csr_ctl.value)
#     #         # can use both type of references, self.tb and TestFPGA_Sim.tb

#     #     print("Inside TestFPGA_Sim ==> 2 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
#     #     print("Inside TestFPGA_Sim ==> 2 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)
#     #     print("\n ***************############# *******************\n")

#     #     # print("\n ***************############# \n")
    

#     # # def check_datafile(self, filename): # ERROR: SyntaxError: 'await' outside async function
#     # # async def check_datafile(self, filename): 
#     #     # ERROR: /home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/test_cpu.py:684: RuntimeWarning: coroutine 'TestFPGA_Sim.check_datafile' was never awaited
#     #     # suite._tests[0].check_datafile(dummy1)
#     #     # RuntimeWarning: Enable tracemalloc to get the object allocation traceback


#     # async def random_stuff_test2(self): # ERROR still there # doesnt seem to run # ERROR RESOLVED by adding async # ERROR   Failed to import module test_cpu: 'await' outside async function (test_cpu.py, line 95)        
        
#     #     print("\n ***************Inside TestFPGA_Sim.check_datafile().random_stuff_test2() ############# *******************\n")

#     #     print("Inside TestFPGA_Sim ==> 1 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
#     #     print("Inside TestFPGA_Sim ==> 1 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)

#     #     await RisingEdge(self.tb.dut.clk)
#     #     await RisingEdge(self.tb.dut.clk)
#     #     # ERROR: SyntaxError: 'await' outside async function

#     #     self.tb.dut.reset_n.setimmediatevalue(0)
#     #     self.tb.dut.csr_ctl.setimmediatevalue(0)

#     #     await RisingEdge(self.tb.dut.clk)
#     #     await RisingEdge(self.tb.dut.clk)

#     #     print("Inside TestFPGA_Sim ==> 2 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
#     #     print("Inside TestFPGA_Sim ==> 2 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)
        
#     #     await RisingEdge(self.tb.dut.clk)
#     #     await RisingEdge(self.tb.dut.clk)

#     #     self.tb.dut.reset_n.setimmediatevalue(1)
#     #     self.tb.dut.csr_ctl.setimmediatevalue(1)

#     #     await RisingEdge(self.tb.dut.clk)
#     #     await RisingEdge(self.tb.dut.clk)

#     #     print("Inside TestFPGA_Sim ==> 2 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
#     #     print("Inside TestFPGA_Sim ==> 2 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)

#     #     print("\n ***************############# *******************\n")
    

#     async def check_datafile(self, filename):  # comment this cx async check_datafile isnt working OR maybe I'll edit the whole unittest library (:)
#     # def check_datafile(self, filename):
#         """
#         Given assembly source code and an expected result, run the eBPF program and
#         verify that the result matches.
#         """

#         # print("\n\n awaiting self.random_stuff_test2()")
#         # self.random_stuff_test3()

#         # yield self.random_stuff_test2()
        
#         # await self.random_stuff_test2()
#             # Still getting ERROR: test_cpu.TestFPGA_Sim
#             # test_jeq-imm_z1 ... /home/zaidtahir/anaconda3/envs/hbpf_2/lib/python3.7/unittest/case.py:628: RuntimeWarning: coroutine 'generate_testcase.<locals>.test' was never awaited
#             # testMethod()
#             # RuntimeWarning: Enable tracemalloc to get the object allocation traceback
#             # ok

        
#         # self.random_stuff_test2()
#             # ERROR: /home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/test_cpu.py:163: RuntimeWarning: coroutine 'TestFPGA_Sim.random_stuff_test2' was never awaited
#             # self.random_stuff_test2()
#             # RuntimeWarning: Enable tracemalloc to get the object allocation traceback
#                 # searching for RuntimeWarning (ctrl F)
#             # Also error in main test method, test_cpu.TestFPGA_Sim
#             # test_jeq-imm_z1 ... /home/zaidtahir/anaconda3/envs/hbpf_2/lib/python3.7/unittest/case.py:628: RuntimeWarning: coroutine 'generate_testcase.<locals>.test' was never awaited
#             # testMethod()
#             # RuntimeWarning: Enable tracemalloc to get the object allocation traceback
#             # ok



#         # deleting self.random_stuff_test2() code from here

#         ##################### resetting verilog-eBPF cpu pgm memory before each test suite is executed #######################

#         # Setting reset HIGH for V-eBPF
#         # self.tb.dut.reset_n.setimmediatevalue(0)
#         # self.tb.dut.csr_ctl.setimmediatevalue(0)
#         # await RisingEdge(self.tb.dut.clk)
#         # await RisingEdge(self.tb.dut.clk)

#         # print("Inside check_datafile ==> 2 self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
#         # print("Inside check_datafile ==> 2 self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)

#         # need to reset and then load pgm mem in V-eBPF while it is in reset state, then set RESET to LOW to start the V-eBPF
#         for idx in range(PGM_DEPTH):
#             self.tb.dut.eth_network_interface_controller.eth_fifo_to_bram.VeBPF.pgm.mem[idx].value = 0
#             # self.tb.dut.pgm.mem[idx].value = 0

#         await RisingEdge(self.tb.dut.clk)


#         print()

#         td = tools.testdata.read(filename)
#         td['filename'] = filename
#         td['name'] = os.path.splitext(os.path.split(filename)[1])[0]

#         self.assertFalse('asm' not in td and 'raw' not in td,
#                     'no asm or raw section in datafile')

#         #self.assertFalse('result' not in td and 'error' not in td and 'error pattern' not in td,
#         #            'no result or error section in datafile')

#         # Prepare program memory
#         if 'raw' in td:
#             code = b''.join(struct.pack('>Q', x) for x in td['raw'])
#         else:
#             code = ubpf.assembler.assemble(td['asm'])
#             td['raw'] = code

#         # // print assembly code
#         # print("----- z Assembly code -----")
#         # print(td['asm'])
#             # throwing error for RAW code 

#         half_words = len(code) // 4
#         pgm_mem = list(struct.unpack('>{}L'.format(half_words), code))  # = means we use native endian to unpack
#         # endian in ubuntu is little endian thats why the code unpacked in little endian and the VM here runs on little endian as well
#             # lscpu | grep Endian
#             # Byte Order:                      Little Endian

#         # // print code td['raw'] vs pgm_mem
#         print("\n \n print code td['raw'] vs pgm_mem \n \n")
#         print("\n \n print code td['raw'] \n \n")
#         print(td['raw'])
#         # print("\n \n print code pgm_mem \n \n")
#         # print(pgm_mem)
#         # print("\n \n")

#         print("\n \n print code code \n \n")
#         print(code)
#         print("\n \n")


#         # print("\n \n print code pgm_mem \n \n")
#         # # print(pgm_mem)
#         # for x in pgm_mem:
#         #     print(hex(x))
#         #     # print(x)
#         # print("\n \n")

#         # Dump program memory for debug.
#         print("----- Program memory -----")
#         words = len(code) // 8
#         print("len(code) = ", len(code))
#         print("words", words)
#             # len(code) =  64   # 64 bytes
#             # words 8           # 8 64-bit DWs
#             # so code is in form of bytes

#         pgm_bytes_len = len(code)  # 64 bytes i.e., 64 bytes x 8 bits/byte 

#         # print("printing byte code[12] in hex = ", hex(code[12]))
#         # print("printing byte code[12] in bytes = ", code[12].to_bytes(length=1, byteorder='big').hex())    
#         #     # int.to_bytes(length=1, byteorder='big', *, signed=False)¶

#         dbg_pgm_mem = list(struct.unpack('>{}Q'.format(words), code))
#             # https://docs.python.org/3/library/struct.html#struct-alignment
#             # Format    C Type                  Python type     Standard size
#             # Q         unsigned long long      integer             8
#             # B         unsigned char           integer             1

#         self.dbg_pgm_mem = dbg_pgm_mem
#         # TestFPGA_Sim.dbg_pgm_mem = dbg_pgm_mem
#         self.test_var1 = dbg_pgm_mem

#         dbg_pgm_mem_BYTES = list(struct.unpack('>{}B'.format(pgm_bytes_len), code))

        
#         # print("\n \n print code dbg_pgm_mem \n \n")
#         # for x in dbg_pgm_mem:
#         #     print(hex(x))
#             # print(x)
#             # machine_instruction_64bit_DW.append()
#         # print(dbg_pgm_mem)
#         # print("\n \n")

#         # print("\n \n print code dbg_pgm_mem_BYTES \n \n")
#         # for x in dbg_pgm_mem_BYTES:
#         #     print(hex(x))  # output same as for loop output of printing code below

#         # print("\n \n print code code using for loop \n \n")
#         counter_pgm_DWbytes = 0
#         counter_pgm_DWs = 0
#         machine_instruction_64bit_DW = [0] * 8   # init array
#         pgm_DW_rearranged_For_VerilgEbpf = [0] * 8   # init array
#         pgm_LE_DW_list_VerilgEbpf = []
        
#         for code_byte in code:
#             # print(hex(code_byte))
            
#             machine_instruction_64bit_DW[counter_pgm_DWbytes] = code_byte
            
#             counter_pgm_DWbytes = counter_pgm_DWbytes + 1
            
#             if (counter_pgm_DWbytes == 8):  # bytes counter 0 till 7 appended
#                 counter_pgm_DWs = counter_pgm_DWs + 1
                
#                 pgm_DW_rearranged_For_VerilgEbpf[0] = machine_instruction_64bit_DW[0]
#                 pgm_DW_rearranged_For_VerilgEbpf[1] = machine_instruction_64bit_DW[1]
#                 # flipping for Byte 5-6 below
#                 pgm_DW_rearranged_For_VerilgEbpf[2] = machine_instruction_64bit_DW[3]
#                 pgm_DW_rearranged_For_VerilgEbpf[3] = machine_instruction_64bit_DW[2]
#                 # flipping for Byte 1-4 below
#                 pgm_DW_rearranged_For_VerilgEbpf[4] = machine_instruction_64bit_DW[7]
#                 pgm_DW_rearranged_For_VerilgEbpf[5] = machine_instruction_64bit_DW[6]
#                 pgm_DW_rearranged_For_VerilgEbpf[6] = machine_instruction_64bit_DW[5]
#                 pgm_DW_rearranged_For_VerilgEbpf[7] = machine_instruction_64bit_DW[4]
                
#                     # // MSB                                                        LSB
#                     # //   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
#                     # //   // +--------+----+----+----------------+------------------------+
#                     # //   // |opcode  | src| dst|          offset|               immediate|
#                     # //   // +--------+----+----+----------------+------------------------+
#                     # //   // 63     56   52   48               32 
#                     # mem [0] = {8'h7a, 8'h01, 16'h0002, 32'h44332211};  // byte 1 - 4 means these bytes are flipped: L.E => 11223344 becomes -> 44332211 // same for other instruction op codes
                
#                 counter_pgm_DWbytes = 0  #reset counter
                
#                 # pgm_LE_DW_list_VerilgEbpf.append(pgm_DW_rearranged_For_VerilgEbpf)
#                     # https://stackoverflow.com/questions/42955147/append-is-overwriting-existing-data-in-list
#                         # append was causing the overwrite of all list elements by last element of list in stack, by reference, hence .copy() is used
#                 pgm_LE_DW_list_VerilgEbpf.append(pgm_DW_rearranged_For_VerilgEbpf.copy())
                
#                 # print("pgm_LE_DW_list_VerilgEbpf ",  pgm_LE_DW_list_VerilgEbpf[counter_pgm_DWs-1])
                
#                 # for pgm_DW_INDEX in range((len(pgm_LE_DW_list_VerilgEbpf))):
#                 #     # print("pgm_LE_DW_list_VerilgEbpf ",  " ".join(hex(x) for x in pgm_LE_DW_list_VerilgEbpf[pgm_DW_INDEX]),end="   ")
#                 #     print("pgm_LE_DW_list_VerilgEbpf ",  " ".join(hex(x) for x in pgm_LE_DW_list_VerilgEbpf[pgm_DW_INDEX]))


#                 # if (counter_pgm_DWs == 3):
#                 #     print("pgm_DW_rearranged_For_VerilgEbpf = ", " ".join(hex(x) for x in pgm_DW_rearranged_For_VerilgEbpf))               
                    
#                 #     sys.exit()
#         print("\n \n *********  print pgm_LE_DW_list_VerilgEbpf ***** \n \n")
#         DW_count = 0
#         for DW in pgm_LE_DW_list_VerilgEbpf:
#             # print("Printing each byte in list of pgm_LE_DW_list_VerilgEbpf = ", DW.hex())
#             print("\n pgm_LE_DW_list_VerilgEbpf[%d] = " % DW_count, end= "")
#             for byte in DW:
#                 print(hex(byte), end=",  ")
#             DW_count = DW_count + 1

#         self.pgm_LE_DW_list_VerilgEbpf = pgm_LE_DW_list_VerilgEbpf

#         print("\n \n print code dbg_pgm_mem \n \n")
#         for i, opc in enumerate(dbg_pgm_mem):
#            print("%04d: %016x" % (i, opc))

#         print("\n\n Preparing data memory \n \n")

#         # Prepare data memory
#         data_mem = td.get('mem')
#         data_mem_flag = 0
#         if isinstance(data_mem, bytes):
#             data_mem = list(data_mem)
#             data_mem_flag = 1

#         # first initialize all data_memory to 0 
#         # data_mem_depth = self.tb.dut.data_mem.MEMORY_DEPTH  # parameters can be accessed this way 
#         data_mem_depth = self.tb.dut.eth_network_interface_controller.eth_fifo_to_bram.VeBPF.data_mem.MEMORY_DEPTH  # parameters can be accessed this way 
        
#         print(f'data_mem_depth = {data_mem_depth} \n')
        
#         for i in range(int(data_mem_depth)):
#             # self.tb.dut.data_mem.mem[i].value = 0
#             self.tb.dut.eth_network_interface_controller.eth_fifo_to_bram.VeBPF.data_mem.mem[i].value = 0

#         await RisingEdge(self.tb.dut.clk)

#         if (data_mem_flag):
#             for i, data in enumerate(data_mem):
#                 print(f'data_mem[{i}] = {hex(data)}')
#                 # self.tb.dut.data_mem.mem[i].value = data
#                 self.tb.dut.eth_network_interface_controller.eth_fifo_to_bram.VeBPF.data_mem.mem[i].value = data
#         else:
#             print("\n No data_mem on initialization \n")

#         await RisingEdge(self.tb.dut.clk)

#         if(data_mem_flag):
#             for i, data in enumerate(data_mem):
#                 # print(f'self.tb.dut.data_mem.mem[{i}] = {hex(self.tb.dut.data_mem.mem[i].value)}')
#                 print(f'self.tb.dut.data_mem.mem[{i}] = {hex(self.tb.dut.eth_network_interface_controller.eth_fifo_to_bram.VeBPF.data_mem.mem[i].value)}')


#         # Inserting pgm memory in V-eBPF cpuz pgm memory 

#         print("\n Setting debug = 1 for the verilog dump module \n")
#         # self.tb.dut.dump_file_module.myString = "Testing123.fst"
#         # self.tb.dut.dump_file_module.my_string = 1
#         # self.tb.dut.dump_file_module.xyz = 12

#         vcd_file = os.path.abspath(os.path.dirname(filename))
#         vcd_file = os.path.join(vcd_file, td['name'] + ".fst")
#         sim_fst_file_name_only = td['name'] + ".fst"

#         # print("\n vcd file name = ", vcd_file)
#             #  vcd file name =  /home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/data9_DISL_eBPF/jge-imm.fst


#         # print("\n sim_fst.fst file name = ", sim_fst_file_name_only)

#         # simulation_dump_name = sim_fst_file_name_only

#         # simulation_dump_name = "Testing123.fst"
        
#         # int_value_of_file_name = int.from_bytes(simulation_dump_name.encode('utf-8'), byteorder='big', signed=False)
        
#         # int_value_of_file_name = int.from_bytes("Testing123.fst".encode('utf-8'), byteorder='big', signed=False)
        
#         # self.tb.dut.dump_file_module.my_string.value = int.from_bytes("Testing123.fst".encode('utf-8'), byteorder='big', signed=False)
#         # self.tb.dut.dump_file_module.my_string.value = int_value_of_file_name
#         # self.tb.dut.eth_network_interface_controller.eth_fifo_to_bram.VeBPF.dump_file_module.my_string.value = int_value_of_file_name
#             # print("Hello world")
#             # x = int.from_bytes("Testing123.fst".encode('utf-8'), byteorder='big', signed=False)
#             # print(x)

#             # print((x.bit_length()))
#             # OUTPUT
#             # Hello world
#             # 1711760182630090602017480629449588
#             # 111

#         # self.tb.dut.dump_file_module.size_bits_string.value = int_value_of_file_name.bit_length()
#         # self.tb.dut.dump_file_module.STRING_SIZE.value = int_value_of_file_name.bit_length()

#         # *************************************************************************
#         # ************* IMP: Enable Waveform Output ******************************* => debug flag to start tracing simulation waveform, comment out if dont want sim waveform
#         # *************************************************************************
#         # self.tb.dut.dump_file_module.debug_flag.value = 1
        
#         # self.tb.dut.dump_file_module.debug_flag2.value = 1
#         # self.tb.dut.dump_file_module.my_string.value = 12
        
        
        
#         # self.tb.dut.dump_file_module.my_string.value = int(float("Testing123.fst"))
#         # self.tb.dut.dump_file_module.my_string.value = int("Testing123.fst")
#         # self.tb.dut.dump_file_module.my_string.value = "Testing123.fst"
#         # self.tb.dut.dump_file_module.myString.value = "Testing123.fst"

#         # vcd_file = os.path.abspath(os.path.dirname(filename))
#         # vcd_file = os.path.join(vcd_file, td['name'] + ".vcd")
#         # print("vcd_file = ", )

#         # await RisingEdge(self.tb.dut.clk)  # always_comb so no need of clk

#         # Re-arranging the program memory so each eBPF machine instruction comes out as a 64 bit DW, arranged
#         # w.r.t what our eBPF cpu requires it to be, for testing and updating program memory here 
#         DW_count = 0
#         pgm_DW = 0
#         byte_count = 0
#         for DW in pgm_LE_DW_list_VerilgEbpf:
#             byte_count = 0
#             pgm_DW = 0
#             for byte in DW:
#                 if (byte_count == 0):
#                     pgm_DW = byte
#                 else:
#                     pgm_DW = (pgm_DW << 8) + byte
#                 # dut.pgm.mem[DW_count][(byte_count*8):(((byte_count*8)+8)-1)] = byte  
#                     # ERROR: IndexError: Slice indexing is not supported
#                 byte_count = byte_count + 1
#             # self.tb.dut.pgm.mem[DW_count] = pgm_DW
#             self.tb.dut.eth_network_interface_controller.eth_fifo_to_bram.VeBPF.pgm.mem[DW_count] = pgm_DW
#             DW_count = DW_count + 1

#         # dut.pgm.mem[1] = 0xb40700000a000000

#         await RisingEdge(self.tb.dut.clk)

#         # print("Inside check_datafile ==>  dut.pgm.mem[1] = ", hex(self.tb.dut.pgm.mem[1].value))
#         print("Inside check_datafile ==>  dut.pgm.mem[1] = ", hex(self.tb.dut.eth_network_interface_controller.eth_fifo_to_bram.VeBPF.pgm.mem[1].value))

#         DW_count = 0
#         for DW in pgm_LE_DW_list_VerilgEbpf:
#             # print(f'For loop After updating thru unittest ==> dut.pgm.mem[{DW_count}] = {hex(self.tb.dut.pgm.mem[DW_count].value)}')
#             print(f'For loop After updating thru unittest ==> dut.pgm.mem[{DW_count}] = {hex(self.tb.dut.eth_network_interface_controller.eth_fifo_to_bram.VeBPF.pgm.mem[DW_count].value)}')
#             # print("For loop After updating thru Inside check_datafile ==> dut.pgm.mem[] = ", hex(self.tb.dut.pgm.mem[DW_count].value))
#             DW_count = DW_count + 1
#             # After updating thru unittest ==> dut.pgm.mem[1] =  0xb40700000000000a

#         for k in range(10):
#                 await RisingEdge(self.tb.dut.clk)


#         # print("Inside check_datafile ==> self.tb.dut.reset_n.value = ", self.tb.dut.reset_n.value)
#         # print("Inside check_datafile ==> self.tb.dut.csr_ctl.value = ", self.tb.dut.csr_ctl.value)
        


#         print(" RUNNING V_eBPF_cpu_test inside check_datafile")

#         # await self.V_eBPF_cpu_test(test_data = td)
#         print("******************* self.iteration = ", TestFPGA_Sim.iteration)
#         # print("******************* self.iteration = ", self.iteration)

#         # resetting debug flag for dumping waveform data
#         # self.tb.dut.dump_file_module.debug_flag.value = 0
#         # await RisingEdge(self.tb.dut.clk)

#         ''' Decision right now is that every waveform will have to be generated separetly .. or a separate cocotb test bench would have to be run each time for each unitest cx dumpfiles doesnt create 
#         separate files.. 
#         next step, test against all steps.. first the migen sim file then our verilog 

#         # Source path with file name 
#         # source = "/home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/" + simulation_dump_name 
#         source = "/home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/" + "jeq-imm_z1.fst" 
#             #  vcd file name =  /home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/data9_DISL_eBPF/jge-imm.fst

#         # destination = "/home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/sim_files/" + simulation_dump_name + str(self.iteration)
#         destination = "/home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/sim_files/" + str(TestFPGA_Sim.iteration)

#         # Move the content of 
#         # source to destination
#         dest = shutil.move(source, destination) 
        
#         # Print path of newly 
#         # created file 
#         print("Destination path:", dest) 

#         TestFPGA_Sim.iteration = TestFPGA_Sim.iteration + 1
#         # print("******************* AFter 1 update TestFPGA_Sim.iteration = ", TestFPGA_Sim.iteration)
#         '''

#         # Set reset to LOW and start the eBPF CPU and its processing!!!!!!!!!!!!!!!!!!!!! We have already uploaded the prog memory!
#         # dut.reset_n.setimmediatevalue(1)            
#         # dut.csr_ctl.setimmediatevalue(1)

#         ''' BLOCK COMMENTS
#         # Instantiate simulated CPU
#         #vcd_file = os.path.abspath(os.path.dirname(__file__))
#         #vcd_file = os.path.join(vcd_file, __name__ + ".vcd")
#         vcd_file = os.path.abspath(os.path.dirname(filename))
#         vcd_file = os.path.join(vcd_file, td['name'] + ".vcd")
        
#         import inspect
#         print("inspecting method run_simulation")
#         print(inspect.getfile(run_simulation))  # inspecting where this func came from
#         # inspecting method run_simulation
#         # /home/zaidtahir/projects/hbpf_2/migen/migen/sim/core.py

#         if inspect.ismethod(run_simulation):
#             the_class = run_simulation.__self__.__class__
#             print("simulation class is = ", the_class)
#             # print("simulation class is = ")

#         print("Printing run_simulation module = ",run_simulation.__module__)
#         print("Printing run_simulation whole path of the file = ", run_simulation.__globals__['__file__'])
#         # Printing run_simulation module =  migen.sim.core
#         # Printing run_simulation whole path of the file =  /home/zaidtahir/projects/hbpf_2/migen/migen/sim/core.py
        
#         '''

#         # cpu = CPU(pgm_init=pgm_mem, data_init=data_mem, debug=True, call_handler=CallHandler())
#         # run_simulation(cpu, self.cpu_test(cpu, td, default_max_clock_cycles=1000),
#         #                vcd_name=vcd_file)
#             # SO RUN SIMULATION WAS DONE INSIDE CHECK DATA FILE METHOD

#         # generating verilog dump of RAM for data memory (not RAM64)
#             # already generated so commenting out the generation code 

#         # MAX_DATA_WORDS = 2048
#         # # hbpf data memory (e.g packet data).
        
#         # ram_dut = RAM(init=data_mem, max_words=MAX_DATA_WORDS,
#         #       write_capable=True, csr_access=True, debug=True)
        
#         # from migen.fhdl.verilog import convert

#         # convert(ram_dut).write("ram_dut.v")

#         # generating verilog dump of RAM64 for pgm (not RAM)

#         # max_pgm_words = 4096

#         # # hbpf program memory.
#         # ram64_pgm_dut = pgm = RAM64(
#         #                         max_words=max_pgm_words,
#         #                         init=pgm_mem,
#         #                         debug=True)

#         # from migen.fhdl.verilog import convert
#         # convert(ram64_pgm_dut).write("ram64_pgm_dut.v")

#     '''
#     # async def V_eBPF_cpu_test(self, cpu, test_data, default_max_clock_cycles=1000):
#     # async def V_eBPF_cpu_test(self, test_data, default_max_clock_cycles=1000+10000):  # max clock cycles increased # didnt need to increase the max clock cycles
#     async def V_eBPF_cpu_test(self, test_data, default_max_clock_cycles=1000):
#         """
#         Perform actual test, control CPU signals like clock etc.
#         """

#         clk_cnt = 0

#         # Prepare result to check
#         result = None
#         if 'result' in test_data:
#             result = int(test_data['result'], 0)
#             # overwriting this test case z
#             # result = 0

#         expected_error = 0
#         expected_error_msg = None
#         if 'error' in test_data:
#             expected_error = 1
#             expected_error_msg = test_data['error']

#         expected = dict(re.findall(r'(\S+)\s*=\s*(".*?"|\S+)', test_data.get('expected', '')))
#         #print(expected)
#         expected_halt = 1 if int(expected.get('halt', '1'), 0) > 0 else 0
#         # this can override error section above
#         expected_error = 1 if int(expected.get('error', str(expected_error)), 0) > 0 else 0
#         # overwriting above z
#         # expected_error = 1

#         max_clock_cycles = int(expected.get('clocks', str(default_max_clock_cycles)), 0)
#         disable_test = int(expected.get('disable_sim_test', str("0")))

#         if disable_test == 1:
#             self.skipTest("Testcase not available for Simulator test")

#         # Start with 5 clocks in reset.
        
#         # yield cpu.reset_n.eq(0)
#         self.tb.dut.reset_n.value = 0  # RESET HIGH
        
#         for i in range(5):
#             # yield
#             await RisingEdge(self.tb.dut.clk)

#         # set r1 - r5 input arguments
#         args = test_data.get('args', {})
#         r1 = int(str(args.get('r1', 0)), 0)
#         r2 = int(str(args.get('r2', 0)), 0)
#         r3 = int(str(args.get('r3', 0)), 0)
#         r4 = int(str(args.get('r4', 0)), 0)
#         r5 = int(str(args.get('r5', 0)), 0)
#         # yield cpu.csr_r1.storage.eq(r1)
#         # yield cpu.csr_r2.storage.eq(r2)
#         # yield cpu.csr_r3.storage.eq(r3)
#         # yield cpu.csr_r4.storage.eq(r4)
#         # yield cpu.csr_r5.storage.eq(r5)
#         # yield

#         self.tb.dut.r1.value = r1
#         self.tb.dut.r2.value = r2
#         self.tb.dut.r3.value = r3
#         self.tb.dut.r4.value = r4
#         self.tb.dut.r5.value = r5
#         await RisingEdge(self.tb.dut.clk)

#         print("Input:")
#         print("R1: ({:20}, 0x{:016x}), R2: ({:20}, 0x{:016x})".format(r1, r1, r2, r2))
#         print("R3: ({:20}, 0x{:016x}), R4: ({:20}, 0x{:016x})".format(r3, r3, r4, r4))
#         print("R5: ({:20}, 0x{:016x})".format(r5, r5))

#         # Open op-code statistics file
#         test_file = test_data.get("filename", None)
#         stat_file = None
#         if test_file is not None:
#             stat_file = os.path.splitext(test_file)[0] + ".stats"
#             sfd = open(stat_file, "a")

#         # End reset.
#         self.tb.dut.reset_n.value = 1  # RESET LOW 
#         await RisingEdge(self.tb.dut.clk)
#         # yield cpu.reset_n.eq(1)
#         # yield


#         # Clock CPU until halt, error or max clock cycles reached.
#         # halt = (yield cpu.halt)
#         # error = (yield cpu.error)
#         # r0 = (yield cpu.r0)

#         halt = self.tb.dut.halt.value
#         error = self.tb.dut.error.value
#         r0 = self.tb.dut.r0.value



#         while halt == 0 and clk_cnt <= max_clock_cycles:
#             # break while loop when halt = 1 means our ebpf cpu finihsed processing
#             # or the max clk cycles have been reached 
            
#             halt = self.tb.dut.halt.value
#             error = self.tb.dut.error.value
#             r0 = self.tb.dut.r0.value
#             r6 = self.tb.dut.r6.value 
#             r7 = self.tb.dut.r7.value
#             r8 = self.tb.dut.r8.value 
#             r9 = self.tb.dut.r9.value
#             r10 = self.tb.dut.r10.value 
#             await RisingEdge(self.tb.dut.clk)
            
#             # halt = (yield cpu.halt)
#             # error = (yield cpu.error)
#             # r0 = (yield cpu.r0)
#             # r6 = (yield cpu.r6)
#             # r7 = (yield cpu.r7)
#             # r8 = (yield cpu.r8)
#             # r9 = (yield cpu.r9)
#             # r10 = (yield cpu.r10)
#             # yield
            
#             if not halt: # means halt is 0
#                 clk_cnt += 1

#         print("Output:")
#         if result is None:
#             # print("Clock cycles: ({}), halt: ({}), error: ({}), R0: ({:20}, 0x{:016x})".format(
#             print("Clock cycles: ({}), halt: ({}), error: ({}), R0: (b'{}, d'{}, 0x{})".format(
#                 clk_cnt,
#                 "LOW" if halt == 0 else "HIGH",
#                 # "LOW" if error == 0 else "HIGH", r0, r0))
#                 "LOW" if error == 0 else "HIGH", r0, int(r0), hex(r0)))

#             # Error
#             # print("Clock cycles: ({}), halt: ({}), error: ({}), R0: (b'{}, d'{}, 0x{}), expected R0: (d'{}, 0x{})".format(
#             #     clk_cnt,
#             #     "LOW" if halt == 0 else "HIGH",
#             #     # "LOW" if error == 0 else "HIGH", r0, r0))
#             #     "LOW" if error == 0 else "HIGH", r0, int(r0), hex(r0), result, hex(result)))

#         else:
#             print("Clock cycles: ({}), halt: ({}), error: ({}), R0: (b'{}, d'{}, 0x{}), expected R0: (d'{}, 0x{})".format(
#                 clk_cnt,
#                 "LOW" if halt == 0 else "HIGH",
#                 # "LOW" if error == 0 else "HIGH", r0, r0))
#                 "LOW" if error == 0 else "HIGH", r0, int(r0), hex(r0), result, hex(result)))



#         # print("R6: ({:20}, 0x{:016x}), R7: ({:20}, 0x{:016x})".format(r6, r6, r7, r7))
#         print("R6: ({}, 0x{}), R7: ({}, 0x{})".format(r6, hex(r6), r7, hex(r7)))

#         # print("R8: ({:20}, 0x{:016x}), R9: ({:20}, 0x{:016x})".format(r8, r8, r9, r9))
#         print("R8: ({}, 0x{}), R9: ({}, 0x{})".format(r8, hex(r8), r9, hex(r9)))
        
#         # print("R10:({:20}, 0x{:016x})".format(r10, r10))
#         print("R10:({}, 0x{})".format(r10, hex(r10)))

#         # Write clock cycles for this test to statistics file
#         if stat_file is not None:
#             do_graph = int(str(args.get('graph', 1)), 0)
#             do_graph = 1 if do_graph > 0 else 0
#             date = datetime.now().strftime("%Y%m%d-%H%M%S")
#             sfd.write("\"SIM\",\"{}\",{},{},{},{}\n".format(date, clk_cnt, halt, error, do_graph))
#             sfd.close()

#         # Check result
#         #if not expected_error:
#         #    self.assertEqual(error, 0,
#         #        "Action completes with error signal HIGH")
#         #else:
#         #    self.assertEqual(error, 1,
#         #        "Action expected to complete with error signal HIGH but was LOW")
#         #    if error_expected_msg is not None:
#         #        print("Expected error: {}".format(error_expected_msg))
#         #    return

#         self.assertEqual(error, expected_error,
#             ("Action does not complete with expected error signal level; " +
#                 "was {} should be {}").format(error, expected_error))

#         self.assertLessEqual(clk_cnt, max_clock_cycles,
#             "Action did not complete within max clock cycles ({})".format(
#                 max_clock_cycles))

#         self.assertEqual(halt, expected_halt,
#             ("Action does not complete with expected halt signal level; " +
#                 "was {} should be {}").format(halt, expected_halt))

#         # if result is not None:
#         #     self.assertEqual(r0, result,
#         #         ("Received result ({}, 0x{:08x}) not equal expected " +
#         #         "({}, 0x{:08x})").format(
#         #             r0, r0, result, result))

#         if result is not None:
#             self.assertEqual(r0, result,
#                 ("Received result (b'{}, d'{}, 0x{}) not equal expected " +
#                 "(d'{}, 0x{})").format(
#                     r0, int(r0), hex(r0), result, hex(result)))
#     '''

#     ''' BLOCK COMMENTS
#     def cpu_test(self, cpu, test_data, default_max_clock_cycles=1000):
#         """
#         Perform actual test, control CPU signals like clock etc.
#         """

#         clk_cnt = 0

#         # Prepare result to check
#         result = None
#         if 'result' in test_data:
#             result = int(test_data['result'], 0)
#             # overwriting this test case z
#             # result = 0

#         expected_error = 0
#         expected_error_msg = None
#         if 'error' in test_data:
#             expected_error = 1
#             expected_error_msg = test_data['error']

#         expected = dict(re.findall(r'(\S+)\s*=\s*(".*?"|\S+)', test_data.get('expected', '')))
#         #print(expected)
#         expected_halt = 1 if int(expected.get('halt', '1'), 0) > 0 else 0
#         # this can override error section above
#         expected_error = 1 if int(expected.get('error', str(expected_error)), 0) > 0 else 0
#         # overwriting above z
#         # expected_error = 1

#         max_clock_cycles = int(expected.get('clocks', str(default_max_clock_cycles)), 0)
#         disable_test = int(expected.get('disable_sim_test', str("0")))

#         if disable_test == 1:
#             self.skipTest("Testcase not available for Simulator test")

#         # Start with 5 clocks in reset.
#         yield cpu.reset_n.eq(0)
#         for i in range(5):
#             yield

#         # set r1 - r5 input arguments
#         args = test_data.get('args', {})
#         r1 = int(str(args.get('r1', 0)), 0)
#         r2 = int(str(args.get('r2', 0)), 0)
#         r3 = int(str(args.get('r3', 0)), 0)
#         r4 = int(str(args.get('r4', 0)), 0)
#         r5 = int(str(args.get('r5', 0)), 0)
#         yield cpu.csr_r1.storage.eq(r1)
#         yield cpu.csr_r2.storage.eq(r2)
#         yield cpu.csr_r3.storage.eq(r3)
#         yield cpu.csr_r4.storage.eq(r4)
#         yield cpu.csr_r5.storage.eq(r5)
#         yield

#         print("Input:")
#         print("R1: ({:20}, 0x{:016x}), R2: ({:20}, 0x{:016x})".format(r1, r1, r2, r2))
#         print("R3: ({:20}, 0x{:016x}), R4: ({:20}, 0x{:016x})".format(r3, r3, r4, r4))
#         print("R5: ({:20}, 0x{:016x})".format(r5, r5))

#         # Open op-code statistics file
#         test_file = test_data.get("filename", None)
#         stat_file = None
#         if test_file is not None:
#             stat_file = os.path.splitext(test_file)[0] + ".stats"
#             sfd = open(stat_file, "a")

#         # End reset.
#         yield cpu.reset_n.eq(1)
#         yield

#         # Clock CPU until halt, error or max clock cycles reached.
#         halt = (yield cpu.halt)
#         error = (yield cpu.error)
#         r0 = (yield cpu.r0)

#         while halt == 0 and clk_cnt <= max_clock_cycles:
#             # break while loop when halt = 1 means our ebpf cpu finihsed processing
#             # or the max clk cycles have been reached 
#             halt = (yield cpu.halt)
#             error = (yield cpu.error)
#             r0 = (yield cpu.r0)
#             r6 = (yield cpu.r6)
#             r7 = (yield cpu.r7)
#             r8 = (yield cpu.r8)
#             r9 = (yield cpu.r9)
#             r10 = (yield cpu.r10)
#             yield
#             if not halt: # means halt is 0
#                 clk_cnt += 1

#         print("Output:")
#         print("Clock cycles: ({}), halt: ({}), error: ({}), R0: ({:20}, 0x{:016x})".format(
#             clk_cnt,
#             "LOW" if halt == 0 else "HIGH",
#             "LOW" if error == 0 else "HIGH", r0, r0))

#         print("R6: ({:20}, 0x{:016x}), R7: ({:20}, 0x{:016x})".format(r6, r6, r7, r7))
#         print("R8: ({:20}, 0x{:016x}), R9: ({:20}, 0x{:016x})".format(r8, r8, r9, r9))
#         print("R10:({:20}, 0x{:016x})".format(r10, r10))

#         # Write clock cycles for this test to statistics file
#         if stat_file is not None:
#             do_graph = int(str(args.get('graph', 1)), 0)
#             do_graph = 1 if do_graph > 0 else 0
#             date = datetime.now().strftime("%Y%m%d-%H%M%S")
#             sfd.write("\"SIM\",\"{}\",{},{},{},{}\n".format(date, clk_cnt, halt, error, do_graph))
#             sfd.close()

#         # Check result
#         #if not expected_error:
#         #    self.assertEqual(error, 0,
#         #        "Action completes with error signal HIGH")
#         #else:
#         #    self.assertEqual(error, 1,
#         #        "Action expected to complete with error signal HIGH but was LOW")
#         #    if error_expected_msg is not None:
#         #        print("Expected error: {}".format(error_expected_msg))
#         #    return

#         self.assertEqual(error, expected_error,
#             ("Action does not complete with expected error signal level; " +
#                 "was {} should be {}").format(error, expected_error))

#         self.assertLessEqual(clk_cnt, max_clock_cycles,
#             "Action did not complete within max clock cycles ({})".format(
#                 max_clock_cycles))

#         self.assertEqual(halt, expected_halt,
#             ("Action does not complete with expected halt signal level; " +
#                 "was {} should be {}").format(halt, expected_halt))

#         if result is not None:
#             self.assertEqual(r0, result,
#                 ("Received result ({}, 0x{:08x}) not equal expected " +
#                 "({}, 0x{:08x})").format(
#                     r0, r0, result, result))
#     '''

# # Generate a testcase for each test data file when module is loaded.
# # async def generate_testcase(filename):
# def generate_testcase(filename):  # nope dont need to do that here.. Will have another ASYNC sim function inside generate test_case!
#     # def test(self):
#     async def test(self):
#         gc.collect()
        
#         # yield self.check_datafile(filename)
        
#         # self.check_datafile(filename)
#             # ERROR: /home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/test_cpu.py:684: RuntimeWarning: coroutine 'TestFPGA_Sim.check_datafile' was never awaited
#             # suite._tests[0].check_datafile(dummy1)
#             # RuntimeWarning: Enable tracemalloc to get the object allocation traceback

#             # ANOTHER ERROR WHEN DOING runnner.run
#                 # test_cpu.TestFPGA_Sim
#                     # test_jeq-imm_z1 ... /home/zaidtahir/projects/hbpf_2/hBPF/DISL_Verilog_eBPF/DISL_Verilog_eBPF_tb/test_cpu.py:516: RuntimeWarning: coroutine 'TestFPGA_Sim.check_datafile' was never awaited
#                     # self.check_datafile(filename)
#                     # RuntimeWarning: Enable tracemalloc to get the object allocation traceback

#                 # so will add await here before self.check_datafile()
#         # await added 
#         await self.check_datafile(filename)
#         # ERROR: SyntaxError: 'await' outside async function

#         # Hence adding await with checkdatafile

#         gc.collect()
#     # return await test
#     return test

class TB:
    def __init__(self, dut, speed=1000e6):
        self.dut = dut

        self.log = SimLog("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        # 125 MHz clk
        # cocotb.start_soon(Clock(dut.clk, 8, units="ns").start())  
        
        # 100 MHz clk
        # cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())  

        # 83.33 MHz clk : sys clk based on our DDR controller ui_clk .. it halves the 166.66 MHz input clk to DDR PHY
        # Alinx: a 200 MHz DIFFERENTIAL system clock. sys_clk_n is driven as the
        # exact complement so the IBUFGDS model (see src/xilinx_sim_primitives.v)
        # resolves it the way the real buffer does. The on-chip 125 MHz and its
        # 90-degree partner come out of the MMCM, exactly as on hardware -- the
        # testbench deliberately does NOT bypass the clocking chain.
        cocotb.start_soon(Clock(dut.sys_clk_p, 5, units="ns").start())
        cocotb.start_soon(self._drive_sys_clk_n())

        # RGMII, not MII: data is DDR on 4 lanes with a single control line per
        # direction carrying dv/err on the two edges. Same cocotbext-eth package.
        self.rgmii_phy = RgmiiPhy(dut.phy_txd, dut.phy_tx_ctl, dut.phy_tx_clk,
            dut.phy_rxd, dut.phy_rx_ctl, dut.phy_rx_clk, speed=speed)

        dut.sys_rst_n.setimmediatevalue(1)   # alinx: async reset, held inactive

        # dut.btn.setimmediatevalue(0)
        # dut.sw.setimmediatevalue(0)  // in top.v
        # dut.uart_rxd.setimmediatevalue(0)  // not in top.v


    async def _drive_sys_clk_n(self):
        """sys_clk_n is the complement of sys_clk_p. IBUFGDS takes both."""
        while True:
            await Edge(self.dut.sys_clk_p)
            self.dut.sys_clk_n.value = 0 if self.dut.sys_clk_p.value else 1
    async def init(self):

        # self.dut.rst.setimmediatevalue(0)
        self.dut.sw.setimmediatevalue(0)

        for k in range(10):
            await RisingEdge(self.dut.sys_clk_p)

        # self.dut.rst <= 1
        self.dut.sw[0] <= 1
        # self.dut.sw[0] <= 0

        for k in range(10):
            await RisingEdge(self.dut.sys_clk_p)

        # self.dut.rst <= 0
        self.dut.sw[0] <= 0

        await Timer(130, units="ns")

        # using riscv prog loader in simulation
        if (RISCV_PROGLOADER_SIM):
            
            self.dut.sw[1].value = 1
            print("\n\nRISCV_PROGLOADER_SIM = 1 so manually loading riscv pgm from prog_loader in Cocotb Simulation. \n Make sure to have a compatible hex file\n")
            print("\nWaiting 3 ms for riscv prog to upload\n")

            await Timer(3000, units="us")
                # need 3 ms to upload 27k pgm instruction thru pgm loader

            print("\nDone loading riscv prog\n")
            self.dut.sw[1].value = 0

        else:

            self.dut.sw[1] <= 1
            # self.dut.sw[1] <= 0

            await Timer(600, units="ns")

            self.dut.sw[1] <= 0

@cocotb.test()
async def run_test(dut):

    # this test is for C file: 2023_10_19_edgetestbed_a100T20_sim_test1

    # print("from inside run_test Printing cocotb_test.simulator whole path of the file = ", cocotb_test.simulator.__globals__['__file__'])
    
    print("from inside run_test Printing cocotb_test.simulator whole path of the file = ")
    

    import inspect
    print(inspect.getfile(cocotb_test.simulator))  # inspecting where this func came from
    
    print("from inside run_test Printing cocotb.test() whole path of the file = ")

    print(inspect.getfile(cocotb.test()))  # inspecting where this func came from
    # /home/zaidtahir/anaconda3/envs/hbpf_2/lib/python3.7/site-packages/cocotb/decorators.py

    # sys.exit("Sys exitingZ from inside run_test ")

    tb = TB(dut)

    # Count VeBPF halt events for the application-level assertions at the end of
    # this test. A halt is how a core signals that an eBPF program reached EXIT,
    # so a run with zero halts executed nothing -- the exact symptom of the eBPF
    # rules never being loaded.
    _halt_count = {"n": 0}

    async def _count_vebpf_halts():
        sig = dut.eth_nic.eth_fifo_to_bram.VeBPF_halt_combined_global
        prev = 0
        while True:
            await RisingEdge(dut.sys_clk_p)
            try:
                cur = int(sig.value)
            except Exception:      # X/Z during reset
                continue
            if cur == 1 and prev == 0:
                _halt_count["n"] += 1
            prev = cur

    cocotb.start_soon(_count_vebpf_halts())

    await tb.init()  # async def init(self): function in the coroutine 

    tb.log.info("Loading VeBPF program memory throught the program loader module")

    # VeBPF reprogram switch OFF
    dut.sw[2].value = 0

    

    # await Timer(10, units="ns")
    
    # await Timer(5, units="us")

    # wait 15 us so that all 3 rules can be uploaded to the VeBPFs
    # await Timer(15, units="us")
        # 15 us isn't enough for 3 rules to upload in simulation

    # await Timer(30, units="us")
        # 30 us isn't enough for 5 rules to upload in simulation

    # await Timer(70, units="us")
        # ERROR was that reprogram_VeBPF_in was going to 0 BEFORE all 17 firewall rules were uploaded!!
        # specifically it went to 0 while rule7 was uploading!!



    if (RX_VEBPF_SIM):
        # VeBPF reprogram switch ON
        dut.sw[2].value = 1
        print("\n\n waiting 1000us for VeBPF prog to load because RX_VEBPF_SIM = 1 for simulating RX_PIPELINE \n and dut.sw[2].value = 1 \n")
        await Timer(1000, units="us")
    
    else:
        print("\n\n RX_VEBPF_SIM = 0, hence not waiting 1000us for VeBPF prog to load. Make RX_VEBPF_SIM = 1 if you want to simulate RX_PIPELINE \n\n")
    # await Timer(100, units="us")

    # adding 50 ns since reprog is becoming LOW 6 ns before rule 17 is completely uploaded.. but it works so not adding it
    # await Timer(50, units="ns")

    # VeBPF reprogram switch OFF
    dut.sw[2].value = 0

    for k in range(10):
            await RisingEdge(dut.sys_clk_p)

    ''' Block comment starts here, not deleting this cx useful tests and packet formation code here

    # Check results in WAVEFORM after this much time has passed

    # This runner.run gonna wipe out all memory after it is finised running.
    #gotta see what happens when it runs

    # eth_test = Ether(src='11:22:33:44:55:66', dst='08:00:27:58:9D:6A')
    # # payload_test = bytes([x % 256 for x in range(4)])
    # payload_test = bytes([255, 0, 255, 0])
    # # ip = IP(src='192.168.1.100', dst='192.168.1.128') 
    # ip = IP(src='192.168.1.128', dst='192.168.1.100') # flipping so that src is arty ip since I wana look at the pkt when arty sends its out
    # # udp = UDP(sport=4049, dport=2049) 
    # udp = UDP(sport=4049, dport=2049, chksum=None)  
    # # https://scapy.readthedocs.io/en/latest/api/scapy.layers.inet.html#scapy.layers.inet.UDP 
    #     # using checksum = None to compare the rxpkt with the txpkt I am sending out
    # # payload_test[0] = 255;
    # # payload_test[0] = 0;
    # # payload_test[2] = 255;
    # # payload_test[3] = 0;

    # pkt_test = eth_test / ip / udp / payload_test 

    # frame_test = GmiiFrame.from_payload(pkt_test.build())

    # print("\n Printing frame_test = ")

    # print(hexdump(frame_test))  # full packet displayed with CRC (FSC)
    # # yes the 4 bits in the byte are flipped in the rxd due to the MII 100mbps mode as in txd  


    # # sys.exit("frame_test exi()t\n")

    # print(f'\n\nSending pkt_test to RX port of arty, size of udp pkt_test frame = {len(frame_test.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(frame_test)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # tb.log.info("test custom packet")
    
    eth = Ether(src='5a:51:52:53:54:55', dst='04:00:00:00:00:00')

    ip = IP(src='192.168.1.100', dst='192.168.1.128') 
    udp = UDP(sport=5678, dport=1234)
    tcp = TCP(sport=5678, dport=1234)     

    # payload_test = 'A' * 15
        # Size of pkt_test_frame = 69 bytes 

    # payload_test = 'A' * 8
        # Size of pkt_test_frame = 62 bytes 
            # I think raw frames have SFD and preamble and CRC as well
                # len of raw pkt_test_frame =74 
                    # Preamble 7 byte + SFD 1 byte + pkt_test_frame 62 bytes + CRC 4 bytes
                        # my etherner modules strips off Preamble SFD and CRC = 12 bytes

    # payload_test = 'A' * 6
        # Size of pkt_test_frame = 60 bytes 

    # req_payload_len_after_60 = 2

    # payload_test = 'A' * (6 + req_payload_len_after_60) 

    # pkt_test = eth / ip / tcp / payload_test
    # # pkt_test = eth / ip / tcp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # # print(f'Size of pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes')  
    # print(f'Size of pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # print(f'len of raw pkt_test_frame ={len(pkt_test_frame)} \n\n')  # full packet displayed without CRC (FSC)  
    # print(f'raw pkt_test_frame ={hexdump(pkt_test_frame)} \n\n')  # full packet displayed without CRC (FSC)  
    # print(f'raw pkt_test ={hexdump(pkt_test)} \n\n')  # full packet displayed without CRC (FSC)  
    # # print(f'Size of raw pkt_test ={len(hexdump(pkt_test))} \n\n')  # full packet displayed without CRC (FSC)  
    #     # error 
    #     # coming out to be 60 so lets calculate
    #         # min eth header is 18 byte
    #         # min ip header is 20 byte
    #         # min tcp header is 20 byte
    #         # total len is 58 bytes


    # sys.exit("\n\n\n sys exit """)

    tb.log.info("Waiting for tx_pkt to be sent packet")

    await Timer(50, units="us")

    print(f"tx_pkt wait complete")

    tb.log.info("test UDP RX packet")

    payload = bytes([x % 256 for x in range(256)])  # rx pkt word len is = 74 and rx pkt byte len is =  298
    # eth header is 14 bytes # udp header is 8 bytes # ip header is 20 bytes min # total headers leng is 42
    # so 256 data len + 42 header len = 298 is total data len
        # simulation shows " rx pkt word len is = 74 and rx pkt byte len is =  298 "
        # words should be 75 since 298/4 = 74.5

    # print(hex(payload)) #error
    
    # for x in payload:
    #     print(" ", hex(x), end = '') # prints from 0x0  0x1  0x2  ... till 0xfd  0xfe  0xff (8'd255) i.e., 256 bytes in total
    
    #payload = bytes([x % 256 for x in range(258)]) # rx pkt word len is = 74 and rx pkt byte len is =  300 
    # payload = bytes([x % 256 for x in range(259)]) # rx pkt word len is = 75 and rx pkt byte len is =  301     
    
    # print(payload)  # prints hex from 0 till 255 (0xff)
    # sys.exit("payloaded xD")

    # eth = Ether(src='5a:51:52:53:54:55', dst='02:00:00:00:00:00')
    
    # changing this to see if VeBPF give correct result if it does not receive rxpkt with dest mac of 02:00:00:00:00:00
    # eth = Ether(src='5a:51:52:53:54:55', dst='04:00:00:00:00:00')
    eth = Ether(src='5a:51:52:53:54:55', dst='04:00:00:00:00:00')
    
    

    #print(eth)  # 
    #print(raw(eth))  # 
    # print(hexdump(eth))  # 0000  02 00 00 00 00 00 5A 51 52 53 54 55 90 00
    # sys.exit("Ether")

    ip = IP(src='192.168.1.100', dst='192.168.1.128') 
    udp = UDP(sport=5678, dport=1234)   
    test_pkt = eth / ip / udp / payload  # eth header is 14 bytes # udp header is 8 bytes # ip header is 20 bytes min 
    # total headers leng is 42

    # print(hexdump(test_pkt))  # full packet displayed without CRC (FSC)
    # sys.exit("test_pkt")

    test_frame = GmiiFrame.from_payload(test_pkt.build()) # pads zeros automatically if framelength is less than minimum

    

    # arp = ARP(hwtype=1, ptype=0x0800, hwlen=6, plen=4, op=2,
        # hwsrc=test_pkt.src, psrc=test_pkt[IP].src,
        # hwdst=test_pkt.dst, pdst=test_pkt[IP].dst)
    arp = ARP(hwtype=1, ptype=0x0800, hwlen=6, plen=4, op=1,  
        hwsrc=test_pkt.src, psrc=test_pkt[IP].src,
        hwdst= '00:00:00:00:00:00', pdst=test_pkt[IP].dst)
    # op = 1 for ARP req and 2 for resp
        # https://en.wikipedia.org/wiki/Address_Resolution_Protocol
        # https://scapy.readthedocs.io/en/latest/api/scapy.layers.l2.html#id1
    #  hw dst is 0 cx in other tb assert rx_pkt[ARP].hwdst == '00:00:00:00:00:00' cx we are asking the hw for its mac

    arp_pkt = eth / arp
    arp_frame =  GmiiFrame.from_payload(arp_pkt.build()) # pads zeros automatically if framelength is less than minimum

    # print(hexdump(test_frame))  # full packet displayed with CRC (FSC)
    # sys.exit("test_frame")

    #z
    #tb.log.info("TX UDP packet to Arty is: %s", repr(test_frame))
    #tb.log.info("TX UDP packet to Arty is: %s", repr(test_frame))

    # payload2 = bytes([x % 512 for x in range(512)])  # ValueError: bytes must be in range(0, 256) cx 255 is FF, after that it is grater than a byte
    # payload2 = bytes([x % 256 for x in range(512)])  # works
        # This one was causing problems... TODO: test this in syntheiszed version
            # its not getting stuck anymore .....
                # The SOLUTION?... comment from eth_fifo_aixs_to_bram_axi.v
                    # // okay so I guess the riscv c code hex file was causing the simulation to get stuck.. cx this setting is running smoothly with the 412 payload
                    # // udp rxpkt now which was causing issues,,.. but this time the c code sim file is diff... 
                    # // "2023_4_7_edgetestbed_a100T13_sim_multiRxPkt_AND_VeBPF_result_reads_fromMem_sim.hex" was causing the problem.. 
                    # // "2023_4_16_edgetestbed_a100T14_sim_multiRxPkt_AND_VeBPF_result_reads_fromMem_v4_sim.hex" is working smoothly
                    # // without any hangups...
                    
    # payload2 = bytes([x % 256 for x in range(510)])  # experimental
    # payload2 = bytes([x % 256 for x in range(511)])  # experimental
    # payload2 = bytes([x % 256 for x in range(514)])  # experimental
    # payload2 = bytes([x % 256 for x in range(513)])  # experimental
    # payload2 = bytes([x % 256 for x in range(515)])  # experimental
    # payload2 = bytes([x % 256 for x in range(516)])  # experimental
    payload2 = bytes([x % 256 for x in range(518)])  # experimental
    # eth = Ether(src='5a:51:52:53:54:55', dst='02:00:00:00:00:00')
    eth = Ether(src='5a:51:52:53:54:55', dst='01:00:00:00:00:00') # dont need the correct dest for this test
    # eth = Ether(src='5a:51:52:53:54:55', dst='05:00:00:00:00:00')
    ip = IP(src='192.168.1.100', dst='192.168.1.128') 
    udp = UDP(sport=5678, dport=1234)  
    test_pkt2 = eth / ip / udp / payload2
    test_frame2 = GmiiFrame.from_payload(test_pkt2.build()) # pads zeros automatically if framelength is less than minimum 


    payload3 = bytes([x % 256 for x in range(100)])  # experimental
    # eth = Ether(src='5a:51:52:53:54:55', dst='02:00:00:00:00:00')
    eth = Ether(src='5a:51:52:53:54:55', dst='01:00:00:00:00:00')  # dont need the correct dest for this test
    # eth = Ether(src='5a:51:52:53:54:55', dst='05:00:00:00:00:00')
    ip = IP(src='192.168.1.100', dst='192.168.1.128') 
    udp = UDP(sport=5678, dport=1234)  
    test_pkt3 = eth / ip / udp / payload3
    test_frame3 = GmiiFrame.from_payload(test_pkt3.build()) # pads zeros automatically if framelength is less than minimum 
        # test_frame3 has correct dst mac address (coorect according to our vebpf rule rightnow)

    # tcp payloads
    payload4 = bytes([x % 256 for x in range(100)])  # experimental
    # eth = Ether(src='5a:51:52:53:54:55', dst='02:00:00:00:00:00')
    eth = Ether(src='5a:51:52:53:54:55', dst='01:00:00:00:00:00')  # dont need the correct dest for this test
    # eth = Ether(src='5a:51:52:53:54:55', dst='05:00:00:00:00:00')
    ip = IP(src='192.168.1.100', dst='192.168.1.128') 
    tcp = TCP(sport=5678, dport=1234)  
    test_pkt4 = eth / ip / tcp / payload4
    test_frame4 = GmiiFrame.from_payload(test_pkt4.build()) # pads zeros automatically if framelength is less than minimum


    payload5 = bytes([x % 256 for x in range(97)])  # experimental
    # eth = Ether(src='5a:51:52:53:54:55', dst='02:00:00:00:00:00')
    eth = Ether(src='5a:51:52:53:54:55', dst='01:00:00:00:00:00')
    # eth = Ether(src='5a:51:52:53:54:55', dst='05:00:00:00:00:00')
    ip = IP(src='192.168.1.100', dst='192.168.1.128') 
    tcp = TCP(sport=5678, dport=1234)  
    test_pkt5 = eth / ip / tcp / payload5
    test_frame5 = GmiiFrame.from_payload(test_pkt5.build()) # pads zeros automatically if framelength is less than minimum


    payload6 = bytes([x % 256 for x in range(800)])  # experimental
    # eth = Ether(src='5a:51:52:53:54:55', dst='02:00:00:00:00:00')
    eth = Ether(src='5a:51:52:53:54:55', dst='01:00:00:00:00:00')
    # eth = Ether(src='5a:51:52:53:54:55', dst='05:00:00:00:00:00')
    ip = IP(src='192.168.1.100', dst='192.168.1.128') 
    tcp = TCP(sport=5678, dport=1234)  
    test_pkt6 = eth / ip / tcp / payload6
    test_frame6 = GmiiFrame.from_payload(test_pkt6.build())  

    print("Size of arp_frame = bytes", len(arp_frame.get_payload()))
    print("Size of test_frame2 = bytes", len(test_frame2.get_payload()))
        # test_frame2 has correct dst mac address (coorect according to our vebpf rule rightnow)
    print("Size of test_frame = bytes", len(test_frame.get_payload()))
    print("Size of test_frame3 = bytes", len(test_frame3.get_payload()))
    print("Size of test_frame4 = bytes", len(test_frame4.get_payload()))
    print("Size of test_frame5 = bytes", len(test_frame5.get_payload()))
    print("Size of test_frame6 = bytes", len(test_frame6.get_payload()))
        # test_frame3 has correct dst mac address (coorect according to our vebpf rule rightnow)
    # Size of arp_frame = %d bytes 60  .. = 15 words (60 bytes)
        # in wireshark the ARP len is 42.. its cx its on the same laptop because min eth packet len is 64 (60 + 4 byte crc)
            #So, arp stands for "Address Resolution Protocol", and 42 is the number of bytes comprising this ARP packet. 
            # And since 42 is less than the minimum number of bytes for an Ethernet frame, it also means that you were capturing on the same machine 
            #that sent the ARP request, in this case, 192.168.1.33.
                # for my eth module min packet len is 60 cx 4 byte crc is stripped off


    # Size of test_frame = %d bytes 298 = 74.5 words = 75 words (300 bytes)
    # Size of test_frame2 = %d bytes 560 = 140 words ................... not 138.5 words = 139 words!!!!!! (556 bytes)
    # Size of test_frame3 = %d bytes 142 = 35.5 words = 36 words
        # total bytes of these 3 rxpkts (arp_frame + test_frame + test_frame2) = 300 + 556 + 60 = 910 bytes = 227.5 words == 228 words
    # sys.exit("bye")

    test_frames_array = []
    # test_frames_array.append(test_frame)
    test_frames_array.append(arp_frame)  # sending arp frame here first to see if tb still works
    # test_frames_array.append(test_frame2) 
        # commenting out the correct MAC address frame
    test_frames_array.append(test_frame)
    test_frames_array.append(test_frame2)
    # test_frames_array.append(test_frame3)
    # test_frames_array.append(test_frame)

    eth = Ether(src='5a:51:52:53:54:55', dst='04:00:00:00:00:00')
    ip = IP(src='192.168.1.100', dst='192.168.1.128') 
    udp = UDP(sport=5678, dport=1234)
    tcp = TCP(sport=5678, dport=1234)   

    # req_payload_len_after_60 = 2
    # payload_test = 'A' * (6 + req_payload_len_after_60) 
    # pkt_test = eth / ip / tcp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'Size of pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')

    ################################################################################################################################################
    # Below is an experiment according to specific packets sent on wireshark on 11-9-2023, scrrenshot available in folder for details of the packets
    ################################# START ########################################################################################################
    # BLOCK COMMENT START

    # # result: Was able to generate the FULL rxpkthdrBram bug AL!

    # # sending ARP packet
    # print(f'\n\nSize of arp arp_frame = {len(arp_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(arp_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit 

    # # sending tcp packet of len 78
    # req_payload_len_after_60 = 18
    # payload_test = 'A' * (6 + req_payload_len_after_60) 
    # pkt_test = eth / ip / tcp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of tcp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # # sending tcp packet of len 62
    # req_payload_len_after_60 = 2
    # payload_test = 'A' * (6 + req_payload_len_after_60) 
    # pkt_test = eth / ip / tcp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of tcp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # # sending tcp packet of len 90
    # req_payload_len_after_60 = 30
    # payload_test = 'A' * (6 + req_payload_len_after_60) 
    # pkt_test = eth / ip / tcp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of tcp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit  

    # # sending udp packet of len 60
    # req_payload_len_after_60 = 0
    # payload_test = 'A' * (6 + req_payload_len_after_60) 
    # pkt_test = eth / ip / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit  

    # # sending udp packet of len 342
    # req_payload_len_after_60 = 282
    # payload_test = 'A' * (6 + 12 + req_payload_len_after_60) # added 12 for udp
    # pkt_test = eth / ip / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # # sending tcp packet of len 145
    # req_payload_len_after_60 = 85
    # payload_test = 'A' * (6 + req_payload_len_after_60) 
    # pkt_test = eth / ip / tcp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of tcp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit   


    # # sending tcp packet of len 90
    # req_payload_len_after_60 = 30
    # payload_test = 'A' * (6 + req_payload_len_after_60) 
    # pkt_test = eth / ip / tcp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of tcp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # # sending ARP packet
    # print(f'\n\nSize of arp arp_frame = {len(arp_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(arp_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit  

    # # sending tcp packet of len 86
    # req_payload_len_after_60 = 26
    # payload_test = 'A' * (6 + req_payload_len_after_60) 
    # pkt_test = eth / ip / tcp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of tcp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit  

    # # sending tcp packet of len 110
    # req_payload_len_after_60 = 50
    # payload_test = 'A' * (6 + req_payload_len_after_60) 
    # pkt_test = eth / ip / tcp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of tcp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit  

    # # sending ARP packet
    # print(f'\n\nSize of arp arp_frame = {len(arp_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(arp_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit  

    # # sending ARP packet
    # print(f'\n\nSize of arp arp_frame = {len(arp_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(arp_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit  

    # # sending udp packet of len 69
    # req_payload_len_after_60 = 9
    # payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    # pkt_test = eth / ip / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # # sending udp packet of len 89
    # req_payload_len_after_60 = 29
    # payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    # pkt_test = eth / ip / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # # sending udp packet of len 127
    # req_payload_len_after_60 = 67
    # payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    # pkt_test = eth / ip / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # # sending udp packet of len 107
    # req_payload_len_after_60 = 47
    # payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    # pkt_test = eth / ip / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # # sending tcp packet of len 145
    # req_payload_len_after_60 = 85
    # payload_test = 'A' * (6 + req_payload_len_after_60) 
    # pkt_test = eth / ip / tcp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of tcp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # # sending udp packet of len 209
    # req_payload_len_after_60 = 149
    # payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    # pkt_test = eth / ip / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # BLOCK COMMENT END
    ################################################################################################################################################
    # Below is an experiment according to specific packets sent on wireshark on 11-9-2023, scrrenshot available in folder for details of the packets
    ################################# END ##########################################################################################################

    # sending the correct dest eth pkt
    eth2 = Ether(src='5a:51:52:53:54:55', dst='02:00:00:00:00:00')
    ip = IP(src='192.168.1.100', dst='192.168.1.128') 
    udp = UDP(sport=5678, dport=1234)
    tcp = TCP(sport=5678, dport=1234)

    # # sending udp packet of len 209
    # req_payload_len_after_60 = 149
    # payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    # pkt_test = eth2 / ip / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit   

    # # Doing stressTest2 below

    # for x in range(4):
    #     # sending 4 udp packets of len 1024 .. #1000
    #     req_payload_len_after_60 = 964 #940
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth2 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(100, units="us")  # wait a bit  

    # for x in range(4):
    #     # sending 4 udp packets of len 1024 .. #1000
    #     req_payload_len_after_60 = 964 #940
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth2 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(100, units="us")  # wait a bit  

    # for x in range(4):
    #     # sending 4 udp packets of len 1024 .. #1000
    #     req_payload_len_after_60 = 964 #940
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth2 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(100, units="us")  # wait a bit 


    # Doing stressTest4 below
    # testing the updates in network subsystem VeBPF result evaluator 

    # for x in range(4):
    #     # sending 4 udp packets of len 90
    #     req_payload_len_after_60 = 30
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth2 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")  # wait a bit  n

    block comment ends here
    '''

    eth3 = Ether(src='5a:51:52:53:54:55', dst='03:00:00:00:00:00')
    ip = IP(src='192.168.1.100', dst='192.168.1.129') 
    udp = UDP(sport=5678, dport=1234)
    tcp = TCP(sport=5678, dport=1234) 


    eth4 = Ether(src='5a:51:52:53:54:55', dst='08:02:00:00:00:00')
    ip = IP(src='192.168.1.100', dst='192.168.1.121') 
    udp = UDP(sport=5678, dport=1234)
    tcp = TCP(sport=5678, dport=1234)

    eth5 = Ether(src='5a:51:52:53:54:55', dst='08:02:00:00:00:00')
    ip2 = IP(src='255.255.255.255', dst='192.168.1.121') 
    udp = UDP(sport=5678, dport=1234)
    tcp = TCP(sport=5678, dport=1234)

    ip_rule1 = IP(src='255.255.255.255', dst='192.168.1.121') 
    ip_rule1_v2_modified = IP(src='245.255.255.255', dst='192.168.1.121') 

    ip_rule2 = IP(src='127.0.0.0', dst='192.168.1.121') 
    ip_rule2_v2_modified = IP(src='128.0.0.0', dst='192.168.1.121') 
    
    ip_rule3 = IP(src='240.0.0.0', dst='192.168.1.121') 
    
    ip_rule4 = IP(src='0.0.0.0', dst='192.168.1.121') 
    ip_rule4_v2_modified = IP(src='1.0.0.0', dst='192.168.1.121') 

    udp_rule5 = UDP(sport=5678, dport=111)
    udp_rule6 = UDP(sport=5678, dport=2000)
    udp_rule7 = UDP(sport=5678, dport=37)
    udp_rule8 = UDP(sport=5678, dport=135)
    udp_rule9 = UDP(sport=5678, dport=137)
    udp_rule10 = UDP(sport=5678, dport=138)
    udp_rule11 = UDP(sport=5678, dport=161)
    udp_rule12 = UDP(sport=5678, dport=162)
    udp_rule13 = UDP(sport=5678, dport=514)
    udp_rule14 = UDP(sport=5678, dport=69)
    udp_rule15 = UDP(sport=5678, dport=2049)
    udp_rule16 = UDP(sport=5678, dport=389)
    udp_rule17 = UDP(sport=5678, dport=4045)

    ethx1 = Ether(src='5a:51:52:53:54:55', dst='01:02:00:00:00:00')
    ethx2 = Ether(src='5a:51:52:53:54:55', dst='02:02:00:00:00:00')
    ethx3 = Ether(src='5a:51:52:53:54:55', dst='03:02:00:00:00:00')
    ethx4 = Ether(src='5a:51:52:53:54:55', dst='04:02:00:00:00:00')
    ethx5 = Ether(src='5a:51:52:53:54:55', dst='05:02:00:00:00:00')
    ethx6 = Ether(src='5a:51:52:53:54:55', dst='06:02:00:00:00:00')
    ethx7 = Ether(src='5a:51:52:53:54:55', dst='07:02:00:00:00:00')
    ethx8 = Ether(src='5a:51:52:53:54:55', dst='08:02:00:00:00:00')
    ethx9 = Ether(src='5a:51:52:53:54:55', dst='09:02:00:00:00:00')
    ethx10 = Ether(src='5a:51:52:53:54:55', dst='0a:02:00:00:00:00')
    ethx11 = Ether(src='5a:51:52:53:54:55', dst='0b:02:00:00:00:00')
    ethx12 = Ether(src='5a:51:52:53:54:55', dst='0c:02:00:00:00:00')
    ethx13 = Ether(src='5a:51:52:53:54:55', dst='0d:02:00:00:00:00')
    ethx14 = Ether(src='5a:51:52:53:54:55', dst='0e:02:00:00:00:00')
    ethx15 = Ether(src='5a:51:52:53:54:55', dst='0f:02:00:00:00:00')
    ethx16 = Ether(src='5a:51:52:53:54:55', dst='10:02:00:00:00:00')
    ethx17 = Ether(src='5a:51:52:53:54:55', dst='11:02:00:00:00:00')
    ethx18 = Ether(src='5a:51:52:53:54:55', dst='12:02:00:00:00:00')
    ethx19 = Ether(src='5a:51:52:53:54:55', dst='13:02:00:00:00:00')

    # 12 Sept 2024, VeBPF_prog_LoaderV2 test here. Will send 5 rxpkts...
    # first 3 will be rule1,2,3 packets, then random packet, then rule4 packet..

    # rule1 packet
    # sending rule1 malicious rxpkt ip_rule1 of length 256 bytes
    req_payload_len_after_60 = 196
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    # pkt_test = eth5 / ip_rule1 / udp / payload_test
    pkt_test = eth5 / ip_rule1_v2_modified / udp / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit
    # wait a bit less :)
    # await Timer(200, units="ns")  
    await Timer(120, units="ns")   

    # rule2 packet
    # sending rule2_v2_modified malicious rxpkt ip_rule2
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx2 / ip_rule2_v2_modified / udp / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit

    # rule3 packet
    # sending rule3 malicious rxpkt ip_rule3
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx3 / ip_rule3 / udp / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit

    # rule5 random packet in between
    # sending rule5 malicious rxpkt udp_rule5
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx5 / ip / udp_rule5 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit

    # rule4 packet
    # sending rule4_v2_modified malicious rxpkt ip_rule4
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx4 / ip_rule4_v2_modified / udp / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit

    # THROUGHPUT CALCULATION
    '''
    # sending 4 rule1 malicious rxpkt ip_rule1 of length 1500 bytes
    for x in range(4):
        req_payload_len_after_60 = 1440
        payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
        pkt_test = eth5 / ip_rule1 / udp / payload_test
        pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
        print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
        await tb.rgmii_phy.rx.send(pkt_test_frame)
        await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
        # await Timer(5000, units="ns")  # wait a bit
        # wait a bit less :)
        # await Timer(200, units="ns")  
        await Timer(120, units="ns")

    # sending 4 rule1 malicious rxpkt ip_rule1 of length 1024 bytes
    # for x in range(4):
    #     req_payload_len_after_60 = 964
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    #     pkt_test = eth5 / ip_rule1 / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     # await Timer(5000, units="ns")  # wait a bit
    #     # wait a bit less :)
    #     # await Timer(200, units="ns")  
    #     await Timer(120, units="ns") 

    # sending 4 rule1 malicious rxpkt ip_rule1 of length 512 bytes
    # for x in range(4):
    #     req_payload_len_after_60 = 452
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    #     pkt_test = eth5 / ip_rule1 / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     # await Timer(5000, units="ns")  # wait a bit
    #     # wait a bit less :)
    #     # await Timer(200, units="ns")  
    #     await Timer(120, units="ns")

    # sending 4 rule1 malicious rxpkt ip_rule1 of length 256 bytes
    # for x in range(4):
    #     req_payload_len_after_60 = 196
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    #     # pkt_test = eth5 / ip_rule1 / udp / payload_test
    #     pkt_test = eth5 / ip_rule1_v2_modified / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     # await Timer(5000, units="ns")  # wait a bit
    #     # wait a bit less :)
    #     # await Timer(200, units="ns")  
    #     await Timer(120, units="ns")   

    # sending 4 rule1 malicious rxpkt ip_rule1 of length 128 bytes
    # for x in range(4):
    #     req_payload_len_after_60 = 68
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    #     # pkt_test = eth5 / ip_rule1 / udp / payload_test
    #     pkt_test = eth5 / ip_rule1_v2_modified / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     # await Timer(5000, units="ns")  # wait a bit
    #     # wait a bit less :)
    #     # await Timer(200, units="ns")  
    #     await Timer(120, units="ns")

    # sending 4 rule1 malicious rxpkt ip_rule1 of length 64 bytes
    # for x in range(4):
    #     req_payload_len_after_60 = 4
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    #     # pkt_test = eth5 / ip_rule1 / udp / payload_test
    #     pkt_test = eth5 / ip_rule1_v2_modified / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     # await Timer(5000, units="ns")  # wait a bit
    #     # wait a bit less :)
    #     # await Timer(200, units="ns")  
    #     await Timer(120, units="ns")  

    await Timer(70, units="us")
        # for printing throughput

    await Timer(500, units="us")
        # additional delay for riscv throughput

    await Timer(1500, units="us")
    #     # additional delay for 512 byte rxpkts for riscv throughput

    await Timer(1500, units="us")
    #     # additional delay for 1024 byte rxpkts for riscv throughput

    await Timer(3000, units="us")
    #     # additional delay for 1500 byte rxpkts for riscv throughput
    
    '''
    

    '''
    # the plan:
        # send 1 non malicious rxpkt first
        # then send rxpkts according to the firewall rules but in decending order from rule 17

    # sending 1 non malicious rxpkt
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = eth5 / ip / udp / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit 

    # sending rule17 malicious rxpkt udp_rule17
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx17 / ip / udp_rule17 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit 

    # sending rule16 malicious rxpkt udp_rule16
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx16 / ip / udp_rule16 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit 

    # sending rule15 malicious rxpkt udp_rule15
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx15 / ip / udp_rule15 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit 


    # sending rule14 malicious rxpkt udp_rule14
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx14 / ip / udp_rule14 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit 

    # sending rule13 malicious rxpkt udp_rule13
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx13 / ip / udp_rule13 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit 

    # sending rule12 malicious rxpkt udp_rule12
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx12 / ip / udp_rule12 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit 

    # sending rule11 malicious rxpkt udp_rule11
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx11 / ip / udp_rule11 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit

    # sending rule10 malicious rxpkt udp_rule10
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx10 / ip / udp_rule10 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit

    # sending rule9 malicious rxpkt udp_rule9
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx9 / ip / udp_rule9 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit  

    # sending rule8 malicious rxpkt udp_rule8
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx8 / ip / udp_rule8 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit 

    # sending rule7 malicious rxpkt udp_rule7
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx7 / ip / udp_rule7 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit

    # sending rule6 malicious rxpkt udp_rule6
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx6 / ip / udp_rule6 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit

    # sending rule5 malicious rxpkt udp_rule5
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx5 / ip / udp_rule5 / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit

    # # sending rule4 malicious rxpkt ip_rule4
    # req_payload_len_after_60 = 10
    # payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    # pkt_test = ethx4 / ip_rule4 / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # sending rule4_v2_modified malicious rxpkt ip_rule4
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx4 / ip_rule4_v2_modified / udp / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit
    
    # sending rule3 malicious rxpkt ip_rule3
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx3 / ip_rule3 / udp / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit

    # # sending rule2 malicious rxpkt ip_rule2
    # req_payload_len_after_60 = 10
    # payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    # pkt_test = ethx2 / ip_rule2 / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit
    
    # sending rule2_v2_modified malicious rxpkt ip_rule2
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx2 / ip_rule2_v2_modified / udp / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit
    
    # # sending rule1 malicious rxpkt ip_rule1
    # req_payload_len_after_60 = 10
    # payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    # pkt_test = ethx1 / ip_rule1 / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit
    
    # sending rule1_v2_modified malicious rxpkt ip_rule1
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60)
    pkt_test = ethx1 / ip_rule1_v2_modified / udp / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit
       
 

    # # sending 1 ip2 src rxpkt  // valid pkt
    # req_payload_len_after_60 = 10
    # payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    # pkt_test = ethx18 / ip2 / udp / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # sending 1 ip_rule2 src rxpkt  
    # sending 1 ip_rule3 src rxpkt  
    # sending 1 ip_rule4 src rxpkt  
    # sending 1 udp_rule5 rxpkt  
    # sending 1 udp_rule6 rxpkt  
    # sending 1 udp_rule7 rxpkt  
    # sending 1 udp_rule8 rxpkt  
    # sending 1 udp_rule9 rxpkt  
    # sending 1 udp_rule10 rxpkt  
    # sending 1 udp_rule11 rxpkt  
    # sending 1 udp_rule12 rxpkt  
    # sending 1 udp_rule13 rxpkt  
    # sending 1 udp_rule14 rxpkt  
    # sending 1 udp_rule15 rxpkt  
    # sending 1 udp_rule16 rxpkt  
    # sending 1 udp_rule17 rxpkt  
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    # pkt_test = eth5 / ip_rule2 / udp / payload_test
    # pkt_test = eth5 / ip_rule3 / udp / payload_test
    # pkt_test = eth5 / ip_rule4 / udp / payload_test
    # pkt_test = eth5 / ip / udp_rule5 / payload_test
    # pkt_test = eth5 / ip / udp_rule6 / payload_test
    # pkt_test = eth5 / ip / udp_rule7 / payload_test
    # pkt_test = eth5 / ip / udp_rule8 / payload_test
    # pkt_test = eth5 / ip / udp_rule9 / payload_test
    # pkt_test = eth5 / ip / udp_rule10 / payload_test
    # pkt_test = eth5 / ip / udp_rule11 / payload_test
    # pkt_test = eth5 / ip / udp_rule12 / payload_test
    # pkt_test = eth5 / ip / udp_rule13 / payload_test
    # pkt_test = eth5 / ip / udp_rule14 / payload_test
    # pkt_test = eth5 / ip / udp_rule15 / payload_test
    # pkt_test = eth5 / ip / udp_rule16 / payload_test
    # pkt_test = ethx17 / ip / udp_rule17 / payload_test
    # pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    # print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    # await tb.rgmii_phy.rx.send(pkt_test_frame)
    # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    # await Timer(5000, units="ns")  # wait a bit

    # sending 1 eth3 src rxpkt  
    req_payload_len_after_60 = 10
    payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    pkt_test = ethx19 / ip / udp / payload_test
    pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    await tb.rgmii_phy.rx.send(pkt_test_frame)
    await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    await Timer(5000, units="ns")  # wait a bit

    await Timer(200, units="us")

    '''

    # await Timer(2000, units="us")
        # wait to filter all rxpkts in riscv

    # Debugging a100T22

    # # sending 4 ip2 src MAC rxpkts  // valid pkt
    # for x in range(4):
    #     # sending 4 udp packets of len 60, 70, 80, 90
    #     req_payload_len_after_60 = 10 * x
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth5 / ip2 / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")

    # # sending 4 eth4 dest MAC rxpkts  // invalid pkt
    # for x in range(4):
    #     # sending 4 udp packets of len 60, 70, 80, 90
    #     req_payload_len_after_60 = 10 * x
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth4 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")

    # # sending 4 eth3 dest MAC rxpkts  // valid pkt
    # for x in range(4):
    #     # sending 4 udp packets of len 60, 70, 80, 90
    #     req_payload_len_after_60 = 10 * x
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth3 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")

    # # sending 4 eth2 dest MAC rxpkts  // valid pkt
    # for x in range(4):
    #     # sending 4 udp packets of len 60, 70, 80, 90
    #     req_payload_len_after_60 = 10 * x
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth2 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")

    # # sending 4 eth4 dest MAC rxpkts  // invalid pkt
    # for x in range(4):
    #     # sending 4 udp packets of len 60, 70, 80, 90
    #     req_payload_len_after_60 = 10 * x
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth4 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")

    # # sending 4 eth2 dest MAC rxpkts  // valid pkt
    # for x in range(4):
    #     # sending 4 udp packets of len 60, 70, 80, 90
    #     req_payload_len_after_60 = 10 * x
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth2 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")





    # # sending 4 eth4 dest MAC rxpkts
    # for x in range(4):
    #     # sending 4 udp packets of len 60, 70, 80, 90
    #     req_payload_len_after_60 = 10 * x
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth4 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")

    # # sending 4 eth3 dest MAC rxpkts
    # for x in range(4):
    #     # sending 4 udp packets of len 60, 70, 80, 90
    #     req_payload_len_after_60 = 10 * x
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth3 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")

    # # sending 4 eth2 dest MAC rxpkts
    # for x in range(4):
    #     # sending 4 udp packets of len 60, 70, 80, 90
    #     req_payload_len_after_60 = 10 * x
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth2 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")

    # # sending 4 eth4 dest MAC rxpkts
    # for x in range(4):
    #     # sending 4 udp packets of len 60, 70, 80, 90
    #     req_payload_len_after_60 = 10 * x
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth4 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")

    # # sending 4 eth2 dest MAC rxpkts
    # for x in range(4):
    #     # sending 4 udp packets of len 60, 70, 80, 90
    #     req_payload_len_after_60 = 10 * x
    #     payload_test = 'A' * (6 + 12 + req_payload_len_after_60) 
    #     pkt_test = eth2 / ip / udp / payload_test
    #     pkt_test_frame = GmiiFrame.from_payload(pkt_test.build())
    #     print(f'\n\nSize of udp pkt_test_frame = {len(pkt_test_frame.get_payload())} bytes \n\n')
    #     await tb.rgmii_phy.rx.send(pkt_test_frame)
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit

    # await Timer(50, units="us")





    # await Timer(10000, units="us")
    # await Timer(5000, units="us")
    # await Timer(3000, units="us")
    # await Timer(800, units="us")
    

    # await Timer(50, units="us")
    # await Timer(200, units="us")
        # need more time to display all 17 rxpkts results

    # await Timer(5000, units="us")
    # await Timer(2000, units="us")
        # only need 2 ms to display 17 rxpkts results

    # sending 5 rx pkts
    #for x in range(5):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo

    
    # send 10 tx pkts
    # for x in range(3):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
    # for x in range(1):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
    #     # await tb.rgmii_phy.rx.send(test_frame)
    #     await tb.rgmii_phy.rx.send(test_frames_array[x])
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit 
    #print(tb.rgmii_phy.tx_complete.data.sim_time_sfd)

    ###################################  BLOCK COMMENT Of prev Experiments START ###################################
    '''

    # copied this to check the rollover condition for a100T16 experiment with the await tb.rgmii_phy.rx.wait() statement included
    for x in range(3):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
    # for x in range(1):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
        # await tb.rgmii_phy.rx.send(test_frame)
        # await tb.rgmii_phy.rx.send(test_frames_array[x])
        await tb.rgmii_phy.rx.send(test_frames_array[2])
            # testing the memory allocated limits
        await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
        await Timer(5000, units="ns")  # wait a bit 
    #print(tb.rgmii_phy.tx_complete.data.sim_time_sfd)

    for x in range(9):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
    # for x in range(1):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
        # await tb.rgmii_phy.rx.send(test_frame)
        # await tb.rgmii_phy.rx.send(test_frames_array[x])
        await tb.rgmii_phy.rx.send(test_frames_array[1])
            # testing the memory allocated limits
        await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
        await Timer(5000, units="ns")  # wait a bit 

    for x in range(3):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
    # for x in range(1):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
        # await tb.rgmii_phy.rx.send(test_frame)
        # await tb.rgmii_phy.rx.send(test_frames_array[x])
        await tb.rgmii_phy.rx.send(test_frames_array[0])
            # testing the memory allocated limits
        await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
        await Timer(5000, units="ns")  # wait a bit

    for x in range(3):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
    # for x in range(1):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
        # await tb.rgmii_phy.rx.send(test_frame)
        # await tb.rgmii_phy.rx.send(test_frames_array[x])
        await tb.rgmii_phy.rx.send(test_frame4)
            # testing the memory allocated limits
        await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
        await Timer(5000, units="ns")  # wait a bit

    for x in range(3):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
    # for x in range(1):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
        # await tb.rgmii_phy.rx.send(test_frame)
        # await tb.rgmii_phy.rx.send(test_frames_array[x])
        await tb.rgmii_phy.rx.send(test_frames_array[0])
            # testing the memory allocated limits
        await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
        await Timer(5000, units="ns")  # wait a bit

    for x in range(3):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
    # for x in range(1):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
        # await tb.rgmii_phy.rx.send(test_frame)
        # await tb.rgmii_phy.rx.send(test_frames_array[x])
        await tb.rgmii_phy.rx.send(test_frame6)
            # testing the memory allocated limits
        await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
        await Timer(5000, units="ns")  # wait a bit

    for x in range(13):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
    # for x in range(1):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
        # await tb.rgmii_phy.rx.send(test_frame)
        # await tb.rgmii_phy.rx.send(test_frames_array[x])
        await tb.rgmii_phy.rx.send(test_frames_array[2])
            # testing the memory allocated limits
        await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
        await Timer(5000, units="ns")  # wait a bit    
    
    ''' 
    ###################################  BLOCK COMMENT Of prev Experiments END ###################################
    

    # for x in range(3):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
    # # for x in range(1):  # 8k / 300 (rx pkt len) = 27.3. So 27 pkts atleast can fit into eth rx fifo
    #     # await tb.rgmii_phy.rx.send(test_frame)
    #     await tb.rgmii_phy.rx.send(test_frames_array[x])
    #     await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
    #     await Timer(5000, units="ns")  # wait a bit 

    # for x in range(180):  # send 180 of test_frame packets # doesnt work
    # for x in range(11):  # works
        # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
        # await Timer(5000, units="ns")  # wait a bit  
    
    ## ************* VIP test START ****************** #################
    
    # for x in range(12):  # testing without rx.wait to see if it runs cx it wasnt running when it was greater than 2 
    # for x in range(2):  # runs 
    # for x in range(64):  # runs 
    # for x in range(640):  # runs and tested and saved as "top_20ms_643rxpkts.fst"  in experimentals folder
        # await tb.rgmii_phy.rx.send(test_frame)
        # await tb.rgmii_phy.rx.wait()  # wait for frame to be transmitted fully https://github.com/alexforencich/cocotbext-eth
            # testing.. commenting out await
            # SO rx.await() is causing the simulation to get stuck when there are rx pkts more than 5,
            # I think it might be due to most probably that the initial MAC fifos get full after 5 pkts or something,
            # and riscv softcore DOES empty them out as simulation moves on, but I guess rx.wait() gets stuck in a 
            # forever while loop waiting for the MAC fifos to get empty, while they do get emptied as simulation progresses
            # maybe rx.wait() does no look at the rest of simulation that the MAC fifos got empited out and just gets stuck 
            # in a while loop waiting for the MAC fifos to have space without checking for that. Hence, when I comment out
            # "await tb.rgmii_phy.rx.wait()", the simulation works fine and I can see 12 rx pkts being read and emptied out by riscv softcore

        # await Timer(5000, units="ns")  # wait a bit

    # await tb.rgmii_phy.rx.send(test_frame2)
        # sending out the network pkt with correct MAC address
    # await tb.rgmii_phy.rx.wait() 
        # dont need this

    # await tb.rgmii_phy.rx.send(test_frame3)
    #         # sending out the network pkt with correct MAC address
    # await tb.rgmii_phy.rx.wait() 
    
    await Timer(5000, units="ns")  # wait a bit

    # results for 643 total rx pkts and 20 ms sim time, stored of this experiment in "top_20ms_643rxpkts.fst"  in experimentals folder
    # Btw sim time of just 1.5 ms is required instead of 20 ms................. !!!!!!!!!!!!! VIP!!!***
    # Commented out await tb.rgmii_phy.rx.wait(), otherwise it was getting stuck,,, maybe it was waiting for a resp from GMII module of my design,
    # i.e., that it can take in more rx pkts but the fifos were filled and although they were being emptied and should have been captured by
    # fifos and they should have taken in more rx pkts but somehow it was getting stuck... need to look into this await tb.rgmii_phy.rx.wait() func
    # and print out data while its awaiting to debug the tb getting stuck...
        # also will experiment with sending the 3 rx pkts with one rx pkt having payload of 512, which was causing the tb to get stuck... will comment
        # out the await tb.rgmii_phy.rx.wait() statment and see if it is getting stuck,...
            # its not getting stuck anymore .....
                # The SOLUTION?... comment from eth_fifo_aixs_to_bram_axi.v
                    # // okay so I guess the riscv c code hex file was causing the simulation to get stuck.. cx this setting is running smoothly with the 412 payload
                    # // udp rxpkt now which was causing issues,,.. but this time the c code sim file is diff... 
                    # // "2023_4_7_edgetestbed_a100T13_sim_multiRxPkt_AND_VeBPF_result_reads_fromMem_sim.hex" was causing the problem.. 
                    # // "2023_4_16_edgetestbed_a100T14_sim_multiRxPkt_AND_VeBPF_result_reads_fromMem_v4_sim.hex" is working smoothly
                    # // without any hangups...
                        # I tested this again with the problem causing hex file and it was getting stuck.. but it got unstuck when I commented out
                        # await tb.rgmii_phy.rx.wait() line in the test_top.py file... which means there is a relation of riscv softcore with this
                        # await tb.rgmii_phy.rx.wait() courotine? .. Guess I don't need to spend too much time on this and move on...


     ## ************* VIP test END ****************** #################

    await Timer(5000, units="ns")  # wait a bit  
    # await Timer(15000, units="ns")  # wait a bit  
    # await Timer(10000, units="ns")  # wait a bit  
    await Timer(50000, units="ns")  # wait a bit

    # await Timer(8, units="ms")  # wait for 8 big udp tx_pk
    await Timer(2, units="ms")  # wait for 8 big udp tx_pk
    

    print(" **************** ALL PACKETS SENT ************************** \n")
    

    # print("hello cocotb \n")

    # so the rx pkt was recevied at around 25 us, and it was avaialble at eth_fifo_axis_to_bram_axi
    # at 27.5 us 
    # So at 30 us, will send rv core araddr of axi_arddr = 0x20800000 (and increment by words, i.e., + 0x4)
    # since we are reading in form of words 
    # have an int var pktlen store pkt length and run while loop for the pkt length to read the full pkt and 
    # --pktlen var in the while loop.

    # we are at 35 us right now here
    
    #rx_pkt_word_len = dut.eth_fifo_to_bram.rx_pkt_len_words_counter_reg.value
    # adding "fpga_core" as the top file has changed

    # block comment STARTS HERE
    rx_pkt_word_len = dut.eth_nic.eth_fifo_to_bram.rx_pkt_len_words_counter_reg.value
    # rx_pkt_word_len = dut.eth_network_interface_controller.eth_fifo_to_bram.rx_pkt_len_words_counter_reg
    
    rx_pkt_word_addr = 0

    #rx_pkt_byte_len = dut.eth_fifo_to_bram.rx_pkt_len_counter_reg.value
    # adding "fpga_core" as the top file has changed
    rx_pkt_byte_len = dut.eth_nic.eth_fifo_to_bram.rx_pkt_len_counter_reg.value 
    # rx_pkt_byte_len = dut.eth_network_interface_controller.eth_fifo_to_bram.rx_pkt_len_counter_reg

    ############################
    # uncommented these to see the leds turining on for the 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex file, at 1.6 ms :3
    # dut.sw[2].value = 1
    # await Timer(10, units="us")
    # dut.sw[2].value = 0

#    while (rx_pkt_word_len >= 0):  # include 0 in the counts 
        #TypeError: '>=' not supported between instances of 'BinaryValue' and 'int'

    print("\n \n rx pkt word len is = %d and rx pkt byte len is = % d \n \n" % 
        (int(rx_pkt_word_len), int(rx_pkt_byte_len)))


    #payload = bytes([x % 256 for x in range(256)])
        #rx pkt word len is = 74 (f74.5) and rx pkt byte len is =  298 
    #payload = bytes([x % 256 for x in range(258)])
        # rx pkt word len is = 74 and rx pkt byte len is =  300 
            #word length seems to be correct since word len is the same
            #next test with 1 byte more than multiple of rx byte len
    # payload = bytes([x % 256 for x in range(259)]) 
        # rx pkt word len is = 75 and rx pkt byte len is =  301 
    # block comment ENDS HERE
   
    
    # block comment: commented out the rv emulating axi reads to the ethernet bram to rv module
    # block comment STARTS HERE

    # # emulating rv axi reading signals to the ethernet bram to rv module
    # while (rx_pkt_word_len+1):  # +1 added to include 0 in the counts. 
        # Will HAVE TO DO rx_pkt_word_len+1 in c code for length as well
            
    #     if (dut.eth_fifo_to_bram.rx_pkt_avail_bram_reg.value):
    #         dut.eth_fifo_to_bram.axi_araddr.value = 0x20800000 + rx_pkt_word_addr # hex works  # rv sw board.h static volatile unsigned *const _netbrx = ((unsigned *)0x20800000);
    #         dut.eth_fifo_to_bram.axi_arvalid.value = 0b1   # this binary format works
    #         dut.eth_fifo_to_bram.axi_rready.value = 0b1
    #         rx_pkt_word_addr = rx_pkt_word_addr + 4
    #         rx_pkt_word_len = rx_pkt_word_len - 1
    #         # await RisingEdge(dut.clk)  
    #     await RisingEdge(dut.clk)

    # # dut.eth_fifo_to_bram.rx_clear.value = 0b1
    # # await RisingEdge(dut.clk)  # Works great. Clear bit in w_rx_ctrl reg as well.
    
    # # dut.eth_fifo_to_bram.rx_clear.value = 0b0 # check if FSM goes back to STATE_IDLE
    # # await RisingEdge(dut.clk)

    # dut.eth_fifo_to_bram.axi_araddr.value = 0x00  # this needed to be made 0 so that net_selb got 0, so that we were able to write to rx_clear. Otherwise it wasnt possible. 
    # # it isnt possible to write to rx or tx ctrl register while rx or tx pkt brams are being READ (for tx and rx) or WRITTEN (for tx) to by the RV core
    # dut.eth_fifo_to_bram.axi_arvalid.value = 0b0   # this binary format works
    # dut.eth_fifo_to_bram.axi_rready.value = 0b1  # rready is always 1 from rv. If this isnt 1, this FSM will stay stuck in this state
    #         # and rx_clear won't be cleared due the the araddr from rx pkt reading making netselb HIGH due to its
    #         # address being stored in ar_addr_buf from the previous state
    # await RisingEdge(dut.clk)

    # if(dut.eth_fifo_to_bram.axi_rvalid.value):  # double check if rready stays HIGH in rv core
    #     dut.eth_fifo_to_bram.axi_rready.value = 0b0  
    #     await RisingEdge(dut.clk)

    # # write code to send rx_clear using axi_write protocol instead of manually from cocotb as done above
    #     # rx pkt reception FSM will be stuck in last state till rx_clear bit is set as follows:
    # if (dut.eth_fifo_to_bram.rx_pkt_avail_bram_reg.value):
    #     while (dut.eth_fifo_to_bram.b_valid.value == 0):
    #         dut.eth_fifo_to_bram.axi_awaddr.value = 0x20500000  # rv sw board.h static volatile ENETPACKET *const _net1 = ((ENETPACKET *)0x20500000); 
    #         dut.eth_fifo_to_bram.axi_awvalid.value = 0b1   # this binary format works
    #         dut.eth_fifo_to_bram.axi_wdata.value = 0x00004000   # rv sw board.h define   ENET_RXAVAIL        0x004000 = 0100 0000 0000 0000 (1 on bit no [14] (15th bit))
    #         dut.eth_fifo_to_bram.axi_wstrb.value = 0b1111   
    #         dut.eth_fifo_to_bram.axi_wvalid.value = 0b1
    #         dut.eth_fifo_to_bram.b_ready.value = 0b1
    #         print("HELLO")  # yep stuck here
    #         await RisingEdge(dut.clk)

    # # assuiming that rv core wr_ctrl and wr_addr will go to 0 after this access. double check it as well.
    # dut.eth_fifo_to_bram.axi_awaddr.value = 0x00  # rv sw board.h static volatile ENETPACKET *const _net1 = ((ENETPACKET *)0x20500000); 
    # dut.eth_fifo_to_bram.axi_awvalid.value = 0b0   # this binary format works
    # dut.eth_fifo_to_bram.axi_wdata.value = 0x00000000   # rv sw board.h define   ENET_RXAVAIL        0x004000 = 0100 0000 0000 0000 (1 on bit no [14] (15th bit))
    # dut.eth_fifo_to_bram.axi_wstrb.value = 0b0000   
    # dut.eth_fifo_to_bram.axi_wvalid.value = 0b0
    # dut.eth_fifo_to_bram.b_ready.value = 0b1
    # await RisingEdge(dut.clk)

    # # after the write is done, b_valid will be 1 and rx_clear will be set which will cause the rx pkt reception FSM
    # # to start transferring rx pkt from the eth fifo to the rx pkt bram again

    # # dut.eth_fifo_to_bram.axi_arvalid.value = 0b0   # this binary format works
    # # dut.eth_fifo_to_bram.axi_rready.value = 0b0
    # # await RisingEdge(dut.clk)

    # await Timer(5000, units="ns")  # wait a bit  
    # # rx pkt comes in around 2.5 us

    # if(dut.eth_fifo_to_bram.rx_pkt_avail_bram_reg.value):  # reading the last rx pkt word again
    #     dut.eth_fifo_to_bram.axi_araddr.value = 0x20800000 + rx_pkt_word_addr 
    #     dut.eth_fifo_to_bram.axi_arvalid.value = 0b1   # this binary format works
    #     dut.eth_fifo_to_bram.axi_rready.value = 0b1
    # await RisingEdge(dut.clk)
    
    # block comment ENDS HERE

    # await Timer(30000, units="ns")  # wait a bit  

    # # To see the results of " 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex", uncomment the await Timer commands below
    # await Timer(300, units="us")  # wait 300 us
    # await Timer(300, units="us")  # wait 300 us
    # await Timer(900, units="us")    # additional 900 us time for 2022_11_28_edgetestbed_a100T8_multiRxPkt_reads_fromMem_sim so that rx pkt can be displayed on uart tx
    # await Timer(2000, units="us")  # wait 2000 us  # additional 2000 us time for 2022_11_28_edgetestbed_a100T8_multiRxPkt_reads_fromMem_sim
    # await Timer(2000, units="us")  # wait 2000 us  # additional 2000 us time for 2022_11_28_edgetestbed_a100T8_multiRxPkt_reads_fromMem_sim
    # await Timer(900, units="us")  # wait 900 us  # need this for displaying full rx pkt in 2022_11_17_netowrkSub_rx_pkt_memWrite_read_6_sim.hex
    # await Timer(900, units="us")  # wait 900 us  # uncommented these to see the leds turining on for the 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex file, at 1.6 ms :3
    
    # everything gets done at 350 us (led4 gets HIGH the second time) for 2023_4_3_edgetestbed_a100T12_synthesis_multiRxPkt_reads_fromMem_sim.hex
    # so comment all the extra await timers above

    # await Timer(50, units="us") 
    # await Timer(400, units="us")  # wait 300 us
    # await Timer(300, units="us")  # wait 300 us

    # await Timer(1000, units="us")  # wait 1000 us

    # await Timer(20000, units="us")
    # await Timer(15000, units="us")

    await RisingEdge(dut.sys_clk_p)
    await RisingEdge(dut.sys_clk_p)

    # =====================================================================
    # APPLICATION-LEVEL ASSERTIONS
    #
    # Until these existed, this testbench had NO active assertions at all --
    # every one in the file was commented out -- so it passed as long as the
    # simulation reached the end without a Python exception. It could not fail
    # on wrong firmware, wrong eBPF rules, or a VeBPF core erroring out. It
    # notably did not fail during the long period when the RTL's hardcoded
    # $readmemh paths were silently loading nothing at all.
    #
    # Failures are collected and reported together rather than aborting on the
    # first one, so a broken run tells you everything that is wrong at once.
    # =====================================================================
    tb.log.info("=" * 70)
    tb.log.info("APPLICATION-LEVEL ASSERTIONS")
    tb.log.info("=" * 70)

    _failures = []

    def _read(path_desc, handle):
        """Read a signal, turning a bad read into a reported failure rather than
        a traceback. Two distinct problems are worth separating:
          - the value contains X/Z, i.e. the register was never driven or a
            memory was never initialized (the historical failure mode here); or
          - the handle itself is unreadable, i.e. renamed, optimized away, or
            the hierarchy path is wrong.
        """
        try:
            raw = handle.value
        except Exception as exc:                      # noqa: BLE001
            _failures.append(f"{path_desc}: signal not readable ({exc!r}) -- "
                              f"renamed, optimized away, or wrong hierarchy path?")
            return None
        try:
            return int(raw)
        except Exception:                             # noqa: BLE001
            _failures.append(f"{path_desc}: value is UNINITIALIZED (contains x/z: {raw}) -- "
                              f"nothing ever drove this. For a memory, that means the "
                              f"image was never loaded.")
            return None

    def _check(desc, got, want):
        if got is None:
            return
        if got != want:
            _failures.append(f"{desc}: got {got} (0x{got:X}), expected {want} (0x{want:X})")
        else:
            tb.log.info(f"  OK  {desc} = {got}")

    # ---------------------------------------------------------------------
    # 1. The eBPF rules really are in the cores' program memory.
    #
    # Read back against the SAME image the RTL was told to load -- staged by
    # disl-core's MEM_INIT into <build_dir>/mem/ -- so this check maintains
    # itself when the rule set changes, and fails loudly if the image is not
    # loaded, is the wrong file, or is mis-padded.
    # ---------------------------------------------------------------------
    _rules_img = os.path.join("..", "mem", "progloader_v2.RULES_INIT_FILE.hex")
    if not os.path.isfile(_rules_img):
        _failures.append(f"staged eBPF rules image missing: {_rules_img} "
                          f"(MEM_INIT should have produced it)")
    else:
        _words = []
        with open(_rules_img) as f:
            for line in f:
                _words.extend(line.split("//", 1)[0].split())
        tb.log.info(f"  staged rules image: {len(_words)} words from {_rules_img}")

        # Compare the leading real rule content word-for-word. Everything past
        # it is MEM_INIT zero padding, spot-checked below.
        _n_real = 64
        _mismatch = 0
        for i in range(min(_n_real, len(_words))):
            got = _read(f"instrs[{i}]", dut.progloader_v2.genblk4.instrs[i])
            if got is None:
                break
            want = int(_words[i], 16)
            if got != want:
                _mismatch += 1
                if _mismatch <= 4:
                    _failures.append(
                        f"eBPF rule word {i} not loaded correctly: "
                        f"memory has 0x{got:016X}, image has 0x{want:016X}")
        if _mismatch == 0:
            tb.log.info(f"  OK  first {_n_real} eBPF rule words match the staged image exactly")
        elif _mismatch > 4:
            _failures.append(f"...and {_mismatch - 4} further eBPF rule word mismatches")

        # Padding must be zeros, not X -- an unpadded image used to leave the
        # tail of this memory undefined.
        for i in (len(_words) - 1, len(_words) // 2):
            if i >= _n_real:
                got = _read(f"instrs[{i}] (padding)", dut.progloader_v2.genblk4.instrs[i])
                _check(f"eBPF rules padding at word {i} is zero", got, 0)

    # ---------------------------------------------------------------------
    # 2. Nothing errored. These are the flags the design raises when a VeBPF
    #    core faults or the result path detects a bad outcome; any of them set
    #    means the run was not clean, however far the simulation got.
    # ---------------------------------------------------------------------
    _nic = dut.eth_nic.eth_fifo_to_bram
    _check("VeBPF_error_combined_global (any core errored)",
           _read("VeBPF_error_combined_global", _nic.VeBPF_error_combined_global), 0)
    _check("VeBPF result-evaluator final error flag",
           _read("final_result_error_flag_reg",
                 _nic.VeBPF_result_evaluator_final_result_error_flag_reg), 0)
    _check("VeBPF rules-scheduler error flag",
           _read("VeBPF_rules_scheduler_error_flag",
                 _nic.VeBPF_rules_scheduler_error_flag), 0)

    # ---------------------------------------------------------------------
    # 3. Every descriptor-table slot reports a clean, completed classification.
    #    RX_PKT_DESC_TABLE_DEPTH is 4, so these are the last four packets the
    #    VeBPF array classified.
    # ---------------------------------------------------------------------
    _DESC_DEPTH = 4
    for i in range(_DESC_DEPTH):
        _check(f"descriptor slot {i} error bit",
               _read(f"desc_table error_bit[{i}]",
                     _nic.desc_table_VeBPF_rx_pkt_hdr_processing_done_result_error_bit[i]), 0)

    # ---------------------------------------------------------------------
    # 4. The verdicts themselves -- the actual firewall output.
    #
    # GOLDEN VALUES for this example's fixed stimulus and rule set. Four
    # packets classified to four DIFFERENT destinations, which is what makes
    # this a real check on the eBPF programs rather than on plumbing: wrong or
    # unloaded rules do not produce this pattern. Update deliberately if the
    # stimulus or rule set changes, and say why in the commit.
    # ---------------------------------------------------------------------
    _EXPECTED_VERDICTS = [5, 3, 4, 1]
    for i, want in enumerate(_EXPECTED_VERDICTS):
        _check(f"descriptor slot {i} rx_pkt_destination (VeBPF verdict)",
               _read(f"desc_table destination[{i}]",
                     _nic.desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination[i]),
               want)

    _check("VeBPF result-evaluator final result",
           _read("final_result_reg", _nic.VeBPF_result_evaluator_final_result_reg), 5)

    # ---------------------------------------------------------------------
    # 5. The cores actually ran. A halt is how a VeBPF core signals that an
    #    eBPF program reached EXIT, so zero halts across the whole run means
    #    nothing executed -- exactly the symptom of rules never loading.
    # ---------------------------------------------------------------------
    _halts = _halt_count["n"]
    _MIN_HALTS = 4          # one per classified packet; 4 observed on a good run
    if _halts < _MIN_HALTS:
        _failures.append(
            f"only {_halts} VeBPF halt event(s) observed, expected at least "
            f"{_MIN_HALTS} (one per classified packet). Zero would mean the "
            f"cores never completed an eBPF program at all.")
    else:
        tb.log.info(f"  OK  VeBPF halt events observed: {_halts} (>= {_MIN_HALTS})")

    # ---------------------------------------------------------------------
    # 6. The RISC-V control plane actually did its job.
    #
    # Everything above tests the VeBPF data plane. These check the *software*
    # side: the firmware polls the network CSRs, reads each packet's descriptor
    # and VeBPF verdict, then acknowledges by writing NET_RX_PKT_AVAIL_CLEAR and
    # NET_RX_FIFO_RD_PTR_INC. So the rx descriptor read pointer only advances
    # because the firmware advanced it.
    #
    # This is what makes it a real check on the control plane: the WRITE pointer
    # is driven by hardware and advances whether or not the CPU is alive, while
    # the READ pointer moves only if the firmware ran, understood the CSR layout
    # and kept up. Firmware that never started, hung, or busy-looped without
    # acknowledging leaves read at 0 while write climbs.
    # ---------------------------------------------------------------------
    _wr = _read("wr_fifo_ptr_rx_pkt_reg", _nic.wr_fifo_ptr_rx_pkt_reg)
    _rd = _read("rd_fifo_ptr_rx_pkt_reg", _nic.rd_fifo_ptr_rx_pkt_reg)

    _EXPECTED_RX_DESCRIPTORS = 5    # golden: packets enqueued by this stimulus
    _check("rx descriptors enqueued by hardware (write pointer)", _wr,
           _EXPECTED_RX_DESCRIPTORS)

    if _rd is not None and _wr is not None:
        if _wr == 0:
            # Both pointers at zero is NOT a passing drain -- it means no
            # descriptor was ever enqueued, so there was nothing to drain and
            # this check would otherwise pass vacuously. Found by fault
            # injection: with no firmware loaded the RISC-V never arms packet
            # reception, so the hardware never enqueues either and rd == wr == 0.
            _failures.append(
                "no rx descriptor was ever enqueued (read == write == 0), so the "
                "control plane had nothing to consume. The firmware never armed "
                "packet reception -- check that it loaded and started.")
        elif _rd == 0:
            _failures.append(
                f"the RISC-V control plane consumed NOTHING: hardware enqueued {_wr} rx "
                f"descriptor(s) but the firmware's read pointer is still 0. The firmware "
                f"never ran, hung, or is not acknowledging via NET_RX_FIFO_RD_PTR_INC.")
        elif _rd != _wr:
            _failures.append(
                f"the RISC-V control plane did not drain the rx descriptor queue: "
                f"read pointer {_rd} != write pointer {_wr} ({_wr - _rd} descriptor(s) "
                f"left unconsumed).")
        else:
            tb.log.info(f"  OK  control plane drained every rx descriptor "
                        f"(read == write == {_rd}, non-zero)")

    # The length the firmware latched when it read a descriptor. Zero or X here
    # would mean it read the register but got nothing meaningful out of it.
    _check("packet length read by the firmware from the descriptor table",
           _read("desc_table_rx_pkt_len_rd_ptr_reg", _nic.desc_table_rx_pkt_len_rd_ptr_reg),
           70)

    # The VeBPF verdict the firmware most recently latched. Must be one the data
    # plane actually produced (section 4), not a stale or garbage value -- this
    # is the hand-off point between the two planes.
    _verdict_read = _read(
        "desc_table_..._rx_pkt_destination_rd_ptr_reg",
        _nic.desc_table_VeBPF_rx_pkt_hdr_processing_done_result_rx_pkt_destination_rd_ptr_reg)
    if _verdict_read is not None:
        if _verdict_read not in _EXPECTED_VERDICTS:
            _failures.append(
                f"the verdict the firmware read ({_verdict_read}) is not one the VeBPF "
                f"array produced {_EXPECTED_VERDICTS}; the data plane and control plane "
                f"disagree about this packet.")
        else:
            tb.log.info(f"  OK  verdict read by the firmware ({_verdict_read}) is one the "
                        f"VeBPF array produced")

    # The firmware image is really in the RISC-V instruction memory. Same idea
    # as the eBPF rules check, read back against the image MEM_INIT staged.
    # Icarus does not always expose a large unpacked memory over VPI, so an
    # unreadable handle is reported as a skip rather than a failure -- it is a
    # simulator limitation, not a defect in the design.
    _fw_img = os.path.join("..", "mem", "cache_bram_cachecontroller_v2.MEM_INIT_FILE.hex")
    if not os.path.isfile(_fw_img):
        _failures.append(f"staged RISC-V firmware image missing: {_fw_img}")
    else:
        _fw_words = []
        with open(_fw_img) as f:
            for line in f:
                _fw_words.extend(line.split("//", 1)[0].split())
        try:
            _probe = int(dut.cache_bram_cachecontroller_v2.mem[0].value)
        except Exception as exc:                      # noqa: BLE001
            tb.log.warning(f"  SKIP  RISC-V firmware memory not readable over VPI "
                            f"({type(exc).__name__}); relying on the control-plane "
                            f"pointer checks above instead")
            _probe = None
        if _probe is not None:
            _fw_mismatch = 0
            for i in range(min(32, len(_fw_words))):
                got = _read(f"riscv mem[{i}]", dut.cache_bram_cachecontroller_v2.mem[i])
                if got is None:
                    break
                want = int(_fw_words[i], 16)
                if got != want:
                    _fw_mismatch += 1
                    if _fw_mismatch <= 3:
                        _failures.append(
                            f"RISC-V firmware word {i} not loaded correctly: memory has "
                            f"0x{got:08X}, staged image has 0x{want:08X}")
            if _fw_mismatch == 0:
                tb.log.info("  OK  first 32 RISC-V firmware words match the staged image")

    # ---------------------------------------------------------------------
    tb.log.info("=" * 70)
    if _failures:
        tb.log.error(f"{len(_failures)} APPLICATION-LEVEL CHECK(S) FAILED:")
        for f in _failures:
            tb.log.error(f"    - {f}")
        raise AssertionError(
            f"{len(_failures)} application-level check(s) failed; see the log above. "
            f"First: {_failures[0]}")
    tb.log.info("ALL APPLICATION-LEVEL ASSERTIONS PASSED")
    tb.log.info("=" * 70)

    #z
    # test_framez = Ether(bytes(test_frame.get_payload()))
    # tb.log.info("TX UDP packet to Arty is: %s", repr(test_framez)) # works but displays some garbage values (as the other commands do)

      
    # tb.log.info("receive ARP request")

    # rx_frame = await tb.rgmii_phy.tx.recv() # wait here till ARP req is received

    # rx_pkt = Ether(bytes(rx_frame.get_payload()))

    # tb.log.info("RX packet: %s", repr(rx_pkt))

    # assert rx_pkt.dst == 'ff:ff:ff:ff:ff:ff'
    # assert rx_pkt.src == test_pkt.dst
    # assert rx_pkt[ARP].hwtype == 1
    # assert rx_pkt[ARP].ptype == 0x0800  # means this ARP packet is for IPv4 type IP packet
    # assert rx_pkt[ARP].hwlen == 6
    # assert rx_pkt[ARP].plen == 4
    # assert rx_pkt[ARP].op == 1
    # assert rx_pkt[ARP].hwsrc == test_pkt.dst
    # assert rx_pkt[ARP].psrc == test_pkt[IP].dst
    # assert rx_pkt[ARP].hwdst == '00:00:00:00:00:00'
    # assert rx_pkt[ARP].pdst == test_pkt[IP].src

    # tb.log.info("send ARP response")

    # eth = Ether(src=test_pkt.src, dst=test_pkt.dst)
    # arp = ARP(hwtype=1, ptype=0x0800, hwlen=6, plen=4, op=2,
    #     hwsrc=test_pkt.src, psrc=test_pkt[IP].src,
    #     hwdst=test_pkt.dst, pdst=test_pkt[IP].dst)
    # resp_pkt = eth / arp

    # resp_frame = GmiiFrame.from_payload(resp_pkt.build())  # pads zeros automatically if framelength is less than minimum

    # await tb.rgmii_phy.rx.send(resp_frame)
    # #z
    # test_framez2 = Ether(bytes(resp_frame.get_payload()))
    # tb.log.info("TX ARP response packet to Arty is: %s", repr(test_framez2)) # works but displays some garbage values

    # tb.log.info("receive UDP packet")

    # rx_frame = await tb.rgmii_phy.tx.recv()

    # rx_pkt = Ether(bytes(rx_frame.get_payload()))

    # tb.log.info("RX packet: %s", repr(rx_pkt))

    # sending test frame again
    # test_frame = GmiiFrame.from_payload(test_pkt.build())
    # await tb.rgmii_phy.rx.send(test_frame)
    # tb.log.info("TX UDP packet 2 to Arty is: %s", repr(test_frame))

    # # receive test frame again

    # rx_frame = await tb.rgmii_phy.tx.recv()

    # rx_pkt = Ether(bytes(rx_frame.get_payload()))

    # tb.log.info("RX packet 2: %s", repr(rx_pkt))

    # assert rx_pkt.dst == test_pkt.src
    # assert rx_pkt.src == test_pkt.dst
    # assert rx_pkt[IP].dst == test_pkt[IP].src
    # assert rx_pkt[IP].src == test_pkt[IP].dst
    # assert rx_pkt[UDP].dport == test_pkt[UDP].sport
    # assert rx_pkt[UDP].sport == test_pkt[UDP].dport
    # assert rx_pkt[UDP].payload == test_pkt[UDP].payload

    await RisingEdge(dut.sys_clk_p)
    await RisingEdge(dut.sys_clk_p)


# cocotb-test

# THE SIMULATION WAS just getting stuck without reporting any errors for edgetestbed_a100T14_sim_FROM_CODES1server_ExperimentalStuff.
# Following were the bugs:
    # REMEMBER TO REPLACE THE PROG_LOADER HDL AS WELL (use the sim HDL and not the syn HDL)
    # Sim was getting stuck cx I had not added SIMULATION parameter to the eth_nic_100m_mmi.v module instantiation in the top.v of edgetestbed_a100T14_sim_FROM_CODES1server_ExperimentalStuff

# run make using the following flags for cocotb debugging
# make WAVES=1 COCOTB_SCHEDULER_DEBUG=1 COCOTB_ENABLE_PROFILING=1 COCOTB_LOG_LEVEL=DEBUG

# press "Ctrl+c" during simulation of icarus verilog console debugging and use commands like "cont", "finish", "step" etc
# finish: This finished the simulation causing the waveform to be generated which I am currently using to debug my FSMs although that 
# simulation waveform is limited till the time the cocotb simulation froze up

# https://steveicarus.github.io/iverilog/usage/vvp_debug.html
 
project_name = 'edgetestbed_a100T30_cocotbsim_sim'  
# project_name = 'edgetestbed_a100T29_pgmLoader_cocotbsim_simv2'  
# project_name = 'edgetestbed_a100T28_sim_converted_to_syn_sim'  
# project_name = 'edgetestbed_a100T27_sim'  
# project_name = 'edgetestbed_a100T26_sim'  
# project_name = 'edgetestbed_a100T25_sim'  
# project_name = 'edgetestbed_a100T24_sim'  
# project_name = 'edgetestbed_a100T23_sim'  
# project_name = 'edgetestbed_a100T22_sim'  
# project_name = 'edgetestbed_a100T21_sim'  
# project_name = 'edgetestbed_a100T20_sim_FROM_CODES1server_ExperimentalStuff'  
# project_name = 'edgetestbed_a100T19_sim_FROM_CODES1server_ExperimentalStuff'  
# project_name = 'edgetestbed_a100T18_sim_FROM_CODES1server_ExperimentalStuff'
# project_name = 'edgetestbed_a100T17_sim_FROM_CODES1server_ExperimentalStuff'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T16_sim_FROM_CODES1server_ExperimentalStuff'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T15_sim_FROM_CODES1server_ExperimentalStuff'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T14_sim_FROM_CODES1server_ExperimentalStuff'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T13_sim'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T11_sim'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T10_sim'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T9_sim'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T8_sim'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T7_sim'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T6_sim'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T5_sim'  # uncomment these dut.sw[2].value = 1 for the hex file 2022_8_12_Demo_DST_IP_DST_UDP_PORT_sim.hex
# project_name = 'edgetestbed_a100T4_sim'

cwd = os.getcwd()

# tests_dir = os.path.abspath(os.path.dirname(__file__))
# print("HElooooooooooooooo2",tests_dir)

# proj_top_dir = os.path.join(cwd, '..', '..', '..', '..','tests', project_name, 'hdl')

# eth_top_dir = os.path.join(cwd, '..', '..', 'hdl')
# eth_top_dir_files = os.listdir(eth_top_dir)

# eth_rtl_dir = os.path.join(cwd, '..', '..', 'hdl', 'lib', 'eth', 'rtl')
# eth_rtl_dir_files = os.listdir(eth_rtl_dir)

# axis_rtl_dir = os.path.join(cwd, '..', '..', 'hdl', 'lib', 'axis', 'rtl')
# axis_rtl_dir_files = os.listdir(axis_rtl_dir)

build_dir = os.path.join(cwd, '..')
build_dir_files = os.listdir(build_dir)
print(f"build_dir = {build_dir}")
# build_dir_files_filtered = [os.path.join(build_dir, file) for file in build_dir_files if ((file[-1] == 'v') or (file[-2:] == 'vh'))]

# softcore_dir = os.path.join(cwd, '..', '..', '..', 'softcore_subsystem','riscv32i', 'hdl')
# softcore_dir_files = os.listdir(softcore_dir)
# # softcore_dir_files_filtered = [os.path.join(softcore_dir, file) for file in softcore_dir_files if ((file[-1] == 'v') or (file[-2:] == 'vh'))]

# smartswitch_dir = os.path.join(cwd, '..', '..', '..', 'smartswitch_subsystem', 'hdl')
# smartswitch_dir_files = os.listdir(smartswitch_dir)
# # smartswitch_dir_files_filtered = [os.path.join(smartswitch_dir, file) for file in smartswitch_dir_files if ((file[-1] == 'v') or (file[-2:] == 'vh'))]

# memory_subsystem_dir = os.path.join(cwd, '..', '..', '..', 'memory_subsystem', 'hdl')
# memory_subsystem_dir_files = os.listdir(memory_subsystem_dir)

# VeBPF_dir = os.path.join(cwd, '..', '..', 'VeBPF', 'DISL_FPGA_eBPF', 'DISL_Verilog_eBPF')

# programmer_subsystem_dir = os.path.join(cwd, '..', '..', '..', 'programmer_subsystem', 'hdl')

# xilinx_unisim_dir = os.path.abspath(os.path.join('/', 'home', 'zaidtahir', 'XilinxUnisimLibrary', 'verilog', 'src', 'unisims'))
# xilinx_unisim_dir_files = os.listdir(xilinx_unisim_dir)
# # xilinx_unisim_dir_files_filtered  = [os.path.join(xilinx_unisim_dir, file) for file in xilinx_unisim_dir_files if ((file == 'BUFG.v') or (file == 'BUFIO.v') or (file == 'BUFR.v'))]
# xilinx_unisim_dir_files_filtered2 = os.path.join(xilinx_unisim_dir, '..', 'glbl.v')

# def test_fpga_core(request):
def test_top(request):
    # dut = "fpga_core"
    dut = "top"
    module = os.path.splitext(os.path.basename(__file__))[0]  # test_top
    toplevel = dut
    VeBPF = "cpu"

    verilog_sources = [
        os.path.join(build_dir_files, f"{dut}.v")
        # os.path.join(proj_top_dir, f"{dut}.v"),
        # os.path.join(memory_subsystem_dir, "softcore_memory_bus_grant.v"),
        # os.path.join(memory_subsystem_dir, "bram_axi_cachecontroller.v"),
        # os.path.join(VeBPF_dir, f"{VeBPF}.v"),
        # os.path.join(VeBPF_dir, "divider.v"),
        # os.path.join(VeBPF_dir, "call_handler.v"),
        # os.path.join(VeBPF_dir, "shifter.v"),
        # os.path.join(VeBPF_dir, "ram_module_v3.v"),
        # os.path.join(VeBPF_dir, "ram64_memory_v1.v"),
        # os.path.join(VeBPF_dir, "ram64_memory_v3.v"),
        # os.path.join(programmer_subsystem_dir, "progloader_axi.v")
    ]

    # for file in eth_top_dir_files:
    #     if ((file[-1] == 'v') or (file[-2:] == 'vh')):
    #         verilog_sources.append(os.path.join(eth_top_dir, file))
    #     else:
    #         pass

    # for file in eth_rtl_dir_files:
    #     if ((file[-1] == 'v') or (file[-2:] == 'vh')):
    #         verilog_sources.append(os.path.join(eth_rtl_dir, file))
    #     else:
    #         pass

    # for file in axis_rtl_dir_files:
    #     if ((file[-1] == 'v') or (file[-2:] == 'vh')):
    #         verilog_sources.append(os.path.join(axis_rtl_dir, file))
    #     else:
    #         pass

    for file in build_dir_files:
        if ((file[-1] == 'v') or (file[-2:] == 'vh')):
            verilog_sources.append(os.path.join(build_dir, file))
        else:
            pass

    # for file in softcore_dir_files:
    #     if ((file[-1] == 'v') or (file[-2:] == 'vh')):
    #         verilog_sources.append(os.path.join(softcore_dir, file))
    #     else:
    #         pass

    # for file in smartswitch_dir_files:
    #     if ((file[-1] == 'v') or (file[-2:] == 'vh')):
    #         verilog_sources.append(os.path.join(smartswitch_dir, file))
    #     else:
    #         pass



    # for file in xilinx_unisim_dir_files:
    #     if ((file == 'BUFG.v') or (file == 'BUFIO.v') or (file == 'BUFR.v')):
    #         verilog_sources.append(os.path.join(xilinx_unisim_dir, file))
    #     else:
    #         pass


    parameters = {}

    # parameters['A'] = val
    


    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    # sys.exit("Sys exitingZ_0")

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    # print("HElooooooooooooooo",[tests_dir])
    # print("HElooooooooooooooo",module)
    # print("HElooooooooooooooo",toplevel)
    # print("HElooooooooooooooo",sim_build)
    # print("HElooooooooooooooo",verilog_sources)

    # run make using the following flags for cocotb debugging
    # make WAVES=1 COCOTB_SCHEDULER_DEBUG=1 COCOTB_ENABLE_PROFILING=1 COCOTB_LOG_LEVEL=DEBUG

    # press "Ctrl+c" during simulation of icarus verilog console debugging and use commands like "cont", "finish", "step" etc
    # finish: This finished the simulation causing the waveform to be generated which I am currently using to debug my FSMs although that 
    # simulation waveform is limited till the time the cocotb simulation froze up
    
    # print("from Printing cocotb_test.simulator whole path of the file = ")

    # import inspect
    # print(inspect.getfile(cocotb_test.simulator))  # inspecting where this func came from

    # sys.exit("Sys exitingZ ")

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )
