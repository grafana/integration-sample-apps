#!/bin/bash

ROOT_DIR=$(git rev-parse --show-toplevel)
OPS_DIR=${ROOT_DIR}/ops
SAMPLE_APPS_DIR=${ROOT_DIR}/sample-apps

# we expect a comma separated list
SAMPLE_APPS=$1

if [[ -z "${SAMPLE_APPS}" ]]; then
  echo "No sample-apps provided. Exiting."
  exit 1
else
  for APP in ${SAMPLE_APPS//,/ }; do
    cd ${SAMPLE_APPS_DIR}/${APP}
    echo "Stopping sample-app \`${APP}\`"
    make stop
  done
fi
