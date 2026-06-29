VM_NAME ?= mongodb-sample-app
CONFIG_FILE_DIR := jinja/variables
CONFIG_FILE := $(CONFIG_FILE_DIR)/cloud-init.yaml
LOKI_INSTANCE ?= your-loki-instance:3100
PROMETHEUS_INSTANCE ?= your-prometheus-instance:9090
# Cloud-init template and VM size; overridden by run-cluster for the sharded topology
TEMPLATE ?= cloud-init-template.yaml
MEMORY ?= 2G

# Import last to ensure expected parameters are set and available to import from this file
include ../Makefile

.PHONY: run run-cluster run-ci stop exporter fetch-prometheus-metrics render-config launch-vm clean defaultconfig

run: launch-vm
	@echo "VM $(VM_NAME) launched and configured."

# Launch the sharded cluster (config server + two shards + mongos) instead of the single replicaset
run-cluster: TEMPLATE = cloud-init-template_local_setup.yaml
run-cluster: MEMORY = 4G
run-cluster: launch-vm
	@echo "VM $(VM_NAME) launched with sharded cluster."

run-ci: clean defaultconfig launch-vm
	@echo "Running in CI mode"

stop:
	@multipass stop $(VM_NAME)
	@multipass delete $(VM_NAME)
	@multipass purge

fetch-prometheus-metrics:
	@multipass exec $(VM_NAME) -- curl http://localhost:9127/metrics > prometheus_metrics

render-config:
	@docker run --rm -v $(shell pwd)/jinja/templates:/templates -v $(shell pwd)/jinja/variables:/variables dinutac/jinja2docker:latest /templates/$(TEMPLATE) /variables/cloud-init.yaml --format=yaml > cloud-init.yaml

launch-vm: render-config
	@multipass launch 24.04 -n $(VM_NAME) --cpus 4 --memory $(MEMORY) --disk 15G --cloud-init cloud-init.yaml

clean:
	@rm -f cloud-init.yaml
	@rm -rf $(CONFIG_FILE_DIR)

defaultconfig:
	@mkdir -p $(CONFIG_FILE_DIR)
	@echo "interval: \"10s\"" >> jinja/variables/cloud-init.yaml
	@echo "loki_url: http://$(LOKI_INSTANCE)/loki/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "loki_user: your_loki_username" >> jinja/variables/cloud-init.yaml
	@echo "loki_pass: your_loki_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_url: http://$(PROMETHEUS_INSTANCE)/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "prom_user: your_prometheus_username" >> jinja/variables/cloud-init.yaml
	@echo "prom_pass: your_prometheus_password" >> jinja/variables/cloud-init.yaml
