#!/bin/bash

VM_ID=$1
IP_FILE=$2

# Read IP addresses from file
readarray -t IPS < "${IP_FILE}"

# Assign IPs to variables
IP1=${IPS[0]}
IP2=${IPS[1]}
IP3=${IPS[2]}

echo "Setting up Solr on VM_ID: $VM_ID"

# Define Solr Version
SOLR_VERSION="8.11.2"

# Install Solr
cd /tmp
sudo wget https://downloads.apache.org/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz
sudo tar xzf solr-$SOLR_VERSION.tgz
sudo solr-$SOLR_VERSION/bin/install_solr_service.sh solr-$SOLR_VERSION.tgz

# Configure Solr for ZooKeeper and set Solr port
SOLR_PORT=$((8983 + VM_ID))
SOLR_IN_SH=$(sudo find / -name solr.in.sh 2>/dev/null)
sudo sed -i "/^SOLR_PORT=/c\SOLR_PORT=\"$SOLR_PORT\"" $SOLR_IN_SH
sudo bash -c "echo ZK_HOST=\\\"$IP1:2181,$IP2:2181,$IP3:2181\\\" >> $SOLR_IN_SH"

# Restart
sudo systemctl restart solr

# Set up Prometheus exporter for Solr
cd /tmp/solr-$SOLR_VERSION/contrib/prometheus-exporter
nohup sudo ./bin/solr-exporter -p 9854 -z $IP1:2181,$IP2:2181,$IP3:2181 -f ./conf/solr-exporter-config.xml -n 16 &

# Create Solr collection only on the first node
if [ "$VM_ID" == "1" ]; then
    sudo /opt/solr-$SOLR_VERSION/bin/solr create_collection -c cluster-collection-vm -shards 2 -replicationFactor 2 -force
fi
