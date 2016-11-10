#!/bin/bash
BASE_DIR=${1:-}
WORK_DIR=${2:-}
CONFIG_PATH=${3:-}

source "$CONFIG_PATH"

"$BASE_DIR/ubuntu-xenial/get-releases.sh" \
    "$BASE_DIR" \
    "$WORK_DIR" \
    "$CONFIG_PATH" \
    "$KUBE_VERSION" \
    "$FLANNEL_VERSION" \
    "$ETCD_VERSION"

if [ "$GENERATE_CERTS" == "true" ]; then
    "$BASE_DIR/ubuntu-xenial/generate-certs.sh" \
        "$BASE_DIR" \
        "$WORK_DIR" \
        "$CONFIG_PATH"
fi


#1 : master_node
function provision-master(){
    master_node=${1:-}
    etcd_node_name=${2:-}
    etcd_cluster_name=${3:-}
    etcd_initial_cluster=${4:-}
    master_host_name="$(echo $master_node | awk -F @ '{print $2}' )"

    # stage files for scp
    rm -rf "$WORK_DIR/ha-kube"
    mkdir -p "$WORK_DIR/ha-kube"

    # Copy Config file
    cp "$CONFIG_PATH" "$WORK_DIR/ha-kube"

    # Copy master files
    cp -r "$BASE_DIR/ubuntu-xenial/master" "$WORK_DIR/ha-kube"

    # Create folder for binaries 
    mkdir -p  "$WORK_DIR/ha-kube/master/binaries"

    # Copy binaries
    cp "$WORK_DIR/binaries/etcd" "$WORK_DIR/binaries/etcdctl" \
        "$WORK_DIR/binaries/kube-apiserver" "$WORK_DIR/binaries/kube-controller-manager" \
        "$WORK_DIR/binaries/kube-scheduler" \
        "$WORK_DIR/ha-kube/master/binaries"

    # Create folder for certs 
    mkdir -p  "$WORK_DIR/ha-kube/master/certs"

    # Copy certs

    cp "$WORK_DIR/certs/ca.crt" "$WORK_DIR/certs/${master_host_name}-server.crt" \
        "$WORK_DIR/certs/${master_host_name}-server.key" \
        "$WORK_DIR/ha-kube/master/certs"

    # Copy Token files
    cp "$WORK_DIR/token.csv" "$WORK_DIR/ha-kube/master/environment"

    scp $SSH_OPTS -r "$WORK_DIR/ha-kube" "${master_node}:~/"

    #echo "$etcd_node_name" "$etcd_cluster_name" "$etcd_initial_cluster"
    ssh $SSH_OPTS -t "$master_node" "
        sudo chmod +x ~/ha-kube/master/deploy-master.sh 
        ~/ha-kube/master/deploy-master.sh deploy-master $master_host_name $etcd_node_name $etcd_cluster_name $etcd_initial_cluster
    "
}


#1 : master_node
function provision-minion(){
    worker_node=${1:-}
    master_node_ip=${2:-}
    worker_host_name="$(echo $worker_node | awk -F @ '{print $2}' )"

    # stage files for scp
    rm -rf "$WORK_DIR/ha-kube"
    mkdir -p "$WORK_DIR/ha-kube"

    # Copy Config file
    cp "$CONFIG_PATH" "$WORK_DIR/ha-kube"

    # Copy master files
    cp -r "$BASE_DIR/ubuntu-xenial/minion" "$WORK_DIR/ha-kube"

    # Create folder for binaries 
    mkdir -p  "$WORK_DIR/ha-kube/minion/binaries"

    # Copy binaries
    cp "$WORK_DIR/binaries/flanneld" \
        "$WORK_DIR/binaries/kubelet" \
        "$WORK_DIR/binaries/kube-proxy" \
        "$WORK_DIR/ha-kube/minion/binaries"
    
    # Create folder for certs 
    mkdir -p  "$WORK_DIR/ha-kube/minion/certs"

    # Copy certs

    cp "$WORK_DIR/certs/ca.crt" "$WORK_DIR/certs/${worker_host_name}-node.crt" \
        "$WORK_DIR/certs/${worker_host_name}-node.key" \
        "$WORK_DIR/ha-kube/minion/certs"
    
    scp $SSH_OPTS -r "$WORK_DIR/ha-kube" "${worker_node}:~/"

    #echo "$etcd_node_name" "$etcd_cluster_name" "$etcd_initial_cluster"
    ssh $SSH_OPTS -t "$worker_node" "
        sudo chmod +x ~/ha-kube/minion/deploy-minion.sh 
        ~/ha-kube/minion/deploy-minion.sh deploy-minion $worker_host_name $master_node_ip
    "
}

etcd_cluster_name="$CLUSTER_NAME-etcd"
etcd_initial_cluster=""
default_master_node_ip=""
suffix=0
function create-etcd-initial-cluster-info(){
    for master_node in "${MASTER_NODES[@]}"; do
        node_name="infra""$suffix"
        master_node_ip=$(ssh $SSH_OPTS "$master_node" \
            "/sbin/ifconfig -a |grep eth0 -A 1|grep 'inet addr'|sed 's/\:/ /'|awk"' '"'"'{print $3}'"'"'')
        if [ -z "$etcd_initial_cluster" ]; then 
            etcd_initial_cluster="$node_name=https://$master_node_ip:2380"
            default_master_node_ip=$master_node_ip
        else
            etcd_initial_cluster="$etcd_initial_cluster"",$node_name=https://$master_node_ip:2380"
        fi
        ((suffix=suffix+1))
    done
} 

function provision-master-nodes(){
    suffix=0
    # Provision and Deploy Masters
    for master_node in "${MASTER_NODES[@]}"; do
        node_name="infra""$suffix"
        provision-master "$master_node" "$node_name" "$etcd_cluster_name" "$etcd_initial_cluster"
        ((suffix=suffix+1))
    done
    echo "Sleeping 120s allowing etcd cluster to boot up"
    sleep 30s
    for master_node in "${MASTER_NODES[@]}"; do
        master_host_name="$(echo $master_node | awk -F @ '{print $2}' )"
        ssh $SSH_OPTS -t "$master_node" "
        sudo chmod +x ~/ha-kube/master/deploy-master.sh 
        ~/ha-kube/master/deploy-master.sh enable-kube-services $master_host_name
    "
    done
}


function privision-minion-nodes(){
    # Provision and Deploy Workers
    for worker_node in "${WORKER_NODES[@]}"; do
        provision-minion "$worker_node" "$default_master_node_ip"
    done
}


function create-token-authentication-file(){
    # These credentials will be used by kubectl so as to connect to api server.
    token_file="$WORK_DIR/token.csv"
    user=admin
    admin_token=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
    echo "$admin_token,$user,$user" > "$token_file"
} 

create-token-authentication-file
create-etcd-initial-cluster-info
provision-master-nodes
privision-minion-nodes






