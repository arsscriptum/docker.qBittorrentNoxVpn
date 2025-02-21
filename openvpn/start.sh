#!/bin/bash

# Forked from binhex's OpenVPN dockers
set -e

CYAN='\033[0;36m'
WHITE='\033[0;97m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

LOGS_DIR="/logs"
LOG_FILE="$LOGS_DIR/start.log"

log_warning() {
    echo -e " ⚠   ${YELLOW}$1${NC}"  | ts '%Y-%m-%d %H:%M:%.S'
    logger --tag "qbittorrentvpn" -p user.warning " ⚠ $1"
    echo -e " ⚠   ${YELLOW}$1${NC}" >> "$LOG_FILE"
}

log_error() {
    echo -e " ❌   ${YELLOW}$1${NC}"  | ts '%Y-%m-%d %H:%M:%.S'
    logger --tag "qbittorrentvpn" -p user.error " ❌ $1"
    echo -e " ❌   $1" >> "$LOG_FILE"
}

log_info() {
    logger --tag "qbittorrentvpn" -p user.info "$1"
    echo -e "${CYAN} 🛈 ${NC}${WHITE}$1${NC}"  | ts '%Y-%m-%d %H:%M:%.S'
    echo -e "${CYAN} 🛈 ${NC}${WHITE}$1${NC}" >> "$LOG_FILE"
}

get_next_filename() {
    local base_file="$1"
    local max_suffix=9
    local next_file=""

    for i in $(seq 0 $max_suffix); do
        next_file="${base_file}.${i}"
        if [[ ! -e "$next_file" ]]; then
            echo "$next_file"
            return
        fi
    done

    next_file="${base_file}.0"
    rm -rf $next_file
    echo "$next_file"
    return
}


if [[ ! -d "$LOGS_DIR" ]]; then
   mkdir -p "$LOGS_DIR"
   chmod -R 777 "$LOGS_DIR"
   log_info "Creating \"$LOGS_DIR\""
fi


if [[ -f "$LOG_FILE" ]]; then
    next_file=$(get_next_filename "$LOG_FILE")
    log_info "Next available filename: $next_file"
    log_info "Backup of log file \"$next_file\""
    mv -f "$LOG_FILE" "$next_file"
fi

log_info "logging to \"$LOG_FILE\"..."
echo -e  "\n\n ========== STARTED ON $START_TIME ========== \n" > "$LOG_FILE"


# check for presence of network interface docker0
check_network=$(ifconfig | grep docker0 || true)

# if network interface docker0 is present then we are running in host mode and thus must exit
if [[ ! -z "${check_network}" ]]; then
	log_error "Network type detected as 'Host', this will cause major issues, please stop the container and switch back to 'Bridge' mode" && exit 1
fi

export VPN_ENABLED=$(echo "${VPN_ENABLED}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${VPN_ENABLED}" ]]; then
	log_info "VPN_ENABLED defined as '${VPN_ENABLED}'"
else
	log_warning "VPN_ENABLED not defined,(via -e VPN_ENABLED), defaulting to 'yes'"
	export VPN_ENABLED="yes"
fi

