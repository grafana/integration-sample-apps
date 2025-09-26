#!/bin/bash

echo "-- Configuring /etc/hosts for K3d setup --"
DNSSERVER=$(resolvectl status | grep 'Current DNS Server: ' | grep -o -E '[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}')

HOSTS="${DNSSERVER} loki.k3d.localhost mimir.k3d.localhost cortex.k3d.localhost"

echo "${HOSTS}" | sudo tee -a /etc/hosts
