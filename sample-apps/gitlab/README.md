# GitLab Community Edition Linux sample app

This sample application creates an Ubuntu VM integrated with Alloy for metric and log collection. This sample app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of [GitLab Community Edition](https://about.gitlab.com/install/) using GitLab's built-in monitoring endpoints. 

**Note**
> This sample application is installing quite a bit and requires some decent resources to run properly please see [Gitlab Pre-requisites](https://docs.gitlab.com/install/requirements) for more information about deployment.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Multipass](https://multipass.run/)
- Docker (for rendering the cloud-init configuration)
- Git (for cloning the repository)

## Quick Start for new users

To get started with the sample app, follow these steps:

1. **Clone the repository**: 
   ```sh
   git clone https://github.com/grafana/integration-sample-apps.git
   cd integration-sample-apps/sample-apps/gitlab
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VM**: 
   Use `make run` to start the GitLab sample app.

5. **Login to Gitlab**:
   Use `make gitlab-ui` to display the local URL for accessing the GitLab web interface. The default root username is `root` and the password is `d.^_R740Vp=/`. You can also run `make gitlab-creds` to print these credentials.

6. **Stop and clean Up**: 
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the GitLab sample app VM with GitLab Community Edition installed and configured.
- `make run-ci`: Runs in CI mode by cleaning, setting up default config, and launching the VM.
- `make shell`: Opens a shell session to the running VM for debugging and troubleshooting.
- `make stop`: Stops and removes the VM, then purges multipass resources.
- `make clean`: Removes generated configuration files and temporary resources.
- `make gitlab-version`: Displays GitLab environment information including version details.
- `make gitlab-creds`: Displays a Gitlab root username and password combination for testing.
- `make gitlab-ui`: Displays a locally reachable UI for accessing Gitlab.

## Default configuration variables

- `prom_pass`: Your Prometheus password.
- `prom_user`: Your Prometheus username.
- `prom_url`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9090/api/v1/push`).
- `loki_url`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.
- `interval`: Scrape interval for metrics collection (default: `10s`).

## GitLab configuration

The sample app automatically installs GitLab Community Edition and configures it for monitoring:

- **Memory**: Requires 8GB RAM minimum for proper operation
- **Storage**: Uses 10GB disk space
- **Installation timeout**: 10 minutes (GitLab installation can be time-consuming)
- **Metrics endpoint**: Available at `/-/metrics` for Prometheus scraping
- **Monitoring whitelist**: Configured to allow localhost (`127.0.0.0/8`) access
- **Default credentials**: Root user with password `d.^_R740Vp=/`

## Log collection

The sample app collects GitLab logs from:
- `/var/log/gitlab/gitlab-rails/exceptions_json.log`: GitLab exception logs in JSON format

## Validating services

### Alloy
- **Check service status**: Confirm that Alloy is running.
  ```bash
  systemctl status alloy.service
  ```
- **Review configuration**: Verify the configuration in `/etc/alloy/config.alloy` is correct.
- **Check logs**: Review Alloy logs for any connectivity or configuration issues.
  ```bash
  journalctl -u alloy.service
  ```

### GitLab
- **Check service status**: Confirm that GitLab is running.
  ```bash
  sudo gitlab-ctl status
  ```
- **Verify web interface**: Access GitLab web interface at `http://VM_IP` (get IP with `multipass list`).
- **Check GitLab configuration**: Review the GitLab configuration.
  ```bash
  sudo cat /etc/gitlab/gitlab.rb | grep -v '^#' | grep -v '^$'
  ```
- **GitLab environment info**: Get detailed GitLab version and environment information.
  ```bash
  sudo gitlab-rake gitlab:env:info
  ```
- **Check GitLab logs**: Review GitLab logs for any issues.
  ```bash
  sudo gitlab-ctl tail
  ```

### GitLab Metrics
- **Test metrics endpoint**: Verify metrics are being exposed on the `/-/metrics` endpoint.
  ```bash
  curl localhost/-/metrics
  ```
- **Check monitoring whitelist**: Ensure monitoring whitelist is configured properly.
  ```bash
  sudo grep monitoring_whitelist /etc/gitlab/gitlab.rb
  ```

## Troubleshooting

For debugging and troubleshooting, you can access the VM directly using:
```bash
make shell
```

Check which version of Gitlab is installed:
```bash
➜ make gitlab-version

System information
System:		Ubuntu 24.04
Current User:	git
Using RVM:	no
Ruby Version:	3.2.5
Gem Version:	3.6.9
Bundler Version:2.6.9
Rake Version:	13.0.6
Redis Version:	7.2.9
Sidekiq Version:7.3.9
Go Version:	unknown

GitLab information
Version:	18.1.2
Revision:	98bf90e2827
Directory:	/opt/gitlab/embedded/service/gitlab-rails
DB Adapter:	PostgreSQL
DB Version:	16.8
URL:		http://gitlab.example.com
HTTP Clone URL:	http://gitlab.example.com/some-group/some-project.git
SSH Clone URL:	git@gitlab.example.com:some-group/some-project.git
Using LDAP:	no
Using Omniauth:	yes
Omniauth Providers:

GitLab Shell
Version:	14.42.0
Repository storages:
- default: 	unix:/var/opt/gitlab/gitaly/gitaly.socket
GitLab Shell path:		/opt/gitlab/embedded/service/gitlab-shell

Gitaly
- default Address: 	unix:/var/opt/gitlab/gitaly/gitaly.socket
- default Version: 	18.1.2
- default Git Version: 	2.49.0.gl2
```



This opens a shell session to the running VM where you can execute the validation commands above and investigate any issues with the services.

Some known metrics that are not being generated by default and require further configuration:
- job_register_attempts_failed_total
- job_register_attempts_total
- pipelines_created_total

### Common issues

- **GitLab not starting**: Check if the VM has sufficient memory (8GB minimum required).
- **Metrics not available**: Ensure GitLab has fully initialized - this can take several minutes after installation.
- **Log access issues**: Verify that the `alloy` user has been added to the appropriate groups for log file access.

### Helper scripts

The sample app includes helper scripts located in `/home/ubuntu/`:
- `generate-error-log.sh`: Generates test exception logs for testing log collection.
- `reset-root-password.sh`: Resets the GitLab root user password if needed.
