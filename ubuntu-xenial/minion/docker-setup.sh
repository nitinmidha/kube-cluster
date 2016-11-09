#!/bin/bash

function check_package_installed(){
    if dpkg --get-selections | grep -q "^$1[[:space:]]*" >/dev/null; then
        return 0
    else
        return 1
    fi
}
package_to_check=docker-engine
if check_package_installed $package_to_check; then
    echo "$package_to_check is already installed"
else
    echo "Installing $package_to_check"
    version=${1:-}
    apt-get -y update
    apt-get -y upgrade
    apt-get -y install apt-transport-https ca-certificates bridge-utils linux-image-extra-$(uname -r) apparmor
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" > /etc/apt/sources.list.d/docker.list
    apt-get -y update
    apt-get -y purge lxc-docker
    apt-cache policy docker-engine
    if [ -z "$version" ]; then
        apt-get -y install docker-engine
    else
        apt-get -y install docker-engine=$version
    fi 
    service docker start
fi