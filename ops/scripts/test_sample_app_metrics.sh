#!/bin/bash

ROOT_DIR=$(git rev-parse --show-toplevel)
OPS_DIR=${ROOT_DIR}/ops
SAMPLE_APPS_DIR=${ROOT_DIR}/sample-apps

# This script will check each metric of a provided metric list against a provided Prometheus host
# and calculate the success rate

SAMPLE_APP_NAME=$1
PROMETHEUS_INSTANCE=$2

# Global default variables are set via ./ops/.defaultconfig. Required are:
# - SAMPLE_APP_PATH
# - SAMPLE_APP_CONFIG_FILE
# - OUTPUT_MISSING_METRICS_FILE
# - METRICS_SUCCESS_RATE_REQUIRED
source "${OPS_DIR}/.defaultconfig"

DEFAULT_SUCCESS_RATE=$METRICS_SUCCESS_RATE_REQUIRED

# Track overall test status
OVERALL_STATUS=0

check_metrics() {
  # Expects two parameters, expected_metrics file and .config file
  # Existence should already be confirmed by the time this function is invoked
  # $1 is sample app name
  # $2 is prometheus instance
  # $3 is expected metrics file
  # $4 is .config file, to source
  # Clear the keys a config owns so they cannot carry over between configs
  unset JOB_LABEL EXTRA_GREP_REGEX INSTANCE_FILTER
  METRICS_SUCCESS_RATE_REQUIRED=$DEFAULT_SUCCESS_RATE
  source $4

  # An empty JOB_LABEL leaves GREP_REGEX empty, which matches every metric
  if [ -z "$JOB_LABEL" ]; then
    echo "[FAIL] JOB_LABEL not set in $4"
    return 1
  fi

  # Setup grep statement
  GREP_REGEX=$JOB_LABEL
  if [[ ! -z "$EXTRA_GREP_REGEX" ]]; then
    GREP_REGEX="$GREP_REGEX|$EXTRA_GREP_REGEX"
    echo "---- [ EXTRA_GREP_REGEX provided: "$EXTRA_GREP_REGEX" ] ----"
    echo "---- [ GREP regex now: "$GREP_REGEX" ] ----"
  fi

  # `:-` only defaults an unset or empty value, so a whitespace-only filter would
  # word-split to nothing and check no instances at all
  INSTANCES=$(echo $INSTANCE_FILTER)
  [ -z "$INSTANCES" ] && INSTANCES=any

  STATUS=0
  for INSTANCE in $INSTANCES; do
    check_instance $1 $2 $3 $INSTANCE || STATUS=1
  done
  return $STATUS
}

check_instance() {
  # $1 is sample app name
  # $2 is prometheus instance
  # $3 is expected metrics file
  # $4 is an instance regex, or "any" for no instance filter
  SELECTOR="job=~\"$JOB_LABEL\""
  ON=""
  if [ "$4" != any ]; then
    SELECTOR="$SELECTOR,instance=~\"$4\""
    ON=" on instance '$4'"
  fi
  SUCCESS_COUNTER=0
  TOTAL_COUNTER=0

  {
    echo "--- [ Checking Metrics for $1 using job='$JOB_LABEL'$ON ] ---"
    # `|| [ -n ... ]` so a last line with no trailing newline is still read
    while read METRIC_NAME || [ -n "$METRIC_NAME" ]; do
      let TOTAL_COUNTER++
      if curl -s http://$2/prometheus/api/v1/query?query=$METRIC_NAME%7B$SELECTOR%7D | jq -r .data.result[0].metric | grep -q -E "$GREP_REGEX"; then
        let SUCCESS_COUNTER++
        echo "[PASS] '$METRIC_NAME' present"
      else
        echo "[FAIL] '$METRIC_NAME' **not present**"
        echo $METRIC_NAME >> $OUTPUT_MISSING_METRICS_FILE
      fi
    done

    if (($SUCCESS_COUNTER == $TOTAL_COUNTER)); then
      echo "--- [ TEST SUCCESS$ON ] ---"
      echo "All expected metrics were present in Prometheus/Mimir ($2)"
      return 0
    elif (( $(echo "$SUCCESS_COUNTER >= ($TOTAL_COUNTER*$METRICS_SUCCESS_RATE_REQUIRED)" | bc -l) )); then
      echo "--- [ TEST SUCCESS (with warnings)$ON ] ---"
      echo "$SUCCESS_COUNTER out of $TOTAL_COUNTER expected metrics were present in Prometheus/Mimir ($2)"
      echo "This is considered a PASS as it exceeds a success rate of $METRICS_SUCCESS_RATE_REQUIRED"
      return 0
    elif (($SUCCESS_COUNTER == 0)); then
      echo "--- [ TEST FAIL$ON ] ---"
      echo "None of the expected metrics were detected in Prometheus/Mimir ($2)"
      return 1
    else
      echo "--- [ TEST FAIL$ON ] ---"
      echo "$SUCCESS_COUNTER out of $TOTAL_COUNTER expected metrics were present in Prometheus/Mimir ($2)"
      echo "This is a FAIL as it falls below the required success rate of $METRICS_SUCCESS_RATE_REQUIRED"
      return 1
    fi
  } < "$3"
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
