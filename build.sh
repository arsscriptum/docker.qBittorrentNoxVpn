#!/bin/bash

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

# Start the new container
echo "Starting qbittorrent container..."

docker build -t "$OWNER/$IMAGE_NAME:$1" .

docker push "$OWNER/$IMAGE_NAME:$1" 

docker build -t "$OWNER/$IMAGE_NAME:latest" .

docker push "$OWNER/$IMAGE_NAME:latest" 