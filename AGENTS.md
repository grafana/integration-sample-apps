# AGENTS.md

Sample apps run a system that a Grafana Cloud integration monitors, put load on it, and send its
telemetry to Mimir and Loki. CI then checks that the metrics the integration expects arrive. They're
for transient testing only, never production. This repository is public.

## What a passing sample app proves

- **It proves** that the system, under this app's load, produces the listed metric names with the
  integration's job label.
- **It doesn't prove** that the integration's own collector configuration keeps those metrics. Each
  sample app ships its own collector config, written to resemble the integration's. Most don't apply
  the integration's metric filtering.
- **It doesn't check** values, labels other than `job` and `instance`, logs, dashboards or alerts.
  The test is an instant query per metric name: present or not.

## Layout

| Path | What |
|---|---|
| `sample-apps/<slug>/` | One sample app per integration. The directory name is the integration's slug. |
| `sample-apps/README.md` | What CI needs from a sample app. Read it before adding one or changing its tests. |
| `sample-apps/Makefile` | Shared targets that each app's `Makefile` includes: k3s setup and teardown, `configure-k3d-dns`, `shell`. |
| `ops/scripts/` | Scripts behind the root `Makefile` and CI. |
| `ops/qa/dbs/` | The Mimir, Loki and Grafana that apps send to, locally and in CI. |
| `ops/.defaultconfig` | Test defaults: `METRICS_SUCCESS_RATE_REQUIRED=0.8`, `SAMPLE_APP_SETUP_TIME=180s`. |
| `charts/` | Helm charts for apps on Kubernetes. |
| `quickstart/` | A clustered k3s quickstart. |

## Kinds of sample app

- **One VM with cloud-init.** Most apps, e.g. `sample-apps/mysql`. `jinja/templates/cloud-init-template.yaml`
  installs the system and Alloy (from `apt.grafana.com`), and writes Alloy's config to
  `/etc/alloy/config.alloy`. `render-config` renders it with Docker from `jinja/variables/cloud-init.yaml`,
  which `defaultconfig` writes.
- **k3s.** `apache-activemq`, `apache-cassandra`, `apache-couchdb`, `apache-mesos`, `gitlab`,
  `influxdb`, `oracledb`, `presto` and `varnish-cache` run on one k3s node (`k3s-setup`). `kafka`
  runs on a main node and two workers (`k3s-setup-cluster`). Both go through
  `ops/scripts/k3s_setup.sh`, then the app's scripts install the system and its monitoring.
- **Not runnable in CI.** Apps with an empty `.CI_BYPASS` file need a cloud provider or an external
  service: `apache-hbase`, `apache-solr`, `catchpoint`, `databricks`, `istio`, `openstack`, `pinecone`,
  `velero` and `windows-active-directory`. They have no `tests/metrics/` and are tested by hand.
- **Windows.** `sample-apps/windows` has its own workflow on a Windows runner, through WSL.

When adding an app, copy the closest existing one rather than starting from scratch.

### Tests

- `tests/metrics/<scenario>`: expected metric names, one per line.
- `tests/configs/<scenario>.config`: `JOB_LABEL` is required. It's used as a regex (`job=~"..."`).
  Optional: `EXTRA_GREP_REGEX`, `INSTANCE_FILTER` (space-separated instance regexes, each checked
  separately), `METRICS_SUCCESS_RATE_REQUIRED`. `SAMPLE_APP_SETUP_TIME` is documented as optional
  too, but the main QA workflow ignores it (see Gotchas).

The list should hold what the integration's dashboards and alerts use, not every metric the exporter
emits. A rate below `1.0` allows for listed metrics the load doesn't produce. When the list changes,
check the rate still fits it.

## The development loop

Needs bash, Multipass and Docker. Run these from the repository root.

1. **Databases:** `make setup-dbs` starts a VM called `dbs` (2 CPUs, 4G, 40G disk) with Mimir on
   `:9009` and Loki on `:3100`, plus Grafana on `:3000` with anonymous Admin. Get its address with
   `ops/scripts/multipass_get_ips.sh dbs`.
2. **App:** `make setup-apps APPS=mysql` runs the app's `make run-ci` pointed at `dbs`, as CI does.
   `ENV=k3d` points it at the local k3d stack (`mimir.k3d.localhost:9999`) instead, and adds the DNS
   entries the VM needs.
