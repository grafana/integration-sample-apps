#!/bin/bash
set -e

{% set wildfly_version = wildfly_version | default("36.0.1.Final") %}

sudo apt-get update

# Debian 12 very specifically wants openjdk-17-jdk for installing Java via apt
source /etc/os-release
if [[ $ID == debian && "${VERSION_ID}" == 12 ]]; then
    sudo apt-get install -y curl openjdk-17-jdk
else
    sudo apt-get install -y curl default-jre
fi

curl -L \
    -o wildfly.tar.gz \
    https://github.com/wildfly/wildfly/releases/download/{{ wildfly_version }}/wildfly-{{ wildfly_version }}.tar.gz

sudo mkdir -p /opt/wildfly
sudo tar xf wildfly.tar.gz -C /opt/wildfly --strip-components 1

sudo cp /opt/wildfly/docs/contrib/scripts/systemd/launch.sh /opt/wildfly/bin/launch.sh
sudo chmod +x /opt/wildfly/bin/*.sh
sudo mkdir -p /var/run/wildfly

sed -i.bak 's/<remoting-connector\/>/<remoting-connector use-management-endpoint="true"\/>/' /opt/wildfly/standalone/configuration/standalone.xml
sudo /opt/wildfly/bin/add-user.sh sample-user sample-password --silent

# This line enables the prometheus metrics endpoint on the Wildfly server
sudo /opt/wildfly/bin/jboss-cli.sh --connect -u=sample-user -p=sample-password --command='/subsystem=undertow:write-attribute(name=statistics-enabled,value=true)'