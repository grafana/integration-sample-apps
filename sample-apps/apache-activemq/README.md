# Apache ActiveMQ sample app

This sample application demonstrates Apache ActiveMQ monitoring on a single-node K3s cluster. It deploys a custom [Apache ActiveMQ](https://hub.docker.com/r/apache/activemq-classic) image with integrated [JMX Prometheus Exporter](https://github.com/prometheus/jmx_exporter), includes a Go-based [load generator](./configs/loadgenerator/main.go) for semi-realistic message traffic across topics and queues, and applies the [k8s-monitoring-helm](https://github.com/grafana/k8s-monitoring-helm) chart for comprehensive observability. The setup supports both GitHub Actions runners and local development environments.

Feel free to modify the [main.go](./configs/loadgenerator/main.go) or [values.yaml](./configs/values.yaml) for your testing purposes.

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
   cd integration-sample-apps/sample-apps/apache-activemq
   ```

2. **Stand up the sample app**
   Execute `make LOKI_INSTANCE=<loki_host>:<loki_port> PROMETHEUS_INSTANCE=<prom_host>:<prom_port> run-ci`, substituting the host and ports as required for your setup.
   This will take care of rendering the correct config and setup, as used in the Github Actions workflow on this repository.

6. **Stop and clean Up**: 
   Use `make stop` to clean up the k3s cluster and automatically clean up temporary files.

## What's Included

This sample app provides:

- **Custom ActiveMQ Image**: Apache ActiveMQ Classic 6.1.6 with JMX Prometheus Exporter pre-configured
- **Load Generator**: Go application that generates realistic message traffic on multiple topics and queues
- **Observability**: Grafana Alloy configuration for metrics and logs collection
- **Kubernetes Deployment**: Production-ready manifests for deploying ActiveMQ with proper service exposure

## Make commands

- `make default-monitoring-config`: Initializes the configuration file with default connection parameters used when applying the [k8s-monitoring-helm chart](https://github.com/grafana/k8s-monitoring-helm).
- `make render-config`: Generates the `monitoring-config.yaml` configuration file using the defined variables.
- `make run-ci`: Creates the Apache ActiveMQ sample app with load generator and monitoring.
- `make install-suo`: Transfers required configs and installs Apache ActiveMQ; useful for debugging.
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
     `multipass exec apache-activemq-sample-app-k3s-main -- kubectl get pods -n monitoring`
   - To view Alloy logs:  
     `multipass exec apache-activemq-sample-app-k3s-main -- kubectl logs -n monitoring -l app.kubernetes.io/name=alloy`
2. *`Apache ActiveMQ status`*
   - To check the status of the Apache ActiveMQ deployment, run:
     `multipass exec apache-activemq-sample-app-k3s-main -- kubectl get pods -n apache-activemq`
   - To view logs for the Apache ActiveMQ pod, run:
     `multipass exec apache-activemq-sample-app-k3s-main -- kubectl logs -n apache-activemq <pod-name>`
3. *`Apache ActiveMQ loadgen script`*
   - To describe the cronjob:
     `multipass exec apache-activemq-sample-app-k3s-main -- kubectl get cronjob -n apache-activemq`
   - To get logs for the cronjob
     `multipass exec apache-activemq-sample-app-k3s-main -- kubectl logs -n apache-activemq <loadgen pod>`