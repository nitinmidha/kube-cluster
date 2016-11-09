#!/bin/bash
CONFIG_PATH=~/ha-kube/config-default.sh
mode=${1:-}



function copy-binaries(){
    # copy binaries
    sudo mkdir -p /opt/bin
    sudo cp ~/ha-kube/master/binaries/* /opt/bin/
}

function configure-certs(){
    # Configure Certs
    if [ "$GENERATE_CERTS" == "true" ]; then
        sudo groupadd -f -r "$CERT_GROUP"
        sudo mkdir -p "$CERT_DIR"
        sudo cp ~/ha-kube/master/certs/* "${CERT_DIR}/"
        sudo chgrp $CERT_GROUP "${CERT_DIR}/${1}-server.key" "${CERT_DIR}/${1}-server.crt" "${CERT_DIR}/ca.crt"
        sudo chmod 660 "${CERT_DIR}/${1}-server.key" "${CERT_DIR}/${1}-server.crt" "${CERT_DIR}/ca.crt"
    fi
}

function configure-services(){
    
    export CURRENT_NODE_HOSTNAME=${1:-}
    export ETCD_NODE_NAME=${2:-}
    export ETCD_CLUSTER_NAME=${3:-}
    export ETCD_INITIAL_CLUSTER=${4:-}
    export CURRENT_NODE_IP=$(/sbin/ifconfig -a |grep eth0 -A 1|grep 'inet addr'|sed 's/\:/ /'|awk '{print $3}')
    
    
    
    sudo mkdir -p /etc/kubernetes
    envsubst < ~/ha-kube/master/environment/etcd.env | sudo tee /etc/kubernetes/etcd.env
    envsubst < ~/ha-kube/master/environment/config.env | sudo tee /etc/kubernetes/config.env
    envsubst < ~/ha-kube/master/environment/kube-apiserver.env | sudo tee /etc/kubernetes/kube-apiserver.env
    envsubst < ~/ha-kube/master/environment/kube-controller-manager.env | sudo tee /etc/kubernetes/kube-controller-manager.env
    envsubst < ~/ha-kube/master/environment/kube-scheduler.env | sudo tee /etc/kubernetes/kube-scheduler.env
    envsubst < ~/ha-kube/master/environment/kubecfg.conf | sudo tee /etc/kubernetes/kubecfg.conf

    cat ~/ha-kube/master/environment/token.csv | sudo tee /etc/kubernetes/token.csv


    sudo cp ~/ha-kube/master/systemd/* /etc/systemd/system/

    
    
    sudo systemctl enable etcd.service
    sudo sudo systemctl reload-or-restart etcd.service
}

function config-etcd-flannel {
  host_name=${1:-}
  source $CONFIG_PATH
  echo "Configuring ETCD for Initial Flannel Net"
  attempt=0
  while true; do
      options=" --cert-file=$CERT_DIR/${host_name}-server.crt --key-file=$CERT_DIR/${host_name}-server.key --ca-file=$CERT_DIR/ca.crt --endpoints=https://localhost:2379 "
      response=$(sudo /opt/bin/etcdctl $options get /coreos.com/network/config)
      echo "Response from etcd is :$response"
      if [ -z "$response" ]; then
        # enough timeout??
        if (( attempt > 600 )); then
            echo "timeout waiting for /coreos.com/network/config" >> ~/ha-kube/err.log
            exit 2
        fi
        echo "Configuring etcd"
        sudo /opt/bin/etcdctl $options mk /coreos.com/network/config "{\"Network\":\"${FLANNEL_NET}\", \"Backend\": {\"Type\": \"vxlan\"}${FLANNEL_OTHER_NET_CONFIG}}"
        attempt=$((attempt+1))
        sleep 3
      else
        echo "Key Exists:$response"
        break
      fi
  done
}

function enable-kube-services(){
    sudo systemctl enable kube-apiserver.service
    sudo sudo systemctl reload-or-restart kube-apiserver.service

    sleep 30s

    sudo systemctl enable kube-controller-manager.service
    sudo sudo systemctl reload-or-restart kube-controller-manager.service

    sudo systemctl enable kube-scheduler
    sudo sudo systemctl reload-or-restart kube-scheduler
}

#hostname=${1:-}
#etcd_node_name=${2:-}
#etcd_cluster_name=${3:-}
#etcd_initial_cluster=${4:-}
function deploy-master(){
    host_name=${1:-}
    
    source $CONFIG_PATH
    
    copy-binaries
    
    configure-certs "$host_name"
    
    configure-services "$host_name" "$2" "$3" "$4"
}

if [ "$mode" == "deploy-master" ]; then
    shift
    deploy-master "$1" "$2" "$3" "$4"
elif [ "$mode" == "enable-kube-services" ]; then
    shift
    enable-kube-services
    config-etcd-flannel "$1"
fi