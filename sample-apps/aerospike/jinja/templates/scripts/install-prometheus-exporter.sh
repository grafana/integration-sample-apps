#!/bin/bash

set -e

ARCH=$(uname -m)

# Download the deb file
{% set aerospike_prometheus_exporter_version = aerospike_prometheus_exporter_version | default("1.24.0") %}


case $ARCH in
    x86_64)
        EXPORTER_ARCH="amd64"
        ;;
    aarch64)
        EXPORTER_ARCH="arm64"
        ;;
    *) echo "Unsupported architecture: $ARCH";;
esac

curl -L https://dl.aerospike.com/artifacts/aerospike-prometheus-exporter/1.24.0/aerospike-prometheus-exporter_1.24.0-1_${EXPORTER_ARCH}.deb -o aerospike-prometheus-exporter.deb
sudo dpkg -i aerospike-prometheus-exporter.deb

sudo systemctl enable aerospike-prometheus-exporter
sudo systemctl start aerospike-prometheus-exporter
