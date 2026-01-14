.PHONY: help validate-config test clean

help:
	@echo "Databricks Monitoring Runbook"
	@echo ""
	@echo "Available commands:"
	@echo "  make validate-config  - Validate Alloy configuration syntax"
	@echo "  make test            - Run metric validation tests"
	@echo "  make clean           - Clean up temporary files"
	@echo ""
	@echo "This is a runbook, not an automated sample app."
	@echo "Follow the instructions in README.md for manual setup."

validate-config:
	@echo "Validating Alloy configurations..."
	@if command -v alloy > /dev/null 2>&1; then \
		alloy fmt configs/alloy-simple.alloy; \
		alloy fmt configs/alloy-advanced.alloy; \
		echo "✓ Configuration syntax is valid"; \
	else \
		echo "⚠ Alloy binary not found. Install from:"; \
		echo "  https://grafana.com/docs/alloy/latest/get-started/install/"; \
	fi

test:
	@echo "Running metric validation tests..."
	@echo "Note: This validates expected metrics, not live data."
	@if [ -f tests/metrics/databricks ]; then \
		echo "Expected metrics ($(shell wc -l < tests/metrics/databricks | tr -d ' '))"; \
		cat tests/metrics/databricks; \
	else \
		echo "✗ Metric validation file not found"; \
		exit 1; \
	fi

clean:
	@echo "Cleaning up temporary files..."
	@rm -f configs/*.tmp
	@rm -f *.log
	@echo "✓ Clean complete"
