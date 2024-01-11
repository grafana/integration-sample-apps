# Apache Solr and ZooKeeper Cluster Sample App

This project sets up a cluster of Apache Solr and ZooKeeper instances, integrated with Grafana agent for metric and log collection. It uses Multipass to create virtual machines where Apache Solr and ZooKeeper are deployed and configured. Additionally, a Grafana Agent is installed for metrics and logs collection and forwarding.

## Prerequisites

- Multipass: Used to create and manage VMs.
- Grafana Cloud Account: For metrics and log forwarding (optional).
- Basic understanding of Solr, ZooKeeper, and Grafana.

## Versions
Apache Solr: 8.11.2
ZooKeeper: 3.4.13
Grafana Agent: 0.39.0-1 for arm64 architecture (adjust as per your architecture)

## Configuration

Before running the setup, ensure to fill out the `grafana-agent-template.yaml` with your Grafana Cloud credentials and endpoints. Replace placeholders like `<your grafana.com password>`, `<your grafana.com username>`, `<your prometheus push endpoint>`, etc., with actual values. Rename the file to `grafana-agent.yaml` after configuration.

## Getting Started

To get started with setting up the cluster, follow these steps:

1. **Clone the Repository:**
   
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd grafana/integration-sample-apps/apache-solr
   ```

2. **Configure Grafana Agent:**

   Copy `grafana-agent-template.yaml` to `grafana-agent.yaml` and fill in your specific Grafana Cloud details.

3. **Run the Makefile Commands:**

   - To create and setup VMs with Solr and ZooKeeper:

     ```sh
     make run
     ```

   - To generate load which is also needed to populate solr prometheus metrics:

     ```sh
     make load-test
     ```

   - To setup Grafana Agent on VMs:

     ```sh
     make setup-grafana-agent
     ```

   - To fetch Prometheus metrics:

     ```sh
     make fetch-prometheus-metrics
     ```

   - To clean up and delete VMs:

     ```sh
     make clean
     ```

## Makefile Commands

- `make run`: Creates VMs and sets up Solr and ZooKeeper clusters.
- `make load-test`: Generates load on the Solr cluster for testing purposes.
- `make fetch-prometheus-metrics`: Fetches metrics from Prometheus exporter and saves to `prometheus_metrics`.
- `make setup-grafana-agent`: Sets up Grafana Agent on each VM for forwarding metrics and logs.
- `make clean`: Deletes all created VMs and performs cleanup.
