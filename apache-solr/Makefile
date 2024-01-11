VM_PREFIX=apache-solr-zookeeper-instance

.PHONY: run create-vms setup-zookeeper setup-solr load-test fetch-prometheus-metrics setup-grafana-agent clean

run:
    # Create VMs
	for i in 1 2 3; do \
        multipass launch --name $(VM_PREFIX)-$$i --cpus 4 --memory 4G --disk 10G; \
    done
    # Run the script to collect IP addresses
	./scripts/collect_ips.sh
    # Read IP addresses from the file and print them
	cat vms_ips.txt
    # Execute ZooKeeper setup script on VMs with IP addresses
	for i in 1 2 3; do \
        multipass transfer scripts/setup_zookeeper.sh $(VM_PREFIX)-$$i:/home/ubuntu/setup_zookeeper.sh; \
        multipass transfer vms_ips.txt $(VM_PREFIX)-$$i:/home/ubuntu/vms_ips.txt; \
        multipass exec $(VM_PREFIX)-$$i -- bash -c "chmod +x /home/ubuntu/setup_zookeeper.sh && /home/ubuntu/setup_zookeeper.sh $$i /home/ubuntu/vms_ips.txt"; \
    done
    # Execute Solr setup script on VMs with IP addresses
	for i in 1 2 3; do \
        multipass transfer scripts/setup_solr.sh $(VM_PREFIX)-$$i:/home/ubuntu/setup_solr.sh; \
        multipass transfer vms_ips.txt $(VM_PREFIX)-$$i:/home/ubuntu/vms_ips.txt; \
        multipass exec $(VM_PREFIX)-$$i -- bash -c "chmod +x /home/ubuntu/setup_solr.sh && /home/ubuntu/setup_solr.sh $$i /home/ubuntu/vms_ips.txt"; \
    done
    # Clean up
	rm vms_ips.txt

load-test:
	multipass transfer scripts/load_generation.sh $(VM_PREFIX)-1:/home/ubuntu/load_generation.sh; \
    multipass exec $(VM_PREFIX)-1 -- bash -c "chmod +x /home/ubuntu/load_generation.sh && nohup /home/ubuntu/load_generation.sh > load_gen.log 2>&1 &"

fetch-prometheus-metrics:
	multipass exec $(VM_PREFIX)-1 -- bash -c "curl http://localhost:9854/metrics" > prometheus_metrics

setup-grafana-agent:
	for i in 1 2 3; do \
        multipass transfer grafana-agent.yaml $(VM_PREFIX)-$$i:/home/ubuntu/grafana-agent.yaml; \
        multipass transfer scripts/install_grafana_agent.sh $(VM_PREFIX)-$$i:/home/ubuntu/install_grafana_agent.sh; \
        multipass exec $(VM_PREFIX)-$$i -- bash -c "chmod +x /home/ubuntu/install_grafana_agent.sh && /home/ubuntu/install_grafana_agent.sh"; \
    done

clean:
    # Delete VMs
	for i in 1 2 3; do \
        multipass delete $(VM_PREFIX)-$$i && multipass purge; \
    done
