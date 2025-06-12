#!/bin/sh

set -e

# Run TensorFlow serving image
# Custom image with baked in model, see https://github.com/observIQ/application-helm-charts/tree/main/container/tensorflow
docker run -d --platform linux/amd64 -p 8501:8501 --name tensorflow-serving --rm \
  -e MODEL_NAME=half_plus_two \
  -v /home/ubuntu/models:/home/ubuntu/models \
  -v /home/ubuntu/config:/home/ubuntu/config \
  ghcr.io/observiq/tensorflow:dc57387 \
  --monitoring_config_file=/home/ubuntu/config/monitoring_config.txt \
  --enable_batching \
  --batching_parameters_file=/home/ubuntu/config/batching_config.txt
