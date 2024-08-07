#!/bin/bash

# Install dependencies if not already installed
sudo apt-get update
sudo apt-get install -y wget

# Copy the Grafana Agent configuration file from local directory to VM
GRAFANA_AGENT_YAML="grafana-agent.yaml"

# Check if the configuration file already exists
if [ -f "/etc/grafana-agent.yaml" ]; then
    # Backup the existing configuration file
    sudo mv /etc/grafana-agent.yaml /etc/grafana-agent.yaml.backup
fi

# Download the specified version of Grafana Agent for arm64 architecture
GRAFANA_AGENT_VERSION="0.39.0-1"
GRAFANA_AGENT_FILE="grafana-agent-${GRAFANA_AGENT_VERSION}.arm64.deb"
GRAFANA_AGENT_URL="https://github.com/grafana/agent/releases/download/v0.39.0/${GRAFANA_AGENT_FILE}"

wget "$GRAFANA_AGENT_URL"

# Install the Grafana Agent .deb package
if [ -f "$GRAFANA_AGENT_FILE" ]; then
    sudo dpkg -i "$GRAFANA_AGENT_FILE"

    if [ -f "/etc/grafana-agent.yaml.backup" ]; then
        sudo mv /etc/grafana-agent.yaml.backup /etc/grafana-agent.yaml
    fi

    # Set up Grafana Agent as a systemd service
    sudo tee /etc/systemd/system/grafana-agent.service > /dev/null <<EOF
[Unit]
Description=Grafana Agent
Wants=network-online.target
After=network-online.target

[Service]
User=grafana-agent
ExecStart=/usr/bin/grafana-agent -config.file /etc/grafana-agent.yaml

[Install]
WantedBy=multi-user.target
EOF

    # Add grafana-agent user to the solr group (for log access)
    sudo usermod -a -G solr grafana-agent

    # Reload systemd, enable and start Grafana Agent service
    sudo systemctl daemon-reload
    sudo systemctl enable grafana-agent.service
    sudo systemctl start grafana-agent.service
else
    echo "Failed to download Grafana Agent."
fi
