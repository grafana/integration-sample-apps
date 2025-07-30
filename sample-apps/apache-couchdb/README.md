# Apache CouchDB sample app

This sample application stands up a single-node K3s cluster, with the [k8s-monitoring-helm](https://github.com/grafana/k8s-monitoring-helm) chart applied, and then spawns a full Apache CouchDB setup using the official [Apache CouchDB Helm chart](https://artifacthub.io/packages/helm/couchdb/couchdb). The CouchDB instance is configured with Prometheus metrics enabled on port `17986` and admin party mode for simplified setup. For more information on values provided to the chart please refer to [the values.yaml](./configs/values.yaml). The sample app is capable of running both in a ubuntu-latest-8-core Github Actions runner, and locally.

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
   cd integration-sample-apps/sample-apps/apache-couchdb
   ```

2. **Stand up the sample app**
   Execute `make LOKI_INSTANCE=<loki_host>:<loki_port> PROMETHEUS_INSTANCE=<prom_host>:<prom_port> run-ci`, substituting the host and ports as required for your setup.
   This will take care of rendering the correct config and setup, as used in the Github Actions workflow on this repository.

6. **Stop and clean Up**: 
   Use `make stop` to clean up the k3s cluster and automatically clean up temporary files.

## What this sample app does

This sample app deploys Apache CouchDB in a Kubernetes cluster and configures monitoring for it. Specifically, it:

- Deploys Apache CouchDB using the official Helm chart with:
  - Admin party mode enabled for simplified setup
  - Prometheus metrics endpoint enabled on port 17986
  - Persistent volume for data storage (3Gi)
  - Auto-setup enabled
- Configures Alloy to scrape CouchDB metrics from the `/_node/_local/_prometheus` endpoint
- Collects CouchDB logs from the pods in the `apache-couchdb` namespace
- Monitors comprehensive CouchDB metrics including replication, authentication, database operations, and performance metrics

The monitoring configuration targets the job label `integrations/apache-couchdb` and includes cluster identification for proper metric and log labeling.

## Make commands

- `make default-monitoring-config`: Initializes the configuration file with default connection parameters used when applying the [k8s-monitoring-helm chart](https://github.com/grafana/k8s-monitoring-helm).
- `make render-config`: Generates the `monitoring-config.yaml` configuration file using the defined variables.
- `make run-ci`: Creates the Apache CouchDB sample app.
- `make install-suo`: Transfers required configs and installs Apache CouchDB; useful for debugging.
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
     `multipass exec apache-couchdb-sample-app-k3s-main -- kubectl get pods -n monitoring`
   - To view Alloy logs:  
     `multipass exec apache-couchdb-sample-app-k3s-main -- kubectl logs -n monitoring -l app.kubernetes.io/name=alloy`
2. *`Apache CouchDB status`*
   - To check the status of the Apache CouchDB nodes, run:
     `multipass exec apache-couchdb-sample-app-k3s-main -- kubectl get pods -n apache-couchdb`
   - To view logs for a specific CouchDB pod, run:
     `multipass exec apache-couchdb-sample-app-k3s-main -- kubectl logs -n apache-couchdb <pod-name>`
