#!/bin/bash

# Squid setup script for load generation
# This should be run once during setup/installation

echo "Configuring Squid for load generation..."

# Allow localhost access (both from and to localhost)
sudo tee -a /etc/squid/squid.conf << 'EOF'
# Allow requests from localhost
http_access allow localhost
# Allow requests to localhost (needed for load generation)
acl localhost_servers dst 127.0.0.1/32
http_access allow localhost_servers
EOF

echo "Restarting Squid service..."
sudo systemctl restart squid

echo "Squid configuration complete!" 
