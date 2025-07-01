# Aerospike Community edition sample app

This sample application creates an Ubuntu VM integrated with Alloy for metric and log collection. This sample app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of [Aerospike Community Edition](https://aerospike.com/products/database/) using the [aerospike-prometheus-exporter](https://github.com/aerospike/aerospike-prometheus-exporter/).

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
   cd integration-sample-apps/sample-apps/aerospike
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VM**: 
   Use `make run` to start the Aerospike sample app.

5. **Stop and clean Up**: 
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the Aerospike sample app VM with Aerospike Community Edition installed and configured.
- `make run-ci`: Runs in CI mode by cleaning, setting up default config, and launching the VM.
- `make shell`: Opens a shell session to the running VM for debugging and troubleshooting.
- `make stop`: Stops and removes the VM, then purges multipass resources.
- `make clean`: Removes generated configuration files and temporary resources.

## Default configuration variables

- `prom_pass`: Your Prometheus password.
- `prom_user`: Your Prometheus username.
- `prom_url`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9009/api/v1/push`).
- `loki_url`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.
- `aerospike_cluster`: Name identifier for the Aerospike cluster (default: `aerospike-sample-app-cluster`).

## Aerospike version compatibility

The sample app automatically installs the appropriate Aerospike Community Edition version based on the Ubuntu version:

- **Ubuntu 18.04**: Aerospike 5.7.0.23 with Tools 7.1.1
- **Ubuntu 20.04/22.04**: Aerospike 6.3.0.2 with Tools 8.3.0  
- **Ubuntu 24.04**: Aerospike 7.2.0.11 with Tools 11.2.2

## Aerospike configuration

The sample app configures Aerospike with two namespaces:

- **test namespace**: Uses file-based storage with a 4GB data file located at `/opt/aerospike/data/test.data`
- **bar namespace**: Uses in-memory storage with 4GB allocated memory

This configuration allows you to test both storage engines and understand their performance characteristics.

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

### Aerospike
- **Check service status**: Confirm that Aerospike is running.
  ```bash
  systemctl status aerospike.service
  ```
- **Verify database**: Check if Aerospike is accessible and responsive.
  ```bash
  asinfo -v status
  ```
- **Review configuration**: Check the Aerospike configuration file.
  ```bash
  cat /etc/aerospike/aerospike.conf
  ```
- **Check logs**: Review Aerospike logs for any issues.
  ```bash
  tail -f /var/log/aerospike/aerospike.log
  ```

### Aerospike Prometheus Exporter
- **Check service status**: Confirm that the exporter is running.
  ```bash
  systemctl status aerospike-prometheus-exporter.service
  ```
- **Test metrics endpoint**: Verify metrics are being exposed on port 9145.
  ```bash
  curl localhost:9145/metrics
  ```
- **Check logs**: Review exporter logs for any connectivity issues.
  ```bash
  journalctl -u aerospike-prometheus-exporter.service
  ```

## Troubleshooting

For debugging and troubleshooting, you can access the VM directly using:
```bash
make shell
```

This opens a shell session to the running VM where you can execute the validation commands above and investigate any issues with the services.