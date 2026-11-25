package main

import (
	"context"
	"encoding/json"
	"io/fs"
	"net/http"
	"net/http/httptest"
	"os"
	"path"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// The fake GitHub here only knows demo-mixin, at any ref.
func TestDashboards(t *testing.T) {
	var refs, tokens []string
	github := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/contents/demo-mixin/dashboards_out" {
			http.Error(w, `{"message": "Not Found"}`, http.StatusNotFound)
			return
		}
		refs = append(refs, r.URL.Query().Get("ref"))
		tokens = append(tokens, r.Header.Get("Authorization"))
		raw := "https://raw.example.com/" + r.URL.Query().Get("ref") + "/demo-mixin/dashboards_out/"
		w.Write([]byte(`[
			{"name": "overview.json", "type": "file", "download_url": "` + raw + `overview.json"},
			{"name": "README.md", "type": "file", "download_url": "` + raw + `README.md"},
			{"name": "nested.json", "type": "dir", "download_url": null}
		]`))
	}))
	defer github.Close()
	defer func(api string) { jsonnetLibsAPI = api }(jsonnetLibsAPI)
	jsonnetLibsAPI = github.URL
	t.Setenv("GITHUB_TOKEN", "test-token")

	root := newRepo(t, map[string]string{
		"listed/tests/dashboards":    "# from the mixin\nhttps://example.com/a.json\n\njsonnet-libs/demo-mixin\njsonnet-libs/demo-mixin@feature/branch\n",
		"none/Makefile":              "",
		"insecure/tests/dashboards":  "http://example.com/a.json\n",
		"missing/tests/dashboards":   "jsonnet-libs/missing-mixin\n",
		"traversal/tests/dashboards": "jsonnet-libs/../demo-mixin\n",
	})
	apps, err := sampleApps(root, "listed,none,insecure,missing,traversal")
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	want := []dashboard{
		{url: "https://example.com/a.json"},
		{url: "https://raw.example.com/master/demo-mixin/dashboards_out/overview.json", mixin: "demo-mixin", ref: "master"},
		{url: "https://raw.example.com/feature/branch/demo-mixin/dashboards_out/overview.json", mixin: "demo-mixin", ref: "feature/branch"},
	}
	if listed, err := apps[0].dashboards(ctx, ""); err != nil || !slices.Equal(listed, want) {
		t.Errorf("listed: got %+v, %v; want %+v", listed, err, want)
	}
	if strings.Join(refs, " ") != "master feature/branch" || tokens[0] != "Bearer test-token" {
		t.Errorf("want the master and feature/branch listings with the token, got refs %q and tokens %q", refs, tokens)
	}
	if listed, err := apps[1].dashboards(ctx, ""); err != nil || len(listed) != 0 {
		t.Errorf("none: got %+v, %v; want no dashboards and no error", listed, err)
	}
	if _, err := apps[2].dashboards(ctx, ""); err == nil {
		t.Error("insecure: want an error for a URL that is not https://")
	}
	if _, err := apps[3].dashboards(ctx, ""); err == nil || !strings.Contains(err.Error(), "missing-mixin@master") {
		t.Errorf("missing: want an error naming the mixin, got: %v", err)
	}
	if _, err := apps[4].dashboards(ctx, ""); err == nil {
		t.Error("traversal: want an error for a mixin name that is not a plain directory")
	}

	// ref replaces master and each line's @ref.
	refs = nil
	want = []dashboard{
		{url: "https://example.com/a.json"},
		{url: "https://raw.example.com/abc123/demo-mixin/dashboards_out/overview.json", mixin: "demo-mixin", ref: "abc123"},
		{url: "https://raw.example.com/abc123/demo-mixin/dashboards_out/overview.json", mixin: "demo-mixin", ref: "abc123"},
	}
	if listed, err := apps[0].dashboards(ctx, "abc123"); err != nil || !slices.Equal(listed, want) {
		t.Errorf("listed at abc123: got %+v, %v; want %+v", listed, err, want)
	}
	if strings.Join(refs, " ") != "abc123 abc123" {
		t.Errorf("want both listings at abc123, got refs %q", refs)
	}
}

func TestScreenshotRejectsABadRef(t *testing.T) {
	for _, ref := range []string{"..", "../x", "-x", "a b"} {
		err := appsScreenshot(context.Background(), t.TempDir(), nil, "dbs", ref)
		if err == nil || !strings.Contains(err.Error(), "--jsonnet-libs-ref") {
			t.Errorf("ref %q: want an error naming --jsonnet-libs-ref, got %v", ref, err)
		}
	}
}

