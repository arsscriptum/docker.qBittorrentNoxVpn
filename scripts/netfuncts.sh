#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   netfuncts.sh                                                                 |
#|                                                                                |
#+--------------------------------------------------------------------------------+
#|   Guillaume Plante <codegp@icloud.com>                                         |
#|   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      |
#+--------------------------------------------------------------------------------+



get_ipv4_address() {
    local iface ip netmask

    # Check if ipcalc is installed
    if ! command -v ipcalc &>/dev/null; then
        echo "Error: 'ipcalc' is not installed. Please install it using:"
        echo "    sudo apt install ipcalc  # Debian/Ubuntu"
        return 1
    fi

    # Get the active network interface
    iface=$(ip -4 route show default | awk '{print $5}' | head -n 1)
    if [[ -z "$iface" ]]; then
        echo "No active network interface found."
        return 1
    fi

    # Check if ifconfig is installed 
    if ! command -v ifconfig &>/dev/null; then
        echo "Error: 'ifconfig' is not installed. Install net-tools:"
        echo "    sudo apt install net-tools  # Debian/Ubuntu"
        echo "    sudo yum install net-tools  # CentOS/RHEL"
        return 1
    fi

    # Extract IP address and netmask from ifconfig output
    ip=$(ifconfig "$iface" 2>/dev/null | awk '/inet / {print $2}')
    netmask=$(ifconfig "$iface" 2>/dev/null | awk '/inet / {print $4}')
    echo "$ip"
    # pritn both since I need both later
    echo "$netmask"
}

get_lan_network() {
    local iface ip network netmask cidr

    # Check if ipcalc is installed
    if ! command -v ipcalc &>/dev/null; then
        echo "Error: 'ipcalc' is not installed. Please install it using:"
        echo "    sudo apt install ipcalc  # Debian/Ubuntu"
        return 1
    fi

    # Get the active network interface (ignores loopback)
    iface=$(ip -4 route show default | awk '{print $5}' | head -n 1)
    if [[ -z "$iface" ]]; then
        echo "No active network interface found."
        return 1
    fi

    # Check if ifconfig is installed
    if ! command -v ifconfig &>/dev/null; then
        echo "Error: 'ifconfig' is not installed. Install net-tools:"
        echo "    sudo apt install net-tools  # Debian/Ubuntu"
        echo "    sudo yum install net-tools  # CentOS/RHEL"
        return 1
    fi

    # Extract IP address and netmask from ifconfig output
    ip=$(get_ipv4_address | head -n 1)
    netmask=$(get_ipv4_address | tail -n 1)

    if [[ -z "$ip" || -z "$netmask" ]]; then
        echo "Error: Could not retrieve IP address or netmask for $iface."
        return 1
    fi
    # Extract network address and CIDR
    nn_and_cidr=$(ipcalc -b -n "$ip" | grep Network | awk '{ print $2 }')
    network="${nn_and_cidr%/*}"
  
    echo "$network"
}

