FROM oraclelinux:10@sha256:3061fde67a9d9eb7226ac2e8b640cedbea98cc67fe2b517ce7f352eb7f9618ba

# Installing from oraclelinux:8 so that we can easily get the Oracle Instant Client
RUN dnf install -y oracle-instantclient-release-23ai-el8 && \
    dnf install -y oracle-instantclient-basic
