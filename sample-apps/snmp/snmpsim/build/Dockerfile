FROM python:3.14-slim@sha256:b877e50bd90de10af8d82c57a022fc2e0dc731c5320d762a27986facfc3355c1

COPY requirements.txt ./requirements.txt
# Install any needed packages specified in requirements.txt
RUN pip install -q --trusted-host pypi.python.org -r requirements.txt

# snmpsim 1.2.2 passes the numeric variation's deviation setting to random.randrange as a float.
# This fails on Python 3.12+. The sed casts both bounds to int in the installed numeric.py.
# The grep fails the build if a new snmpsim release changes the line.
RUN f=$(python -c 'import os, snmpsim; print(os.path.dirname(snmpsim.__file__))')/variation/numeric.py \
    && sed -i 's/random.randrange(-deviation, deviation)/random.randrange(int(-deviation), int(deviation))/' "$f" \
    && grep -q 'random.randrange(int(-deviation), int(deviation))' "$f"

RUN adduser --system snmpsim

EXPOSE 161/udp

CMD snmpsim-command-responder --data-dir=/usr/local/snmpsim/data --agent-udpv4-endpoint=0.0.0.0:161 --process-user=snmpsim --process-group=nogroup $EXTRA_FLAGS
