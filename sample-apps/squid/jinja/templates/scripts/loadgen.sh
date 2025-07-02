{% raw %}#!/bin/bash

# Load generation script for Squid proxy
# This script generates various types of HTTP traffic through the squid proxy


# Configuration
PROXY_HOST="localhost"
PROXY_PORT="3128"
PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"

# run a simple http server just serving the working directory
python3 -m http.server --bind localhost 8080 &

while true; do 
    # generate successful proxy request
    for i in {1..5}; do
        curl -x http://${PROXY_HOST}:${PROXY_PORT} http://localhost:8080/index.html
    done

    # generate failed proxy request
    curl -x http://${PROXY_HOST}:${PROXY_PORT} http://localhost:8080/index2.html
    sleep 15
done

{% endraw %}