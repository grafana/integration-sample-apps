#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is not installed or not on PATH." >&2
  exit 0
fi

STATUS="$(brew services list | awk '$1 == "grafana/grafana/alloy" { print $2 }' || true)"

if [[ -z "${STATUS}" ]]; then
  echo "Alloy service is not registered with Homebrew. Nothing to stop."
  exit 0
fi

if [[ "${STATUS}" == "started" ]]; then
  echo "Stopping Alloy service..."
  brew services stop grafana/grafana/alloy
  echo "Alloy service stopped."
else
  echo "Alloy service is not running (status: ${STATUS}). Nothing to stop."
fi
