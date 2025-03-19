# --- QUICKSTART INSTRUCTIONS ---
This section of the README is intended to help quickly convert this quickstart example to a functional sample app, and assumes that you have already read the short summary on [updating sample-apps to be CI capable](https://github.com/grafana/integration-sample-apps/blob/main/sample-apps/README.md)

## 1 - Variables
Some variables, e.g. `<INTEGRATION_NAME>` are used throughout and will need to be replaced with appropriate values. You can find-replace these, but please do a sanity check.

|Variable |Description |
|---------|------------|
|<INTEGRATION_NAME>| Full integration name, as youi want it to show up in the documentation, e.g. `Linux` |
|<INTEGRATION_SLUG>| Integration slug, as defined by the cloud integration, e.g. `linux-node`|
|<INTEGRATION_SNIPPET_SLUG>| Like integration slug, but in case they are different, e.g. `node_exporter`. Used in the Alloy scrape jobs and the integrations/ job label. |

## 2 - Files
The following files require manual review or modification, and is where logic for spinning up your sample app will go in most cases. Please carefully review the list and add logic where required.
| File | Instructions |
|------|--------------|
|[.config](./.config) | Add integration specific config like the job label, or potential pass-rate override here.|
|[expected_metrics](./expected_metrics) | Add a newline separated list of expected metrics for the integration. Simple metrics names only, no labels or other qualifiers should be present |
|[README](./README.md) | End-user facing README, update with a brief summary of the what the sample app does, and any specific instructions needed to run it. If you include any new relevant make commands, make sure to add them. |
|[makefile](./Makefile) | Makefile for setting up the sample app. There is a minimal interface contract that must be obeyed, which the Github Actions CI expects to be present, which you can find documented briefly under [section 6 here](https://github.com/grafana/integration-sample-apps/blob/main/sample-apps/README.md) |
|[configs/suo.alloy] | This file holds the Kubernetes specific Alloy scrape config and must be fully configured as it gets deployed with the [k8s-monitoring-helm chart](https://github.com/grafana/k8s-monitoring-helm). |
|[scripts/install_monitoring.sh](./scripts/install_monitoring.sh) | This file installs the k8s-monitoring-helm chart, and applies the SUO-specific Alloy config as defined in `configs/suo.alloy`. Modification should not be necessary in most cases, though it may be required for complicated Alloy scrape setups, or if an external Alloy setup is desired, rather than via k8s-monitoring-helm. |
|[scripts/suo_setup.sh](./scrips/suo_setup.sh) | This file contains the setup script to install and configure the system under observation. Executed during the `make install-suo` step, and must be provided by the user.

## 3 - Folders
A quick note here, the [configs/](configs/) folder will be copied wholesale to the main node of the spawned k3s cluster, so you can supply any additional configs here, if you need them on the host machine. 
This could include things like JMX configs or subcomponent configs needed for a reliable setup.

Once the sample-app has been completed and validated, update the README to reflect to end-users how to use it. As a final step, delete the QUICKSTART_README.md file (this file)
# --- QUICKSTART INSTRUCTIONS END ---