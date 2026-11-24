package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

// defaultSuccessRate applies unless a test config sets METRICS_SUCCESS_RATE_REQUIRED.
const defaultSuccessRate = 0.8

// seriesExist reports whether an instant query against Mimir returns any series.
func seriesExist(ctx context.Context, prometheus, query string) (bool, error) {
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	data, err := request(ctx, http.MethodGet, "http://"+prometheus+"/prometheus/api/v1/query?"+url.Values{"query": {query}}.Encode(), nil)
	if err != nil {
		return false, err
	}
	var body struct {
		Status string
		Data   struct{ Result []json.RawMessage }
	}
	if err := json.Unmarshal(data, &body); err != nil || body.Status != "success" {
		return false, fmt.Errorf("unexpected response from %s: %.200s", prometheus, data)
	}
	return len(body.Data.Result) > 0, nil
}

// appsTest checks the apps' metrics in Mimir, found through env unless prometheus is set.
// With overrides set, lists in that directory replace the apps' own: see listOverrides.
func appsTest(ctx context.Context, apps []app, env, dbsName, prometheus, overrides string) error {
	if prometheus == "" {
		var err error
		if prometheus, _, err = endpoints(ctx, env, dbsName); err != nil {
			return err
		}
	}
	var errs []error
	for _, a := range apps {
		files := a.metricsFiles()
		if len(files) == 0 {
			errs = append(errs, fmt.Errorf("%s: no expected metrics files in tests/metrics", a.name))
			continue
		}
		lists, err := listOverrides(overrides, a, files)
		if err != nil {
			errs = append(errs, fmt.Errorf("%s: %w", a.name, err))
			continue
		}
		for _, file := range files {
			if err := testCase(ctx, a, prometheus, file, lists[file]); err != nil {
				errs = append(errs, fmt.Errorf("%s: %s: %w", a.name, filepath.Base(file), err))
			}
		}
	}
	return errors.Join(errs...)
}

// listOverrides maps the app's scenario files to the lists in dir that replace
// them: <dir>/<app>/<scenario>, or <dir>/<app> for the app's only scenario, or
// for its "integration" scenario when it has several. A scenario without one
// keeps its own list.
func listOverrides(dir string, a app, scenarios []string) (map[string]string, error) {
	lists := map[string]string{}
	if dir == "" {
		return lists, nil
	}
	path := filepath.Join(dir, a.name)
	info, err := os.Stat(path)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		return lists, nil
	case err != nil:
		return nil, err
	case info.IsDir():
		entries, err := os.ReadDir(path)
		if err != nil {
			return nil, err
		}
		for _, e := range entries {
			scenario := filepath.Join(a.dir, "tests", "metrics", e.Name())
			if !slices.Contains(scenarios, scenario) {
				return nil, fmt.Errorf("%s replaces tests/metrics/%s, which doesn't exist", filepath.Join(path, e.Name()), e.Name())
			}
			lists[scenario] = filepath.Join(path, e.Name())
		}
		return lists, nil
	}
	if len(scenarios) == 1 {
		lists[scenarios[0]] = path
		return lists, nil
	}
	integration := filepath.Join(a.dir, "tests", "metrics", "integration")
	if !slices.Contains(scenarios, integration) {
		return nil, fmt.Errorf("%s doesn't say which of its %d scenarios it replaces: use %s/<scenario>, or name one scenario integration",
			path, len(scenarios), path)
	}
	lists[integration] = path
	return lists, nil
}

// readMetricList reads a list of metric names separated by whitespace. A #
// starts a comment that runs to the end of the line, as in an integration's
// metric_names.
func readMetricList(path string) ([]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var names []string
	for _, line := range strings.Split(string(data), "\n") {
		line, _, _ = strings.Cut(line, "#")
		names = append(names, strings.Fields(line)...)
	}
	return names, nil
}

// isRuleOutput reports whether a metric name is a recording rule's output,
// named level:metric:operations by convention. The databases run no rules, so
// these never arrive. Exporters shouldn't use colons, but TensorFlow Serving
// starts names with one, such as :tensorflow:serving:request_count.
func isRuleOutput(name string) bool {
	return strings.Contains(name, ":") && !strings.HasPrefix(name, ":")
}

// testCase checks the metrics listed in a tests/metrics file, or in list when
// it's set, using the config named after the tests/metrics file, and fails when
// too few of them are present in Mimir.
func testCase(ctx context.Context, a app, prometheus, metricsFile, list string) error {
	config, err := godotenv.Read(filepath.Join(a.dir, "tests", "configs", filepath.Base(metricsFile)+".config"))
	if err != nil {
		return fmt.Errorf("config: %w", err)
	}
	// An empty JOB_LABEL would match every metric in the database.
	job := config["JOB_LABEL"]
	if job == "" {
		return errors.New("JOB_LABEL not set")
	}
	rate := defaultSuccessRate
	if v := config["METRICS_SUCCESS_RATE_REQUIRED"]; v != "" {
		if rate, err = strconv.ParseFloat(v, 64); err != nil {
			return fmt.Errorf("METRICS_SUCCESS_RATE_REQUIRED: %w", err)
		}
	}
	// Each INSTANCE_FILTER regex is checked separately; without any, the whole job is.
	instances := strings.Fields(config["INSTANCE_FILTER"])
	if len(instances) == 0 {
		instances = []string{""}
	}

	if list == "" {
		list = metricsFile
	} else {
		fmt.Printf("Expected metrics for %s's %s scenario come from %s\n", a.name, filepath.Base(metricsFile), list)
	}
	listed, err := readMetricList(list)
	if err != nil {
		return err
	}
	var expected, rules []string
	for _, name := range listed {
		if isRuleOutput(name) {
			rules = append(rules, name)
		} else {
			expected = append(expected, name)
		}
	}
	if len(rules) > 0 {
		fmt.Printf("Skipping %d recording rule outputs, which the databases don't produce: %s\n", len(rules), strings.Join(rules, " "))
	}
	// Zero of zero metrics would otherwise count as a pass.
	if len(expected) == 0 {
		return errors.New("no metrics listed, other than recording rule outputs")
	}

	var errs []error
	for _, instance := range instances {
		selector, on := fmt.Sprintf("job=~%q", job), ""
		if instance != "" {
			selector += fmt.Sprintf(",instance=~%q", instance)
			on = fmt.Sprintf(" on instance '%s'", instance)
		}

		fmt.Printf("--- [ Checking Metrics for %s using job='%s'%s ] ---\n", a.name, job, on)
		found := 0
		for _, metric := range expected {
			present, err := seriesExist(ctx, prometheus, metric+"{"+selector+"}")
			if err != nil {
				return err
			}
			if present {
				fmt.Printf("[PASS] '%s' present\n", metric)
				found++
			} else {
				fmt.Printf("[FAIL] '%s' **not present**\n", metric)
			}
		}

		// The tolerance absorbs floating-point error: 0.1*30 is slightly more than 3.
		result := "SUCCESS"
		if float64(found)+1e-9 < float64(len(expected))*rate {
			result = "FAIL"
			errs = append(errs, fmt.Errorf("%d of %d expected metrics present%s, %v required", found, len(expected), on, rate))
		}
		fmt.Printf("--- [ TEST %s%s ] ---\n", result, on)
		fmt.Printf("%d out of %d expected metrics were present in Prometheus/Mimir (%s); the required success rate is %v\n",
			found, len(expected), prometheus, rate)
	}
	return errors.Join(errs...)
}
