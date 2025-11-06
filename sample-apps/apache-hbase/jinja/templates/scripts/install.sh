#!/bin/bash

# Integration only claims support for HBase 3.0+
{% set hbase_version = hbase_version | default("3.0.0-beta-1") %}

set -e

sudo apt-get update
sudo apt-get install -y openjdk-11-jdk-headless

sudo mkdir -p /opt/hbase/logs \
    /opt/volume/hbase

echo "Downloading HBase {{ hbase_version }}..."
HBASE_URL="https://archive.apache.org/dist/hbase/{{ hbase_version }}/hbase-{{ hbase_version }}-bin.tar.gz"
sudo curl -L --progress-bar --retry 3 --retry-delay 5 "$HBASE_URL" -o /home/ubuntu/hbase.tar.gz

sudo mkdir -p /opt/hbase
sudo tar -xzf /home/ubuntu/hbase.tar.gz -C /opt/hbase --strip 1

ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
else
    JAVA_HOME="/usr/lib/jvm/java-11-openjdk-arm64"
fi

sudo cat <<EOF | sudo tee /opt/hbase/env
export JAVA_HOME=$JAVA_HOME
export PATH=$PATH:$JAVA_HOME/bin
export HBASE_HOME=/opt/hbase
export PATH=$PATH:/opt/hbase/bin
EOF

sudo cat <<EOF | sudo tee /opt/hbase/hbase.env
JAVA_HOME=$JAVA_HOME
HBASE_HOME=/opt/hbase
EOF

source /opt/hbase/env

sudo cat > /opt/hbase/conf/hbase-site.xml << 'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>file:///opt/volume/hbase</value>
  </property>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>/opt/volume/hbase/zookeeper</value>
  </property>
  <property>
    <name>hbase.unsafe.stream.capability.enforce</name>
    <value>false</value>
  </property>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>localhost</value>
  </property>
  <property>
    <name>hbase.zookeeper.property.clientPort</name>
    <value>2181</value>
  </property>
</configuration>
EOF

# Create regionservers file to ensure RegionServer starts on localhost
echo "localhost" | sudo tee /opt/hbase/conf/regionservers > /dev/null

# Disable SSH requirement by configuring HBase to use local process spawning
sudo cat >> /opt/hbase/conf/hbase-env.sh << 'EOFENV'

# Use local process spawning instead of SSH for single-node setup
export HBASE_MANAGES_ZK=true
EOFENV


# Create hbase user
sudo useradd -r -s /bin/bash -d /opt/hbase hbase || true
sudo chown -R hbase:hbase /opt/hbase
sudo chown -R hbase:hbase /opt/volume/hbase
# Ensure logs directory is writable for PID files
sudo chmod 755 /opt/hbase/logs

# Create systemd service for HBase (starts ZooKeeper, Master, and RegionServer)
sudo tee /etc/systemd/system/hbase.service > /dev/null << EOF
[Unit]
Description=Apache HBase
After=network.target

[Service]
Type=forking
User=hbase
Group=hbase
EnvironmentFile=/opt/hbase/hbase.env
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${JAVA_HOME}/bin:/opt/hbase/bin"
ExecStart=/bin/bash -c 'source /opt/hbase/env && /opt/hbase/bin/hbase-daemon.sh start zookeeper && sleep 5 && /opt/hbase/bin/start-hbase.sh'
ExecStop=/bin/bash -c 'source /opt/hbase/env && /opt/hbase/bin/stop-hbase.sh && /opt/hbase/bin/hbase-daemon.sh stop zookeeper'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable hbase.service

sudo systemctl start hbase.service || echo "HBase service start returned non-zero, but continuing..."

# Wait a moment for HBase to initialize
sleep 5

if sudo systemctl is-active --quiet hbase.service; then
    echo "HBase service is running successfully!"
else
    echo "WARNING: HBase service may not be fully started yet. Check logs with: sudo journalctl -u hbase.service"
fi

echo "HBase installation completed!"
echo "HBase Master Web UI: http://localhost:16010"
echo "HBase Master JMX Metrics: http://localhost:8888/metrics"
echo "HBase RegionServer Web UI: http://localhost:16030"
echo "HBase RegionServer JMX Metrics: http://localhost:8889/metrics"
