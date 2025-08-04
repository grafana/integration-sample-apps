#!/bin/bash

{% set hadoop_version = hadoop_version | default("3.3.6") %}
{% set jmx_exporter_version = jmx_exporter_version | default("1.3.0") %}

set -e

sudo apt-get update
sudo apt-get install -y openjdk-11-jdk-headless
sudo apt install -y ssh

sudo mkdir -p /opt/hadoop/logs \
    /opt/volume/datanode \
    /opt/volume/namenode

echo "Downloading Hadoop {{ hadoop_version }}..."
sudo curl https://dlcdn.apache.org/hadoop/common/hadoop-{{ hadoop_version }}/hadoop-{{ hadoop_version }}.tar.gz -o /home/ubuntu/hadoop.tar.gz

sudo mkdir -p /opt/hadoop
sudo tar -xzf /home/ubuntu/hadoop.tar.gz -C /opt/hadoop --strip 1

JMX_EXPORTER_VERSION={{ jmx_exporter_version }}

ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
else
    JAVA_HOME="/usr/lib/jvm/java-11-openjdk-arm64"
fi

sudo cat <<EOF | sudo tee /opt/hadoop/env
export JAVA_HOME=$JAVA_HOME
export PATH=$PATH:$JAVA_HOME/bin
export CLASSPATH=.:$JAVA_HOME/jre/lib:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar
export HADOOP_HOME=/opt/hadoop
export HADOOP_COMMON_HOME=/opt/hadoop
export HADOOP_HDFS_HOME=/opt/hadoop
export HADOOP_MAPRED_HOME=/opt/hadoop
export HADOOP_YARN_HOME=/opt/hadoop
export HADOOP_OPTS="-Djava.library.path=/opt/hadoop/lib/native"
export HADOOP_COMMON_LIB_NATIVE_DIR=/opt/hadoop/lib/native
export PATH=$PATH:/opt/hadoop/sbin:/opt/hadoop/bin
EOF

source /opt/hadoop/env

sudo cat >> /etc/systemd/system/hadoop.service << EOF
[Unit]
Description=Apache Hadoop
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment="JAVA_HOME=$JAVA_HOME"
Environment="PATH=$PATH:$JAVA_HOME/bin"
Environment="HADOOP_HOME=/opt/hadoop"
Environment="HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop"
ExecStart=/opt/hadoop/sbin/start-dfs.sh
ExecStop=/opt/hadoop/sbin/stop-dfs.sh
WorkingDirectory=/opt/hadoop
User=hadoop
Group=hadoop

[Install]
WantedBy=multi-user.target
EOF

sudo cat > /etc/systemd/system/hadoop-yarn-nodemanager.service << EOF
[Unit]
Description=Apache Hadoop YARN NodeManager
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment="JAVA_HOME=$JAVA_HOME"
Environment="PATH=$PATH:$JAVA_HOME/bin"
Environment="HADOOP_HOME=/opt/hadoop"
Environment="HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop"
Environment="YARN_NODEMANAGER_OPTS=-javaagent:/opt/jmx-prometheus-exporter/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar=8887:/opt/jmx-prometheus-exporter/apache-hadoop-jmx-config.yml"
ExecStart=/opt/hadoop/bin/yarn --daemon start nodemanager
ExecStop=/opt/hadoop/bin/yarn --daemon stop nodemanager
WorkingDirectory=/opt/hadoop
User=hadoop
EOF

sudo cat > /etc/systemd/system/hadoop-yarn-resourcemanager.service << EOF
[Unit]
Description=Apache Hadoop YARN ResourceManager
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment="JAVA_HOME=$JAVA_HOME"
Environment="PATH=$PATH:$JAVA_HOME/bin"
Environment="HADOOP_HOME=/opt/hadoop"
Environment="HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop"
Environment="YARN_RESOURCEMANAGER_OPTS=-javaagent:/opt/jmx-prometheus-exporter/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar=8886:/opt/jmx-prometheus-exporter/apache-hadoop-jmx-config.yml"
ExecStart=/opt/hadoop/bin/yarn --daemon start resourcemanager
ExecStop=/opt/hadoop/bin/yarn --daemon stop resourcemanager
WorkingDirectory=/opt/hadoop
User=hadoop
EOF


sudo cat > /opt/hadoop/etc/hadoop/hdfs-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
<property>
    <name>dfs.data.dir</name>
    <value>file:///opt/volume/datanode</value>
  </property>
  <property>
    <name>dfs.name.dir</name>
    <value>file:///opt/volume/namenode</value>
