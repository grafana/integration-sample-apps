# integration-sample-apps

This repository contains various components used to test and validate [Grafana Cloud Integrations](https://grafana.com/docs/grafana-cloud/what-are/integrations/).

**Please note, all components in this repository are meant for transient testing only, and are _not for production use!_**

## Repository structure
| Directory             | Contents          |
|-----------------------|-------------------|
|[`charts/`](charts/) | A set of helm charts used to spin up temporary sample-apps for systems under observation on Kubernetes. |
|[`sample-apps/`](sample-apps/) | A collection of stand-alone sample-apps, primarily using [Multipass](https://multipass.run/) orchestration to configure and setup a temporary application, along with requisite load-testing to generate metrics. |
|[`ops/`](ops/) | Contains the scripts and configuration files required for CI workflows. |


## Local setup instructions
Sample apps can be run locally, as well as on Github with Github Actions.
Currently, only Unix based systems are supported, and all scripts expect a bash shell.

### Prerequisites

Before you begin, ensure you have the following installed:

- [Multipass](https://multipass.run/)
- Docker (for rendering cloud-init files using Jinja)
- Git (for cloning the repository)

### Setup databases

Ensure Multipass is running, then from the root of the repo execute:
```sh 
./ops/scripts/multipass_setup_qa_dbs.sh dbs local
```

This will setup Grafana, Mimir, and Loki using Docker Compose in a single Multipass VM, and handle relevant port-forwarding. The `dbs` parameter is the name of the deployment, and can be changed should you want to run multiple setups in isolation.

Then get the IP address of the deployed VM with the databases, either manually through the Multipass GUI, or via the following script:

```sh
./ops/scripts/multipass_get_ips.sh dbs
``` 
This command should result in a single IP being returned, and can be piped into further commands or used manually, e.g. `10.252.79.181` in this example and can be piped into further commands, env vars, or used manually, if you wish. Again, `dbs` is the name of the VM, and can be changed to whatever name you chose.

### Run a sample-app
Running sample apps can differ from sample-app to sample-app, but if they are CI compatible, e.g. if they do **not** have a `.CI_BYPASS` file in their directory, then they can be run locally as well.

To do so, navigate to the sample app of choice, then run the following command, substituting the `<ip>` variable with the IP of your database obtained above, or an environment variable if you stored it in one. 
This provides an override for the make command to set the `remote_write` address for Alloy:

```sh
make LOKI_INSTANCE=<ip>:3100 PROMETHEUS_INSTANCE=<ip>:9009 run-ci
```

For most purposes, the `run-ci` make target will be the ideal, and so is used as the default here, as that will run any templating and prerequisite steps needed, and potentially load generation.

### Checking metrics match expected_metrics

Once your sample-app has been setup, and given time to run (we recommend 2-3 minutes), you can run a script to check if the expected metrics have been emitted, scraped, and stored in Mimir:

To do so, run the following command from the root of the repository, substituting `<sample-app>` with the name of your sample app, and `<ip>` of the database host:
```sh
./ops/scripts/check_metrics.sh <sample-app> <ip>:9009
```

This will give you a metric by metric pass/fail, as well as an overall pass-fail based on the configured pass-rate for the given sample-app

### Tearing down the test setup

Tearing down the sample-app is as simple as running the following command from within the sample-app directory:
```sh
make stop
```

To destroy the database vm and ensure it's properly cleaned up, run the following command, substituting `dbs` if you changed the name of the database deployment:
```sh
multipass delete --purge dbs
```
