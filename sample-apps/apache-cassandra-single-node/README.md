# Apache Cassandra Single Node sample app

This sample application stands up a three node K3s cluster, with the [k8s-monitoring-helm](https://github.com/grafana/k8s-monitoring-helm) chart applied, and then spawns a full Apache Cassandra multi-node setup using a custom Docker image with built-in JMX monitoring. The sample app deploys a 2-replica StatefulSet of Cassandra nodes and is capable of running both in a `ubuntu-latest-8-core` Github Actions runner, and locally.

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
   cd integration-sample-apps/sample-apps/apache-cassandra-single-node
   ```

2. **Stand up the sample app**
   Execute `make LOKI_INSTANCE=<loki_host>:<loki_port> PROMETHEUS_INSTANCE=<prom_host>:<prom_port> run-ci`, substituting the host and ports as required for your setup.
   This will take care of rendering the correct config and setup, as used in the Github Actions workflow on this repository.

6. **Stop and clean Up**: 
   Use `make stop` to clean up the k3s cluster and automatically clean up temporary files.

## Make commands

- `make default-monitoring-config`: Initializes the configuration file with default connection parameters used when applying the [k8s-monitoring-helm chart](https://github.com/grafana/k8s-monitoring-helm).
- `make render-config`: Generates the `monitoring-config.yaml` configuration file using the defined variables.
- `make run-ci`: Creates the Apache Cassandra multi-node sample app.
- `make install-suo`: Transfers required configs and installs Apache Cassandra; useful for debugging.
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



## Notes about this Sample App

Docker is installed and builds an image that properly sets the java agent so the JMX Prometheus Exporter is configured properly. It is then deployed to the `StatefulSet` and corresponding `Service` and spins up a load generation cronjob to utilize `cassandra-stress` using the same container.


## Troubleshooting Commands:

### Check Pod Status
```bash
# Check if Cassandra pods are running
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl get pods -n cassandra

# Check pod details and events
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl describe pods -n cassandra

# Check StatefulSet status
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl get statefulset -n cassandra
```

### Check Cassandra Cluster Health
```bash
# Check Cassandra cluster status from pod
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl exec -n cassandra cassandra-0 -- nodetool status

# Check if nodes can see each other
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl exec -n cassandra cassandra-0 -- nodetool ring

# Check Cassandra logs
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl logs -n cassandra cassandra-0 -f
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl logs -n cassandra cassandra-1 -f
```

### Check Load Generation
```bash
# Check cronjob status
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl get cronjobs -n cassandra

# Check recent jobs
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl get jobs -n cassandra

# Check load generation job logs
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl logs -n cassandra -l job-name=apache-cassandra-loadgen
```

### Check Monitoring and Metrics
```bash
# Check if k8s-monitoring is running
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl get pods -n monitoring

# Check if metrics are being scraped (JMX exporter endpoint)
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl exec -n cassandra cassandra-0 -- curl -s localhost:9145/metrics | head -20

# Check Alloy configuration
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl logs -n monitoring -l app.kubernetes.io/name=alloy
```

### Check Services and Connectivity
```bash
# Check services
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl get svc -n cassandra

# Test connectivity between pods
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl exec -n cassandra cassandra-0 -- nc -zv cassandra-1.cassandra.cassandra.svc.cluster.local 7000

# Check if client port is accessible
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl exec -n cassandra cassandra-0 -- nc -zv localhost 9042
```

### Resource Usage and Performance
```bash
# Check resource usage
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl top pods -n cassandra

# Check events for resource issues
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl get events -n cassandra --sort-by='.lastTimestamp'
```

### Access Cassandra CLI
```bash
# Connect to Cassandra shell (cqlsh)
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl exec -it -n cassandra cassandra-0 -- cqlsh

# Run a simple query to test
multipass exec apache-cassandra-sample-app-k3s-main -- kubectl exec -n cassandra cassandra-0 -- cqlsh -e "DESCRIBE KEYSPACES;"
```

