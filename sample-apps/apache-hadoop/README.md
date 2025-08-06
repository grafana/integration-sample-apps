# Apache Hadoop sample app

This sample application creates an Ubuntu VM integrated with Alloy for metric and log collection. This sample app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of [Apache Hadoop](https://hadoop.apache.org/) using the [JMX Prometheus Exporter](https://github.com/prometheus/jmx_exporter).

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
   cd integration-sample-apps/sample-apps/apache-hadoop
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VM**: 
   Use `make run` to start the Apache Hadoop sample app.

5. **Stop and clean Up**: 
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the Apache Hadoop sample app VM with Hadoop installed and configured.
- `make run-ci`: Runs in CI mode by cleaning, setting up default config, and launching the VM.
- `make shell`: Opens a shell session to the running VM for debugging and troubleshooting.
- `make stop`: Stops and removes the VM, then purges multipass resources.
- `make clean`: Removes generated configuration files and temporary resources.
- `make resourcemanager-metrics`: Fetches metrics from the YARN ResourceManager endpoint.
- `make nodemanager-metrics`: Fetches metrics from the YARN NodeManager endpoint.
- `make hdfs-metrics`: Fetches metrics from the HDFS NameNode endpoint.
- `make datanode-metrics`: Fetches metrics from the HDFS DataNode endpoint.
- `make system-status`: Shows the status of all Hadoop-related systemd services.

## Default configuration variables

- `prom_pass`: Your Prometheus password.
- `prom_user`: Your Prometheus username.
- `prom_url`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9090/api/v1/push`).
- `loki_url`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.
- `interval`: Metrics collection interval (default: `10s`).
- `hadoop_version`: Version of Apache Hadoop to install (default: `3.3.6`).
- `jmx_exporter_version`: Version of JMX Prometheus Exporter to use (default: `1.3.0`).

You can edit these variables in `jinja/variables/cloud-init.yaml` before rendering the configuration.

## Hadoop configuration

The sample app installs and configures Apache Hadoop with both HDFS and YARN components:

- **Hadoop Version**: 3.3.6 (configurable via `hadoop_version` variable)
- **Java**: OpenJDK 11
- **HDFS Configuration**: 
  - NameNode: localhost:9000
  - DataNode storage: `/opt/volume/datanode`
  - NameNode storage: `/opt/volume/namenode`
- **YARN Configuration**: 
  - ResourceManager and NodeManager services
- **JMX Monitoring**: 
  - NameNode: port 8888
  - DataNode: port 8889
  - YARN ResourceManager: port 8886
  - YARN NodeManager: port 8887
  - JMX Prometheus Exporter version: 1.3.0

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

### Apache Hadoop HDFS
- **Check HDFS service status**: Confirm that Hadoop HDFS is running.
  ```bash
  systemctl status hadoop.service
  ```
- **Verify HDFS**: Check if HDFS is accessible and responsive.
  ```bash
  sudo -u hadoop hdfs dfsadmin -report
  ```
- **Check NameNode Web UI**: Access the NameNode web interface.
  ```bash
  curl localhost:9870
  ```
- **Check HDFS logs**: Review HDFS logs for any issues.
  ```bash
  sudo -u hadoop tail -f /opt/hadoop/logs/hadoop-hadoop-namenode-*.log
  sudo -u hadoop tail -f /opt/hadoop/logs/hadoop-hadoop-datanode-*.log
  ```

### Apache Hadoop YARN
- **Check YARN ResourceManager status**: Confirm that YARN ResourceManager is running.
  ```bash
  systemctl status hadoop-yarn-resourcemanager.service
  ```
- **Check YARN NodeManager status**: Confirm that YARN NodeManager is running.
  ```bash
  systemctl status hadoop-yarn-nodemanager.service
  ```
- **Check ResourceManager Web UI**: Access the ResourceManager web interface.
  ```bash
  curl localhost:8088
  ```
- **Check YARN logs**: Review YARN logs for any issues.
  ```bash
  sudo -u hadoop tail -f /opt/hadoop/logs/yarn-hadoop-resourcemanager-*.log
  sudo -u hadoop tail -f /opt/hadoop/logs/yarn-hadoop-nodemanager-*.log
  ```

### Configuration Files
- **Review Hadoop configuration**: Check the main Hadoop configuration files.
  ```bash
  cat /opt/hadoop/etc/hadoop/core-site.xml
  cat /opt/hadoop/etc/hadoop/hdfs-site.xml
  ```

### JMX Prometheus Exporter
- **Check NameNode metrics**: Verify NameNode metrics are exposed.
  ```bash
  curl localhost:8888/metrics
  ```
- **Check DataNode metrics**: Verify DataNode metrics are exposed.
  ```bash
  curl localhost:8889/metrics
  ```
- **Check ResourceManager metrics**: Verify ResourceManager metrics are exposed.
  ```bash
  curl localhost:8886/metrics
  ```
- **Check NodeManager metrics**: Verify NodeManager metrics are exposed.
  ```bash
  curl localhost:8887/metrics
  ```

## Troubleshooting

For debugging and troubleshooting, you can access the VM directly using:
```bash
make shell
```

This opens a shell session to the running VM where you can execute the validation commands above and investigate any issues with the services.


## Updating Versions of Apache Hadoop or JMX Prometheus Exporter
### Updating the Apache Hadoop Version

To target a different version of Hadoop, simply replace the `hadoop_version` (default=`3.3.0`) within your variables with your desired version.

### Updating the JMX Prometheus Exporter Version

To target a different version of the JMX Prometheus Exporter, simply update the `jmx_exporter_version` (default=`1.3.0`) with your desired version.

```yaml
interval: "10s"
loki_url: http://your-loki-instance:3100/loki/api/v1/push
loki_user: your_loki_username
loki_pass: your_loki_password
prom_url: http://your-prometheus-instance:9090/api/v1/push
prom_user: your_prometheus_username
prom_pass: your_prometheus_password
hadoop_version: 3.3.6
jmx_exporter_version: 1.3.0
```
