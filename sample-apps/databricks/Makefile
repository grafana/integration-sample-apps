VM_NAME ?= databricks-sample-app
CONFIG_FILE_DIR := jinja/variables
CONFIG_FILE := $(CONFIG_FILE_DIR)/cloud-init.yaml
LOKI_INSTANCE ?= your-loki-instance:3100
PROMETHEUS_INSTANCE ?= your-prometheus-instance:9090

# Import last to ensure expected parameters are set and available to import from this file
include ../Makefile

.PHONY: run run-ci stop render-config launch-vm clean defaultconfig

run: launch-vm
	@echo "VM $(VM_NAME) launched and configured."
	@echo ""
	@echo "IMPORTANT: You must configure jinja/variables/cloud-init.yaml with your Databricks credentials before launching."
	@echo "See README.md for required configuration values."

run-ci: clean defaultconfig launch-vm
	@echo "Running in CI mode"

stop:
	@multipass stop $(VM_NAME)
	@multipass delete $(VM_NAME)
	@multipass purge

render-config:
	@docker run --rm -v $(shell pwd)/jinja/templates:/templates -v $(shell pwd)/jinja/variables:/variables dinutac/jinja2docker:latest /templates/cloud-init-template.yaml /variables/cloud-init.yaml --format=yaml > cloud-init.yaml

launch-vm: render-config
	@multipass launch -n $(VM_NAME) --disk 10G --cloud-init cloud-init.yaml

clean:
	@rm -f cloud-init.yaml
	@rm -rf $(CONFIG_FILE_DIR)

defaultconfig:
	@mkdir -p $(CONFIG_FILE_DIR)
	@echo "# Databricks Exporter Configuration" > $(CONFIG_FILE)
	@echo "# See README.md for instructions on obtaining these values" >> $(CONFIG_FILE)
	@echo "" >> $(CONFIG_FILE)
	@echo "# Grafana Cloud endpoints" >> $(CONFIG_FILE)
	@echo "loki_url: http://$(LOKI_INSTANCE)/loki/api/v1/push" >> $(CONFIG_FILE)
	@echo "loki_user: your_loki_username" >> $(CONFIG_FILE)
	@echo "loki_pass: your_loki_password" >> $(CONFIG_FILE)
	@echo "prom_url: http://$(PROMETHEUS_INSTANCE)/api/v1/push" >> $(CONFIG_FILE)
	@echo "prom_user: your_prometheus_username" >> $(CONFIG_FILE)
	@echo "prom_pass: your_prometheus_password" >> $(CONFIG_FILE)
	@echo "" >> $(CONFIG_FILE)
	@echo "# Databricks OAuth2 Service Principal credentials" >> $(CONFIG_FILE)
	@echo "databricks_server_hostname: your-workspace.cloud.databricks.com" >> $(CONFIG_FILE)
	@echo "databricks_warehouse_http_path: /sql/1.0/warehouses/your-warehouse-id" >> $(CONFIG_FILE)
	@echo "databricks_client_id: your-service-principal-client-id" >> $(CONFIG_FILE)
	@echo "databricks_client_secret: your-service-principal-client-secret" >> $(CONFIG_FILE)

