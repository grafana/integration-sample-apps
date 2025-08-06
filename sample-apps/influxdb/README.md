# InfluxDB sample app

This sample application demonstrates InfluxDB monitoring on a single-node K3s cluster. It deploys [InfluxDB 2.x](https://hub.docker.com/_/influxdb) using the official [InfluxData Helm chart](https://helm.influxdata.com/) with built-in Prometheus metrics endpoints, includes a custom containerized load generator that creates realistic time-series data workloads using sample datasets, and applies the [k8s-monitoring-helm](https://github.com/grafana/k8s-monitoring-helm) chart for comprehensive observability. The setup supports both GitHub Actions runners and local development environments.

Feel free to modify the [loadgen.sh](./configs/loadgen.sh) or [values.yaml](./configs/values.yaml) for your testing purposes.

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
   cd integration-sample-apps/sample-apps/influxdb
   ```

2. **Stand up the sample app**
   Execute `make LOKI_INSTANCE=<loki_host>:<loki_port> PROMETHEUS_INSTANCE=<prom_host>:<prom_port> run-ci`, substituting the host and ports as required for your setup.
   This will take care of rendering the correct config and setup, as used in the Github Actions workflow on this repository.

6. **Stop and clean Up**: 
   Use `make stop` to clean up the k3s cluster and automatically clean up temporary files.

## What's Included

This sample app provides:

- **InfluxDB 2.x Instance**: Modern time-series database with built-in web UI and API
- **Custom Load Generator**: Containerized application that creates buckets, writes sample data, performs queries, and cleans up
- **Sample Datasets**: Air sensor data, Bitcoin prices, NOAA weather data, and USGS earthquake data
- **Prometheus Metrics**: Native InfluxDB metrics export for query performance, storage, and system health
- **Observability**: Grafana Alloy configuration for metrics and logs collection from InfluxDB pods
- **Kubernetes Deployment**: Production-ready manifests for deploying InfluxDB with proper service exposure

## Make commands

- `make default-monitoring-config`: Initializes the configuration file with default connection parameters used when applying the [k8s-monitoring-helm chart](https://github.com/grafana/k8s-monitoring-helm).
- `make render-config`: Generates the `monitoring-config.yaml` configuration file using the defined variables.
- `make run-ci`: Creates the InfluxDB sample app with load generator and monitoring.
- `make install-suo`: Transfers required configs and installs InfluxDB; useful for debugging.
- `make install-monitoring`: Installs the k8s-monitoring chart with InfluxDB-specific configuration.
- `make transfer-configs`: Transfers configuration files to the VM.
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

## InfluxDB Configuration

The sample app includes pre-configured credentials for easy testing:

- **Organization**: `influxdata`
- **Bucket**: `default`
- **Username**: `admin`
- **Password**: `Evergreen8080!`
- **Token**: `nrlukwAn13XLMIlYeDTg7g47T28cEG4P`

## Metrics Collected

The sample app collects comprehensive InfluxDB metrics including:

- **Database Metrics**: Buckets, users, dashboards, scrapers, replications
- **Query Metrics**: Request counts, response times, query execution performance
- **Storage Metrics**: BoltDB reads/writes, data ingestion rates
- **System Metrics**: Memory usage, garbage collection, goroutines
- **HTTP Metrics**: API request duration, query/write request bytes
- **Task Metrics**: Scheduler performance, executor workers, active tasks

## Load Generator Behavior

The load generator performs the following actions every minute:

1. **Creates temporary buckets**: `loadgen-0` and `loadgen-1`
2. **Writes sample data**:
   - Air sensor temperature readings
   - Bitcoin price data
   - Weather observations from NOAA buoys
   - USGS earthquake data
3. **Executes queries**: Runs range queries on both buckets for 15 seconds
4. **Cleanup**: Removes the temporary buckets

## Troubleshooting

1. **Alloy status**
   - To check the status of monitoring pods:  
     `multipass exec influxdb-sample-app-k3s-main -- kubectl get pods -n monitoring`
   - To view Alloy logs:  
     `multipass exec influxdb-sample-app-k3s-main -- kubectl logs -n monitoring -l app.kubernetes.io/name=alloy`

2. **InfluxDB status**
   - To check the status of the InfluxDB deployment, run:
     `multipass exec influxdb-sample-app-k3s-main -- kubectl get pods -n influxdb`
   - To view logs for the InfluxDB pod, run:
     `multipass exec influxdb-sample-app-k3s-main -- kubectl logs -n influxdb -l app.kubernetes.io/name=influxdb2`

3. **InfluxDB loadgen cronjob**
   - To describe the cronjob:
     `multipass exec influxdb-sample-app-k3s-main -- kubectl get cronjob -n influxdb`
   - To get logs for the cronjob:
     `multipass exec influxdb-sample-app-k3s-main -- kubectl logs -n influxdb -l app.kubernetes.io/name=influxdb-loadgen`

4. **InfluxDB Web Interface**
   - The InfluxDB web UI is available at `http://<multipass vm>:80` after port-forwarding:
     `multipass exec influxdb-sample-app-k3s-main -- kubectl port-forward -n influxdb svc/influxdb-influxdb2 8080:80 --address 0.0.0.0`
   - Access the UI at `http://<vm-ip>:8080` using the credentials above
