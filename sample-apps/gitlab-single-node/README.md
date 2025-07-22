# GitLab sample app

This sample application stands up a single-node K3s cluster, with the [k8s-monitoring-helm](https://github.com/grafana/k8s-monitoring-helm) chart applied, and then spawns a full GitLab setup using the official GitLab Helm chart. The sample app deploys GitLab Community Edition with embedded PostgreSQL, Redis, and MinIO for a complete self-contained GitLab instance. The sample app is capable of running both in a ubuntu-latest-8-core Github Actions runner, and locally.

## Architecture

This sample app deploys the following components:
- **GitLab Community Edition** - Self-hosted Git repository management and DevOps platform
- **PostgreSQL** - Database backend for GitLab
- **Redis** - Caching and session storage
- **MinIO** - Object storage for GitLab artifacts and uploads
- **k8s-monitoring-helm** - Grafana Alloy-based monitoring stack
- **Kubernetes (k3s)** - Container orchestration platform

## System Requirements

- **CPU**: 8 cores
- **Memory**: 12 GB RAM
- **Disk**: 20 GB available space
- **OS**: macOS, Linux, or Windows with Multipass support

## Prerequisites

Before you begin, ensure you have the following installed:

- [Multipass](https://multipass.run/)
- Docker (for rendering the cloud-init configuration)
- Git (for cloning the repository)
- `jq` (for JSON parsing in some make commands)

## Quick Start for new users

To get started with the sample app, follow these steps:

1. **Clone the repository**: 
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd integration-sample-apps/sample-apps/gitlab-single-node
   ```

2. **Stand up the sample app**
   Execute `make LOKI_INSTANCE=<loki_host>:<loki_port> PROMETHEUS_INSTANCE=<prom_host>:<prom_port> run-ci`, substituting the host and ports as required for your setup.
   This will take care of rendering the correct config and setup, as used in the Github Actions workflow on this repository.

3. **Access GitLab**
   Once the deployment is complete, get access information:
   ```sh
   make gitlab-info
   ```

4. **Stop and clean Up**: 
   Use `make stop` to clean up the k3s cluster and automatically clean up temporary files.

## Accessing GitLab

```sh
# Set up local DNS resolution as Gitlab has security features that require non-port forward based access
make setup-hosts
# Retrieve Gitlab Connection Information
make gitlab-info
```
Then browse to the provided URL (e.g., http://gitlab.local:32080)

### Login Credentials
- **Username**: `root`
- **Password**: Get with `make get-password`

## Make commands

### Core Commands
- `make run-ci`: Creates the complete GitLab sample app (runs k3s-setup, install-suo, default-monitoring-config, render-config, install-monitoring)
- `make stop`: Tears down the sample-app cluster
- `make clean`: Deletes all created VMs and performs cleanup

### Configuration Commands
- `make default-monitoring-config`: Initializes the configuration file with default connection parameters used when applying the [k8s-monitoring-helm chart](https://github.com/grafana/k8s-monitoring-helm)
- `make render-config`: Generates the `monitoring-config.yaml` configuration file using the defined variables

### Installation Commands
- `make install-suo`: Transfers required configs and installs GitLab; useful for debugging
- `make install-monitoring`: Installs the monitoring stack (k8s-monitoring-helm chart)
- `make transfer-configs`: Transfers configuration files to the VM

### Access and Information Commands
- `make gitlab-info`: Shows GitLab access URLs, credentials, and connection information
- `make get-password`: Retrieves the GitLab root password
- `make get-vm-ip`: Shows the VM's IP address
- `make setup-hosts`: Configures local /etc/hosts file for gitlab.local access
- `make shell`: Opens a shell session in the VM

### Monitoring Commands
- `make access-alloy-ui`: Port-forwards and provides access to the Alloy monitoring UI

## Default configuration variables

- `prom_pass`: Your Prometheus password
- `prom_user`: Your Prometheus username
- `prom_host`: Host for Prometheus (e.g., `http://your-prometheus-instance:9090`)
- `prom_path`: Path on Prometheus host for the push endpoint (e.g. `/api/v1/push`)
- `loki_host`: Host for Loki push endpoint (e.g., `http://your-loki-instance:3100`)
- `loki_path`: Path on Loki host for the push endpoint (e.g. `/loki/api/v1/push`)
- `loki_user`: Your Loki username
- `loki_pass`: Your Loki password

## Expected Metrics

This sample app produces GitLab-specific metrics including:
- `gitlab_cache_misses_total` - Cache performance metrics
- `gitlab_database_connection_pool_*` - Database connection pool status
- `gitlab_filesystem_*` - Filesystem access and performance metrics
- `gitlab_http_requests_total` - HTTP request metrics
- `gitlab_rails_boot_time_seconds` - Application startup time
- `gitlab_redis_client_*` - Redis client metrics
- `gitlab_ruby_*` - Ruby runtime metrics

For a complete list of expected metrics, see the `expected_metrics` file.

## Configuration Files

- `configs/values.yaml`: GitLab Helm chart configuration
- `configs/suo.alloy`: Alloy agent configuration for metrics collection
- `configs/gitaly-pvc.yaml`: Persistent volume claim for GitLab Git storage
- `configs/load-generation.yaml`: Optional load generation configuration
- `jinja/templates/`: Jinja2 templates for dynamic configuration generation
- `jinja/variables/monitoring-config.yaml`: Variables for template rendering

## Troubleshooting

### GitLab Not Accessible
1. Check if the VM is running: `multipass list`
2. Verify GitLab pods are ready: `make shell` then `kubectl get pods -n gitlab`
3. Check service status: `make gitlab-info`

### Monitoring Not Working
1. Verify Alloy is running: `make shell` then `kubectl get pods -n monitoring`
2. Check Alloy UI: `make access-alloy-ui`
3. Review configuration: `make shell` then `kubectl logs -n monitoring deployment/k8s-monitoring-alloy`

### VM Issues
1. Check VM status: `multipass info gitlab-sample-app-k3s-main`
2. Restart if needed: `multipass restart gitlab-sample-app-k3s-main`
3. For persistent issues: `make clean` and re-run `make run-ci`

### Resource Issues
- Ensure your system meets the minimum requirements (8 CPU, 12GB RAM, 20GB disk)
- Close other resource-intensive applications
- Consider increasing Multipass VM limits if necessary

## Scripts

- `scripts/suo_setup.sh`: Sets up GitLab using Helm chart
- `scripts/install_monitoring.sh`: Installs the k8s-monitoring-helm chart
- `modify-etc-hosts.sh`: Helper script for local DNS configuration
