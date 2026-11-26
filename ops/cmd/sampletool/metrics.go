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

	"github.com/joho/godotenv"
)

// seriesExist reports whether an instant query against Mimir returns any series.
func seriesExist(ctx context.Context, prometheus, query string) (bool, error) {
	ctx, cancel := context.WithTimeout(ctx, queryTimeout)
	defer cancel()
	data, err := request(ctx, http.MethodGet, "http://"+prometheus+queryPath+"?"+url.Values{"query": {query}}.Encode(), nil)
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
			s, err := loadScenario(a, file)
			if err == nil {
				err = s.check(ctx, prometheus)
			}
			if err != nil {
				errs = append(errs, fmt.Errorf("%s: %s: %w", a.name, filepath.Base(file), err))
			}
		}
	}
	return errors.Join(errs...)
}

// scenario is a tests/metrics file and the config of the same name.
type scenario struct {
	app      string
	job      string
	rate     float64
	expected []string
	// The INSTANCE_FILTER regexes, each checked separately, or "" for the whole job.
	instances []string
}

// loadScenario reads a tests/metrics file and its config.
func loadScenario(a app, metricsFile string) (scenario, error) {
	config, err := godotenv.Read(filepath.Join(a.dir, configsDir, filepath.Base(metricsFile)+".config"))
	if err != nil {
		return scenario{}, fmt.Errorf("config: %w", err)
	}
	s := scenario{app: a.name, job: config["JOB_LABEL"], rate: defaultSuccessRate, instances: strings.Fields(config["INSTANCE_FILTER"])}
	// An empty JOB_LABEL would match every metric in the database.
	if s.job == "" {
		return scenario{}, errors.New("JOB_LABEL not set")
	}
	if v := config["METRICS_SUCCESS_RATE_REQUIRED"]; v != "" {
		if s.rate, err = strconv.ParseFloat(v, 64); err != nil {
			return scenario{}, fmt.Errorf("METRICS_SUCCESS_RATE_REQUIRED: %w", err)
		}
	}
	if len(s.instances) == 0 {
		s.instances = []string{""}
	}

	data, err := os.ReadFile(metricsFile)
	if err != nil {
		return scenario{}, err
	}
	s.expected = strings.Fields(string(data))
	// Zero of zero metrics would otherwise count as a pass.
	if len(s.expected) == 0 {
		return scenario{}, errors.New("no metrics listed")
	}
	return s, nil
}

// check fails when too few of the scenario's metrics are present in Mimir, on
// any of its instance filters.
func (s scenario) check(ctx context.Context, prometheus string) error {
	var errs []error
	for _, instance := range s.instances {
		selector, on := fmt.Sprintf("job=~%q", s.job), ""
		if instance != "" {
			selector += fmt.Sprintf(",instance=~%q", instance)
			on = fmt.Sprintf(" on instance '%s'", instance)
		}

		fmt.Printf("--- [ Checking Metrics for %s using job='%s'%s ] ---\n", s.app, s.job, on)
		found := 0
		for _, metric := range s.expected {
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
		if float64(found)+1e-9 < float64(len(s.expected))*s.rate {
			result = "FAIL"
			errs = append(errs, fmt.Errorf("%d of %d expected metrics present%s, %v required", found, len(s.expected), on, s.rate))
		}
		fmt.Printf("--- [ TEST %s%s ] ---\n", result, on)
		fmt.Printf("%d out of %d expected metrics were present in Prometheus/Mimir (%s); the required success rate is %v\n",
			found, len(s.expected), prometheus, s.rate)
	}
	return errors.Join(errs...)
}
