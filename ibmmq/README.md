# Summary

The following sample app creates an Ubuntu VM on GCP which hosts an IBM MQ cluster running through MiniKube.

# Instruction

- Ensure that Terraform is installed.
- Run `make init` the first time you use this.
- Run `make run-cloud-vm` to run the interactive prompt that will create the VM with Active Directory.

# Further details

The script creates a `e2-standard-2` Ubuntu VM with around 50GB of disk space. Pricing can be found [here](https://cloud.google.com/compute/vm-instance-pricing)
