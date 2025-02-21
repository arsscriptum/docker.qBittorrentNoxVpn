# Use Ubuntu as the base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    QBITTORRENT_USER=qbittorrent \
    QBITTORRENT_CONFIG=/config \
    LD_LIBRARY_PATH=/usr/lib/qt6:/usr/local/lib:/opt/qt5.15.2/lib:/opt/qt5.15.2/lib

# Install system dependencies (except Qt6)
RUN apt update && apt install -y \
    libboost-dev \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Create directories for libraries
RUN mkdir -p /usr/lib/qt6 /usr/local/lib

# Copy compiled qbittorrent-nox binary
COPY build/qbittorrent-nox /usr/bin/qbittorrent-nox

# Copy all required Qt6 and ICU libraries from host
COPY libs/libQt6*.so.6 /usr/lib/qt6/
COPY libs/libicu*.so.73 /usr/lib/qt6/

# 🔥 Copy the locally stored libraries into the container
COPY libs/libz.so.1.3.1 /usr/local/lib/
COPY libs/libtorrent-rasterbar.so.2.0.11 /usr/local/lib/

# Create the missing symlinks inside the container
RUN ln -s /usr/local/lib/libz.so.1.3.1 /usr/local/lib/libz.so.1 && \
    ln -s /usr/local/lib/libtorrent-rasterbar.so.2.0.11 /usr/local/lib/libtorrent-rasterbar.so.2.0

# Ensure binaries and libraries are executable
RUN chmod +x /usr/bin/qbittorrent-nox && chmod -R 755 /usr/lib/qt6 /usr/local/lib

# Create necessary directories
RUN mkdir -p /downloads /config /logs && chown -R ${QBITTORRENT_USER}:${QBITTORRENT_USER} /downloads /config /logs

# Expose ports (WebUI & BitTorrent)
EXPOSE 8080 8999 8999/udp

# Switch to the qbittorrent user
USER ${QBITTORRENT_USER}

# Command to run qbittorrent-nox
ENTRYPOINT ["/usr/bin/qbittorrent-nox", "--profile=/config"]
