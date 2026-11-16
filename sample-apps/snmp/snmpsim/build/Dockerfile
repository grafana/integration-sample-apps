FROM python:3.15-slim@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928

COPY requirements.txt ./requirements.txt
# Install any needed packages specified in requirements.txt
RUN pip install -q --trusted-host pypi.python.org -r requirements.txt

RUN adduser --system snmpsim

EXPOSE 161/udp

CMD snmpsim-command-responder --data-dir=/usr/local/snmpsim/data --agent-udpv4-endpoint=0.0.0.0:161 --process-user=snmpsim --process-group=nogroup $EXTRA_FLAGS
