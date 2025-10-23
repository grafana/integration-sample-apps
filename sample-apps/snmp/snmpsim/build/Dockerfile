FROM python:3.6-slim@sha256:2cfebc27956e6a55f78606864d91fe527696f9e32a724e6f9702b5f9602d0474

COPY requirements.txt ./requirements.txt
# Install any needed packages specified in requirements.txt
RUN pip install -q --trusted-host pypi.python.org -r requirements.txt

RUN adduser --system snmpsim

EXPOSE 161/udp

CMD snmpsimd.py --agent-udpv4-endpoint=0.0.0.0:161 --process-user=snmpsim --process-group=nogroup $EXTRA_FLAGS
