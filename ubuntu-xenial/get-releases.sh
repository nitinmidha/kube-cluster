#!/bin/bash
BASE_DIR=${1:-}
WORK_DIR=${2:-}
CONFIG_PATH=${3:-}
FLANNEL_VERSION=${4:-}
ETCD_VERSION=${5:-}
KUBERNETES_RELEASE=${6:-}


ETCD="etcd-v${ETCD_VERSION}-linux-amd64"

mkdir -p "$WORK_DIR/releases/kube"
mkdir -p "$WORK_DIR/releases/etcd"
mkdir -p "$WORK_DIR/releases/flannel"

# Cleanup from last run

rm -rf "$WORK_DIR/binaries"
mkdir -p "$WORK_DIR/binaries"



function get_latest_version_number {
  local -r latest_url="https://storage.googleapis.com/kubernetes-release/release/stable.txt"
  if [[ $(which wget) ]]; then
    wget -qO- ${latest_url}
  elif [[ $(which curl) ]]; then
    curl -Ss ${latest_url}
  else
    echo "Couldn't find curl or wget.  Bailing out." >&2
    exit 4
  fi
}

cd "$WORK_DIR/releases/kube"
if [[ -d "./kubernetes" ]]; then
    echo "Skipping download step."
else
  cd "$WORK_DIR/releases/kube"

  release=${KUBERNETES_RELEASE:-$(get_latest_version_number)}
  release_url=https://storage.googleapis.com/kubernetes-release/release/${release}/kubernetes-server-linux-amd64.tar.gz


  uname=$(uname)
  if [[ "${uname}" == "Darwin" ]]; then
    platform="darwin"
  elif [[ "${uname}" == "Linux" ]]; then
    platform="linux"
  else
    echo "Unknown, unsupported platform: (${uname})."
    echo "Supported platforms: Linux, Darwin."
    echo "Bailing out."
    exit 2
  fi

  machine=$(uname -m)
  if [[ "${machine}" == "x86_64" ]]; then
    arch="amd64"
  elif [[ "${machine}" == "i686" ]]; then
    arch="386"
  elif [[ "${machine}" == "arm*" ]]; then
    arch="arm"
  elif [[ "${machine}" == "s390x*" ]]; then
    arch="s390x"
  elif [[ "${machine}" == "ppc64le" ]]; then
    arch="ppc64le"
  else
    echo "Unknown, unsupported architecture (${machine})."
    echo "Supported architectures x86_64, i686, arm, s390x, ppc64le."
    echo "Bailing out."
    exit 3
  fi

  file=kubernetes-server-linux-amd64.tar.gz

  echo "Downloading kubernetes release ${release} to ${PWD}/kubernetes-server-linux-amd64.tar.gz"
  if [[ -n "${KUBERNETES_SKIP_CONFIRM-}" ]]; then
    echo "Is this ok? [Y]/n"
    read confirm
    if [[ "$confirm" == "n" ]]; then
      echo "Aborting."
      exit 0
    fi
  fi

  if [[ $(which wget) ]]; then
    wget -N ${release_url}
  elif [[ $(which curl) ]]; then
    curl -L -z ${file} ${release_url} -o ${file}
  else
    echo "Couldn't find curl or wget.  Bailing out."
    exit 1
  fi

  echo "Unpacking kubernetes release ${release}"
  tar -xzf ${file}

  #echo "Unpacking kubernetes binaries"

  #pushd kubernetes/server
  #tar xzf kubernetes-server-linux-amd64.tar.gz
  #popd


  # flannel
  cd "$WORK_DIR/releases/flannel"
  echo "Prepare flannel ${FLANNEL_VERSION} release ..."
  grep -q "^${FLANNEL_VERSION}\$" binaries/.flannel 2>/dev/null || {
    curl -L  https://github.com/coreos/flannel/releases/download/v${FLANNEL_VERSION}/flannel-v${FLANNEL_VERSION}-linux-amd64.tar.gz -o flannel.tar.gz
    tar xzf flannel.tar.gz
    
  }

  #etcd
  cd "$WORK_DIR/releases/etcd"
  echo "Prepare etcd ${ETCD_VERSION} release ..."
  grep -q "^${ETCD_VERSION}\$" binaries/.etcd 2>/dev/null || {
    curl -L https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/${ETCD}.tar.gz -o etcd.tar.gz
    tar xzf etcd.tar.gz
    
  }
fi

cd "$WORK_DIR/releases/kube"

cp kubernetes/server/bin/kube-apiserver \
    kubernetes/server/bin/kube-controller-manager \
    kubernetes/server/bin/kube-scheduler "$WORK_DIR/binaries"
cp kubernetes/server/bin/kubelet \
    kubernetes/server/bin/kube-proxy "$WORK_DIR/binaries"
cp kubernetes/server/bin/kubectl "$WORK_DIR/binaries"

cd "$WORK_DIR/releases/flannel"
cp flanneld "$WORK_DIR/binaries"

cd "$WORK_DIR/releases/etcd"
cp ${ETCD}/etcd ${ETCD}/etcdctl "$WORK_DIR/binaries"