FROM cassandra:5.0.6@sha256:5e2c85d2d5db759c28c3efb50905f8d237f958321d6dfd8c176cb148700d9ade

# Redeclare ARG variables after FROM so they're available in RUN commands
ARG JMX_EXPORTER_VERSION=1.3.0
ARG JMX_EXPORTER_PORT=9145

# Convert ARG to ENV so variables are available at runtime
ENV JMX_EXPORTER_VERSION=${JMX_EXPORTER_VERSION}
ENV JMX_EXPORTER_PORT=${JMX_EXPORTER_PORT}

COPY ./ready-probe.sh /ready-probe.sh
COPY ./jmx/config.yaml /cassandra-jmx-config.yaml

RUN chmod +x /ready-probe.sh

# Use ARG variables during build time for downloading the JAR
RUN apt-get update && \
 apt-get install -y curl && \
 curl -L -o jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar "https://github.com/prometheus/jmx_exporter/releases/download/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar"

RUN sed -i 's/JVM_OPTS="$JVM_OPTS -Dcom.sun.management.jmxremote.authenticate=true"/JVM_OPTS="$JVM_OPTS -Dcom.sun.management.jmxremote.authenticate=false"/g' /etc/cassandra/cassandra-env.sh
RUN sed -i '/password/d' /etc/cassandra/cassandra-env.sh

## Disable auth requirements
ENV LOCAL_JMX="no"
ENV JVM_EXTRA_OPTS="-Djava.rmi.server.hostname=127.0.0.1 -javaagent:./jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar=${JMX_EXPORTER_PORT}:/cassandra-jmx-config.yaml"
