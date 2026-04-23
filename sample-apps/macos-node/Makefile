LOKI_INSTANCE := your-loki-instance:3100
PROMETHEUS_INSTANCE := your-prometheus-instance:9009

.PHONY: run run-ci stop clean defaultconfig install-alloy configure-alloy start-alloy generate-load

run: defaultconfig install-alloy configure-alloy start-alloy generate-load
	@echo "macOS sample app is running. Alloy should be collecting metrics and logs."

run-ci: defaultconfig install-alloy configure-alloy start-alloy generate-load
	@echo "Running in CI mode"

stop:
	@bash scripts/stop_alloy.sh

clean:
	@rm -f config/alloy-config.alloy
	@rm -rf temp

defaultconfig:
	@mkdir -p config
	@bash scripts/create_default_config.sh \
		--loki-url "http://$(LOKI_INSTANCE)/loki/api/v1/push" \
		--prometheus-url "http://$(PROMETHEUS_INSTANCE)/api/v1/push"

install-alloy:
	@bash scripts/install_alloy.sh

configure-alloy:
	@bash scripts/configure_alloy.sh

start-alloy:
	@bash scripts/start_alloy.sh

generate-load:
	@bash scripts/generate_load.sh
