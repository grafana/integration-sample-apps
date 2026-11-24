package main

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// fakeMimir returns a series for the queries listed in present. It returns
// its host:port and records the queries it was asked.
func fakeMimir(t *testing.T, present ...string) (string, *[]string) {
	t.Helper()
	var queries []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/prometheus/api/v1/query" {
			http.NotFound(w, r)
			return
		}
		query := r.URL.Query().Get("query")
		queries = append(queries, query)
		result := ""
		for _, p := range present {
			if p == query {
				result = `{"metric":{"job":"integrations/demo","instance":"host-1"},"value":[1,"1"]}`
			}
		}
		w.Write([]byte(`{"status":"success","data":{"resultType":"vector","result":[` + result + `]}}`))
	}))
	t.Cleanup(server.Close)
	return strings.TrimPrefix(server.URL, "http://"), &queries
}

func TestSuccessRate(t *testing.T) {
	const job = "JOB_LABEL=integrations/demo"
	tests := []struct {
		name    string
		config  string
		found   []string // of the metrics a, b, c, d, e
		wantErr string   // empty for a pass
	}{
		{"all present", job, []string{"a", "b", "c", "d", "e"}, ""},
		{"exactly at the default rate", job, []string{"a", "b", "c", "d"}, ""},
		{"below the default rate", job, []string{"a", "b", "c"}, "3 of 5 expected metrics present, 0.8 required"},
		{"none present", job, nil, "0 of 5 expected metrics present"},
		{"lower rate from the config", job + "\nMETRICS_SUCCESS_RATE_REQUIRED=0.6", []string{"a", "b", "c"}, ""},
		{"stricter rate from the config", job + "\nMETRICS_SUCCESS_RATE_REQUIRED=1.0", []string{"a", "b", "c", "d"}, "4 of 5 expected metrics present, 1 required"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// The blank line and the trailing tab must not count as metrics.
			root := newRepo(t, map[string]string{
				"demo/tests/metrics/main":        "a\nb\t\n\nc\nd\ne",
				"demo/tests/configs/main.config": tt.config,
			})
			var present []string
			for _, metric := range tt.found {
				present = append(present, metric+`{job=~"integrations/demo"}`)
			}
			mimir, queries := fakeMimir(t, present...)
			apps, _ := sampleApps(root, "demo")

			err := appsTest(context.Background(), apps, "", "", mimir, "")
			if tt.wantErr == "" && err != nil || tt.wantErr != "" && (err == nil || !strings.Contains(err.Error(), tt.wantErr)) {
				t.Errorf("err = %v, want %q", err, tt.wantErr)
			}
			if len(*queries) != 5 {
				t.Errorf("ran %d queries, want 5: %v", len(*queries), *queries)
			}
		})
	}
}

func TestInstanceFilterChecksEachInstance(t *testing.T) {
	root := newRepo(t, map[string]string{
		"demo/tests/metrics/main":        "up\n",
		"demo/tests/configs/main.config": "JOB_LABEL=integrations/demo\nINSTANCE_FILTER=\".*-alloy.* .*-otelcol.*\"\n",
	})
	mimir, _ := fakeMimir(t, `up{job=~"integrations/demo",instance=~".*-alloy.*"}`)
	apps, _ := sampleApps(root, "demo")

	err := appsTest(context.Background(), apps, "", "", mimir, "")
	if err == nil || !strings.Contains(err.Error(), "on instance '.*-otelcol.*'") || strings.Contains(err.Error(), "alloy") {
		t.Errorf("want a failure for the otelcol instance only, got: %v", err)
	}
}

func TestBrokenTestCasesFail(t *testing.T) {
	tests := map[string]struct {
		files   map[string]string
		mimir   string // empty for a working fake
		wantErr string
	}{
		"missing JOB_LABEL": {
			files:   map[string]string{"demo/tests/metrics/main": "up\n", "demo/tests/configs/main.config": "# nothing set\n"},
			wantErr: "demo: main: JOB_LABEL not set",
		},
		"missing config file": {
			files:   map[string]string{"demo/tests/metrics/main": "up\n"},
			wantErr: "main.config",
		},
		"empty metrics list": {
			files:   map[string]string{"demo/tests/metrics/main": "\n", "demo/tests/configs/main.config": "JOB_LABEL=x\n"},
			wantErr: "no metrics listed",
		},
		"only recording rule outputs": {
			files:   map[string]string{"demo/tests/metrics/main": "instance:up:sum\n", "demo/tests/configs/main.config": "JOB_LABEL=x\n"},
			wantErr: "no metrics listed, other than recording rule outputs",
		},
		"no expected metrics": {
			files:   map[string]string{"demo/Makefile": ""},
			wantErr: "no expected metrics files",
		},
		"unreachable Mimir": {
			files:   map[string]string{"demo/tests/metrics/main": "up\n", "demo/tests/configs/main.config": "JOB_LABEL=x\n"},
			mimir:   "127.0.0.1:1",
			wantErr: "127.0.0.1:1",
		},
	}
	for name, tt := range tests {
		t.Run(name, func(t *testing.T) {
			root := newRepo(t, tt.files)
			apps, _ := sampleApps(root, "demo")
			if tt.mimir == "" {
				tt.mimir, _ = fakeMimir(t)
			}
			err := appsTest(context.Background(), apps, "", "", tt.mimir, "")
			if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
				t.Errorf("err = %v, want one mentioning %q", err, tt.wantErr)
			}
		})
	}
}

