# Runs an interactive prompt that asks users for information to then pass to terraform script
.PHONY: run-cloud-vm
run-cloud-vm:
	terraform apply -var-file="variables.tfvars" 

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
	terraform destroy -var-file="variables.tfvars" 
