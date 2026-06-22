FROM debian:bookworm-slim@sha256:96e378d7e6531ac9a15ad505478fcc2e69f371b10f5cdf87857c4b8188404716 AS stage

WORKDIR /exporter
ADD https://github.com/jonnenauha/prometheus_varnish_exporter/releases/download/1.6.1/prometheus_varnish_exporter-1.6.1.linux-amd64.tar.gz /exporter/exporter.tar.gz
RUN tar -xvf exporter.tar.gz
RUN chmod +x /exporter/prometheus_varnish_exporter-1.6.1.linux-amd64/prometheus_varnish_exporter
RUN dpkg --add-architecture amd64  && apt-get update && apt-get install -y libc6-dev

FROM varnish:stable@sha256:65de4db75b40ab26fe1b769b3fecafe12ecc0312310d2a8a557a1958683fa279

COPY --from=stage /exporter/prometheus_varnish_exporter-1.6.1.linux-amd64/prometheus_varnish_exporter /prometheus_varnish_exporter
ENTRYPOINT [ "/prometheus_varnish_exporter" ]