func TestMixinApps(t *testing.T) {
	root := newRepo(t, map[string]string{
		"mysql/tests/dashboards":       "# the integration's mixin\njsonnet-libs/mysql-mixin@some-branch\n",
		"mysql/tests/metrics/main":     "up\n",
		"kafka/tests/dashboards":       "https://example.com/a.json\njsonnet-libs/kafka-mixin\n",
		"kafka/tests/metrics/main":     "up\n",
		"bypassed/tests/dashboards":    "jsonnet-libs/mysql-mixin\n",
		"bypassed/.CI_BYPASS":          "",
		"commented/tests/dashboards":   "# jsonnet-libs/mysql-mixin\n",
		"commented/tests/metrics/main": "up\n",
		"none/tests/metrics/main":      "up\n",
	})
	apps, err := allApps(root)
	if err != nil {
		t.Fatal(err)
	}
	tests := map[string]struct {
		mixins []string
		want   []string
	}{
		"one mixin":               {[]string{"mysql-mixin"}, []string{"mysql"}},
		"several mixins":          {[]string{"kafka-mixin", "mysql-mixin"}, []string{"kafka", "mysql"}},
		"a mixin no app names":    {[]string{"common-lib"}, nil},
		"an empty name from a ,,": {[]string{""}, nil},
	}
	for name, tt := range tests {
		t.Run(name, func(t *testing.T) {
			if got, err := mixinApps(apps, tt.mixins); err != nil || !slices.Equal(got, tt.want) {
				t.Errorf("mixinApps(%v) = %v, %v; want %v", tt.mixins, got, err, tt.want)
			}
		})
	}
}

// The fake Grafana here renders only the dashboard with uid "good".
func TestScreenshotApp(t *testing.T) {
	var imported []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/mixin/shared.json":
			w.Write([]byte(`{"__inputs": [{"name": "DS_LOKI", "type": "datasource"}], "uid": "shared"}`))
		case strings.HasPrefix(r.URL.Path, "/mixin/"):
			uid := strings.TrimSuffix(path.Base(r.URL.Path), ".json")
			w.Write([]byte(`{"id": 7, "uid": "` + uid + `", "title": "Demo"}`))
		case r.Method == http.MethodPost && r.URL.Path == "/api/dashboards/db":
			var body struct {
				Dashboard map[string]any
				Overwrite bool
			}
			json.NewDecoder(r.Body).Decode(&body)
			if _, hasID := body.Dashboard["id"]; hasID || !body.Overwrite {
				http.Error(w, "want an overwriting import without an id", http.StatusBadRequest)
				return
			}
			imported = append(imported, body.Dashboard["uid"].(string))
			w.Write([]byte(`{"uid": "` + imported[len(imported)-1] + `"}`))
		case r.URL.Path == "/render/d/good/_" && r.URL.Query().Get("height") == "-1":
			w.Write([]byte("\x89PNG fake image"))
		default:
			http.Error(w, "rendering failed", http.StatusInternalServerError)
		}
	}))
	defer server.Close()

	dir := t.TempDir()
	// The failure comes first, and the query string must not reach the file name.
	dashboards := []dashboard{
		{url: server.URL + "/mixin/broken.json"},
		{url: server.URL + "/mixin/shared.json", mixin: "demo-mixin", ref: "master"},
		{url: server.URL + "/mixin/good.json?v=1.2"},
		{url: server.URL + "/mixin/good.json", mixin: "demo-mixin", ref: "feature/branch"},
	}
	err := screenshotApp(context.Background(), server.URL, dashboards, dir)
	if err == nil || !strings.Contains(err.Error(), "dashboard broken") || strings.Contains(err.Error(), "dashboard good") ||
		strings.Contains(err.Error(), "dashboard shared") {
		t.Errorf("want an error for the broken dashboard only, skipping the shared one, got: %v", err)
	}
	var images []string
	filepath.WalkDir(dir, func(file string, entry fs.DirEntry, err error) error {
		if err == nil && !entry.IsDir() {
			image, _ := os.ReadFile(file)
			if !strings.HasPrefix(string(image), "\x89PNG") {
				t.Errorf("%s = %q, want the rendered image", file, image)
			}
			rel, _ := filepath.Rel(dir, file)
			images = append(images, filepath.ToSlash(rel))
		}
		return err
	})
	// A mixin's image sits under its ref, with any slash in it replaced.
	if want := []string{"feature-branch/demo-mixin/good.png", "good-json-v-1-2.png"}; !slices.Equal(images, want) || len(imported) != 3 {
		t.Errorf("want images %q and 3 imports, got images %q and imports %v", want, images, imported)
	}
}
