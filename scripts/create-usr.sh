#!/bin/bash

# Create group 'qbittorrentvpn' if it doesn't already exist
if ! getent group qbittorrentvpn >/dev/null; then
    sudo groupadd qbittorrentvpn
fi

# Create user 'qbittorrentvpn' with group 'qbittorrentvpn' and no password
sudo useradd -g qbittorrentvpn -m -s /bin/bash qbittorrentvpn

# Lock the password to prevent prompts for password setting
sudo passwd -d qbittorrentvpn
sudo usermod -L qbittorrentvpn

echo "User 'qbittorrentvpn' with group 'qbittorrentvpn' created without a password and no prompts."
