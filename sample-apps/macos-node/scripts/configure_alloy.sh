#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is not installed or not on PATH." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAMPLE_APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_CONFIG="${SAMPLE_APP_DIR}/config/alloy-config.alloy"

if [[ ! -f "${SOURCE_CONFIG}" ]]; then
  echo "Error: Alloy config not found at ${SOURCE_CONFIG}" >&2
  echo "Run 'make defaultconfig' first." >&2
  exit 1
fi

BREW_PREFIX="$(brew --prefix)"
TARGET_DIR="${BREW_PREFIX}/etc/alloy"
TARGET_CONFIG="${TARGET_DIR}/config.alloy"

mkdir -p "${TARGET_DIR}"
cp "${SOURCE_CONFIG}" "${TARGET_CONFIG}"

echo "Configuration copied to: ${TARGET_CONFIG}"

# Restart the service if it's already running to reload config
if brew services list | awk '$1 == "alloy" { print $2 }' | grep -q "started"; then
  echo "Alloy service is running. Restarting to pick up config change."
  brew services stop alloy
fi

echo "Alloy configuration completed."
