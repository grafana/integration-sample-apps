.PHONY: run
run: run-multipass

.PHONY: run-multipass
run-multipass:
	@multipass launch -n istio-sample-app --memory 14G --disk 10G --cpus 4;
		multipass exec istio-sample-app -- sudo mkdir /etc/systemd/resolved.conf.d/;
		multipass exec istio-sample-app -- sudo touch /etc/systemd/resolved.conf.d/dns_servers.conf;
		multipass exec istio-sample-app --working-directory /etc/systemd/resolved.conf.d -- sh -c 'echo "[Resolve]\nDNS=8.8.8.8 1.1.1.1\n" | sudo tee -a dns_servers.conf';
		multipass exec istio-sample-app -- sudo systemctl restart systemd-resolved;
		multipass mount ./bookinfo/ istio-sample-app:/istio/bookinfo;
		multipass mount ./scripts/ istio-sample-app:/istio/scripts
		multipass exec istio-sample-app -- bash /istio/scripts/setup-docker.sh;
		multipass stop istio-sample-app;
		multipass start istio-sample-app;
		multipass exec istio-sample-app -- bash /istio/scripts/setup-final.sh;
		multipass exec istio-sample-app -- bash /istio/scripts/loadgen.sh;

.PHONY: stop
stop: stop-multipass

.PHONY: stop-multipass
stop-multipass:
	@multipass delete istio-sample-app
