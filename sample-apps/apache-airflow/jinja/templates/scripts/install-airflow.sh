#!/bin/bash

set -e

# Pre-requisites
# - Python 3.8+


{% set airflow_version = airflow_version | default("2.9.3") %}

AIRFLOW_VERSION="{{ airflow_version }}"
airflow_download_dir="$(mktemp -d)"

sudo apt install -y python3.12 python3-pip python3.12-venv


# Verify Python
python3 --version
if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
    echo "Python 3.8+ required"
    exit 1
fi

# Create airflow user first
sudo useradd -m -s /bin/bash airflow

# Create virtual environment with error checking
VENV_PATH="${VENV_PATH:-/home/airflow/airflow-venv}"
if [ ! -d "$VENV_PATH" ]; then
    sudo -u airflow python3 -m venv "$VENV_PATH"
fi

# Activate and upgrade pip
sudo -u airflow bash -c "source $VENV_PATH/bin/activate && pip install --upgrade pip"

# Verify constraint file exists before using
PYTHON_VERSION="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

if curl --fail --silent --head "$CONSTRAINT_URL" > /dev/null; then
    sudo -u airflow bash -c "source $VENV_PATH/bin/activate && pip install 'apache-airflow['statsd']==${AIRFLOW_VERSION}' --constraint '${CONSTRAINT_URL}' --no-color"
else
    echo "Warning: Constraint file not found, installing without constraints"
    sudo -u airflow bash -c "source $VENV_PATH/bin/activate && pip install 'apache-airflow['statsd']==${AIRFLOW_VERSION}' --no-color"
fi

# Install statsd client for metrics
sudo -u airflow bash -c "source $VENV_PATH/bin/activate && pip install statsd --no-color"

# Create systemd service file for Airflow
sudo tee /etc/systemd/system/airflow.service > /dev/null << 'EOF'
[Unit]
Description=Apache Airflow

[Service]
Type=simple
User=airflow
Group=airflow
Environment=PATH=/home/airflow/airflow-venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WorkingDirectory=/home/airflow
ExecStart=/home/airflow/airflow-venv/bin/airflow standalone
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service
sudo systemctl daemon-reload
sudo systemctl enable airflow.service
sudo systemctl start airflow.service



# Wait for airflow.cfg to appear
echo "Waiting for airflow.cfg to appear..."
timeout=10
counter=0
while [ $counter -lt $timeout ]; do
    if [ -f "/home/airflow/airflow/airflow.cfg" ]; then
        echo "airflow.cfg found!"
        break
    fi
    sleep 1
    counter=$((counter + 1))
done

if [ $counter -eq $timeout ]; then
    echo "Error: airflow.cfg did not appear within ${timeout} seconds"
    exit 1
fi


# Modify airflow.cfg to enable StatsD metrics
sudo sed -i 's/statsd_on = False/statsd_on = True/' /home/airflow/airflow/airflow.cfg
sudo sed -i 's/statsd_prefix = airflow/statsd_prefix = airflow/' /home/airflow/airflow/airflow.cfg

# Restart the service to apply the configuration change
sudo systemctl restart airflow.service

echo "Airflow installation completed!"

# Run DAG triggering in the background
(
    echo "Starting background DAG triggering process..."
    
    # Wait for Airflow to be fully operational
    echo "Waiting for Airflow to be fully operational..."
    timeout=120
    counter=0
    while [ $counter -lt $timeout ]; do
        if sudo -u airflow bash -c "source $VENV_PATH/bin/activate && airflow dags list" > /dev/null 2>&1; then
            echo "Airflow is operational!"
            break
        fi
        sleep 5
        counter=$((counter + 5))
    done

    if [ $counter -ge $timeout ]; then
        echo "Warning: Airflow may not be fully operational yet"
    else
        # Check if there are any DAGs available and trigger one
        echo "Checking for available DAGs..."
        available_dags=$(sudo -u airflow bash -c "source $VENV_PATH/bin/activate && airflow dags list --output plain" 2>/dev/null | tail -n +2)
        
        if [ -n "$available_dags" ]; then
            # Get the first available DAG
            first_dag=$(echo "$available_dags" | head -n 1 | awk '{print $1}')
            echo "Triggering DAG run for: $first_dag"
            sudo -u airflow bash -c "source $VENV_PATH/bin/activate && airflow dags trigger $first_dag"
            echo "DAG run triggered successfully!"
        else
            echo "No DAGs found to trigger"
        fi
    fi
) >> /home/ubuntu/dag-trigger.log 2>&1 &

echo "DAG triggering started in background. Check /home/ubuntu/dag-trigger.log for progress."
