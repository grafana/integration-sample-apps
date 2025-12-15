# Databricks Sample Application

This sample application sets up monitoring for Databricks using Grafana Alloy. The application runs the Databricks Prometheus Exporter in a containerized environment and includes automated setup using cloud-init.

## Overview

The sample application:
- Deploys the [Databricks Prometheus Exporter](https://github.com/grafana/databricks-prometheus-exporter) as a Docker container
- Configures Grafana Alloy to scrape metrics from the exporter
- Forwards metrics to Grafana Cloud (or any Prometheus-compatible remote write endpoint)
- Automates the entire setup process using cloud-init

## Prerequisites

- [Multipass](https://multipass.run/) for VM management
- A Databricks workspace with Unity Catalog enabled
- A Databricks Service Principal with OAuth2 credentials
- A running SQL Warehouse (or one configured to auto-start)

## Databricks Configuration

Before running the sample app, you need to set up authentication in your Databricks workspace.

### 1. Create a Service Principal

1. Log into your Databricks workspace
2. Go to **Settings** → **Admin Console** → **Service Principals**
3. Click **Add Service Principal**
4. Note the **Application ID** (this is your Client ID)
5. Click **Generate Secret** under OAuth Secrets
6. Copy and securely store the **Client Secret**

### 2. Grant Required Permissions

Run these SQL commands as a Databricks admin (replace `<service-principal-id>` with your Application ID):

```sql
GRANT MANAGE ON CATALOG system TO `<service-principal-id>`;
GRANT USE CATALOG ON CATALOG system TO `<service-principal-id>`;
GRANT USE SCHEMA ON SCHEMA system.billing TO `<service-principal-id>`;
GRANT SELECT ON SCHEMA system.billing TO `<service-principal-id>`;
GRANT USE SCHEMA ON SCHEMA system.query TO `<service-principal-id>`;
GRANT SELECT ON SCHEMA system.query TO `<service-principal-id>`;
GRANT USE SCHEMA ON SCHEMA system.lakeflow TO `<service-principal-id>`;
GRANT SELECT ON SCHEMA system.lakeflow TO `<service-principal-id>`;
GRANT SELECT ON TABLE system.lakeflow.pipeline_update_timeline TO `<service-principal-id>`;
```

### 3. Get Configuration Values

- **Server Hostname**: Found in your Databricks workspace URL (e.g., `dbc-abc123-def456.cloud.databricks.com`)
- **Warehouse HTTP Path**: Go to **SQL Warehouses** → Select your warehouse → **Connection Details** → Copy **HTTP Path**
- **Client ID**: The **Application ID** from step 1
- **Client Secret**: The secret generated in step 1

## Configuration

1. Create a configuration file:
```bash
make defaultconfig
```

2. Edit `jinja/variables/cloud-init.yaml` with your credentials:
```yaml
# Grafana Cloud endpoints
loki_url: https://logs-prod-us-central1.grafana.net/loki/api/v1/push
loki_user: your_loki_username
loki_pass: your_loki_password
prom_url: https://prometheus-prod-us-central1.grafana.net/api/prom/push
prom_user: your_prometheus_username
prom_pass: your_prometheus_password

# Databricks OAuth2 Service Principal credentials
databricks_server_hostname: dbc-abc123-def456.cloud.databricks.com
databricks_warehouse_http_path: /sql/1.0/warehouses/abc123def456
databricks_client_id: your-application-id
databricks_client_secret: your-client-secret
```

## Usage

### Running the Application

1. Launch the VM with the sample application:
```bash
make run
```

This command will:
- Create a new VM named `databricks-sample-app`
- Configure the VM using cloud-init
- Deploy the Databricks exporter in a Docker container
- Set up Grafana Alloy for monitoring and forwarding metrics

### Stopping the Application

To stop and clean up the VM:
```bash
make stop
```

## Metrics Collected

The exporter collects 18 metrics across four categories:

### Billing Metrics
- `databricks_billing_dbus_total` - Daily DBU consumption per workspace and SKU
- `databricks_billing_cost_estimate_usd` - Estimated cost in USD
- `databricks_price_change_events` - Count of price changes per SKU

### Job Metrics
- `databricks_job_runs_total` - Total job runs
- `databricks_job_run_status` - Job run counts by result state
- `databricks_job_run_duration_seconds` - Job duration quantiles (p50, p95, p99)
- `databricks_task_retries_total` - Task retry counts
- `databricks_job_sla_miss_total` - Jobs exceeding SLA threshold

### Pipeline Metrics
- `databricks_pipeline_runs_total` - Total pipeline runs
- `databricks_pipeline_run_status` - Pipeline runs by result state
- `databricks_pipeline_run_duration_seconds` - Pipeline duration quantiles
- `databricks_pipeline_retry_events_total` - Pipeline retry counts
- `databricks_pipeline_freshness_lag_seconds` - Data freshness lag

### SQL Query Metrics
- `databricks_queries_total` - Total SQL queries executed
- `databricks_query_errors_total` - Failed query count
- `databricks_query_duration_seconds` - Query duration quantiles
- `databricks_queries_running` - Estimated concurrent queries

### System Metrics
- `databricks_up` - Exporter health (1 = healthy, 0 = unhealthy)

## Development

### Project Structure
```
databricks/
├── .CI_BYPASS           # Excludes from CI (cloud service)
├── Makefile             # Build and deployment commands
├── README.md            # This file
├── jinja/
│   └── templates/       # Cloud-init templates
└── tests/
    ├── configs/         # Test configuration
    └── metrics/         # Expected metrics list
```

### Available Make Commands

- `make run` - Launch the VM with the sample application
- `make stop` - Stop and delete the VM
- `make render-config` - Generate cloud-init configuration
- `make clean` - Clean up generated files
- `make defaultconfig` - Create default configuration template

## Troubleshooting

### Check VM Status
```bash
multipass info databricks-sample-app
```

### View Cloud-Init Logs
```bash
multipass exec databricks-sample-app -- sudo cat /var/log/cloud-init-output.log
```

### Check Alloy Status
```bash
multipass exec databricks-sample-app -- systemctl status alloy
```

### Check Exporter Container
```bash
multipass exec databricks-sample-app -- docker ps
multipass exec databricks-sample-app -- docker logs databricks-exporter
```

### Verify Metrics
```bash
multipass exec databricks-sample-app -- curl -s localhost:9976/metrics | head -50
```

### Common Issues

1. **Authentication Errors (401)**: Verify Client ID and Client Secret are correct
2. **No Metrics**: Check that the SQL Warehouse is running and the Service Principal has required permissions
3. **Connection Errors**: Verify the Server Hostname doesn't include `https://` prefix

For more detailed troubleshooting, see the [Databricks Exporter README](https://github.com/grafana/databricks-prometheus-exporter#troubleshooting).

