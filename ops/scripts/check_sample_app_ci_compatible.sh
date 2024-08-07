#!/bin/bash

# This script will check a given sample app to see if it is compatible with running in CI

SAMPLE_APP_NAME=$1

# Expected files for a compatible sample app
declare -a EXPECTED_FILES=(".config")

for i in "${EXPECTED_FILES[@]}"
do
  if ! test -f "sample-apps/$1/$i"; then
    # File does not exist, exit
    echo false
    exit 0
  fi
done

echo true