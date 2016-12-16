#!/bin/bash
BASE_DIR=${1:-}
WORK_DIR=${2:-}
CONFIG_PATH=${3:-}

KUBECTL="$WORK_DIR/binaries/kubectl"

source "$CONFIG_PATH"


mkdir -p "$WORK_DIR/addons"

function configure-kubectl(){
    
    index=0
    for node in "${NODES[@]}"; do
        role="${NODE_ROLES[$index]}"
        if [ "$role" = "MO" ] || [ "$role" = "MW" ]; then
            node_host_name="$(echo $node | awk -F @ '{print $2}' )"
            break
        fi
        ((index=index+1))
    done
    
    if [ -z "$CLUSTER_DNS_EXTERNAL" ]; then
        server_address=$node_host_name
    else
        server_address=$CLUSTER_DNS_EXTERNAL
    fi
    admin_token=$(cat $WORK_DIR/token.csv | grep admin | awk -F , '{print $1}')
    "$KUBECTL" config set-cluster "$CLUSTER_NAME-cluster" \
        --server=https://$server_address \
        --certificate-authority="$WORK_DIR/certs/ca.crt"
    "$KUBECTL" config set-credentials "$CLUSTER_NAME-admin-user" --token=$admin_token
    "$KUBECTL" config set-context "$KUBECTL_CONTEXT" --user="$CLUSTER_NAME-admin-user" \
        --cluster="$CLUSTER_NAME-cluster"
    #"$KUBECTL" config use-context "$CLUSTER_NAME-context"
}


function deploy_dns {
  echo "Deploying DNS on Kubernetes"
  sed -e "s/\\\$DNS_REPLICAS/${DNS_REPLICAS}/g;s/\\\$DNS_DOMAIN/${DNS_DOMAIN}/g;" "$BASE_DIR/addons/kubedns-controller.yaml.sed" > $WORK_DIR/addons/kubedns-controller.yaml
  sed -e "s/\\\$DNS_SERVER_IP/${DNS_SERVER_IP}/g" "$BASE_DIR/addons/kubedns-service.yaml.sed" > $WORK_DIR/addons/kubedns-service.yaml

  KUBEDNS=`eval "${KUBECTL} --context "$KUBECTL_CONTEXT" get services --namespace=kube-system | grep kube-dns | cat"`
      
  if [ ! "$KUBEDNS" ]; then
    # use kubectl to create skydns rc and service
    ${KUBECTL} --context "$KUBECTL_CONTEXT" --namespace=kube-system create -f $WORK_DIR/addons/kubedns-controller.yaml 
    ${KUBECTL} --context "$KUBECTL_CONTEXT" --namespace=kube-system create -f $WORK_DIR/addons/kubedns-service.yaml

    echo "Kube-dns rc and service is successfully deployed."
  else
    echo "Kube-dns rc and service is already deployed. Skipping."
  fi
}


function deploy_dashboard {
    if ${KUBECTL} --context "$KUBECTL_CONTEXT" get rc -l k8s-app=kubernetes-dashboard --namespace=kube-system | grep kubernetes-dashboard-v &> /dev/null; then
        echo "Kubernetes Dashboard replicationController already exists"
    else
        ${KUBECTL} --context "$KUBECTL_CONTEXT" create -f $BASE_DIR/addons/dashboard-controller.yaml
    fi

    if ${KUBECTL} --context "$KUBECTL_CONTEXT" get service/kubernetes-dashboard --namespace=kube-system &> /dev/null; then
        echo "Kubernetes Dashboard service already exists"
    else
        echo "Creating Kubernetes Dashboard service"
        ${KUBECTL} --context "$KUBECTL_CONTEXT" create -f $BASE_DIR/addons/dashboard-service.yaml
    fi
}




echo "Configuring Kubectl"
configure-kubectl
echo "deploying dns"
deploy_dns
echo "dns deployment completed"
echo "deploying dashboard"
deploy_dashboard
echo "dashboard deployment completed"


    