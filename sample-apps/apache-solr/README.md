# Apache Solr and ZooKeeper Cluster sample app

This sample application creates 3 VMs each with an Apache Solr and ZooKeeper instance, integrated with Grafana Agent for metric and log collection. This sample app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of Apache Solr and ZooKeeper instances.

*Note*: In order to have a working apache-solr-zookeeper-instances, additional memory and cpu resources are allocated to each VM.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Multipass](https://multipass.run/)
- Docker (for rendering the cloud-init configuration)
- Git (for cloning the repository)

## Platform Support
Currently, this sample app only supports the amd64 platform.

## Quick Start for new users

To get started with the Apache Solr and ZooKeeper cluster along with monitoring tools, follow these steps:

1. **Clone the repository**: 
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd integration-sample-apps/apache-solr
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect the Grafana agent to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VMs**: 
   Use `make run` to start VMs with Apache Solr and ZooKeeper clusters.

5. **Fetch Prometheus metrics**: 
   Fetch metrics from the Prometheus exporter and save them with `make fetch-prometheus-metrics`.

6. **Stop and clean Up**: 
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates VMs and sets up Solr and ZooKeeper clusters.
- `make load-test`: Generates load on the Solr cluster for testing purposes.
- `make fetch-prometheus-metrics`: Fetches metrics from the Prometheus exporter and saves them to a local file.
- `make setup-grafana-agent`: Sets up Grafana Agent on each VM for forwarding metrics and logs.
- `make clean`: Deletes all created VMs and performs cleanup.

## Default configuration variables

- `prom_pass`: Your Prometheus password.
- `prom_user`: Your Prometheus username.
- `prom_url`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9090/api/v1/push`).
- `solr_cluster_name`: Name of the Solr cluster.
- `solr_host`: Hostname for Solr (e.g., `localhost`).
- `solr_port`: Port for Solr (e.g., `9854`).
- `solr_log_path`: Path to Solr log files (e.g., `/var/solr/logs/*.log`).
- `instance_name`: Name of the Solr instance.
- `loki_url`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.

# Debugging Tips

When deploying the Apache Solr and ZooKeeper Cluster sample app, you may encounter issues that require debugging. Here are some tips to validate the setup and troubleshoot common problems.

## Accessing the Multipass Instances

To access the Multipass instances for Apache Solr and ZooKeeper, use the following command for each instance:

```bash
multipass shell apache-solr-zookeeper-instance-1
```

## Validating services

### Apache Solr Service
- **Check service status**: Ensure the Apache Solr service is active and running.
  ```bash
  systemctl status solr
  ```
- **Check logs**: If the service isn't running, check the logs for errors.
  ```bash
  journalctl -u solr
  ```

### ZooKeeper Service
- **Check service status**: Verify that the ZooKeeper service is active.
  ```bash
  systemctl status zookeeper
  ```
- **Check logs**: Look for errors in the service logs if it's not running.
  ```bash
  journalctl -u zookeeper
  ```

### Grafana Agent
- **Check service status**: Confirm that the Grafana Agent is running.
  ```bash
  systemctl status grafana-agent
  ```
- **Review configuration**: Verify the configuration in `/etc/grafana-agent.yaml` is correct.
- **Check logs**: Review Grafana Agent logs for any connectivity or configuration issues.
  ```bash
  journalctl -u grafana-agent
  ```
