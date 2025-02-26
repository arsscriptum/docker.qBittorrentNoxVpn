#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   create-compose-config.sh                                                     |
#|                                                                                |
#+--------------------------------------------------------------------------------+
#|   Guillaume Plante <codegp@icloud.com>                                         |
#|   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      |
#+--------------------------------------------------------------------------------+


SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo -e "$tmp_root")
ROOT_DIRECTORY="$ROOT_DIR"
NETFUNCTS="$ROOT_DIR/scripts/netfuncts.sh"
DCCFG_DIRECTORY="$ROOT_DIR/docker-compose-config" 

COMPOSE_CONFIG_DIR="$DCCFG_DIRECTORY/config"
COMPOSE_SCRIPTS_DIR="$DCCFG_DIRECTORY/scripts"
OVPN_DIRECTORIES_PATH="$COMPOSE_CONFIG_DIR/openvpn"

source "$NETFUNCTS"

# Ensure exactly one argument is provided
if [[ $# -ne 1 ]]; then
    echo "Usage: create-compose-config <path>"
    exit  1
fi

QBROOT="$1"


    # Check if the path exists
if [[ -e "$QBROOT" ]]; then
    echo "Error: Path '$QBROOT' already exists."
    exit 1
fi

mkdir -p "$QBROOT" 2>/dev/null

# Check if the directory was created successfully
if [[ ! -d "$QBROOT" ]]; then
    echo "Error: Access denied or unable to create '$QBROOT'. Use SUDO"
    exit 1
fi

QBROOT_BTR_PATH="$QBROOT/qBittorrent"
QBROOT_VPN_PATH="$QBROOT/openvpn"

print_providers() {
    # Ensure OVPN_DIRECTORIES_PATH is set
    if [[ -z "$OVPN_DIRECTORIES_PATH" ]]; then
        echo "Error: OVPN_DIRECTORIES_PATH is not set."
        return 1
    fi

    # Get the list of providers (excluding .sh files)
    PROVIDERS=$(ls "$OVPN_DIRECTORIES_PATH" -w 1 | grep -v "\.sh")

    # Convert to an array
    IFS=$'\n' read -r -d '' -a providers_array <<<"$PROVIDERS"

    # Get the total count
    total=${#providers_array[@]}

    # Define number of columns
    cols=4

    # Print the providers in 4 columns with numbers
    for ((i=0; i<total; i++)); do
        printf "%-20s" "$((i+1)). ${providers_array[i]}"
        if (( (i+1) % cols == 0 )); then
            echo  # New line after every 4 entries
        fi
    done

    # Final newline if not evenly divisible by 4
    if (( total % cols != 0 )); then
        echo
    fi
}



select_vpn_provider() {
    # Ensure OVPN_DIRECTORIES_PATH is set
    if [[ -z "$OVPN_DIRECTORIES_PATH" ]]; then
        echo "Error: OVPN_DIRECTORIES_PATH is not set."
        exit 1
    fi

    # Get the list of providers (excluding .sh files)
    PROVIDERS=$(ls "$OVPN_DIRECTORIES_PATH" -w 1 | grep -v "\.sh")

    # Convert to an array
    IFS=$'\n' read -r -d '' -a providers_array <<<"$PROVIDERS"

    # Get the total count
    total=${#providers_array[@]}
    if [[ "$total" -eq 0 ]]; then
        echo "No VPN providers found."
        exit 1
    fi

    # Define number of columns
    cols=4

    # Print the providers in 4 columns with numbers
    echo "Available VPN Providers:"
    for ((i=0; i<total; i++)); do
        printf "%-20s" "$((i+1)). ${providers_array[i]}"
        if (( (i+1) % cols == 0 )); then
            echo  # New line after every 4 entries
        fi
    done
    echo  # Final newline

    # Ask the user to select a provider
    while true; do
        read -rp "Select a provider (1-$total): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= total )); then
            break
        fi
        echo "Invalid selection. Please enter a number between 1 and $total."
    done

    # Get the selected provider
    provider="${providers_array[choice-1]}"
    provider_path="$OVPN_DIRECTORIES_PATH/$provider"

    # Ensure the provider directory exists
    if [[ ! -d "$provider_path" ]]; then
        echo "Error: Provider directory '$provider_path' not found."
        exit 1
    fi

    # Get a random file from the provider directory
    random_file=$(find "$provider_path" -type f | shuf -n 1)

    if [[ -z "$random_file" ]]; then
        echo "No files found in '$provider_path'."
        exit 1
    fi

    echo "$random_file" > /tmp/vpn_filename
}

select_vpn_provider
OVPN_FILE_PATH=$(cat /tmp/vpn_filename)
OVPN_FILE_NAME=$(basename $OVPN_FILE_PATH)
OVPN_BASENAME="${OVPN_FILE_NAME%.*}"

echo "cp \"$OVPN_FILE_PATH\" \"$QBROOT_VPN_PATH\""


OWNER="arsscriptum"
IMAGE_NAME="qbittorrentvpn"

# Stop the container if it's running
if docker ps | grep -q "qbittorrent"; then
    log_warn "Stopping qbittorrent container..."
    docker stop "$IMAGE_NAME" > /dev/null 2>&1
fi

# Remove the container if it exists
if docker ps -a | grep -q "qbittorrent"; then
    log_warn "Removing qbittorrent container..."
    docker rm "$IMAGE_NAME" > /dev/null 2>&1
fi


make_new_path() {
    NEW_PATH="$1"
    mkdir -p "$NEW_PATH/bufferzone"
    mkdir -p "$NEW_PATH/logs"
    mkdir -p "$NEW_PATH/secrets"
    mkdir -p "$NEW_PATH/downloads"
    mkdir -p "$NEW_PATH/incomplete"
    mkdir -p "$NEW_PATH/torrentfiles"

    chown $ME:$ME -R $NEW_PATH
    chmod 777 -R $NEW_PATH

}


make_new_path "$QBROOT"
ME=$(whoami)


cp -R "$COMPOSE_CONFIG_DIR" "$QBROOT"
cp -R "$COMPOSE_SCRIPTS_DIR" "$QBROOT"



MY_UID=$(id -u)
MY_GID=$(id -g)

NETWORK=$(get_lan_network)
MY_IP=$(get_ipv4_address | head -n 1)


CFG_FILE="$QBROOT/docker-compose.yml"

cat <<EOF > "$CFG_FILE"
services:
  qbittorrentvpn:
    image: arsscriptum/qbittorrentvpn:latest
    container_name: qbittorrentvpn
    privileged: true
    cap_add:
      - NET_RAW
      - NET_ADMIN
    environment:
      - PUID=$MY_UID
      - PGID=$MY_GID
      - WEBUI_PORT_ENV=8080
      - INCOMING_PORT_ENV=8999
      - OPENVPN_CONFIG=$OVPN_BASENAME
      - VPN_ENABLED=yes
      - LAN_NETWORK=$NETWORK/24
      - NAME_SERVERS=1.1.1.1,1.0.0.1
    logging:
      driver: journald
      options:
        tag: "qbittorrentvpn"
    ports:
      - $MY_IP:8080:8080
      - $MY_IP:8999:8999
      - $MY_IP:8999:8999/udp
    volumes:
      - $QBROOT/bufferzone:/bufferzone:rw
      - $QBROOT/logs:/logs:rw
      - $QBROOT/secrets:/secrets
      - $QBROOT/scripts:/scripts
      - $QBROOT/config:/config
      - $QBROOT/downloads:/downloads
      - $QBROOT/incomplete:/Incomplete
      - $QBROOT/torrentfiles:/TorrentFiles
      - /etc/timezone:/etc/timezone:ro
    restart: unless-stopped
EOF

chown -R $MY_UID:$MY_GID $QBROOT
chmod -R 777 $QBROOT

echo "File '$CFG_FILE' created successfully."

docker-compose -f "$CFG_FILE" up 
