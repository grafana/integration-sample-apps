FROM debian:bookworm-slim@sha256:78d2f66e0fec9e5a39fb2c72ea5e052b548df75602b5215ed01a17171529f706 AS stage

WORKDIR /exporter
ADD https://github.com/jonnenauha/prometheus_varnish_exporter/releases/download/1.6.1/prometheus_varnish_exporter-1.6.1.linux-amd64.tar.gz /exporter/exporter.tar.gz
RUN tar -xvf exporter.tar.gz
RUN chmod +x /exporter/prometheus_varnish_exporter-1.6.1.linux-amd64/prometheus_varnish_exporter
RUN dpkg --add-architecture amd64  && apt-get update && apt-get install -y libc6-dev

FROM varnish:stable@sha256:eafb03356055355f32df19cc652c47846a96b4d1cfc45ad3a7cf9bee52135f2d

COPY --from=stage /exporter/prometheus_varnish_exporter-1.6.1.linux-amd64/prometheus_varnish_exporter /prometheus_varnish_exporter
ENTRYPOINT [ "/prometheus_varnish_exporter" ]