</property>
</configuration>
EOF

sudo cat > /opt/hadoop/etc/hadoop/core-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
<property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost:9000/</value>
</property>
</configuration>
EOF

sudo cat >> /opt/hadoop/etc/hadoop/hadoop-env.sh << EOF
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export JAVA_HOME=\${JAVA_HOME}
export HADOOP_CONF_DIR=\${HADOOP_CONF_DIR:-"/etc/hadoop"}
for f in \$HADOOP_HOME/contrib/capacity-scheduler/*.jar; do
  if [ "\$HADOOP_CLASSPATH" ]; then
    export HADOOP_CLASSPATH=\$HADOOP_CLASSPATH:\$f
  else
    export HADOOP_CLASSPATH=\$f
  fi
done
export HDFS_OPTS="\$HDFS_OPTS -Djava.net.preferIPv4Stack=true"
export HDFS_NAMENODE_OPTS="-Dhadoop.security.logger=\${HADOOP_SECURITY_LOGGER:-INFO,RFAS} -Dhdfs.audit.logger=\${HDFS_AUDIT_LOGGER:-INFO,NullAppender} \$HDFS_NAMENODE_OPTS"
export HDFS_NAMENODE_OPTS="-Dcom.sun.management.jmxremote \$HDFS_NAMENODE_OPTS"
export HDFS_NAMENODE_OPTS="\$HDFS_NAMENODE_OPTS -javaagent:/opt/jmx-prometheus-exporter/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar=8888:/opt/jmx-prometheus-exporter/apache-hadoop-jmx-config.yml"
export HDFS_DATANODE_OPTS="-Dhadoop.security.logger=ERROR,RFAS \$HDFS_DATANODE_OPTS"
export HDFS_DATANODE_OPTS="\$HDFS_DATANODE_OPTS -javaagent:/opt/jmx-prometheus-exporter/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar=8889:/opt/jmx-prometheus-exporter/apache-hadoop-jmx-config.yml"
export HDFS_SECONDARYNAMENODE_OPTS="-Dhadoop.security.logger=\${HADOOP_SECURITY_LOGGER:-INFO,RFAS} -Dhdfs.audit.logger=\${HDFS_AUDIT_LOGGER:-INFO,NullAppender} \$HDFS_SECONDARYNAMENODE_OPTS"
export HDFS_NFS3_OPTS="\$HDFS_NFS3_OPTS"
export HDFS_PORTMAP_OPTS="-Xmx512m \$HDFS_PORTMAP_OPTS"
export HDFS_CLIENT_OPTS="\$HDFS_CLIENT_OPTS"
if [ "\$HDFS_HEAPSIZE" = "" ]; then
  export HDFS_CLIENT_OPTS="-Xmx512m \$HDFS_CLIENT_OPTS"
fi
export HDFS_SECURE_DN_USER=\${HDFS_SECURE_DN_USER}
export HDFS_PID_DIR=\${HDFS_PID_DIR}
export HDFS_SECURE_DN_PID_DIR=\${HDFS_PID_DIR}
export HDFS_IDENT_STRING=\$USER
EOF

sudo groupadd hadoop || true
sudo useradd -s /bin/bash -d /opt/hadoop hadoop -g hadoop || true

# Fix ownership of hadoop home directory and subdirectories
sudo chown -R hadoop:hadoop /opt/hadoop
sudo chown -R hadoop:hadoop /opt/volume

# Set up environment for hadoop user by appending to .bashrc
sudo su - hadoop -c "cat /opt/hadoop/env >> ~/.bashrc"

# Generate SSH key for hadoop user
sudo su - hadoop -c "echo -e 'y\n' | ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ''"

# Copy the hadoop user's public key to authorized_keys (for passwordless SSH)
sudo su - hadoop -c "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"
sudo su - hadoop -c "chmod 600 ~/.ssh/authorized_keys"

# Format the namenode using POSIX-compatible approach
sudo su - hadoop -c ". /opt/hadoop/env && hdfs namenode -format"

sudo systemctl daemon-reload

sudo systemctl enable hadoop
sudo systemctl start hadoop

sudo systemctl enable hadoop-yarn-nodemanager
sudo systemctl start hadoop-yarn-nodemanager

sudo systemctl enable hadoop-yarn-resourcemanager
sudo systemctl start hadoop-yarn-resourcemanager


