#!/bin/bash

echo "Setting up ip table rules for vebpf exp"

echo "sudo iptables -I OUTPUT -p udp --dport 1534 -j DROP"
echo "sudo iptables -I OUTPUT -p udp --dport 5353 -j DROP"

sudo iptables -I OUTPUT -p udp --dport 1534 -j DROP
sudo iptables -I OUTPUT -p udp --dport 5353 -j DROP

echo "Use this command for sudo iptables -L -v -n --line-numbers => iptables rules have been setup with following line numbers: "

sudo iptables -L -v -n --line-numbers

echo "To delete iptables rules use the following commands:"

echo "(for in going packets) sudo iptables -D INPUT line_number"

echo "(for out going packets) sudo iptables -D OUTPUT line_number (I HAVE TO USE THIS RULE)"


