.PHONY: run
run: run-kubernetes

kubeconfig.yaml:
	kind create cluster --name cert-manager-test --kubeconfig ./kubeconfig.yaml
	helm install --kubeconfig kubeconfig.yaml prometheus prometheus-community/prometheus -f ../.github/configs/prometheus.yaml -n prometheus --create-namespace --wait
	helm install --kubeconfig kubeconfig.yaml loki grafana/loki -f ../.github/configs/loki.yaml -n loki --create-namespace --wait

.PHONY: run-kubernetes
run-kubernetes: values.yaml kubeconfig.yaml
	@helm repo add jetstack https://charts.jetstack.io
	@helm repo add grafana https://grafana.github.io/helm-charts
	@helm repo update
	helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set installCRDs=true --wait --kubeconfig ./kubeconfig.yaml
	helm install k8s-monitoring grafana/k8s-monitoring -n monitoring --create-namespace --wait --kubeconfig ./kubeconfig.yaml \
		--values values.yaml \
		--set-file extraConfig=cert-manager.river \
		--values test-queries.yaml

.PHONY: test-kubernetes
test-kubernetes:
	helm test k8s-monitoring -n monitoring --kubeconfig ./kubeconfig.yaml --logs

.PHONY: clean
clean:
	@rm -f kubeconfig.yaml values.yaml jinja/variables/servers.yaml

.PHONY: defaultconfig
defaultconfig:
	@echo "loki_host: http://loki.k3d.localhost:9999" > jinja/variables/servers.yaml; \
		echo "loki_user: " >> jinja/variables/servers.yaml; \
		echo "loki_pass: " >> jinja/variables/servers.yaml; \
		echo "loki_path: /loki/api/v1/push" >> jinja/variables/servers.yaml; \
		echo "prom_host: http://mimir.k3d.localhost:9999" >> jinja/variables/servers.yaml; \
		echo "prom_user: " >> jinja/variables/servers.yaml; \
		echo "prom_pass:" >> jinja/variables/servers.yaml
		echo "prom_path: /api/v1/push" >> jinja/variables/servers.yaml; \

.PHONY: localclusterconfig
localclusterconfig:
	@echo "loki_host: http://loki.loki.svc:3100" > jinja/variables/servers.yaml; \
		echo "loki_path: /loki/api/v1/push" >> jinja/variables/servers.yaml; \
		echo "loki_user: loki" >> jinja/variables/servers.yaml; \
		echo "loki_pass: lokipassword" >> jinja/variables/servers.yaml; \
		echo "prom_host: http://prometheus-server.prometheus.svc:80" >> jinja/variables/servers.yaml; \
		echo "prom_path: /api/v1/write" >> jinja/variables/servers.yaml; \
		echo "prom_query_path: /api/v1/query" >> jinja/variables/servers.yaml; \
		echo "prom_user: promuser" >> jinja/variables/servers.yaml; \
		echo "prom_pass: prometheuspassword" >> jinja/variables/servers.yaml

values.yaml: jinja/variables/servers.yaml
	@docker run --rm \
		-v $(shell pwd)/jinja/templates:/templates \
		-v $(shell pwd)/jinja/variables:/variables \
		dinutac/jinja2docker:latest /templates/values-template.yaml /variables/servers.yaml --format=yaml > values.yaml

jinja/variables/servers.yaml:
	@echo "Fetching remote write secrets for Grafana Agent Config."
	@read -p "Enter Loki Server Host (no paths): " loki_host; \
		read -p "Enter Loki write path (/loki/api/v1/push): " loki_path; \
		read -p "Enter Loki Username: " loki_user; \
		read -p "Enter Loki Password: " loki_pass; \
		read -p "Enter Prom Server Host (no paths): " prom_host; \
		read -p "Enter Prom write path (/api/prom/push): " prom_path; \
		read -p "Enter Prom Username: " prom_user; \
		read -p "Enter Prom Password: " prom_pass; \
		echo "loki_host: $$loki_host" > jinja/variables/servers.yaml; \
		echo "loki_path: $$loki_path" >> jinja/variables/servers.yaml; \
		echo "loki_user: $$loki_user" >> jinja/variables/servers.yaml; \
		echo "loki_pass: $$loki_pass" >> jinja/variables/servers.yaml; \
		echo "prom_host: $$prom_host" >> jinja/variables/servers.yaml; \
		echo "prom_path: $$prom_path" >> jinja/variables/servers.yaml; \
		echo "prom_user: $$prom_user" >> jinja/variables/servers.yaml; \
		echo "prom_pass: $$prom_pass" >> jinja/variables/servers.yaml
