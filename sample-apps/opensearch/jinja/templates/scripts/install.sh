#! /bin/bash

{% set opensearch_version = opensearch_version | default("2.17.1") %}
{% set opensearch_password = opensearch_password | default("DevPass123!2025") %}

set -e

ARCH=$(uname -m)

case $ARCH in
  x86_64)
    install_link="https://artifacts.opensearch.org/releases/bundle/opensearch/{{opensearch_version}}/opensearch-{{opensearch_version}}-linux-x64.deb"
    ;;
  aarch64)
    install_link="https://artifacts.opensearch.org/releases/bundle/opensearch/{{opensearch_version}}/opensearch-{{opensearch_version}}-linux-arm64.deb"
    ;;
  *)
    echo "Error: Unsupported architecture $ARCH"
    exit 1
    ;;
esac

echo "Architecture: $ARCH"
echo "Downloading OpenSearch from: ${install_link}"

# Remove any existing file first
sudo rm -f /home/ubuntu/opensearch.deb

# Download with better error handling
if ! sudo curl -L -f --retry 3 --retry-delay 2 "${install_link}" -o /home/ubuntu/opensearch.deb; then
    echo "Error: Failed to download OpenSearch package"
    exit 1
fi


echo "Installing OpenSearch..."
if ! sudo env OPENSEARCH_INITIAL_ADMIN_PASSWORD={{opensearch_password}} dpkg -i /home/ubuntu/opensearch.deb; then
    echo "Error: Failed to install OpenSearch package"
    exit 1
fi


echo "Configuring OpenSearch service..."
sudo systemctl daemon-reload
sudo systemctl enable opensearch
sudo systemctl start opensearch

echo "OpenSearch installation completed successfully"







