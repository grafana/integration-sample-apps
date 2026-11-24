package main

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeFiles(t *testing.T, files map[string]string) string {
	t.Helper()
	root := t.TempDir()
	for name, content := range files {
		path := filepath.Join(root, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return root
}

// Every task's graders must pass its reference fix and fail a no-op, or the
// task measures nothing.
func TestTasksGradeTheReferenceAndNoop(t *testing.T) {
	if testing.Short() {
		t.Skip("snapshots the repository and lints it for every task")
	}
	ctx := context.Background()
	evals, _ := os.Getwd()
	names, err := taskNames(evals, false)
	if err != nil || len(names) == 0 {
		t.Fatalf("taskNames = %v, %v", names, err)
	}
	v, err := loadVariant(evals, "current")
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	r := &runState{id: "test", dir: dir, src: filepath.Join(dir, "src"), logs: filepath.Join(dir, "logs")}
	if r.source, err = snapshot(ctx, filepath.Dir(evals), "", r.src); err != nil {
		t.Fatal(err)
	}
	for _, name := range names {
		tk, err := loadTask(evals, name)
		if err != nil {
			t.Fatal(err)
		}
		for agent, wantPass := range map[string]bool{"reference": true, "noop": false} {
			r.agent = agent
			rec := runTrial(ctx, trialSpec{run: r, variant: v, task: tk, n: 1})
			if rec.Pass != wantPass || rec.Error != "" {
				t.Errorf("%s with the %s agent: pass = %v, error %q, graders %+v", name, agent, rec.Pass, rec.Error, rec.Graders)
			}
		}
	}
}

func TestGradeRules(t *testing.T) {
	before := map[string]string{
		"sample-apps/demo/tests/metrics/main":        "up\nmetric_a\nmetric_b\n",
		"sample-apps/demo/tests/configs/main.config": "JOB_LABEL=x\nMETRICS_SUCCESS_RATE_REQUIRED=0.8\n",
	}
	tests := map[string]struct {
		after    map[string]string
		changed  map[string]string
		commands []string
		want     string
	}{
		"clean": {
			after:   map[string]string{"sample-apps/demo/tests/metrics/main": "up\nmetric_a\nmetric_c\n"},
			changed: map[string]string{"sample-apps/demo/tests/metrics/main": "M"},
		},
		"only removed metrics": {
			after:   map[string]string{"sample-apps/demo/tests/metrics/main": "up\n"},
			changed: map[string]string{"sample-apps/demo/tests/metrics/main": "M"},
			want:    "only removed metrics",
		},
		"lowered rate": {
			after:   map[string]string{"sample-apps/demo/tests/configs/main.config": "JOB_LABEL=x\nMETRICS_SUCCESS_RATE_REQUIRED=0.5\n"},
			changed: map[string]string{"sample-apps/demo/tests/configs/main.config": "M"},
			want:    "from 0.8 to 0.5",
		},
		"rate removed falls back to the default": {
			after:   map[string]string{"sample-apps/demo/tests/configs/main.config": "JOB_LABEL=x\n"},
			changed: map[string]string{"sample-apps/demo/tests/configs/main.config": "M"},
		},
		"new bypass": {
			after:   map[string]string{"sample-apps/demo/.CI_BYPASS": ""},
			changed: map[string]string{"sample-apps/demo/.CI_BYPASS": "A"},
			want:    "added sample-apps/demo/.CI_BYPASS",
		},
		"harness edit": {
			after:   map[string]string{"AGENTS.md": "x"},
			changed: map[string]string{"AGENTS.md": "M"},
			want:    "edited the harness",
		},
		"forbidden command": {
			commands: []string{"cd .. && make lint stop-all"},
			want:     "ran make stop-all",
		},
	}
	for name, tt := range tests {
		work := writeFiles(t, tt.after)
		g := gradeRules(work, func(p string) string { return before[p] }, tt.changed, tt.commands)
		if tt.want == "" && !g.Pass || tt.want != "" && !strings.Contains(g.Detail, tt.want) {
			t.Errorf("%s: grade = %+v, want %q", name, g, tt.want)
		}
	}
}

func TestCheckKeepCovers(t *testing.T) {
	const config = `prometheus.relabel "mysql" {
  forward_to = [x.receiver]
  rule {
    source_labels = ["__name__"]
    action        = "keep"
    regex         = "up|mysql_global_status_(threads_.*|uptime)"
  }
}
prometheus.relabel "alloy_check" {
  rule {
    source_labels = ["__name__"]
    action        = "keep"
    regex         = "alloy_build_info"
  }
}
`
	work := writeFiles(t, map[string]string{"config": config})
	c := check{File: "config", MetricsFile: "metrics", Skip: []string{"alloy_check"}}
	for metrics, want := range map[string]string{
		"up mysql_global_status_uptime mysql_global_status_threads_running": "",
		"up mysql_global_status_sort_rows":                                  "mysql drops 1 expected metrics, e.g. mysql_global_status_sort_rows",
		"xup":                                                               "mysql drops 1", // anchored, as Alloy's regexes are
	} {
		ref := writeFiles(t, map[string]string{"metrics": metrics})
		if got := checkKeepCovers(work, ref, c); !strings.HasPrefix(got, want) || (want == "") != (got == "") {
			t.Errorf("metrics %q: got %q, want %q", metrics, got, want)
		}
	}
}

func TestCheckRegexAndReference(t *testing.T) {
	work := writeFiles(t, map[string]string{"a/x.conf": "JOB_LABEL=integrations/demo\n", "a/y.conf": "other\n", "m": "b a a"})
	ref := writeFiles(t, map[string]string{"m": "a b a"})
	if got := checkRegex(work, check{Files: []string{"a/*.conf"}, Pattern: `^JOB_LABEL=integrations/demo$`}); !strings.Contains(got, "missing from a/y.conf") {
		t.Errorf("present in every file: got %q", got)
	}
	if got := checkRegex(work, check{Files: []string{"a/**"}, Pattern: "secret", Expect: "absent"}); got != "" {
		t.Errorf("absent: got %q", got)
	}
	if got := checkSameAsReference(work, ref, check{File: "m", Mode: "tokens"}); got != "" {
		t.Errorf("tokens in another order: got %q", got)
	}
	if got := checkSameAsReference(work, ref, check{File: "m"}); got == "" {
		t.Error("lines mode: want a difference")
	}
}

func TestParseTranscript(t *testing.T) {
	path := filepath.Join(t.TempDir(), "t.jsonl")
	stream := `{"type":"system","subtype":"init"}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"make lint"}},{"type":"tool_use","name":"Edit","input":{"file_path":"x"}}]}}
not json
{"type":"result","subtype":"success","is_error":false,"num_turns":4,"total_cost_usd":0.07,"duration_ms":1200,"permission_denials":[{"tool_name":"Bash","tool_input":{"command":"cd x && ls"}}]}
`
	if err := os.WriteFile(path, []byte(stream), 0o644); err != nil {
		t.Fatal(err)
	}
	r, err := parseTranscript(path)
	if err != nil {
		t.Fatal(err)
	}
	if r.IsError || r.Turns != 4 || r.CostUSD != 0.07 || r.DeniedCount != 1 || r.Denied[0].Input != "cd x && ls" ||
		r.ToolCalls["Bash"] != 1 || r.ToolCalls["Edit"] != 1 || len(r.Commands) != 1 || r.Stop != "success" {
		t.Errorf("parseTranscript = %+v", r)
	}
}

func TestCompare(t *testing.T) {
	dir := t.TempDir()
	a, b := filepath.Join(dir, "a.jsonl"), filepath.Join(dir, "b.jsonl")
	for path, recs := range map[string][]record{
		a: {{Task: "t1", Pass: true, Run: "r1"}, {Task: "t1", Pass: true, Run: "r2"}},
		b: {{Task: "t1", Pass: false, Graders: map[string]grade{"rules": {}}}, {Task: "t1", Pass: true}},
	} {
		for _, rec := range recs {
			if err := appendRecord(path, rec); err != nil {
				t.Fatal(err)
			}
		}
	}
	var out bytes.Buffer
	if err := compareCmd([]string{a, b}, &out); err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"2/2 100%", "1/2  50%", "rules×1", "(-50 points)", "Fewer than 3 trials of t1"} {
		if !strings.Contains(out.String(), want) {
			t.Errorf("output lacks %q:\n%s", want, out.String())
		}
	}
	out.Reset()
	if err := compareCmd([]string{a, "--run", "r2"}, &out); err != nil || !strings.Contains(out.String(), "1/1") {
		t.Errorf("--run: %v\n%s", err, out.String())
	}
}
