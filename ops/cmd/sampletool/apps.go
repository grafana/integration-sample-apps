package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// setupTime is how long sample apps get to produce metrics before the test.
const setupTime = 180 * time.Second

// app is one directory below sample-apps/.
type app struct{ name, dir string }

// sampleApps resolves a comma-separated list of sample-app names.
func sampleApps(root, list string) ([]app, error) {
	var apps []app
	for _, name := range strings.Split(list, ",") {
		if name == "" {
			continue
		}
		dir := filepath.Join(root, "sample-apps", name)
		// Names come from CI inputs, so keep them inside sample-apps/.
		if name != filepath.Base(name) || name[0] == '.' || !exists(dir) {
			return nil, fmt.Errorf("no sample-app named %q", name)
		}
		apps = append(apps, app{name: name, dir: dir})
	}
	if len(apps) == 0 {
		return nil, errors.New("no sample-apps provided")
	}
	return apps, nil
}

// metricsFiles lists the app's expected-metrics files, sorted by name.
func (a app) metricsFiles() []string {
	files, _ := filepath.Glob(filepath.Join(a.dir, "tests", "metrics", "*"))
	return files
}

// endpoints returns the Mimir and Loki host:port of an environment.
func endpoints(ctx context.Context, env, dbsName string) (prometheus, loki string, err error) {
	switch env {
	case "local":
		ip, err := multipassIP(ctx, dbsName)
		return ip + ":9009", ip + ":3100", err
	case "k3d":
		return "mimir.k3d.localhost:9999", "loki.k3d.localhost:9999", nil
	default:
		return "", "", fmt.Errorf("invalid environment %q (want local or k3d)", env)
	}
}

// appsUp launches each app, stopping at the first that fails.
func appsUp(ctx context.Context, apps []app, env, dbsName string) error {
	prometheus, loki, err := endpoints(ctx, env, dbsName)
	if err != nil {
		return err
	}
	for _, a := range apps {
		fmt.Printf("-- Spawning sample-app %s --\n", a.name)
		if err := command(ctx, a.dir, "make", "PROMETHEUS_INSTANCE="+prometheus, "LOKI_INSTANCE="+loki, "run-ci"); err != nil {
			return err
		}
		if env == "k3d" {
			if err := command(ctx, a.dir, "make", "configure-k3d-dns"); err != nil {
				return err
			}
		}
	}
	return nil
}

func appsWait(ctx context.Context) error {
	fmt.Printf("Waiting %s for the sample apps to generate metrics\n", setupTime)
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(setupTime):
		return nil
	}
}

// appsDown stops every app, even when one of them fails to stop.
func appsDown(ctx context.Context, apps []app) error {
	var errs []error
	for _, a := range apps {
		fmt.Printf("Stopping sample-app `%s`\n", a.name)
		errs = append(errs, command(ctx, a.dir, "make", "stop"))
	}
	return errors.Join(errs...)
}

// ciCheck reports whether CI should launch and test the app. It fails for an
// app that has neither expected metrics nor a .CI_BYPASS file.
func ciCheck(a app) (bool, error) {
	bypass := exists(filepath.Join(a.dir, ".CI_BYPASS"))
	testable := len(a.metricsFiles()) > 0
	if !testable && !bypass {
		return false, fmt.Errorf("[FAIL] The %s sample-app is not CI compatible and does not have a CI bypass file", a.name)
	}
	return testable && !bypass, nil
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
