FROM ubuntu:jammy@sha256:09506232a8004baa32c47d68f1e5c307d648fdd59f5e7eaa42aaf87914100db3

RUN apt-get update && apt-get install -y \
    wget curl gnupg software-properties-common
RUN curl https://www.aventer.biz/assets/support_aventer.asc | apt-key add -
RUN add-apt-repository 'deb http://rpm.aventer.biz/Ubuntu/jammy jammy main'
RUN apt-get install -y aventer-mesos

ENV EXPORTER_URL=""

RUN ARCH=$(uname -m) && \
    if [ "${ARCH}" = "arm64" ] || [ "${ARCH}" = "aarch64" ]; then \
        EXPORTER_URL="https://github.com/mesos/mesos_exporter/releases/download/v1.1.2/mesos_exporter-1.1.2.linux-arm64.tar.gz"; \
    else \
        apt-get install -y libapr1 libsvn1 libevent-2.1-7 libevent-core-2.1-7 libevent-pthreads-2.1-7 libevent-openssl-2.1-7 && \
        EXPORTER_URL="https://github.com/mesos/mesos_exporter/releases/download/v1.1.2/mesos_exporter-1.1.2.linux-amd64.tar.gz"; \
    fi && \
    wget ${EXPORTER_URL} && \
    tar -xzvf $(basename ${EXPORTER_URL})
