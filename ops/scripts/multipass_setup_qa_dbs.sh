#!/bin/bash
# NOTE: This file expects to be run from project root, e.g. via CI/CD workflows

# Spawn a docker vm based on multipass blueprint
multipass launch docker --name $1

# Transfer required config files for loki & mimir
multipass transfer ./ops/qa/dbs/* $1:/home/ubuntu -r

# Spin up docker containers for loki and mimir within the multipass vm
multipass exec $1 -- bash -c "docker-compose -f docker-compose.yaml up -d"

# Spin up grafana (optional)
if [[ $2 -eq "local" ]]; then
   multipass exec $1 -- bash -c "docker-compose -f docker-compose.grafana.yaml up -d"
fi
