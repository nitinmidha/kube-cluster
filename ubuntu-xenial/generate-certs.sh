#!/bin/bash
BASE_DIR=${1:-}
WORK_DIR=${2:-}
CONFIG_PATH=${3:-}

GET_NODE_IP="ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print "'$2'"}' | cut -f1  -d'/'"

source "$CONFIG_PATH"

declare -a EXTRA_SANS
declare -a MASTER_NODE_IPS
declare -a MASTER_NODE_HOSTNAMES

declare -a WORKER_NODE_IPS
declare -a WORKER_NODE_HOSTNAMES

CERT_TMP_DIR="$WORK_DIR/certs"

mkdir -p "$CERT_TMP_DIR"

# $1 Node
# $2 Role
function generate-cert(){
    node=${1:-}
    role=${2:-}
    node_hostname="$(echo $node | awk -F @ '{print $2}' )"
    node_ip=$(ssh $SSH_OPTS "$node" "$GET_NODE_IP")
    key_file="$CERT_TMP_DIR/${node_hostname}.key"
    if [ -f "${key_file}" ]; then
        echo "Key file for master:$node_hostname already exists. Skipping Cert generation."
    else
        if [ "$role" = "MO" ] || [ "$role" = "MW" ]; then
            EXTRA_SANS=(
                IP.0=${node_ip}
                IP.1=${SERVICE_CLUSTER_IP_RANGE%.*}.1
                IP.2=127.0.0.1
                DNS.1=kubernetes
                DNS.2=kubernetes.default
                DNS.3=kubernetes.default.svc
                DNS.4=kubernetes.default.svc.cluster.local
                DNS.5=localhost
                DNS.6=$node_hostname
            )
            if [[ ! -z "$CLUSTER_DNS_EXTERNAL" ]]; then
                EXTRA_SANS=("${EXTRA_SANS[@]}" "DNS.7=$CLUSTER_DNS_EXTERNAL")
            fi

                
        else
            EXTRA_SANS=(
                IP.0=${node_ip}
                DNS.1=localhost
                DNS.2=$node_hostname
            )
        fi

        export EXTRA_SANS_STRING=$(printf -- '%s\n' "${EXTRA_SANS[@]}")

        envsubst < "$BASE_DIR/ubuntu-xenial/certs/openssl-altname.template.conf" > "$CERT_TMP_DIR/openssl-altname.conf"

        openssl genrsa -out "${key_file}" 2048
        openssl req -new -key "${key_file}" \
            -out "$CERT_TMP_DIR/${node_hostname}.csr" \
            -subj "/CN=${node_hostname}" \
            -config "$CERT_TMP_DIR/openssl-altname.conf"
        openssl x509 -req -in "$CERT_TMP_DIR/${node_hostname}.csr" \
            -CA "$CA_CRT_FILE" \
            -CAkey "$CA_KEY_FILE" \
            -CAcreateserial \
            -out "$CERT_TMP_DIR/${node_hostname}.crt" \
            -days 365 \
            -extensions v3_req \
            -extfile "$CERT_TMP_DIR/openssl-altname.conf"

    fi
}
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

# Generate Node Certificattes
index=0
for node in "${NODES[@]}"; do
    role="${NODE_ROLES[$index]}"
    generate-cert "$node" "$role"
    ((index=index+1))
done
