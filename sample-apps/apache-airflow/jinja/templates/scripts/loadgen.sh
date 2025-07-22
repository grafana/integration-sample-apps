#!/bin/bash

set -e

VENV_PATH="/home/airflow/airflow-venv"

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

echo "Starting continuous DAG triggering..."

while true; do 
    echo "Checking for available DAGs..."
    available_dags=$(sudo -u airflow bash -c "source $VENV_PATH/bin/activate && airflow dags list --output plain" 2>/dev/null | tail -n +2)
    
    if [ -n "$available_dags" ]; then
        # Get the first available DAG
        first_dag=$(echo "$available_dags" | head -n 1 | awk '{print $1}')
        echo "Triggering DAG run for: $first_dag"
        
        if sudo -u airflow bash -c "source $VENV_PATH/bin/activate && airflow dags trigger $first_dag" > /dev/null 2>&1; then
            echo "DAG run triggered successfully!"
        else
            echo "Failed to trigger DAG run for: $first_dag"
        fi
    else
        echo "No DAGs found to trigger"
    fi
    
    echo "Waiting 30 seconds before next trigger..."
    sleep 30
done 