// An integration's metric_names has comments and recording rule outputs,
// neither of which is queried.
func TestCommentsAndRuleOutputsAreNotQueried(t *testing.T) {
	root := newRepo(t, map[string]string{
		"demo/tests/metrics/main":        "# Generated\nup # the target\ninstance:up:sum\n:tensorflow:serving:request_count\n",
		"demo/tests/configs/main.config": "JOB_LABEL=integrations/demo\nMETRICS_SUCCESS_RATE_REQUIRED=1\n",
	})
	mimir, queries := fakeMimir(t, `up{job=~"integrations/demo"}`, `:tensorflow:serving:request_count{job=~"integrations/demo"}`)
	apps, _ := sampleApps(root, "demo")

	if err := appsTest(context.Background(), apps, "", "", mimir, ""); err != nil {
		t.Errorf("err = %v, want a pass", err)
	}
	if want := []string{`up{job=~"integrations/demo"}`, `:tensorflow:serving:request_count{job=~"integrations/demo"}`}; !slices.Equal(*queries, want) {
		t.Errorf("queries = %v, want %v", *queries, want)
	}
}

func TestListOverrides(t *testing.T) {
	const config = "JOB_LABEL=integrations/demo\nMETRICS_SUCCESS_RATE_REQUIRED=1\n"
	tests := map[string]struct {
		app       map[string]string // files below sample-apps/
		overrides map[string]string // files below the overrides directory
		want      []string          // the metrics queried, in order
		wantErr   string
	}{
		"no override for the app": {
			app:       map[string]string{"demo/tests/metrics/main": "up\n", "demo/tests/configs/main.config": config},
			overrides: map[string]string{"other": "nope\n"},
			want:      []string{"up"},
		},
		"the only scenario": {
			app:       map[string]string{"demo/tests/metrics/main": "up\n", "demo/tests/configs/main.config": config},
			overrides: map[string]string{"demo": "new_metric\n"},
			want:      []string{"new_metric"},
		},
		"the integration scenario of several": {
			app: map[string]string{
				"demo/tests/metrics/integration": "up\n", "demo/tests/configs/integration.config": config,
				"demo/tests/metrics/extra": "extra_metric\n", "demo/tests/configs/extra.config": config,
			},
			overrides: map[string]string{"demo": "new_metric\n"},
			want:      []string{"extra_metric", "new_metric"},
		},
		"a named scenario": {
			app: map[string]string{
				"demo/tests/metrics/one": "up\n", "demo/tests/configs/one.config": config,
				"demo/tests/metrics/two": "up\n", "demo/tests/configs/two.config": config,
			},
			overrides: map[string]string{"demo/two": "new_metric\n"},
			want:      []string{"up", "new_metric"},
		},
		"several scenarios, none named integration": {
			app: map[string]string{
				"demo/tests/metrics/one": "up\n", "demo/tests/configs/one.config": config,
				"demo/tests/metrics/two": "up\n", "demo/tests/configs/two.config": config,
			},
			overrides: map[string]string{"demo": "new_metric\n"},
			wantErr:   "doesn't say which of its 2 scenarios it replaces",
		},
		"a scenario the app doesn't have": {
			app:       map[string]string{"demo/tests/metrics/main": "up\n", "demo/tests/configs/main.config": config},
			overrides: map[string]string{"demo/missing": "new_metric\n"},
			wantErr:   "replaces tests/metrics/missing, which doesn't exist",
		},
	}
	for name, tt := range tests {
		t.Run(name, func(t *testing.T) {
			root := newRepo(t, tt.app)
			overrides := t.TempDir()
			for name, content := range tt.overrides {
				path := filepath.Join(overrides, name)
				if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
					t.Fatal(err)
				}
			}
			var present []string
			for _, metric := range []string{"up", "new_metric", "extra_metric"} {
				present = append(present, metric+`{job=~"integrations/demo"}`)
			}
			mimir, queries := fakeMimir(t, present...)
			apps, _ := sampleApps(root, "demo")

			err := appsTest(context.Background(), apps, "", "", mimir, overrides)
			if tt.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
					t.Errorf("err = %v, want one mentioning %q", err, tt.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatalf("err = %v, want a pass", err)
			}
			var got []string
			for _, q := range *queries {
				got = append(got, strings.TrimSuffix(q, `{job=~"integrations/demo"}`))
			}
			if !slices.Equal(got, tt.want) {
				t.Errorf("queried %v, want %v", got, tt.want)
			}
		})
	}
}

// The k3d environment is reached as mimir.k3d.localhost, which not every
// system resolver knows.
func TestLocalhostNamesReachLoopback(t *testing.T) {
	query := `up{job=~"x"}`
	mimir, _ := fakeMimir(t, query)
	_, port, err := net.SplitHostPort(mimir)
	if err != nil {
		t.Fatal(err)
	}
	if found, err := seriesExist(context.Background(), "mimir.k3d.localhost:"+port, query); !found || err != nil {
		t.Errorf("seriesExist via mimir.k3d.localhost = %t, %v; want true", found, err)
	}
}
