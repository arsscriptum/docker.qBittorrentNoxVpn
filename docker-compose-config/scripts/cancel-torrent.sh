#!/bin/bash

# Log function to log both to system journal and a log file
log() {
    local message="$1"
    logger -t qbittorrentvpn "$message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> /logs/cancel-torrent.log
}

# Check if all arguments are provided
if [[ $# -ne 1 ]]; then
    log "Error: Missing arguments. Usage: $0 <Info hash>"
    exit 1
fi

# qBittorrent Web UI endpoint
QBIT_HOST="http://127.0.0.1:8080"
CURRENT_TIME=`date`
INFO_HASH="$1"

log "[cancel-torrent] Server: $QBIT_HOST . $CURRENT_TIME Cancelling torrent with hash $INFO_HASH"

# /api/v2/torrents/delete?hashes=8c212779b4abde7c6bc608063a0d008b7e40ce32&deleteFiles=false

curl -X POST "${QBIT_HOST}/api/v2/torrents/delete" -d "hashes=$INFO_HASH&deleteFiles=true" 


log "[cancel-torrent] Script completed."

