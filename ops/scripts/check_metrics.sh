#!/bin/bash

# This script will check each metric of a provided metric list against a provided Prometheus host
# and calculate the success rate

SAMPLE_APP_NAME=$1
PROMETHEUS_INSTANCE=$2

# Global default variables are set via ./ops/.defaultconfig. Required are:
# - SAMPLE_APP_PATH
# - SAMPLE_APP_CONFIG_FILE
# - OUTPUT_MISSING_METRICS_FILE
# - METRICS_SUCCESS_RATE_REQUIRED
source ./ops/.defaultconfig

# In addition, some additional expected variables are set per sample app:
# - JOB_LABEL
# - METRICS_FILE
# Additionally METRICS_SUCCESS_RATE_REQUIRED may be overwritten on a case by case basis
source $SAMPLE_APP_PATH/$SAMPLE_APP_NAME/$SAMPLE_APP_CONFIG_FILE


SUCCESS_COUNTER=0
TOTAL_COUNTER=0

# Group the commands for the counter to work as intended
cat "$SAMPLE_APP_PATH/$SAMPLE_APP_NAME/$METRICS_FILE" | 
{
  echo "--- [ Checking Metrics for $SAMPLE_APP_NAME using job='$JOB_LABEL' ] ---"
  while read METRIC_NAME; do
    let TOTAL_COUNTER++
    if curl -s http://$PROMETHEUS_INSTANCE/prometheus/api/v1/query?query=$METRIC_NAME | jq -r .data.result[0].metric | grep -q $JOB_LABEL; then
      let SUCCESS_COUNTER++
      echo "[PASS] '$METRIC_NAME' present"
    else
      echo "[FAIL] '$METRIC_NAME' **not present**"
      echo $METRIC_NAME >> $OUTPUT_MISSING_METRICS_FILE
    fi
  done

  if (($SUCCESS_COUNTER == $TOTAL_COUNTER)); then
    echo "--- [ TEST SUCCESS ] ---"
    echo "All expected metrics were present in Prometheus/Mimir ($PROMETHEUS_INSTANCE)"
  elif (( $(echo "$SUCCESS_COUNTER >= ($TOTAL_COUNTER*$METRICS_SUCCESS_RATE_REQUIRED)" | bc -l) )); then
    echo "--- [ TEST SUCCESS (with warnings) ] ---"
    echo "$SUCCESS_COUNTER out of $TOTAL_COUNTER expected metrics were present in Prometheus/Mimir ($PROMETHEUS_INSTANCE)"
    echo "This is considered a PASS as it exceeds a success rate of $METRICS_SUCCESS_RATE_REQUIRED"
  elif (($SUCCESS_COUNTER == 0)); then
    echo "--- [ TEST FAIL ] ---"
    echo "None of the expected metrics were detected in Prometheus/Mimir ($PROMETHEUS_INSTANCE)"
    exit 1
  else
    echo "--- [ TEST FAIL ] ---"
    echo "$SUCCESS_COUNTER out of $TOTAL_COUNTER expected metrics were present in Prometheus/Mimir ($PROMETHEUS_INSTANCE)"
    echo "This is a FAIL as it falls below the required success rate of $METRICS_SUCCESS_RATE_REQUIRED"
    exit 1
  fi
}