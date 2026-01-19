# Pinecone Monitoring Runbook

This runbook guides you through setting up monitoring for Pinecone using Grafana Alloy. Unlike automated sample apps, this requires manual configuration with your existing Pinecone account. Pinecone is a cloud-hosted SaaS service that cannot be spun up locally.

## Prerequisites

Before you begin, ensure you have the following:

- A Pinecone account with Standard or Enterprise plan (Prometheus exporter is not available on Starter plan)
- API key with access to your Pinecone project(s)
- Project ID(s) for the Pinecone project(s) you want to monitor
- Grafana Alloy installed on a host that can reach Pinecone APIs
- Grafana Cloud credentials (or any Prometheus-compatible endpoint)

## Quick Start

To get started with this runbook, follow these steps:

1. **Clone the repository**:
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd sample-apps/pinecone
   ```

2. **Get your Pinecone credentials** (follow Pinecone Configuration section below)

3. **Configure Alloy**:
   - Copy `configs/alloy-simple.alloy` to your Alloy config directory
   - Update with your Pinecone project ID and API key
   - Restart Alloy service

4. **Verify metrics**:
   - Query `pinecone_db_record_total` in your Prometheus instance
   - Check Alloy logs for successful scrapes

## Pinecone Configuration

### Step 1: Get your Project ID

1. Log in to the [Pinecone Console](https://app.pinecone.io/)
2. Navigate to your project
3. Your Project ID can be found in the project settings or URL
4. The Project ID is typically a UUID format (e.g., `12345678-1234-1234-1234-123456789abc`)

### Step 2: Get your API Key

1. In the Pinecone Console, go to **API Keys** in the left sidebar
2. Either use an existing API key or create a new one
3. Copy the API key value (you won't be able to see it again after creation)
4. Ensure the API key has access to the project(s) you want to monitor

### Step 3: Verify Prometheus Exporter Access

1. Ensure your Pinecone plan includes Prometheus monitoring (Standard or Enterprise)
2. The Prometheus exporter is available at: `https://api.pinecone.io/prometheus/projects/<your-project-ID>/metrics/discovery`
3. You can test access by making a curl request:
   ```bash
   curl -H "Authorization: Bearer <your-api-key>" \
     "https://api.pinecone.io/prometheus/projects/<your-project-ID>/metrics/discovery"
   ```
4. This should return a JSON response with target information

