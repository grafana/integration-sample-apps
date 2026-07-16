# MongoDB sample app

This sample application creates an Ubuntu VM integrated with Alloy for metric and log collection. This sample app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of MongoDB 8.0 using the Percona mongodb_exporter embedded within Alloy.

A built-in load generator seeds a user collection and runs a continuous insert/update/delete/query workload so the dashboards have live data for the operation, latency, oplog, document and (in the sharded topology) data-distribution panels.

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
   cd integration-sample-apps/sample-apps/mongodb
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VMs**: 
   Use `make run` to start the MongoDB sample app.

5. **Stop and clean Up**: 
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the MongoDB sample app as a sharded cluster (config server + two 3-member shards + mongos) for testing cluster dashboards.
- `make run-single`: Creates the lighter single three-member replicaset instead.
- `make clean`: Deletes all created VMs and performs cleanup.

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

### Load generator
- **Check service status**: Confirm the workload generator is running.
  ```bash
  systemctl status mongodb-loadgen.service
  ```
- **Check logs**: Review the generator output for connection or write errors.
  ```bash
  journalctl -u mongodb-loadgen.service
  ```
- **Script**: The workload is defined in `/usr/local/bin/loadgen.js` and writes to the `loadgen.events` collection (sharded with a hashed key in the cluster topology).
