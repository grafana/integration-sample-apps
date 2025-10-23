FROM debian:stable-slim@sha256:a771c85b2287eae7ce8fe0a4c2637d575c5d991555ae680c187c5572153648d9 AS builder

RUN apt-get update && \
    apt-get install -y curl unzip && \
    curl -L https://github.com/influxdata/influxdb2-sample-data/archive/refs/heads/master.zip -o master.zip && \
    unzip /master.zip -d / && \
    curl -L https://dl.influxdata.com/influxdb/releases/influxdb2-client-2.7.3-linux-amd64.tar.gz -o influxdb2-client-2.7.3-linux-amd64.tar.gz && \
    tar -xvf influxdb2-client-2.7.3-linux-amd64.tar.gz

FROM debian:stable-slim@sha256:a771c85b2287eae7ce8fe0a4c2637d575c5d991555ae680c187c5572153648d9

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /influxdb2-sample-data-master /influxdb2-sample-data
COPY --from=builder /influx /usr/local/bin/influx
COPY loadgen.sh /
RUN chmod +x /loadgen.sh
CMD ["/loadgen.sh"]

