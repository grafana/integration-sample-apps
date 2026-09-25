# Linux hostmetrics sample app

This sample application creates Ubuntu VMs instrumented with the OpenTelemetry `hostmetrics` receiver, exporting over OTLP. This sample app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of Linux using semantic convention metrics. The receiver is run by both Grafana Alloy (through its OpenTelemetry engine) and the OpenTelemetry Collector.

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
   cd integration-sample-apps/sample-apps/linux-hostmetrics
   ```

2. **Set up default config**:
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect the receiver to an external OTLP endpoint.

3. **Render cloud-init configuration**:
   Run `make render-config` to generate a `cloud-init-<collector>.yaml` file for each collector.

4. **Create and set up VMs**:
   Use `make run` to start the Linux hostmetrics sample app.

5. **Stop and clean up**:
   Use `make stop` to clean up the VMs and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Creates the configuration file with default values, if it does not already exist. `make run` and `make render-config` create it when missing.
- `make render-config`: Generates a `cloud-init-<collector>.yaml` configuration file per collector using the defined variables.
- `make run`: Creates the Linux hostmetrics sample app.
- `make stop`: Deletes all created VMs.
- `make clean`: Removes the rendered configuration files.
- `make distclean`: Also removes `jinja/variables/`, including any endpoint and credentials set there.

## Make variables

Any of these can be overridden on the command line, e.g. `make COLLECTORS=otelcol NODES=3 run`.

- `COLLECTORS`: Which collectors to run, one VM per collector. Defaults to `alloy otelcol`. Each has a matching `jinja/templates/<collector>.yaml`.
- `NODES`: How many VMs to launch per collector. Defaults to `1`.
- `PROMETHEUS_INSTANCE`: `host:port` of the OTLP endpoint written into the default config when it is created. Defaults to `your-prometheus-instance:9090`.
- `OTEL_COL_VERSION`: Pinned OpenTelemetry Collector release to install.
- `VM_NAME`: Name prefix for the launched VMs. Defaults to `linux-hostmetrics-sample-app`.
- `VM_CPUS`, `VM_MEMORY`, `VM_DISK`: Per-VM resources. Default to `2`, `2G` and `8G`.

## Default configuration variables

- `interval`: How often the receiver collects metrics (e.g., `10s`).
- `otlp_url`: Base URL of the OTLP endpoint; the exporter appends `/v1/metrics`.
- `otel_col_version`: OpenTelemetry Collector release to install, e.g. `0.161.0`. Set from `OTEL_COL_VERSION`.
- `otlp_user`, `otlp_pass`: Basic auth credentials for the OTLP endpoint. Empty by default, which sends no credentials; set both to export to an endpoint that requires them.

The `job` and `instance` labels are derived by OTLP ingest from the `service.namespace`, `service.name` and `service.instance.id` resource attributes, which the collector's `resource` processor sets.

## Validating services

### Alloy
- **Check service status**: Confirm that Alloy is running.
  ```bash
  systemctl status alloy.service
  ```
- **Review configuration**: Verify the configuration in `/etc/alloy/hostmetrics.yaml` is correct. Alloy is installed from the Grafana apt repository and run through its OpenTelemetry engine, configured by the drop-in at `/etc/systemd/system/alloy.service.d/otel.conf`.
- **Check logs**: Review Alloy logs for any connectivity or configuration issues.
  ```bash
  journalctl -u alloy.service
  ```

### OpenTelemetry Collector
- **Check service status**: Confirm that the collector is running.
  ```bash
  systemctl status otelcol-contrib.service
  ```
- **Review configuration**: Verify the configuration in `/etc/otelcol-contrib/config.yaml` is correct.
- **Check logs**: Review collector logs for any connectivity or configuration issues.
  ```bash
  journalctl -u otelcol-contrib.service
  ```
