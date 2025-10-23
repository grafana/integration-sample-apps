FROM apache/activemq-classic:6.1.7@sha256:b2727c008ccc51fd45a8011fa1b2f1666bcc031766f0a9e6f3598bc7fdf3cb5e

ARG JMX_EXPORTER_VERSION=1.3.0
ARG JMX_EXPORTER_PORT=9000

ENV JMX_EXPORTER_VERSION=${JMX_EXPORTER_VERSION}
ENV JMX_EXPORTER_PORT=${JMX_EXPORTER_PORT}

COPY ./jmx/config.yaml /activemq-jmx-config.yaml

RUN apt-get update && \
    apt-get install -y curl && \
    curl -L -o jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar "https://github.com/prometheus/jmx_exporter/releases/download/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"

ENV ACTIVEMQ_OPTS="-javaagent:/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar=${JMX_EXPORTER_PORT}:/activemq-jmx-config.yaml"
