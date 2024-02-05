#!/bin/bash

VM_ID=$1
IP_FILE=$2

# Read IP addresses from file
readarray -t IPS < "${IP_FILE}"

# Assign IPs to variables
IP1=${IPS[0]}
IP2=${IPS[1]}
IP3=${IPS[2]}

echo "Setting up ZooKeeper on VM_ID: $VM_ID"

# Update and install dependencies
sudo DEBIAN_FRONTEND=noninteractive apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confnew" upgrade
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confnew" install default-jdk zookeeperd netcat


# Configure ZooKeeper
ZOO_CFG="/etc/zookeeper/conf/zoo.cfg"
sudo bash -c "echo server.1=$IP1:2888:3888 >> $ZOO_CFG"
sudo bash -c "echo server.2=$IP2:2888:3888 >> $ZOO_CFG"
sudo bash -c "echo server.3=$IP3:2888:3888 >> $ZOO_CFG"

echo $VM_ID | sudo tee /var/lib/zookeeper/myid

# Restart ZooKeeper
sudo systemctl restart zookeeper

# Wait a bit for ZooKeeper to stabilize
sleep 10
