VM_NAME := snmp-sample-app
CONFIG_FILE_DIR := jinja/variables
CONFIG_FILE := $(CONFIG_FILE_DIR)/cloud-init.yaml
LOKI_INSTANCE := your-loki-instance:3100
PROMETHEUS_INSTANCE := your-prometheus-instance:9090

.PHONY: run run-ci stop exporter fetch-prometheus-metrics render-config launch-vm clean defaultconfig snmpsim

run: launch-vm snmpsim
	@echo "VM $(VM_NAME) launched and configured."

run-ci: clean defaultconfig launch-vm snmpsim
	@echo "Running in CI mode"

stop:
	@multipass stop $(VM_NAME)
	@multipass delete --purge $(VM_NAME)

fetch-prometheus-metrics:
	@multipass exec $(VM_NAME) -- curl http://localhost:9127/metrics > prometheus_metrics

render-config:
	@docker run --rm -v $(shell pwd)/jinja/templates:/templates -v $(shell pwd)/jinja/variables:/variables dinutac/jinja2docker:latest /templates/cloud-init-template.yaml /variables/cloud-init.yaml --format=yaml > cloud-init.yaml

snmpsim:
	@multipass transfer ./snmpsim $(VM_NAME):/home/ubuntu -r
	@multipass transfer ./snmpsim/targets.yml $(VM_NAME):/tmp/targets.yml
	@multipass transfer ./snmpsim/auths.yml $(VM_NAME):/tmp/auths.yml
	@multipass exec $(VM_NAME) -- bash -c "cd ./snmpsim && docker-compose -f docker-compose.snmpsim.yml up -d"

launch-vm: render-config
	@multipass launch docker -n $(VM_NAME) --cloud-init cloud-init.yaml

clean:
	@rm -f cloud-init.yaml
	@rm -rf $(CONFIG_FILE_DIR)

defaultconfig:
	@mkdir $(CONFIG_FILE_DIR)
	@echo "interval: \"10s\"" >> jinja/variables/cloud-init.yaml
	@echo "loki_url: http://$(LOKI_INSTANCE)/loki/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "loki_user: your_loki_username" >> jinja/variables/cloud-init.yaml
	@echo "loki_pass: your_loki_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_url: http://$(PROMETHEUS_INSTANCE)/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "prom_user: your_prometheus_username" >> jinja/variables/cloud-init.yaml
	@echo "prom_pass: your_prometheus_password" >> jinja/variables/cloud-init.yaml
