### Velero on Minikube with GCP Bucket
---
The following provides a sample app for Velero. The sample app will run a linux multipass VM that automates the install of Velero and runs a simple script that backs up some simple pods. It has been tested for ARM64 and AMD64.

#### Prerequisites
* Access to a Google Cloud Platform project
    * Permission to create a service account
    * Permission to create a storage bucket
* Create a service account (Owner permissions are fine for a ***dev*** project, see VMWare docs for an LPU) and download its json key.
* Create a storage bucket with the default parameters and a unique bucket name.
    * You can use the `gsutil mb` [command](https://cloud.google.com/storage/docs/gsutil/commands/mb).
    * Keep in mind bucket name [considerations](https://cloud.google.com/storage/docs/buckets#considerations).
* Place the contents of the GCP service key into `gcp_credentials.json` which is in the `jinja/variables/` file path.
* Insert the bucket name you created into `jinja/variables/bucket.txt`
* Insert the proper grafana agent credentials into `jinja/variables/cloud-init`

#### Run
Once the prerequisites have been met, use the command: `make run` to create the sample app VM.

#### Loadgen
The sample app starts with some simple loadgen, the user can prompt additional load gen by running `make generate-load`.

#### Metrics
The user can get a snapshot of the prometheus metrics file that the sample app contains by running `make fetch-prometheus-metrics`

#### Documentation
* [GCP Plugin Repository](https://github.com/vmware-tanzu/velero-plugin-for-gcp)
