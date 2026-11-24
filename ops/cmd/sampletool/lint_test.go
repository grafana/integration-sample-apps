package main

import (
	"bytes"
	"encoding/json"
	"path/filepath"
	"strings"
	"testing"
)

const goodMakefile = `include ../Makefile

run-ci: clean defaultconfig launch-vm

defaultconfig:
	@mkdir -p jinja/variables
	@echo "loki_url: x" > jinja/variables/cloud-init.yaml
	@echo "prom_url: y" >> jinja/variables/cloud-init.yaml
`

// goodApp returns the files of an app that lint finds nothing wrong with.
func goodApp(name string) map[string]string {
	return map[string]string{
		name + "/README.md":                 "",
		name + "/Makefile":                  goodMakefile,
		name + "/tests/metrics/main":        "up\nmetric_one\n",
		name + "/tests/configs/main.config": "JOB_LABEL=integrations/demo\nMETRICS_SUCCESS_RATE_REQUIRED=0.9\n",
	}
}

func lintFindings(t *testing.T, files map[string]string) []finding {
	t.Helper()
	root := newRepo(t, files)
	apps, err := sampleApps(root, "demo")
	if err != nil {
		t.Fatal(err)
	}
	return lintApp(apps[0])
}

func TestLintPassesAGoodApp(t *testing.T) {
	if f := lintFindings(t, goodApp("demo")); len(f) != 0 {
		t.Errorf("findings = %v, want none", f)
	}
}

func TestLintFindsProblems(t *testing.T) {
	tests := map[string]struct {
		change map[string]string // files to add to or replace in a good app
		remove []string          // files to delete from it
		level  string
		want   string
	}{
		"no run-ci target": {
			change: map[string]string{"demo/Makefile": "include ../Makefile\n"},
			level:  "error", want: "no run-ci target",
		},
		"shared target without the shared Makefile": {
			change: map[string]string{"demo/Makefile": "run-ci: k3s-setup\n\t@true\n"},
			level:  "error", want: "uses k3s-setup from ../Makefile without including it",
		},
		"defaultconfig only appends": {
			change: map[string]string{"demo/Makefile": strings.Replace(goodMakefile, `" > jinja`, `" >> jinja`, 1)},
			level:  "warning", want: "defaultconfig only appends",
		},
		"hardcoded amd64": {
			change: map[string]string{"demo/scripts/install.sh": "curl -LO https://example.com/tool-linux-amd64.tar.gz\n"},
			level:  "warning", want: "hardcodes amd64",
		},
		"no tests and no bypass": {
			remove: []string{"demo/tests/metrics/main"},
			level:  "error", want: "no tests/metrics/ files and no .CI_BYPASS",
		},
		"bypass with tests": {
			change: map[string]string{"demo/.CI_BYPASS": ""},
			level:  "warning", want: "CI never runs",
		},
		"missing config": {
			remove: []string{"demo/tests/configs/main.config"},
			level:  "error", want: "has no tests/configs/main.config",
		},
		"missing JOB_LABEL": {
			change: map[string]string{"demo/tests/configs/main.config": "INSTANCE_FILTER=x\n"},
			level:  "error", want: "doesn't set JOB_LABEL",
		},
		"rate out of range": {
			change: map[string]string{"demo/tests/configs/main.config": "JOB_LABEL=x\nMETRICS_SUCCESS_RATE_REQUIRED=80\n"},
			level:  "error", want: "isn't a number from 0 to 1",
		},
		"ignored key": {
			change: map[string]string{"demo/tests/configs/main.config": "JOB_LABEL=x\nSAMPLE_APP_SETUP_TIME=300s\n"},
			level:  "warning", want: "sets SAMPLE_APP_SETUP_TIME, which 'apps test' ignores",
		},
		"empty metrics list": {
			change: map[string]string{"demo/tests/metrics/main": "\n\n"},
			level:  "error", want: "lists no metrics",
		},
		"invalid metric name": {
			change: map[string]string{"demo/tests/metrics/main": "up\nnot-a-metric\n"},
			level:  "error", want: "not-a-metric",
		},
		"duplicate metric": {
			change: map[string]string{"demo/tests/metrics/main": "up\nup\n"},
			level:  "warning", want: "more than once",
		},
		"recording rule output": {
			change: map[string]string{"demo/tests/metrics/main": "# from metric_names\nup\ninstance:up:sum\n"},
			level:  "warning", want: "recording rule outputs, which 'apps test' skips: instance:up:sum",
		},
		"only recording rule outputs": {
			change: map[string]string{"demo/tests/metrics/main": "instance:up:sum\n"},
			level:  "error", want: "lists no metrics, other than recording rule outputs",
		},
		"bad dashboards line": {
			change: map[string]string{"demo/tests/dashboards": "# fine\njsonnet-libs/demo-mixin\nhttp://insecure.example.com/d.json\n"},
			level:  "error", want: "line 3",
		},
	}
	for name, tt := range tests {
		t.Run(name, func(t *testing.T) {
			files := goodApp("demo")
			for path, content := range tt.change {
				files[path] = content
			}
			for _, path := range tt.remove {
				delete(files, path)
			}
			findings := lintFindings(t, files)
			for _, f := range findings {
				if f.Level == tt.level && strings.Contains(f.Message, tt.want) {
					return
				}
			}
			t.Errorf("findings = %v, want a %s mentioning %q", findings, tt.level, tt.want)
		})
	}
}

