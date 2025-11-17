FROM golang:1.25@sha256:e68f6a00e88586577fafa4d9cefad1349c2be70d21244321321c407474ff9bf2 as builder

WORKDIR /app
RUN git clone https://github.com/grafana/openldap_exporter.git .
RUN go build -o openldap_exporter ./cmd/openldap_exporter

FROM alpine:latest@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412
WORKDIR /root/
COPY --from=builder /app/openldap_exporter .

ENTRYPOINT ["./openldap_exporter"]
CMD ["--ldapAddr=ldap://my-openldap.default.svc.cluster.local:389", "--ldapUser=cn=monitor,dc=example,dc=org", "--ldapPass=Not@SecurePassw0rd"]
