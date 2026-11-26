#!/bin/sh

set -e

# TensorFlow Serving's half_plus_two test model
MODEL_URL=https://raw.githubusercontent.com/tensorflow/serving/2.21.0/tensorflow_serving/servables/tensorflow/testdata/saved_model_half_plus_two_cpu/00000123
MODEL_DIR=/home/ubuntu/models/half_plus_two/00000123
for file in saved_model.pb assets/foo.txt variables/variables.data-00000-of-00001 variables/variables.index; do
  curl -fsSL --create-dirs -o "$MODEL_DIR/$file" "$MODEL_URL/$file"
done

# The image is amd64 only, so it runs under QEMU on arm64
docker run -d --platform linux/amd64 -p 8501:8501 --name tensorflow-serving --rm \
  -e MODEL_NAME=half_plus_two \
  -v /home/ubuntu/models/half_plus_two:/models/half_plus_two \
  -v /home/ubuntu/config:/home/ubuntu/config \
  tensorflow/serving:2.21.0@sha256:b09456481317351201fbe0b3c5954273e1b697b4a4a7834dc56f01731137a529 \
  --monitoring_config_file=/home/ubuntu/config/monitoring_config.txt \
  --enable_batching \
  --batching_parameters_file=/home/ubuntu/config/batching_config.txt
