FROM oraclelinux:10@sha256:3201ae3dbfbfc68dd9ed48635f355ef6d9269d7b02d0d377dcb147de59a3eb28

# Installing from oraclelinux:8 so that we can easily get the Oracle Instant Client
RUN dnf install -y oracle-instantclient-release-23ai-el8 && \
    dnf install -y oracle-instantclient-basic
