FROM oraclelinux:10@sha256:82d4cf367ef046469bff2f8c5b2adc05187612826325d7967ee0948d9940b2f3

# Installing from oraclelinux:8 so that we can easily get the Oracle Instant Client
RUN dnf install -y oracle-instantclient-release-23ai-el8 && \
    dnf install -y oracle-instantclient-basic
