#!/bin/bash

function cleanup-minion(){
    systemctl stop docker flanneld kube-proxy kubelet
    systemctl disable flanneld kube-proxy kubelet

    rm /etc/systemd/system/flanneld*
    rm /etc/systemd/system/kube*


    systemctl daemon-reload
    systemctl reset-failed

    rm -rf \
        /opt/bin/flanneld* \
        /opt/bin/kube* \
        /opt/bin/pre-docker-setup \
        /etc/kubernetes/ \
        ~/ha-kube \
        /var/lib/kubelet \
        /run/flannel
}

cleanup-minion