FROM oraclelinux:10@sha256:780c7e187276da78a5c92328282481156ca0f4cb9e5d09af95be9da371523faa

# Installing from oraclelinux:8 so that we can easily get the Oracle Instant Client
RUN dnf install -y oracle-instantclient-release-23ai-el8 && \
    dnf install -y oracle-instantclient-basic
