include ../Makefile
VM_NAME := gitlab-sample-app
VM_K3S_NAME := $(VM_NAME)-k3s-main
CONFIG_FILE_DIR := jinja/variables
CONFIG_FILE_VARS := $(CONFIG_FILE_DIR)/monitoring-config.yaml
CONFIG_OUT_FILE := monitoring-config.yaml
TEMPLATE_FILE_DIR := jinja/templates
TEMPLATE_FILE := $(TEMPLATE_FILE_DIR)/monitoring-config-template.yaml
ALLOY_FILE := configs/suo.alloy
LOKI_INSTANCE := 192.168.64.4:3100
PROMETHEUS_INSTANCE := 192.168.64.4:9009

.PHONY: run-ci stop install-suo default-monitoring-config render-config install-monitoring transfer-configs clean get-vm-ip get-nodeport port-forward-metrics access-alloy-ui shell-vm access-gitlab access-gitlab-portforward port-forward-gitlab port-forward-gitlab-direct setup-hosts check-gitlab-services gitlab-info reset-user-password fix-runner-config debug-gitlab wait-for-gitlab check-gitlab-ready wait-for-gitlab-app debug-gitlab-app

run-ci: clean k3s-setup install-suo default-monitoring-config render-config install-monitoring

stop: k3s-stop clean

install-suo: transfer-configs
	@multipass transfer ./scripts/suo_setup.sh $(VM_K3S_NAME):/home/ubuntu/suo_setup.sh;
	@multipass exec $(VM_K3S_NAME) -- bash -c "chmod +x suo_setup.sh && ./suo_setup.sh"

render-config:
	@docker run --rm -v $(shell pwd)/$(TEMPLATE_FILE_DIR):/templates -v $(shell pwd)/$(CONFIG_FILE_DIR):/variables dinutac/jinja2docker:latest /templates/monitoring-config-template.yaml /variables/monitoring-config.yaml --format=yaml > monitoring-config.yaml
	@docker run --rm -v $(shell pwd)/$(TEMPLATE_FILE_DIR):/templates -v $(shell pwd)/$(CONFIG_FILE_DIR):/variables dinutac/jinja2docker:latest /templates/suo.alloy /variables/monitoring-config.yaml > configs/suo.alloy
	
default-monitoring-config:
	@mkdir -p $(CONFIG_FILE_DIR)
	@echo "loki_url: http://$(LOKI_INSTANCE)/loki/api/v1/push" >> $(CONFIG_FILE_VARS)
	@echo "loki_host: http://$(LOKI_INSTANCE)" >> $(CONFIG_FILE_VARS)
	@echo "loki_path: /loki/api/v1/push" >> $(CONFIG_FILE_VARS)
	@echo "loki_user: your_loki_username" >> $(CONFIG_FILE_VARS)
	@echo "loki_pass: your_loki_password" >> $(CONFIG_FILE_VARS)
	@echo "prom_url: http://$(PROMETHEUS_INSTANCE)/api/v1/push" >> $(CONFIG_FILE_VARS)
	@echo "prom_host: http://$(PROMETHEUS_INSTANCE)" >> $(CONFIG_FILE_VARS)
	@echo "prom_path: /api/v1/push" >> $(CONFIG_FILE_VARS)
	@echo "prom_user: your_prometheus_username" >> $(CONFIG_FILE_VARS)
	@echo "prom_pass: your_prometheus_password" >> $(CONFIG_FILE_VARS)
	
transfer-configs: 
	@multipass transfer --recursive configs/ $(VM_K3S_NAME):/home/ubuntu/

install-monitoring: transfer-configs
	@multipass transfer $(CONFIG_OUT_FILE) $(VM_K3S_NAME):/home/ubuntu/monitoring.yaml;
	@multipass transfer ./scripts/install_monitoring.sh $(VM_K3S_NAME):/home/ubuntu/install_monitoring.sh;
	@multipass exec $(VM_K3S_NAME) -- bash -c "chmod +x install_monitoring.sh && ./install_monitoring.sh"

clean:
	@rm -rf $(CONFIG_FILE_DIR)

get-vm-ip:
	@echo "VM IP Address:"
	@multipass info $(VM_K3S_NAME) | grep "IPv4" | awk '{print $$2}'

access-alloy-ui:
	@echo "Port-forwarding Alloy UI to $(shell multipass info $(VM_K3S_NAME) --format json | jq -r '.info."$(VM_K3S_NAME)".ipv4[0]'):12345..."
	@echo "Access Alloy UI at: http://$(shell multipass info $(VM_K3S_NAME) --format json | jq -r '.info."$(VM_K3S_NAME)".ipv4[0]'):12345"
	@echo "Press Ctrl+C to stop port-forwarding"
	@multipass exec $(VM_K3S_NAME) -- kubectl port-forward -n monitoring svc/k8s-monitoring-alloy 12345:12345 --address 0.0.0.0

shell:
	@multipass shell $(VM_K3S_NAME)

get-password:
	@echo "Username: root"
	@echo "Password: $(shell multipass exec $(VM_K3S_NAME) -- kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 --decode)"

setup-hosts:
	@echo "Setting up hosts file for GitLab access..."
	@VM_IP=$$(multipass info $(VM_K3S_NAME) --format json | jq -r '.info."$(VM_K3S_NAME)".ipv4[0]'); \
	NODEPORT=$$(multipass exec $(VM_K3S_NAME) -- kubectl get svc gitlab-nginx-ingress-controller -n gitlab -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}'); \
	echo "Adding $$VM_IP gitlab.local to /etc/hosts"; \
	sudo grep -v "gitlab.local" /etc/hosts > /tmp/hosts.tmp || true; \
	echo "$$VM_IP gitlab.local" | sudo tee -a /tmp/hosts.tmp > /dev/null; \
	sudo mv /tmp/hosts.tmp /etc/hosts; \
	echo "You can now access GitLab at: http://gitlab.local:$$NODEPORT"

gitlab-info: 
	@echo "=== GitLab Access Information ==="
	@VM_IP=$$(multipass info $(VM_K3S_NAME) --format json | jq -r '.info."$(VM_K3S_NAME)".ipv4[0]' 2>/dev/null); \
	NODEPORT=$$(multipass exec $(VM_K3S_NAME) -- kubectl get svc gitlab-nginx-ingress-controller -n gitlab -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null); \
	if [ -n "$$NODEPORT" ]; then \
		echo "✅ NodePort Access:"; \
		echo "   http://$$VM_IP:$$NODEPORT"; \
		echo "   http://gitlab.local:$$NODEPORT (after running 'make setup-hosts')"; \
	else \
		echo "❌ NodePort not available"; \
	fi; \
	echo "👤 Login credentials:"; \
	echo "   Username: root"; \
	echo "   Password: $(shell multipass exec $(VM_K3S_NAME) -- kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 --decode)"; \
	echo ""; \
	echo "🖥️  VM IP: $$VM_IP"
