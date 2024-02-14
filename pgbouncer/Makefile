VM_NAME := pgbouncer-sample-app

.PHONY: run stop exporter fetch-prometheus-metrics render-config launch-vm clean defaultconfig

run: launch-vm
	@echo "VM $(VM_NAME) launched and configured."

stop:
	@multipass stop $(VM_NAME)
	@multipass delete $(VM_NAME)
	@multipass purge

fetch-prometheus-metrics:
	@multipass exec $(VM_NAME) -- curl http://localhost:9127/metrics > prometheus_metrics

load-gen:
	@multipass exec $(VM_NAME) -- sudo bash -c "su postgres -c 'pgbench -i; pgbench; exit;'"

render-config:
	@docker run --rm -it -v $(shell pwd)/jinja/templates:/templates -v $(shell pwd)/jinja/variables:/variables dinutac/jinja2docker:latest /templates/cloud-init-template.yaml /variables/cloud-init.yaml --format=yaml > cloud-init.yaml

launch-vm: render-config
	@multipass launch -n $(VM_NAME) --cloud-init cloud-init.yaml

clean:
	@rm -f cloud-init.yaml

defaultconfig:
	@echo "interval: \"10s\"" >> jinja/variables/cloud-init.yaml
	@echo "loki_url: http://your-loki-instance:3100/loki/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "loki_user: your_loki_username" >> jinja/variables/cloud-init.yaml
	@echo "loki_pass: your_loki_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_url: http://your-prometheus-instance:9090/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "prom_user: your_prometheus_username" >> jinja/variables/cloud-init.yaml
	@echo "prom_pass: your_prometheus_password" >> jinja/variables/cloud-init.yaml
