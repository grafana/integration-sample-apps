# Catchpoint Exporter with Multipass

This sample application sets up a Catchpoint Exporter in a VM environment using Multipass, integrated with Grafana Flow/Alloy for metric collection. This setup uses cloud-init and Make commands to facilitate the configuration and monitoring of the Catchpoint Exporter instance using mock generated load.

*Note*: To ensure a working Catchpoint Exporter instance, sufficient memory and CPU resources are allocated to each VM.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Multipass](https://multipass.run/)
- Docker (for building images and rendering cloud-init configurations)
- Git (for version control and repository management)
- Catchpoint setup to collect metrics from the [Prometheus exporter](https://github.com/grafana/catchpoint-prometheus-exporter/blob/main/README.md)

## Platform Support
Currently, this sample app supports ARM64 and amd64 platforms.

## Quick Start for new users

To get started with the Catchpoint Exporter along with monitoring tools, follow these steps:

1. **Clone the repository**: 
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd integration-sample-apps/catchpoint
   ```
2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to configure Grafana flow to connect to an external Prometheus instance.

3. **Create and set up VMs**: 
   Use `make run-catchpoint-multipass` to start VMs with the Catchpoint Exporter. Optionally, instead use `make all` to port-forward and run the load generation together which is step 4.

4. **Port-forward and run load generation**:
   Start port-forwarding and generate load by running `make port-forward` followed by `make run-metrics`. This will forward the necessary ports and run the `post_metrics.py` script to generate load.

5. **Fetch Prometheus metrics**: 
   Fetch metrics from the Prometheus exporter and save them with `make fetch-prometheus-metrics`.

6. **Stop and clean Up**: 
   Use `make stop-catchpoint-multipass` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run-catchpoint-multipass`: Creates VMs and sets up the Catchpoint Exporter.
- `make port-forward`: Starts port-forwarding for the Prometheus exporter.
- `make run-metrics`: Runs the `post_metrics.py` script to generate load.
- `make all`: Combines `run-catchpoint-multipass` `port-forward` and `run-metrics`.
- `make fetch-prometheus-metrics`: Fetches metrics from the Prometheus exporter and saves them to a local file.
- `make clean`: Deletes all created VMs and performs cleanup.

## Default configuration variables

The following are the default variables used in the `cloud-init.yaml` file:

- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.
- `prom_host`: Your Prometheus host (Default https://prometheus-us-central1.grafana.net).
- `prom_user`: Your Prometheus username.
- `prom_pass`: Your Prometheus password.
