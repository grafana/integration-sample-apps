# Summary
The following is aimed at running a Windows VM through Azure with an Active Directory environment running. This is all managed through a Terraform script.

# Instruction

- Ensure that [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) is installed.
- Ensure you have [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed.
- Sign into Azure CLI by running `az login`
- Run `make init` the first time you use this.
- Populate the credentials in `variables.tfvars`
- Run `make run-cloud-vm` to create the VM.
- When finished, run `make destroy` to delete the VM.

# Further details

The script creates a VM on your Azure account that you supply through Azure CLI. This means that you are in charge of any potential clean up and billing of the VM.

