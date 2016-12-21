#!/bin/bash
BASE_DIR=${1:-}
WORK_DIR=${2:-}
CONFIG_PATH=${3:-}

source "$CONFIG_PATH"

function get-hostname(){
        host_name="$(ssh $SSH_OPTS "$1" hostname)"
        echo "$host_name"
}

GET_NODE_IP="ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print "'$2'"}' | cut -f1  -d'/'"

#"/sbin/ifconfig -a |grep eth0 -A 1|grep 'inet addr'|sed 's/\:/ /'|awk"' '"'"'{print $3}'"'"''

"$BASE_DIR/ubuntu-xenial/get-releases.sh" \
    "$BASE_DIR" \
    "$WORK_DIR" \
    "$CONFIG_PATH" \
    "$FLANNEL_VERSION" \
    "$ETCD_VERSION" \
    "$KUBE_VERSION" 
    

if [ "$GENERATE_CERTS" == "true" ]; then
    "$BASE_DIR/ubuntu-xenial/generate-certs.sh" \
        "$BASE_DIR" \
        "$WORK_DIR" \
        "$CONFIG_PATH"
fi

etcd_cluster_name="$CLUSTER_NAME-etcd"
etcd_initial_cluster=""
etcd_endpoints=""
api_server_ip=""
suffix=0
function create-etcd-initial-cluster-info(){
    index=0
    suffix=0
    for node in "${NODES[@]}"; do
        role="${NODE_ROLES[$index]}"
        if [ "$role" = "MO" ] || [ "$role" = "MW" ]; then
            node_name="infra""$suffix"
            node_ip=$(ssh $SSH_OPTS "$node" "$GET_NODE_IP")
            if [ -z "$etcd_initial_cluster" ]; then 
                etcd_initial_cluster="$node_name=https://$node_ip:2380"
                etcd_endpoints="https://$node_ip:2379"
            else
                etcd_initial_cluster="$etcd_initial_cluster"",$node_name=https://$node_ip:2380"
                etcd_endpoints="$etcd_endpoints"",https://$node_ip:2379"
            fi
            ((suffix=suffix+1))
        fi
        ((index=index+1))
    done
} 

function create-token-authentication-file(){
    # These credentials will be used by kubectl so as to connect to api server.
    token_file="$WORK_DIR/token.csv"
    user=admin
    admin_token=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
    echo "$admin_token,$user,$user" > "$token_file"
} 

# $1 :- Node
# $2:- ETCD Node Name
# $3:- ETCD Cluster Name
# $4:- ETCD Initial Cluster
function provision-etcd-node(){
    etcd_node=${1:-}
    etcd_node_name=${2:-}
    etcd_cluster_name=${3:-}
    etcd_initial_cluster=${4:-}
    etcd_node_host_name="$(get-hostname $etcd_node )"

    # stage files for scp
    rm -rf "$WORK_DIR/ha-kube"
    mkdir -p "$WORK_DIR/ha-kube"

    # Copy Config file
    cp "$CONFIG_PATH" "$WORK_DIR/ha-kube"

    # Copy master files
    cp -r "$BASE_DIR/ubuntu-xenial/etcd" "$WORK_DIR/ha-kube"

    # Create folder for binaries 
    mkdir -p  "$WORK_DIR/ha-kube/etcd/binaries"

    # Copy binaries
    cp "$WORK_DIR/binaries/etcd" "$WORK_DIR/binaries/etcdctl" \
        "$WORK_DIR/ha-kube/etcd/binaries/"

    # Create folder for certs 
    mkdir -p  "$WORK_DIR/ha-kube/certs"

    # Copy certs
    if [ "$GENERATE_CERTS" == "true" ]; then
        # Create folder for certs 
        mkdir -p  "$WORK_DIR/ha-kube/certs"
        cp "$WORK_DIR/certs/ca.crt" "$WORK_DIR/certs/${etcd_node_host_name}.crt" \
            "$WORK_DIR/certs/${etcd_node_host_name}.key" \
            "$WORK_DIR/ha-kube/certs"
    fi

    scp $SSH_OPTS -r "$WORK_DIR/ha-kube" "${etcd_node}:~/"

    #echo "$etcd_node_name" "$etcd_cluster_name" "$etcd_initial_cluster"
    ssh $SSH_OPTS -t "$etcd_node" "
        sudo chmod +x ~/ha-kube/etcd/deploy-etcd.sh 
        ~/ha-kube/etcd/deploy-etcd.sh deploy-etcd \
            $etcd_node_host_name \
            $etcd_node_name \
            $etcd_cluster_name \
            $etcd_initial_cluster
    "
}

function configure-etcd-auth(){
    file=$1
    if [ "$DEPLOY_ETCD" == "true" ]; then
        echo -e '\nETCD_AUTH_CERTS="--etcd-cafile=${CERT_DIR}/ca.crt \
                --etcd-certfile=${CERT_DIR}/${CURRENT_NODE_HOSTNAME}.crt \
                --etcd-keyfile=${CERT_DIR}/${CURRENT_NODE_HOSTNAME}.key"' >> "$file"
    else
        if [[ ! -z "$EXTERNAL_ETCD_CA_CERT" ]]; then
            etcd_cert_auth=" --etcd-cafile=${EXTERNAL_ETCD_CA_CERT}"
        fi
        if [[ ! -z "$EXTERNAL_ETCD_CLIENT_CERT" ]]; then
            etcd_cert_auth=$etcd_cert_auth" --etcd-certfile=${EXTERNAL_ETCD_CLIENT_CERT}"
        fi
        if [[ ! -z "$EXTERNAL_ETCD_CLIENT_KEY" ]]; then
            etcd_cert_auth=$etcd_cert_auth" --etcd-keyfile=${EXTERNAL_ETCD_CLIENT_KEY}"
        fi
        echo -e '\nETCD_AUTH_CERTS="'"$etcd_cert_auth"'"' >> "$file"
    fi
}

