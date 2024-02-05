VM_PREFIX=apache-solr-zookeeper-instance

.PHONY: run create-vms setup-zookeeper setup-solr load-test fetch-prometheus-metrics setup-grafana-agent clean render-config defaultconfig

run: create-vms setup-zookeeper setup-solr load-test fetch-prometheus-metrics setup-grafana-agent
	@echo "VMs and services configured."

create-vms:
	# Create VMs
	multipass launch --name $(VM_PREFIX)-1 --cpus 4 --memory 4G --disk 10G --cloud-init jinja/variables/cloud-init.yaml
	multipass launch --name $(VM_PREFIX)-2 --cpus 4 --memory 4G --disk 10G --cloud-init jinja/variables/cloud-init.yaml
	multipass launch --name $(VM_PREFIX)-3 --cpus 4 --memory 4G --disk 10G --cloud-init jinja/variables/cloud-init.yaml
	# Run the script to collect IP addresses
	./scripts/collect_ips.sh
	# Read IP addresses from the file and print them
	cat vms_ips.txt

setup-zookeeper:
	# Execute ZooKeeper setup script on VMs with IP addresses
	for i in 1 2 3; do \
        multipass transfer scripts/setup_zookeeper.sh $(VM_PREFIX)-$$i:/home/ubuntu/setup_zookeeper.sh; \
        multipass transfer vms_ips.txt $(VM_PREFIX)-$$i:/home/ubuntu/vms_ips.txt; \
        multipass exec $(VM_PREFIX)-$$i -- bash -c "chmod +x /home/ubuntu/setup_zookeeper.sh && /home/ubuntu/setup_zookeeper.sh $$i /home/ubuntu/vms_ips.txt"; \
    done

setup-solr:
	# Execute Solr setup script on VMs with IP addresses
	for i in 1 2 3; do \
        multipass transfer scripts/setup_solr.sh $(VM_PREFIX)-$$i:/home/ubuntu/setup_solr.sh; \
        multipass transfer vms_ips.txt $(VM_PREFIX)-$$i:/home/ubuntu/vms_ips.txt; \
        multipass exec $(VM_PREFIX)-$$i -- bash -c "chmod +x /home/ubuntu/setup_solr.sh && /home/ubuntu/setup_solr.sh $$i /home/ubuntu/vms_ips.txt"; \
    done

load-test:
	multipass transfer scripts/load_generation.sh $(VM_PREFIX)-1:/home/ubuntu/load_generation.sh; \
    multipass exec $(VM_PREFIX)-1 -- bash -c "chmod +x /home/ubuntu/load_generation.sh && nohup /home/ubuntu/load_generation.sh > load_gen.log 2>&1 &"

fetch-prometheus-metrics:
	multipass exec $(VM_PREFIX)-1 -- bash -c "curl http://localhost:9854/metrics" > prometheus_metrics

setup-grafana-agent:
	for i in 1 2 3; do \
        multipass transfer scripts/install_grafana_agent.sh $(VM_PREFIX)-$$i:/home/ubuntu/install_grafana_agent.sh; \
        multipass exec $(VM_PREFIX)-$$i -- bash -c "chmod +x /home/ubuntu/install_grafana_agent.sh && /home/ubuntu/install_grafana_agent.sh"; \
	done

stop:
	# Delete VMs
	for i in 1 2 3; do \
        multipass delete $(VM_PREFIX)-$$i; \
    done
	multipass purge

render-config:
	@docker run --rm -it -v $(shell pwd)/jinja/templates:/templates -v $(shell pwd)/jinja/variables:/variables dinutac/jinja2docker:latest /templates/cloud-init-template.yaml /variables/cloud-init.yaml --format=yaml > cloud-init.yaml

defaultconfig:
	@echo "prom_pass: your_prometheus_password" > jinja/variables/cloud-init.yaml
	@echo "prom_user: your_prometheus_username" >> jinja/variables/cloud-init.yaml
	@echo "prom_url: http://your-prometheus-instance:9090/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "solr_cluster_name: solr-cluster" >> jinja/variables/cloud-init.yaml
	@echo "solr_host: localhost" >> jinja/variables/cloud-init.yaml
	@echo "solr_port: 9854" >> jinja/variables/cloud-init.yaml
	@echo "solr_log_path: /var/solr/logs/*.log" >> jinja/variables/cloud-init.yaml
	@echo "instance_name: solr-instance" >> jinja/variables/cloud-init.yaml
	@echo "loki_url: http://your-loki-instance:3100/loki/api/v1/push" >> jinja/variables/cloud-init.yaml
	@echo "loki_user: your_loki_username" >> jinja/variables/cloud-init.yaml
	@echo "loki_pass: your_loki_password" >> jinja/variables/cloud-init.yaml

clean:
	@rm -f cloud-init.yaml
