# Presto sample app

This sample application demonstrates Presto monitoring on a single-node K3s cluster. It deploys [Presto](https://prestodb.io/) using the official [Presto Helm chart](https://prestodb.github.io/presto-helm-charts) with integrated JMX Prometheus metrics collection, includes a CronJob-based load generator that executes sample TPCH queries, and applies the [k8s-monitoring-helm](https://github.com/grafana/k8s-monitoring-helm) chart for comprehensive observability. The setup supports both GitHub Actions runners and local development environments.

Feel free to modify the [loadgen-template.yaml](./jinja/templates/loadgen-template.yaml) or [values-template.yaml](./jinja/templates/values-template.yaml) for your testing purposes.

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
   cd integration-sample-apps/sample-apps/presto
   ```

2. **Stand up the sample app**
   Execute `make LOKI_INSTANCE=<loki_host>:<loki_port> PROMETHEUS_INSTANCE=<prom_host>:<prom_port> run-ci`, substituting the host and ports as required for your setup.
   This will take care of rendering the correct config and setup, as used in the Github Actions workflow on this repository.

6. **Stop and clean Up**: 
   Use `make stop` to clean up the k3s cluster and automatically clean up temporary files.

## What's Included

This sample app provides:

- **Presto Cluster**: Presto 0.293 deployed using the official Helm chart with coordinator and worker nodes
- **JMX Metrics Collection**: Comprehensive JMX-to-Prometheus metrics export for query performance, memory usage, and cluster health
- **Load Generator**: CronJob that executes sample TPCH queries every minute to generate realistic workload
- **Observability**: Grafana Alloy configuration for metrics and logs collection from Presto pods

## Make commands

- `make default-monitoring-config`: Initializes the configuration file with default connection parameters used when applying the [k8s-monitoring-helm chart](https://github.com/grafana/k8s-monitoring-helm).
- `make render-config`: Generates the `monitoring-config.yaml` configuration file using the defined variables.
- `make run-ci`: Creates the Presto sample app with load generator and monitoring.
- `make install-suo`: Transfers required configs and installs Presto; useful for debugging.
- `make install-monitoring`: Installs the k8s-monitoring chart with Presto-specific configuration.
- `make stop`: Tears down the sample-app cluster
- `make clean`: Deletes all created VMs and performs cleanup.
- `make remove-suo`: Uninstalls Presto from the cluster.
- `make remove-monitoring`: Uninstalls the monitoring stack from the cluster.

## Default configuration variables

- `prom_pass`: Your Prometheus password
- `prom_user`: Your Prometheus username
- `prom_host`: Host for Prometheus (e.g., `http://your-prometheus-instance:9090`)
- `prom_path`: Path on Prometheus host for the push endpoint (e.g. `/api/v1/push`)
- `loki_host`: Host for Loki push endpoint (e.g., `http://your-loki-instance:3100`)
- `loki_path`: Path on Loki host for the push endpoint (e.g. `/loki/api/v1/push`)
- `loki_user`: Your Loki username
- `loki_pass`: Your Loki password
- `presto_image`(optional): Presto Docker image to use (default: `prestodb/presto`)
- `presto_tag`(optional): Presto Docker tag to use (default: (0.293))

## Metrics Collected

The sample app collects comprehensive Presto metrics including:

- **Query Metrics**: Execution time, completed/failed queries, CPU consumption
- **Memory Metrics**: Heap/non-heap usage, cluster memory pools, blocked nodes
- **Task Metrics**: Task executor performance, queued tasks, completed tasks
- **Cluster Metrics**: Active nodes, coordinator/worker status, node discovery
- **JVM Metrics**: Garbage collection, memory usage, system performance

## Troubleshooting

1. **Alloy status**
   - To check the status of monitoring pods:  
     `multipass exec presto-sample-app-k3s-main -- kubectl get pods -n monitoring`
   - To view Alloy logs:  
     `multipass exec presto-sample-app-k3s-main -- kubectl logs -n monitoring -l app.kubernetes.io/name=alloy`

2. **Presto status**
   - To check the status of the Presto deployment, run:
     `multipass exec presto-sample-app-k3s-main -- kubectl get pods -n presto`

3. **Presto loadgen cronjob**
   - To describe the cronjob:
     `multipass exec presto-sample-app-k3s-main -- kubectl get cronjob -n presto`

4. **Presto Query Interface**
   - The Presto coordinator web UI is available at `http://<multipass vm>:8080` after port-forwarding:
     `multipass exec presto-sample-app-k3s-main -- kubectl port-forward -n presto svc/presto 8080:8080 --address 0.0.0.0`

5. **Manual Query Execution**
   - To run manual queries for testing:
     `multipass exec presto-sample-app-k3s-main -- kubectl exec -n presto deployment/presto-coordinator -- ./opt/presto-cli --server localhost:8080 --catalog tpch --schema sf1 --execute "SHOW TABLES"`
