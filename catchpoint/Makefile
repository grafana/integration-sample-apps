VM_NAME := catchpoint
K8S_NAMESPACE := default
CONFIG_FILE := jinja/variables/cloud-init.yaml
TEMPLATE_DIR := jinja/templates
OUTPUT_DIR := generated_configs
GRAFANA_FLOW_VALUES := $(OUTPUT_DIR)/grafana-flow-k8s-template.yaml

.PHONY: run-catchpoint-multipass
run-catchpoint-multipass:
	@multipass launch -n $(VM_NAME) --memory 14G --disk 10G --cpus 4
	@multipass mount ./generated_configs/ $(VM_NAME):/catchpoint/config
	@multipass mount ./scripts $(VM_NAME):/catchpoint/scripts
	@multipass exec $(VM_NAME) -- bash /catchpoint/scripts/setup_docker.sh
	@multipass stop $(VM_NAME)
	@multipass start $(VM_NAME)
	@multipass exec $(VM_NAME) -- bash /catchpoint/scripts/init_script.sh

.PHONY: stop-catchpoint-multipass
stop-catchpoint-multipass:
	@multipass stop $(VM_NAME)
	@multipass delete $(VM_NAME)
	@sleep 10
	@multipass purge

render-config:
	python3 scripts/render_template.py --config_file $(CONFIG_FILE) --template_dir $(TEMPLATE_DIR) --output_dir $(OUTPUT_DIR)
	@echo "Config templates rendered."

clean:
	@echo "Cleaning generated configs..."
	@rm -f cloud-init.yaml
	@rm -rf $(OUTPUT_DIR)/*
	@echo "Generated configs cleaned."

defaultconfig:
	@echo "exporter_repo: https://github.com/yourgithub/catchpoint-prometheus-exporter.git" > jinja/variables/cloud-init.yaml
	@echo "exporter_dir: catchpoint-prometheus-exporter" >> jinja/variables/cloud-init.yaml
	@echo "prom_addr: \":8080\"" >> jinja/variables/cloud-init.yaml
	@echo "catchpoint_bearer_token: \"your_token\"" >> jinja/variables/cloud-init.yaml
	@echo "node_ids: \"1,2\"" >> jinja/variables/cloud-init.yaml
	@echo "interval: \"10s\"" >> jinja/variables/cloud-init.yaml
	@echo "loki_url: http://your-loki-instance:3100/loki/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "loki_user: your_loki_username" >> jinja/variables/cloud-init.yaml
	@echo "loki_pass: your_loki_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_url: http://your-prometheus-instance:9090/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "prom_user: your_prometheus_username" >> jinja/variables/cloud-init.yaml
	@echo "prom_pass: your_prometheus_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_port: 8080" >> jinja/variables/cloud-init.yaml

fetch-prometheus-metrics:
	@multipass exec $(VM_NAME) -- curl http://localhost:8080/metrics > prometheus_metrics
