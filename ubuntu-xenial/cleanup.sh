#!/bin/bash
BASE_DIR=${1:-}
CONFIG_PATH=${2:-}

source "$CONFIG_PATH"


# Provision and Deploy Masters
for master_node in "${MASTER_NODES[@]}"; do
    ssh $SSH_OPTS "$master_node" 'sudo bash -s' < "$BASE_DIR/ubuntu-xenial/master/cleanup-master.sh"
done


# Provision and Deploy Masters
for worker_node in "${WORKER_NODES[@]}"; do
    ssh $SSH_OPTS "$worker_node" 'sudo bash -s' < "$BASE_DIR/ubuntu-xenial/minion/cleanup-minion.sh"
done