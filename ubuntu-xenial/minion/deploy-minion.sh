#!/bin/bash
CONFIG_PATH=~/ha-kube/config-default.sh
mode=${1:-}



function copy-binaries(){
    # copy binaries
    sudo mkdir -p /opt/bin
    sudo cp ~/ha-kube/minion/binaries/* /opt/bin/
}

function configure-certs(){
    # Configure Certs
    if [ "$GENERATE_CERTS" == "true" ]; then
        sudo groupadd -f -r "$CERT_GROUP"
        sudo mkdir -p "$CERT_DIR"
        sudo cp ~/ha-kube/minion/certs/* "${CERT_DIR}/"
        sudo chgrp $CERT_GROUP "${CERT_DIR}/${1}-node.key" "${CERT_DIR}/${1}-node.crt" "${CERT_DIR}/ca.crt"
        sudo chmod 660 "${CERT_DIR}/${1}-node.key" "${CERT_DIR}/${1}-node.crt" "${CERT_DIR}/ca.crt"
    fi
}




function configure-services(){
    
    export CURRENT_NODE_HOSTNAME=${1:-}
    export MASTER_NODE_IP=${2:-}
    export CURRENT_NODE_IP=$(/sbin/ifconfig -a |grep eth0 -A 1|grep 'inet addr'|sed 's/\:/ /'|awk '{print $3}')
    
    
    
    sudo mkdir -p /etc/kubernetes
    sudo mkdir -p /var/lib/kubelet

    envsubst < ~/ha-kube/minion/environment/config.env | sudo tee /etc/kubernetes/config.env
    envsubst < ~/ha-kube/minion/environment/kubelet.env | sudo tee /etc/kubernetes/kubelet.env
    envsubst < ~/ha-kube/minion/environment/kube-proxy.env | sudo tee /etc/kubernetes/kube-proxy.env
    envsubst < ~/ha-kube/minion/environment/kubecfg.conf | sudo tee /etc/kubernetes/kubecfg.conf
    envsubst < ~/ha-kube/minion/environment/flanneld.env | sudo tee /etc/kubernetes/flanneld.env

    sudo cp ~/ha-kube/minion/environment/default.docker.template /etc/kubernetes/

    sudo cp ~/ha-kube/minion/systemd/* /etc/systemd/system/

    #create-flanneld-default 
    
    
    sudo systemctl enable kube-proxy.service
    sudo sudo systemctl reload-or-restart kube-proxy.service

    sudo systemctl enable flanneld.service
    sudo sudo systemctl reload-or-restart flanneld.service

    #sudo systemctl enable docker.service
    sudo sudo systemctl reload-or-restart docker.service

    sudo systemctl enable kubelet.service
    sudo sudo systemctl reload-or-restart kubelet.service
}



#${1}- Worker Hostname
#${2}- Master IP Address
function deploy-minion(){
    host_name=${1:-}
    master_node_ip=${2:-}
    source $CONFIG_PATH
    echo "Installing docker on ${host_name}"
    sudo chmod +x ~/ha-kube/minion/docker-setup.sh
    sudo ~/ha-kube/minion/docker-setup.sh

    
    copy-binaries
    
    configure-certs "$host_name"
    
    configure-services "$host_name" "$master_node_ip"

}

if [ "$mode" == "deploy-minion" ]; then
    shift
    deploy-minion "$1" "$2"
fi