3. **Wait:** about 3 minutes, as CI does, or longer for slow apps.
4. **Test:** `make test-apps APPS=mysql`. Missing metrics are also appended to `missing_metrics` in
   the current directory. Delete it between runs.
5. **Iterate:** cloud-init only runs on a VM's first boot, so a template change needs a new VM: run
   `make stop` in the app's directory, then set it up again. To try an Alloy change quickly, edit
   `/etc/alloy/config.alloy` on the VM and restart Alloy, then put the change in the template.
6. **Tear down:** `make stop-apps APPS=mysql` and `make stop-dbs`.

To run an app with your own values, work in its directory instead: `make clean defaultconfig`, edit
`jinja/variables/cloud-init.yaml`, then `make run`.

### Debugging

- `multipass list`, and `multipass shell <vm>` or `make shell` in the app's directory.
- On the VM: `cloud-init status --wait`, `/var/log/cloud-init-output.log`,
  `sudo systemctl status alloy`, `sudo journalctl -u alloy -f`, and `curl` the exporter's `/metrics`
  (`make fetch-prometheus-metrics` in `sample-apps/mysql`).
- From the host, query Mimir directly:
  `curl -s "http://<dbs-ip>:9009/prometheus/api/v1/query?query=up"`, or list every metric name with
  `/prometheus/api/v1/label/__name__/values`.

## Gotchas

- **`setup-apps` and `test-apps` always use the VM named `dbs`.** `DBS_NAME` only renames the VM that
  `setup-dbs` creates.
- **CI waits 180s for every app.** `integration-sample-app-qa.yml` reads `SAMPLE_APP_SETUP_TIME` only
  from `ops/.defaultconfig`, so a value in an app's `tests/configs/` has no effect there. An app that
  needs longer has to produce its metrics within 180s, or the workflow has to change.
- **`setup-apps` discards your config edits.** `run-ci` runs `clean` and `defaultconfig` first.
- **`defaultconfig` appends.** Running it twice without `make clean` duplicates every key.
- **Launch VMs one at a time.** Parallel Multipass launches have produced duplicate MAC addresses and
  stuck VMs. `sample-apps/linux-hostmetrics` launches its VMs one at a time for this reason.
- **Architecture.** CI runs on amd64. On Apple Silicon, Multipass VMs are arm64. Pick downloaded
  binaries with `dpkg --print-architecture` rather than hardcoding `amd64`.
- **macOS Local Network permission.** Multipass, Docker and your terminal all need it, or apps can't
  reach `dbs`.
- **Scrape interval.** The local data source assumes 60s, as Grafana Cloud does, and most apps scrape
  at 60s. A shorter interval locally hides `rate()` windows that get too few samples on Cloud.
- **OpenTelemetry names.** Mimir adds unit and type suffixes to OTLP metric names, as Grafana Cloud
  does, e.g. `system.cpu.time` becomes `system_cpu_time_seconds_total`. Expected lists for
  OpenTelemetry apps use the suffixed names. `job` comes from `service.namespace` and `service.name`.
- **CI only runs changed apps**, one job per app on an 8-core Ubuntu runner, with 30 minutes each.
  `windows` is left out of that workflow.

## Rules

MUST NOT:

- Run `make stop-all` or `multipass delete --all`. They delete every Multipass VM on the machine, not
  only this repository's. Stop what you started with `make stop-apps APPS=<apps>` and `make stop-dbs`.
- Commit credentials, real endpoints or stack URLs. `Makefile` defaults stay placeholders such as
  `your_prometheus_password`. Rendered `cloud-init.yaml` files and `jinja/variables/` hold real values:
  check `git status` before committing.
- Name internal repositories, internal documents, tickets or stacks in files or commits. This
  repository is public.
- Remove expected metrics or lower `METRICS_SUCCESS_RATE_REQUIRED` only to make the test pass. Fix the
  app's load or config, or record why the metric can't be produced.
- Add `.CI_BYPASS` to an app CI could run.

MUST:

- Delete the VMs you started once you're done with them.
- Give a new app a `run-ci` target that uses `LOKI_INSTANCE` and `PROMETHEUS_INSTANCE`, a
  `tests/` directory, and a `README.md`, and include `../Makefile` last in its `Makefile`.
- Keep an app's `README.md`, `Makefile` targets and `tests/` in step with what it does.
