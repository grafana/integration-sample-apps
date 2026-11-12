# SNMP sample app

This sample application creates an Ubuntu VM integrated with Alloy for metric and log collection. This sample app utilizes cloud-init and Make commands to facilitate the setup, configuration, and monitoring of SNMP using snmpd as well as snmpsim snapshots.

Alloy runs the SNMP integration's filtered advanced metrics snippet and its logs snippet, adapted from version 2.0.3 of the integration. Update `jinja/templates/cloud-init-template.yaml` when the snippets change. The device list and the authentication file are installed to `/etc/alloy/targets.yml` and `/etc/alloy/auths.yml`.

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
   cd integration-sample-apps/sample-apps/snmp
   ```

2. **Set up default config**: 
   Execute `make defaultconfig` to create a template file with default configuration variables. Modify `jinja/variables/cloud-init.yaml` to connect Alloy to an external Prometheus compatible TSDB and/or Loki server.

3. **Render cloud-init configuration**: 
   Run `make render-config` to generate the `cloud-init.yaml` file based on your configuration.

4. **Create and set up VMs**: 
   Use `make run` to start the SNMP sample app.

5. **Stop and clean Up**:
   Use `make stop` to clean up the VM and `make clean` to remove temporary files.

## Make commands

- `make defaultconfig`: Initializes the configuration file with default values for cloud-init templates.
- `make render-config`: Generates the `cloud-init.yaml` configuration file using the defined variables.
- `make run`: Creates the SNMP sample app.
- `make alert-test CMD="<command>"`: Changes simulated values so an SNMP alert fires. See [Testing alerts](#testing-alerts).
- `make stop`: Stops and deletes the VM.
- `make clean`: Removes the rendered configuration files.

## Default configuration variables

- `prom_pass`: Your Prometheus password.
- `prom_user`: Your Prometheus username.
- `prom_url`: URL for Prometheus push endpoint (e.g., `http://your-prometheus-instance:9090/api/v1/push`).
- `loki_url`: URL for Loki push endpoint (e.g., `http://your-loki-instance:3100/loki/api/v1/push`).
- `loki_user`: Your Loki username.
- `loki_pass`: Your Loki password.

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

## Add new snmpsim snapshots


### Capture SNMP snapshots

Option 1:  
Refer to snmpsim docs in order to find out how to capture data in snmpsim format: 
https://docs.lextudio.com/snmpsim/documentation/building-simulation-data#walking-snmp-agent

`snmpsim-record-commands --agent-udpv4-endpoint=192.168.1.1 \
  --start-oid=1.3.6.1.2.1 --stop-oid=1.3.6.1.2.1.5 \
  --output-file=snmpsim/data/recorded/linksys- \
  system.snmprec`

Option 2:  
You can also request dumps recorded by snmpwalk command:
`snmpwalk -v 2c -c  <SNMP community> -OfnetU  <IP address>   .1.3  > device1.snmpwalk`
If you receive an error that "counters not increasing" then you can try to add `-Сс`:
`snmpwalk -v 2c -Cc -c  <SNMP community> -OfnetU  <IP address>   .1.3 > device1.snmpwalk`

Then you can try to use it directly as a snapshot or convert it to more reliable format:
`datafile.py --input-file=device1.snmpwalk --source-record-type=snmpwalk --output-file=10.100.0.90.snmprec`

### Poll SNMP snapshots
File should be in *.snmprec or *.snmpwalk formats.

1. Name snapshot file as `<domain>.<vendor>.<devicename>.snmprec|snmpwalk`. example domains are: `net`,`os`,`server`,`ups`, `storage`.
1. Sanitize snapshots from sensitive data: 
It is recommended to at least change:
- 1.3.6.1.2.1.1.1 - sysDescr
- 1.3.6.1.2.1.1.4 - sysContact
- 1.3.6.1.2.1.1.5 - sysName
- 1.3.6.1.2.1.1.6 - sysLocation
- 1.3.6.1.2.1.31.1.1.1.18.* - ifAlias.
1. Put snapshot file into ./snmpsim/data dir.
1. Update targets.yml and auths.yml files.
1. Add a `./tests/metrics` list and a matching `./tests/configs` file to check the device in CI.

