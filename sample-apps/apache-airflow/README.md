# Apache Airflow sample app

This sample application creates an Ubuntu VM integrated with Alloy for metric and log collection. This sample app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of [Apache Airflow](https://airflow.apache.org/) using StatsD metrics collection and comprehensive log aggregation.

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
   cd integration-sample-apps/sample-apps/apache-airflow
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VM**: 
   Use `make run` to start the Apache Airflow sample app.

5. **Access Airflow UI**: 
   Use `make airflow-ui` to get the URL for the Airflow web interface.

6. **Get Airflow credentials**: 
   Use `make airflow-creds` to retrieve the admin credentials for Airflow.

7. **Stop and clean Up**: 
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the Apache Airflow sample app VM with Airflow installed and configured.
- `make run-ci`: Runs in CI mode by cleaning, setting up default config, and launching the VM.
- `make shell`: Opens a shell session to the running VM for debugging and troubleshooting.
- `make airflow-ui`: Returns the URL for accessing the Airflow web interface.
- `make airflow-creds`: Retrieves the admin credentials for Airflow from the system logs.
- `make stop`: Stops and removes the VM, then purges multipass resources.
- `make clean`: Removes generated configuration files and temporary resources.

## Default configuration variables

- `interval`: Scrape interval for metrics collection (default: `10s`).
- `prom_pass`: Your Prometheus password.
- `prom_user`: Your Prometheus username.
- `prom_url`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9090/api/v1/push`).
- `loki_url`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.

## Apache Airflow version and configuration

The sample app automatically installs:

- **Apache Airflow 2.9.3** with StatsD support enabled
- **Python 3.12** runtime environment
- **Airflow Standalone Mode** for simplified deployment

## Airflow configuration

The sample app configures Airflow with the following setup:

- **Database**: PostgreSQL 16 with `postgres` user and password `sekret`
- **Airflow User**: Dedicated `airflow` system user with home directory at `/home/airflow`
- **Virtual Environment**: Python virtual environment at `/home/airflow/airflow-venv`
- **StatsD Metrics**: Enabled with UDP endpoint at `localhost:8125`
- **Web UI**: Accessible on port 8080 with auto-generated admin credentials
- **Logging**: Comprehensive DAG and scheduler log collection

## Monitoring and metrics

The sample app provides comprehensive monitoring through:

### StatsD Metrics
- **DAG and Task Metrics**: Duration, success/failure rates, start/finish counts
- **Scheduler Metrics**: Task queuing, execution, and scheduling delays
- **Pool Metrics**: Resource pool utilization and task distribution
- **Executor Metrics**: Open slots, queued tasks, and running tasks

### Log Collection
- **DAG Logs**: Task execution logs with DAG ID and task ID labeling
- **Scheduler Logs**: Scheduler operation logs with DAG file context
- **Structured Parsing**: Timestamp-based log parsing and multiline support

### Available Metrics
The following metrics are exposed through the StatsD exporter:
- `airflow_dag_task_duration`: Task execution duration by DAG and task
- `airflow_dagrun_duration_success/failed`: DAG run duration by outcome
- `airflow_task_start_total/finish_total`: Task lifecycle counters
- `airflow_dagrun_schedule_delay`: Scheduling delay metrics
- `airflow_pool_*_slots`: Resource pool utilization metrics
- `airflow_executor_*_tasks`: Executor task management metrics

## Validating services

### Alloy
- **Check service status**: Confirm that Alloy is running.
  ```bash
  systemctl status alloy.service
  ```
- **Review configuration**: Verify the configuration in `/etc/alloy/config.alloy` is correct.
- **Check logs**: Review Alloy logs for any connectivity or configuration issues.
  ```bash
  journalctl -u alloy.service
  ```

### Apache Airflow
- **Check service status**: Confirm that Airflow is running.
  ```bash
  systemctl status airflow.service
  ```
- **Verify web interface**: Access the Airflow UI using the URL from `make airflow-ui`.
- **Test database connection**: Verify PostgreSQL connectivity.
  ```bash
  sudo -u postgres psql -c "SELECT version();"
  ```
- **Check logs**: Review Airflow logs for any issues.
  ```bash
  journalctl -u airflow.service
  ```

### StatsD Exporter
- **Check metrics endpoint**: Verify StatsD metrics are being exposed.
  ```bash
  curl localhost:9090/metrics | grep airflow
  ```
- **Verify StatsD reception**: Check if Airflow is sending metrics to StatsD.
  ```bash
  netstat -ul | grep 8125
  ```

### PostgreSQL
- **Check service status**: Confirm that PostgreSQL is running.
  ```bash
  systemctl status postgresql.service
  ```
- **Test database access**: Verify database connectivity.
  ```bash
  sudo -u postgres psql -d postgres -c "SELECT current_database();"
  ```

## Accessing Airflow

### Web Interface
1. Get the Airflow UI URL: `make airflow-ui`
2. Retrieve admin credentials: `make airflow-creds`
3. Access the web interface and log in with the provided credentials

### Command Line Interface
Access the Airflow CLI through the VM:
```bash
make shell
sudo -u airflow /home/airflow/airflow-venv/bin/airflow --help
```

## Troubleshooting

### Common Issues

1. **Airflow Service Not Starting**
   - Check the installation log: `cat /home/ubuntu/airflow-install.log`
   - Verify Python and pip installation
   - Check systemd service configuration

2. **No Metrics in Prometheus**
   - Verify StatsD is receiving metrics: `netstat -ul | grep 8125`
   - Check Alloy configuration and connectivity
   - Ensure Airflow StatsD is enabled in configuration

3. **Log Collection Issues**
   - Verify Alloy has access to Airflow logs
   - Check if the `alloy` user is in the `airflow` group
   - Review log file permissions in `/home/airflow/airflow/logs/`

### Debugging Commands

For debugging and troubleshooting, you can access the VM directly using:
```bash
make shell
```

This opens a shell session to the running VM where you can:
- Execute validation commands
- Check service logs
- Investigate configuration issues
- Monitor resource usage

Additional debugging locations:
- Airflow configuration: `/home/airflow/airflow/airflow.cfg`
- Airflow logs: `/home/airflow/airflow/logs/`
- Installation log: `/home/ubuntu/airflow-install.log`
- StatsD mapping: `/home/ubuntu/statsd_mapping.yaml`
- Credentials: `/home/ubuntu/airflow-creds.json`
