# Runs an interactive prompt that asks users for information to then pass to terraform script
.PHONY: run-cloud-vm
run-cloud-vm:
	@echo "Creating Windows VM with Active Directory installed."
	@read -p "Enter GCP project name: " project_name; \
		read -p "Enter GCP region name: " region_name; \
		read -p "Enter GCP zone name: " zone_name; \
		read -p "Enter path to GCP service account credentials file: " credentials_file_path; \
		echo "project=\"$$project_name\"" > terraform.tfvars; \
		echo "region=\"$$region_name\"" >> terraform.tfvars; \
		echo "zone=\"$$zone_name\"" >> terraform.tfvars; \
		echo "credentials=\"$$credentials_file_path\"" >> terraform.tfvars; \
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
