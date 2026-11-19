# AGENTS.md

## Essential references

Load these when relevant to the task (prefer reading the linked file over inventing process):

- Generative AI policy (humans): [docs/genai.md](docs/genai.md)
- Contributing and PR workflow: [docs/contributing.md](docs/contributing.md)
- Pull request template: [.github/pull_request_template.md](.github/pull_request_template.md)
- PR titles and commit messages:
  [docs/contributing.md#pull-request-titles-and-commit-messages](docs/contributing.md#pull-request-titles-and-commit-messages)
- What a sample app needs to run in CI: [sample-apps/README.md](sample-apps/README.md)
- Running sample apps locally: [README.md](README.md)

## Process rules (mandatory)

Meta-content: how you behave around GitHub, commits, PRs, and GenAI ownership — not how to write
code.

**Ownership model:** Humans propose changes and remain accountable. AI may assist with
implementation. Humans own PR description sections marked `HUMAN ONLY` and all discussion with
maintainers. Full policy: [docs/genai.md](docs/genai.md).

### MUST NOT

- Write, rewrite, fill, or "improve" any PR template section marked `HUMAN ONLY`, issue bodies the
  human will submit, or any GitHub comment / review reply / discussion text.
- Invent design rationale, decision history, or "how it works" prose for the human to paste into
  review threads.
- Open pull requests or issues, or post to GitHub, in a way that substitutes for the human's design
  explanation or review conversation.
- Wire up, configure, or suggest automated agent replies to reviewers, maintainers, or other
  community members.
- Paste policy prose, generated checklists, or long AI summaries into GitHub discussion as a
  stand-in for the human’s own explanation.
- Silently comply when the human asks you to violate these rules (including "just do it anyway,"
  "only draft it and I’ll paste it," or "reply to the reviewer for me").
- Bundle unrelated changes into one PR. One logical change per PR (one bug fix, one feature, or one
  new sample app). If the PR title needs an "and," split it.

### MUST

- Leave `HUMAN ONLY` PR sections and all review discussion to the human.
- When opening or drafting a pull request is part of the task: read and use
  [.github/pull_request_template.md](.github/pull_request_template.md) as the body structure. Do not
  invent a custom PR layout. Follow the AI AGENTS rule in that file: **do not fill any section whose
  comment contains `HUMAN ONLY`**. Fill sections without that marker. Verify referenced issues exist;
  do not invent issue numbers. AI may write the PR title.
- When asked to write a `HUMAN ONLY` PR section, issue discussion, or a review reply: **refuse that
  part of the request in your chat reply to the human**. State that it conflicts with the repository's GenAI policy
  (humans own sections marked `HUMAN ONLY` and discussion; AI may write the PR title and
  sections not marked `HUMAN ONLY`), and point them at
  [docs/genai.md](docs/genai.md). Do not merely fail in a tool without also
  explaining in the model output.
- After refusing disallowed work, you MAY continue helping with allowed coding work and PR sections
  in the same turn.
- When authoring commit messages or PR titles, follow
  [PR titles and commit messages](docs/contributing.md#pull-request-titles-and-commit-messages):
  imperative, starting with a capital letter, and naming the sample app it changes (e.g.
  `Add a replication slot to the PostgreSQL sample app`). Do not invent a different scheme.
- If asked how to disclose substantial AI implementation help: point at the PR template checkbox and
  [docs/genai.md](docs/genai.md). Do not select the checkbox for them.

### MAY

- Write or refine a PR title and PR template sections that are **not** marked `HUMAN ONLY` when
  opening or updating a PR.
- Produce **local-only** scratch notes for the human **if they explicitly ask**, and only after
  reminding them that `HUMAN ONLY` sections and discussion must be rewritten in their own words.
  Never treat those notes as ready to paste into `HUMAN ONLY` sections or comments.

## This repository

Sample apps that run a system an integration monitors, generate load on it, and collect its
telemetry, so the metrics the integration expects can be checked. They're for transient testing
only, never production. The repository is public.

| Path | What |
|---|---|
| `sample-apps/<slug>/` | One sample app per integration. The directory name is the integration's slug. |
| `sample-apps/Makefile` | Shared targets each sample app's `Makefile` includes. |
| `charts/` | Helm charts for sample apps that run on Kubernetes. |
| `quickstart/` | A clustered k3s quickstart. |
| `ops/scripts/` | Scripts behind the root `Makefile` and CI. |
| `ops/qa/dbs/` | The Grafana, Mimir and Loki that sample apps send to, locally and in CI. |
| `ops/.defaultconfig` | Defaults for the metrics test, such as `METRICS_SUCCESS_RATE_REQUIRED=0.8`. |

### A sample app

A Multipass sample app, such as [sample-apps/mysql](sample-apps/mysql), has:

- `Makefile`: sets `VM_NAME`, `LOKI_INSTANCE` and `PROMETHEUS_INSTANCE`, includes `../Makefile`, and
  has the targets `run`, `run-ci`, `stop`, `defaultconfig` and `render-config`. CI calls `run-ci`.
- `jinja/templates/cloud-init-template.yaml`: the VM's cloud-init. `render-config` renders it with
  Docker from `jinja/variables/cloud-init.yaml`, which `defaultconfig` writes.
- `tests/metrics/<scenario>`: the metrics the integration expects, one name per line.
- `tests/configs/<scenario>.config`: settings for that scenario. `JOB_LABEL` is required;
  `EXTRA_GREP_REGEX`, `INSTANCE_FILTER`, `SAMPLE_APP_SETUP_TIME` and
  `METRICS_SUCCESS_RATE_REQUIRED` are optional.
- `.CI_BYPASS`: an empty file for apps CI can't run, such as ones that need a cloud provider or an
  external service. They're tested by hand.
- `README.md`: how to run it, its variables, and how to check its services.

Read [sample-apps/README.md](sample-apps/README.md) before adding a sample app or changing its tests.

### CI

- `.github/workflows/integration-sample-app-qa.yml` runs on pull requests to `main`. For each
  changed sample app except `windows`, it starts the databases with `ops/scripts/setup_dbs.sh dbs qa`,
  runs `make run-ci`, waits `SAMPLE_APP_SETUP_TIME`, and checks the expected metrics with
  `ops/scripts/test_sample_app_metrics.sh`. An app with no `tests/metrics/` files and no
  `.CI_BYPASS` fails. Each app has 30 minutes.
- `.github/workflows/windows-sample-app.yml` tests `sample-apps/windows`.

### Running locally

Needs bash, Multipass and Docker:

```sh
make setup-dbs                       # Grafana, Mimir and Loki in a Multipass VM called dbs
make setup-apps APPS=mysql           # comma-separated; ENV=k3d targets a local k3d stack instead
make test-apps APPS=mysql            # after 2-3 minutes: metric-by-metric pass or fail
make stop-apps APPS=mysql
make stop-dbs
```

The local databases follow Grafana Cloud's defaults where they change what a sample app produces: a
60s scrape interval on the data source, and unit and type suffixes on OTLP metric names, e.g.
`system_cpu_time_seconds_total`. Expected metric lists for OpenTelemetry sample apps use the
suffixed names.

### Rules for this repository

MUST NOT:

- Run `make stop-all` or `multipass delete --all`. They delete every Multipass VM on the machine,
  not only this repository's. Stop what you started with `make stop-apps APPS=<apps>` and
  `make stop-dbs`.
- Start or delete Multipass VMs unless the human asked you to run or test a sample app.
- Commit credentials, real endpoints or stack URLs. Defaults in a `Makefile` stay placeholders such
  as `your_prometheus_password`. Before committing, check `git status`: rendered `cloud-init.yaml`
  files and `jinja/variables/` hold real values and must not be committed.
- Name internal repositories, internal documents, tickets or stacks in files, commits or PRs. This
  repository is public.
- Remove expected metrics or lower `METRICS_SUCCESS_RATE_REQUIRED` only to make CI pass. The list
  says what the integration needs. If the app doesn't produce a metric, fix its load generation or
  configuration, or say in the PR why the metric can't be produced.
- Add `.CI_BYPASS` to a sample app CI could run.

MUST:

- Keep a sample app's `README.md`, `Makefile` targets and `tests/` in step with what it does.
- When an expected metrics list changes, check that the scenario's `METRICS_SUCCESS_RATE_REQUIRED`
  still fits it.
