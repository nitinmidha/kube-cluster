#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_PATH="$SCRIPT_DIR/config-default.sh"

source "$CONFIG_PATH"

WORK_DIR="$SCRIPT_DIR/workdir"

mkdir -p "$WORK_DIR"

"$SCRIPT_DIR/ubuntu-xenial/deploy.sh" \
    "$SCRIPT_DIR" \
    "$WORK_DIR" \
    "$CONFIG_PATH"

sleep 30s

"$SCRIPT_DIR/addons/deploy-addons.sh" \
    "$SCRIPT_DIR" \
    "$WORK_DIR" \
    "$CONFIG_PATH"