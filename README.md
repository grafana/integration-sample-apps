# integration-sample-apps

This repository contains various components used to test and validate [Grafana Cloud Integrations](https://grafana.com/docs/grafana-cloud/what-are/integrations/).

**Please note, all components in this repository are meant for transient testing only, and are _not for production use!_**

## Repository structure
| Directory             | Contents          |
|-----------------------|-------------------|
|[`charts/`](charts/) | A set of helm charts used to spin up temporary sample-apps for systems under observation on Kubernetes. |
|[`sample-apps/`](sample-apps/) | A collection of stand-alone sample-apps, primarily using [Multipass](https://multipass.run/) orchestration to configure and setup a temporary application, along with requisite load-testing to generate metrics. |
|[`ops/`](ops/) | Contains `sampletool`, the Go control plane behind the CI workflows and the `make` targets below, along with the files it deploys: the Docker Compose setup for Mimir, Loki and Grafana, and the k3s cloud-init. |


## Local setup instructions
Sample apps can be run locally, as well as on Github with Github Actions.
Currently, only Unix based systems are supported, and the sample-app Makefiles expect a bash shell.

### Prerequisites

Before you begin, ensure you have the following installed:

- [Multipass](https://multipass.run/)
- Docker (for rendering cloud-init files using Jinja)
- Git (for cloning the repository)
- [Go](https://go.dev/dl/), at least the version in [`go.mod`](go.mod) (the `make` targets build and run `sampletool` with `go run`)

Every `make` target below is a thin wrapper around `sampletool`. Run `make help` to see all of its commands, or call it directly with `go run ./ops/cmd/sampletool <group> <command> -h`.

#### macOS Local Network Permissions

**Important for macOS users**: Ensure Multipass, Docker, and your terminal application have local network access permissions. To check or grant these permissions, go to System Settings → Privacy & Security → Local Network, and ensure these applications are enabled. Without these permissions, the sample apps may fail to communicate properly with the databases and services.

### Setup databases

Ensure Multipass is running, then from the root of the repo execute:
```sh 
make setup-dbs
```

This will setup Grafana (with its image renderer), Mimir, and Loki using Docker Compose in a single Multipass VM, and handle relevant port-forwarding. The `dbs` parameter is the name of the deployment, and can be changed should you want to run multiple setups in isolation.

The databases mirror Grafana Cloud stack defaults where it affects what sample apps produce. The data sources are named `grafanacloud-local-prom` (the default, with a 60s scrape interval) and `grafanacloud-local-logs`. Mimir applies Grafana Cloud's non-autoscaled limits, and translates OTLP metrics with unit and type suffixes and the default promoted resource attributes. Grafana only runs for `ENV=local`. 

These settings come from `ops/qa/dbs` and apply to `make setup-dbs` and CI only.
`ENV=k3d` targets a separately configured environment with Mimir, Loki, etc.

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

### Capturing dashboard screenshots

Sample apps that list their integration's dashboards (see [Adding dashboard screenshots](sample-apps/README.md#adding-dashboard-screenshots)) can have them rendered against the data they produced:

```sh
make screenshot-apps APPS=<apps>
```

This loads each dashboard into the Grafana of the databases VM and saves a full-page image of it to `screenshots/<app>/`. In CI the same step runs for every changed sample app, and the images are posted as a comment on the pull request.

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