if [[ $VPN_ENABLED == "yes" ]]; then
	# create directory to store openvpn config files
	mkdir -p /config/openvpn
	# set perms and owner for files in /config/openvpn directory
	set +e
	chown -R "${PUID}":"${PGID}" "/config/openvpn" &> /dev/null
	exit_code_chown=$?
	chmod -R 775 "/config/openvpn" &> /dev/null
	exit_code_chmod=$?
	set -e
	if (( ${exit_code_chown} != 0 || ${exit_code_chmod} != 0 )); then
		log_warning "Unable to chown/chmod /config/openvpn/, assuming SMB mountpoint"
	fi
	
	
	log_info "OPENVPN_CONFIG is set to \"$OPENVPN_CONFIG\""
	if [[ -z "${OPENVPN_CONFIG}" ]]; then
		if [[ ! -e /config/openvpn/default.ovpn ]]; then
			log_error "No OPENVPN_CONFIG config set in environment (docker-compose). Also no /config/openvpn/default.ovpn file, exiting..." && exit 1
		else 
			TMP_CONFIG_FILE="/config/openvpn/$(cat /config/openvpn/default.ovpn)"
			if [[ ! -e "$TMP_CONFIG_FILE" ]]; then
				log_error "No OpenVPN config set in environment (docker-compose). Also no default $TMP_CONFIG_FILE file, exiting..." && exit 1
			fi
			VPN_CONFIG="$TMP_CONFIG_FILE"
			log_info "Setting VPN_CONFIG to $VPN_CONFIG"
		fi
	else
		TMP_CONFIG_FILE=$(find /config/openvpn -maxdepth 1 -name "*.ovpn" -print | grep $OPENVPN_CONFIG)
		if [[ -z $TMP_CONFIG_FILE || ! -e "$TMP_CONFIG_FILE" ]]; then
			log_error "cannot find configuration file \"$OPENVPN_CONFIG\" in /config/openvpn , exiting..." && exit 1
		fi		
		VPN_CONFIG="$TMP_CONFIG_FILE"
		log_info "Setting VPN_CONFIG to $VPN_CONFIG"
	fi

	export VPN_CONFIG="$VPN_CONFIG"
	log_info "OpenVPN config file (ovpn extension) is located at ${VPN_CONFIG}"

	# Read username and password env vars and put them in credentials.conf, then add ovpn config for credentials file
	if [[ ! -z "${VPN_USERNAME}" ]] && [[ ! -z "${VPN_PASSWORD}" ]]; then
		log_info "OpenVPN config set username \"${VPN_USERNAME}\" and password  \"${VPN_PASSWORD}\""

		if [[ ! -e /config/openvpn/credentials.conf ]]; then
			log_info "/config/openvpn/credentials.conf not  present, creating..."
			touch /config/openvpn/credentials.conf
		fi

		echo "${VPN_USERNAME}" > /config/openvpn/credentials.conf
		echo "${VPN_PASSWORD}" >> /config/openvpn/credentials.conf

		# Replace line with one that points to credentials.conf
		auth_cred_exist=$(cat ${VPN_CONFIG} | grep -m 1 'auth-user-pass')
		if [[ ! -z "${auth_cred_exist}" ]]; then
			# Get line number of auth-user-pass
			LINE_NUM=$(grep -Fn -m 1 'auth-user-pass' ${VPN_CONFIG} | cut -d: -f 1)
			sed -i "${LINE_NUM}s/.*/auth-user-pass credentials.conf\n/" ${VPN_CONFIG}
		else
			sed -i "1s/.*/auth-user-pass credentials.conf\n/" ${VPN_CONFIG}
		fi
	fi
	
	# convert CRLF (windows) to LF (unix) for ovpn
	/usr/bin/dos2unix "${VPN_CONFIG}" 1> /dev/null
	
	# parse values from ovpn file
	export vpn_remote_line=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=^remote\s)[^\n\r]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${vpn_remote_line}" ]]; then
		log_info "VPN remote line defined as '${vpn_remote_line}'"
	else
		log_error "VPN configuration file ${VPN_CONFIG} does not contain 'remote' line, showing contents of file before exit..."
		cat "${VPN_CONFIG}" && exit 1
	fi
	export VPN_REMOTE=$(echo "${vpn_remote_line}" | grep -P -o -m 1 '^[^\s\r\n]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${VPN_REMOTE}" ]]; then
		log_info "VPN_REMOTE defined as '${VPN_REMOTE}'"
	else
		log_error "VPN_REMOTE not found in ${VPN_CONFIG}, exiting..." && exit 1
	fi
	export VPN_PORT=$(echo "${vpn_remote_line}" | grep -P -o -m 1 '(?<=\s)\d{2,5}(?=\s)?+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${VPN_PORT}" ]]; then
		log_info "VPN_PORT defined as '${VPN_PORT}'"
	else
		log_error "VPN_PORT not found in ${VPN_CONFIG}, exiting..." && exit 1
	fi
	export VPN_PROTOCOL=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=^proto\s)[^\r\n]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${VPN_PROTOCOL}" ]]; then
		log_info "VPN_PROTOCOL defined as '${VPN_PROTOCOL}'"
	else
		export VPN_PROTOCOL=$(echo "${vpn_remote_line}" | grep -P -o -m 1 'udp|tcp-client|tcp$' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
		if [[ ! -z "${VPN_PROTOCOL}" ]]; then
			log_info "VPN_PROTOCOL defined as '${VPN_PROTOCOL}'"
		else
			log_warning "VPN_PROTOCOL not found in ${VPN_CONFIG}, assuming udp"
			export VPN_PROTOCOL="udp"
		fi
	fi
	
	# required for use in iptables
	if [[ "${VPN_PROTOCOL}" == "tcp-client" ]]; then
		export VPN_PROTOCOL="tcp"
	fi
	
	VPN_DEVICE_TYPE=$(cat "${VPN_CONFIG}" | grep -P -o -m 1 '(?<=^dev\s)[^\r\n\d]+' | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${VPN_DEVICE_TYPE}" ]]; then
		export VPN_DEVICE_TYPE="${VPN_DEVICE_TYPE}0"
		log_info "VPN_DEVICE_TYPE defined as '${VPN_DEVICE_TYPE}'"
	else
		log_error "VPN_DEVICE_TYPE not found in ${VPN_CONFIG}, exiting..." && exit 1
	fi
	# get values from env vars as defined by user
	export LAN_NETWORK=$(echo "${LAN_NETWORK}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${LAN_NETWORK}" ]]; then
		log_info "LAN_NETWORK defined as '${LAN_NETWORK}'"
	else
		log_error "LAN_NETWORK not defined (via -e LAN_NETWORK), exiting..." && exit 1
	fi
	export NAME_SERVERS=$(echo "${NAME_SERVERS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${NAME_SERVERS}" ]]; then
		log_info "NAME_SERVERS defined as '${NAME_SERVERS}'"
	else
		log_warning "NAME_SERVERS not defined (via -e NAME_SERVERS), defaulting to Google and FreeDNS name servers"
		export NAME_SERVERS="8.8.8.8,37.235.1.174,8.8.4.4,37.235.1.177"
	fi
	export VPN_OPTIONS=$(echo "${VPN_OPTIONS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${VPN_OPTIONS}" ]]; then
		log_info "VPN_OPTIONS defined as '${VPN_OPTIONS}'"
	else
		log_info "VPN_OPTIONS not defined (via -e VPN_OPTIONS)"
		export VPN_OPTIONS=""
	fi
