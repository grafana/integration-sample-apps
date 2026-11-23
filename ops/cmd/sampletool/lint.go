package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"

	"github.com/joho/godotenv"
)

// finding is one problem lint found in a sample app. Errors fail the run.
type finding struct {
	Level   string `json:"level"`
	App     string `json:"app"`
	Message string `json:"message"`
}

// configKeys are the tests/configs keys that 'apps test' reads.
var configKeys = []string{"JOB_LABEL", "INSTANCE_FILTER", "METRICS_SUCCESS_RATE_REQUIRED"}

var (
	metricName      = regexp.MustCompile(`^[a-zA-Z_:][a-zA-Z0-9_:]*$`)
	runCITarget     = regexp.MustCompile(`(?m)^run-ci:`)
	sharedMakefile  = regexp.MustCompile(`(?m)^include \.\./Makefile`)
	hardcodedAMD64  = regexp.MustCompile(`amd64|x86_64`)
	archDetection   = regexp.MustCompile(`dpkg --print-architecture|uname -m|arm64|aarch64`)
	overwrite       = regexp.MustCompile(`[^>&0-9]>[^>]`)
	defaultTargets  = []string{"defaultconfig", "default-monitoring-config"}
	maxListedValues = 3
)

// allApps returns every directory below sample-apps/, sorted by name.
func allApps(root string) ([]app, error) {
	entries, err := os.ReadDir(filepath.Join(root, "sample-apps"))
	if err != nil {
		return nil, err
	}
	var apps []app
	for _, e := range entries {
		if e.IsDir() && !strings.HasPrefix(e.Name(), ".") {
			apps = append(apps, app{name: e.Name(), dir: filepath.Join(root, "sample-apps", e.Name())})
		}
	}
	return apps, nil
}

// appsLint checks the apps without starting anything, writes the findings to w
// as text or JSON, and fails if any finding is an error.
func appsLint(w io.Writer, apps []app, asJSON bool) error {
	var findings []finding
	for _, a := range apps {
		findings = append(findings, lintApp(a)...)
	}
	errorCount := 0
	for _, f := range findings {
		if f.Level == "error" {
			errorCount++
		}
	}

	if asJSON {
		report := struct {
			AppsChecked int       `json:"apps_checked"`
			Errors      int       `json:"errors"`
			Warnings    int       `json:"warnings"`
			Findings    []finding `json:"findings"`
		}{len(apps), errorCount, len(findings) - errorCount, findings}
		if report.Findings == nil {
			report.Findings = []finding{}
		}
		enc := json.NewEncoder(w)
		enc.SetIndent("", "  ")
		if err := enc.Encode(report); err != nil {
			return err
		}
	} else {
		for _, f := range findings {
			fmt.Fprintf(w, "%-7s %s: %s\n", strings.ToUpper(f.Level), f.App, f.Message)
		}
		fmt.Fprintf(w, "Checked %d sample apps: %d errors, %d warnings.\n", len(apps), errorCount, len(findings)-errorCount)
	}
	if errorCount > 0 {
		return fmt.Errorf("lint found %d errors", errorCount)
	}
	return nil
}

// lintApp returns the findings for one app.
func lintApp(a app) []finding {
	var findings []finding
	add := func(level, format string, args ...any) {
		findings = append(findings, finding{Level: level, App: a.name, Message: fmt.Sprintf(format, args...)})
	}

	bypass := exists(filepath.Join(a.dir, ".CI_BYPASS"))
	// The sample-app workflow runs apps without .CI_BYPASS; windows has a workflow of its own.
	ci := !bypass && a.name != "windows"

	if !exists(filepath.Join(a.dir, "README.md")) {
		add("warning", "no README.md")
	}

	makefile, err := os.ReadFile(filepath.Join(a.dir, "Makefile"))
	switch {
	case errors.Is(err, fs.ErrNotExist):
		if ci {
			add("error", "no Makefile")
		}
	case err != nil:
		add("error", "reading Makefile: %v", err)
	default:
		if ci && !runCITarget.Match(makefile) {
			add("error", "Makefile has no run-ci target, which 'apps up' runs")
		}
		if ci && !sharedMakefile.Match(makefile) {
			add("warning", "Makefile doesn't include ../Makefile, so 'apps up --env k3d' fails at configure-k3d-dns")
		}
		for _, target := range defaultTargets {
			recipe := makeRecipe(string(makefile), target)
			if strings.Contains(recipe, ">>") && !overwrite.MatchString(recipe) {
				add("warning", "%s only appends (>>), so running it twice duplicates every key: write its first line with >", target)
			}
		}
	}

	if a.name != "windows" && hardcodesAMD64(a.dir) {
		add("warning", "hardcodes amd64 with no architecture detection, so it won't run on arm64 hosts such as Apple Silicon Macs")
	}

	files := a.metricsFiles()
	switch {
	case bypass && len(files) > 0:
		add("warning", "has .CI_BYPASS and tests/metrics/, which CI never runs")
	case !bypass && len(files) == 0:
		add("error", "no tests/metrics/ files and no .CI_BYPASS, so CI fails this app")
	}
	if !bypass {
		for _, file := range files {
			for _, f := range lintTestCase(a, file) {
				add(f.Level, "%s", f.Message)
			}
		}
	}

	if msg := lintDashboards(a); msg != "" {
		add("error", "%s", msg)
	}
	return findings
}

