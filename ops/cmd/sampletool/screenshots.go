package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// grafanaComposeUp starts Grafana and its image renderer in the databases VM.
const grafanaComposeUp = "docker-compose -f docker-compose.grafana.yaml up -d"

// dashboardURLs reads the app's optional tests/dashboards file, which lists
// one https URL of a dashboard JSON file per line.
func (a app) dashboardURLs() ([]string, error) {
	file := filepath.Join(a.dir, "tests", "dashboards")
	data, err := os.ReadFile(file)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, err
	}
	var urls []string
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if !strings.HasPrefix(line, "https://") {
			return nil, fmt.Errorf("%s: %q is not an https:// URL", file, line)
		}
		urls = append(urls, line)
	}
	return urls, nil
}

// appsScreenshot saves an image of every dashboard the apps list to
// <root>/screenshots/<app>/. Apps that list none are skipped.
func appsScreenshot(ctx context.Context, root string, apps []app, dbsName string) error {
	var errs []error
	grafana := ""
	for _, a := range apps {
		urls, err := a.dashboardURLs()
		if err != nil {
			return err
		}
		if len(urls) == 0 {
			fmt.Printf("%s lists no dashboards in tests/dashboards, nothing to capture\n", a.name)
			continue
		}
		if grafana == "" {
			if grafana, err = startGrafana(ctx, dbsName); err != nil {
				return err
			}
		}
		errs = append(errs, screenshotApp(ctx, grafana, urls, filepath.Join(root, "screenshots", a.name)))
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

// screenshotApp captures each dashboard to dir/<name>.png, carrying on when
// one of them fails.
func screenshotApp(ctx context.Context, grafana string, urls []string, dir string) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	var errs []error
	for _, url := range urls {
		// The name ends up in a file name and in the pull-request comment.
		name := unsafeName.ReplaceAllString(strings.TrimSuffix(path.Base(url), ".json"), "-")
		file := filepath.Join(dir, name+".png")

		image, err := renderDashboard(ctx, grafana, url)
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

// renderDashboard downloads a dashboard, imports it into Grafana and returns a
// full-page PNG of it covering the last 15 minutes.
func renderDashboard(ctx context.Context, grafana, url string) ([]byte, error) {
	raw, err := request(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	var dashboard map[string]any
	if err := json.Unmarshal(raw, &dashboard); err != nil {
		return nil, fmt.Errorf("%s is not dashboard JSON: %w", url, err)
	}
	// Dashboards exported for sharing have unresolved datasource placeholders.
	if _, ok := dashboard["__inputs"]; ok {
		return nil, errors.New("dashboards with __inputs are not supported")
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
	image, err := request(ctx, http.MethodGet, grafana+"/render/d/"+imported.UID+"/_?orgId=1&from=now-15m&to=now&tz=UTC&kiosk=true&width=1600&height=-1", nil)
	if err == nil && !bytes.HasPrefix(image, []byte("\x89PNG")) {
		err = fmt.Errorf("the renderer returned no image: %.200s", image)
	}
	return image, err
}
