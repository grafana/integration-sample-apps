#!/bin/bash

ROOT_DIR=$(git rev-parse --show-toplevel)
OPS_DIR=${ROOT_DIR}/ops
SAMPLE_APPS_DIR=${ROOT_DIR}/sample-apps

# we expect a comma separated list
SAMPLE_APPS=$1
ENV=${2:-"local"}

PROMETHEUS_INSTANCE=""
LOKI_INSTANCE=""

if [[ ${ENV} = "local" ]]; then
  DBS_HOST=$(${OPS_DIR}/scripts/multipass_get_ips.sh dbs)
  PROMETHEUS_INSTANCE="${DBS_HOST}:9009"
  LOKI_INSTANCE="${DBS_HOST}:3100"
elif [[ ${ENV} = "k3d" ]]; then
  echo "k3d mode selected"
  PROMETHEUS_INSTANCE="mimir.k3d.localhost:9999"
  LOKI_INSTANCE="loki.k3d.localhost:9999"
else
  echo "Invalid environment provided. Exiting."
  exit 1
fi

if [[ -z "${SAMPLE_APPS}" ]]; then
  echo "No sample-apps provided. Exiting."
  exit 1
else
  for APP in ${SAMPLE_APPS//,/ }; do
    cd ${SAMPLE_APPS_DIR}/${APP}
    echo "-- Spawning sample-app ${APP} --"
    make "PROMETHEUS_INSTANCE=${PROMETHEUS_INSTANCE}" "LOKI_INSTANCE=${LOKI_INSTANCE}" run-ci
    if [[ ${ENV} = "k3d" ]]; then
      make configure-k3d-dns
    fi
  done
fi
