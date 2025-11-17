FROM python:3.14-slim@sha256:9813eecff3a08a6ac88aea5b43663c82a931fd9557f6aceaa847f0d8ce738978

COPY requirements.txt ./requirements.txt
# Install any needed packages specified in requirements.txt
RUN pip install -q --trusted-host pypi.python.org -r requirements.txt

RUN adduser --system snmpsim

EXPOSE 161/udp

CMD snmpsimd.py --agent-udpv4-endpoint=0.0.0.0:161 --process-user=snmpsim --process-group=nogroup $EXTRA_FLAGS
