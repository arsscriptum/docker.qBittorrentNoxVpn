#!/bin/bash

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR" | awk '{print $1}')
ROOT_DIR=$(eval echo -e "$tmp_root")
ROOT_DIRECTORY="$ROOT_DIR"
SCRIPTS_DIRECTORY="$ROOT_DIR/scripts"
TMPLIBS_DIRECTORY="$ROOT_DIR/tmp/libs"
DEPLOY_DIRECTORY="$ROOT_DIR/deploy"
EXTERNALS_DIRECTORY="$ROOT_DIR/externals"
QBITTORRENT_DIRECTORY="$EXTERNALS_DIRECTORY/qBittorrent"
QBITTORRENT_BUILD_DIRECTORY="$QBITTORRENT_DIRECTORY/build"
QBITTORRENT_EXE_PATH="$QBITTORRENT_BUILD_DIRECTORY/qbittorrent-nox"
DEPLOY_BIN="/usr/bin/cqtdeployer"
QT_PATH="/home/gp/Qt/6.8.2"
QT_PLUGINS_PATH="$QT_PATH/gcc_64/plugins/tls"

rm -rf "$DEPLOY_DIRECTORY"
rm -rf "$TMPLIBS_DIRECTORY"
mkdir -p "$TMPLIBS_DIRECTORY"

if [[ ! -f "$QBITTORRENT_EXE_PATH" ]]; then 
    echo "missing $QBITTORRENT_EXE_PATH"
    exit 1 
fi 

OWNER="arsscriptum"
IMAGE_NAME="qbittorrentvpn"

# Stop the container if it's running
if docker ps | grep -q "qbittorrent"; then
    echo "Stopping qbittorrent container..."
    docker stop "$IMAGE_NAME"
fi

# Remove the container if it exists
if docker ps -a | grep -q "qbittorrent"; then
    echo "Removing qbittorrent container..."
    docker rm "$IMAGE_NAME"
fi


$SCRIPTS_DIRECTORY/export-libs.sh "$QBITTORRENT_EXE_PATH" -p "$TMPLIBS_DIRECTORY"

$DEPLOY_BIN -bin "$QBITTORRENT_EXE_PATH" -libDir "$TMPLIBS_DIRECTORY" -extraPlugin $QT_PLUGINS_PATH -targetDir $DEPLOY_DIRECTORY

# Start the new container
echo "Starting qbittorrent container..."

docker build -t "$OWNER/$IMAGE_NAME:$1" .

docker push "$OWNER/$IMAGE_NAME:$1" 

docker build -t "$OWNER/$IMAGE_NAME:latest" .

docker push "$OWNER/$IMAGE_NAME:latest" 