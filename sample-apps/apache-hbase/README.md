# Apache HBase sample app

> Note: this sample application takes a really long time to setup as the install for HBase takes near 20 minutes on good days. Feel free to run a `make tail-install` to track install progress. The install is triggered in the background so expect a long time for the metrics to show up.

This sample application creates an Ubuntu VM integrated with Alloy for metric and log collection. It uses cloud-init and Make commands to ease setup, configuration, and monitoring of [Apache HBase](https://hbase.apache.org/), collecting HBase metrics and logs natively from HBase’s built-in `/prometheus` endpoints.

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
   cd integration-sample-apps/sample-apps/apache-hbase
   ```

2. **Set up default config**:
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**:
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VM**:
   Use `make run` to start the Apache HBase sample app.

5. **Stop and clean Up**:
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the Apache HBase sample app VM with HBase installed and configured.
- `make run-ci`: Runs in CI mode by cleaning, setting up default config, and launching the VM.
- `make stop`: Stops and removes the VM, then purges multipass resources.
- `make clean`: Removes generated configuration files and temporary resources.
- `make master-metrics`: Fetches metrics from the HBase Master's `/prometheus` endpoint.
- `make regionserver-metrics`: Fetches metrics from the HBase RegionServer's `/prometheus` endpoint.
- `make system-status`: Shows the status of the HBase systemd service.

## Default configuration variables

- `prom_pass`: Your Prometheus password.
- `prom_user`: Your Prometheus username.
- `prom_url`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9090/api/v1/push`).
- `loki_url`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.
- `interval`: Metrics collection interval (default: `10s`).
- `hbase_version`: Version of Apache HBase to install (default: `2.5.10`).

You can edit these variables in `jinja/variables/cloud-init.yaml` before rendering the configuration.

## HBase configuration

The sample app installs and configures Apache HBase in standalone mode:

- **HBase Version**: 2.5.10 (configurable via `hbase_version` variable)
- **Java**: OpenJDK 11
- **Mode**: Standalone (single-node with embedded ZooKeeper)
- **Storage Configuration**:
  - Root directory: `/opt/volume/hbase`
  - ZooKeeper data: `/opt/volume/hbase/zookeeper`
- **Web UI Ports**:
  - Master Web UI: port 16010
  - RegionServer Web UI: port 16030
- **Prometheus Metrics Endpoints**:
  - HBase Master: `http://localhost:16010/prometheus`
  - HBase RegionServer: `http://localhost:16030/prometheus`

No JMX exporter or sidecar is needed: Alloy natively scrapes metrics from these `/prometheus` endpoints exposed by HBase.

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

### Apache HBase
- **Check HBase service status**: Confirm that HBase is running.
  ```bash
  systemctl status hbase.service
  ```
- **Check HBase shell**: Access the HBase shell to verify it's working.
  ```bash
  sudo -u hbase /opt/hbase/bin/hbase shell
  ```
  Then try commands like:
  ```
  status
  list
  exit
  ```
- **Check Master Web UI**: Access the HBase Master web interface.
  ```bash
  curl localhost:16010
  ```
- **Check RegionServer Web UI**: Access the HBase RegionServer web interface.
  ```bash
  curl localhost:16030
  ```
- **Check HBase logs**: Review HBase logs for any issues.
  ```bash
  sudo -u hbase tail -f /opt/hbase/logs/hbase-hbase-master-*.log
  sudo -u hbase tail -f /opt/hbase/logs/hbase-hbase-regionserver-*.log
  ```

### Metrics endpoints
- **Check Master metrics**: Verify metrics are exposed by HBase Master at the `/prometheus` endpoint.
  ```bash
  curl localhost:16010/prometheus
  ```
- **Check RegionServer metrics**: Verify metrics are exposed by the RegionServer at the `/prometheus` endpoint.
  ```bash
  curl localhost:16030/prometheus
  ```

### Load Generator
- **Check load generator status**: Confirm that the load generator is running.
  ```bash
  systemctl status hbase-loadgen.service
  ```
- **Check load generator logs**: View the load generator activity.
  ```bash
  journalctl -u hbase-loadgen.service -f
  ```

## Troubleshooting

For debugging and troubleshooting, you can access the VM directly using:
```bash
multipass shell apache-hbase-sample-app
```

Common troubleshooting steps:

1. **HBase won't start**: Check Java installation and JAVA_HOME
   ```bash
   java -version
   echo $JAVA_HOME
   ```

2. **Metrics not available**: Ensure the `/prometheus` endpoints are enabled and reachable. Try:
   ```bash
   curl localhost:16010/prometheus
   curl localhost:16030/prometheus
   ```

3. **Permission issues**: Check file ownership
   ```bash
   ls -la /opt/hbase
   ls -la /opt/volume/hbase
   ```

4. **Port conflicts**: Verify ports are not in use
   ```bash
   sudo netstat -tlnp | grep -E '(16010|16030)'
   ```

## Updating Versions

### Updating the Apache HBase Version

To target a different version of HBase, simply replace the `hbase_version` (default=`2.5.10`) within your variables with your desired version.

Example `jinja/variables/cloud-init.yaml`:
```yaml
interval: "10s"
loki_url: http://your-loki-instance:3100/loki/api/v1/push
loki_user: your_loki_username
loki_pass: your_loki_password
prom_url: http://your-prometheus-instance:9090/api/v1/push
prom_user: your_prometheus_username
prom_pass: your_prometheus_password
hbase_version: 2.5.10
```

## Testing HBase

Once the VM is running, you can test HBase functionality:

1. **Access HBase shell**:
   ```bash
   multipass exec apache-hbase-sample-app -- sudo -u hbase /opt/hbase/bin/hbase shell
   ```

2. **Create a test table**:
   ```
   create 'test', 'cf'
   ```

3. **Insert data**:
   ```
   put 'test', 'row1', 'cf:a', 'value1'
   put 'test', 'row2', 'cf:b', 'value2'
   ```

4. **Scan the table**:
   ```
   scan 'test'
   ```

5. **Exit the shell**:
   ```
   exit
   ```

The included load generator automatically creates a `test_table` and periodically inserts data to generate metrics.
