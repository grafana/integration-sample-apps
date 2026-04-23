# macOS Node sample app

This sample application creates a macOS environment integrated with Alloy for metric and log collection. This sample app utilizes Bash scripts and GitHub Actions to facilitate the setup, configuration, and monitoring of macOS using Grafana Alloy installed via Homebrew.

## Prerequisites

Before you begin, ensure you have the following:

- A macOS environment (GitHub Actions `macos-latest` runner or a local Apple-silicon Mac)
- [Homebrew](https://brew.sh/) installed and on `PATH`
- Bash 3.2 or later (shipped with macOS)
- Internet connectivity for downloading Alloy and its dependencies

## Quick Start for new users

1. **Clone the repository**:

   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd sample-apps/macos
   ```

2. **Set up default config**:
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `config/alloy-config.alloy` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Run the sample app**:
   Use `make run` to start the macOS sample app.

4. **Stop and clean up**:
   Use `make stop` to stop the Alloy service and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the Alloy configuration file with default values.
- `make run`: Installs and starts the macOS sample app with Alloy.
- `make run-ci`: CI-compatible version that installs Alloy and runs metrics collection.
- `make stop`: Stops the Alloy service.
- `make clean`: Removes temporary files and configuration.

## Default configuration variables

- `PROM_URL`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9009/api/v1/push`).
- `PROM_USER`: Your Prometheus username (optional).
- `PROM_PASS`: Your Prometheus password (optional).
- `LOKI_URL`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `LOKI_USER`: Your Loki username (optional).
- `LOKI_PASS`: Your Loki password (optional).

## Validating services

### Alloy

To validate that Alloy is running correctly:

1. Check if the service is running: `brew services list | grep alloy`
2. Verify metrics endpoint: Navigate to `http://localhost:12345/metrics` in a browser
3. Check the configuration file at `$(brew --prefix)/etc/alloy/config.alloy`

## Architecture

This sample app:

1. Installs the latest Grafana Alloy on macOS via Homebrew (`brew install grafana/grafana/alloy`)
2. Configures Alloy with an initial placeholder pipeline (to be populated in a follow-up)
3. Starts Alloy as a Homebrew service
4. Pushes metrics to Mimir and logs to Loki
5. Creates load by running background tasks to generate metrics

> Note: The Alloy configuration generator (`scripts/create_default_config.sh`) is currently a placeholder and does not define any pipelines. Exporters, scrape jobs, remote_write, and log sources are intentionally left blank and will be added in a follow-up change. As a result, CI metric validation will fail by design until `tests/metrics/` and a matching `tests/configs/` entry are authored.
