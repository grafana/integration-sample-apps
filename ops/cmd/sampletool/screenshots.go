package main

import (
	"bytes"
	"cmp"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// grafanaComposeUp starts Grafana and its image renderer in the databases VM.
const grafanaComposeUp = "docker-compose -f docker-compose.grafana.yaml up -d"

// mixinLine matches jsonnet-libs/<mixin>, optionally followed by @<ref>.
var mixinLine = regexp.MustCompile(`^jsonnet-libs/([A-Za-z0-9][A-Za-z0-9._-]*)(?:@([A-Za-z0-9][A-Za-z0-9._/-]*))?$`)

// dashboard is a dashboard to capture. One listed from a mixin keeps the
// mixin's name and ref, so its image can be grouped under them.
type dashboard struct{ url, mixin, ref string }

// dashboards reads the app's optional tests/dashboards file. Each line is
// either the https URL of a dashboard JSON file, or jsonnet-libs/<mixin>[@ref]
// for every dashboard in that mixin's dashboards_out, at master by default.
func (a app) dashboards(ctx context.Context) ([]dashboard, error) {
	file := filepath.Join(a.dir, "tests", "dashboards")
	data, err := os.ReadFile(file)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, err
	}
	var listed []dashboard
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if m := mixinLine.FindStringSubmatch(line); m != nil {
			fromMixin, err := mixinDashboards(ctx, m[1], cmp.Or(m[2], "master"))
			if err != nil {
				return nil, fmt.Errorf("%s: %w", file, err)
			}
			listed = append(listed, fromMixin...)
			continue
		}
		if !strings.HasPrefix(line, "https://") {
			return nil, fmt.Errorf("%s: %q is neither an https:// URL nor jsonnet-libs/<mixin>", file, line)
		}
		listed = append(listed, dashboard{url: line})
	}
	return listed, nil
}

// jsonnetLibsAPI is the GitHub API of grafana/jsonnet-libs, replaced in tests.
var jsonnetLibsAPI = "https://api.github.com/repos/grafana/jsonnet-libs"

// mixinDashboards returns the dashboards a jsonnet-libs mixin has built into
// its dashboards_out directory at ref.
func mixinDashboards(ctx context.Context, mixin, ref string) ([]dashboard, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		jsonnetLibsAPI+"/contents/"+mixin+"/dashboards_out?ref="+url.QueryEscape(ref), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	// Without a token GitHub allows 60 requests an hour, shared by CI runners.
	if token := os.Getenv("GITHUB_TOKEN"); token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	data, err := do(req)
	if err != nil {
		return nil, fmt.Errorf("listing the dashboards of %s@%s: %w", mixin, ref, err)
	}
	var files []struct {
		Name        string
		Type        string
		DownloadURL string `json:"download_url"`
	}
	if err := json.Unmarshal(data, &files); err != nil {
		return nil, fmt.Errorf("listing the dashboards of %s@%s: %w", mixin, ref, err)
	}
	var listed []dashboard
	for _, f := range files {
		if f.Type == "file" && strings.HasSuffix(f.Name, ".json") {
			listed = append(listed, dashboard{url: f.DownloadURL, mixin: mixin, ref: ref})
		}
	}
	if len(listed) == 0 {
		return nil, fmt.Errorf("%s@%s has no dashboards in dashboards_out", mixin, ref)
	}
	return listed, nil
}

// appsScreenshot saves an image of every dashboard the apps list to
// <root>/screenshots/<app>/. Apps that list none are skipped.
func appsScreenshot(ctx context.Context, root string, apps []app, dbsName string) error {
	var errs []error
	grafana := ""
	for _, a := range apps {
		listed, err := a.dashboards(ctx)
		if err != nil {
			return err
		}
		if len(listed) == 0 {
			fmt.Printf("%s lists no dashboards in tests/dashboards, nothing to capture\n", a.name)
			continue
		}
		if grafana == "" {
			if grafana, err = startGrafana(ctx, dbsName); err != nil {
				return err
			}
		}
		errs = append(errs, screenshotApp(ctx, grafana, listed, filepath.Join(root, "screenshots", a.name)))
	}
	return errors.Join(errs...)
}

