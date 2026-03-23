FROM golang:1.25@sha256:e68f6a00e88586577fafa4d9cefad1349c2be70d21244321321c407474ff9bf2 as builder

WORKDIR /app
RUN git clone https://github.com/grafana/openldap_exporter.git .
RUN go build -o openldap_exporter ./cmd/openldap_exporter

FROM alpine:latest@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659
WORKDIR /root/
COPY --from=builder /app/openldap_exporter .

ENTRYPOINT ["./openldap_exporter"]
CMD ["--ldapAddr=ldap://my-openldap.default.svc.cluster.local:389", "--ldapUser=cn=monitor,dc=example,dc=org", "--ldapPass=Not@SecurePassw0rd"]
