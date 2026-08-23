#!/usr/bin/env python
"""
UDP test
"""

import argparse
import socket
import time

def main():
    parser = argparse.ArgumentParser(description=__doc__.strip())
    parser.add_argument('host', help="Host", nargs='?', type=str, default='245.255.255.1') # corresponds to src addr of '245.255.255.255'
    # use any for these host ips for the default vebpf firewall experiment
    # host_firewall_type1_rule1 = '245.255.255.1'  # corresponds to src addr of '245.255.255.255'
    # host_firewall_type1_rule2 = '128.0.0.1'  # corresponds to src addr of '128.0.0.0'
    # host_firewall_type1_rule3 = '240.0.0.1'  # corresponds to src addr of '240.0.0.0'
    # host_firewall_type1_rule4 = '1.0.0.1'  # corresponds to src addr of '1.0.0.0'
    parser.add_argument('port', help="UDP port", nargs='?', type=int, default=1234)
    parser.add_argument('-n', help="Number of packets", type=int, default=1000)

    args = parser.parse_args()
    
    host = args.host
    
    port = args.port
    n = args.n
    
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(0)
    
    sent = 0
    recv = 0
    
    data = b'testing'*100
    
    print(f"Sending {n} UDP packets to {host} on {port}...")
    
    while sent < n:
        try:
            sock.sendto(data, (host, port))
            sent += 1
            print(f"Total rxpkts sent = {sent}")
        except BlockingIOError:
            pass


        time.sleep(0.002)

    sock.settimeout(1)

    print(f"Sent {sent} packets")

if __name__ == "__main__":
    main()
