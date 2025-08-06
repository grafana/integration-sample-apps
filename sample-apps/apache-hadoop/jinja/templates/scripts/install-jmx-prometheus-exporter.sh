#!/bin/bash

{% set jmx_exporter_version = jmx_exporter_version | default("1.3.0") %}

# JMX Prometheus Exporter configuration
JMX_EXPORTER_VERSION={{ jmx_exporter_version }}
JMX_EXPORTER_DIR="/opt/jmx-prometheus-exporter"
JMX_CONFIG_FILE="$JMX_EXPORTER_DIR/apache-hadoop-jmx-config.yml"

sudo mkdir -p "$JMX_EXPORTER_DIR"

echo "Downloading JMX Prometheus Java Agent version $JMX_EXPORTER_VERSION..."
sudo wget -O "$JMX_EXPORTER_DIR/jmx_prometheus_javaagent-$JMX_EXPORTER_VERSION.jar" \
    "https://github.com/prometheus/jmx_exporter/releases/download/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"

sudo cat > "$JMX_CONFIG_FILE" <<'EOF'
lowercaseOutputName: true
lowercaseOutputLabelNames: true
EOF
