package main

import (
	"os"
	"path/filepath"
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

func TestCICheck(t *testing.T) {
	root := newRepo(t, map[string]string{
		"tested/tests/metrics/main":              "up\n",
		"bypassed/.CI_BYPASS":                    "",
		"bypassed-with-tests/.CI_BYPASS":         "",
		"bypassed-with-tests/tests/metrics/main": "up\n",
		"broken/Makefile":                        "",
	})
	tests := map[string]struct{ run, fails bool }{
		"tested":              {run: true},
		"bypassed":            {},
		"bypassed-with-tests": {},
		"broken":              {fails: true},
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
