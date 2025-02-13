# OpenLDAP sample app with VM and Kubernetes Support

This OpenLDAP sample app simplifies the deployment of an OpenLDAP server with integrated monitoring through Prometheus and Grafana Loki. It now includes support for both traditional VM environments using cloud-init and Make commands, as well as Kubernetes environments.

## Enhanced Logging Feature
The app includes detailed logging for the OpenLDAP server, configured to increase log level and capture logs in a dedicated file (`/var/log/slapd.log`). These logs provide valuable insights for performance monitoring and troubleshooting.

### Log Configuration Details
- **OpenLDAP Log Level**: Increased to `stats` for detailed operational statistics.
- **Log File Creation**: Uses `slapdlog.ldif` to modify OpenLDAP configuration.
- **rsyslog Configuration**: `10-slapd.conf` redirects OpenLDAP logs to `/var/log/slapd.log`.

## Platform Support
- Linux (x86 and ARM64): Fully supported on both x86 and ARM64 architectures, making it suitable for a wide range of Linux distributions, including Ubuntu, CentOS, and others.
- macOS (Intel and M2+ Chip): Compatible with macOS running on Intel-based systems and the M2+ chip. However, users with M1 chips might face some compatibility issues due to architecture differences.
- Windows (x86): Supported on Windows with the help of virtualization tools Multipass and Docker.

## Prerequisites
Before you begin, ensure you have the following installed:
- [Multipass](https://multipass.run/)
- Docker (for rendering configurations)
- Git (for cloning the repository)
- Kubernetes Cluster (for Kubernetes setup)
- Helm (for Kubernetes deployment)
- kubectl (for interacting with Kubernetes)

## Quick Start for VM Setup
1. Clone the repository: `git clone https://github.com/grafana/integration-sample-apps.git`.
2. Navigate to project directory: `cd integration-sample-apps/openldap`.
3. Set up default config: `make defaultconfig`.
4. Render cloud-init configuration: `make render-config`.
5. Launch the VM: `make run`.
6. Fetch Prometheus metrics: `make fetch-prometheus-metrics`.
7. Stop and clean Up: `make stop` and `make clean`.

## Quick Start for Kubernetes Setup
1. Clone the repository: `git clone https://github.com/grafana/integration-sample-apps.git`.
2. Navigate to project directory: `cd integration-sample-apps/openldap`.
3. Set up default config: `make defaultconfig`.
4. Render Kubernetes configurations: `make render-k8s`.
5. Deploy to Kubernetes: `make run-k8s`.
6. Verify deployment: check status using `kubectl get pods` and `kubectl get services`.
7. Stop and clean Up: `make stop-k8s` and `make clean`.

## Make commands
- VM Setup: 
- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Launches the virtual machine and performs the entire setup for OpenLDAP.
- `make stop`: Stops and deletes the OpenLDAP virtual machine, cleaning up all resources.
- `make fetch-prometheus-metrics`: Retrieves Prometheus metrics from the exporter and saves them to a local file.
- `make load-test`: Generates load on the OpenLDAP for testing purposes.
- `make clean`: Removes generated files like `cloud-init.yaml`.
  
Kubernetes Setup: 
- `make defaultconfig`: Initializes the configuration file with default values for Kubernetes templates.
- `make render-k8s`: Generates Kubernetes deployment and service YAML files based on the defined configuration.
- `make run-k8s`: Deploys the OpenLDAP application and associated services to the Kubernetes cluster.
- `make stop-k8s`: Stops and removes the OpenLDAP deployment from Kubernetes, cleaning up all resources.
- `make clean`: Removes generated files like Kubernetes YAML configurations.

## Default configuration variables
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

## VM Setup

When deploying the OpenLDAP sample app, you may encounter issues that require debugging. Here are some tips to validate the setup and troubleshoot common problems.

## Accessing the Multipass Instance

To access the Multipass instance named `ldap-server`, use the following command:

```bash
multipass shell ldap-server
```

This command opens a shell session on the `ldap-server` VM, allowing you to run commands and check the status of various services directly.

## Validating services

### OpenLDAP Service
- **Check service status**: Ensure the OpenLDAP service (`slapd`) is active and running.
  ```bash
  sudo systemctl status slapd
  ```
- **Check logs**: If the service isn't running, check the logs for errors.
  ```bash
  sudo journalctl -u slapd
  ```

### OpenLDAP Exporter
- **Check service status**: Verify that the OpenLDAP Exporter service is active.
  ```bash
  sudo systemctl status openldap_exporter.service
  ```
- **Check logs**: Look for errors in the service logs if it's not running.
  ```bash
  journalctl -u openldap_exporter.service
  ```
- **Check Metrics Endpoint**: Ensure the metrics endpoint is accessible.
  ```bash
  curl http://localhost:8080/metrics
  ```

### Grafana Agent
- **Check service status**: Confirm that the Grafana Agent is running.
  ```bash
  sudo systemctl status grafana-agent
  ```
- **Review configuration**: Verify the configuration in `/etc/grafana-agent.yaml` is correct.
- **Check logs**: Review Grafana Agent logs for any connectivity or configuration issues.
  ```bash
  journalctl -u grafana-agent
  ```

### Kubernetes Setup

When deploying the OpenLDAP sample app in a Kubernetes environment, you might face some issues that require troubleshooting. Below are some tips to help you validate the setup and resolve common problems.

## Checking Pod and Service Status

To verify the status of pods and services in your Kubernetes environment, use these commands:

- **Check Pods Status**:
  ```bash
  kubectl get pods
  ```
- **Check Services Status**:
  ```bash
  kubectl get services
  ```

These commands provide an overview of the running pods and services, including their current status and health.

## Viewing Logs

To view the logs of a specific pod, use the following command:

```bash
kubectl logs <pod-name>
```
