VM_NAME := apache-tomcat-sample-app
CONFIG_FILE_DIR := jinja/variables
CONFIG_FILE := $(CONFIG_FILE_DIR)/cloud-init.yaml
LOKI_INSTANCE := your-loki-instance:3100
PROMETHEUS_INSTANCE := your-prometheus-instance:9009

.PHONY: run run-ci stop render-config launch-vm clean defaultconfig tomcat-status

run: launch-vm
	@echo "VM $(VM_NAME) launched and configured."

run-ci: clean defaultconfig launch-vm
	@echo "Running in CI mode"

stop:
	@multipass stop $(VM_NAME) --force
	@multipass delete $(VM_NAME)
	@multipass purge

render-config:
	@docker run --rm -v $(shell pwd)/jinja/templates:/templates -v $(shell pwd)/jinja/variables:/variables dinutac/jinja2docker:latest /templates/cloud-init-template.yaml /variables/cloud-init.yaml --format=yaml > cloud-init.yaml

launch-vm: render-config
	@multipass launch -n $(VM_NAME) --cloud-init cloud-init.yaml

clean:
	@rm -f cloud-init.yaml
	@rm -rf $(CONFIG_FILE_DIR)

shell:
	@multipass shell $(VM_NAME)

tomcat-status:
	@multipass exec $(VM_NAME) -- bash -c "TOMCAT_SERVICE=\$$(systemctl list-units --type=service | grep -E 'tomcat(9|10)\.service' | awk '{print \$$1}'); if [ -n \"\$$TOMCAT_SERVICE\" ]; then systemctl status \$$TOMCAT_SERVICE; else echo 'No Tomcat service found'; fi"

defaultconfig:
	@mkdir -p $(CONFIG_FILE_DIR)
	@echo "# Default variables for cloud-init configuration" > jinja/variables/cloud-init.yaml
	@echo "loki_url: http://$(LOKI_INSTANCE)/loki/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "loki_user: your_loki_username" >> jinja/variables/cloud-init.yaml
	@echo "loki_pass: your_loki_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_url: http://$(PROMETHEUS_INSTANCE)/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "prom_user: your_prometheus_username" >> jinja/variables/cloud-init.yaml
	@echo "prom_pass: your_prometheus_password" >> jinja/variables/cloud-init.yaml