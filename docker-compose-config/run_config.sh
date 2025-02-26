#!/bin/bash

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo -e "$tmp_root")
ROOT_DIRECTORY="$ROOT_DIR"
DCCFG_DIRECTORY="$ROOT_DIR/docker-compose-config/config" 

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
get_ipv4_address() {
    local ip
    ip=$(ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1 | head -n 1)

    if [[ -n "$ip" ]]; then
        echo "$ip"
    else
        echo "No IPv4 address found."
        return 1
    fi
}

make_new_path() {
    NEW_PATH="$1"
    sudo mkdir -p "$NEW_PATH/bufferzone"
    sudo mkdir -p "$NEW_PATH/logs"
    sudo mkdir -p "$NEW_PATH/secrets"
    sudo mkdir -p "$NEW_PATH/downloads"
    sudo mkdir -p "$NEW_PATH/incomplete"
    sudo mkdir -p "$NEW_PATH/torrentfiles"

    sudo chown $ME:$ME -R $NEW_PATH
    sudo chmod 777 -R $NEW_PATH

}

QBROOT="/home/qbittorrent_test3"
make_new_path="$QBROOT"
ME=$(whoami)


cp -R "$DCCFG_DIRECTORY" "$QBROOT"
cp -R "$ROOT_DIR/docker-compose-config/scripts" "$QBROOT"

MY_UID=(uname -u)
MY_GID=(uname -g)

NETWORK="10.0.0.0"
MY_IP=$(get_ipv4_address)


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
      - OPENVPN_CONFIG=$OVPN_FILE
      - VPN_ENABLED=yes
      - LAN_NETWORK=$NETWORK/24
      - NAME_SERVERS=1.1.1.1,1.0.0.1
      - VPN_EXPECTED_COUNTRY="Canada"
      - VPN_EXPECTED_CITY="Montreal"
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

echo "File '$CFG_FILE' created successfully."

docker-compose -f "$CFG_FILE" up 
