FROM golang:1.26@sha256:cfa27959837144bf4649802ba38e59daffd0dd2a7994aa83daaf113285b0f551 as builder

WORKDIR /app
RUN git clone https://github.com/grafana/openldap_exporter.git .
RUN go build -o openldap_exporter ./cmd/openldap_exporter

FROM alpine:latest@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf
WORKDIR /root/
COPY --from=builder /app/openldap_exporter .

ENTRYPOINT ["./openldap_exporter"]
CMD ["--ldapAddr=ldap://my-openldap.default.svc.cluster.local:389", "--ldapUser=cn=monitor,dc=example,dc=org", "--ldapPass=Not@SecurePassw0rd"]
