VM_NAME := velero-sample-app

.PHONY: run stop exporter generate-load fetch-prometheus-metrics render-config launch-vm clean defaultconfig

# Load generation
generate-load:
	NAMESPACES := demo-0 demo-1
# Deploy nginx to namespaces
	@for ns in $(NAMESPACES); do \
		multipass exec $(VM_NAME) -- sudo bash -c "helm install my-nginx bitnami/nginx --version 15.14.0 --create-namespace --namespace $$ns"; \
	done
	# Backup namespaces
	@for ns in $(NAMESPACES); do \
		multipass exec $(VM_NAME) -- sudo bash -c "velero backup create $$ns --include-namespaces $$ns"; \
	done
	# Delete namespaces
	@for ns in $(NAMESPACES); do \
		multipass exec $(VM_NAME) -- sudo bash -c "kubectl delete ns $$ns"; \
	done
	# Restore from backups
	@for ns in $(NAMESPACES); do \
		multipass exec $(VM_NAME) -- sudo bash -c "velero create restore --from-backup $$ns"; \
	done

run: launch-vm
	@echo "VM $(VM_NAME) launched and configured."

stop:
	@multipass delete --purge $(VM_NAME)

fetch-prometheus-metrics:
	@multipass exec $(VM_NAME) -- curl http://localhost:8085/metrics > prometheus_metrics

render-config:
	@docker run --rm -it -v $(shell pwd)/jinja/templates:/templates -v $(shell pwd)/jinja/variables:/variables dinutac/jinja2docker:latest /templates/cloud-init-template.yaml /variables/cloud-init.yaml --format=yaml > cloud-init.yaml

launch-vm: render-config
	@multipass launch --name $(VM_NAME) --memory 14G --disk 10G --cpus 4 --cloud-init cloud-init.yaml; \
		multipass mount ./scripts/ $(VM_NAME):/velero/scripts; \
		multipass exec $(VM_NAME) -- bash /velero/scripts/setup-docker.sh; \
		multipass mount ./jinja/variables/ $(VM_NAME):/velero/variables; \
		multipass stop $(VM_NAME); \
		multipass start $(VM_NAME); \
		multipass exec $(VM_NAME) -- bash /velero/scripts/init-script.sh


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
