#!/bin/bash

set -e

VENV_PATH="/home/airflow/airflow-venv"
DAG_ID="example_bash_operator"

echo "Waiting for Airflow to be fully operational..."
timeout=120
counter=0
while [ $counter -lt $timeout ]; do
    if sudo -u airflow bash -c "source $VENV_PATH/bin/activate && airflow dags list" > /dev/null 2>&1; then
        echo "Airflow is operational!"
        break
    fi
    echo "Waiting for Airflow... ($counter/$timeout seconds)"
    sleep 5
    counter=$((counter + 5))
done

if [ $counter -ge $timeout ]; then
    echo "Error: Airflow did not become operational within ${timeout} seconds"
    exit 1
fi

sudo -u airflow bash -c "source $VENV_PATH/bin/activate && airflow dags unpause $DAG_ID" > /dev/null 2>&1 \
    || echo "Failed to unpause $DAG_ID"

echo "Starting continuous DAG triggering..."

while true; do
    echo "Triggering DAG run for: $DAG_ID"

    if sudo -u airflow bash -c "source $VENV_PATH/bin/activate && airflow dags trigger $DAG_ID" > /dev/null 2>&1; then
        echo "DAG run triggered successfully!"
    else
        echo "Failed to trigger DAG run for: $DAG_ID"
    fi

    echo "Waiting 30 seconds before next trigger..."
    sleep 30
done 
