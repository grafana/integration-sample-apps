# OpenLDAP Sample App

This OpenLDAP Sample App simplifies the deployment of an OpenLDAP server with integrated monitoring through Prometheus and Grafana Loki. Utilizing cloud-init and Make commands, the app facilitates the setup, configuration, and monitoring of OpenLDAP instances.

## Platform Support
- Linux (x86 and ARM64): Fully supported on both x86 and ARM64 architectures, making it suitable for a wide range of Linux distributions, including Ubuntu, CentOS, and others.
- macOS (Intel and M2+ Chip): Compatible with macOS running on Intel-based systems and the M2+ chip. However, users with M1 chips might face some compatibility issues due to architecture differences.
- Windows (x86): Supported on Windows with the help of virtualization tools Multipass and Docker.

## Prerequisites

Before you begin, ensure you have the following installed:
- [Multipass](https://multipass.run/)
- Docker (for rendering the cloud-init configuration)
- Git (for cloning the repository)

## Quick Start for New Users

To get started with the OpenLDAP server and monitoring tools, follow these steps:

1. **Clone the Repository**: `git clone https://github.com/grafana/integration-sample-apps.git`.
2. **Navigate to the Project Directory**: `cd integration-sample-apps/openldap`.
3. **Set Up Default Config**: Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect to a Grafana agent.
4. **Render Cloud-init Configuration**: Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.
5. **Launch the VM**: Use `make run` to start the VM with OpenLDAP and necessary monitoring tools.
6. **Fetch Prometheus Metrics**: Verify that you are getting Prometheus metrics with `make fetch-prometheus-metrics`.
7. **Stop and Clean Up**: Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make Commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Launches the virtual machine and performs the entire setup for OpenLDAP.
- `make stop`: Stops and deletes the OpenLDAP virtual machine, cleaning up all resources.
- `make fetch-prometheus-metrics`: Retrieves Prometheus metrics from the exporter and saves them to a local file.
- `make load-test`: Generates load on the OpenLDAP for testing purposes.
- `make clean`: Removes generated files like `cloud-init.yaml`.

## Default Configuration Variables

- `exporter_repo`: Git repository URL for OpenLDAP Exporter.
- `exporter_dir`: Directory name for cloning the OpenLDAP Exporter repository.
- `prom_addr`: Address and port for the Prometheus metrics endpoint.
- `ldap_addr`: Address and port of the LDAP server.
- `ldap_user`: LDAP user for binding (e.g., `cn=monitor,dc=nodomain`).
- `ldap_pass`: Password for the LDAP user.
- `interval`: Scrape interval for Prometheus metrics.
- `loki_url`, `loki_user`, `loki_pass`: Loki endpoint and authentication details.
- `prom_url`, `prom_user`, `prom_pass`: Prometheus remote write endpoint and authentication details.
- `prom_port`: Port for Prometheus metrics exposure.


# Debugging Tips

When deploying the OpenLDAP Sample App, you may encounter issues that require debugging. Here are some tips to validate the setup and troubleshoot common problems.

## Accessing the Multipass Instance

To access the Multipass instance named `ldap-server`, use the following command:

```bash
multipass shell ldap-server
```

This command opens a shell session on the `ldap-server` VM, allowing you to run commands and check the status of various services directly.

## Validating Services

### OpenLDAP Service
- **Check Service Status**: Ensure the OpenLDAP service (`slapd`) is active and running.
  ```bash
  sudo systemctl status slapd
  ```
- **Check Logs**: If the service isn't running, check the logs for errors.
  ```bash
  sudo journalctl -u slapd
  ```

### OpenLDAP Exporter
- **Check Service Status**: Verify that the OpenLDAP Exporter service is active.
  ```bash
  sudo systemctl status openldap_exporter.service
  ```
- **Check Logs**: Look for errors in the service logs if it's not running.
  ```bash
  journalctl -u openldap_exporter.service
  ```
- **Check Metrics Endpoint**: Ensure the metrics endpoint is accessible.
  ```bash
  curl http://localhost:8080/metrics
  ```

### Grafana Agent
- **Check Service Status**: Confirm that the Grafana Agent is running.
  ```bash
  sudo systemctl status grafana-agent
  ```
- **Review Configuration**: Verify the configuration in `/etc/grafana-agent.yaml` is correct.
- **Check Logs**: Review Grafana Agent logs for any connectivity or configuration issues.
  ```bash
  journalctl -u grafana-agent
  ```
