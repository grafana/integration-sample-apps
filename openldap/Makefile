VM_NAME := ldap-server

.PHONY: run stop exporter fetch-prometheus-metrics render-config launch-vm clean defaultconfig

run: launch-vm load-test
	@echo "VM $(VM_NAME) launched and configured."

stop:
	@multipass stop $(VM_NAME)
	@multipass delete $(VM_NAME)
	@multipass purge

load-test:
	multipass transfer scripts/load_generation.sh $(VM_NAME):/home/ubuntu/load_generation.sh; \
    multipass exec $(VM_NAME) -- bash -c "chmod +x /home/ubuntu/load_generation.sh && nohup /home/ubuntu/load_generation.sh > load_gen.log 2>&1 &"

fetch-prometheus-metrics:
	@multipass exec $(VM_NAME) -- curl http://localhost:8080/metrics > prometheus_metrics

render-config:
	@docker run --rm -it -v $(shell pwd)/jinja/templates:/templates -v $(shell pwd)/jinja/variables:/variables dinutac/jinja2docker:latest /templates/cloud-init-template.yaml /variables/cloud-init.yaml --format=yaml > cloud-init.yaml

launch-vm: render-config
	@multipass launch -n $(VM_NAME) --cloud-init cloud-init.yaml

clean:
	@rm -f cloud-init.yaml

defaultconfig:
	@echo "exporter_repo: https://github.com/tomcz/openldap_exporter.git" > jinja/variables/cloud-init.yaml
	@echo "exporter_dir: openldap_exporter" >> jinja/variables/cloud-init.yaml
	@echo "prom_addr: \":8080\"" >> jinja/variables/cloud-init.yaml
	@echo "ldap_addr: \"localhost:389\"" >> jinja/variables/cloud-init.yaml
	@echo "ldap_user: \"cn=monitor,dc=nodomain\"" >> jinja/variables/cloud-init.yaml
	@echo "ldap_pass: \"pass\"" >> jinja/variables/cloud-init.yaml
	@echo "interval: \"10s\"" >> jinja/variables/cloud-init.yaml
	@echo "loki_url: http://your-loki-instance:3100/loki/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "loki_user: your_loki_username" >> jinja/variables/cloud-init.yaml
	@echo "loki_pass: your_loki_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_url: http://your-prometheus-instance:9090/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "prom_user: your_prometheus_username" >> jinja/variables/cloud-init.yaml
	@echo "prom_pass: your_prometheus_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_port: 8080" >> jinja/variables/cloud-init.yaml

