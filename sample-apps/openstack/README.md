## OpenStack sample app

The following sample app uses Terraform to run an Ubuntu VM on GCP with an OpenStack environment.

The script creates an `e2-standard-8` VM. This machine type includes 8 vCPUs, 4 cores, and 32 GB of memory. The image used by this sample app is Ubuntu 22.04 Jammy with a 50GB disk. Pricing can be found [here](https://cloud.google.com/compute/vm-instance-pricing). Due to the resource demands of OpenStack, modifying this script to create a smaller VM is not recommended.

## Dependencies

This sample app installs the following packages onto the VM it creates:

- Devstack (developer quickstart environment for OpenStack)
- Golang
- [OpenStack Prometheus Exporter](https://github.com/openstack-exporter/openstack-exporter)
- Grafana agent

## Instructions

- Ensure that Terraform is installed.
- Ensure you have a GCP service account with the necessary permissions that will allow you to create a VM.
- Run `make init` the first time you run the sample app.
- Populate the variables in `variables.tfvars` to match your GCP environment and Grafana credentials.
- **Critical**: When entering URLs for Loki and Prometheus, escape any forward slashes with a backslash (`http://localhost:3000` -> `http:\/\/localhost:3000`)
- Run `make run-cloud-vm` to start the interactive prompt which will launch a VM with Openstack installed.

## Platform support

Although this sample initializes an Ubuntu VM, it was not implemented using Multipass because of a lack of official support for the nova service for aarch64, which leads to errors when installing Devstack.
