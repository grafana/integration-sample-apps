#!/bin/bash

# This script will check a given sample app contains the .CI_BYPASS file
SAMPLE_APP_NAME=$1

if test -f "sample-apps/$1/.CI_BYPASS"; then
  echo true
else
  echo false
fi
