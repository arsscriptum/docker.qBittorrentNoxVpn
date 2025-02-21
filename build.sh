#!/bin/bash

# Stop the container if it's running
if docker ps | grep -q "qbittorrent"; then
    echo "Stopping qbittorrent container..."
    docker stop qbittorrent-nox
fi

# Remove the container if it exists
if docker ps -a | grep -q "qbittorrent"; then
    echo "Removing qbittorrent container..."
    docker rm qbittorrent-nox
fi

# Start the new container
echo "Starting qbittorrent container..."

docker build -t arsscriptum/qbittorrent-nox .

echo "qbittorrent container started successfully."
