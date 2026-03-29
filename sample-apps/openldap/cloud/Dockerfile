FROM golang:1.26@sha256:595c7847cff97c9a9e76f015083c481d26078f961c9c8dca3923132f51fe12f1 as builder

WORKDIR /app
RUN git clone https://github.com/grafana/openldap_exporter.git .
RUN go build -o openldap_exporter ./cmd/openldap_exporter

FROM alpine:latest@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412
WORKDIR /root/
COPY --from=builder /app/openldap_exporter .

ENTRYPOINT ["./openldap_exporter"]
CMD ["--ldapAddr=ldap://my-openldap.default.svc.cluster.local:389", "--ldapUser=cn=monitor,dc=example,dc=org", "--ldapPass=Not@SecurePassw0rd"]
