FROM debian:bookworm-slim@sha256:f06537653ac770703bc45b4b113475bd402f451e85223f0f2837acbf89ab020a AS stage

WORKDIR /exporter
ADD https://github.com/jonnenauha/prometheus_varnish_exporter/releases/download/1.6.1/prometheus_varnish_exporter-1.6.1.linux-amd64.tar.gz /exporter/exporter.tar.gz
RUN tar -xvf exporter.tar.gz
RUN chmod +x /exporter/prometheus_varnish_exporter-1.6.1.linux-amd64/prometheus_varnish_exporter
RUN dpkg --add-architecture amd64  && apt-get update && apt-get install -y libc6-dev

FROM varnish:stable@sha256:7f2565f220dda0e42af7f1e02427405db4b647230304a4f2a3759eb01523fc25

COPY --from=stage /exporter/prometheus_varnish_exporter-1.6.1.linux-amd64/prometheus_varnish_exporter /prometheus_varnish_exporter
ENTRYPOINT [ "/prometheus_varnish_exporter" ]
