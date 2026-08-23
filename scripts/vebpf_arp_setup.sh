#!/bin/bash

echo "executing script to add arp entries for VeBPF tests"


sudo arp -s 245.255.255.1 02:00:00:00:00:01
sudo arp -s 128.0.0.1 02:00:00:00:00:02
sudo arp -s 240.0.0.1 02:00:00:00:00:03
sudo arp -s 1.0.0.1 02:00:00:00:00:04
