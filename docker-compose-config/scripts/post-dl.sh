#!/bin/bash

# ###############################################
# Set this in qbittorrentvpn
# /scripts/post-dl.sh "%N" "%R" %I %C %Z
# $1: Torrent name
# $2: Root path (first torrent subdirectory path)
# $3: Info hash
# $4: Number of files
# $5: Torrent size (bytes)

# Log function to log both to system journal and a log file
log() {
    local message="$1"
    logger -t qbittorrentvpn "$message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> /logs/post-dl.log
}

log_error() {
    local message="$1"
    echo -e " ❌ $message"
    logger --tag qbittorrentvpn -p user.error "[error] $message"
    echo -e " ❌ $message" >> /logs/post-dl.log
}

log_disk_space() {
    label="$1"
    disk_info=$(df -h /home | awk 'NR==2 {print "Used: "$3", Available: "$4}')
    log "$label - Disk space on /home: $disk_info"
}

# Check if all arguments are provided
if [[ $# -ne 5 ]]; then
    log "Error: Missing arguments. Usage: $0 <Torrent Name> <Root Path> <Info hash> <Number of files> <Torrent size>"
    exit 1
fi

# Assign arguments to variables
TORRENT_NAME="$1"
ROOT_PATH="$2"
INFO_HASH="$3"
FILE_COUNT="$4"
TORRENT_SIZE="$5"
CURRENT_TIME=`date`

log "Download Completed for \"$TORRENT_NAME\" . At $CURRENT_TIME. FILE_COUNT $FILE_COUNT TORRENT_SIZE $TORRENT_SIZE bytes INFO_HASH $INFO_HASH ROOT_PATH \"$ROOT_PATH\""

# Log disk space before the script starts
log_disk_space "Before processing"



# Create a directory in /bufferzone for the torrent
DEST_DIR="/bufferzone/${TORRENT_NAME}"
mkdir -p "$DEST_DIR"
if [[ $? -ne 0 ]]; then
    log_error "cannot create directory \"$DEST_DIR\""
    exit 1
fi

log "Created directory $DEST_DIR for torrent $TORRENT_NAME"

# Copy files from root path to the newly created directory
cp -R "$ROOT_PATH" "$DEST_DIR"

if [[ $? -ne 0 ]]; then
    log_error "failed to copy files to \"$DEST_DIR\""
    exit 1
fi

COPIED_FILE_COUNT=$(find "$DEST_DIR" -type f | wc -l)

# Validate file count
#if [[ $COPIED_FILE_COUNT -ne $FILE_COUNT ]]; then
#    log "Error: File count mismatch. Expected $FILE_COUNT, but copied $COPIED_FILE_COUNT."
#    exit 1
#fi
#log "File count validated successfully: $COPIED_FILE_COUNT files copied."

# Validate total size of copied files
#COPIED_SIZE=$(du -sb "$DEST_DIR" | cut -f1)
#if [[ $COPIED_SIZE -ne $TORRENT_SIZE ]]; then
#    log "Error: File size mismatch. Expected $TORRENT_SIZE bytes, but copied $COPIED_SIZE bytes."
#    exit 1
#fi
#log "File size validated successfully: $COPIED_SIZE bytes copied."
log "File size: $COPIED_SIZE bytes copied."

sleep 3

# Execute the cancel-torrent script with the info hash
/scripts/cancel-torrent.sh "$INFO_HASH"

if [[ $? -eq 0 ]]; then
    log "Successfully canceled torrent with info hash $INFO_HASH"
else
    log "Error: Failed to cancel torrent with info hash $INFO_HASH"
    exit 1
fi

# Log disk space before the script starts
log_disk_space "Before processing"

log "Script Completed"
