#!/bin/sh

# Remove set -e to prevent immediate exit on errors
while true; do
    curl \
        --silent \
        --output /dev/null \
        -d '{"instances": [13.0, 23.0, 53.0, 103.0, 503.0, 15, 17]}' \
        -X POST \
        http://localhost:8501/v1/models/half_plus_two:predict || true  # Add || true to prevent exit on curl failure
    sleep 10
done
