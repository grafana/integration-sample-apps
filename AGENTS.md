# AGENTS.md

Sample apps run a system that a Grafana Cloud integration monitors, put load on it, and send its
telemetry to Mimir and Loki. CI then checks that the metrics the integration expects arrive, and
captures the integration's dashboards. They're for transient testing only, never production. This
repository is public.

## What a passing sample app proves

- **It proves** that the system, under this app's load, produces the listed metric names with the
  integration's job label.
- **It doesn't prove** that the integration's own collector configuration keeps those metrics. Each
  sample app ships its own collector config, written to resemble the integration's. Most don't apply
  the integration's metric filtering.
- **It doesn't check** values, labels other than `job` and `instance`, logs or alerts. The test is
  an instant query per metric name: present or not. Dashboard screenshots show whether panels have
  data, but nothing fails on them.

## Layout

| Path | What |
|---|---|
| `sample-apps/<slug>/` | One sample app per integration. The directory name is the integration's slug. |
| `sample-apps/README.md` | What CI needs from a sample app, and how to list dashboards to screenshot. Read it before adding an app or changing its tests. |
| `sample-apps/Makefile` | Shared targets that each app's `Makefile` includes: k3s setup and teardown, and `shell`. |
| `ops/cmd/sampletool/` | `sampletool`, the Go control plane behind every root `make` target and CI. `make help` lists its commands. |
| `ops/qa/dbs/` | The Mimir, Loki and Grafana that apps send to, locally and in CI. |
| `ops/qa/k3s-main-cloud-init.yaml` | Cloud-init for k3s main nodes. |
| `charts/` | Helm charts for apps on Kubernetes. |
| `quickstart/` | k3s and Linux quickstarts. |

## Kinds of sample app

- **One VM with cloud-init.** Most apps, e.g. `sample-apps/mysql`. `jinja/templates/cloud-init-template.yaml`
  installs the system and Alloy (from `apt.grafana.com`), and writes Alloy's config to
  `/etc/alloy/config.alloy`. `render-config` renders it with Docker from `jinja/variables/cloud-init.yaml`,
  which `defaultconfig` writes.
- **k3s.** `apache-activemq`, `apache-cassandra`, `apache-couchdb`, `apache-mesos`, `gitlab`,
  `influxdb`, `oracledb`, `presto` and `varnish-cache` run on one k3s node (`make k3s-setup`).
  `kafka` runs on a main node and two workers (`make k3s-setup-cluster`). Both call
  `sampletool k3s up`. An app's `.hardware_requirements` overrides the VM sizes (by default 4 CPUs,
  6G and 20G for the main node, and 2 CPUs, 6G and 20G per worker).
- **Not runnable in CI.** Apps with an empty `.CI_BYPASS` file need a cloud provider or an external
  service: `apache-hbase`, `apache-solr`, `catchpoint`, `databricks`, `istio`, `openstack`, `pinecone`,
  `velero` and `windows-active-directory`. They have no `tests/metrics/` and are tested by hand.
- **Windows.** `sample-apps/windows` has its own workflow on a Windows runner, through WSL.

When adding an app, copy the closest existing one rather than starting from scratch.

### Tests

- `tests/metrics/<scenario>`: expected metric names, separated by whitespace, usually one per line.
  `#` starts a comment. A name listed twice counts twice towards the success rate. Recording rule
  outputs (`level:metric:operations`, such as `instance:mysql_heartbeat_lag_seconds`) are skipped,
  because the databases run no rules.
- `tests/configs/<scenario>.config`, in `.env` syntax: `JOB_LABEL` is required, and used as a regex
  (`job=~"..."`). Optional: `INSTANCE_FILTER` (space-separated instance regexes, each checked
  separately) and `METRICS_SUCCESS_RATE_REQUIRED` (default `0.8`). `sampletool` reads no other key.
- `tests/dashboards` (optional): the integration's mixin as `jsonnet-libs/<mixin>[@ref]`, or dashboard
  JSON URLs, one per line. CI screenshots each one.

The metrics list should hold what the integration's dashboards and alerts use, not every metric the
exporter emits. A rate below `1.0` allows for listed metrics the load doesn't produce. When the list
changes, check the rate still fits it.

`sampletool apps test --metrics <dir>` replaces the lists with ones from `<dir>`: `<dir>/<app>/<scenario>`,
or `<dir>/<app>` for an app's only scenario, or for its `integration` scenario when it has several. The
scenario's config still applies. Other repositories use this to test their own version of an
integration's list: `.github/workflows/sample-app.yml` takes the apps, a ref and an artifact of lists,
and pull requests here call it for the apps they change.

## The development loop

Needs bash, Multipass, Docker and Go. Run these from the repository root.

Without someone to approve permission prompts, these commands are denied, so phrase them this way:

- **No `git` after a `cd` in the same command.** Pass the path instead:
  `git log -- sample-apps/mysql`, `git ls-files sample-apps/mysql`.
- **Edit files directly**, not with `sed -i`, `echo >` or an inline script.
- **Run the root `make` targets and `go` from the root**, e.g. `make lint APPS=mysql` and
  `go test ./ops/...`, not `make -C ../.. lint` or `cd ops && go test ./cmd/sampletool/`.

