.PHONY: run
run: run-multipass

.PHONY: run-multipass
run-multipass: resources/user-inputs.yaml
	@multipass launch -n istio-sample-app --memory 14G --disk 10G --cpus 4; \
		# These commands are to allow external network access
		multipass exec istio-sample-app -- sudo mkdir /etc/systemd/resolved.conf.d/; \
		multipass exec istio-sample-app -- sudo touch /etc/systemd/resolved.conf.d/dns_servers.conf; \
		multipass exec istio-sample-app --working-directory /etc/systemd/resolved.conf.d -- sh -c 'echo "[Resolve]\nDNS=8.8.8.8 1.1.1.1\n" | sudo tee -a dns_servers.conf'; \
		multipass exec istio-sample-app -- sudo systemctl restart systemd-resolved; \
		multipass mount ./bookinfo/ istio-sample-app:/istio/bookinfo; \
		multipass mount ./resources/ istio-sample-app:/istio/resources; \
		multipass mount ./scripts/ istio-sample-app:/istio/scripts; \
		multipass exec istio-sample-app -- bash /istio/scripts/setup-docker.sh; \
		multipass stop istio-sample-app; \
		multipass start istio-sample-app; \
		multipass exec istio-sample-app -- bash /istio/scripts/setup-final.sh; \
		multipass exec istio-sample-app -- bash /istio/scripts/loadgen.sh

.PHONY: stop
stop: stop-multipass

.PHONY: stop-multipass
stop-multipass:
	@multipass delete istio-sample-app; \
		echo "Waiting delete to finish..."; \
    	sleep 5; \
		multipass purge

.PHONY: clean
clean:
	@rm -f resources/user-inputs.yaml

resources/user-inputs.yaml:
	@echo "Fetching remote write secrets for Grafana Agent Config."
	@read -p "Enter Prom Server URL [http://mimir.k3d.localhost:9999/api/v1/push]: " prom_url; \
	    prom_url=$${prom_url:-http://mimir.k3d.localhost:9999/api/v1/push}; \
		read -p "Enter Prom Username: " prom_user; \
		read -p "Enter Prom Password: " prom_pass; \
		read -p "Enter Loki Server URL [http://loki.k3d.localhost:9999/loki/api/v1/push]: " loki_url; \
	    loki_url=$${loki_url:-http://loki.k3d.localhost:9999/loki/api/v1/push}; \
		read -p "Enter Loki Username: " loki_user; \
		read -p "Enter Loki Password: " loki_pass; \
		echo "prom_url: $$prom_url" > resources/user-inputs.yaml; \
		echo "prom_user: $$prom_user" >> resources/user-inputs.yaml; \
		echo "prom_pass: $$prom_pass" >> resources/user-inputs.yaml; \
		echo "loki_url: $$loki_url" >> resources/user-inputs.yaml; \
		echo "loki_user: $$loki_user" >> resources/user-inputs.yaml; \
		echo "loki_pass: $$loki_pass" >> resources/user-inputs.yaml
