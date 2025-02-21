#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   list-secrets.sh                                                              │
# │                                                                                │
# └────────────────────────────────────────────────────────────────────────────────┘

YELLOW='\033[0;33m'
YELLOWH='\033[0;93m'
RED='\033[0;31m'
REDH='\033[0;91m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo "$tmp_root")
ENV_FILE="$ROOT_DIR/.env"
ROOT_DIRECTORY="$ROOT_DIR"
SCRIPT_DIR="$ROOT_DIR/scripts"


if [[ -f "$ENV_FILE" ]]; then
   source "$ENV_FILE"
else
   echo "[error] missing .env file @ \"$ENV_FILE\"!"
   exit 1
fi



# Handy logging and error handling functions
pecho() { printf %s\\n "$*"; }

log() { pecho "$@"; }

DEBUG_MODE=true
# Verbose output function
log_debug() {
    if $DEBUG_MODE; then
        echo -e "${RED}[debug]${NC}${YELLOW} $1${NC}"
    fi
}

log_info() {
    echo -e "${CYAN}[LOG]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1${NC}"
}

log_error() {
    echo -e "${REDH}[ERROR]${NC}${YELLOWH} $1${NC}"; exit 1
}

pushd "$(dirname "$0")/.." > /dev/null
ROOT_DIR=`pwd`

SCRIPTS_DIR="$ROOT_DIR/scripts"

ENV_FILE="$ROOT_DIR/.env"

# Load environment variables from .env file
if [[ -f "$ENV_FILE" ]]; then
    log_debug "Load environment variables from .env file"
    # Use `envsubst` for proper substitution and handling of special characters
    set -a
    source .env
    set +a
else
    log_error "Error: .env file not found. Please create one with GHTOKENWIDE, REPO_OWNER, and REPONAME."
    exit 1
fi

REPO_OWNER=$(git remote get-url origin | awk -F'[:/]' '{print $(NF-1)}')
REPO_NAME=$(git remote get-url origin | sed -E 's#^.*/##; s#\.git$##')

# Validate required variables
if [[ -z "$GH_PAT" || -z "$REPO_OWNER" || -z "$REPO_NAME" ]]; then
    if [[ -f "$ENV_FILE" ]]; then
       source "$ENV_FILE"
       if [[ -z "$GH_PAT" || -z "$REPO_OWNER" || -z "$REPO_NAME" ]]; then
          exit  1
       fi
    else
       log_error "Error: GH_PAT, REPO_OWNER, and REPONAME must be set in the .env file."
       exit 1
    fi
    log_error "Error: GH_PAT, REPO_OWNER, and REPONAME must be set in the .env file."
    exit 1
fi


log_debug "GH_PAT \"$GH_PAT\""
log_debug "REPO_OWNER \"$REPO_OWNER\""
log_debug "REPO_NAME \"$REPO_NAME\""

# GitHub API URL for listing repository secrets
API_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/secrets"


log_debug "API_URL \"$API_URL\""

# Fetch and list secrets
response=$(curl -s -H "Authorization: Bearer $GH_PAT" \
                  -H "Accept: application/vnd.github.v3+json" \
                  "$API_URL")


# Check for errors
if echo "$response" | grep -q '"message":'; then
  echo "Error fetching secrets:"
  echo "$response" | jq
  exit 1
fi

echo -e "reading...\n"
# Parse and display secrets
echo "Secrets for repository '$REPO_OWNER/$REPO_NAME':"
echo "$response" | jq

popd > /dev/null
