VM_NAME := velero-sample-app

.PHONY: run stop exporter generate-load fetch-prometheus-metrics render-config launch-vm clean defaultconfig

# Load generation
generate-load:
	@multipass exec $(VM_NAME) -- bash /velero/scripts/load-gen.sh &

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
		multipass mount ./jinja/variables/ $(VM_NAME):/home/ubuntu/jinja/variables; \
		multipass stop $(VM_NAME); \
		multipass start $(VM_NAME); \
		multipass exec $(VM_NAME) -- bash /velero/scripts/init-script.sh; \
		multipass exec $(VM_NAME) -- bash /velero/scripts/port-forward.sh &

clean:
	@rm -f cloud-init.yaml