// startGrafana starts Grafana in the databases VM, if it is not running yet,
// and returns its URL once it answers.
func startGrafana(ctx context.Context, dbsName string) (string, error) {
	if err := multipass(ctx, "exec", dbsName, "--", "bash", "-c", grafanaComposeUp); err != nil {
		return "", err
	}
	ip, err := multipassIP(ctx, dbsName)
	if err != nil {
		return "", err
	}
	grafana := "http://" + ip + ":3000"
	for deadline := time.Now().Add(2 * time.Minute); ; {
		if _, err = request(ctx, http.MethodGet, grafana+"/api/health", nil); err == nil {
			return grafana, nil
		}
		if time.Now().After(deadline) {
			return "", fmt.Errorf("Grafana is not ready: %w", err)
		}
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		case <-time.After(3 * time.Second):
		}
	}
}

var unsafeName = regexp.MustCompile(`[^A-Za-z0-9_-]`)

// screenshotApp captures each dashboard to dir/<name>.png, or to
// dir/<ref>/<mixin>/<name>.png for one listed from a mixin, carrying on when
// one of them fails. The pull-request comment groups the images by that path.
func screenshotApp(ctx context.Context, grafana string, dashboards []dashboard, dir string) error {
	var errs []error
	for _, d := range dashboards {
		// The names end up in file names and in the pull-request comment.
		name := unsafeName.ReplaceAllString(strings.TrimSuffix(path.Base(d.url), ".json"), "-")
		imageDir := dir
		if d.mixin != "" {
			// A ref such as feature/branch is one directory, feature-branch.
			imageDir = filepath.Join(dir, strings.ReplaceAll(d.ref, "/", "-"), d.mixin)
		}
		if err := os.MkdirAll(imageDir, 0o755); err != nil {
			return err
		}
		file := filepath.Join(imageDir, name+".png")

		image, err := renderDashboard(ctx, grafana, d.url)
		if errors.Is(err, errSharedExport) {
			fmt.Printf("[SKIP] %s: %v\n", name, err)
			continue
		}
		if err == nil {
			err = os.WriteFile(file, image, 0o644)
		}
		if err != nil {
			fmt.Printf("[FAIL] %s: %v\n", name, err)
			errs = append(errs, fmt.Errorf("dashboard %s: %w", name, err))
			continue
		}
		fmt.Printf("[ OK ] %s\n", file)
	}
	return errors.Join(errs...)
}

// errSharedExport is returned for a dashboard exported for sharing, whose
// datasources are __inputs placeholders that only an import with inputs resolves.
var errSharedExport = errors.New("exported for sharing with __inputs, which is not supported")

// renderDashboard downloads a dashboard, imports it into Grafana and returns a
// full-page PNG of it covering the last 5 minutes.
func renderDashboard(ctx context.Context, grafana, url string) ([]byte, error) {
	raw, err := request(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	var dashboard map[string]any
	if err := json.Unmarshal(raw, &dashboard); err != nil {
		return nil, fmt.Errorf("%s is not dashboard JSON: %w", url, err)
	}
	if _, ok := dashboard["__inputs"]; ok {
		return nil, errSharedExport
	}
	// The id belongs to the Grafana the dashboard was saved in.
	delete(dashboard, "id")
	body, _ := json.Marshal(map[string]any{"dashboard": dashboard, "overwrite": true})
	reply, err := request(ctx, http.MethodPost, grafana+"/api/dashboards/db", body)
	if err != nil {
		return nil, err
	}
	var imported struct{ UID string }
	if err := json.Unmarshal(reply, &imported); err != nil || imported.UID == "" {
		return nil, fmt.Errorf("unexpected import response: %.200s", reply)
	}

	// height=-1 asks the renderer for the whole page rather than one screen.
	image, err := request(ctx, http.MethodGet, grafana+"/render/d/"+imported.UID+"/_?orgId=1&from=now-5m&to=now&tz=UTC&kiosk=true&width=1600&height=-1", nil)
	if err == nil && !bytes.HasPrefix(image, []byte("\x89PNG")) {
		err = fmt.Errorf("the renderer returned no image: %.200s", image)
	}
	return image, err
}
