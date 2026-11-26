package main

import (
	"os"
	"path/filepath"
	"slices"
	"testing"

	"github.com/joho/godotenv"
)

// newRepo builds a repository skeleton holding the given files, with paths
// relative to sample-apps/, and returns its root.
func newRepo(t *testing.T, files map[string]string) string {
	t.Helper()
	root := t.TempDir()
	for name, content := range files {
		path := filepath.Join(root, "sample-apps", name)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return root
}

func TestRepositoryConfigsParse(t *testing.T) {
	root := filepath.Join("..", "..", "..")
	parsed := 0
	for _, pattern := range []string{"sample-apps/*/tests/configs/*.config", "sample-apps/*/" + hardwareFile} {
		files, _ := filepath.Glob(filepath.Join(root, pattern))
		for _, file := range files {
			if _, err := godotenv.Read(file); err != nil {
				t.Errorf("%s: %v", file, err)
			}
			parsed++
		}
	}
	if parsed < 10 {
		t.Fatalf("only found %d config files; is the repository layout as expected?", parsed)
	}
}

func TestSampleAppsValidatesNames(t *testing.T) {
	root := newRepo(t, map[string]string{"one/Makefile": "", "two/Makefile": ""})

	apps, err := sampleApps(root, "one,two,")
	if err != nil || len(apps) != 2 || apps[0].name != "one" || apps[1].name != "two" {
		t.Errorf("sampleApps = %v, %v", apps, err)
	}
	for _, bad := range []string{"", ",", "missing", "../ops", "one/../two", ".."} {
		if _, err := sampleApps(root, bad); err == nil {
			t.Errorf("sampleApps(%q) succeeded", bad)
		}
	}
}

func TestMetricsFilesSkipsHiddenFiles(t *testing.T) {
	root := newRepo(t, map[string]string{
		"demo/tests/metrics/b":           "up\n",
		"demo/tests/metrics/a":           "up\n",
		"demo/tests/metrics/.DS_Store":   "\x00\x00",
		"demo/tests/metrics/nested/file": "up\n",
	})
	apps, err := sampleApps(root, "demo")
	if err != nil {
		t.Fatal(err)
	}
	var names []string
	for _, file := range apps[0].metricsFiles() {
		names = append(names, filepath.Base(file))
	}
	if want := []string{"a", "b"}; !slices.Equal(names, want) {
		t.Errorf("metricsFiles = %v, want %v", names, want)
	}
}

func TestCICheck(t *testing.T) {
	root := newRepo(t, map[string]string{
		"tested/tests/metrics/main":              "up\n",
		"bypassed/.CI_BYPASS":                    "",
		"bypassed-with-tests/.CI_BYPASS":         "",
		"bypassed-with-tests/tests/metrics/main": "up\n",
		"broken/Makefile":                        "",
		"hidden-only/tests/metrics/.DS_Store":    "",
	})
	tests := map[string]struct{ run, fails bool }{
		"tested":              {run: true},
		"bypassed":            {},
		"bypassed-with-tests": {},
		"broken":              {fails: true},
		"hidden-only":         {fails: true},
	}
	for name, want := range tests {
		apps, err := sampleApps(root, name)
		if err != nil {
			t.Fatal(err)
		}
		run, err := ciCheck(apps[0])
		if run != want.run || (err != nil) != want.fails {
			t.Errorf("%s: ciCheck = %t, %v; want run %t, failure %t", name, run, err, want.run, want.fails)
		}
	}
}

func TestNewVMs(t *testing.T) {
	before := map[string]bool{"dbs": true, "other": true}
	after := map[string]bool{"dbs": true, "other": true, "kafka-sample-app-k3s-worker-1": true, "kafka-sample-app-k3s-main": true}
	got := newVMs(before, after)
	want := []string{"kafka-sample-app-k3s-main", "kafka-sample-app-k3s-worker-1"}
	if !slices.Equal(got, want) {
		t.Errorf("newVMs = %v, want %v", got, want)
	}
}

func TestCurrentDNSServer(t *testing.T) {
	tests := map[string]struct {
		status, want string
		ok           bool
	}{
		"link":       {status: "Global\n       Protocols: -LLMNR\n\nLink 2 (enp0s1)\n    Current Scopes: DNS\nCurrent DNS Server: 192.168.64.1\n       DNS Servers: 192.168.64.1\n", want: "192.168.64.1", ok: true},
		"IPv6 first": {status: "Current DNS Server: fe80::1\nCurrent DNS Server: 10.0.0.1\n", want: "10.0.0.1", ok: true},
		"none":       {status: "Global\n       Protocols: -LLMNR\n"},
		"not an IP":  {status: "Current DNS Server: 192.168.64\n"},
	}
	for name, tt := range tests {
		got, ok := currentDNSServer(tt.status)
		if got != tt.want || ok != tt.ok {
			t.Errorf("%s: currentDNSServer = %q, %v, want %q, %v", name, got, ok, tt.want, tt.ok)
		}
	}
}
