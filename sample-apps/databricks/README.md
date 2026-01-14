# Databricks Monitoring Runbook

This runbook guides you through setting up monitoring for Databricks using Grafana Alloy. Unlike automated sample apps, this requires manual configuration in your existing Databricks workspace.

## Prerequisites

Before you begin, ensure you have the following:

- A Databricks workspace with Unity Catalog enabled
- Administrative access to create Service Principals
- A SQL Warehouse (serverless is recommended for cost efficiency)
- Grafana Alloy installed on a host that can reach Databricks APIs
- Grafana Cloud credentials (or any Prometheus-compatible endpoint)

## Quick Start

To get started with this runbook, follow these steps:

1. **Clone the repository**:
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd sample-apps/databricks
   ```
1. **Configure Databricks** (follow Databricks Configuration section below)
1. **Configure Alloy**:
   - Copy `configs/alloy-simple.alloy` to your Alloy config directory
   - Update with your Databricks credentials and workspace details
   - Restart Alloy service
1. **Verify metrics**:
   - Query `databricks_up` in your Prometheus instance
   - Check Alloy logs for successful scrapes

## Databricks Configuration

### Step 1: Get your workspace hostname

1. Copy your workspace URL subdomain, for example, `dbc-abc123-def456.cloud.databricks.com`.

### Step 2: Create or configure SQL Warehouse

1. Go to **SQL Warehouses** in the sidebar.
1. Either select an existing warehouse or click **Create SQL warehouse**:
   - **Size**: 2X-Small (minimum size to reduce costs)
   - **Auto stop**: After 10 minutes of inactivity
   - **Scaling**: Min 1, Max 1 cluster
1. Click **Create**, then go to the **Connection Details** tab.
1. Copy the **HTTP path**, for example, `/sql/1.0/warehouses/abc123def456`.

### Step 3: Create a Service Principal

1. Click your workspace name (top-right) and select **Manage Account**.
1. Go to **User Management** > **Service Principals** tab > **Add service principal**.
1. Enter a name, for example, `grafana-cloud-integration`.
1. Go to **Credentials & secrets** tab > **OAuth secrets** > **Generate secret**.
1. Select the maximum lifetime (730 days) and click **Generate**.
1. Copy the **Client ID** and **Client Secret**. You will need both for the Alloy configuration.

### Step 4: Assign the Service Principal to your workspace

1. Go to **Workspaces** in the sidebar and select your workspace.
1. Go to the **Permissions** tab and click **Add permissions**.
1. Search for the Service Principal and assign it the **Admin** permission.

### Step 5: Grant SQL permissions to the Service Principal

As a metastore admin or user with MANAGE privilege, run the following SQL statements in a query editor:

```sql
GRANT USE CATALOG ON CATALOG system TO `<your-service-principal-client-id>`;
GRANT USE SCHEMA ON SCHEMA system.billing TO `<your-service-principal-client-id>`;
GRANT SELECT ON SCHEMA system.billing TO `<your-service-principal-client-id>`;
GRANT USE SCHEMA ON SCHEMA system.query TO `<your-service-principal-client-id>`;
GRANT SELECT ON SCHEMA system.query TO `<your-service-principal-client-id>`;
GRANT USE SCHEMA ON SCHEMA system.lakeflow TO `<your-service-principal-client-id>`;
GRANT SELECT ON SCHEMA system.lakeflow TO `<your-service-principal-client-id>`;
```

Replace `<your-service-principal-client-id>` with your Service Principal's Client ID.

Refer to the [Databricks documentation](https://docs.databricks.com/en/dev-tools/auth/oauth-m2m.html) for detailed OAuth2 M2M setup instructions.

## Alloy Configuration

### Simple Configuration

See [`configs/alloy-simple.alloy`](configs/alloy-simple.alloy) for a basic setup that collects all default metrics with recommended settings.

### Advanced Configuration

See [`configs/alloy-advanced.alloy`](configs/alloy-advanced.alloy) for a configuration with all optional parameters, tuning options, and metric filtering examples.

### Environment Variables

Store sensitive credentials as environment variables:

```bash
export DATABRICKS_CLIENT_ID="your-application-id"
export DATABRICKS_CLIENT_SECRET="your-client-secret"
export PROMETHEUS_URL="https://prometheus-prod-us-central1.grafana.net/api/prom/push"
export PROMETHEUS_USER="your-prometheus-username"
export PROMETHEUS_PASS="your-prometheus-password"
```

### Configuration Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `server_hostname` | Required | Databricks workspace hostname (e.g., `dbc-abc123.cloud.databricks.com`) |
| `warehouse_http_path` | Required | SQL Warehouse HTTP path (e.g., `/sql/1.0/warehouses/xyz`) |
| `client_id` | Required | OAuth2 Application ID of your Service Principal |
| `client_secret` | Required | OAuth2 Client Secret |
| `query_timeout` | `5m` | Timeout for individual SQL queries |
| `billing_lookback` | `24h` | How far back to query billing data |
| `jobs_lookback` | `3h` | How far back to query job runs |
| `pipelines_lookback` | `3h` | How far back to query pipeline runs |
| `queries_lookback` | `2h` | How far back to query SQL warehouse queries |
| `sla_threshold_seconds` | `3600` | Duration threshold for job SLA miss detection |
| `collect_task_retries` | `false` | Collect task-level retry metrics (⚠️ high cardinality) |

### Tuning Recommendations

- **`scrape_interval`**: Use 10-30 minutes. The exporter queries Databricks System Tables which can be slow and costly. Increase the interval to reduce SQL Warehouse usage.
- **`scrape_timeout`**: Must be less than `scrape_interval`. Typical scrapes take 90-120 seconds depending on data volume.
- **Lookback windows**: Should be at least 2x the scrape interval to ensure data continuity between scrapes. The defaults (`3h` for jobs and pipelines, `2h` for queries) work well with 10-30 minute scrape intervals.

## Validating Metrics

### Check Alloy Status

```bash
# Check Alloy service status
systemctl status alloy

