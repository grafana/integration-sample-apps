# OpenSearch sample app

This sample application creates an Ubuntu VM integrated with Alloy for metric and log collection. This sample app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of [OpenSearch](https://opensearch.org/) using the [Prometheus Exporter Plugin for OpenSearch](https://github.com/Aiven-Open/prometheus-exporter-plugin-for-opensearch).

## Prerequisites

Before you begin, ensure you have the following installed:

- [Multipass](https://multipass.run/)
- Docker (for rendering the cloud-init configuration)
- Git (for cloning the repository)

## Quick Start for new users

To get started with the sample app, follow these steps:

1. **Clone the repository**: 
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd integration-sample-apps/sample-apps/opensearch
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VM**: 
   Use `make run` to start the OpenSearch sample app.

5. **Stop and clean Up**: 
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the OpenSearch sample app VM with OpenSearch installed and configured.
- `make run-ci`: Runs in CI mode by cleaning, setting up default config, and launching the VM.
- `make shell`: Opens a shell session to the running VM for debugging and troubleshooting.
- `make stop`: Stops and removes the VM, then purges multipass resources.
- `make clean`: Removes generated configuration files and temporary resources.

## Default configuration variables

- `prom_pass`: Your Prometheus password.
- `prom_user`: Your Prometheus username.
- `prom_url`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9090/api/v1/push`).
- `loki_url`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.
- `opensearch_version`: OpenSearch version to install (default: `2.17.1`).
- `opensearch_password`: Initial admin password for OpenSearch (default: `DevPass123!2025`).

## OpenSearch version compatibility

The sample app supports OpenSearch versions from 1.3.0 to 2.17.1, with automatic installation of the corresponding Prometheus Exporter Plugin version based on the [compatibility matrix](https://github.com/Aiven-Open/prometheus-exporter-plugin-for-opensearch?tab=readme-ov-file#compatibility-matrix).

**Default configuration**: OpenSearch 2.17.1 with Prometheus Exporter Plugin 2.17.1.0

## OpenSearch configuration

The sample app configures OpenSearch with the following settings:

- **Security disabled**: For simplified Prometheus metrics access (`plugins.security.disabled: true`)
- **Memory allocation**: 4GB RAM allocated to the VM for optimal performance
- **Disk space**: 10GB disk space to accommodate OpenSearch installation and data
- **Metrics endpoint**: Prometheus metrics exposed at `/_prometheus/metrics` on port 9200
- **Log collection**: OpenSearch logs collected from `/var/log/opensearch/opensearch.log`

## Validating services

### Alloy
- **Check service status**: Confirm that Alloy is running.
  ```bash
  systemctl status alloy.service
  ```
- **Review configuration**: Verify the configuration in `/etc/alloy/config.alloy` is correct.
- **Check logs**: Review Alloy logs for any connectivity or configuration issues.
  ```bash
  journalctl -u alloy.service
  ```

### OpenSearch
- **Check service status**: Confirm that OpenSearch is running.
  ```bash
  systemctl status opensearch.service
  ```
- **Verify database**: Check if OpenSearch is accessible and responsive.
  ```bash
  curl -X GET "localhost:9200/"
  ```
- **Check cluster health**: Verify the cluster status.
  ```bash
  curl -X GET "localhost:9200/_cluster/health?pretty"
  ```
- **Review configuration**: Check the OpenSearch configuration file.
  ```bash
  sudo cat /etc/opensearch/opensearch.yml
  ```
- **Check logs**: Review OpenSearch logs for any issues.
  ```bash
  sudo tail -f /var/log/opensearch/opensearch.log
  ```

### Prometheus Exporter Plugin
- **Test metrics endpoint**: Verify metrics are being exposed on the Prometheus endpoint.
  ```bash
  curl localhost:9200/_prometheus/metrics
  ```
- **Check plugin installation**: Verify the Prometheus plugin is installed.
  ```bash
  sudo /usr/share/opensearch/bin/opensearch-plugin list
  ```
- **Check plugin logs**: Review plugin logs for any issues.
  ```bash
  sudo journalctl -u opensearch.service | grep prometheus
  ```

## Troubleshooting

For debugging and troubleshooting, you can access the VM directly using:
```bash
make shell
```

This opens a shell session to the running VM where you can execute the validation commands above and investigate any issues with the services.

### Common issues

- **OpenSearch fails to start**: Check if sufficient memory is allocated (minimum 4GB recommended)
- **Prometheus metrics not accessible**: Verify that security is disabled in `/etc/opensearch/opensearch.yml`
- **Plugin installation fails**: Ensure the OpenSearch version is compatible with the plugin version
