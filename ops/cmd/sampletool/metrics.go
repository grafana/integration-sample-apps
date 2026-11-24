package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
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
func appsTest(ctx context.Context, apps []app, env, dbsName, prometheus string) error {
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
		}
		for _, file := range files {
			if err := testCase(ctx, a, prometheus, file); err != nil {
				errs = append(errs, fmt.Errorf("%s: %s: %w", a.name, filepath.Base(file), err))
			}
		}
	}
	return errors.Join(errs...)
}

// testCase checks the metrics listed in a tests/metrics file, using the config
// of the same name, and fails when too few of them are present in Mimir.
func testCase(ctx context.Context, a app, prometheus, metricsFile string) error {
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

	data, err := os.ReadFile(metricsFile)
	if err != nil {
		return err
	}
	expected := strings.Fields(string(data))
	// Zero of zero metrics would otherwise count as a pass.
	if len(expected) == 0 {
		return errors.New("no metrics listed")
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
