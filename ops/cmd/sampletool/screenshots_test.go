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

func TestDashboardURLs(t *testing.T) {
	root := newRepo(t, map[string]string{
		"listed/tests/dashboards":   "# from the mixin\nhttps://example.com/a.json\n\nhttps://example.com/b.json\n",
		"none/Makefile":             "",
		"insecure/tests/dashboards": "http://example.com/a.json\n",
	})
	apps, err := sampleApps(root, "listed,none,insecure")
	if err != nil {
		t.Fatal(err)
	}
	if urls, err := apps[0].dashboardURLs(); err != nil || len(urls) != 2 || urls[1] != "https://example.com/b.json" {
		t.Errorf("listed: got %q, %v", urls, err)
	}
	if urls, err := apps[1].dashboardURLs(); err != nil || len(urls) != 0 {
		t.Errorf("none: got %q, %v; want no dashboards and no error", urls, err)
	}
	if _, err := apps[2].dashboardURLs(); err == nil {
		t.Error("insecure: want an error for a URL that is not https://")
	}
}

// The fake Grafana here renders only the dashboard with uid "good".
func TestScreenshotApp(t *testing.T) {
	var imported []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
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
	urls := []string{server.URL + "/mixin/broken.json", server.URL + "/mixin/good.json?v=1.2"}
	err := screenshotApp(context.Background(), server.URL, urls, dir)
	if err == nil || !strings.Contains(err.Error(), "dashboard broken") || strings.Contains(err.Error(), "dashboard good") {
		t.Errorf("want an error for the broken dashboard only, got: %v", err)
	}
	if image, _ := os.ReadFile(filepath.Join(dir, "good-json-v-1-2.png")); !strings.HasPrefix(string(image), "\x89PNG") {
		t.Errorf("good-json-v-1-2.png = %q, want the rendered image", image)
	}
	if files, _ := filepath.Glob(filepath.Join(dir, "*")); len(files) != 1 || len(imported) != 2 {
		t.Errorf("want 1 image and 2 imports, got files %v and imports %v", files, imported)
	}
}
