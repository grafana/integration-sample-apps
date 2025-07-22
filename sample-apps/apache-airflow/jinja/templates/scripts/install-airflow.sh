#!/bin/bash

set -e

# Pre-requisites
# - Python 3.8+

{% set airflow_version = airflow_version | default("2.9.3") %}
{% set wait_timeout = wait_timeout | default(120) %}

function wait_for_airflow {
    echo "Waiting for Airflow to be fully operational..."
    counter=0
    timeout={{ wait_timeout }}
    while [ $counter -lt $timeout ]; do
        if sudo -u airflow bash -c "source $VENV_PATH/bin/activate && airflow dags list" > /dev/null 2>&1; then
            break
        fi
        sleep 1
        counter=$((counter + 1))
    done
    if [ $counter -eq $timeout ]; then
        echo "Error: Airflow did not become operational within ${timeout} seconds"
        exit 1
    fi
}

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

# Create initialization script
sudo tee /home/airflow/init-airflow.sh > /dev/null << 'EOF'
#!/bin/bash
set -e

VENV_PATH="/home/airflow/airflow-venv"
export AIRFLOW_HOME="/home/airflow/airflow"

# Initialize database
source $VENV_PATH/bin/activate
airflow db migrate

# Create admin user (ignore if it already exists)
airflow users create \
    --username admin \
    --firstname Airflow \
    --lastname Admin \
    --role Admin \
    --email admin@example.com \
    --password admin || echo "Admin user already exists"

echo "Airflow initialized successfully"
EOF

sudo chmod +x /home/airflow/init-airflow.sh
sudo chown airflow:airflow /home/airflow/init-airflow.sh

# Create systemd service file for Airflow
sudo tee /etc/systemd/system/airflow.service > /dev/null << 'EOF'
[Unit]
Description=Apache Airflow

[Service]
Type=simple
User=airflow
Group=airflow
Environment=PATH=/home/airflow/airflow-venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=AIRFLOW_HOME=/home/airflow/airflow
WorkingDirectory=/home/airflow
ExecStartPre=/home/airflow/init-airflow.sh
ExecStart=/home/airflow/airflow-venv/bin/airflow standalone
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service to create all the configuration files
sudo systemctl daemon-reload
sudo systemctl enable airflow.service
sudo systemctl start airflow.service

wait_for_airflow

# Modify airflow.cfg to enable StatsD metrics
sudo sed -i 's/statsd_on = False/statsd_on = True/' /home/airflow/airflow/airflow.cfg
sudo sed -i 's/statsd_prefix = airflow/statsd_prefix = airflow/' /home/airflow/airflow/airflow.cfg

# Restart the service to apply the configuration change
sudo systemctl restart airflow.service

wait_for_airflow

echo "Airflow installation completed!"
