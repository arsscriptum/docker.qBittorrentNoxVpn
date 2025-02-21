#!/bin/bash

# Stop the container if it's running
if docker ps | grep -q "qbittorrent"; then
    echo "Stopping qbittorrent container..."
    docker stop qbittorrent
fi

# Remove the container if it exists
if docker ps -a | grep -q "qbittorrent"; then
    echo "Removing qbittorrent container..."
    docker rm qbittorrent
fi

# Start the new container
echo "Starting qbittorrent container..."

docker build -t qbittorrent-nox .

echo "qbittorrent container started successfully."
