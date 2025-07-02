# Create default Alloy configuration for Windows monitoring
param(
    [string]$LokiUrl = "http://localhost:3100/loki/api/v1/push",
    [string]$PrometheusUrl = "http://localhost:9009/api/v1/push",
    [string]$LokiUser = "",
    [string]$LokiPass = "",
    [string]$PrometheusUser = "",
    [string]$PrometheusPass = ""
)

$ErrorActionPreference = "Stop"

# Alloy configuration template
$configTemplate = @"
// Alloy configuration for Windows monitoring

// Prometheus remote write endpoint
prometheus.remote_write "metrics_service" {
  endpoint {
    url = "$PrometheusUrl"
"@

if ($PrometheusUser -and $PrometheusPass) {
    $configTemplate += @"

    basic_auth {
      username = "$PrometheusUser"
      password = "$PrometheusPass"
    }
"@
}

$configTemplate += @"
  }
}

// Loki endpoint for logs
loki.write "logs_service" {
  endpoint {
    url = "$LokiUrl"
"@

if ($LokiUser -and $LokiPass) {
    $configTemplate += @"

    basic_auth {
      username = "$LokiUser"
      password = "$LokiPass"
    }
"@
}

$configTemplate += @"
  }
}

// Windows exporter for system metrics
prometheus.exporter.windows "windows_metrics" {
  enabled_collectors = ["cpu", "cs", "logical_disk", "memory", "net", "os", "service", "system"]
}

// Scrape Windows metrics
prometheus.scrape "windows_scrape" {
  targets    = prometheus.exporter.windows.windows_metrics.targets
  forward_to = [prometheus.relabel.windows_relabel.receiver]
  scrape_interval = "15s"
}

// Relabel Windows metrics with proper job label
prometheus.relabel "windows_relabel" {
  forward_to = [prometheus.remote_write.metrics_service.receiver]
  
  rule {
    target_label = "job"
    replacement  = "integrations/windows_exporter"
  }
  
  rule {
    target_label = "instance"
    replacement  = env("COMPUTERNAME")
  }
}

// Self monitoring for Alloy
prometheus.exporter.self "alloy_metrics" {}

prometheus.scrape "alloy_scrape" {
  targets    = prometheus.exporter.self.alloy_metrics.targets
  forward_to = [prometheus.relabel.alloy_relabel.receiver]
  scrape_interval = "60s"
}

prometheus.relabel "alloy_relabel" {
  forward_to = [prometheus.remote_write.metrics_service.receiver]
  
  rule {
    target_label = "job"
    replacement  = "integrations/alloy-check"
  }
  
  rule {
    target_label = "instance"
    replacement  = env("COMPUTERNAME")
  }
  
  rule {
    source_labels = ["__name__"]
    regex         = "(alloy_build_info|prometheus_target_sync_length_seconds_sum|prometheus_target_scrapes_.*|prometheus_target_interval.*|prometheus_sd_discovered_targets|prometheus_remote_write_wal_samples_appended_total|process_start_time_seconds)"
    action        = "keep"
  }
}

// Windows Event Log collection
loki.source.windowsevent "system_events" {
  locale                   = 1033
  eventlog_name            = "System"
  bookmark_path            = "./bookmarks-system.xml"
  forward_to               = [loki.relabel.windows_logs.receiver]
}

loki.source.windowsevent "application_events" {
  locale                   = 1033
  eventlog_name            = "Application"
  bookmark_path            = "./bookmarks-application.xml"
  forward_to               = [loki.relabel.windows_logs.receiver]
}

loki.source.windowsevent "security_events" {
  locale                   = 1033
  eventlog_name            = "Security"
  bookmark_path            = "./bookmarks-security.xml"
  forward_to               = [loki.relabel.windows_logs.receiver]
  xpath_query              = "*[System[(Level=1 or Level=2 or Level=3)]]"
}

// Relabel logs with proper job and instance labels
loki.relabel "windows_logs" {
  forward_to = [loki.write.logs_service.receiver]
  
  rule {
    target_label = "job"
    replacement  = "integrations/windows_exporter"
  }
  
  rule {
    target_label = "instance"
    replacement  = env("COMPUTERNAME")
  }
  
  rule {
    source_labels = ["computer"]
    target_label  = "agent_hostname"
  }
}
"@

# Write configuration to file
$configPath = "config\alloy-config.alloy"
$configTemplate | Out-File -FilePath $configPath -Encoding UTF8

Write-Host "Created Alloy configuration at: $configPath"
Write-Host "Configuration includes:"
Write-Host "  - Windows system metrics collection"
Write-Host "  - Windows Event Log collection (System, Application, Security)"
Write-Host "  - Alloy self-monitoring"
Write-Host "  - Prometheus endpoint: $PrometheusUrl"
Write-Host "  - Loki endpoint: $LokiUrl" 