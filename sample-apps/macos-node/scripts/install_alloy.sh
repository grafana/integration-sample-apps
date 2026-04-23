#!/usr/bin/env bash
set -euo pipefail

echo "Installing Grafana Alloy via Homebrew..."

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is not installed or not on PATH." >&2
  exit 1
fi

if brew list --formula alloy >/dev/null 2>&1; then
  echo "Alloy already installed; upgrading to the latest version..."
  brew upgrade alloy || true
else
  brew tap grafana/grafana
  brew install alloy
fi

alloy --version || {
  echo "Error: 'alloy' binary not available after install." >&2
  exit 1
}

echo "Alloy installation completed."
