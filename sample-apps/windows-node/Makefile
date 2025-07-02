LOKI_INSTANCE := your-loki-instance:3100
PROMETHEUS_INSTANCE := your-prometheus-instance:9009

.PHONY: run run-ci stop clean defaultconfig install-alloy configure-alloy start-alloy generate-load

run: defaultconfig install-alloy configure-alloy start-alloy generate-load
	@echo "Windows sample app is running. Alloy should be collecting metrics and logs."

run-ci: defaultconfig install-alloy configure-alloy start-alloy generate-load
	@echo "Running in CI mode"
	@timeout /t 30 /nobreak > nul 2>&1 || true

stop:
	@powershell -ExecutionPolicy Bypass -File "scripts/stop_alloy.ps1"

clean:
	@if exist "config\alloy-config.alloy" del "config\alloy-config.alloy"
	@if exist "temp" rmdir /s /q "temp"

defaultconfig:
	@if not exist "config" mkdir "config"
	@powershell -ExecutionPolicy Bypass -File "scripts/create_default_config.ps1" -LokiUrl "http://$(LOKI_INSTANCE)/loki/api/v1/push" -PrometheusUrl "http://$(PROMETHEUS_INSTANCE)/api/v1/push"

install-alloy:
	@powershell -ExecutionPolicy Bypass -File "scripts/install_alloy.ps1"

configure-alloy:
	@powershell -ExecutionPolicy Bypass -File "scripts/configure_alloy.ps1"

start-alloy:
	@powershell -ExecutionPolicy Bypass -File "scripts/start_alloy.ps1"

generate-load:
	@powershell -ExecutionPolicy Bypass -File "scripts/generate_load.ps1" 