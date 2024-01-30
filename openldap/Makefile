.PHONY: fetch_monitoring_stats make stop make run make exporter fetch-prometheus-metrics render-config launch-vm clean defaultconfig 

VM_NAME := ldap-server

make run:
	multipass launch --name $(VM_NAME)
	./setup_ldap.sh $(VM_NAME)
	./setup_ldap_exporter.sh $(VM_NAME)

make stop:
	multipass delete $(VM_NAME)
	multipass purge

fetch_monitoring_stats:
	multipass exec $(VM_NAME) -- sudo ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=Monitor + > output_monitoring

make exporter:
	./setup_ldap_exporter.sh $(VM_NAME)

fetch-prometheus-metrics:
	multipass exec $(VM_NAME) -- bash -c "curl http://localhost:8080/metrics" > prometheus_metrics


.PHONY: render-config
render-config:
	@docker run --rm -it \
		-v $(shell pwd)/jinja/templates:/templates \
		-v $(shell pwd)/jinja/variables:/variables \
		dinutac/jinja2docker:latest /templates/cloud-init-template.yaml /variables/cloud-init.yaml --format=yaml > cloud-init.yaml

.PHONY: launch-vm
launch-vm: render-config
	@multipass launch -n ldap-server --cloud-init cloud-init.yaml

.PHONY: clean
clean:
	@rm -f cloud-init.yaml

.PHONY: defaultconfig
defaultconfig:
	@echo "loki_url: http://your-loki-instance:3100/loki/api/v1/push" > jinja/variables/cloud-init.yaml
	@echo "loki_user: your_loki_username" >> jinja/variables/cloud-init.yaml
	@echo "loki_pass: your_loki_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_url: http://your-prometheus-instance:9090/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "prom_user: your_prometheus_username" >> jinja/variables/cloud-init.yaml
	@echo "prom_pass: your_prometheus_password" >> jinja/variables/cloud-init.yaml
	@echo "prom_port: 8080" >> jinja/variables/cloud-init.yaml
