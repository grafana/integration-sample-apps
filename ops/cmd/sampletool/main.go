// Command sampletool is the control plane for testing integration sample apps.
package main

import (
	"bytes"
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"strings"
)

const usage = `sampletool - control plane for integration sample apps

Usage: sampletool <group> <command> [flags] [name]

  dbs up       Launch the VM running Mimir, Loki and (for --env local) Grafana
  dbs down     Delete that VM

  apps up      Launch the --apps with 'make run-ci'
  apps wait    Sleep until sample apps have had time to produce metrics
  apps test    Check the expected metrics of the --apps arrived in Mimir
  apps down    Tear the --apps down with 'make stop'

  k3s up       Launch <name>-k3s-main, plus two workers with --cluster; VM sizes
               come from .hardware_requirements in the working directory
  k3s down     Delete that environment

  ci check     Print run=true or run=false: whether CI can test the sample app <name>

Flags:
`

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	if err := run(ctx, os.Args[1:]); err != nil && !errors.Is(err, flag.ErrHelp) {
		fmt.Fprintln(os.Stderr, "sampletool:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, args []string) error {
	flags := flag.NewFlagSet("sampletool", flag.ContinueOnError)
	apps := flags.String("apps", "", "comma-separated sample apps")
	env := flags.String("env", "local", "where the databases run: local (the dbs VM) or k3d")
	dbs := flags.String("dbs", "dbs", "name of the databases VM")
	prometheus := flags.String("prometheus", "", "Mimir host:port for 'apps test', instead of the one --env implies")
	cluster := flags.Bool("cluster", false, "for k3s: also manage two worker nodes")
	flags.Usage = func() {
		fmt.Fprint(flags.Output(), usage)
		flags.PrintDefaults()
	}

	if len(args) < 2 {
		flags.Usage()
		return flag.ErrHelp
	}
	if err := flags.Parse(args[2:]); err != nil {
		return err
	}
	names := 0
	if args[0] == "k3s" || args[0] == "ci" {
		names = 1
	}
	if names == 1 && flags.Arg(0) == "" {
		return fmt.Errorf("%s %s needs a name; run 'sampletool' for usage", args[0], args[1])
	}
	if flags.NArg() > names {
		return fmt.Errorf("unexpected argument %q (flags go before the name; run 'sampletool' for usage)", flags.Arg(names))
	}
	out, err := exec.CommandContext(ctx, "git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		return errors.New("not inside a git checkout of integration-sample-apps")
	}
	root := strings.TrimSpace(string(out))
	var selected []app
	if args[0] == "ci" {
		selected, err = sampleApps(root, flags.Arg(0))
	} else if args[0] == "apps" && args[1] != "wait" {
		selected, err = sampleApps(root, *apps)
	}
	if err != nil {
		return err
	}

	switch command := args[0] + " " + args[1]; command {
	case "dbs up":
		return dbsUp(ctx, root, *dbs, *env == "local")
	case "dbs down":
		return dbsDown(ctx, *dbs)
	case "apps up":
		return appsUp(ctx, selected, *env, *dbs)
	case "apps wait":
		return appsWait(ctx)
	case "apps test":
		return appsTest(ctx, selected, *env, *dbs, *prometheus)
	case "apps down":
		return appsDown(ctx, selected)
	case "k3s up":
		return k3sUp(ctx, root, flags.Arg(0), *cluster)
	case "k3s down":
		return k3sDown(ctx, flags.Arg(0), *cluster)
	case "ci check":
		run, err := ciCheck(selected[0])
		fmt.Printf("run=%t\n", run)
		return err
	default:
		return fmt.Errorf("unknown command %q; run 'sampletool' for usage", command)
	}
}

var httpClient = func() *http.Client {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.DialContext = func(ctx context.Context, network, addr string) (net.Conn, error) {
		if host, port, err := net.SplitHostPort(addr); err == nil && strings.HasSuffix(host, ".localhost") {
			addr = net.JoinHostPort("127.0.0.1", port)
		}
		return new(net.Dialer).DialContext(ctx, network, addr)
	}
	return &http.Client{Transport: transport}
}()

// request returns the body of a successful HTTP response. A body is sent as JSON.
func request(ctx context.Context, method, url string, body []byte) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, method, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(resp.Body)
	if err == nil && resp.StatusCode/100 != 2 {
		err = fmt.Errorf("HTTP %d: %.200s", resp.StatusCode, data)
	}
	return data, err
}
