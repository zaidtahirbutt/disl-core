#!/usr/bin/env python
"""
UDP echo test
"""

import argparse
import socket
import time
import sys

DEFAULT_UDP_DEST_PORT = 1234
# DEFAULT_HOST_DEST_IP = '192.168.1.128'
DEFAULT_HOST_DEST_IP = '129.0.0.1'

def main():
    parser = argparse.ArgumentParser(description=__doc__.strip())
    parser.add_argument('-sizes', help="Sizes of transmitted rxpkts for this experiment", type=int, default=64)
    parser.add_argument('-exp_type', help="Type of firewall rules for this experiment", type=int, default=1)
    parser.add_argument('-itrs', help="Number of times the exp is iterated", type=int, default=1)
    parser.add_argument('-riscv_used', help="If RISCV is being used for filtering, make this argument 1", type=int, default=0)
    # sys.exit("Manually exiting")
    # arg.host = 192.168.1.1 when I did: python VeBPF_Experiments_RAW_paper_Jan2024.py "192.168.1.1" -n 1
    # so the arguments without a dash are inputted as positional arguments and not as KEYWORD arguments
        # using this logic I can test out the different firewall rules packets.. type 1,2,3 rxpkts (txpkts actually)

    # VEBPF_PGM_LDR_V2 experimentation terminal commands: 
        # Set experimentation =  "VEBPF_PGM_LDR_V2"
        # Type1 size 64
            # python3 VeBPF_Experiments_HPEC_paper_v3_Sept2024.py -exp_type 1 -sizes 64
		# use this command for a single pkt "echo "HELLO" | nc -u 1.0.0.1 389"
    # HPEC2024 experimentation terminal commands:

        # ran this script using: 

            # I also tested the commands below work with "-itrs 2" as well for multiple iterations

            ###################################### Type1 ########################################### 

            # Type1 size 64
                # python3 VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 1 -sizes 64

            # Type1 size 128
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 1 -sizes 128

            # Type1 size 256    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 1 -sizes 256

            # Type1 size 512    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 1 -sizes 512

            # Type2 size 1024    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 1 -sizes 1024

            # Type1 size 1500
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 1 -sizes 1500

            ###################################### Type2 ###########################################

            # Type2 size 64
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 2 -sizes 64

            # Type2 size 128
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 2 -sizes 128

            # Type2 size 256    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 2 -sizes 256

            # Type2 size 512    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 2 -sizes 512

            # Type2 size 1024    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 2 -sizes 1024

            # Type2 size 1500
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 2 -sizes 1500

            ###################################### Type3 ###########################################

            # Type3 size 64
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 3 -sizes 64

            # Type3 size 128
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 3 -sizes 128

            # Type3 size 256    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 3 -sizes 256

            # Type3 size 512    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 3 -sizes 512

            # Type3 size 1024    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 3 -sizes 1024

            # Type3 size 1500
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 3 -sizes 1500

            ###################################### Type4 ###########################################

            # Type4 size 64
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 4 -sizes 64

            # Type4 size 128
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 4 -sizes 128

            # Type4 size 256    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 4 -sizes 256

            # Type4 size 512    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 4 -sizes 512

            # Type4 size 1024    
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 4 -sizes 1024

            # Type4 size 1500
                # python VeBPF_Experiments_RAW_paper_Jan2024_v2_Final_used.py -exp_type 4 -sizes 1500



    args = parser.parse_args()
    
    print(f"Experiment configs are as follows: exp_type = {args.exp_type}, rxpkt size = {args.sizes}, experiment iterations = {args.itrs}")

    exp_iterations = args.itrs
    exp_type = args.exp_type

    # experimentation = "POST_VEBPF_PGM_LDR_V2_HPEC" #"VEBPF_PGM_LDR_V2" # or "HPEC2024"

    experimentation =  "VEBPF_PGM_LDR_V2"   #"HPEC2024" # or "VEBPF_PGM_LDR_V2"
        # python VeBPF_Experiments_HPEC_paper_v3_Sept2024.py
            # use this for the simple demo experiment

    # host = args.host
    # host = '192.168.1.128'

    # print(f"arg.host = {host}")
        # arg.host = 192.168.1.1 when I did: python VeBPF_Experiments_RAW_paper_Jan2024.py "192.168.1.1" -n 1


    
    # port = args.port
    # n = args.n
    
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

    # pkt_len = args.pkt_len + 18
    # now when I use args.pkt_len 1 the rpkt total len is 61 bytes
    # and when I use args.pkt_len 0 the rpkt total len is 60 bytes
    
    # when 18 is added so the args.pkt_len table becomes as follows: THIS IS WRONG!!!!!!!!!!!!!!!! The table above is correct!
        # For ALz lappi this table is correct FOR THE v1 of this file, not this FILE!!!.. since it doesnt have a VM.. 
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
    # data = b'A'*pkt_len
    # above outputs b'testingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtestingtesting'
    
    # Before doing the experiments, configure your linux as follows

    # • Adding static arp entries so they dont get deleted:
    #     To add STATIC arp entries that dont get delete when ethernet is unplugged:
    #         sudo arp -i enp20s0 -s 1.0.0.1 05:00:00:00:00:00
    #     The only way to delete these static arp entries is by using:
    #         sudo arp -i enp20s0 -d 1.0.0.1
    #     ○ Modify the arp commands below:
    # • sudo arp -s 192.168.1.128 02:00:00:00:00:00
    # • sudo arp -s 245.255.255.1 02:00:00:00:00:01
    # • sudo arp -s 128.0.0.1 02:00:00:00:00:02
    # • sudo arp -s 240.0.0.1 02:00:00:00:00:03
    # • sudo arp -s 1.0.0.1 02:00:00:00:00:04
    # • sudo arp -s 129.0.0.1 02:00:00:00:00:05
    # • arp -a
    # • Adding following ips as src laptop ipz to ALz laptop
    #     1. 192.168.1.100
    #     2. 245.255.255.255  // correction this needs to be 245:255:255:0 instead of 245:255:255:255 since i was getting an error that the last 8 bits being 1s i.e. 255 means its a broadcast address
    #     3. 128.0.0.0
    #     4. 240.0.0.0
    #     5. 1.0.0.0
    #     6. 129.0.0.0 (for testing purposes)
    #     Don't put any GATEWAY address in 
    # Put 255.255.255.0 as Netmask for all

    # hosts for type1 firewall i.e., dest ip addr
    host_firewall_type1_rule1 = '245.255.255.1'  # corresponds to src addr of '245.255.255.255'
    host_firewall_type1_rule2 = '128.0.0.1'  # corresponds to src addr of '128.0.0.0'
    host_firewall_type1_rule3 = '240.0.0.1'  # corresponds to src addr of '240.0.0.0'
    host_firewall_type1_rule4 = '1.0.0.1'  # corresponds to src addr of '1.0.0.0'

    # UDP destination ports for type2 firewall 
    host_firewall_type2_rule5 = 111
    host_firewall_type2_rule6 = 2000
    host_firewall_type2_rule7 = 37
    host_firewall_type2_rule8 = 135
    host_firewall_type2_rule9 = 137
    host_firewall_type2_rule10 = 138
    host_firewall_type2_rule11 = 161
    host_firewall_type2_rule12 = 162
    host_firewall_type2_rule13 = 514

    # UDP destination ports for type3 firewall 
    host_firewall_type3_rule14 = 69
    host_firewall_type3_rule15 = 2049
    host_firewall_type3_rule16 = 389
    host_firewall_type3_rule17 = 4045

    # this can be either 64, 128, 256, 512, 1024, 1500
    # upon selecting one of these, UPD packets of these sizes will be sent
    pkt_sizes = args.sizes

    # had errors below.. need to add 18 to all
    if (pkt_sizes == 64):
        pkt_len = 4 + 18
    elif (pkt_sizes == 128):
        pkt_len = 68 + 18
    elif (pkt_sizes == 256):
        pkt_len = 196 + 18
    elif (pkt_sizes == 512):
        pkt_len = 452 + 18
    elif (pkt_sizes == 1024):
        pkt_len = 964 + 18
    elif (pkt_sizes == 1500):
        pkt_len = 1440 + 18
    else:
        pkt_len = 4 + 18 # pkt_sizes == 64

    data = b'A'*pkt_len

    # exp_type will have values 1, 2, 3, 4
    # chose pkt_sizes as required per experiment
    # Below details the type of experiments:
        # when exp_type = 1
            # We will send out 2000 of each of TYPE1 rxpkts, so total rxpkts for TYPE1 = 4 x 2000 = 8000 rxpkts with no normal rxpkts mixed in them..
        # when exp_type = 2
            # We will out 2000 of each of TYPE2 rxpkts, so total rxpkts for TYPE2 = 9 x 2000 = 18000 rxpkts with no normal rxpkts mixed in them..
        # when exp_type = 3
            # We will send out 2000 of each of TYPE3 rxpkts, so total rxpkts for TYPE3 = 4 x 2000 = 8000 rxpkts with no normal rxpkts mixed in them..
        # when exp_type = 4
            # We will send out 2000 of each of TYPE4 = TYPE1 + TYPE2 + TYPE3 rxpkts, so total rxpkts for TYPE4 = 8000 + 18000 + 8000  = 34000 rxpkts with no normal rxpkts mixed in them..
    sent = 0

    # VeBPF firewall is being used for filtering
    if (args.riscv_used == 0):

        if (args.sizes == 1024):
            sleep_time = 0.000020  # 20 us
            print(f"\nVeBPF firewall For pkt size = {args.sizes} sleep_time = {sleep_time} = 0.000020  # 20 us \n")
        elif (args.sizes == 1500):
            sleep_time = 0.000055  # 55 us
            print(f"\nVeBPF firewall For pkt size = {args.sizes} sleep_time = {sleep_time} = 0.000055  # 55 us \n")
        else:
            # for args.sizes == 64 or 128 or 512
            sleep_time = 0.0000002  # 0.2 us = 200 ns
            if (experimentation != "VEBPF_PGM_LDR_V2"):
                print(f"\nVeBPF firewall For pkt size = {args.sizes} sleep_time = {sleep_time} = 0.0000002  # 0.2 us = 200 ns \n")
    else:
    # RISCV firewall is being used for filtering

        if (args.sizes == 1024):

            sleep_time = 0.0005900  # 590 us # 
            print(f"\nRISCV firewall For pkt size = {args.sizes} sleep_time = {sleep_time} \n")

        elif (args.sizes == 1500):

            sleep_time = 0.0012000  # 1200 us
            print(f"\nRISCV firewall For pkt size = {args.sizes} sleep_time = {sleep_time} \n")

        elif (args.sizes == 512):
            
            # sleep_time = 0.0002400  # 240 us # not enough time
            sleep_time = 0.0002700  # 270 us # 
            print(f"\nRISCV firewall For pkt size = {args.sizes} sleep_time = {sleep_time} \n")

        elif (args.sizes == 256):
            
            if (args.exp_type == 1):

                # sleep_time = 0.0000900  # 90 us
                sleep_time = 0.0001200  # 120 us
                print(f"\nRISCV firewall For pkt size = {args.sizes} sleep_time = {sleep_time} \n")
            
            elif (args.exp_type == 3 or args.exp_type == 2 or args.exp_type == 4):
                
                sleep_time = 0.0001300  # 130 us
                print(f"\nRISCV firewall For pkt size = {args.sizes} sleep_time = {sleep_time} \n")
            
            else:

                # sleep_time = 0.0000900  # 90 us
                sleep_time = 0.0001200  # 120 us
                print(f"\nRISCV firewall For pkt size = {args.sizes} sleep_time = {sleep_time} \n")


        elif (args.sizes == 128):
            
            if (args.exp_type == 1):

                sleep_time = 0.0000450  # 45 us
                print(f"\nRISCV firewall For pkt size = {args.sizes} sleep_time = {sleep_time} \n")

            elif (args.exp_type == 3 or args.exp_type == 2 or args.exp_type == 4):
                # the above sleep timer value wasnt enough for exp_type3
                    # Since riscv has to process the rxpkt deeper into the UDP hence 
                    # it takes more time to process it and hence we need more delay here

                sleep_time = 0.0000550  # 55 us
                print(f"\nRISCV firewall For pkt size = {args.sizes} sleep_time = {sleep_time} \n")

            else:

                sleep_time = 0.0000450  # 45 us
                print(f"\nRISCV firewall For pkt size = {args.sizes} sleep_time = {sleep_time} \n")

        else:
            # for args.sizes == 64 or 128 or 512
            # sleep_time = 0.0000002  # 0.2 us = 200 ns
                # 7500 rxpkts being counted.. increasing the sleep_time
            sleep_time = 0.0000250  # 25 us
            print(f"\nRISCV firewall For pkt size = {args.sizes} sleep_time = {sleep_time} \n")

    # sleep_time = 0.000090  # 90 us
        # Works for 1500 type1 config4

    # sleep_time = 0.000070  # 70 us
        # Works for 1500 type1 config4

    # sleep_time = 0.000060  # 60 us
        # Works for 1500 type1 config4

    # sleep_time = 0.000055  # 55 us
        # Works for 1500 type1 config4 and is FINAL .. but not consistent so just resend and reset the counter

    # sleep_time = 0.000052  # 52 us
        # Does not Works for 1500 type1 config4 .. not consistent

    # sleep_time = 0.000051  # 51 us
        # DOES NOT work for 1500 type1 config4
    # sleep_time = 0.000050  # 50 us
        # DOES NOT work for 1500 type1 config4

    # sleep_time = 0.000020  # 20 us
        # works for 1024 type1 config4 and chosen as FINAL for 1024 byte rxpkt

    # sleep_time = 0.000015  # 15 us
        # still doesnt work for 1024 type1 config4

    # sleep_time = 0.000010  # 10 us
        # still doesnt work for 1024 type1 config4
    
    # sleep_time = 0.000001  # 1 us
        # still doesnt work for 1024 type1 config4

    # sleep_time = 0.000000001  # 0.001 us = 1 ns
        # When I made sleep timer = sleep_time = 0.000000001  # 0.001 us = 1 ns,, and did the 64 byte 8k rxpkt experiment, 
        # the filtering time per rxpkt was more than when sleep timer was = 0.2 us, since the PHY is sending out rxpkts at 100Mbps, 
        # so as long as sleep timer isn't close to that (120 us for 1500 byte rxpkt and lower for smaller ones), then it shouldn't matter.

    # sleep_time = 0.0000002  # 0.2 us = 200 ns and works
        # used for Config4 TYPE1 uptill size 512
    # BUG here: When I am sending these with default sleep time of 200 ns, only 6800 rxpkts are being SENT out of the laptop as shown in wireshark, that all 8k rxpkts are not being sent out of the laptop and the VeBPF firewall on arty100T board is able to filter all rxpkts at line rate cx none is dropped and however many were sent out of this laptop were shown in wireshark, that many were shown in malicious rxpkts counter in the arty100T UART output.
    #     So for 1024 byte 8k rxpkts, I am slowly going to increase the sleep time.. lets see where it stops..

    if (experimentation == "VEBPF_PGM_LDR_V2"):

        print(f'experimentation = {experimentation} \n')

        firewall_type1_total_rules = 4

        # sending out rxpkts
        for rule in range(firewall_type1_total_rules):

            if (rule == 0):
                # sending firewall rule1 rxpkt
                
                # dest ip
                host = host_firewall_type1_rule1
                
                # dest DEFAULT udp port
                port = DEFAULT_UDP_DEST_PORT

                try:
                    sock.sendto(data, (host, port))
                    sent += 1
                    print(f"Firewall type-{rule+1} packet sent")
                except BlockingIOError:
                    print(f"Firewall type-{rule+1} packet BlockingIOError")
                    pass

                time.sleep(sleep_time)  # 0.2 us = 200 ns and works

            elif (rule == 1):
                # sending firewall rule2 rxpkt
                
                # dest ip
                host = host_firewall_type1_rule2
                
                # dest DEFAULT udp port
                port = DEFAULT_UDP_DEST_PORT

                try:
                    sock.sendto(data, (host, port))
                    sent += 1
                    print(f"Firewall type-{rule+1} packet sent")
                except BlockingIOError:
                    print(f"Firewall type-{rule+1} packet BlockingIOError")
                    pass

                time.sleep(sleep_time)  # 0.2 us = 200 ns and works

            elif (rule == 2):
                # sending firewall rule3 rxpkt
                
                # dest ip
                host = host_firewall_type1_rule3
                
                # dest DEFAULT udp port
                port = DEFAULT_UDP_DEST_PORT

                try:
                    sock.sendto(data, (host, port))
                    sent += 1
                    print(f"Firewall type-{rule+1} packet sent")
                except BlockingIOError:
                    print(f"Firewall type-{rule+1} packet BlockingIOError")
                    pass

                time.sleep(sleep_time)  # 0.2 us = 200 ns and works

            elif (rule == 3):
                # sending firewall rule4 rxpkt
                
                # dest ip
                host = host_firewall_type1_rule4
                
                # dest DEFAULT udp port
                port = DEFAULT_UDP_DEST_PORT

                try:
                    sock.sendto(data, (host, port))
                    sent += 1
                    print(f"Firewall type-{rule+1} packet sent")
                except BlockingIOError:
                    print(f"Firewall type-{rule+1} packet BlockingIOError")
                    pass

                time.sleep(sleep_time)  # 0.2 us = 200 ns and works

            print(f"Sent {sent} firewall TYPE1  UDP packets to {host} on DEFAULT {port}...")
            sent = 0

    elif (experimentation == "HPEC2024"):

        print(f'experimentation = {experimentation} \n')

        for exp_iteration in range(exp_iterations):

            print(f"Starting experiment iteration {exp_iteration} out of total {exp_iterations} for experiment firewall rule type {exp_type}")

            # firewall rule-type1 rxpkts 
            if (exp_type == 1): 
                firewall_type1_total_rules = 4
                total_iterations_per_rule = 2000 + 6

                # sending out rxpkts
                for rule in range(firewall_type1_total_rules):
                    
                    for iteration in range(total_iterations_per_rule):
                        if (rule == 0):
                            # sending firewall rule1 rxpkt
                            
                            # dest ip
                            host = host_firewall_type1_rule1
                            
                            # dest DEFAULT udp port
                            port = DEFAULT_UDP_DEST_PORT

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 1):
                            # sending firewall rule2 rxpkt
                            
                            # dest ip
                            host = host_firewall_type1_rule2
                            
                            # dest DEFAULT udp port
                            port = DEFAULT_UDP_DEST_PORT

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 2):
                            # sending firewall rule3 rxpkt
                            
                            # dest ip
                            host = host_firewall_type1_rule3
                            
                            # dest DEFAULT udp port
                            port = DEFAULT_UDP_DEST_PORT

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 3):
                            # sending firewall rule4 rxpkt
                            
                            # dest ip
                            host = host_firewall_type1_rule4
                            
                            # dest DEFAULT udp port
                            port = DEFAULT_UDP_DEST_PORT

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                    print(f"Sent {sent} firewall TYPE1 rule-{rule+1} UDP packets to {host} on DEFAULT {port}...")
                    sent = 0

            # firewall rule-type1 rxpkts 
            elif (exp_type == 2):
                firewall_type2_total_rules = 9
                total_iterations_per_rule = 2000 + 6

                # sending out rxpkts
                for rule in range(firewall_type2_total_rules):
                    
                    for iteration in range(total_iterations_per_rule):
                        if (rule == 0):
                            # sending firewall rule5 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule5

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 1):
                            # sending firewall rule6 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule6

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 2):
                            # sending firewall rule7 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule7

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 3):
                            # sending firewall rule8 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule8

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 4):
                            # sending firewall rule9 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule9

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 5):
                            # sending firewall rule10 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule10

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 6):
                            # sending firewall rule11 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule11

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 7):
                            # sending firewall rule12 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule12

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 8):
                            # sending firewall rule13 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule13

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                    print(f"Sent {sent} firewall TYPE2 rule-{rule+5} UDP packets to DEFAULT {host} on {port}...")
                    sent = 0
            
            elif (exp_type == 3):
                firewall_type3_total_rules = 4
                total_iterations_per_rule = 2000 + 6

                # sending out rxpkts
                for rule in range(firewall_type3_total_rules):
                    
                    for iteration in range(total_iterations_per_rule):
                        if (rule == 0):
                            # sending firewall rule14 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type3_rule14

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 1):
                            # sending firewall rule15 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type3_rule15

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 2):
                            # sending firewall rule16 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type3_rule16

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 3):
                            # sending firewall rule17 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type3_rule17

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                    print(f"Sent {sent} firewall TYPE3 rule-{rule+5} UDP packets to DEFAULT {host} on {port}...")
                    sent = 0

            elif (exp_type == 4):
                # firewall_type3_total_rules = 17
                # sending all firewall types (1, 2, 3) rxpkts

                # type1 firewall rules rxpkts
                firewall_type1_total_rules = 4
                total_iterations_per_rule = 2000 + 6

                # sending out rxpkts
                for rule in range(firewall_type1_total_rules):
                    
                    for iteration in range(total_iterations_per_rule):
                        if (rule == 0):
                            # sending firewall rule1 rxpkt
                            
                            # dest ip
                            host = host_firewall_type1_rule1
                            
                            # dest DEFAULT udp port
                            port = DEFAULT_UDP_DEST_PORT

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 1):
                            # sending firewall rule2 rxpkt
                            
                            # dest ip
                            host = host_firewall_type1_rule2
                            
                            # dest DEFAULT udp port
                            port = DEFAULT_UDP_DEST_PORT

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 2):
                            # sending firewall rule3 rxpkt
                            
                            # dest ip
                            host = host_firewall_type1_rule3
                            
                            # dest DEFAULT udp port
                            port = DEFAULT_UDP_DEST_PORT

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 3):
                            # sending firewall rule4 rxpkt
                            
                            # dest ip
                            host = host_firewall_type1_rule4
                            
                            # dest DEFAULT udp port
                            port = DEFAULT_UDP_DEST_PORT

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                    print(f"Sent {sent} firewall TYPE1 rule-{rule+1} UDP packets to {host} on DEFAULT {port}...")
                    sent = 0

                # type2 firewall rules rxpkts
                firewall_type2_total_rules = 9
                total_iterations_per_rule = 2000 + 6

                # sending out rxpkts
                for rule in range(firewall_type2_total_rules):
                    
                    for iteration in range(total_iterations_per_rule):
                        if (rule == 0):
                            # sending firewall rule5 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule5

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 1):
                            # sending firewall rule6 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule6

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 2):
                            # sending firewall rule7 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule7

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 3):
                            # sending firewall rule8 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule8

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 4):
                            # sending firewall rule9 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule9

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 5):
                            # sending firewall rule10 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule10

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 6):
                            # sending firewall rule11 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule11

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 7):
                            # sending firewall rule12 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule12

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 8):
                            # sending firewall rule13 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type2_rule13

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                    print(f"Sent {sent} firewall TYPE2 rule-{rule+5} UDP packets to DEFAULT {host} on {port}...")
                    sent = 0

                # type 3 firewall rules rxpkts
                firewall_type3_total_rules = 4
                total_iterations_per_rule = 2000 + 6

                # sending out rxpkts
                for rule in range(firewall_type3_total_rules):
                    
                    for iteration in range(total_iterations_per_rule):
                        if (rule == 0):
                            # sending firewall rule14 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type3_rule14

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 1):
                            # sending firewall rule15 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type3_rule15

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 2):
                            # sending firewall rule16 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type3_rule16

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                        elif (rule == 3):
                            # sending firewall rule17 rxpkt
                            
                            # dest DEFAULT ip
                            host = DEFAULT_HOST_DEST_IP
                            
                            # dest udp port
                            port = host_firewall_type3_rule17

                            try:
                                sock.sendto(data, (host, port))
                                sent += 1
                                # print(f"Total rxpkts sent = {sent}")
                            except BlockingIOError:
                                pass

                            time.sleep(sleep_time)  # 0.2 us = 200 ns and works

                    print(f"Sent {sent} firewall TYPE3 rule-{rule+5} UDP packets to DEFAULT {host} on {port}...")
                    sent = 0

        sock.settimeout(1)

        print(f"All Packets Sent!")

    
    else:

        print(f'Please select correct experimentation type \n')
        sys.exit("ERROR")

    '''
    print(f"Sending {n} UDP packets to {host} on {port}...")
    
    while sent < n:
        try:
            sock.sendto(data, (host, port))
            sent += 1
            print(f"Total rxpkts sent = {sent}")
        except BlockingIOError:
            pass


        time.sleep(0.0000002)  # 0.2 us = 200 ns and works
        # time.sleep(0.2)
            # https://docs.python.org/3/library/time.html 
            # Suspend execution of the calling thread for the given number of seconds. 
            # The argument may be a floating point number to indicate a more precise sleep time.
                    
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
    '''

if __name__ == "__main__":
    main()
