# Tensorflow Serving sample app

This sample application creates an Ubuntu VM running a docker container with [Tensorflow Serving](https://www.tensorflow.org/tfx/serving/setup) installed and integrated with Alloy for metric and log collection. The app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of Tensorflow Serving using Alloy.

This sample app also ships with a simple `loadgen.sh` script to generate server metrics which are the metrics prefixed with: `:tensorflow:serving:` if you are not receiving these metrics that is likely the issue.

> Note: This application utilizes a pre-built docker image which includes a pre-built sample model for Tensorflow Serving to expose.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Multipass](https://multipass.run/)
- Docker (for rendering the cloud-init configuration)
- Git (for cloning the repository)

## Platform Support
Currently, this sample app supports both amd64 and ARM64 platforms.

## Quick Start for new users

To get started with the sample app, follow these steps:

1. **Clone the repository**: 
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd integration-sample-apps/tensorflow
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VMs**: 
   Use `make run` to start the Tensorflow Serving sample app.

5. **Stop and clean Up**: 
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the Tensorflow Serving sample app.
- `make stop`: Stops the running VM.
- `make clean`: Deletes all created VMs and performs cleanup.

## Default configuration variables

- `prom_pass`: Your Prometheus password.
- `prom_user`: Your Prometheus username.
- `prom_url`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9090/api/v1/push`).
- `loki_url`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.

## Validating services

### Alloy

Alloy is set up to monitor the REST/API endpoint from the Tensorflow Serving container.

- **Check service status**: Confirm that Alloy is running.
  ```bash
  systemctl status alloy.service
  ```
- **Review configuration**: Verify the configuration in `/etc/alloy/config.alloy` is correct.
- **Check logs**: Review Alloy logs for any connectivity or configuration issues.
  ```bash
  journalctl -u alloy.service
  ```

### Tensorflow Serving

- **Check service status**: Confirm that the Tensorflow Serving container is running.
  ```bash
  sudo docker ps
  ```
  Should return a container running this image: `ghcr.io/observiq/tensorflow`

  ```sh
  CONTAINER ID   IMAGE                                 COMMAND                  CREATED          STATUS          PORTS                                                   NAMES
  3722e9fb8927   ghcr.io/observiq/tensorflow:dc57387   "/usr/bin/tf_serving…"   14 minutes ago   Up 14 minutes   8500/tcp, 0.0.0.0:8501->8501/tcp, [::]:8501->8501/tcp   tensorflow-serving
  ```

- **Test the model**: Use curl to make a prediction using the container
  ```sh
  curl \
      --silent \
      --output /dev/null \
      -H "Content-Type: application/json" \
      -d '{"instances": [[13.0], [23.0], [53.0], [103.0], [503.0], [15.0], [17.0]]}' \
      -X POST \
      http://localhost:8501/v1/models/half_plus_two:predict
  ```

- **Check logs**: Review container logs for any errors.
  ```bash
  multipass exec tensorflow-sample-app -- sudo docker logs tensorflow-serving
  ```