.PHONY: run
run: run-multipass

.PHONY: run-multipass
run-multipass: cloud-init.yaml
	@multipass launch -n linux-sample-app --cloud-init cloud-init.yaml

.PHONY: clean
clean:
	@rm -f cloud-init.yaml jinja/variables/cloud-init.yaml

.PHONY: defaultconfig
defaultconfig:
	@echo "loki_url: http://loki.k3d.localhost:9999/loki/api/v1/push" >> jinja/variables/cloud-init.yaml; \
		echo "loki_user: " >> jinja/variables/cloud-init.yaml; \
		echo "loki_pass: " >> jinja/variables/cloud-init.yaml; \
		echo "prom_url: http://mimir.k3d.localhost:9999/api/v1/push" >> jinja/variables/cloud-init.yaml; \
		echo "prom_user: " >> jinja/variables/cloud-init.yaml; \
		echo "prom_pass:" >> jinja/variables/cloud-init.yaml


cloud-init.yaml: jinja/variables/cloud-init.yaml
	@docker run --rm -it \
		-v $(shell pwd)/jinja/templates:/templates \
		-v $(shell pwd)/jinja/variables:/variables \
		dinutac/jinja2docker:latest /templates/cloud-init-template.yaml /variables/cloud-init.yaml --format=yaml > cloud-init.yaml

jinja/variables/cloud-init.yaml:
	@echo "Fetching remote write secrets for Grafana Agent Config."
	@read -p "Enter Loki Server URL: " loki_url; \
		read -p "Enter Loki Username: " loki_user; \
		read -p "Enter Loki Password: " loki_pass; \
		read -p "Enter Prom Server URL: " prom_url; \
		read -p "Enter Prom Username: " prom_user; \
		read -p "Enter Prom Password: " prom_pass;\
		echo "loki_url: $$loki_url" >> jinja/variables/cloud-init.yaml; \
		echo "loki_user: $$loki_user" >> jinja/variables/cloud-init.yaml; \
		echo "loki_pass: $$loki_pass" >> jinja/variables/cloud-init.yaml; \
		echo "prom_url: $$prom_url" >> jinja/variables/cloud-init.yaml; \
		echo "prom_user: $$prom_user" >> jinja/variables/cloud-init.yaml; \
		echo "prom_pass: $$prom_pass" >> jinja/variables/cloud-init.yaml