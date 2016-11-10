#!/bin/bash
BASE_DIR=${1:-}
WORK_DIR=${2:-}
CONFIG_PATH=${3:-}

KUBECTL="$WORK_DIR/binaries/kubectl"

source "$CONFIG_PATH"

"$KUBECTL" config use-context "$CLUSTER_NAME-context"

"$KUBECTL" delete -f "$BASE_DIR/addons/dashboard-controller.yaml"
"$KUBECTL" delete -f "$BASE_DIR/addons/dashboard-service.yaml"
"$KUBECTL" delete -f "$WORK_DIR/addons/skydns-rc.yaml"
"$KUBECTL" delete -f "$WORK_DIR/addons/skydns-svc.yaml"