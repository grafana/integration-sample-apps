package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path"
	"path/filepath"
	"strings"
	"testing"
)

// The fake GitHub here only knows demo-mixin, at any ref.
func TestDashboardURLs(t *testing.T) {
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
		"listed/tests/dashboards":   "# from the mixin\nhttps://example.com/a.json\n\njsonnet-libs/demo-mixin\njsonnet-libs/demo-mixin@feature/branch\n",
		"none/Makefile":             "",
		"insecure/tests/dashboards": "http://example.com/a.json\n",
		"missing/tests/dashboards":  "jsonnet-libs/missing-mixin\n",
	})
	apps, err := sampleApps(root, "listed,none,insecure,missing")
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	want := []string{
		"https://example.com/a.json",
		"https://raw.example.com/master/demo-mixin/dashboards_out/overview.json",
		"https://raw.example.com/feature/branch/demo-mixin/dashboards_out/overview.json",
	}
	if urls, err := apps[0].dashboardURLs(ctx); err != nil || strings.Join(urls, " ") != strings.Join(want, " ") {
		t.Errorf("listed: got %q, %v; want %q", urls, err, want)
	}
	if strings.Join(refs, " ") != "master feature/branch" || tokens[0] != "Bearer test-token" {
		t.Errorf("want the master and feature/branch listings with the token, got refs %q and tokens %q", refs, tokens)
	}
	if urls, err := apps[1].dashboardURLs(ctx); err != nil || len(urls) != 0 {
		t.Errorf("none: got %q, %v; want no dashboards and no error", urls, err)
	}
	if _, err := apps[2].dashboardURLs(ctx); err == nil {
		t.Error("insecure: want an error for a URL that is not https://")
	}
	if _, err := apps[3].dashboardURLs(ctx); err == nil || !strings.Contains(err.Error(), "missing-mixin@master") {
		t.Errorf("missing: want an error naming the mixin, got: %v", err)
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
	urls := []string{server.URL + "/mixin/broken.json", server.URL + "/mixin/shared.json", server.URL + "/mixin/good.json?v=1.2"}
	err := screenshotApp(context.Background(), server.URL, urls, dir)
	if err == nil || !strings.Contains(err.Error(), "dashboard broken") || strings.Contains(err.Error(), "dashboard good") ||
		strings.Contains(err.Error(), "dashboard shared") {
		t.Errorf("want an error for the broken dashboard only, skipping the shared one, got: %v", err)
	}
	if image, _ := os.ReadFile(filepath.Join(dir, "good-json-v-1-2.png")); !strings.HasPrefix(string(image), "\x89PNG") {
		t.Errorf("good-json-v-1-2.png = %q, want the rendered image", image)
	}
	if files, _ := filepath.Glob(filepath.Join(dir, "*")); len(files) != 1 || len(imported) != 2 {
		t.Errorf("want 1 image and 2 imports, got files %v and imports %v", files, imported)
	}
}
