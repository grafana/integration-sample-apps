variable "agent_config" {
  default = <<EOF
integrations:
  node_exporter:
    enabled: true
    relabel_configs:
      - replacement: hostname
        target_label: instance
  prometheus_remote_write:
    - basic_auth:
        password: var.prometheus_password
        username: var.prometheus_username
      url: var.prometheus_url
logs:
  configs:
    - name: integrations/openstack
      clients:
      - basic_auth:
          password: var.loki_password
          username: var.loki_username
        url: var.loki_url
      positions:
        filename: /tmp/positions.yaml
      target_config:
        sync_period: 10s
      scrape_configs:
        - job_name: integrations/openstack
          journal:
            max_age: 12h
            labels:
              job: integrations/openstack
              instance: openstack-sample-app:9180
          relabel_configs:
            - source_labels: ["__journal_systemd_unit"]
              target_label: "unit"
          pipeline_stages:
            - multiline:
                firstline: "(?P<level>(DEBUG|INFO|WARNING|ERROR)) "
            - regex:
                expression: '(?P<level>(DEBUG|INFO|WARNING|ERROR)) (?P<service>\w+)[\w|.]+ (\[.*] )(?P<message>.*)'
            - labels:
                level:
                service:
metrics:
  configs:
    - name: integrations/openstack
      remote_write:
        - basic_auth:
            password: var.prometheus_password
            username: var.prometheus_username
          url: var.prometheus_url
      scrape_configs:
        - job_name: integrations/openstack
          metrics_path: /metrics
          static_configs:
            - targets: ["localhost:9180"]
  global:
    scrape_interval: 60s
  wal_directory: /tmp/grafana-agent-wal
EOF
}
