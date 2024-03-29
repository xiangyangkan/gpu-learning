#!/bin/bash
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yaml"
SOURCE_ENV_FILE="$SCRIPT_DIR/default.env"
TARGET_ENV_FILE="$SCRIPT_DIR/.env"
source "$SCRIPT_DIR/../utils.sh"
source "$SCRIPT_DIR/default.env"

USER=$1
WORKSPACE=$2

if [[ -z "$USER" ]]; then
    echo "Please provide a username"
    exit 1
fi

if [[ -z "$WORKSPACE" ]]; then
    WORKSPACE="/data"
    echo "No workspace provided, using default: $WORKSPACE"
fi

function change_user_env() {
    local compose_file="$1"
    local username="$2"
    local workspace_dir="$3"
    sed -i -e "s|user|${username}|g" "$compose_file"
    sed -i -e "s|WORKSPACE|${workspace_dir}|g" "$compose_file"
}

dos2unix "$COMPOSE_FILE" "$SOURCE_ENV_FILE" "$TARGET_ENV_FILE"
change_user_env "$COMPOSE_FILE" "$USER" "$WORKSPACE"
replace_tag_in_env_file "rivia/deepstream" "$SOURCE_ENV_FILE" "$TARGET_ENV_FILE" "IMAGE_TAG__DEEPSTREAM" 2 "moderate"
replace_tag_in_env_file "aler9/rtsp-simple-server" "$SOURCE_ENV_FILE" "$TARGET_ENV_FILE" "IMAGE_TAG__RTSP" 2
