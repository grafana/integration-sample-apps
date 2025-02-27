#!/bin/bash

# This script will check a given sample app to see if it is compatible with running in CI

SAMPLE_APP_NAME=$1

# Expected files for a compatible sample app
EXPECTED_METRICS_LIST=`ls sample-apps/$1/tests/metrics/*`

if [ -z "$EXPECTED_METRICS_LIST" ]; then
  #[FAIL] Incompatible sample-app or no expected metrics files provided."
  echo false
  exit 1
else
  echo true
  exit 0
fi
