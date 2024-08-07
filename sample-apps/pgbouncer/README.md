# PgBouncer Sample App

This sample application creates a VM with a PgBouncer instance, integrated with Grafana Agent for metric and log collection. This sample app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of PgBouncer instances.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Multipass](https://multipass.run/)
- Docker (for rendering the cloud-init configuration)
- Git (for cloning the repository)

This sample app supports the following platforms: Linux, Windows, Darwin. The sample app was also tested with the ARM64 architecture.

## Quick Start for New Users

To get started with the sample app, follow these steps:

1. **Clone the Repository**: 
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd integration-sample-apps/pgbouncer
   ```

2. **Set Up Default Config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect the Grafana agent to an external Prometheus compatible TSDB and/or Loki server.

3. **Render Cloud-init Configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and Set Up VMs**: 
   Use `make run` to start the PgBouncer sample app.

5. **Fetch Prometheus Metrics**: 
   Fetch metrics from the Prometheus exporter and save them with `make fetch-prometheus-metrics`.

6. **Stop and Clean Up**: 
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make Commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the PgBouncer sample app.
- `make load-gen`: Sets up a load generation for the sample app.
- `make fetch-prometheus-metrics`: Fetches metrics from the Prometheus exporter and saves them to a local file.
- `make setup-grafana-agent`: Sets up Grafana Agent on each VM for forwarding metrics and logs.
- `make clean`: Deletes all created VMs and performs cleanup.

## Default Configuration Variables

- `prom_pass`: Your Prometheus password.
- `prom_user`: Your Prometheus username.
- `prom_url`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9090/api/v1/push`).
- `loki_url`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.

## Validating Services

### PGbouncer
- **Check Service Status**: Ensure the PGbouncer service is active and running.
  ```bash
  systemctl status pgbouncer
  ```
- **Check Logs**: If the service isn't running, check the logs for errors.
  ```bash
  journalctl -u pgbouncer
  ```

### Grafana Agent
- **Check Service Status**: Confirm that the Grafana Agent is running.
  ```bash
  systemctl status grafana-agent
  ```
- **Review Configuration**: Verify the configuration in `/etc/grafana-agent.yaml` is correct.
- **Check Logs**: Review Grafana Agent logs for any connectivity or configuration issues.
  ```bash
  journalctl -u grafana-agent
  ```
