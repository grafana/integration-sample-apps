## Load Generation

To generate test data and operations for monitoring, you can use the included load generation script. This script performs continuous operations (upsert, query, fetch, delete) on a test index to generate metrics.

### Prerequisites

- Go 1.21 or later installed
- Pinecone API key set in environment: `export PINECONE_API_KEY="your-api-key"`

### Running the Load Generator

1. Navigate to the scripts directory:
   ```bash
   cd scripts
   ```

2. Install dependencies:
   ```bash
   go mod download
   ```

3. Run the load generator:
   ```bash
   go run loadgen.go
   ```

The script will:
- Create or use an existing index named `loadgen-test-index`
- Perform operations for a configurable duration (default: 10 minutes):
  - **Upsert**: Adds 10 vectors per batch
  - **Query**: Performs semantic search queries
  - **Fetch**: Retrieves vectors by ID
  - **Delete**: Removes old vectors to generate delete metrics

All operations are logged with timestamps. The script runs for the specified duration and then exits automatically.

### Configuration

You can configure the run duration using the `PINECONE_LOADGEN_DURATION` environment variable:

```bash
# Run for 30 minutes
export PINECONE_LOADGEN_DURATION="30m"
go run loadgen.go
```
**Note**: The script creates a serverless index in AWS us-east-1. You can modify the index configuration in `scripts/loadgen.go` if needed.