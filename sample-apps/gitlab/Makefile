VM_NAME := gitlab-sample-app
CONFIG_FILE_DIR := jinja/variables
CONFIG_FILE := $(CONFIG_FILE_DIR)/cloud-init.yaml
LOKI_INSTANCE := your-loki-instance:3100
PROMETHEUS_INSTANCE := your-prometheus-instance:9090
GITLAB_ROOT_PASSWORD := d.^_R740Vp=/

.PHONY: run run-ci stop render-config launch-vm clean defaultconfig shell

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

# > In some cases, GitLab can run with at least 8 GB of memory. For more information, see running GitLab in a memory-constrained environment.
# > reference: https://docs.gitlab.com/install/requirements
# The timeout is set to 10 minutes, as the GitLab installation can take quite a while to complete. Most of the time it completes around 6-8 minutes on an adequately provisioned multipass VM.
launch-vm: render-config
	@multipass launch -n $(VM_NAME) --memory 8G --disk 10G --cloud-init cloud-init.yaml --timeout 600

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
	@echo "gitlab_root_password: $(GITLAB_ROOT_PASSWORD)" >> jinja/variables/cloud-init.yaml

shell:
	@multipass shell $(VM_NAME)

gitlab-version:
	@multipass exec $(VM_NAME) -- sudo gitlab-rake gitlab:env:info

gitlab-creds:
	@echo "Gitlab root username: root"
	@echo "Gitlab root password: $(GITLAB_ROOT_PASSWORD)"

gitlab-ui:
	@echo "http://$(shell multipass info $(VM_NAME) --format json | jq -r '.info."$(VM_NAME)".ipv4[0]'):80"