#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is not installed or not on PATH." >&2
  exit 1
fi

echo "Starting Alloy service..."
brew services start grafana/grafana/alloy

SERVICE_MAX_RETRIES=5
SERVICE_RETRY_DELAY=10

for attempt in $(seq 1 "${SERVICE_MAX_RETRIES}"); do
  STATUS="$(brew services list | awk '$1 == "grafana/grafana/alloy" { print $2 }' || true)"
  echo "Checking service status... attempt ${attempt}/${SERVICE_MAX_RETRIES} (status: ${STATUS:-unknown})"
  if [[ "${STATUS}" == "started" ]]; then
    echo "Alloy service is running."
    break
  fi
  if [[ "${attempt}" -eq "${SERVICE_MAX_RETRIES}" ]]; then
    echo "Error: Alloy service did not reach 'started' state (last status: ${STATUS:-unknown})." >&2
    exit 1
  fi
  sleep "${SERVICE_RETRY_DELAY}"
done

ENDPOINT_MAX_RETRIES=6
ENDPOINT_RETRY_DELAY=10
METRICS_URL="http://localhost:12345/metrics"

echo "Verifying Alloy metrics endpoint at ${METRICS_URL}..."
for attempt in $(seq 1 "${ENDPOINT_MAX_RETRIES}"); do
  if curl -fsS -o /dev/null --max-time 10 "${METRICS_URL}"; then
    echo "Alloy metrics endpoint is accessible."
    break
  fi
  echo "Metrics endpoint not yet available. Attempt ${attempt}/${ENDPOINT_MAX_RETRIES}"
  if [[ "${attempt}" -eq "${ENDPOINT_MAX_RETRIES}" ]]; then
    echo "Warning: metrics endpoint not accessible at ${METRICS_URL}, but the service is running."
    echo "This may indicate a configuration issue."
  else
    sleep "${ENDPOINT_RETRY_DELAY}"
  fi
done

echo "Alloy service startup completed."
