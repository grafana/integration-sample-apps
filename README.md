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

#### macOS Local Network Permissions

**Important for macOS users**: Ensure Multipass, Docker, and your terminal application have local network access permissions. To check or grant these permissions, go to System Settings → Privacy & Security → Local Network, and ensure these applications are enabled. Without these permissions, the sample apps may fail to communicate properly with the databases and services.

### Setup databases

Ensure Multipass is running, then from the root of the repo execute:
```sh 
make setup-dbs
```

This will setup Grafana, Mimir, and Loki using Docker Compose in a single Multipass VM, and handle relevant port-forwarding. The `dbs` parameter is the name of the deployment, and can be changed should you want to run multiple setups in isolation.

### Run a sample-app
Running sample apps can differ from sample-app to sample-app, but if they are CI compatible, e.g. if they do **not** have a `.CI_BYPASS` file in their directory, then they can be run locally as well.

Simply run the following, replacing `<apps>` with a comma-separated list of desired sample-apps. This will, by default connect to the established databases in the previous section, with no need to supply IP address or ports.

```sh
make setup-apps APPS=<apps>
```

Should you desire another metrics target, such as k3d for cloud integration development, simply supply `ENV=k3d`

### Checking metrics match expected_metrics

Once your sample-app has been setup, and given time to run (we recommend 2-3 minutes), you can run a script to check if the expected metrics have been emitted, scraped, and stored in Mimir:

To do so, simply run the following make command, again providing a comma-separated list of apps, and an optional `ENV` parameter.
*Note*: The `APPS` and `ENV` parameters can be assigned as environment variables and thus easily reused throughout.
```sh
make test-apps APPS=<apps>
```
This will give you a metric by metric pass/fail, as well as an overall pass-fail based on the configured pass-rate for the given sample-app

### Tearing down the test setup

Tearing down can be done separately for the databases and sample-apps.
For the databases, run:
```shell
make stop-dbs
```

For sample-apps, a comma-separated list is again expected, and can therefore selectively tear down apps.
```shell
make stop-apps APPS=<apps>
```

Should you wish to delete all spawned VMs, you can do so with 
```shell
make stop-all
```