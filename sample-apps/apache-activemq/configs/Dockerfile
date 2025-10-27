FROM apache/activemq-classic:6.1.8@sha256:015faf259d726f296be16ab9d6e0a97bc195dc321f1d68c931dfdff03e600d72

ARG JMX_EXPORTER_VERSION=1.3.0
ARG JMX_EXPORTER_PORT=9000

ENV JMX_EXPORTER_VERSION=${JMX_EXPORTER_VERSION}
ENV JMX_EXPORTER_PORT=${JMX_EXPORTER_PORT}

COPY ./jmx/config.yaml /activemq-jmx-config.yaml

RUN apt-get update && \
    apt-get install -y curl && \
    curl -L -o jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar "https://github.com/prometheus/jmx_exporter/releases/download/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"

ENV ACTIVEMQ_OPTS="-javaagent:/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar=${JMX_EXPORTER_PORT}:/activemq-jmx-config.yaml"
