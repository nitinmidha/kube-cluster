#!/bin/bash
MODE=${1:-}
NODE_HOSTNAME=${2:-} # Hostname of the machine
NODE_NAME=${3:-} # Name in ETCD cluster infra${suffix}
CLUSTER_NAME=${4:-} # Name of etcd cluster
INITIAL_CLUSTER=${5:-} # Initial Cluster for ETCD cluster bootstrap

CONFIG_PATH=~/ha-kube/config-default.sh

source $CONFIG_PATH


function copy-binaries(){
    # copy binaries
    sudo mkdir -p /opt/bin
    sudo cp ~/ha-kube/etcd/binaries/* /opt/bin/
}

function configure-certs(){
    # Configure Certs
    if [ "$GENERATE_CERTS" == "true" ]; then
        #sudo groupadd -f -r "$CERT_GROUP"
        sudo mkdir -p "$CERT_DIR"
        sudo cp ~/ha-kube/certs/* "${CERT_DIR}/"
        #sudo chgrp $CERT_GROUP "${CERT_DIR}/${1}.key" "${CERT_DIR}/${1}.crt" "${CERT_DIR}/ca.crt"
        sudo chmod 660 "${CERT_DIR}/${1}.key" "${CERT_DIR}/${1}.crt" "${CERT_DIR}/ca.crt"
    fi
}


function configure-services(){
    
    export CURRENT_NODE_HOSTNAME=${1:-}
    export ETCD_NODE_NAME=${2:-}
    export ETCD_CLUSTER_NAME=${3:-}
    export ETCD_INITIAL_CLUSTER=${4:-}
    export CURRENT_NODE_IP=$(/sbin/ifconfig -a |grep eth0 -A 1|grep 'inet addr'|sed 's/\:/ /'|awk '{print $3}')
    
    
    
    sudo mkdir -p /etc/kubernetes
    envsubst < ~/ha-kube/etcd/environment/etcd.env | sudo tee /etc/kubernetes/etcd.env

    sudo cp ~/ha-kube/etcd/systemd/* /etc/systemd/system/

    
    
    sudo systemctl enable etcd.service
    sudo sudo systemctl reload-or-restart etcd.service
}

# $1: NODE_HOSTNAME
# $2: NODE_NAME, 
# $3: CLUSTER_NAME
# $4: INITIAL_CLUSTER
function deploy-etcd(){
    copy-binaries
    configure-certs "$1"
    configure-services "$1" "$2" "$3" "$4"
}

if [ "$MODE" == "deploy-etcd" ]; then
    deploy-etcd "$NODE_HOSTNAME" "$NODE_NAME" "$CLUSTER_NAME" "$INITIAL_CLUSTER"
fi