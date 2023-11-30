# Summary

The following is aimed at running a Windows VM through GCP with an Active Directory environment running. This is all managed through a Terraform script.

# Instruction

- Ensure that Terraform is installed.
- Ensure you have a GCP service account with the nessesary permissions that will allow you to create a Windows VM. (Note: GCP does not allow for a free Windows VM, so you will likely have to enable billing on your account.)
- Run `make init` the first time you use this.
- Run `make run-cloud-vm` to run the interactive prompt that will create the VM with Active Directory.

# Further details

The script creates a `n2-standard-2` vm. Pricing can be found [here](https://cloud.google.com/compute/vm-instance-pricing)
