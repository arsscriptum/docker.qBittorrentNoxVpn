#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   export-libs.sh                                                               |
#|                                                                                |
#+--------------------------------------------------------------------------------+
#|   Guillaume Plante <codegp@icloud.com>                                         |
#|   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      |
#+--------------------------------------------------------------------------------+

# variables for colors
WHITE='\033[0;97m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'

# variables for cmd arguments
LISTONLY_OPT=0
DESTPATH_OPT=0
FORCE_OPT=0

# Usage function
usage() {
    echo "Usage: $0 <executable> -p <path> [options]"  
    echo "  -l, --list      Just list the libraries"
    echo "  -p, --path      Destination path"
    echo "  -f, --force     Force, overwrite if lib is present"
    echo "  -h, --help      Show this help message"
    exit 0
}
log_info() {
   
    echo -e "${CYAN}[log]${NC} $1"
}
log_warn() {

    echo -e "${YELLOW}[warn]${NC} ${WHITE}$1${NC}"
}
log_error() {
 
    echo -e "${RED}[error]${NC} ${YELLOW}$1${NC}"
    exit 1
}

# get paths values
pushd "$(dirname "$0")/.." > /dev/null
ROOT_DIRECTORY=`pwd`
popd  > /dev/null
SCRIPT_DIR="$ROOT_DIRECTORY/scripts"
EXPORT_DIR="$ROOT_DIRECTORY/export"
EXECUTABLE="$1"
DEST_PATH="$2"
NO_COPY=false

# install
do_install() {
    log_info "Virtual environment setup completed."
    return 0
}

# Parse script arguments
for arg in "$@"; do
    case $arg in
        -l|--list)
            LISTONLY_OPT=1
            NO_COPY=true
            ;;
        -p|--path)
            DESTPATH_OPT=1
            shift # Shift past the version
            if [[ $# -gt 1 ]]; then
                TMP_EXPORT_DIR="$2"
                EXPORT_DIR="$TMP_EXPORT_DIR"
            fi
            ;;
        -f|--force)
            FORCE_OPT=1
            ;;
        -h|--help)
            usage
            ;;
    esac
done

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

mkdir -p "$EXPORT_DIR"
if [[ "$DESTPATH_OPT" -eq 0 ]]; then
    log_warn "No destination path specified, using $EXPORT_DIR"
else
    log_info "Exporting to $EXPORT_DIR"
fi 

# Validate executable exists
if [[ ! -f "$EXECUTABLE" ]]; then
    echo "Error: Executable '$EXECUTABLE' not found."
    exit 1
fi

# Validate destination path
if [[ ! -d "$EXPORT_DIR" ]]; then
    echo "Error: Destination path '$EXPORT_DIR' is not a directory."
    exit 1
fi

# Use ldd to find library dependencies
LIBS=$(ldd "$EXECUTABLE" | awk '{print $3}' | grep -v '^$')
COUNT=0

if [[ "$NO_COPY" == true ]]; then
    log_info "WOULD COPY:"
fi
# Process each library
for LIB in $LIBS; do
    if [[ -f "$LIB" ]]; then
        BASENAME=$(basename "$LIB")
        DEST_LIB="$EXPORT_DIR/$BASENAME"

        if [[ "$NO_COPY" == true ]]; then
            echo "$LIB"
        else
            if [[ -f "$DEST_LIB" ]]; then
                if [[ $FORCE_OPT -eq 0 ]]; then
                    log_info "Skipping: $BASENAME (already exists in destination)"
                else
                    log_info "Force Copying: $LIB -> $DEST_LIB"
                    cp -f "$LIB" "$EXPORT_DIR"
                    COUNT=$(( $COUNT + 1 ))
                fi
            else
                log_info "Copying: $LIB -> $DEST_LIB"
                cp "$LIB" "$EXPORT_DIR"
                COUNT=$(( $COUNT + 1 ))
            fi
        fi
    fi
done

if [[ "$NO_COPY" == false ]]; then
    log_info "$COUNT libraries copied successfully."
fi
