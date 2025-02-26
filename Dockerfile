# Use Ubuntu as the base image
FROM ubuntu:24.04

VOLUME /downloads
VOLUME /config

ENV DOCKER_IMAGE_VERSION=2.0
ENV DEBIAN_FRONTEND=noninteractive

RUN usermod -u 99 nobody

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    QBITTORRENT_USER=qbittorrent \
    QBITTORRENT_CONFIG=/config \
    LD_LIBRARY_PATH="/usr/local/lib:/usr/lib/qt6:/lib/x86_64-linux-gnu"


# create an apt config file for this repository
COPY speedtest-cli/ookla_speedtest-cli.list /etc/apt/sources.list.d/ookla_speedtest-cli.list
COPY speedtest-cli/ookla_speedtest-cli-archive-keyring.gpg /etc/apt/keyrings/ookla_speedtest-cli-archive-keyring.gpg

RUN chmod 0644 /etc/apt/keyrings/ookla_speedtest-cli-archive-keyring.gpg

RUN apt update && apt install -y \
    libboost-dev libssl3 && apt-get install -y --no-install-recommends \
    bash curl wget jq apt-utils openssl software-properties-common iproute2 \
    speedtest-cli openvpn curl moreutils net-tools dos2unix kmod \
    iptables ipcalc unrar && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Verify installation
RUN speedtest --version

# Add configuration and scripts
COPY openvpn/ /etc/openvpn/
COPY qbittorrent/ /etc/qbittorrent/

RUN chmod +x /etc/qbittorrent/*.sh /etc/qbittorrent/*.init /etc/openvpn/*.sh

# Create directories for libraries
RUN mkdir -p /opt/qbittorrent

# Super Critical! My deploy directory here
COPY deploy /opt/qbittorrent

# Create necessary directories
RUN mkdir -p /config/qBittorrent/cache /downloads /logs
#RUN chown -R 1000:1000 /downloads /config /logs
RUN chmod -R 777 /config
RUN chmod -R 777 /logs
# Expose ports (WebUI & BitTorrent)
EXPOSE 8080 8999 8999/udp

# Switch to the qbittorrent user
# USER ${QBITTORRENT_USER}

ENTRYPOINT ["/bin/bash", "/etc/openvpn/start.sh"]
# Command to run qbittorrent-nox
# ENTRYPOINT ["/opt/qbittorrent/qbittorrent-nox.sh", "--profile=/config"]
