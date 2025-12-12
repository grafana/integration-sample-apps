# Windows Node sample app

This sample application creates a Windows environment integrated with Alloy for metric and log collection. This sample app utilizes PowerShell scripts and GitHub Actions to facilitate the setup, configuration, and monitoring of Windows using the windows_exporter built into Alloy.

## Prerequisites

Before you begin, ensure you have the following:

- A Windows environment (GitHub Actions runner or local Windows machine)
- PowerShell 5.1 or later
- Internet connectivity for downloading Alloy

## Quick Start for new users

To get started with the sample app, follow these steps:

1. **Clone the repository**: 
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd sample-apps/windows
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `config/alloy-config.alloy` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Run the sample app**: 
   Use `make run` to start the Windows sample app.

4. **Stop and clean Up**: 
   Use `make stop` to clean up Alloy service and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for Alloy configuration.
- `make run`: Installs and starts the Windows sample app with Alloy.
- `make run-ci`: CI-compatible version that installs Alloy and runs metrics collection.
- `make stop`: Stops the Alloy service and cleans up.
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
1. Check if the service is running: `Get-Service -Name "Alloy" -ErrorAction SilentlyContinue`
2. Verify metrics endpoint: Navigate to `http://localhost:12345/metrics` in a browser
3. Check the configuration file at the installation directory

### Windows Exporter (via Alloy)
The windows_exporter is built into Alloy and will automatically collect system metrics including:
- CPU usage and info
- Memory usage
- Disk I/O and space
- Network interface statistics
- Windows services status
- System calls and processes
- Windows Event Logs

## Architecture

This sample app:
1. Downloads and installs the latest Grafana Alloy on Windows
2. Configures Alloy with the built-in windows_exporter
3. Sets up log collection from Windows Event Logs
4. Pushes metrics to Mimir and logs to Loki
5. Creates load by running background tasks to generate metrics 
