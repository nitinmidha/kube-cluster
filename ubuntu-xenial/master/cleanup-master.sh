#!/bin/bash

function cleanup-master(){
    systemctl stop etcd kube-apiserver kube-controller-manager kube-scheduler
    systemctl disable etcd kube-apiserver kube-controller-manager kube-scheduler

    rm /etc/systemd/system/etcd*
    rm /etc/systemd/system/kube-apiserver*
    rm /etc/systemd/system/kube-controller-manager*
    rm /etc/systemd/system/kube-scheduler*


    systemctl daemon-reload
    systemctl reset-failed

    rm -rf \
        /opt/bin/etcd* \
        /opt/bin/kube* \
        /etc/kubernetes/ \
        /var/lib/etcd \
        ~/ha-kube \
        /infra*
}

cleanup-master