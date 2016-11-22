#!/bin/bash
MODE="${1:-}"
CONFIG_PATH=~/ha-kube/config-default.sh

function configure-etcd-flannel(){
  host_name=${1:-}
  etcd_end_points=${2:-}
  url=$(echo $etcd_end_points | awk -F , '{print $1}' )
  echo "Configuring ETCD for Initial Flannel Net. URL: $url"
  attempt=0
  while true; do
      options=" --cert $CERT_DIR/${host_name}.crt \
                --key $CERT_DIR/${host_name}.key \
                --cacert $CERT_DIR/ca.crt"
      response=$(sudo curl -is $options \
                    $url/v2/keys/coreos.com/network/config | \
                    head -n 1 | \
                    grep -c 200)
      echo "Key count from etcd is :$response"
      if [ "$response" == 0 ]; then
        # enough timeout??
        if (( attempt > 600 )); then
            echo "timeout waiting for /coreos.com/network/config" >> ~/ha-kube/err.log
            exit 2
        fi
        echo "Configuring etcd"
        echo "sudo curl $url/v2/keys/coreos.com/network/config \
            $options  \
            -XPUT -d \
            value=""{\"Network\":\"${FLANNEL_NET}\", \"Backend\": {\"Type\": \"vxlan\"}${FLANNEL_OTHER_NET_CONFIG}}"
        sudo curl $url/v2/keys/coreos.com/network/config \
            $options  \
            -XPUT -d \
            value="{\"Network\":\"${FLANNEL_NET}\", \"Backend\": {\"Type\": \"vxlan\"}${FLANNEL_OTHER_NET_CONFIG}}"
        attempt=$((attempt+1))
        sleep 3
      else
        echo "Key Exists. Count is:$response"
        break
      fi
  done
}

function copy-binaries(){
    # copy binaries
    sudo mkdir -p /opt/bin
    sudo cp ~/ha-kube/node/binaries/* /opt/bin/
}

function configure-certs(){
    # Configure Certs
    if [ "$GENERATE_CERTS" == "true" ]; then
        #sudo groupadd -f -r "$CERT_GROUP"
        sudo mkdir -p "$CERT_DIR"
        sudo cp ~/ha-kube/certs/* "${CERT_DIR}/"
        #sudo chgrp $CERT_GROUP "${CERT_DIR}/${1}-server.key" "${CERT_DIR}/${1}-server.crt" "${CERT_DIR}/ca.crt"
        sudo chmod 660 "${CERT_DIR}/${1}.key" "${CERT_DIR}/${1}.crt" "${CERT_DIR}/ca.crt"
    fi
}

function enable-kube-services(){
    ROLE=${1:-}
    if [ "$ROLE" == "MO" ] || [ "$ROLE" == "MW" ]; then
        sudo systemctl enable kube-apiserver.service
        sudo sudo systemctl reload-or-restart kube-apiserver.service

        sleep 30s

        sudo systemctl enable kube-controller-manager.service
        sudo sudo systemctl reload-or-restart kube-controller-manager.service

        sudo systemctl enable kube-scheduler
        sudo sudo systemctl reload-or-restart kube-scheduler
    fi

    if [ "$ROLE" == "WO" ] || [ "$ROLE" == "MW" ]; then
        sudo systemctl enable kube-proxy.service
        sudo sudo systemctl reload-or-restart kube-proxy.service

        sudo systemctl enable flanneld.service
        sudo sudo systemctl reload-or-restart flanneld.service

        #sudo systemctl enable docker.service
        sudo sudo systemctl reload-or-restart docker.service

        sudo systemctl enable kubelet.service
        sudo sudo systemctl reload-or-restart kubelet.service
    fi
}

function configure-services(){
    export CURRENT_NODE_HOSTNAME=${1:-}
    ROLE=${2:-}
    export API_SERVER_IP=${3:-}
    export ETCD_END_POINTS=${4:-}
    export CURRENT_NODE_IP=$(/sbin/ifconfig -a |grep eth0 -A 1|grep 'inet addr'|sed 's/\:/ /'|awk '{print $3}')
    
    sudo mkdir -p /etc/kubernetes

    if [ "$ROLE" == "WO" ] || [ "$ROLE" == "MW" ]; then
        sudo mkdir -p /var/lib/kubelet
        echo "Installing docker on ${host_name}"
        sudo chmod +x ~/ha-kube/node/docker-setup.sh
        sudo ~/ha-kube/node/docker-setup.sh
    fi

    envsubst < ~/ha-kube/node/environment/config.env | sudo tee /etc/kubernetes/config.env
    envsubst < ~/ha-kube/node/environment/kubecfg.conf | sudo tee /etc/kubernetes/kubecfg.conf
    
    if [ "$ROLE" == "MO" ] || [ "$ROLE" == "MW" ]; then 
        envsubst < ~/ha-kube/node/environment/kube-apiserver.env | sudo tee /etc/kubernetes/kube-apiserver.env
        envsubst < ~/ha-kube/node/environment/kube-controller-manager.env | sudo tee /etc/kubernetes/kube-controller-manager.env
        envsubst < ~/ha-kube/node/environment/kube-scheduler.env | sudo tee /etc/kubernetes/kube-scheduler.env
        
        cat ~/ha-kube/node/environment/token.csv | sudo tee /etc/kubernetes/token.csv
    fi
    
    if [ "$ROLE" == "WO" ] || [ "$ROLE" == "MW" ]; then
        envsubst < ~/ha-kube/node/environment/kubelet.env | sudo tee /etc/kubernetes/kubelet.env
        envsubst < ~/ha-kube/node/environment/kube-proxy.env | sudo tee /etc/kubernetes/kube-proxy.env
        envsubst < ~/ha-kube/node/environment/flanneld.env | sudo tee /etc/kubernetes/flanneld.env
        sudo cp ~/ha-kube/node/environment/default.docker.template /etc/kubernetes/
    fi

    sudo cp ~/ha-kube/node/systemd/* /etc/systemd/system/    

}

#NODE_HOST_NAME="${1:-}"
#ROLE="${2:-}"
#API_SERVER_IP="${3:-}"
#ETCD_END_POINTS="${4:-}"
#CONFIGURE_ETCD_FLANNEL="${5:-}"
function deploy-node(){
    echo "${@}"
    NODE_HOST_NAME="${1:-}"
    ROLE="${2:-}"
    API_SERVER_IP="${3:-}"
    ETCD_END_POINTS="${4:-}"
    CONFIGURE_ETCD_FLANNEL="${5:-}"
    source $CONFIG_PATH

    if [ "$CONFIGURE_ETCD_FLANNEL" == "true" ]; then
        configure-etcd-flannel "$NODE_HOST_NAME" "$ETCD_END_POINTS"
    fi

    copy-binaries
    configure-certs "$NODE_HOST_NAME"
    configure-services "$NODE_HOST_NAME" "$ROLE" "$API_SERVER_IP" "$ETCD_END_POINTS"
    enable-kube-services "$ROLE"
}


if [ "$MODE" == "deploy-node" ]; then
    shift
    deploy-node "${@}"
fi