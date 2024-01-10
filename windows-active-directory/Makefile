# Runs an interactive prompt that asks users for information to then pass to terraform script
.PHONY: run-cloud-vm
run-cloud-vm:
	terraform apply

.PHONY: fmt
fmt:
	terraform fmt

.PHONY: lint
lint: 
	terraform validate

.PHONY: show
show: 
	terraform show

.PHONY: init
init:
	terraform init

.PHONY: destroy
destroy:
	terraform destroy