func TestLintSkipsCIChecksForWindowsAndBypassedApps(t *testing.T) {
	for _, files := range []map[string]string{
		{"windows/README.md": "", "windows/tests/metrics/main": "up\n", "windows/tests/configs/main.config": "JOB_LABEL=x\n",
			"windows/scripts/install.ps1": "amd64\n"},
		{"cloud/README.md": "", "cloud/.CI_BYPASS": ""},
	} {
		root := newRepo(t, files)
		apps, err := allApps(root)
		if err != nil || len(apps) != 1 {
			t.Fatalf("allApps = %v, %v", apps, err)
		}
		if f := lintApp(apps[0]); len(f) != 0 {
			t.Errorf("%s: findings = %v, want none", apps[0].name, f)
		}
	}
}

func TestAppsLintOutput(t *testing.T) {
	files := goodApp("demo")
	files["demo/tests/metrics/main"] = "up\nup\nbad-name\n"
	root := newRepo(t, files)
	apps, _ := sampleApps(root, "demo")

	var text bytes.Buffer
	if err := appsLint(&text, apps, false); err == nil || !strings.Contains(err.Error(), "1 errors") {
		t.Errorf("appsLint error = %v, want one counting 1 error", err)
	}
	if !strings.Contains(text.String(), "Checked 1 sample apps: 1 errors, 1 warnings.") {
		t.Errorf("text output:\n%s", text.String())
	}

	var out bytes.Buffer
	_ = appsLint(&out, apps, true)
	var report struct {
		AppsChecked int       `json:"apps_checked"`
		Errors      int       `json:"errors"`
		Warnings    int       `json:"warnings"`
		Findings    []finding `json:"findings"`
	}
	if err := json.Unmarshal(out.Bytes(), &report); err != nil {
		t.Fatal(err)
	}
	if report.AppsChecked != 1 || report.Errors != 1 || report.Warnings != 1 || len(report.Findings) != 2 || report.Findings[0].App != "demo" {
		t.Errorf("report = %+v", report)
	}

	out.Reset()
	if err := appsLint(&out, nil, true); err != nil || !strings.Contains(out.String(), `"findings": []`) {
		t.Errorf("empty report = %s, %v", out.String(), err)
	}
}

// The repository itself must lint without errors, as CI requires of changed apps.
func TestRepositoryLintsWithoutErrors(t *testing.T) {
	apps, err := allApps(filepath.Join("..", "..", ".."))
	if err != nil || len(apps) < 10 {
		t.Fatalf("allApps = %d apps, %v", len(apps), err)
	}
	for _, a := range apps {
		for _, f := range lintApp(a) {
			if f.Level == "error" {
				t.Errorf("%s: %s", f.App, f.Message)
			}
		}
	}
}
