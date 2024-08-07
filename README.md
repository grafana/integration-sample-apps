# integration-sample-apps

This repository contains various components used to test and validate Grafana Cloud Integrations](https://grafana.com/docs/grafana-cloud/what-are/integrations/).

**Please note, all components in this repository are meant for transient testing only, and are _not for production use!_**

## Repository structure
| Directory             | Contents          |
|-----------------------|-------------------|
|[`charts/`](charts/) | A set of helm charts used to spin up temporary sample-apps for systems under observation on Kubernetes. |
|[`sample-apps/`](sample-apps/) | A collection of stand-alone sample-apps, primarily using [Multipass](https://multipass.run/) orchestration to configure and setup a temporary application, along with requisite load-testing to generate metrics. |
|[`ops/`](ops/) | Contains the scripts and configuration files required for CI workflows. |