# $1:- Node
# $2:- Role
function provision-node(){
    node="${1:-}"
    role="${2:-}"
    api_server_ip_for_node="${3:-}"
    etcd_end_points="${4:-}"
    configure_etcd_flannel="${5:-}"

    node_host_name="$(get-hostname $node )"
    # stage files for scp
    rm -rf "$WORK_DIR/ha-kube"
    mkdir -p "$WORK_DIR/ha-kube"
    mkdir -p  "$WORK_DIR/ha-kube/node/binaries"
    # Copy Config file
    cp "$CONFIG_PATH" "$WORK_DIR/ha-kube"

    # Copy master files
    cp -r $BASE_DIR/ubuntu-xenial/common/* "$WORK_DIR/ha-kube/node/"

    if [ "$role" == "MO" ] || [ "$role" == "MW" ]; then
        cp -r $BASE_DIR/ubuntu-xenial/master/* "$WORK_DIR/ha-kube/node/"

        configure-etcd-auth "$WORK_DIR/ha-kube/node/environment/kube-apiserver.env"

        cp "$WORK_DIR/token.csv" "$WORK_DIR/ha-kube/node/environment/"

        # Copy binaries
        cp "$WORK_DIR/binaries/kube-apiserver" "$WORK_DIR/binaries/kube-controller-manager" \
            "$WORK_DIR/binaries/kube-scheduler" \
            "$WORK_DIR/ha-kube/node/binaries/"
    fi
    
    if [ "$role" == "WO" ] || [ "$role" == "MW" ]; then
        cp -r $BASE_DIR/ubuntu-xenial/minion/* "$WORK_DIR/ha-kube/node/"

        configure-etcd-auth "$WORK_DIR/ha-kube/node/environment/flanneld.env"

        # Copy binaries
        cp "$WORK_DIR/binaries/kube-proxy" "$WORK_DIR/binaries/kubelet" \
            "$WORK_DIR/binaries/flanneld" \
            "$WORK_DIR/ha-kube/node/binaries/"
    fi

    if [ "$role" == "MW" ]; then
        cp -r $BASE_DIR/ubuntu-xenial/master-minion/* "$WORK_DIR/ha-kube/node/"
    fi

    # Copy certs
    if [ "$GENERATE_CERTS" == "true" ]; then
        mkdir -p $WORK_DIR/ha-kube/certs
        cp "$WORK_DIR/certs/ca.crt" "$WORK_DIR/certs/${node_host_name}.crt" \
            "$WORK_DIR/certs/${node_host_name}.key" \
            "$WORK_DIR/ha-kube/certs"
    fi
    
    scp $SSH_OPTS -r "$WORK_DIR/ha-kube" "${node}:~/"

    #echo "$etcd_node_name" "$etcd_cluster_name" "$etcd_initial_cluster"
    ssh $SSH_OPTS -t "$node" "
        sudo chmod +x ~/ha-kube/node/deploy-node.sh 
        ~/ha-kube/node/deploy-node.sh deploy-node \
            $node_host_name \
            $role \
            $api_server_ip_for_node \
            $etcd_end_points \
            $configure_etcd_flannel
    "
}

function provision-etcd-nodes(){
    index=0
    suffix=0
    for node in "${NODES[@]}"; do
        role="${NODE_ROLES[$index]}"
        if [ "$role" = "MO" ] || [ "$role" = "MW" ]; then
            node_name="infra""$suffix"
            provision-etcd-node "$node" "$node_name" "$etcd_cluster_name" "$etcd_initial_cluster"
            ((suffix=suffix+1))
        fi
        ((index=index+1))
    done
}

function provision-nodes(){
    index=0
    for node in "${NODES[@]}"; do
        role="${NODE_ROLES[$index]}"
        if [ "$role" == "MO" ] || [ "$role" == "MW" ]; then
            node_ip=$(ssh $SSH_OPTS "$node" "$GET_NODE_IP")
            api_server_ip="$node_ip"
            break
        fi 
        ((index=index+1))
    done

    index=0
    for node in "${NODES[@]}"; do
        role="${NODE_ROLES[$index]}"

        if [ "$index" == 0 ]; then
            configure_etcd_flannel="true"
        else
            configure_etcd_flannel="false"
        fi

        # If we are provisioning Master Only or Master Worker, then we can use 127.0.0.1 as api_server_ip
        if [ "$role" == "MO" ] || [ "$role" == "MW" ]; then
            api_server_ip_for_node="127.0.0.1"
            # If provisioning master, we can use local etcd deployment ....
            if [ "$DEPLOY_ETCD" == "true" ]; then
                etcd_endpoints_for_node="https://127.0.0.1:2379"
            else
                etcd_endpoints_for_node=$etcd_endpoints
            fi
        else
            api_server_ip_for_node=$api_server_ip
            etcd_endpoints_for_node=$etcd_endpoints
        fi

        provision-node "$node" "$role" "$api_server_ip_for_node" "$etcd_endpoints_for_node" "$configure_etcd_flannel"
        ((index=index+1))
    done
}

create-token-authentication-file
if [ "$DEPLOY_ETCD" == "true" ]; then
    create-etcd-initial-cluster-info
    provision-etcd-nodes
    echo "Sleeping 120s allowing etcd cluster to boot up"
    sleep 120s
else
    etcd_endpoints=${EXTERNAL_ETCD_ENDPOINTS}
fi
provision-nodes




