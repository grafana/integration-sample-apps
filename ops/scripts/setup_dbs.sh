#!/bin/bash
# NOTE: This file expects to be run from project root, e.g. via CI/CD workflows

DBS_NAME=$1
ENV=$2

# Spawn a docker vm based on docker cloud-init from Canonical
multipass launch 24.04 \
  --name $1 \
  --cpus 2 \
  --memory 4G \
  --disk 40G \
  --cloud-init https://raw.githubusercontent.com/canonical/multipass/refs/heads/main/data/cloud-init-yaml/cloud-init-docker.yaml

# Transfer required config files for loki & mimir
multipass transfer ./ops/qa/dbs/* $1:/home/ubuntu -r

# Spin up docker containers for loki and mimir within the multipass vm
multipass exec $1 -- bash -c "docker-compose -f docker-compose.yaml up -d"

# Spin up local specific options, e.g. Grafana.
if [[ -n "${ENV}" ]]; then
  if [[ "${ENV}" == "local" ]]; then
    echo "Configuring extras for local development"
    multipass exec $1 -- bash -c "docker-compose -f docker-compose.grafana.yaml up -d"
  fi
fi
