PRIMARY_VM_NAME   ?= postgres-primary
SECONDARY_VM_NAME ?= postgres-secondary
CONFIG_FILE_DIR   := jinja/variables
CONFIG_FILE       := $(CONFIG_FILE_DIR)/cloud-init.yaml
LOKI_INSTANCE     ?= your-loki-instance:3100
PROMETHEUS_INSTANCE ?= your-prometheus-instance:9090

# Import last to ensure expected parameters are set and available to import from this file
include ../Makefile

.PHONY: run run-primary run-secondary run-ci stop wait-primary \
        render-primary-config render-secondary-config \
        launch-primary launch-secondary \
        setup-traffic load-gen fetch-prometheus-metrics clean defaultconfig

# Launch the full primary + secondary cluster
run: launch-primary wait-primary setup-traffic launch-secondary load-gen
	@echo "Cluster ready: primary=$(PRIMARY_VM_NAME) secondary=$(SECONDARY_VM_NAME)"

run-primary: launch-primary wait-primary
	@echo "Primary $(PRIMARY_VM_NAME) is ready."

run-secondary: launch-secondary
	@echo "Secondary $(SECONDARY_VM_NAME) is ready."

run-ci: clean defaultconfig run
	@echo "Running in CI mode"

# Poll until the primary has finished its cloud-init postgres setup
wait-primary:
	@echo "Waiting for primary postgres initialization..."
	@until multipass exec $(PRIMARY_VM_NAME) -- test -f /tmp/postgres-initialized 2>/dev/null; do \
		printf '.'; sleep 5; \
	done
	@echo " ready."

stop:
	@multipass stop $(PRIMARY_VM_NAME) $(SECONDARY_VM_NAME) 2>/dev/null || true
	@multipass delete $(PRIMARY_VM_NAME) $(SECONDARY_VM_NAME) 2>/dev/null || true
	@multipass purge

fetch-prometheus-metrics:
	@multipass exec $(PRIMARY_VM_NAME) -- curl -s http://localhost:9187/metrics > prometheus_metrics

setup-traffic:
	@multipass transfer traffic/schema.sql $(PRIMARY_VM_NAME):/tmp/schema.sql
	@multipass transfer traffic/load.sh $(PRIMARY_VM_NAME):/tmp/load.sh
	@multipass exec $(PRIMARY_VM_NAME) -- sudo mkdir -p /opt/traffic
	@multipass exec $(PRIMARY_VM_NAME) -- sudo mv /tmp/schema.sql /opt/traffic/schema.sql
	@multipass exec $(PRIMARY_VM_NAME) -- sudo mv /tmp/load.sh /opt/traffic/load.sh
	@multipass exec $(PRIMARY_VM_NAME) -- sudo chmod +x /opt/traffic/load.sh
	@multipass exec $(PRIMARY_VM_NAME) -- sudo -u postgres psql -f /opt/traffic/schema.sql
	@echo "Traffic schema applied on $(PRIMARY_VM_NAME)."

load-gen:
	@multipass exec $(PRIMARY_VM_NAME) -- bash -c \
		"nohup sudo -u postgres bash /opt/traffic/load.sh 86400 10 > /tmp/traffic.log 2>&1 &"
	@echo "Traffic generator started on $(PRIMARY_VM_NAME)."

render-primary-config:
	@docker run --rm \
		-v $(shell pwd)/jinja/templates:/templates \
		-v $(shell pwd)/jinja/variables:/variables \
		dinutac/jinja2docker:latest \
		/templates/cloud-init-primary-template.yaml \
		/variables/cloud-init.yaml \
		--format=yaml > cloud-init-primary.yaml

render-secondary-config:
	@PRIMARY_IP=$$(multipass info $(PRIMARY_VM_NAME) 2>/dev/null | grep IPv4 | awk '{print $$2}') && \
	cp jinja/variables/cloud-init.yaml jinja/variables/cloud-init-secondary.yaml && \
	echo "primary_ip: '$$PRIMARY_IP'" >> jinja/variables/cloud-init-secondary.yaml && \
	docker run --rm \
		-v $(shell pwd)/jinja/templates:/templates \
		-v $(shell pwd)/jinja/variables:/variables \
		dinutac/jinja2docker:latest \
		/templates/cloud-init-secondary-template.yaml \
		/variables/cloud-init-secondary.yaml \
		--format=yaml > cloud-init-secondary.yaml && \
	rm -f jinja/variables/cloud-init-secondary.yaml

launch-primary: render-primary-config
	@multipass launch -n $(PRIMARY_VM_NAME) --cloud-init cloud-init-primary.yaml

launch-secondary: render-secondary-config
	@multipass launch -n $(SECONDARY_VM_NAME) --cloud-init cloud-init-secondary.yaml

clean:
	@rm -f cloud-init.yaml cloud-init-primary.yaml cloud-init-secondary.yaml
	@rm -rf $(CONFIG_FILE_DIR)

defaultconfig:
	@mkdir -p $(CONFIG_FILE_DIR)
	@printf 'interval: "10s"\n'                                                  > jinja/variables/cloud-init.yaml
	@printf 'loki_url: http://$(LOKI_INSTANCE)/loki/api/v1/push\n'             >> jinja/variables/cloud-init.yaml
	@printf 'loki_user: your_loki_username\n'                                  >> jinja/variables/cloud-init.yaml
	@printf 'loki_pass: your_loki_password\n'                                  >> jinja/variables/cloud-init.yaml
	@printf 'prom_url: http://$(PROMETHEUS_INSTANCE)/api/v1/push\n'            >> jinja/variables/cloud-init.yaml
	@printf 'prom_user: your_prometheus_username\n'                            >> jinja/variables/cloud-init.yaml
	@printf 'prom_pass: your_prometheus_password\n'                            >> jinja/variables/cloud-init.yaml
