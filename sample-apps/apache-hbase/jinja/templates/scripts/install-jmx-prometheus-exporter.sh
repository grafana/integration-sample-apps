#!/bin/bash

{% set jmx_exporter_version = jmx_exporter_version | default("1.3.0") %}

# JMX Prometheus Exporter configuration
JMX_EXPORTER_VERSION={{ jmx_exporter_version }}
JMX_EXPORTER_DIR="/opt/jmx-prometheus-exporter"
JMX_EXPORTER_JAR="$JMX_EXPORTER_DIR/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"
JMX_MASTER_CONFIG_FILE="$JMX_EXPORTER_DIR/apache-hbase-master-jmx-config.yml"
JMX_REGIONSERVER_CONFIG_FILE="$JMX_EXPORTER_DIR/apache-hbase-regionserver-jmx-config.yml"

sudo mkdir -p "$JMX_EXPORTER_DIR"

echo "Downloading JMX Prometheus Java Agent version $JMX_EXPORTER_VERSION..."
sudo wget -O "$JMX_EXPORTER_JAR" \
    "https://github.com/prometheus/jmx_exporter/releases/download/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"

sudo cat > "$JMX_MASTER_CONFIG_FILE" <<'EOF'
lowercaseOutputName: true
lowercaseOutputLabelNames: true
rules:
  - pattern: ".*"
EOF

sudo cat > "$JMX_REGIONSERVER_CONFIG_FILE" <<'EOF'
lowercaseOutputName: true
lowercaseOutputLabelNames: true
rules:
  - pattern: ".*"
EOF

echo "JMX Prometheus Exporter installation completed!"
echo "JAR location: $JMX_EXPORTER_JAR"
echo "Master config: $JMX_MASTER_CONFIG_FILE"
echo "RegionServer config: $JMX_REGIONSERVER_CONFIG_FILE"
