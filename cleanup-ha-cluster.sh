#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_PATH="$SCRIPT_DIR/config-default.sh"

source "$CONFIG_PATH"

"$SCRIPT_DIR/ubuntu-xenial/cleanup.sh" \
    "$SCRIPT_DIR" \
    "$CONFIG_PATH"