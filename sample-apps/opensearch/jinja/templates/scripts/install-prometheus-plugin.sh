#!/bin/bash

set -e

{% set opensearch_version = opensearch_version | default("2.17.1") %}


# Compatibility Matrix for Prometheus Plugin: https://github.com/Aiven-Open/prometheus-exporter-plugin-for-opensearch?tab=readme-ov-file#compatibility-matrix
case {{ opensearch_version }} in
    2.17.1)
        plugin_version="2.17.1.0"
        ;;
    2.17.0)
        plugin_version="2.17.0.0"
        ;;
    2.16.0)
        plugin_version="2.16.0.0"
        ;;
    2.15.0)
        plugin_version="2.15.0.0"
        ;;
    2.14.0)
        plugin_version="2.14.0.0"
        ;;
    2.13.0)
        plugin_version="2.13.0.0"
        ;;
    2.12.0)
        plugin_version="2.12.0.0"
        ;;
    2.11.1)
        plugin_version="2.11.1.0"
        ;;
    2.11.0)
        plugin_version="2.11.0.0"
        ;;
    2.10.0)
        plugin_version="2.10.0.0"
        ;;
    2.9.0)
        plugin_version="2.9.0.0"
        ;;
    2.8.0)
        plugin_version="2.8.0.0"
        ;;
    2.7.0)
        plugin_version="2.7.0.0"
        ;;
    2.6.0)
        plugin_version="2.6.0.0"
        ;;
    2.5.0)
        plugin_version="2.5.0.0"
        ;;
    2.4.1)
        plugin_version="2.4.1.0"
        ;;
    2.4.0)
        plugin_version="2.4.0.0"
        ;;
    2.3.0)
        plugin_version="2.3.0.0"
        ;;
    2.2.1)
        plugin_version="2.2.1.0"
        ;;
    2.2.0)
        plugin_version="2.2.0.0"
        ;;
    2.1.0)
        plugin_version="2.1.0.0"
        ;;
    2.0.1)
        plugin_version="2.0.1.0"
        ;;
    2.0.0)
        plugin_version="2.0.0.0"
        ;;
    2.0.0-rc1)
        plugin_version="2.0.0.0-rc1"
        ;;
    1.3.19)
        plugin_version="1.3.19.0"
        ;;
    1.3.18)
        plugin_version="1.3.18.0"
        ;;
    1.3.17)
        plugin_version="1.3.17.0"
        ;;
    1.3.16)
        plugin_version="1.3.16.0"
        ;;
    1.3.15)
        plugin_version="1.3.15.0"
        ;;
    1.3.14)
        plugin_version="1.3.14.0"
        ;;
    1.3.13)
        plugin_version="1.3.13.0"
        ;;
    1.3.12)
        plugin_version="1.3.12.0"
        ;;
    1.3.11)
        plugin_version="1.3.11.0"
        ;;
    1.3.10)
        plugin_version="1.3.10.0"
        ;;
    1.3.9)
        plugin_version="1.3.9.0"
        ;;
    1.3.8)
        plugin_version="1.3.8.0"
        ;;
    1.3.7)
        plugin_version="1.3.7.0"
        ;;
    1.3.6)
        plugin_version="1.3.6.0"
        ;;
    1.3.5)
        plugin_version="1.3.5.0"
        ;;
    1.3.4)
        plugin_version="1.3.4.0"
        ;;
    1.3.3)
        plugin_version="1.3.3.0"
        ;;
    1.3.2)
        plugin_version="1.3.2.0"
        ;;
    1.3.1)
        plugin_version="1.3.1.0"
        ;;
    1.3.0)
        plugin_version="1.3.0.0"
        ;;
    *)
        echo "Unsupported OpenSearch version: $opensearch_version"
        echo "Please check the compatibility matrix at: https://github.com/Aiven-Open/prometheus-exporter-plugin-for-opensearch?tab=readme-ov-file#compatibility-matrix"
        exit 1
        ;;
esac



echo "Using plugin version: $plugin_version for OpenSearch version: $opensearch_version"

# Install the Prometheus plugin
# For testing, you can use this command with the default version (2.17.1):
# sudo /usr/share/opensearch/bin/opensearch-plugin install https://github.com/Aiven-Open/prometheus-exporter-plugin-for-opensearch/releases/download/2.17.1.0/prometheus-exporter-2.17.1.0.zip
sudo /usr/share/opensearch/bin/opensearch-plugin install https://github.com/Aiven-Open/prometheus-exporter-plugin-for-opensearch/releases/download/$plugin_version/prometheus-exporter-$plugin_version.zip

# Configure OpenSearch to disable security for Prometheus metrics access
echo "Configuring OpenSearch security settings..."
echo "plugins.security.disabled: true" | sudo tee -a /etc/opensearch/opensearch.yml

# Restart OpenSearch to apply the changes
echo "Restarting OpenSearch service..."
sudo systemctl restart opensearch

echo "Prometheus plugin installation and configuration completed."
echo "You can now access metrics at: http://localhost:9200/_prometheus/metrics"