elif [[ $VPN_ENABLED == "no" ]]; then
	log_warning  "!!IMPORTANT!! You have set the VPN to disabled, you will NOT be secure!"
fi

# split comma seperated string into list from NAME_SERVERS env variable
IFS=',' read -ra name_server_list <<< "${NAME_SERVERS}"

# process name servers in the list
for name_server_item in "${name_server_list[@]}"; do

	# strip whitespace from start and end of lan_network_item
	name_server_item=$(echo "${name_server_item}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')

	log_info "Adding ${name_server_item} to resolv.conf"
	echo "nameserver ${name_server_item}" >> /etc/resolv.conf

done

if [[ -z "${PUID}" ]]; then
	log_info "PUID not defined. Defaulting to root user"
	export PUID="root"
fi

if [[ -z "${PGID}" ]]; then
	log_info "PGID not defined. Defaulting to root group"
	export PGID="root"
fi

if [[ $VPN_ENABLED == "yes" ]]; then
	log_info "Starting OpenVPN..."
	cd /config/openvpn
	exec openvpn --config ${VPN_CONFIG} &
	# give openvpn some time to connect
	sleep 5
	#exec /bin/bash /etc/openvpn/openvpn.init start &
	exec /bin/bash /etc/qbittorrent/iptables.sh
else
	exec /bin/bash /etc/qbittorrent/start.sh
fi
