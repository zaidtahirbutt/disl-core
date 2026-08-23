#!/bin/bash

echo "executing script to add scr ips and arp entries for VeBPF tests"

# Get the first Ethernet adapter name (not loopback, not wireless)
ETH_DEV=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^en' | head -n1)

# Check if detection worked
if [ -z "$ETH_DEV" ]; then
    echo "No Ethernet adapter detected. Please enter the adapter name manually and try again."
    return 1 2>/dev/null || exit 1
else
    echo -e "\nEthernet adapter detected: $ETH_DEV\n"
fi

# --- Reset Mode ---
if [ "$1" == "--reset" ]; then
    echo "Resetting $ETH_DEV to automatic (DHCP)..."

    # Delete any custom connection with same name
    sudo nmcli connection delete "$ETH_DEV" 2>/dev/null || true

    # Recreate with DHCP
    sudo nmcli connection add type ethernet ifname "$ETH_DEV" con-name "$ETH_DEV" || true
    sudo nmcli connection modify "$ETH_DEV" ipv4.method auto
    sudo nmcli --wait 0 connection up "$ETH_DEV"

    echo -e "\n$ETH_DEV reset complete. Now managed automatically (DHCP).\n"
    return 0 2>/dev/null || exit 0
fi

# --- Setup Mode ---
echo "Configuring $ETH_DEV with static IP and custom routes..."

# Ensure a connection profile exists
sudo nmcli connection add type ethernet ifname "$ETH_DEV" con-name "$ETH_DEV" 2>/dev/null || true

# Clear old addresses first
sudo nmcli connection modify "$ETH_DEV" ipv4.addresses ""

# Add multiple static IP addresses (each with +)
sudo nmcli connection modify "$ETH_DEV" +ipv4.addresses "245.255.255.255/24"
sudo nmcli connection modify "$ETH_DEV" +ipv4.addresses "128.0.0.0/24"
sudo nmcli connection modify "$ETH_DEV" +ipv4.addresses "240.0.0.0/24"
sudo nmcli connection modify "$ETH_DEV" +ipv4.addresses "1.0.0.0/24"

# Switch to manual mode
sudo nmcli connection modify "$ETH_DEV" ipv4.method manual

# Apply changes
sudo nmcli --wait 0 connection up "$ETH_DEV"

sleep 0.5  # wait for kernel to fully activate IPs

# Add FPGA static ARP entries (NetworkManager does not persist ARP, so still need ip/arp)
sudo arp -s 128.0.0.1 02:00:00:00:00:02
sudo arp -s 240.0.0.1 02:00:00:00:03
sudo arp -s 1.0.0.1 02:00:00:00:04
sudo arp -s 245.255.255.1 02:00:00:00:00:01

echo -e "\nShowing active connection config:"
nmcli -f NAME,DEVICE,STATE connection show "$ETH_DEV"

echo -e "\nShowing arp table entries:"
ip neigh show
arp -a

echo -e "\ndone"

return 0 2>/dev/null || exit 0
