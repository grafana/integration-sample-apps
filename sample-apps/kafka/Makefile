include ../Makefile
VM_NAME := kafka-sample-app
VM_CLUSTER_MAIN := $(VM_NAME)-k3s-main
CONFIG_FILE_DIR := jinja/variables
CONFIG_FILE_VARS := $(CONFIG_FILE_DIR)/monitoring-config.yaml
CONFIG_OUT_FILE := monitoring-config.yaml
TEMPLATE_FILE_DIR := jinja/templates
TEMPLATE_FILE := $(TEMPLATE_FILE_DIR)/monitoring-config-template.yaml
ALLOY_FILE := configs/kafka.alloy
LOKI_INSTANCE := your-loki-instance:3100
PROMETHEUS_INSTANCE := your-prometheus-instance:9090

.PHONY: run-ci stop install-kafka default-monitoring-config render-config install-monitoring transfer-configs clean

run-ci: clean k3s-setup-cluster install-kafka default-monitoring-config render-config install-monitoring

stop: k3s-stop-cluster clean

install-kafka: transfer-configs
	@multipass transfer ./scripts/kafka_setup.sh $(VM_CLUSTER_MAIN):/home/ubuntu/kafka_setup.sh;
	@multipass exec $(VM_CLUSTER_MAIN) -- bash -c "chmod +x kafka_setup.sh && ./kafka_setup.sh"

render-config:
	@docker run --rm -v $(shell pwd)/$(TEMPLATE_FILE_DIR):/templates -v $(shell pwd)/$(CONFIG_FILE_DIR):/variables dinutac/jinja2docker:latest /templates/monitoring-config-template.yaml /variables/monitoring-config.yaml --format=yaml > monitoring-config.yaml
	
default-monitoring-config:
	@mkdir $(CONFIG_FILE_DIR)
	@echo "loki_host: http://$(LOKI_INSTANCE)" >> $(CONFIG_FILE_VARS)
	@echo "loki_path: /loki/api/v1/push" >> $(CONFIG_FILE_VARS)
	@echo "loki_user: your_loki_username" >> $(CONFIG_FILE_VARS)
	@echo "loki_pass: your_loki_password" >> $(CONFIG_FILE_VARS)
	@echo "prom_host: http://$(PROMETHEUS_INSTANCE)" >> $(CONFIG_FILE_VARS)
	@echo "prom_path: /api/v1/push" >> $(CONFIG_FILE_VARS)
	@echo "prom_user: your_prometheus_username" >> $(CONFIG_FILE_VARS)
	@echo "prom_pass: your_prometheus_password" >> $(CONFIG_FILE_VARS)
	
transfer-configs: 
	@multipass transfer --recursive configs/ $(VM_CLUSTER_MAIN):/home/ubuntu/

install-monitoring: transfer-configs
	@multipass transfer $(CONFIG_OUT_FILE) $(VM_CLUSTER_MAIN):/home/ubuntu/monitoring.yaml;
	@multipass transfer ./scripts/install_monitoring.sh $(VM_CLUSTER_MAIN):/home/ubuntu/install_monitoring.sh;
	@multipass exec $(VM_CLUSTER_MAIN) -- bash -c "chmod +x install_monitoring.sh && ./install_monitoring.sh"

clean:
	@rm -rf $(CONFIG_FILE_DIR)
