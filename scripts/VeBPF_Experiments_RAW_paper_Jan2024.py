#!/usr/bin/env python
"""
UDP echo test
"""

import argparse
import socket
import time

def main():
    parser = argparse.ArgumentParser(description=__doc__.strip())
    parser.add_argument('host', help="Host", nargs='?', type=str, default='192.168.1.128')
    # parser.add_argument('host', help="Host", nargs='?', type=str, default='240.0.0.128')
    # parser.add_argument('port', help="UDP port", nargs='?', type=int, default=1234)
    parser.add_argument('-port', help="UDP port", nargs='?', type=int, default=1234)
    parser.add_argument('-n', help="Number of packets", type=int, default=1000)
    parser.add_argument('-pkt_len', help="Length of packets", type=int, default=1)

    # arg.host = 192.168.1.1 when I did: python VeBPF_Experiments_RAW_paper_Jan2024.py "192.168.1.1" -n 1
    # so the arguments without a dash are inputted as positional arguments and not as KEYWORD arguments
        # using this logic I can test out the different firewall rules packets.. type 1,2,3 rxpkts (txpkts actually)

    # ran this script using: python VeBPF_Experiments_RAW_paper_Jan2024.py "128.0.0.1" -port 4045 -n 30 -pkt_len 4


    args = parser.parse_args()
    
    host = args.host
    # host = '192.168.1.128'

    print(f"arg.host = {host}")
        # arg.host = 192.168.1.1 when I did: python VeBPF_Experiments_RAW_paper_Jan2024.py "192.168.1.1" -n 1


    
    port = args.port
    n = args.n
    
    # pkt_len = args.pkt_len
    # when I use args.pkt_len 0 the rpkt total len is 60 bytes, when I use args.pkt_len 18 the rxpkt len is still 60 bytes on wireshark
    # So I will add 18 to args.pkt_len 

    # we have 42 bytes of header data = eth header 14 bytes + ipv4 header 20 bytes + udp header 8 bytes = 42 bytes
    # minimum ethernet frame size is 64 bytes, but last 4 bytes are CRC and that gets appended automatically,
    # so real min ethernet frame size is 60 bytes.
        # When I send 0 arg.pkt_len, then 0s are padded (not to udp data but to eth packet), to make it 60 in length.
        # That is why if I make arg.pkt_len = 0 - 18, the sent eth pkts have len 42 + 18 = 60 bytes.. If I add a len 
        # more than 18 then it gets added as UDP data if I enter it less than 18 then the enetered amount that is less
        # than 18 gets added as UDP data and rest are 0s padded to eth frame.. 
        # So I'll add 18 to pkt_len but I also need to take care that I the limit for my eth frame len is 1518 - 42 = 1476
        # cx if I insert a length greater than 1476, the eth frame will be compiled as a jumbo frame and will be sent as small fragmented
        # ethernet frames..

    # table of args.pkt_len values 
    # Hence, if I need to send an eth frame of length 1500, then pkt_len should be 1500 - 42 = 1458 (AND its proved on wireshark right now)
    # Hence, if I need to send an eth frame of length 1024, then pkt_len should be 1024 - 42 = 982 (AND its proved on wireshark right now)
    # Hence, if I need to send an eth frame of length 512, then pkt_len should be 512 - 42 = 470 (AND its proved on wireshark right now)
    # Hence, if I need to send an eth frame of length 256, then pkt_len should be 256 - 42 = 214 (AND its proved on wireshark right now)
    # Hence, if I need to send an eth frame of length 128, then pkt_len should be 128 - 42 = 86 (AND its proved on wireshark right now)
    # Hence, if I need to send an eth frame of length 64, then pkt_len should be 64 - 42 = 22 (AND its proved on wireshark right now)

    pkt_len = args.pkt_len + 18
    # now when I use args.pkt_len 1 the rpkt total len is 61 bytes
    # and when I use args.pkt_len 0 the rpkt total len is 60 bytes
    
    # when 18 is added so the args.pkt_len table becomes as follows..
    # THIS TABLE WORKS FOR THIS FILE IN ALz LAPPI
        
    # args.pkt_len value for eth frame of length 1500 -> 1500 - 42  - 18 = 1440
    # args.pkt_len value for eth frame of length 1024 -> 1024 - 42  - 18 = 964
    # args.pkt_len value for eth frame of length 512 -> 512 - 42  - 18 = 452
    # args.pkt_len value for eth frame of length 256 -> 256 - 42  - 18 = 196
    # args.pkt_len value for eth frame of length 128 -> 128 - 42  - 18 = 68
    # args.pkt_len value for eth frame of length 64 -> 64 - 42  - 18 = 4

    # use above table for pkt_len values

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    # sock.bind(("1.2.3.4", 1200))
    # sock.bind(("0.0.0.0", 1200))
    # sock.bind(("0.0.0.0", 4200))
    # sock.bind(("240.0.0.0", 4200))
    # sock.bind(("0.0.1.0", 1200))
    # server.bind(("0.0.0.0", 6677)) 

    sock.settimeout(0)
    
    sent = 0
    recv = 0
    
    # data = b'testing'*100
    data = b'A'*pkt_len
    # above outputs b'testingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtesting'


    print(f"Sending {n} UDP packets to {host} on {port}...")
    
    while sent < n:
        try:
            sock.sendto(data, (host, port))
            sent += 1
            print(f"Total rxpkts sent = {sent}")
        except BlockingIOError:
            pass


        
        # time.sleep(0.0000000001)  # 0.0001 us = 0.1 ns
            # 13 rxpkts were consistently received when rxpkt len were 1518 (1514 without CRC) bytes
            # almost 80 -> NOPE XXXX
                # but these values were for rxpkts of length 700 ... when I was sending rxpkts of len 1460, only 10-15 rxpkts were being received consistently
                # These experiments have shown me that I have to use TOTAL_MALICIOUS_RXPKTS_FOR_LATENCY_CAL = 13 cx that covers up the latency for 1518 byte rxpkts

        time.sleep(0.000000001)  # 0.001 us = 1 ns
            # works for VeBPF now with v5 c file

        # time.sleep(0.00000001)  # 0.01 us = 10 ns
            # 84 were recvd ALMOST
            # 100 Mbps means 1 bites goes in 1/(100 Mbps) s = 10 ns per bit
            # but we are not sending 1 bit in this loop so we don't need to be restricted to running the loop every 10 ns
            # Lets say we are sending 1500 bytes each loop iteration.. Then the total loop iteration time required for the throughput to be 100 Mbps is:
                # 1500 bytes x 8 bits per byte x 10 ns per bit (loop iteration time req for each bit for 100 Mbps) = 120,000 ns (cancelling the units only ns remains)
                # = 120 us = 0.12 ms
                # but experiments below show that for sending 1000 rxpkts of len 700 bytes this much time per loop is req at least:
                    # time.sleep(0.002) = 2 ms
                    # the reason for requiring this much time vs all these other lower time values that I tested was that the DMA of network subsystem has limitations,
                    # but according to my caluclations previously while doing experiments in simulations, I believe that the DMA of network subsystem could support 100 Mbps
                    # but the problem is that the DMA of network subsystem is in constant fight with the RISCV to win over the memory bus grant through the memory grant arbitrer
                    # and after each rxpkt VeBPF result is read, the RISCV has to increment the rdptr of the desc_table in the network subsystem and run a bunch of other code as well
                    # so even if the network subsystem has by change won the memory bus grant for the full depth of the desc_table (4 is the depth atm), the memory bus grant would have
                    # to be given back to the RISCV which would run a bunch of other code, and I don't think that the network subsystem can continuously keep the memory bus grant for the num of
                    # rxpkts equal to the desc_table depth anyway, cx if I had a desc_table depth of 1000, then all 1000 rxpkts could have been written in one DMA surge if network subsystem
                    # could have kept the memory bus grant, even in that case I would have gotten delay since in the RISCV c code I am calculating the time while incrementing the rd_ptr 
                    # using the RISCV manually which then runs other RISCV instructions as well, introducing additional delays. 
                        # Hence even though VeBPF firewall framework has line-rate throughput calculated through the throughput experiments, we don't see that much throughput while calculating 
                        # latency per rxpkt cx it has tug of war between RISCV and network subsystem and RISCV running it own instructions. 


        # time.sleep(0.0000001)  # 0.1 us = 100 ns
            # 84 were recvd ALMOST.. good number

        # time.sleep(0.0000002)  # 0.2 us = 200 ns and works .. working with 100 rxpkts now... with smaller length of 61 bytes
            # 84 were recvd.. good number
            # this is too fast and doest work when I send 1000 rxpkts to arty... 1000 rxpkts of 800 bytes len = 800 x 8 x 1000 = 6400000 = 6.40 MB req.. whereas I only gave 32 kB in c file
                # only 100 rxpkts recvd ... 100 rxpkts of 800 bytes len = 800 x 8 x 100 = 640000 = 640 kB req.. whereas I only gave 32 kB in c file
            # if I send 1000 rxpkts of 64 bytes then total memory = 64 x 8 x 1000 = 512000 = 512 kB

            # table of sizes
                # 8000 rxpkts of size 1500 bytes, total size = 8000 x 1500 x 8 = 96,000,000 = 96 MB
                # 18000 rxpkts of size 1500 bytes, total size = 18000 x 1500 x 8 = 216,000,000 = 216 MB
                # 34000 rxpkts of size 1500 bytes, total size = 34000 x 1500 x 8 = 408,000,000 = 408 MB

                # but arty100t has 256MB DDR3L with a 16-bit bus @ 333 MHz (667 MT/s)
                # So I want to keep the maximum memory taken up by rxpkts to be 128 MB.. I'll give it 210 MBs
                    # dividing total pkts to be sent by 2
                    # 8000/2 rxpkts of size 1500 bytes, total size = 8000/2 x 1500 x 8 = 96,000,000/2 = 48 MB
                    # 18000/2 rxpkts of size 1500 bytes, total size = 18000/2 x 1500 x 8 = 216,000,000/2 = 108 MB
                    # 34000/2 rxpkts of size 1500 bytes, total size = 34000 x 1500 x 8 = 408,000,000/2 = 204 MB

            # incremented the memory but still only 100 rxpkts being received at line rate.. I guess thed desctable is being full and reaching its limits due to the extra instructions for riscv 

        # time.sleep(0.0000005)  # 0.5 us = 500 ns
            # 84 were recvd ALMOST.. good number

        # time.sleep(0.000001)  # 1 us = 1000 ns
            # 90 were recvd ALMOST..

        # time.sleep(0.000002)  # 2 us = 2000 ns
            # 200 were recvd ALMOST..
            # this is too fast and doest work when I send 1000 rxpkts to arty
            # These experiments have shown me that I have to use TOTAL_MALICIOUS_RXPKTS_FOR_LATENCY_CAL = 13 cx that covers up the latency for 1518 byte rxpkts


        # time.sleep(0.000050)  # 50 us

        # time.sleep(0.2)  # works perfectly.. leme divide it down by 10
            # https://docs.python.org/3/library/time.html 
            # Suspend execution of the calling thread for the given number of seconds. 
            # The argument may be a floating point number to indicate a more precise sleep time.

        # time.sleep(0.02)  # works for 1000 rxpkts: python VeBPF_Experiments_RAW_paper_Jan2024.py "128.0.0.1" -port 1234 -n 1000 -pkt_len 720
        # time.sleep(0.002) # 2ms  # works for 1000 rxpkts: python VeBPF_Experiments_RAW_paper_Jan2024.py "128.0.0.1" -port 1234 -n 1000 -pkt_len 720
        # time.sleep(0.0012) # 1.2ms  # DOESNOT works for 1000 rxpkts: python VeBPF_Experiments_RAW_paper_Jan2024.py "128.0.0.1" -port 1234 -n 1000 -pkt_len 720
        # time.sleep(0.0010) # 1 ms  # DOESNOT works for 1000 rxpkts.. 600 sent: python VeBPF_Experiments_RAW_paper_Jan2024.py "128.0.0.1" -port 1234 -n 1000 -pkt_len 720
        

        # time.sleep(0.001)  # DOES NOT works for 1000 rxpkts, only 700 or so rxpkts received, : python VeBPF_Experiments_RAW_paper_Jan2024.py "128.0.0.1" -port 1234 -n 1000 -pkt_len 720
        # time.sleep(0.0002) # 200 us  # DOES NOT works for 1000 rxpkts, only 300 or so rxpkts received, rest need to be dropped cx riscv can't increment the rdptr enough and that desc table depth is too low
                            #: python VeBPF_Experiments_RAW_paper_Jan2024.py "128.0.0.1" -port 1234 -n 1000 -pkt_len 720


        # try:
        #     ret = sock.recvfrom(1024)  #1024 is tcp/udp port
        #     recv += 1
        # except BlockingIOError:
        #     pass

    sock.settimeout(1)
    
    # while True:
    
    #     try:
    #         ret = sock.recvfrom(1024)
    #         recv += 1
    #     except socket.timeout:
    #         break
    
    # print(f"Sent {sent} packets")
    # print(f"Received {recv} packets ({recv/sent*100}%)")
    # print(f"Missed {sent-recv} packets ({(sent-recv)/sent*100}%)")


if __name__ == "__main__":
    main()
