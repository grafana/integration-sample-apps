# Varnish Single Node sample app

This sample application stands up a single-node K3s cluster, with the [k8s-monitoring-helm](https://github.com/grafana/k8s-monitoring-helm) chart applied, and then spawns a full [Varnish Cache](https://varnish-cache.org) setup using a local Helm deployment with Varnish Cache, nginx backend, and prometheus_varnish_exporter. The sample app is capable of running both in a `ubuntu-latest-8-core` Github Actions runner, and locally.

## Quick Start for new users

To get started with the sample app, follow these steps:

1. **Clone the repository**: 
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd integration-sample-apps/sample-apps/varnish-single-node
   ```

2. **Stand up the sample app**
   Execute `make LOKI_INSTANCE=<loki_host>:<loki_port> PROMETHEUS_INSTANCE=<prom_host>:<prom_port> run-ci`, substituting the host and ports as required for your setup.
   This will take care of rendering the correct config and setup, as used in the Github Actions workflow on this repository.

3. **Stop and clean Up**: 
   Use `make stop` to clean up the k3s cluster and automatically clean up temporary files.

## Make commands

- `make default-monitoring-config`: Initializes the configuration file with default connection parameters used when applying the [k8s-monitoring-helm chart](https://github.com/grafana/k8s-monitoring-helm).
- `make render-config`: Generates the `monitoring-config.yaml` configuration file using the defined variables.
- `make run-ci`: Creates the Varnish sample app.
- `make install-suo`: Transfers required configs and installs Varnish; useful for debugging.
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

## Varnish configuration

The sample app configures a complete Varnish Cache stack including:

- **Varnish Cache**: Main caching server running on port 6081 using the `varnish:stable` image
- **nginx Backend**: Backend web server using `nginx:1.25.1` image to serve content
- **prometheus_varnish_exporter**: Custom-built metrics exporter (version 1.6.1) for exposing Varnish metrics to Prometheus

The deployment includes proper security contexts, shared process namespaces for metric collection, and persistent logging volumes.


## Validating

### Varnish Cache
- **Check deployment status**: Confirm that Varnish is deployed and running.
  ```bash
  kubectl get pods -n varnish
  ```
- **Check service status**: Verify the Varnish service is accessible.
  ```bash
  kubectl get services -n varnish
  ```

- **Test cache functionality**: Test if Varnish is serving content.
  ```bash
  kubectl port-forward -n varnish service/varnish-cache 80:80
  curl localhost:80
  ```

### Prometheus Varnish Exporter
- **Check metrics endpoint**: Verify metrics are being exposed.
  ```bash
  kubectl port-forward -n varnish deployment/varnish-cache 9131:9131
  curl localhost:9131/metrics
  ```

### k8s-monitoring-helm Chart
- **Check helm releases**: Verify the monitoring chart is installed.
  ```bash
  helm list -A
  ```
- **Check monitoring components**: Verify all monitoring components are running.
  ```bash
  kubectl get pods -n monitoring
  ```

## Troubleshooting

For debugging and troubleshooting, you can access the K3s VM directly using:

```sh
make shell
```

This opens a shell session to the running VM where you can execute the validation commands above and investigate any issues with the services.