0. **Lint first:** `make lint APPS=mysql`, or `make lint` for every app, checks in under a second what
   CI needs, without a VM. Add `--json` for machine-readable findings:
   `go run ./ops/cmd/sampletool apps lint --json --apps mysql`. Errors fail it; warnings don't. CI
   lints the apps a pull request changes.
1. **Databases:** `make setup-dbs` starts a VM called `dbs` (2 CPUs, 4G, 40G disk) with Mimir on
   `:9009` and Loki on `:3100`, plus Grafana on `:3000` with anonymous Admin, and prints its address.
   Pass the same `DBS_NAME=<name>` to `setup-dbs`, `setup-apps`, `test-apps`, `screenshot-apps` and
   `stop-dbs` to run a stack of your own beside someone else's.
2. **App:** `make setup-apps APPS=mysql` runs the app's `make run-ci` pointed at `dbs`, as CI does.
   `ENV=k3d` points it at the local k3d stack (`mimir.k3d.localhost:9999`) instead, and adds the k3d
   hostnames to `/etc/hosts` on every VM the app launched.
3. **Wait:** 3 minutes, as CI does (`go run ./ops/cmd/sampletool apps wait`).
4. **Test:** `make test-apps APPS=mysql` prints a pass or fail per metric and per scenario.
5. **Screenshots:** `make screenshot-apps APPS=mysql` saves each dashboard in `tests/dashboards` to
   `screenshots/mysql/`. Set `GITHUB_TOKEN` if you list mixins often: without one, GitHub allows 60
   API requests an hour.
6. **Iterate:** cloud-init only runs on a VM's first boot, so a template change needs a new VM: run
   `make stop` in the app's directory, then set it up again. To try an Alloy change quickly, edit
   `/etc/alloy/config.alloy` on the VM and restart Alloy, then put the change in the template.
7. **Tear down:** `make stop-apps APPS=mysql` and `make stop-dbs`.

To run an app with your own values, work in its directory instead: `make clean defaultconfig`, edit
`jinja/variables/cloud-init.yaml`, then `make run`.

When changing `sampletool` itself, run `go test ./ops/...`. Its tests include a lint of the whole
repository, so an app that lints with errors fails them.

### Debugging

- `multipass list`, and `multipass shell <vm>` or `make shell` in the app's directory.
- On the VM: `cloud-init status --wait`, `/var/log/cloud-init-output.log`,
  `sudo systemctl status alloy`, `sudo journalctl -u alloy -f`, and `curl` the exporter's `/metrics`
  (`make fetch-prometheus-metrics` in `sample-apps/mysql`).
- From the host, query Mimir directly:
  `curl -s "http://<dbs-ip>:9009/prometheus/api/v1/query?query=up"`, or list every metric name with
  `/prometheus/api/v1/label/__name__/values`. `multipass info dbs` shows the address.

## Gotchas

- **CI waits 180s for every app**, with no per-app override. An app has to produce its metrics in
  that time.
- **`setup-apps` discards your config edits.** `run-ci` runs `clean` and `defaultconfig` first.
- **`defaultconfig` resets the variables file.** Its first line overwrites it, so edit the file after
  running it, never before. Lint warns about a recipe that only appends.
- **`ENV=k3d` finds an app's VMs by comparing `multipass list` before and after `run-ci`.** A VM
  someone else launches in the meantime gets the k3d hostnames too.
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
- **Screenshots cover the 5 minutes before they're taken**, and skip dashboards exported for sharing
  (with `__inputs`).
- **CI only runs changed apps**, one job per app on an 8-core Ubuntu runner, at most 10 at a time,
  with 30 minutes each. `windows` is left out of that workflow.

## Rules

MUST NOT:

- Run `make stop-all` or `multipass delete --all`. They delete every Multipass VM on the machine, not
  only this repository's. Stop what you started with `make stop-apps APPS=<apps>` and `make stop-dbs`.
  `.claude/settings.json` denies both, and allows the usual `make`, `sampletool` and `multipass`
  commands.
- Commit credentials, real endpoints or stack URLs. `Makefile` defaults stay placeholders such as
  `your_prometheus_password`. Rendered `cloud-init.yaml` files and `jinja/variables/` hold real values:
  check `git status` before committing.
- Name internal repositories, internal documents, tickets or stacks in files or commits. This
  repository is public.
- Remove expected metrics or lower `METRICS_SUCCESS_RATE_REQUIRED` only to make the test pass. Fix the
  app's load or config, or record why the metric can't be produced.
- Add `.CI_BYPASS` to an app CI could run.

MUST:

- Run `make lint APPS=<apps>` before starting a VM, and leave it with no errors.
- Delete the VMs you started once you're done with them.
- Give a new app a `run-ci` target that uses `LOKI_INSTANCE` and `PROMETHEUS_INSTANCE`, a
  `tests/` directory, and a `README.md`, and include `../Makefile` last in its `Makefile`.
- Keep an app's `README.md`, `Makefile` targets and `tests/` in step with what it does.
