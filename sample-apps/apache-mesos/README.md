# Apache Mesos sample app

This sample application stands up a single-node K3s cluster, with the [k8s-monitoring-helm](https://github.com/grafana/k8s-monitoring-helm) chart applied, and then spawns a full Apache Mesos setup using a custom Docker image with the Aventer Mesos distribution and mesos_exporter for Prometheus metrics. The sample app is capable of running both in a ubuntu-latest-8-core Github Actions runner, and locally.

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
   cd integration-sample-apps/sample-apps/apache-mesos
   ```

2. **Stand up the sample app**
   Execute `make LOKI_INSTANCE=<loki_host>:<loki_port> PROMETHEUS_INSTANCE=<prom_host>:<prom_port> run-ci`, substituting the host and ports as required for your setup.
   This will take care of rendering the correct config and setup, as used in the Github Actions workflow on this repository.

6. **Stop and clean Up**: 
   Use `make stop` to clean up the k3s cluster and automatically clean up temporary files.

## What this sample app does

This sample app deploys Apache Mesos in a Kubernetes cluster and configures monitoring for it. Specifically, it:

- Builds and deploys a custom Apache Mesos Docker image using:
  - Ubuntu Jammy as the base image
  - Aventer Mesos distribution for ARM64 and AMD64 support
  - Mesos Exporter v1.1.2 for Prometheus metrics on port 9105
  - Both Mesos master (port 5050) and agent (port 5051) in the same pod
- Deploys using a custom Helm chart with configurable replicas (default: 2)
- Configures Alloy to scrape Mesos metrics from both master and agent exporters
- Collects Mesos logs from both master and agent containers in the `apache-mesos` namespace
- Monitors comprehensive Mesos metrics including cluster state, framework operations, task execution, and resource utilization

The monitoring configuration targets the job label `integrations/apache-mesos` and includes instance identification for proper metric and log labeling.

## Make commands

- `make default-monitoring-config`: Initializes the configuration file with default connection parameters used when applying the [k8s-monitoring-helm chart](https://github.com/grafana/k8s-monitoring-helm).
- `make render-config`: Generates the `monitoring-config.yaml` configuration file using the defined variables.
- `make run-ci`: Creates the Apache Mesos sample app.
- `make install-suo`: Transfers required configs and installs Apache Mesos; useful for debugging.
- `make stop`: Tears down the sample-app cluster
- `make clean`: Deletes all created VMs and performs cleanup.

## Default configuration variables

- `prom_pass`: Your Prometheus password
- `prom_user`: Your Prometheus username
- `prom_host`: Host for Prometheus (e.g., `http://your-prometheus-instance:9090`)
- `prom_path`: Path on Prometheus host for the push endpoint (e.g. `/api/v1/push`)
- `loki_host`: Host for Loki push endpoint (e.g., `http://your-loki-instance:3100`)
- `loki_path`: Path on Loki host for the push endpoint (e.g. `/loki/api/v1/push`)
- `loki_user`: Your Loki username
- `loki_pass`: Your Loki password


## Troubleshooting

1. *`Alloy status`*
   - To check the status of monitoring pods:  
     `multipass exec apache-mesos-sample-app-k3s-main -- kubectl get pods -n monitoring`
   - To view Alloy logs:  
     `multipass exec apache-mesos-sample-app-k3s-main -- kubectl logs -n monitoring -l app.kubernetes.io/name=alloy`
2. *`Apache Mesos status`*
   - To check the status of the Apache Mesos pods, run:
     `multipass exec apache-mesos-sample-app-k3s-main -- kubectl get pods -n apache-mesos`
   - To view logs for a specific Mesos pod, run:
     `multipass exec apache-mesos-sample-app-k3s-main -- kubectl logs -n apache-mesos <pod-name> -c mesos-master`
   - To view Mesos agent logs, run:
     `multipass exec apache-mesos-sample-app-k3s-main -- kubectl logs -n apache-mesos <pod-name> -c mesos-agent`