For more details, see the [Pinecone monitoring documentation](https://docs.pinecone.io/guides/production/monitoring#monitor-with-prometheus).

## Alloy Configuration

### Simple Configuration (Single Project)

See [`configs/alloy-simple.alloy`](configs/alloy-simple.alloy) for a basic setup that monitors a single Pinecone project with recommended settings.

### Advanced Configuration (Multiple Projects)

See [`configs/alloy-advanced.alloy`](configs/alloy-advanced.alloy) for a configuration that monitors multiple Pinecone projects with relabeling to distinguish metrics by project.

### Environment Variables

Store sensitive credentials as environment variables:

```bash
export PINECONE_API_KEY="your-api-key"
export PINECONE_PROJECT_ID="your-project-id"
export PROMETHEUS_URL="https://prometheus-prod-us-central1.grafana.net/api/prom/push"
export PROMETHEUS_USER="your-prometheus-username"
export PROMETHEUS_PASS="your-prometheus-password"
```

### Configuration Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `url` | Required | Pinecone discovery endpoint URL (e.g., `https://api.pinecone.io/prometheus/projects/<project-ID>/metrics/discovery`) |
| `api_key` | Required | Pinecone API key for authentication |
| `refresh_interval` | `1m` | How often to refresh the service discovery targets |
| `scrape_interval` | `15s` | How often to scrape metrics from Pinecone (recommended: 15s-1m) |
| `scrape_timeout` | `30s` | Timeout for individual metric scrapes |

### Tuning Recommendations

- **`refresh_interval`**: Use 1 minute. Pinecone's service discovery endpoint provides dynamic target information that may change as indexes are created or deleted.
- **`scrape_interval`**: The [Pinecone documentation](https://docs.pinecone.io/guides/production/monitoring#monitor-with-prometheus) recommends 15 seconds, but you can adjust based on your needs (15s-1m). More frequent scraping provides better granularity but increases API usage.
- **`scrape_timeout`**: Set to 30 seconds. Most scrapes complete quickly, but allow time for multiple index endpoints.

### Multiple Projects

If you have multiple Pinecone projects, you need to add separate scrape configurations for each project. It is recommended to add a `project_id` label via relabeling to distinguish metrics from different projects. See [`configs/alloy-advanced.alloy`](configs/alloy-advanced.alloy) for an example configuration.

## Validating Metrics

### Check Alloy Status

```bash
# Check Alloy service status
systemctl status alloy

# View Alloy logs
journalctl -u alloy -f

# Check metrics endpoint
curl http://localhost:12345/metrics | grep pinecone
```

### Verify in Prometheus

Query for index records to verify metrics are being collected:

```promql
sum by (index_name) (pinecone_db_record_total)
```

Should return data for each index in your project.

### Check Key Metrics

```promql
# Total number of records per index
sum by (index_name) (pinecone_db_record_total)

# Total number of records in a specific index
pinecone_db_record_total{index_name="docs-example"}

# Upsert requests per second per index
sum by (index_name) (rate(pinecone_db_op_upsert_count[5m]))

# Average upsert duration in milliseconds per index
(sum by (index_name) (rate(pinecone_db_op_upsert_duration_sum[1m]))) / 
(sum by (index_name) (rate(pinecone_db_op_upsert_count[1m])))

# Query requests per second per index
sum by (index_name) (rate(pinecone_db_op_query_count[5m]))

# Read units consumed per second per index
sum by (index_name) (rate(pinecone_db_read_unit_count[5m]))

# Write units consumed per second for a specific index
sum (rate(pinecone_db_write_unit_count{index_name="docs-example"}[5m]))
```

## Metrics Collected

Pinecone's built-in Prometheus exporter provides the following metrics as documented in the [official Pinecone documentation](https://docs.pinecone.io/guides/production/monitoring#monitor-with-prometheus):

### Index Metrics
- `pinecone_db_record_total` (gauge) - The total number of records in the index
- `pinecone_db_storage_size_bytes` (gauge) - The total size of the index in bytes

### Operation Count Metrics
- `pinecone_db_op_upsert_count` (counter) - The number of upsert requests
- `pinecone_db_op_query_count` (counter) - The number of query requests
- `pinecone_db_op_fetch_count` (counter) - The number of fetch requests
- `pinecone_db_op_update_count` (counter) - The number of update requests
- `pinecone_db_op_delete_count` (counter) - The number of delete requests

### Operation Duration Metrics
- `pinecone_db_op_upsert_duration_sum` (counter) - Total time taken processing upsert requests in milliseconds
- `pinecone_db_op_query_duration_sum` (counter) - Total time taken processing query requests in milliseconds
- `pinecone_db_op_fetch_duration_sum` (counter) - Total time taken processing fetch requests in milliseconds
- `pinecone_db_op_update_duration_sum` (counter) - Total time taken processing update requests in milliseconds
- `pinecone_db_op_delete_duration_sum` (counter) - Total time taken processing delete requests in milliseconds

### Resource Usage Metrics
- `pinecone_db_write_unit_count` (counter) - The total number of write units consumed by an index
- `pinecone_db_read_unit_count` (counter) - The total number of read units consumed by an index

### Metric Labels

Each metric contains the following labels:
- `index_name` - Name of the index to which the metric applies
- `cloud` - Cloud where the index is deployed: `aws`, `gcp`, or `azure`
- `region` - Region where the index is deployed
- `capacity_mode` - Type of index: `serverless` or `byoc`
- `instance` - Server instance (only available for counter metrics)

**Note:** Some metric names changed on December 19, 2025. The current names listed above are the latest. For historical reference, see the [Pinecone monitoring documentation](https://docs.pinecone.io/guides/production/monitoring#monitor-with-prometheus).

## Troubleshooting

### Common Issues

#### Authentication Errors (401)
**Symptom**: Alloy logs show `401 Unauthorized` or `Invalid API key`

**Solution**:
- Verify your API key is correct and hasn't expired
- Ensure the API key has access to the project you're trying to monitor
- Check that you're using the correct project ID in the URL
- Verify your Pinecone plan includes Prometheus monitoring (Standard or Enterprise)

#### No Metrics Appearing
**Symptom**: `pinecone_db_record_total` returns no data

**Solution**:
- Verify the discovery endpoint is accessible: `curl -H "Authorization: Bearer <key>" "https://api.pinecone.io/prometheus/projects/<project-ID>/metrics/discovery"`
- Check that you have at least one index in your project (empty projects may not expose metrics)
- Verify your Pinecone plan supports Prometheus monitoring
- Check Alloy logs for service discovery errors
- Ensure network connectivity to `api.pinecone.io`

#### Service Discovery Returns Empty Targets
**Symptom**: Alloy logs show no targets discovered

**Solution**:
- Verify you have active indexes in your Pinecone project
- Check that the project ID in the URL matches your actual project ID
- Ensure your API key has read access to the project
- Try manually querying the discovery endpoint to see what targets are returned

#### High Cardinality Warning
**Symptom**: Too many time series, high storage costs

**Solution**:
- Review metric cardinality with `pinecone_*` queries in Prometheus
- Consider using metric relabeling to drop high-cardinality labels
- Filter metrics if you only need specific ones (see `alloy-advanced.alloy` for examples)
- Monitor the number of indexes in your project (each index adds multiple time series)

#### Connection Timeouts
**Symptom**: Scrapes take longer than `scrape_timeout`

**Solution**:
- Increase `scrape_timeout` (but keep it reasonable, e.g., 30-60 seconds)
- Check network connectivity to Pinecone APIs
- Verify your project doesn't have an excessive number of indexes
- Consider increasing `scrape_interval` if timeouts persist (though this reduces metric granularity)

## Additional Resources

- [Pinecone Monitoring Documentation](https://docs.pinecone.io/guides/production/monitoring#monitor-with-prometheus)
- [Pinecone API Documentation](https://docs.pinecone.io/reference/api)
- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Pinecone Mixin Documentation](https://github.com/grafana/pinecone-mixin)

## Platform Support

This runbook is platform-agnostic. Grafana Alloy can be installed on:
- Linux (systemd service)
- Docker (container)
- Kubernetes (Helm chart or operator)

Refer to the [Alloy installation documentation](https://grafana.com/docs/alloy/latest/get-started/install/) for your platform.
