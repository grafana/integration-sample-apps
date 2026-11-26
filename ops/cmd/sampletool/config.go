package main

import "time"

// The repository's layout. Paths are relative to its root, or to a sample app's
// directory for those under tests/.
const (
	sampleAppsDir = "sample-apps"
	metricsDir    = "tests/metrics" // an expected-metrics list per scenario
	configsDir    = "tests/configs" // <scenario>.config for each list
	ciBypassFile  = ".CI_BYPASS"
	hardwareFile  = ".hardware_requirements"
	dbsFilesDir   = "ops/qa/dbs" // copied to the databases VM
	k3sCloudInit  = "ops/qa/k3s-main-cloud-init.yaml"
)

// Flag defaults.
const (
	defaultDBsName = "dbs"
	defaultEnv     = "local"
)

// DBs. The ports must match ops/qa/dbs/docker-compose.yaml.
const (
	mimirPort    = "9009"
	lokiPort     = "3100"
	queryPath    = "/prometheus/api/v1/query"
	queryTimeout = 30 * time.Second

	// The DBs VM's compose files in dbsFilesDir.
	dbsCompose     = "docker-compose.yaml"
	grafanaCompose = "docker-compose.grafana.yaml"

	// ENV=k3d's stack which runs on the host.
	k3dMimirHost = "mimir.k3d.localhost"
	k3dLokiHost  = "loki.k3d.localhost"
	k3dPort      = "9999"
)

// Test config
const (
	// How long sample apps get to produce metrics
	setupTime = 180 * time.Second
	// Unless a given scenario's config sets METRICS_SUCCESS_RATE_REQUIRED this is the default
	defaultSuccessRate = 0.8
)

// The VMs and their installations
const (
	ubuntuRelease    = "24.04"
	dockerCloudInit  = "https://raw.githubusercontent.com/canonical/multipass/refs/tags/v1.17.2/data/cloud-init-yaml/cloud-init-docker.yaml"
	k3sInstallScript = "https://get.k3s.io"

	// k3s's defaults
	k3sAPIPort   = "6443"
	k3sTokenFile = "/var/lib/rancher/k3s/server/node-token"

	// The DBs VM's size.
	dbsCPUs   = "2"
	dbsMemory = "4G"
	dbsDisk   = "40G"
	// Where dbsFilesDir is copied to on the DBs VM, and where docker-compose runs.
	dbsHome = "/home/ubuntu"
)

// k3s VM sizes (in cores and gigabytes) unless hardwareFile overrides them.
var k3sHardware = map[string]string{
	"PRIMARY_CPU": "4", "PRIMARY_MEMORY": "6", "PRIMARY_DISK": "20",
	"WORKER_CPU": "2", "WORKER_MEMORY": "6", "WORKER_DISK": "20",
}
