# --- QUICKSTART INSTRUCTIONS ---
This section of the README is intended to help quickly convert this quickstart example to a functional sample app, and assumes that you have already read the that you have already read the short summary on [updating sample-apps to be CI capable](https://github.com/grafana/integration-sample-apps/blob/main/sample-apps/README.md)

## 1 - Variables
Some variables, e.g. `<INTEGRATION_NAME>` are used throughout and will need to be replaced with appropriate values. You can find-replace these, but please do a sanity check.

|Variable |Description |
|---------|------------|
|<INTEGRATION_NAME>| Full integration name, as youi want it to show up in the documentation, e.g. `Linux` |
|<INTEGRATION_SLUG>| Integration slug, as defined by the cloud integration, e.g. `linux-node`|
|<INTEGRATION_SNIPPET_SLUG>| Like integration slug, but in case they are different, e.g. `node_exporter`. Used in the Alloy scrape jobs. |

## 2 - Files
The following files require manual review or modification, and is where logic for spinning up your sample app will go in most cases. Please carefully review the list and add logic where required.
| File | Instructions |
|------|--------------|
|[.config](./.config) | Add integration specific config like the job label, or potential pass-rate override here.|
|[expected_metrics](./expected_metrics) | Add a newline separated list of expected metrics for the integration. Simple metrics names only, no labels or other qualifiers should be present |
|[README](./README.md) | End-user facing README, update with a brief summary of the what the sample app does, and any specific instructions needed to run it. If you include any new relevant make commands, make sure to add them. |
|[makefile](./Makefile) | Makefile for setting up the sample app. There is a minimal interface contract that must be obeyed, which the Github Actions CI expects to be present, which you can find documented briefly under [section 6 here](https://github.com/grafana/integration-sample-apps/blob/main/sample-apps/README.md) |
|[cloud-init-template.yaml](./jinja/templates/cloud-init-template.yaml) | Cloud-init template file for standing up the sample app VM and embedded Alloy deployment. Include any instructions needed to install and configure the system under observation, along with a fully configured Alloy snippet. If needed you can add load-generationd directly in this cloud-init, or copy this setup to spawn a second node for load-generation |

Once the sample-app has been completed and validated, update the README to reflect to end-users how to use it. As a final step, delete the QUICKSTART_README.md file (this file)
# --- QUICKSTART INSTRUCTIONS END ---