# View Alloy logs
journalctl -u alloy -f

# Check metrics endpoint
curl http://localhost:12345/metrics | grep databricks
```

### Verify in Prometheus

Query for the health metric:

```promql
databricks_up{job="databricks"}
```

Should return `1` if the exporter is healthy.

### Check Key Metrics

```promql
# Billing metrics
databricks_billing_dbus_total

# Job metrics
databricks_job_runs_total

# Query metrics
databricks_queries_total

# Exporter up/down
databricks_up
```

## Metrics Collected

The exporter collects 18 metrics across four categories:

### Billing Metrics
- `databricks_billing_dbus_total` - Daily DBU consumption per workspace and SKU
- `databricks_billing_cost_estimate_usd` - Estimated cost in USD
- `databricks_price_change_events_total` - Count of price changes per SKU

### Job Metrics
- `databricks_job_runs_total` - Total job runs
- `databricks_job_run_status_total` - Job run counts by result state
- `databricks_job_run_duration_seconds` - Job duration quantiles (p50, p95, p99)
- `databricks_task_retries_total` - Task retry counts (optional, high cardinality)
- `databricks_job_sla_miss_total` - Jobs exceeding SLA threshold

### Pipeline Metrics
- `databricks_pipeline_runs_total` - Total pipeline runs
- `databricks_pipeline_run_status_total` - Pipeline runs by result state
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

## Troubleshooting

### Common Issues

#### Authentication Errors (401)
**Symptom**: Alloy logs show `401 Unauthorized`

**Solution**:
- Verify Client ID and Client Secret are correct
- Ensure the Service Principal exists and hasn't expired (check OAuth secret lifetime)
- Verify the Service Principal has workspace Admin permission

#### No Metrics Appearing
**Symptom**: `databricks_up` returns no data or returns `0`

**Solution**:
- Check that the SQL Warehouse is running (or configured to auto-start)
- Verify the Service Principal has all required SQL permissions (re-run GRANT statements)
- Check Alloy logs for SQL query errors
- Verify network connectivity to `<your-workspace>.cloud.databricks.com`

#### SQL Permission Errors
**Symptom**: Alloy logs show `PERMISSION_DENIED` or `TABLE_OR_VIEW_NOT_FOUND`

**Solution**:
- Re-run the GRANT SQL statements as a metastore admin
- Verify Unity Catalog is enabled in your workspace
- Check that System Tables are enabled (they should be by default with Unity Catalog)

#### Connection Timeouts
**Symptom**: Queries take longer than `scrape_timeout`

**Solution**:
- Increase `scrape_timeout` (but keep it less than `scrape_interval`)
- Reduce lookback windows to query less data
- Use a larger SQL Warehouse size if queries are consistently slow
- Consider increasing `scrape_interval` to 20-30 minutes

#### High Cardinality Warning
**Symptom**: Too many time series, high storage costs

**Solution**:
- Disable `collect_task_retries` if enabled (this adds `task_key` label)
- Review metric cardinality with `databricks_*` queries in Prometheus
- Consider metric relabeling to drop high-cardinality labels (see `alloy-advanced.alloy` for examples)

## Make Commands

This runbook provides validation commands:

- `make validate-config` - Validate Alloy configuration syntax
- `make test` - Run metric validation tests
- `make clean` - Clean up temporary files
- `make help` - Show available commands

## Additional Resources

- [Databricks OAuth2 M2M Documentation](https://docs.databricks.com/en/dev-tools/auth/oauth-m2m.html)
- [Databricks System Tables Documentation](https://docs.databricks.com/en/admin/system-tables/index.html)
- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Databricks Exporter GitHub](https://github.com/grafana/databricks-prometheus-exporter)
- [Integration Documentation](https://grafana.com/docs/grafana-cloud/monitor-infrastructure/integrations/integration-reference/integration-databricks/)

## Platform Support

This runbook is platform-agnostic. Grafana Alloy can be installed on:
- Linux (systemd service)
- Docker (container)
- Kubernetes (Helm chart or operator)

Refer to the [Alloy installation documentation](https://grafana.com/docs/alloy/latest/get-started/install/) for your platform.