`./tests/metrics/integration` is the integration's `metric_names`, checked across every SNMP job. Update it when the integration's `metric_names` change.

## Simulated traffic

Traffic moves on `net.cisco.c2911`, `net.cisco.c7600`, `net.cisco.mds9148s`, `net.juniper.ex4200-24f` and the three MikroTik devices. Uptime moves on the same devices except `net.cisco.c2911`, whose uptime stays fixed so that the `reboot` test can set it. Each moving counter keeps the average rate of its recording and varies between polls. On `net.cisco.c7600`, the 10 busiest interfaces move. On `net.cisco.mds9148s`, the Fibre Channel credit counters move too.

A moving counter is a row like `1.3.6.1.2.1.31.1.1.1.6.1|70:numeric|cumulative=1,scale=0,rate=1,offset=675.769,deviation=8109`. `offset` is the average increase per second and `deviation` is the jitter added at each poll. See snmpsim's [numeric variation module](https://docs.lextudio.com/snmpsim/documentation/simulation-with-variation-modules#numeric-module).

`net.cisco.mds9148s` is hand-written, not a recording from a real switch.

`net.juniper.mx240` and `net.juniper.srx` are snmpwalk recordings. That format holds fixed values only, so their traffic stays flat.

## Testing alerts

`make alert-test` changes simulated values on demand. Run it from this directory:

```sh
make alert-test CMD="cpu-high"
```

| Command | Alert |
|---|---|
| `interface-down warning`, `interface-up warning` | `SNMPInterfaceDown`, warning |
| `interface-down critical`, `interface-up critical` | `SNMPInterfaceDown`, critical |
| `reboot` | `SNMPNodeHasRebooted` |
| `fru-fail`, `fru-on` | `SNMPFRUComponentProblem` |
| `cpu-high`, `cpu-normal` | `SNMPNodeCPUHighUsage` |
| `memory-high`, `memory-normal` | `SNMPNodeMemoryUtilization` |
| `errors [minutes]` | `SNMPInterfaceErrors` |
| `drops [minutes]` | `SNMPInterfaceDrops` |
| `fc-errors [minutes]` | `SNMPInterfaceFCerrors` |

`fru-fail` and `fru-on` act on `net.cisco.c7600`. `fc-errors` acts on `fc1/1` of `net.cisco.mds9148s`. The other commands act on `net.cisco.c2911`. Its uplink and critical interfaces are `Gi0/0` and `Gi0/0.114`. `errors` and `drops` keep adding to the uplink's counters for 20 and 35 minutes by default, past each alert's pending period. `fc-errors` adds to all three counters the `SNMPInterfaceFCerrors` rules read, for 20 minutes by default. `make alert-test` with no command lists them all.

## Testing syslog

Alloy and rsyslog are setup to receive logs.
To manually test it you can run the following from the sample app shell:

Cisco IOS, with origin: (to rsyslog):
```
echo  '485: net.cisco.c2911: *Feb 14 09:40:10.326: %LINEPROTO-2-UPDOWN: Line protocol on Interface GigabitEthernet0/1, changed state to up1' | nc -v -w0 -u localhost 10516
```

Syslog  (RFC3164):
```
echo '<34>Oct 11 22:14:15 net.juniper.srx su: 'su root' failed for user1 on /dev/pts/8' | nc -v -w0 -u localhost 10514
```

Syslog (RFC5424):

```
echo '<165>1 2003-10-11T22:14:15.003Z net.juniper.mx240 evntslog - ID47 [exampleSDID@32473 iut="3" eventSource="Application" eventID="1011"] application event log entry...' | nc -v -w0 -u localhost 10515
```

In Grafana, you should see logs messages enriched with `rack` and `datacenter` labels.

