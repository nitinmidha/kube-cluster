#!/bin/bash
BASE_DIR=${1:-}
WORK_DIR=${2:-}
CONFIG_PATH=${3:-}

KUBECTL="$WORK_DIR/binaries/kubectl"

source "$CONFIG_PATH"

mkdir -p "$WORK_DIR/addons"

function configure-kubectl(){
    master_node="${MASTER_NODES[0]}"
    master_host_name="$(echo $master_node | awk -F @ '{print $2}' )"

    if [ -z "$CLUSTER_DNS_EXTERNAL" ]; then
        server_address=$master_host_name
    else
        server_address=$CLUSTER_DNS_EXTERNAL
    fi
    admin_token=$(cat $WORK_DIR/token.csv | grep admin | awk -F , '{print $1}')
    "$KUBECTL" config set-cluster "$CLUSTER_NAME-cluster" \
        --server=https://$server_address \
        --certificate-authority="$WORK_DIR/certs/ca.crt"
    "$KUBECTL" config set-credentials "$CLUSTER_NAME-admin-user" --token=$admin_token
    "$KUBECTL" config set-context "$CLUSTER_NAME-context" --user="$CLUSTER_NAME-admin-user" \
        --cluster="$CLUSTER_NAME-cluster"
    "$KUBECTL" config use-context "$CLUSTER_NAME-context"
}


function deploy_dns {
  echo "Deploying DNS on Kubernetes"
  sed -e "s/\\\$DNS_REPLICAS/${DNS_REPLICAS}/g;s/\\\$DNS_DOMAIN/${DNS_DOMAIN}/g;" "$BASE_DIR/addons/skydns-rc.yaml.sed" > $WORK_DIR/addons/skydns-rc.yaml
  sed -e "s/\\\$DNS_SERVER_IP/${DNS_SERVER_IP}/g" "$BASE_DIR/addons/skydns-svc.yaml.sed" > $WORK_DIR/addons/skydns-svc.yaml

  KUBEDNS=`eval "${KUBECTL} get services --namespace=kube-system | grep kube-dns | cat"`
      
  if [ ! "$KUBEDNS" ]; then
    # use kubectl to create skydns rc and service
    ${KUBECTL} --namespace=kube-system create -f $WORK_DIR/addons/skydns-rc.yaml 
    ${KUBECTL} --namespace=kube-system create -f $WORK_DIR/addons/skydns-svc.yaml

    echo "Kube-dns rc and service is successfully deployed."
  else
    echo "Kube-dns rc and service is already deployed. Skipping."
  fi
}


function deploy_dashboard {
    if ${KUBECTL} get rc -l k8s-app=kubernetes-dashboard --namespace=kube-system | grep kubernetes-dashboard-v &> /dev/null; then
        echo "Kubernetes Dashboard replicationController already exists"
    else
        master_node="${MASTER_NODES[0]}"
        MASTER_NODE_IP=$(ssh $SSH_OPTS "$master_node" \
            "/sbin/ifconfig -a |grep eth0 -A 1|grep 'inet addr'|sed 's/\:/ /'|awk"' '"'"'{print $3}'"'"'')
        echo "Creating Kubernetes Dashboard replicationController"


        DASHBOARD_TOKEN=$(cat $WORK_DIR/token.csv | grep admin | awk -F , '{print $1}')

        sed -e "s/\\\$MASTER_NODE_IP/${MASTER_NODE_IP}/g;s/\\\$DASHBOARD_TOKEN/${DASHBOARD_TOKEN}/g" "$BASE_DIR/addons/kubecfg.conf.sed" > $WORK_DIR/addons/kubecfg.conf

        ${KUBECTL} delete secret dashboard-config --namespace=kube-system

        ${KUBECTL} create secret generic dashboard-config \
            --from-file=$WORK_DIR/addons/kubecfg.conf \
            --from-file=$WORK_DIR/certs/ca.crt \
            --namespace=kube-system

        sed -e "s/\\\$MASTER_NODE_IP/${MASTER_NODE_IP}/g" "$BASE_DIR/addons/dashboard-controller.yaml.sed" > $WORK_DIR/addons/dashboard-controller.yaml
        ${KUBECTL} create -f $WORK_DIR/addons/dashboard-controller.yaml
    fi

    if ${KUBECTL} get service/kubernetes-dashboard --namespace=kube-system &> /dev/null; then
        echo "Kubernetes Dashboard service already exists"
    else
        echo "Creating Kubernetes Dashboard service"
        ${KUBECTL} create -f $BASE_DIR/addons/dashboard-service.yaml
    fi
}




echo "Configuring Kubectl"
configure-kubectl
${KUBECTL} delete -f $WORK_DIR/addons
echo "deploying dns"
deploy_dns
echo "dns deployment completed"
echo "deplying dashboard"
deploy_dashboard
echo "dashboard deployment completed"


    