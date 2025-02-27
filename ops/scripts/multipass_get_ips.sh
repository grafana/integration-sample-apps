#!/bin/bash

# Grab first (internal) IPv4 address assigned to a given multipass instance
multipass info $1 --format json | jq -r .info.$1.ipv4[0]
