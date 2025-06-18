#!/bin/bash
set -e

source /etc/os-release

if [[ $ID == debian && "${VERSION_ID}" == 12 ]]; then
    TOMCAT_VERSION=tomcat10
    sudo apt-get install -y curl openjdk-17-jdk openjdk-17-jdk-headless
else
    if [[ $ID == ubuntu && "${VERSION_ID}" == 24* ]]; then
        TOMCAT_VERSION=tomcat10
    else
        TOMCAT_VERSION=tomcat9
    fi
    sudo apt-get install -y curl default-jdk default-jdk-headless
fi

DEBIAN_FRONTEND=noninteractive  sudo apt install ${TOMCAT_VERSION} -y

# JMX Prometheus Exporter configuration
JMX_EXPORTER_VERSION=${JMX_EXPORTER_VERSION:-"1.3.0"}
JMX_EXPORTER_PORT=${JMX_EXPORTER_PORT:-"9145"}
JMX_EXPORTER_DIR="/opt/jmx-prometheus-exporter"
JMX_CONFIG_FILE="$JMX_EXPORTER_DIR/tomcat-jmx-config.yml"

sudo mkdir -p "$JMX_EXPORTER_DIR"

echo "Downloading JMX Prometheus Java Agent version $JMX_EXPORTER_VERSION..."
sudo wget -O "$JMX_EXPORTER_DIR/jmx_prometheus_javaagent-$JMX_EXPORTER_VERSION.jar" \
    "https://github.com/prometheus/jmx_exporter/releases/download/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"

echo "Creating JMX configuration file..."
sudo cat > "$JMX_CONFIG_FILE" << 'EOF'
lowercaseOutputLabelNames: true
lowercaseOutputName: true
rules:
- pattern: 'Catalina<type=GlobalRequestProcessor, name=\"(\w+-\w+)-(\d+)\"><>(\w+):'
  name: tomcat_$3_total
  labels:
    port: "$2"
    protocol: "$1"
  help: Tomcat global $3
  type: COUNTER
- pattern: 'Catalina<j2eeType=Servlet, WebModule=//([-a-zA-Z0-9+&@#/%?=~_|!:.,;]*[-a-zA-Z0-9+&@#/%=~_|]), name=([-a-zA-Z0-9+/$%~_-|!.]*), J2EEApplication=none, J2EEServer=none><>(requestCount|maxTime|processingTime|errorCount):'
  name: tomcat_servlet_$3_total
  labels:
    module: "$1"
    servlet: "$2"
  help: Tomcat servlet $3 total
  type: COUNTER
- pattern: 'Catalina<type=ThreadPool, name="(\w+-\w+)-(\d+)"><>(currentThreadCount|currentThreadsBusy|keepAliveCount|pollerThreadCount|connectionCount):'
  name: tomcat_threadpool_$3
  labels:
    port: "$2"
    protocol: "$1"
  help: Tomcat threadpool $3
  type: GAUGE
- pattern: 'Catalina<type=Manager, host=([-a-zA-Z0-9+&@#/%?=~_|!:.,;]*[-a-zA-Z0-9+&@#/%=~_|]), context=([-a-zA-Z0-9+/$%~_-|!.]*)><>(processingTime|sessionCounter|rejectedSessions|expiredSessions):'
  name: tomcat_session_$3_total
  labels:
    context: "$2"
    host: "$1"
  help: Tomcat session $3 total
  type: COUNTER

# Generic JVM metrics
- pattern: 'java.lang<type=Memory><(\w+)MemoryUsage>(\w+): (\d+)'
  name: jvm_memory_usage_$2_bytes
  labels:
    area: "$1"  # Heap/NonHeap
  value: $3
  type: GAUGE

- pattern: 'java.lang<type=OperatingSystem><>TotalPhysicalMemorySize: (\d+)'
  name: jvm_physical_memory_bytes
  value: $1
  type: GAUGE

# CPU Load
- pattern: 'java.lang<type=OperatingSystem><>ProcessCpuLoad: (.[0-9]*[.]?[0-9]+)'
  name: jvm_process_cpu_load
  value: $1
  type: GAUGE
EOF

# Set appropriate permissions
sudo chown -R root:root "$JMX_EXPORTER_DIR"
sudo chmod 644 "$JMX_CONFIG_FILE"
sudo chmod 644 "$JMX_EXPORTER_DIR/jmx_prometheus_javaagent-$JMX_EXPORTER_VERSION.jar"

sudo mkdir -p /etc/systemd/system/${TOMCAT_VERSION}.service.d
sudo cat >> /etc/systemd/system/${TOMCAT_VERSION}.service.d/local.conf << EOF
[Service]
# Configuration
Environment="JAVA_OPTS=-Djava.awt.headless=true -javaagent:/opt/jmx-prometheus-exporter/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar=${JMX_EXPORTER_PORT}:/opt/jmx-prometheus-exporter/tomcat-jmx-config.yml"
Environment="CATALINA_OPTS=-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9010 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false"
EOF

sudo systemctl daemon-reload

sudo systemctl restart ${TOMCAT_VERSION}

# Create the proper Ubuntu Tomcat configuration file
sudo cat > /etc/default/${TOMCAT_VERSION} << EOF
# Tomcat Configuration for JMX Prometheus Exporter
JAVA_OPTS="-Djava.awt.headless=true"
JAVA_OPTS="\$JAVA_OPTS -javaagent:/opt/jmx-prometheus-exporter/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar=${JMX_EXPORTER_PORT}:/opt/jmx-prometheus-exporter/tomcat-jmx-config.yml"
JAVA_OPTS="\$JAVA_OPTS -Dcom.sun.management.jmxremote"
JAVA_OPTS="\$JAVA_OPTS -Dcom.sun.management.jmxremote.port=9010"
JAVA_OPTS="\$JAVA_OPTS -Dcom.sun.management.jmxremote.authenticate=false"
JAVA_OPTS="\$JAVA_OPTS -Dcom.sun.management.jmxremote.ssl=false"
EOF

sudo systemctl restart ${TOMCAT_VERSION}
