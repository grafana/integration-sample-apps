VM_NAME ?= linux-hostmetrics-sample-app
CONFIG_FILE_DIR := jinja/variables
CONFIG_FILE := $(CONFIG_FILE_DIR)/cloud-init.yaml
PROMETHEUS_INSTANCE ?= your-prometheus-instance:9090
OTEL_COL_VERSION ?= 0.161.0

COLLECTORS ?= alloy otelcol
NODES ?= 1
VM_CPUS ?= 2
VM_MEMORY ?= 2G
VM_DISK ?= 8G

TEMPLATES := $(wildcard jinja/templates/*.yaml jinja/templates/*/*.yaml)
CLOUD_INITS := $(foreach c,$(COLLECTORS),cloud-init-$(c).yaml)

# Import last to ensure expected parameters are set and available to import from this file
include ../Makefile

.PHONY: run run-ci stop render-config launch-vm clean defaultconfig
.DELETE_ON_ERROR:

run: launch-vm
	@echo "Launched $(NODES) node(s) per collector: $(COLLECTORS)"

run-ci: clean defaultconfig launch-vm
	@echo "Running in CI mode"

stop:
	@multipass list --format csv | awk -F, '/^$(VM_NAME)/ {print $$1}' | xargs -r multipass delete --purge

render-config: $(CLOUD_INITS)

# Static pattern rule; a bare cloud-init-%.yaml also matches the template itself
$(CLOUD_INITS): cloud-init-%.yaml: jinja/templates/%.yaml $(TEMPLATES) $(CONFIG_FILE)
	@docker run --rm -v $(shell pwd)/jinja/templates:/templates -v $(shell pwd)/$(CONFIG_FILE_DIR):/variables \
		dinutac/jinja2docker:latest /templates/$*.yaml /variables/cloud-init.yaml --format=yaml > $@
	@echo "rendered $@"

# Launched in parallel; each launch blocks until its cloud-init finishes
launch-vm: render-config
	@pids=""; \
	for c in $(COLLECTORS); do \
		for i in $$(seq 1 $(NODES)); do \
			if [ $(NODES) -gt 1 ]; then name=$(VM_NAME)-$$c-$$i; else name=$(VM_NAME)-$$c; fi; \
			multipass launch 24.04 -n $$name --cpus $(VM_CPUS) --memory $(VM_MEMORY) \
				--disk $(VM_DISK) --cloud-init cloud-init-$$c.yaml & \
			pids="$$pids $$!"; \
		done; \
	done; \
	status=0; \
	for p in $$pids; do wait $$p || status=1; done; \
	exit $$status

clean:
	@rm -f cloud-init-*.yaml
	@rm -rf $(CONFIG_FILE_DIR)

defaultconfig:
	@mkdir -p $(CONFIG_FILE_DIR)
	@echo "interval: \"10s\"" >> $(CONFIG_FILE)
	@echo "otlp_url: http://$(PROMETHEUS_INSTANCE)/otlp" >> $(CONFIG_FILE)
	@echo "otel_col_version: \"$(OTEL_COL_VERSION)\"" >> $(CONFIG_FILE)
	@echo "otlp_user: \"\"" >> $(CONFIG_FILE)
	@echo "otlp_pass: \"\"" >> $(CONFIG_FILE)
