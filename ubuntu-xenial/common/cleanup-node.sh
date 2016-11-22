#!/bin/bash

# Cleanup ETCD
if [ -f /opt/bin/etcd ]; then
    systemctl stop etcd
    systemctl disable etcd

    rm /etc/systemd/system/etcd*

    rm -rf \
        /opt/bin/etcd* \
        /var/lib/etcd \
        /infra*
fi

# cleanup kube-master 
if [ -f /opt/bin/kube-apiserver ]; then
    systemctl stop kube-apiserver kube-controller-manager kube-scheduler
    systemctl disable kube-apiserver kube-controller-manager kube-scheduler

    rm /etc/systemd/system/kube-apiserver*
    rm /etc/systemd/system/kube-controller-manager*
    rm /etc/systemd/system/kube-scheduler*

    rm -rf \
        /opt/bin/kube* 
fi

# cleanup Kube-Minion 
if [ -f /opt/bin/flanneld ]; then
    systemctl stop docker flanneld kube-proxy kubelet
    systemctl disable flanneld kube-proxy kubelet

    rm /etc/systemd/system/flanneld*
    rm /etc/systemd/system/kube*

    rm -rf \
        /opt/bin/flanneld* \
        /opt/bin/kube* \
        /opt/bin/pre-docker-setup \
        /var/lib/kubelet \
        /run/flannel 
fi

rm -rf \
    /etc/kubernetes/ \
    ~/ha-kube

systemctl daemon-reload
systemctl reset-failed