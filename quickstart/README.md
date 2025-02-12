## Quickstart

This directory contains examples and templates to help you get started with creating new sample apps that are CI capable.

Simply copy the sample-app type you need into the `sample-apps/` directory, name the new folder the same as the integration slug, e.g. for the `Linux` sample app, the integration slug is `linux-node`, thus the created folder must be `linux-node`.
Then read the instructions within to get it configured.

Currently supported are:

## Repository structure
| Sample-app example             | Notes         |
|-----------------------|-------------------|
|[`linux-standalone/`](linux-standalone/) | This example contains a simple standalone sample-app, providing a single Linux (Ubuntu-latest) node to build your sample app on|
|[`k3s-clustered/`](k3s-clustered/) | This example contains a three-node k3s cluster, and instructions to apply a helm chart and configuration for your sample app. Alloy is provided via the K8s-monitoring-helm chart. |
|[`k3s-singlenode/`](k3s-singlenode/) | This example contains a single-node k3s deployment, and instructions to apply a helm chart and configuration for your sample app. Alloy is provided via the K8s-monitoring-helm chart. |