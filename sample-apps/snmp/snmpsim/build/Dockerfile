FROM python:3.14-slim@sha256:9aaa474097d094040649f2162a627c0049b408f52138d980916788d80f04802f

COPY requirements.txt ./requirements.txt
# Install any needed packages specified in requirements.txt
RUN pip install -q --trusted-host pypi.python.org -r requirements.txt

# snmpsim 1.2.2 passes the numeric variation's deviation setting to random.randrange as a float.
# This fails on Python 3.12+. The sed casts both bounds to int in the installed numeric.py.
# The grep fails the build if a new snmpsim release changes the line.
RUN f=$(python -c 'import os, snmpsim; print(os.path.dirname(snmpsim.__file__))')/variation/numeric.py \
    && sed -i 's/random.randrange(-deviation, deviation)/random.randrange(int(-deviation), int(deviation))/' "$f" \
    && grep -q 'random.randrange(int(-deviation), int(deviation))' "$f"

COPY alert_test.py /usr/local/bin/alert-test

RUN adduser --system snmpsim

EXPOSE 161/udp

CMD snmpsim-command-responder --data-dir=/usr/local/snmpsim/data --agent-udpv4-endpoint=0.0.0.0:161 --process-user=snmpsim --process-group=nogroup $EXTRA_FLAGS