// lintTestCase checks one tests/metrics file and the config of the same name,
// as 'apps test' reads them.
func lintTestCase(a app, metricsFile string) []finding {
	var findings []finding
	add := func(level, format string, args ...any) {
		findings = append(findings, finding{Level: level, Message: fmt.Sprintf(format, args...)})
	}
	scenario := filepath.Base(metricsFile)

	configFile := filepath.Join("tests", "configs", scenario+".config")
	config, err := godotenv.Read(filepath.Join(a.dir, configFile))
	switch {
	case errors.Is(err, fs.ErrNotExist):
		add("error", "tests/metrics/%s has no %s", scenario, configFile)
	case err != nil:
		add("error", "%s doesn't parse: %v", configFile, err)
	default:
		if config["JOB_LABEL"] == "" {
			add("error", "%s doesn't set JOB_LABEL", configFile)
		}
		if v, ok := config["METRICS_SUCCESS_RATE_REQUIRED"]; ok {
			if rate, err := strconv.ParseFloat(v, 64); err != nil || rate < 0 || rate > 1 {
				add("error", "%s: METRICS_SUCCESS_RATE_REQUIRED=%q isn't a number from 0 to 1", configFile, v)
			}
		}
		var unknown []string
		for key := range config {
			if !slices.Contains(configKeys, key) {
				unknown = append(unknown, key)
			}
		}
		slices.Sort(unknown)
		if len(unknown) > 0 {
			add("warning", "%s sets %s, which 'apps test' ignores", configFile, strings.Join(unknown, ", "))
		}
	}

	data, err := os.ReadFile(metricsFile)
	if err != nil {
		add("error", "reading tests/metrics/%s: %v", scenario, err)
		return findings
	}
	metrics := strings.Fields(string(data))
	if len(metrics) == 0 {
		add("error", "tests/metrics/%s lists no metrics", scenario)
	}
	var invalid, duplicates []string
	seen := map[string]bool{}
	for _, m := range metrics {
		if !metricName.MatchString(m) {
			invalid = append(invalid, m)
		}
		if seen[m] && !slices.Contains(duplicates, m) {
			duplicates = append(duplicates, m)
		}
		seen[m] = true
	}
	if len(invalid) > 0 {
		add("error", "tests/metrics/%s lists names that aren't metric names: %s", scenario, firstFew(invalid))
	}
	if len(duplicates) > 0 {
		add("warning", "tests/metrics/%s lists metrics more than once, which counts them twice towards the success rate: %s", scenario, firstFew(duplicates))
	}
	return findings
}

// lintDashboards checks the syntax of the app's optional tests/dashboards file
// without fetching anything, and returns a message for the first bad line.
func lintDashboards(a app) string {
	data, err := os.ReadFile(filepath.Join(a.dir, "tests", "dashboards"))
	if errors.Is(err, fs.ErrNotExist) {
		return ""
	}
	if err != nil {
		return fmt.Sprintf("reading tests/dashboards: %v", err)
	}
	for i, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") || mixinLine.MatchString(line) || strings.HasPrefix(line, "https://") {
			continue
		}
		return fmt.Sprintf("tests/dashboards line %d: %q is neither an https:// URL nor jsonnet-libs/<mixin>[@ref]", i+1, line)
	}
	return ""
}

// makeRecipe returns the recipe lines of a Makefile target.
func makeRecipe(makefile, target string) string {
	var recipe []string
	in := false
	for _, line := range strings.Split(makefile, "\n") {
		switch {
		case strings.HasPrefix(line, target+":"):
			in = true
		case in && strings.HasPrefix(line, "\t"):
			recipe = append(recipe, line)
		case in && line != "":
			in = false
		}
	}
	return strings.Join(recipe, "\n")
}

// hardcodesAMD64 reports whether the app's Makefile, jinja/ or scripts/ name
// amd64 without ever detecting the architecture.
func hardcodesAMD64(dir string) bool {
	var hardcoded, detected bool
	check := func(path string) {
		data, err := os.ReadFile(path)
		if err != nil {
			return
		}
		hardcoded = hardcoded || hardcodedAMD64.Match(data)
		detected = detected || archDetection.Match(data)
	}
	check(filepath.Join(dir, "Makefile"))
	for _, sub := range []string{"jinja", "scripts"} {
		_ = filepath.WalkDir(filepath.Join(dir, sub), func(path string, d fs.DirEntry, err error) error {
			if err == nil && d.Type().IsRegular() {
				check(path)
			}
			return nil
		})
	}
	return hardcoded && !detected
}

func firstFew(values []string) string {
	if len(values) > maxListedValues {
		return strings.Join(values[:maxListedValues], ", ") + fmt.Sprintf(" and %d more", len(values)-maxListedValues)
	}
	return strings.Join(values, ", ")
}
