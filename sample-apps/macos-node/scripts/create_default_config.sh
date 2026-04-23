#!/usr/bin/env bash
set -euo pipefail

LOKI_URL="http://localhost:3100/loki/api/v1/push"
PROMETHEUS_URL="http://localhost:9009/api/v1/push"
LOKI_USER=""
LOKI_PASS=""
PROM_USER=""
PROM_PASS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --loki-url)         LOKI_URL="$2"; shift 2 ;;
    --prometheus-url)   PROMETHEUS_URL="$2"; shift 2 ;;
    --loki-user)        LOKI_USER="$2"; shift 2 ;;
    --loki-pass)        LOKI_PASS="$2"; shift 2 ;;
    --prom-user)        PROM_USER="$2"; shift 2 ;;
    --prom-pass)        PROM_PASS="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

: "${LOKI_USER:=}"
: "${LOKI_PASS:=}"
: "${PROM_USER:=}"
: "${PROM_PASS:=}"

CONFIG_DIR="$(cd "$(dirname "$0")/.." && pwd)/config"
CONFIG_PATH="${CONFIG_DIR}/alloy-config.alloy"

mkdir -p "${CONFIG_DIR}"

PROM_BASIC_AUTH=""
if [[ -n "${PROM_USER}" && -n "${PROM_PASS}" ]]; then
  PROM_BASIC_AUTH=$(cat <<EOF
    basic_auth {
      username = "${PROM_USER}"
      password = "${PROM_PASS}"
    }
EOF
  )
fi

LOKI_BASIC_AUTH=""
if [[ -n "${LOKI_USER}" && -n "${LOKI_PASS}" ]]; then
  LOKI_BASIC_AUTH=$(cat <<EOF
    basic_auth {
      username = "${LOKI_USER}"
      password = "${LOKI_PASS}"
    }
EOF
  )
fi

cat > "${CONFIG_PATH}" <<EOF
prometheus.exporter.self "alloy_check" { }

discovery.relabel "alloy_check" {
  targets = prometheus.exporter.self.alloy_check.targets

  rule {
    target_label = "instance"
    replacement  = constants.hostname
  }

  rule {
    target_label = "alloy_hostname"
    replacement  = constants.hostname
  }

  rule {
    target_label = "job"
    replacement  = "integrations/alloy-check"
  }
}

prometheus.scrape "alloy_check" {
  targets    = discovery.relabel.alloy_check.output
  forward_to = [prometheus.relabel.alloy_check.receiver]

  scrape_interval = "60s"
}

prometheus.relabel "alloy_check" {
  forward_to = [prometheus.remote_write.metrics_service.receiver]

  rule {
    source_labels = ["__name__"]
    regex         = "(prometheus_target_sync_length_seconds_sum|prometheus_target_scrapes_.*|prometheus_target_interval.*|prometheus_sd_discovered_targets|alloy_build.*|prometheus_remote_write_wal_samples_appended_total|process_start_time_seconds)"
    action        = "keep"
  }
}

prometheus.remote_write "metrics_service" {
  endpoint {
    url = "${PROMETHEUS_URL}"
${PROM_BASIC_AUTH}
  }
}

loki.write "grafana_cloud_loki" {
  endpoint {
    url = "${LOKI_URL}"
${LOKI_BASIC_AUTH}
  }
}
discovery.relabel "integrations_node_exporter" {
  targets = prometheus.exporter.unix.integrations_node_exporter.targets

  rule {
    target_label = "instance"
    replacement  = constants.hostname
  }

  rule {
    target_label = "job"
    replacement = "integrations/node_exporter"
  }
}

prometheus.exporter.unix "integrations_node_exporter" { }

discovery.relabel "integrations_node_exporter" {
	targets = prometheus.exporter.unix.integrations_node_exporter.targets

	rule {
		target_label = "instance"
		replacement  = constants.hostname
	}

	rule {
		target_label = "job"
		replacement  = "integrations/macos-node"
	}
}

prometheus.scrape "integrations_node_exporter" {
	targets    = discovery.relabel.integrations_node_exporter.output
	forward_to = [prometheus.relabel.integrations_node_exporter.receiver]
	job_name   = "integrations/node_exporter"
}

prometheus.relabel "integrations_node_exporter" {
	forward_to = [prometheus.remote_write.metrics_service.receiver]

	rule {
		source_labels = ["__name__"]
		regex         = "up|node_boot_time_seconds|node_cpu_seconds_total|node_disk_io_time_seconds_total|node_disk_read_bytes_total|node_disk_written_bytes_total|node_filesystem_avail_bytes|node_filesystem_files|node_filesystem_files_free|node_filesystem_readonly|node_filesystem_size_bytes|node_load1|node_load15|node_load5|node_memory_compressed_bytes|node_memory_internal_bytes|node_memory_purgeable_bytes|node_memory_swap_total_bytes|node_memory_swap_used_bytes|node_memory_total_bytes|node_memory_wired_bytes|node_network_receive_bytes_total|node_network_receive_drop_total|node_network_receive_errs_total|node_network_receive_packets_total|node_network_transmit_bytes_total|node_network_transmit_drop_total|node_network_transmit_errs_total|node_network_transmit_packets_total|node_os_info|node_textfile_scrape_error|node_uname_info"
		action        = "keep"
	}
}

local.file_match "logs_integrations_integrations_node_exporter_direct_scrape" {
	path_targets = [{
		__address__ = "localhost",
		__path__    = "/var/log/*.log",
		instance    = constants.hostname,
		job         = "integrations/macos-node",
	}]
}

loki.process "logs_integrations_integrations_node_exporter_direct_scrape" {
	forward_to = [loki.write.grafana_cloud_loki.receiver]

	stage.multiline {
		firstline     = "^([\\w]{3} )?[\\w]{3} +[\\d]+ [\\d]+:[\\d]+:[\\d]+|[\\w]{4}-[\\w]{2}-[\\w]{2} [\\w]{2}:[\\w]{2}:[\\w]{2}(?:[+-][\\w]{2})?"
		max_lines     = 0
		max_wait_time = "10s"
	}

	stage.regex {
		expression = "(?P<timestamp>([\\w]{3} )?[\\w]{3} +[\\d]+ [\\d]+:[\\d]+:[\\d]+|[\\w]{4}-[\\w]{2}-[\\w]{2} [\\w]{2}:[\\w]{2}:[\\w]{2}(?:[+-][\\w]{2})?) (?P<hostname>\\S+) (?P<sender>.+?)\\[(?P<pid>\\d+)\\]:? (?P<message>(?s:.*))$"
	}

	stage.labels {
		values = {
			hostname = null,
			pid      = null,
			sender   = null,
		}
	}

	stage.match {
		selector = "{sender!=\"\", pid!=\"\"}"

		stage.template {
			source   = "message"
			template = "{{ .sender }}[{{ .pid }}]: {{ .message }}"
		}

		stage.label_drop {
			values = ["pid"]
		}

		stage.output {
			source = "message"
		}
	}
}

loki.source.file "logs_integrations_integrations_node_exporter_direct_scrape" {
	targets    = local.file_match.logs_integrations_integrations_node_exporter_direct_scrape.targets
	forward_to = [loki.process.logs_integrations_integrations_node_exporter_direct_scrape.receiver]
}
EOF

echo "Created Alloy configuration at: ${CONFIG_PATH}"
echo "  - Prometheus endpoint: ${PROMETHEUS_URL}"
echo "  - Loki endpoint:       ${LOKI_URL}"
