FROM apache/activemq-classic:6.2.0@sha256:992bc29a8459f6772ff14d168a8b011c9cde7a769ec01d72788c9cc4e9229564

ARG JMX_EXPORTER_VERSION=1.3.0
ARG JMX_EXPORTER_PORT=9000

ENV JMX_EXPORTER_VERSION=${JMX_EXPORTER_VERSION}
ENV JMX_EXPORTER_PORT=${JMX_EXPORTER_PORT}

COPY ./jmx/config.yaml /activemq-jmx-config.yaml

RUN apt-get update && \
    apt-get install -y curl && \
    curl -L -o jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar "https://github.com/prometheus/jmx_exporter/releases/download/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"

ENV ACTIVEMQ_OPTS="-javaagent:/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar=${JMX_EXPORTER_PORT}:/activemq-jmx-config.yaml"
