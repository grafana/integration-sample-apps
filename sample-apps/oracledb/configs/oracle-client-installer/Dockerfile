FROM oraclelinux:9@sha256:68e856948bfc029c1ab471e3228225fb0415ec95c479177a0e761d5939480d89

# Installing from oraclelinux:8 so that we can easily get the Oracle Instant Client
RUN dnf install -y oracle-instantclient-release-23ai-el8 && \
    dnf install -y oracle-instantclient-basic
