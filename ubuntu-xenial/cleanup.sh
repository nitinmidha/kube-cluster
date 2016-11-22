#!/bin/bash
BASE_DIR=${1:-}
CONFIG_PATH=${2:-}

source "$CONFIG_PATH"

# Provision and Deploy Masters
for node in "${NODES[@]}"; do
    echo "Cleaninng up:$node"
    
    ssh $SSH_OPTS "$node" 'sudo bash -s' < "$BASE_DIR/ubuntu-xenial/common/cleanup-node.sh"
done