#!/bin/bash

set -e

ARCH=$(uname -m)

# Configurable versions via Jinja templating
{% set aerospike_v5_version = aerospike_v5_version | default("5.7.0.23") %}
{% set aerospike_v6_version = aerospike_v6_version | default("6.3.0.2") %}
{% set aerospike_v7_version = aerospike_v7_version | default("7.2.0.11") %}
{% set aerospike_tools_v5_version = aerospike_tools_v5_version | default("7.1.1") %}
{% set aerospike_tools_v6_version = aerospike_tools_v6_version | default("8.3.0") %}
{% set aerospike_tools_v7_version = aerospike_tools_v7_version | default("11.2.2") %}

install_5() {
    # download, extract, install, and start aerospike community edition
    wget -O aerospike.tgz "https://download.aerospike.com/artifacts/aerospike-server-community/{{ aerospike_v5_version }}/aerospike-server-community-{{ aerospike_v5_version }}-$os_version.tgz"
    tar -xvf aerospike.tgz
    (cd aerospike-server-community-{{ aerospike_v5_version }}-*/ && sudo ./asinstall)

    wget -O aerospike-tools.tgz "https://download.aerospike.com/artifacts/aerospike-tools/{{ aerospike_tools_v5_version }}/aerospike-tools-{{ aerospike_tools_v5_version }}-$os_version.tgz"
    tar -xzf aerospike-tools.tgz
    (cd aerospike-tools-{{ aerospike_tools_v5_version }}-*/ && sudo ./asinstall)
}

install_6() {
    # download, extract, install, and start aerospike community edition
    wget -O aerospike.tgz "https://download.aerospike.com/artifacts/aerospike-server-community/{{ aerospike_v6_version }}/aerospike-server-community_{{ aerospike_v6_version }}_tools-{{ aerospike_tools_v6_version }}_${os_version}_${ARCH}.tgz"
    tar -xvf aerospike.tgz
    (cd aerospike-server-community_{{ aerospike_v6_version }}*/ && sudo ./asinstall)
}

install_7() {
    # download, extract, install, and start aerospike community edition
    wget -O aerospike.tgz "https://download.aerospike.com/artifacts/aerospike-server-community/{{ aerospike_v7_version }}/aerospike-server-community_{{ aerospike_v7_version }}_tools-{{ aerospike_tools_v7_version }}_${os_version}_${ARCH}.tgz"
    tar -xvf aerospike.tgz
    (cd aerospike-server-community_{{ aerospike_v7_version }}*/ && sudo ./asinstall)
}

source /etc/os-release

case $ID in
    ubuntu)
        case "$VERSION_ID" in
            18*) os_version=ubuntu18.04;;
            20*) os_version=ubuntu20.04;;
            22*) os_version=ubuntu22.04;;
            24*) os_version=ubuntu24.04;;
            *) echo "Unsupported Ubuntu version: $VERSION_ID"; exit 1;;
        esac
        ;;
esac


case $os_version in 
    ubuntu18.04)
        install_5
        ;;
    ubuntu20.04|ubuntu22.04)
        install_6
        ;;
    ubuntu24.04)
        install_7
        ;;
    *) echo "Found os_version: $os_version, not in supported list";;
esac


mkdir -p /var/log/aerospike
sudo cp /home/ubuntu/aerospike.conf /etc/aerospike/aerospike.conf
sudo systemctl enable aerospike
sudo systemctl start aerospike
