#!/bin/bash

SCRIPT_PATH=$(realpath "$BASH_SOURCE")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

tmp_root=$(pushd "$SCRIPT_DIR/.." | awk '{print $1}')
ROOT_DIR=$(eval echo -e "$tmp_root")
ENV_FILE="$ROOT_DIR/.env"
ROOT_DIRECTORY="$ROOT_DIR"
SCRIPT_DIR="$ROOT_DIR/scripts"

# variables for colors
WHITE='\033[0;30m'
YELLOW='\033[0;33m'
YELLOWI='\033[3;33m'
RED='\033[0;31m'
IRED='\033[4;31m'
NC='\033[0m' # No Color

NOCACHE="--no-cache"

pushd "$ROOT_DIR" > /dev/null

# Function to display usage information
usage() {
    echo -e "Usage: $0 <tag> [-p|--push]"
    echo -e "  tag: Docker image tag (e.g., latest, v1.0)"
    echo -e "  -p, --push: Push the image to Docker Hub"
    exit 1
}


# Validate if tag is provided
if [ -z "$1" ]; then
    TAG="latest"
else
    TAG=$1
fi

PUSH_IMAGE=false

REPO_OWNER=$(git remote get-url origin | awk -F'[:/]' '{print $(NF-1)}')
REPO_NAME=$(git remote get-url origin | sed -E 's#^.*/##; s#\.git$##')
IMAGE_NAME=$(git remote get-url origin | awk -F'[:/.]' '{print $(NF-1)}')

echo -e "\n⚠ ${IRED}ENVIRONMENT VALUES${NC}\n${YELLOW}REPO_OWNER${NC} ➪ ${RED}$REPO_OWNER\n${NC}${YELLOW}REPO_NAME${NC} ➪ ${RED}$REPO_NAME\n${NC}${YELLOW}IMAGE_NAME${NC} ➪ ${RED}$IMAGE_NAME\n${NC}${YELLOW}TAG${NC} ➪ ${RED}$TAG\n${NC}"

# Parse optional arguments
if [ "$2" == "-p" ] || [ "$2" == "--push" ]; then
    PUSH_IMAGE=true
fi

# Validate if the user is in the docker group
if ! groups "$USER" | grep -q "\bdocker\b"; then
    echo -e " ❌ Error: User '$USER' is not in the 'docker' group."
    echo -e "Add the user to the docker group with: sudo usermod -aG docker $USER"
    exit 1
fi

# Build the Docker image
IMAGE_ID="$REPO_OWNER/$IMAGE_NAME:$TAG"
echo -e "${RED}  🛈${NC} ${YELLOWI}  Building Docker image: $IMAGE_NAME${NC}"
docker build $NOCACHE -t "$IMAGE_NAME" .

if [ $? -ne 0 ]; then
    echo -e " ❌ Error: Docker build failed."
    exit 1
fi

# Optionally push the image
if $PUSH_IMAGE; then
    if ! docker info | grep -q "Username:"; then
        echo -e " ❌ Error: Not logged into Docker Hub. Run 'docker login' and try again."
        exit 1
    fi

    echo -e "${RED}  🛈${NC} ${YELLOWI}  Pushing Docker image: $IMAGE_ID${NC}"
    docker push "$IMAGE_ID"

    if [ $? -ne 0 ]; then
        echo -e " ❌ Error: Failed to push Docker image."
        exit 1
    else 
        echo -e " ✅ successfully pushed $IMAGE_ID"
    fi

    if [[ "$TAG" != "latest" ]]; then 
        echo -e "${RED}  🛈${NC} ${YELLOWI}Pushing \"latest\" tag: $REPO_OWNER/$IMAGE_NAME:latest${NC}"
        docker push "$REPO_OWNER/$IMAGE_NAME:latest"
    fi

    if [ $? -ne 0 ]; then
        echo -e "  ❌ Error: Failed to push Docker image."
        exit 1
    else 
        echo -e " ✅ successfully pushed $REPO_OWNER/$IMAGE_NAME:latest"
    fi
fi

popd > /dev/null
exit 0
