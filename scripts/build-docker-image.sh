#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   build-docker-image.sh                                                        |
#|                                                                                |
#+--------------------------------------------------------------------------------+
#|   Guillaume Plante <codegp@icloud.com>                                         |
#|   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      |
#+--------------------------------------------------------------------------------+


SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo -e "$tmp_root")
ROOT_DIRECTORY="$ROOT_DIR"
SCRIPTS_DIRECTORY="$ROOT_DIR/scripts"
DEPLOY_PATH="$ROOT_DIR/deploy"
TMPLIBS_DIRECTORY="$ROOT_DIR/tmp/libs"
EXTERNALS_DIRECTORY="$ROOT_DIR/externals"
QBITTORRENT_DIRECTORY="$EXTERNALS_DIRECTORY/qBittorrent"
VERSION_FILE="$QBITTORRENT_DIRECTORY/version.nfo"

# =========================================================
# function:     logs functions
# description:  log messages to fils and console
# =========================================================
log_ok() {
    echo -e " ✔️ ${WHITE}$1${NC}"
}
log_info() {
    echo -e " ➡️ ${WHITE}$1${NC}"
}
log_warn() {
    echo -e " ⚠️ ${YELLOW}$1${NC}"
}
log_error() {
    CAT="error"
    if [[ "$2" != "" ]]; then
        CAT="$2"
    fi
    echo -e " ⛔ ${RED}[$CAT]${NC} ${YELLOW}$1${NC}"
    popd > /dev/null
    exit 1
}



list_docker_tags() {
    local user="arsscriptum"
    local repo="qbittorrentvpn"
    local url="https://hub.docker.com/v2/repositories/$user/$repo/tags/"

    # Fetch the list of tags
    curl -s "$url" | jq -r '.results[].name' || echo "Error fetching tags"
}


check_docker_tag() {
    local tag="$1"
    local user="arsscriptum"
    local repo="qbittorrentvpn"
    local url="https://hub.docker.com/v2/repositories/$user/$repo/tags/"

    if [[ -z "$tag" ]]; then
        echo "Usage: check_docker_tag <tag>"
        return 1
    fi

    # Fetch tags and check if the specified tag exists
    if curl -s "$url" | jq -e --arg tag "$tag" '.results[].name | select(. == $tag)' >/dev/null; then
        log_ok "Tag '$tag' exists in $user/$repo."
        return 0
    else
        log_warn "Tag '$tag' does NOT exist in $user/$repo."
        return 1
    fi
}



if [[ ! -d "$DEPLOY_PATH" ]]; then 
    log_error "MISSING DEPLOY PATH. Build using ./scripts/build-and-install.sh" 
fi 


pushd "$ROOT_DIRECTORY" > /dev/null
VERSION_NUM="1.2.0"
if [[ -f "$VERSION_FILE" ]]; then 
    VERSION_NUM=$(cat "$VERSION_FILE")
else 
    log_warn "NO VERSION FILE at $VERSION_FILE" 
fi 


NEW_PATH=$(du -sh "$DEPLOY_PATH" | awk '{ print $2 }')
DEPLOY_PATH_SIZE=$(du -sh "$DEPLOY_PATH" | awk '{ print $1 }')

if [[ "$DEPLOY_PATH_SIZE" == "4.0K" ]]; then 
    log_error "MISSING DEPLOY DATA in PATH $NEW_PATH. Build using ./scripts/build-and-install.sh" 
fi 

OWNER="arsscriptum"
IMAGE_NAME="qbittorrentvpn"

log_info "======================================================"
log_info "OWNER          $OWNER"
log_info "IMAGE_NAME     $IMAGE_NAME"
log_info "VERSION_NUM    $VERSION_NUM"
log_info "DEPLOY_PATH    $VERSION_NUM"
log_info "DEPLOY_SIZE    $DEPLOY_PATH_SIZE"
log_info "======================================================"


# Stop the container if it's running
if docker ps | grep -q "qbittorrent"; then
    log_warn "Stopping qbittorrent container..."
    docker stop "$IMAGE_NAME" > /dev/null 2>&1
fi

# Remove the container if it exists
if docker ps -a | grep -q "qbittorrent"; then
    log_warn "Removing qbittorrent container..."
    docker rm "$IMAGE_NAME" > /dev/null 2>&1
fi

check_docker_tag "$VERSION_NUM"

if [[ $? -eq 0 ]]; then
    log_error "ALREADY A TAG $VERSION_NUM"
fi

# Start the new container
log_info "BUILDING qbittorrent container $VERSION_NUM"

docker build -t "$OWNER/$IMAGE_NAME:$VERSION_NUM" .

docker push "$OWNER/$IMAGE_NAME:$VERSION_NUM" 

docker build -t "$OWNER/$IMAGE_NAME:latest" .

docker push "$OWNER/$IMAGE_NAME:latest" 
 

log_info "checking $VERSION_NUM"
check_docker_tag "$VERSION_NUM"

if [[ $? -ne 0 ]]; then
    log_error "no such tag"
fi

TAGS=$(list_docker_tags)

for tag in $TAGS; do 
    log_info "TAG: $tag" 
done