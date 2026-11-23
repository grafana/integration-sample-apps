FROM golang:1.27@sha256:205c7636d74e0ffbe3d007162df7d74f859f5a8c8322dfb9f907977686c126cf as builder

WORKDIR /app
RUN git clone https://github.com/grafana/openldap_exporter.git .
RUN go build -o openldap_exporter ./cmd/openldap_exporter

FROM alpine:latest@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b
WORKDIR /root/
COPY --from=builder /app/openldap_exporter .

ENTRYPOINT ["./openldap_exporter"]
CMD ["--ldapAddr=ldap://my-openldap.default.svc.cluster.local:389", "--ldapUser=cn=monitor,dc=example,dc=org", "--ldapPass=Not@SecurePassw0rd"]
