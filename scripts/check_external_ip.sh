#!/bin/bash

app=qbittorrentvpn

YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

pecho() { echo -e "${RED}$1${NC}"; }
log() { pecho "$@"; }
error() { log "ERROR: $@" >&2; }
fatal() { error "$@"; exit 1; }
try() { "$@" || fatal "'$@' failed"; }
usage_fatal() { usage >&2; pecho "" >&2; fatal "$@"; }


exit_error()  { echo -e "{\n\t\"status\": \"error\"\n\t\"id\": \"$1\"\n}\n";exit $1;  }



# check if container running
#if ! docker ps --format "{{.Names}}"| grep -iq $app ; then
#  exit_error 2
#fi 


f_container_name()
{
	ret=$(docker ps --format "{{.Names}}"| grep -i $app)
	if [ $? -eq 0 ]; then
		echo "$ret"
	else
		echo "error"
	fi
}

f_get_extip()
{
	ret=$(docker exec $1 curl --silent "http://ipinfo.io/ip")
	if [ $? -eq 0 ]; then
		echo "$ret"
	else
		echo "error"
	fi
}


f_check_extip()
{
	ret=$(curl --silent ipinfo.io/$ext_ip | jq '. + {status: "success"}')
	if [ $? -eq 0 ]; then
		echo "$ret"
	else
		echo "error"
	fi
}

# get full container name
var_cont_name=$(f_container_name "$app")

# if failure to get container name, return error
if [ $var_cont_name == "error" ]; then
	exit_error 3
fi

# get external ip
ext_ip=$(f_get_extip "$var_cont_name")
if [ $ext_ip == "error" ]; then
	exit_error 4
fi

json=$(f_check_extip)

if [ $? -ne 0 ]; then
	exit_error 5
fi

echo "$json"