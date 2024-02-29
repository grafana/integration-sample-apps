## OpenStack Sample App

The following sample app uses Terraform to run an Ubuntu VM on GCP with an OpenStack environment.

The script creates an `e2-standard-8` VM. Pricing can be found [here](https://cloud.google.com/compute/vm-instance-pricing). Due to the resource demands of OpenStack, modifying this script to create a smaller VM is not recommended.

# Instructions

- Ensure that Terraform is installed.
- Ensure you have a GCP service account with the necessary permissions that will allow you to create a VM.
- Run `make init` the first time you run the sample app.
- Populate the variables in `variables.tfvars` to match your GCP environment and Grafana credentials.
- **Critical**: When entering URLs for Loki and Prometheus, escape any forward slashes with a backslash (`http://localhost:3000` -> `http:\/\/localhost:3000`)
- Run `make run-cloud-vm` to start the interactive prompt which will launch a VM with Openstack installed.
