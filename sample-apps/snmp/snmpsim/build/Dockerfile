FROM python:3.8-slim@sha256:1d52838af602b4b5a831beb13a0e4d073280665ea7be7f69ce2382f29c5a613f

COPY requirements.txt ./requirements.txt
# Install any needed packages specified in requirements.txt
RUN pip install -q --trusted-host pypi.python.org -r requirements.txt

RUN adduser --system snmpsim

EXPOSE 161/udp

CMD snmpsimd.py --agent-udpv4-endpoint=0.0.0.0:161 --process-user=snmpsim --process-group=nogroup $EXTRA_FLAGS
