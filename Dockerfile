# Use Ubuntu as the base image
FROM ubuntu:24.04


# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    QBITTORRENT_USER=qbittorrent \
    QBITTORRENT_CONFIG=/config \
    LD_LIBRARY_PATH="/usr/local/lib:/usr/lib/qt6:/lib/x86_64-linux-gnu"

# Create qbittorrent user and group
RUN groupadd -r ${QBITTORRENT_USER} && useradd -r -g ${QBITTORRENT_USER} -m ${QBITTORRENT_USER}


# Install system dependencies (except Qt6)
RUN apt update && apt install -y \
    libboost-dev \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*


# Create directories for libraries
RUN mkdir -p /opt/qbittorrent

COPY deploy /opt/qbittorrent

# Create necessary directories
RUN mkdir -p /config/qBittorrent/cache /downloads /logs
RUN chown -R ${QBITTORRENT_USER}:${QBITTORRENT_USER} /downloads /config /logs
RUN chmod -R 777 /config

# Expose ports (WebUI & BitTorrent)
EXPOSE 8080 8999 8999/udp

# Switch to the qbittorrent user
USER ${QBITTORRENT_USER}

# Command to run qbittorrent-nox
ENTRYPOINT ["/opt/qbittorrent/qbittorrent-nox.sh", "--profile=/config"]
