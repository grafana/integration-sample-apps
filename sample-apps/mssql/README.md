# MSSQL Sample Application

This sample application sets up and monitors a Microsoft SQL Server instance using Grafana Alloy. The application runs in a containerized environment and includes automated setup using cloud-init.

## Overview

The sample application:
- Deploys a Microsoft SQL Server instance using Azure SQL Edge
- Configures Grafana Alloy to collect metrics and logs from the container
- Sets up appropriate monitoring permissions
- Automates the entire setup process using cloud-init
- Integrates with Grafana Cloud for metrics and logs

## Prerequisites

- [Multipass](https://multipass.run/) for VM management

## Configuration

1. Create a configuration file:
```bash
make defaultconfig
```

1. Edit `jinja/variables/cloud-init.yaml` with your credentials/configuration:
```yaml
loki_url: http://your-loki-instance:3100/loki/api/v1/push
loki_user: your_loki_username
loki_pass: your_loki_password
prom_url: http://your-prometheus-instance:9090/api/v1/push
prom_user: your_prometheus_username
prom_pass: your_prometheus_password
```

## Usage

### Running the Application

1. Launch the VM with the sample application:
```bash
make run
```

This command will:
- Create a new VM named `mssql-sample-app`
- Configure the VM using cloud-init
- Deploy MSSQL in a container
- Set up Grafana Alloy for monitoring

### Stopping the Application

To stop and clean up the VM:
```bash
make stop
```

### CI/CD Usage

For CI/CD environments, use:
```bash
make run-ci
```

This command will clean any existing configuration and start fresh.

## Security

The sample application includes:
- A monitoring user with appropriate permissions
- Secure password configuration
- Proper access controls for metrics collection

## Development

### Project Structure
```
mssql/
├── Makefile             # Build and deployment commands
├── README.md            # This file
└── jinja/
    ├── templates/       # Cloud-init templates
    └── variables/       # Configuration variables
```

### Available Make Commands

- `make run` - Launch the VM with the sample application
- `make run-ci` - Run in CI mode (cleans and starts fresh)
- `make stop` - Stop and delete the VM
- `make render-config` - Generate cloud-init configuration
- `make clean` - Clean up generated files
- `make defaultconfig` - Create default configuration

## Troubleshooting

If you encounter issues:

1. Check the VM status:
```bash
multipass info mssql-sample-app
```

2. View cloud-init logs:
```bash
multipass exec mssql-sample-app -- sudo cat /var/log/cloud-init-output.log
```

3. Check Alloy status:
```bash
multipass exec mssql-sample-app -- systemctl status alloy
```

4. Check MSSQL container is running:
```bash
multipass exec mssql-sample-app -- docker ps
```

5. Check MSSQL container logs:
```bash
multipass exec mssql-sample-app -- docker logs mssql-sample-app
```