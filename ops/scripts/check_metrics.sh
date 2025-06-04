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

# Track overall test status
OVERALL_STATUS=0

check_metrics() {
  # Expects two parameters, expected_metrics file and .config file
  # Existence should already be confirmed by the time this function is invoked
  # $1 is sample app name  
  # $2 is prometheus instance
  # $3 is expected metrics file
  # $4 is .config file, to source
  source $4
  SUCCESS_COUNTER=0
  TOTAL_COUNTER=0
  local status=0
  
  # Group the commands for the counter to work as intended
  cat $3 | 
  {
    # Setup grep statement
    GREP_REGEX=$JOB_LABEL

    echo "--- [ Checking Metrics for $1 using job='$JOB_LABEL' ] ---"
    if [[ ! -z "$EXTRA_GREP_REGEX" ]]; then
      GREP_REGEX="$GREP_REGEX|$EXTRA_GREP_REGEX"
      echo "---- [ EXTRA_GREP_REGEX provided: "$EXTRA_GREP_REGEX" ] ----"
      echo "---- [ GREP regex now: "$GREP_REGEX" ] ----"
    fi
    while read METRIC_NAME; do
      let TOTAL_COUNTER++
      if curl -s http://$2/prometheus/api/v1/query?query=$METRIC_NAME%7Bjob=~\"$JOB_LABEL\"%7D | jq -r .data.result[0].metric | grep -q -E "$GREP_REGEX"; then
        let SUCCESS_COUNTER++
        echo "[PASS] '$METRIC_NAME' present"
      else
        echo "[FAIL] '$METRIC_NAME' **not present**"
        echo $METRIC_NAME >> $OUTPUT_MISSING_METRICS_FILE
      fi
    done

    if (($SUCCESS_COUNTER == $TOTAL_COUNTER)); then
      echo "--- [ TEST SUCCESS ] ---"
      echo "All expected metrics were present in Prometheus/Mimir ($2)"
      exit 0
    elif (( $(echo "$SUCCESS_COUNTER >= ($TOTAL_COUNTER*$METRICS_SUCCESS_RATE_REQUIRED)" | bc -l) )); then
      echo "--- [ TEST SUCCESS (with warnings) ] ---"
      echo "$SUCCESS_COUNTER out of $TOTAL_COUNTER expected metrics were present in Prometheus/Mimir ($PROMETHEUS_INSTANCE)"
      echo "This is considered a PASS as it exceeds a success rate of $METRICS_SUCCESS_RATE_REQUIRED"
      exit 0
    elif (($SUCCESS_COUNTER == 0)); then
      echo "--- [ TEST FAIL ] ---"
      echo "None of the expected metrics were detected in Prometheus/Mimir ($2)"
      exit 1
    else
      echo "--- [ TEST FAIL ] ---"
      echo "$SUCCESS_COUNTER out of $TOTAL_COUNTER expected metrics were present in Prometheus/Mimir ($PROMETHEUS_INSTANCE)"
      echo "This is a FAIL as it falls below the required success rate of $METRICS_SUCCESS_RATE_REQUIRED"
      exit 1
    fi
  }
  status=${PIPESTATUS[0]}
  return $status
}

TESTS_PATH="$SAMPLE_APP_PATH/$SAMPLE_APP_NAME/tests"
EXPECTED_METRICS_LIST=`ls $TESTS_PATH/metrics/*`
if [ -z "$EXPECTED_METRICS_LIST" ]; then
  echo "[FAIL] Incompatible sample-app or no expected metrics files provided."
  exit 1
else
  for METRICS_FILE_PATH in $EXPECTED_METRICS_LIST
  do
    METRICS_FILE=`basename $METRICS_FILE_PATH`

    # For each expected metrics file, check if a matching config file exists
    CONFIG_FILE_PATH="$TESTS_PATH/configs/$METRICS_FILE.config"
    if [ -f $CONFIG_FILE_PATH ]; then
      # Given a matching pair is found, we can execute the tests
      check_metrics $SAMPLE_APP_NAME $PROMETHEUS_INSTANCE $METRICS_FILE_PATH $CONFIG_FILE_PATH
      if [ $? -gt 0 ]; then
        echo "Test failed for $METRICS_FILE"
        OVERALL_STATUS=1
      fi
    else
      echo "[FAIL] Matching config file for $METRICS_FILE not found in $TESTS_PATH/configs/"
      OVERALL_STATUS=1
    fi
  done
fi

echo "--- [ FINAL TEST RESULTS ] ---"
if [ $OVERALL_STATUS == 0 ]; then
  echo "All test cases completed successfully"
else
  echo "Some test cases failed"
fi

exit $OVERALL_STATUS
