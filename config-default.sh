export CLUSTER_NAME="kubetestcluster"
export MASTER_NODES=("testuser@kubmaster1" "testuser@kubmaster2" "testuser@kubmaster3")
export WORKER_NODES=("testuser@kubminion1" "testuser@kubminion2" )
export DNS_SERVER_IP=${DNS_SERVER_IP:-"192.168.3.10"}
export DNS_DOMAIN=${DNS_DOMAIN:-"cluster.local"}
export ADMISSION_CONTROL=NamespaceLifecycle,LimitRanger,ServiceAccount,SecurityContextDeny,DefaultStorageClass,ResourceQuota
export SERVICE_CLUSTER_IP_RANGE=${SERVICE_CLUSTER_IP_RANGE:-192.168.3.0/24}
export SERVICE_NODE_PORT_RANGE=${SERVICE_NODE_PORT_RANGE:-"1-32767"}
export CERT_DIR=${CERT_DIR:-/etc/kubernetes/pki}
export CERT_GROUP=${CERT_GROUP:-kube-cert}
export FLANNEL_NET=${FLANNEL_NET:-172.16.0.0/16}
export MASTER_NODE_IP="${MASTER_NODE_IP:-}"
export CLUSTER_DNS_EXTERNAL=""
export KUBECTL_CONTEXT="${CLUSTER_NAME}-context"
export GENERATE_CERTS="${GENERATE_CERTS:-true}"
export DEPLOY_TEST_DEPLOYMENT="${DEPLOY_TEST_DEPLOYMENT:-true}"

export KUBE_VERSION=${KUBE_VERSION:-} # kubernetes version, if not provided will get latest
export FLANNEL_VERSION=${FLANNEL_VERSION:-"0.5.5"} 
export ETCD_VERSION=${ETCD_VERSION:-"2.3.1"} 

export SSH_OPTS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=ERROR"
