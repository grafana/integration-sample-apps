#!/bin/sh

set -e

# Run TensorFlow serving image
docker run -d --platform linux/amd64 -p 8501:8501 --name tensorflow-serving --rm \
  -e MODEL_NAME=${MODEL_NAME} \
  -v /home/ubuntu/models:/home/ubuntu/models \
  -v /home/ubuntu/config:/home/ubuntu/config \
  tensorflow/serving:2.19.0 \
  --model_name=$MODEL_NAME \
  --model_base_path=/home/ubuntu/models/$MODEL_NAME \
  --monitoring_config_file=/home/ubuntu/config/monitoring_config.txt \
  --enable_batching \
  --batching_parameters_file=/home/ubuntu/config/batching_config.txt
