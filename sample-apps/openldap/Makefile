VM_NAME := ldap-server
K8S_NAMESPACE := default
CONFIG_FILE_DIR := jinja/variables
CONFIG_FILE := $(CONFIG_FILE_DIR)/cloud-init.yaml
TEMPLATE_DIR := jinja/templates
OUTPUT_DIR := generated_configs
GRAFANA_FLOW_VALUES := $(OUTPUT_DIR)/grafana-flow-k8s-template.yaml
GRAFANA_MULTIPASS_VALUES := $(OUTPUT_DIR)/grafana-cloud-init-template.yaml
OPENLDAP_VALUES := cloud/my-openldap-values.yaml
OPENLDAP_EXPORTER_DEPLOYMENT := cloud/openldap_exporter_deployment.yaml
OPENLDAP_SERVICE := cloud/openldap_service.yaml
OPENLDAP_EXPORTER_SERVICE := cloud/openldap_exporter_service.yaml
GRAFANA_AGENT_DEPLOYMENT := cloud/grafana-agent-deployment.yaml
LOKI_INSTANCE := your-loki-instance:3100
PROMETHEUS_INSTANCE := your-prometheus-instance:9090

.PHONY: run run-ci stop exporter fetch-prometheus-metrics render-config launch-vm clean defaultconfig run-k8s stop-k8s render-k8s install-grafana-agent install-grafana-flow install-openldap deploy-openldap-exporter deploy-grafana-agent clean-generated

run: launch-vm load-test
	@echo "VM $(VM_NAME) launched and configured."

run-ci: clean defaultconfig launch-vm load-test
	echo "Setting up sample-app"

stop:
	@multipass stop $(VM_NAME)
	@multipass delete $(VM_NAME)
	@multipass purge

load-test:
	multipass transfer ./scripts/load_generation.sh $(VM_NAME):/home/ubuntu/load_generation.sh; \
    multipass exec $(VM_NAME) -- bash -c "chmod +x load_generation.sh && nohup load_generation.sh > load_gen.log 2>&1 &"

fetch-prometheus-metrics:
	@multipass exec $(VM_NAME) -- curl http://localhost:8080/metrics > prometheus_metrics

render-config2:
	@docker run --rm -it -v $(shell pwd)/jinja/templates:/templates -v $(shell pwd)/jinja/variables:/variables dinutac/jinja2docker:latest /templates/cloud-init-template.yaml /variables/cloud-init.yaml --format=yaml > cloud-init.yaml

launch-vm: render-config
	@multipass launch -n $(VM_NAME) --cloud-init generated_configs/cloud-init-template.yaml

clean:
	@echo "Cleaning generated configs..."
	@mkdir $(OUTPUT_DIR)
	@rm -f cloud-init.yaml
	@rm -rf $(OUTPUT_DIR)/*
	@echo "Generated configs cleaned."

defaultconfig:
	@mkdir $(CONFIG_FILE_DIR)
	@echo "exporter_repo: https://github.com/grafana/openldap_exporter.git" >> jinja/variables/cloud-init.yaml
	@echo "exporter_dir: openldap_exporter" >> jinja/variables/cloud-init.yaml
	@echo "prom_addr: \":8080\"" >> jinja/variables/cloud-init.yaml
	@echo "ldap_addr: \"localhost:389\"" >> jinja/variables/cloud-init.yaml
	@echo "ldap_user: \"cn=monitor,dc=nodomain\"" >> jinja/variables/cloud-init.yaml
	@echo "ldap_pass: \"pass\"" >> jinja/variables/cloud-init.yaml
	@echo "interval: \"10s\"" >> jinja/variables/cloud-init.yaml
	@echo "loki_url: http://$(LOKI_INSTANCE)/loki/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "loki_user: your_loki_username" >> jinja/variables/cloud-init.yaml
	@echo "loki_pass: your_loki_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_url: http://$(PROMETHEUS_INSTANCE)/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "prom_user: your_prometheus_username" >> jinja/variables/cloud-init.yaml
	@echo "prom_pass: your_prometheus_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_port: 8080" >> jinja/variables/cloud-init.yaml

install-grafana-flow:
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update
	helm install grafana-agent-flow grafana/k8s-monitoring -n $(K8S_NAMESPACE) --values $(GRAFANA_FLOW_VALUES)

clean-grafana-flow:
	helm uninstall grafana-agent-flow -n $(K8S_NAMESPACE)

install-openldap:
	helm repo add helm-openldap https://jp-gouin.github.io/helm-openldap/
	helm repo update
	helm install my-openldap jp-gouin/openldap -n $(K8S_NAMESPACE) -f $(OPENLDAP_VALUES)

deploy-openldap-exporter:
	kubectl apply -f $(OPENLDAP_EXPORTER_DEPLOYMENT)
	kubectl apply -f $(OPENLDAP_EXPORTER_SERVICE)
	kubectl apply -f $(OPENLDAP_SERVICE)

run-k8s: render-k8s install-openldap install-grafana-flow deploy-openldap-exporter
	@echo "Kubernetes deployments complete."

stop-k8s:
	kubectl delete -f $(OPENLDAP_EXPORTER_DEPLOYMENT)
	helm uninstall my-openldap -n $(K8S_NAMESPACE)
	helm uninstall grafana-agent-flow -n $(K8S_NAMESPACE)

render-config:
	@echo "Rendering Configs templates..."
	python3 scripts/render_template.py --config_file $(CONFIG_FILE) --template_dir $(TEMPLATE_DIR) --output_dir $(OUTPUT_DIR)
	@echo "Config templates rendered."

clean-generated:
	@echo "Cleaning generated configs..."
	@rm -rf $(OUTPUT_DIR)/*
	@echo "Generated configs cleaned."
