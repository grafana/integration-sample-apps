# Squid proxy sample app

This sample application creates an Ubuntu VM integrated with Alloy for metric and log collection. This sample app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of [Squid](https://www.squid-cache.org/) proxy server using Alloy's built-in [prometheus.exporter.squid](https://grafana.com/docs/alloy/latest/reference/components/prometheus.exporter.squid/) component.

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
   cd integration-sample-apps/sample-apps/squid
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VM**: 
   Use `make run` to start the Squid sample app.

5. **Stop and clean Up**: 
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the Squid sample app VM with Squid proxy server installed and configured.
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
- `interval`: Scrape interval for metrics collection (default: `10s`).

## Squid configuration

The sample app configures Squid proxy with the following features:

- **Proxy server**: Runs on port 3128 (standard Squid port)
- **Access control**: Configured to allow localhost access for load generation
- **Logging**: Writes access and cache logs to `/var/log/squid/access.log` and `/var/log/squid/cache.log`
- **Load generation**: Includes automated load generation service that creates HTTP traffic patterns

## Load generation

The sample app includes a built-in load generation system:

- **HTTP server**: Simple Python HTTP server on port 8080 serving test content
- **Load generator**: Automated service that generates both successful and failed proxy requests
- **Traffic patterns**: Creates realistic proxy usage patterns including cache hits/misses and error conditions
- **Systemd service**: Runs as `loadgen.service` for continuous traffic generation

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

### Squid
- **Check service status**: Confirm that Squid is running.
  ```bash
  systemctl status squid.service
  ```
- **Verify proxy functionality**: Test if the proxy is responding on port 3128.
  ```bash
  curl -x http://localhost:3128 http://www.google.com
  ```
- **Review configuration**: Check the Squid configuration file.
  ```bash
  cat /etc/squid/squid.conf
  ```
- **Check logs**: Review Squid logs for any issues.
  ```bash
  tail -f /var/log/squid/access.log
  tail -f /var/log/squid/cache.log
  ```

### Load Generation Service
- **Check service status**: Confirm that the load generator is running.
  ```bash
  systemctl status loadgen.service
  ```
- **Monitor traffic**: Watch the load generation in real-time.
  ```bash
  journalctl -u loadgen.service -f
  ```
- **Test HTTP server**: Verify the test HTTP server is accessible.
  ```bash
  curl http://localhost:8080/index.html
  ```

## Troubleshooting

For debugging and troubleshooting, you can access the VM directly using:
```bash
make shell
```

This opens a shell session to the running VM where you can execute the validation commands above and investigate any issues with the services.

Common troubleshooting steps:
- Verify Squid is accepting connections on port 3128
- Check that the load generator is creating traffic patterns
- Ensure Alloy has proper permissions to read Squid log files
- Confirm the HTTP test server is running on port 8080
