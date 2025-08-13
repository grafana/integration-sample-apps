# Oracle Database sample app

This sample application demonstrates Oracle Database monitoring on a single-node K3s cluster. It deploys [Oracle Database 23c Free](https://hub.docker.com/r/gvenzl/oracle-free) with the [Oracle DB Prometheus exporter](https://github.com/grafana/alloy/blob/main/docs/sources/reference/components/prometheus/prometheus.exporter.oracledb.md) integrated via Grafana Alloy, and applies the [k8s-monitoring-helm](https://github.com/grafana/k8s-monitoring-helm) chart for comprehensive observability. The setup includes Oracle Instant Client configuration for database connectivity and supports both GitHub Actions runners and local development environments.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Multipass](https://multipass.run/)
- Docker (for rendering the cloud-init configuration and building Oracle Instant Client image)
- Git (for cloning the repository)

**Note**: This sample app automatically handles Oracle Instant Client installation. The setup process builds a custom Docker image containing the Oracle Instant Client libraries, which are then deployed via a Kubernetes job to a persistent volume for use by the Alloy Oracle DB exporter.

## Quick Start for new users

To get started with the sample app, follow these steps:

1. **Clone the repository**: 
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd integration-sample-apps/sample-apps/oracledb2
   ```

2. **Stand up the sample app**
   Execute `make LOKI_INSTANCE=<loki_host>:<loki_port> PROMETHEUS_INSTANCE=<prom_host>:<prom_port> run-ci`, substituting the host and ports as required for your setup.
   This will take care of rendering the correct config and setup, as used in the Github Actions workflow on this repository.

6. **Stop and clean Up**: 
   Use `make stop` to clean up the k3s cluster and automatically clean up temporary files.

## What's Included

This sample app provides:

- **Oracle Database 23c Free**: Containerized Oracle Database instance with pre-configured monitoring user and permissions
- **Oracle Instant Client**: Configured Oracle Instant Client libraries for database connectivity
- **Oracle User**: A single standard common monitoring user is setup `C##GRAFANAU/r7DC98o8Op` which can be used to run the underlying queries of the prometheus exporter. This should have access to all PDBs of the deployment.
- **Observability**: Grafana Alloy configuration with Oracle DB Prometheus exporter for metrics and logs collection

## Make commands

- `make default-monitoring-config`: Initializes the configuration file with default connection parameters used when applying the [k8s-monitoring-helm chart](https://github.com/grafana/k8s-monitoring-helm).
- `make render-config`: Generates the `monitoring-config.yaml` configuration file using the defined variables.
- `make run-ci`: Creates the Oracle Database sample app with monitoring.
- `make install-suo`: Transfers required configs and installs Oracle Database; useful for debugging.
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
     `multipass exec oracledb-sample-app-k3s-main -- kubectl get pods -n monitoring`
   - To view Alloy logs:  
     `multipass exec oracledb-sample-app-k3s-main -- kubectl logs -n monitoring -l app.kubernetes.io/name=alloy`

2. *`Oracle Database status`*
   - To check the status of the Oracle Database deployment:
     `multipass exec oracledb-sample-app-k3s-main -- kubectl get pods -n oracledb`
   - To view logs for the Oracle Database pod:
     `multipass exec oracledb-sample-app-k3s-main -- kubectl logs -n oracledb <pod-name>`
   - To connect to the Oracle Database directly as sys user:
     `multipass exec oracledb-sample-app-k3s-main -- kubectl exec -it -n oracledb deployment/oracledb -- sqlplus / as sysdba`

3. *`Oracle Instant Client setup`*
   - To verify the persistent volume claim:
     `multipass exec oracledb-sample-app-k3s-main -- kubectl get pvc -n monitoring`

4. *`Database connectivity issues`*

   - **Verify the monitoring user exists and has correct permissions:**

     1. Connect to the Oracle Database as `sysdba`:
        ```sh
        multipass exec oracledb-sample-app-k3s-main -- bash -c "kubectl exec -it -n oracledb deployment/oracledb -- sqlplus / as sysdba"
        ```

     2. In the SQL*Plus prompt, switch to the correct PDB and check for the monitoring user:
        ```sql
        ALTER SESSION SET CONTAINER = FREEPDB1;
        SELECT username FROM dba_users WHERE username LIKE '%GRAFANAU%';
        ```

     3. You should see output similar to:
        ```
        C##GRAFANAU
        GRAFANAU
        ```

   - **Check if the database is accepting connections on port 1521:**
     ```sh
     multipass exec oracledb-sample-app-k3s-main -- kubectl get svc -n oracledb
     ```
