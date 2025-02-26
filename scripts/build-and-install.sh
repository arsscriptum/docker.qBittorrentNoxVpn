#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   build-and-install.sh                                                         |
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
TMPLIBS_DIRECTORY="$ROOT_DIR/tmp/libs"
EXTERNALS_DIRECTORY="$ROOT_DIR/externals"
QBITTORRENT_DIRECTORY="$EXTERNALS_DIRECTORY/qBittorrent"
TMP_DEPLOY_DIRECTORY="$QBITTORRENT_DIRECTORY/install"
DEPLOY_DIRECTORY="$ROOT_DIR/deploy"

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



rm -rf "$DEPLOY_DIRECTORY"

pushd "$QBITTORRENT_DIRECTORY" > /dev/null

./scripts/build.sh --release


if [[ $? -ne 0 ]]; then
    log_error "build error"
fi

log_ok "Export libs"


./scripts/install.sh

if [[ $? -ne 0 ]]; then
    log_error "build error"
fi



cp -R "$TMP_DEPLOY_DIRECTORY" "$DEPLOY_DIRECTORY"
rm -rf "$TMP_DEPLOY_DIRECTORY"

popd > /dev/null 

NEW_PATH=$(du -sh "$DEPLOY_DIRECTORY" | awk '{ print $2 }')
SIZE=$(du -sh "$DEPLOY_DIRECTORY" | awk '{ print $1 }')

log_ok "SUCCESSFULLY DEPLOYED BINARY AND DEPENDENCIES"
log_ok "Deployed to \"$DEPLOY_DIRECTORY\" size: $SIZE"
