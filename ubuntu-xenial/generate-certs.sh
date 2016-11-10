#!/bin/bash
BASE_DIR=${1:-}
WORK_DIR=${2:-}
CONFIG_PATH=${3:-}

source "$CONFIG_PATH"

declare -a EXTRA_SANS
declare -a MASTER_NODE_IPS
declare -a MASTER_NODE_HOSTNAMES

declare -a WORKER_NODE_IPS
declare -a WORKER_NODE_HOSTNAMES

CERT_TMP_DIR="$WORK_DIR/certs"

mkdir -p "$CERT_TMP_DIR"

# Generate CA cert if it does not exists ...

CA_KEY_FILE="$CERT_TMP_DIR/ca.key"
CA_CRT_FILE="$CERT_TMP_DIR/ca.crt"
if [ -f "$CA_KEY_FILE" ]; then
    echo "CA Key exists. Skipping CA cert generation"
else
    echo "CA Key does not exists, generating a new one."
    openssl genrsa -out "$CA_KEY_FILE" 2048
    openssl req -x509 -new -nodes -key "$CA_KEY_FILE" -days 10000 -out "$CA_CRT_FILE" -subj "/CN=kube-ca"    
fi

# Generate Master Node Certificattes

for master_node in "${MASTER_NODES[@]}"; do
    master_host_name="$(echo $master_node | awk -F @ '{print $2}' )"
    MASTER_NODE_HOSTNAMES=("$MASTER_NODE_HOSTNAMES{@}" "${master_host_name}")
    master_node_ip=$(ssh $SSH_OPTS "$master_node" \
            "/sbin/ifconfig -a |grep eth0 -A 1|grep 'inet addr'|sed 's/\:/ /'|awk"' '"'"'{print $3}'"'"'')
    
    MASTER_NODE_IPS=("$MASTER_NODE_IPS{@}" "${master_node_ip}")
    
    key_file="$CERT_TMP_DIR/${master_host_name}-server.key"
    if [ -f "${key_file}" ]; then
        echo "Key file for master:$master_host_name already exists. Skipping Cert generation."
    else

        if [ -z "$CLUSTER_DNS_EXTERNAL" ]; then
            server_address=$master_host_name
        else
            server_address=$CLUSTER_DNS_EXTERNAL
        fi

        EXTRA_SANS=(
            IP.0=${master_node_ip}
            IP.1=${SERVICE_CLUSTER_IP_RANGE%.*}.1
            IP.2=127.0.0.1
            DNS.1=${server_address}
            DNS.2=kubernetes
            DNS.3=kubernetes.default
            DNS.4=kubernetes.default.svc
            DNS.5=kubernetes.default.svc.cluster.local
            DNS.6=localhost
        )

        export EXTRA_SANS_STRING=$(printf -- '%s\n' "${EXTRA_SANS[@]}")

        envsubst < "$BASE_DIR/ubuntu-xenial/certs/openssl-altname.template.conf" > "$CERT_TMP_DIR/openssl-altname.conf"

        openssl genrsa -out "${key_file}" 2048
        openssl req -new -key "${key_file}" -out "$CERT_TMP_DIR/${master_host_name}-server.csr" -subj "/CN=${master_host_name}" -config "$CERT_TMP_DIR/openssl-altname.conf"
        openssl x509 -req -in "$CERT_TMP_DIR/${master_host_name}-server.csr" -CA "$CA_CRT_FILE" -CAkey "$CA_KEY_FILE" -CAcreateserial -out "$CERT_TMP_DIR/${master_host_name}-server.crt" -days 365 -extensions v3_req -extfile "$CERT_TMP_DIR/openssl-altname.conf"

    fi
done


# Generate Minion Node  Certificattes

for worker_node in "${WORKER_NODES[@]}"; do
    worker_host_name="$(echo $worker_node | awk -F @ '{print $2}' )"
    WORKER_NODE_HOSTNAMES=("$WORKER_NODE_HOSTNAMES{@}" "${worker_host_name}")
    worker_node_ip=$(ssh $SSH_OPTS "$worker_node" \
            "/sbin/ifconfig -a |grep eth0 -A 1|grep 'inet addr'|sed 's/\:/ /'|awk"' '"'"'{print $3}'"'"'')
    
    WORKER_NODE_IPS=("$WORKER_NODE_IPS{@}" "${worker_node_ip}")
    
    key_file="$CERT_TMP_DIR/${worker_host_name}-node.key"
    if [ -f "${key_file}" ]; then
        echo "Key file for node:$worker_host_name already exists. Skipping Cert generation."
    else
        EXTRA_SANS=(
            IP.0=${worker_node_ip}
            DNS.1=localhost
        )

        export EXTRA_SANS_STRING=$(printf -- '%s\n' "${EXTRA_SANS[@]}")

        envsubst < "$BASE_DIR/ubuntu-xenial/certs/openssl-altname.template.conf" > "$CERT_TMP_DIR/openssl-altname.conf"

        openssl genrsa -out "${key_file}" 2048
        openssl req -new -key "${key_file}" -out "$CERT_TMP_DIR/${worker_host_name}-node.csr" -subj "/CN=${worker_host_name}" -config "$CERT_TMP_DIR/openssl-altname.conf"
        openssl x509 -req -in "$CERT_TMP_DIR/${worker_host_name}-node.csr" -CA "$CA_CRT_FILE" -CAkey "$CA_KEY_FILE" -CAcreateserial -out "$CERT_TMP_DIR/${worker_host_name}-node.crt" -days 365 -extensions v3_req -extfile "$CERT_TMP_DIR/openssl-altname.conf"

    fi
done
