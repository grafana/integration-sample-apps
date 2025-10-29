FROM oraclelinux:10@sha256:753e18ae99854795a67768092f187e1a7b82a61a684ceceb9e060e3cf5d31805

# Installing from oraclelinux:8 so that we can easily get the Oracle Instant Client
RUN dnf install -y oracle-instantclient-release-23ai-el8 && \
    dnf install -y oracle-instantclient-basic
