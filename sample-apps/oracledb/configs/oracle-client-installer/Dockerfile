FROM oraclelinux:8@sha256:7a2401b216210c0670d8707a85f7e7a238c527b0e2280e732dd45a9103b2e29d

# Installing from oraclelinux:8 so that we can easily get the Oracle Instant Client
RUN dnf install -y oracle-instantclient-release-23ai-el8 && \
    dnf install -y oracle-instantclient-basic
