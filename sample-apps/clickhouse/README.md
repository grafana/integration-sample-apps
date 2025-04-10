# ClickHouse Sample App

This sample application creates an Ubuntu VM with ClickHouse server installed and integrated with Alloy for metric and log collection. The app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of ClickHouse using Alloy.

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
   cd integration-sample-apps/sample-apps/clickhouse
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VMs**: 
   Use `make run` to start the ClickHouse sample app.

6. **Stop and clean Up**: 
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the ClickHouse sample app.
- `make clean`: Deletes all created VMs and performs cleanup.
- `make clickhouse-shell`: Opens ClickHouse shell in the VM.
- `make clickhouse-status`: Checks the status of the ClickHouse server.

## Default configuration variables

- `prom_pass`: Your Prometheus password.
- `prom_user`: Your Prometheus username.
- `prom_url`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9090/api/v1/push`).
- `loki_url`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.

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

### ClickHouse
- **Check service status**: Confirm that ClickHouse server is running.
  ```bash
  systemctl status clickhouse-server
  ```
- **Connect to ClickHouse**: Use ClickHouse client to connect to the server.
  ```bash
  clickhouse-client
  ```
- **Query example data**: Execute sample queries to verify ClickHouse is working correctly.
  ```sql
  SELECT * FROM example.metrics;
  ```
- **Check logs**: Review ClickHouse logs for any errors.
  ```bash
  cat /var/log/clickhouse-server/clickhouse-server.log
  ```

## Monitoring
The sample app sets up Alloy to collect and forward metrics and logs from ClickHouse:

- **Metrics**: Collected using the ClickHouse exporter and forwarded to Prometheus.
- **Logs**: Collected from `/var/log/clickhouse-server/` and forwarded to Loki.

## Troubleshooting
If you encounter issues with the sample app, check the following:

1. Ensure ClickHouse server is running (`make clickhouse-status`).
2. Check Alloy configuration and logs for any errors.
3. Verify network connectivity to your Prometheus and Loki instances. 