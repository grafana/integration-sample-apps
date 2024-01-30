#!/bin/bash

VM_NAME=$1
LDAP_USER="cn=monitor,dc=nodomain"
LDAP_PASS="pass"
EXPORTER_REPO="https://github.com/tomcz/openldap_exporter.git"
EXPORTER_DIR="openldap_exporter"
PROM_ADDR=":8080"
LDAP_ADDR="localhost:389"
INTERVAL="10s"

# Install necessary tools and clone the OpenLDAP Exporter repository
multipass exec "$VM_NAME" -- sudo apt update
multipass exec "$VM_NAME" -- sudo apt install -y git golang-go
multipass exec "$VM_NAME" -- git clone "$EXPORTER_REPO" "$EXPORTER_DIR"

# Build the exporter
multipass exec "$VM_NAME" -- bash -c "cd $EXPORTER_DIR/cmd/openldap_exporter && go build ."

# Make the exporter executable
multipass exec "$VM_NAME" -- chmod +x "$EXPORTER_DIR/cmd/openldap_exporter/openldap_exporter"

# Create a systemd service file for the OpenLDAP Exporter
SERVICE_FILE_CONTENT="[Unit]\nDescription=OpenLDAP Exporter\nAfter=network.target\n\n[Service]\nType=simple\nUser=ubuntu\nExecStart=/home/ubuntu/$EXPORTER_DIR/cmd/openldap_exporter/openldap_exporter --promAddr \"$PROM_ADDR\" --ldapAddr \"$LDAP_ADDR\" --ldapUser \"$LDAP_USER\" --ldapPass \"$LDAP_PASS\" --interval \"$INTERVAL\"\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target"
multipass exec "$VM_NAME" -- bash -c "echo -e \"$SERVICE_FILE_CONTENT\" | sudo tee /etc/systemd/system/openldap_exporter.service"

# Reload systemd and enable the OpenLDAP Exporter service
multipass exec "$VM_NAME" -- sudo systemctl daemon-reload
multipass exec "$VM_NAME" -- sudo systemctl enable openldap_exporter.service

# Start the service
multipass exec "$VM_NAME" -- sudo systemctl start openldap_exporter.service

echo "OpenLDAP Exporter setup, service enabled, and started."
