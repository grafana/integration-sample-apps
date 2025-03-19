VM_NAME := catchpoint
K8S_NAMESPACE := default
CONFIG_FILE := jinja/variables/cloud-init.yaml
TEMPLATE_DIR := jinja/templates
OUTPUT_DIR := generated_configs
GRAFANA_FLOW_VALUES := $(OUTPUT_DIR)/grafana-flow-k8s-template.yaml

.PHONY: run-catchpoint-multipass
run-catchpoint-multipass: render-config
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

.PHONY: port-forward
port-forward:
	@echo "Setting kubectl context to minikube"
	@multipass exec $(VM_NAME) -- bash -c "kubectl config use-context minikube"
	@echo "Starting port-forwarding for Prometheus exporter"
	@multipass exec $(VM_NAME) -- bash -c "tmux new-session -d -s port-forward 'kubectl port-forward svc/catchpoint-exporter 9090:9090'"
	@sleep 5 # Wait a few seconds to ensure port-forwarding is established
	@echo "Port-forwarding enabled for Prometheus exporter."

.PHONY: run-metrics
run-metrics:
	@echo "Running post_metrics.py script"
	@multipass exec $(VM_NAME) -- python3 /catchpoint/scripts/post_metrics.py
	@echo "Metrics script executed."

.PHONY: render-config
render-config:
	python3 scripts/render_template.py --config_file $(CONFIG_FILE) --template_dir $(TEMPLATE_DIR) --output_dir $(OUTPUT_DIR)
	@echo "Config templates rendered."

.PHONY: clean
clean: stop-catchpoint-multipass
	@echo "Cleaning generated configs..."
	@rm -f cloud-init.yaml
	@rm -rf $(OUTPUT_DIR)/*
	@echo "Generated configs cleaned."

.PHONY: defaultconfig
defaultconfig:
	@echo "loki_user: your_loki_username" >> jinja/variables/cloud-init.yaml
	@echo "loki_pass: your_loki_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_host: https://prometheus-us-central1.grafana.net" >> jinja/variables/cloud-init.yaml
	@echo "prom_user: your_prometheus_username" >> jinja/variables/cloud-init.yaml
	@echo "prom_pass: your_prometheus_password" >> jinja/variables/cloud-init.yaml

.PHONY: fetch-prometheus-metrics
fetch-prometheus-metrics:
	@multipass exec $(VM_NAME) -- curl http://localhost:9090/metrics > prometheus_metrics

.PHONY: all
all: run-catchpoint-multipass port-forward run-metrics
	@echo "All tasks completed."
