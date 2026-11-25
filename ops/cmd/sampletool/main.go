// Command sampletool is the control plane for testing integration sample apps.
package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"strings"

	"github.com/alecthomas/kong"
)

type cli struct {
	DBs struct {
		Up   dbsUpCmd   `cmd:"" help:"Launch the VM running Mimir, Loki and, for --env local, Grafana."`
		Down dbsDownCmd `cmd:"" help:"Delete that VM."`
	} `cmd:"" name:"dbs" help:"The databases that sample apps send to."`

	Apps struct {
		Up   appsUpCmd   `cmd:"" help:"Launch the --apps with 'make run-ci'."`
		Wait appsWaitCmd `cmd:"" help:"Sleep until sample apps have had time to produce metrics."`
		Test appsTestCmd `cmd:"" help:"Check the expected metrics of the --apps arrived in Mimir."`
		Down appsDownCmd `cmd:"" help:"Tear the --apps down with 'make stop'."`
	} `cmd:"" help:"Sample apps."`

	K3s struct {
		Up   k3sUpCmd   `cmd:"" help:"Launch <name>-k3s-main, plus two workers with --cluster. VM sizes come from .hardware_requirements in the working directory."`
		Down k3sDownCmd `cmd:"" help:"Delete that environment."`
	} `cmd:"" name:"k3s" help:"k3s VMs, for sample apps that run on Kubernetes."`

	CI struct {
		Check ciCheckCmd `cmd:"" help:"Print run=true or run=false: whether CI can test the sample app <name>."`
	} `cmd:"" name:"ci" help:"Steps of the CI workflows."`
}

// repoRoot is the top of the integration-sample-apps checkout, found only for
// the commands that use it.
type repoRoot string

func findRepoRoot() (repoRoot, error) {
	out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output()
	if err != nil {
		return "", errors.New("not inside a git checkout of integration-sample-apps")
	}
	return repoRoot(strings.TrimSpace(string(out))), nil
}

type dbsFlag struct {
	DBs string `name:"dbs" default:"dbs" help:"Name of the databases VM."`
}

type envFlag struct {
	Env string `default:"local" enum:"local,k3d" help:"Where the databases run: local (the dbs VM) or k3d."`
}

type appsFlag struct {
	Apps string `required:"" help:"Comma-separated sample apps."`
	apps []app
}

func (f *appsFlag) AfterApply(root repoRoot) (err error) {
	f.apps, err = sampleApps(string(root), f.Apps)
	return err
}

type dbsUpCmd struct {
	dbsFlag `embed:""`
	Env     string `default:"local" enum:"local,qa" help:"local also starts Grafana. CI uses qa."`
}

func (c *dbsUpCmd) Run(ctx context.Context, root repoRoot) error {
	return dbsUp(ctx, string(root), c.DBs, c.Env == "local")
}

type dbsDownCmd struct {
	dbsFlag `embed:""`
}

func (c *dbsDownCmd) Run(ctx context.Context) error {
	return dbsDown(ctx, c.DBs)
}

type appsUpCmd struct {
	appsFlag `embed:""`
	envFlag  `embed:""`
	dbsFlag  `embed:""`
}

func (c *appsUpCmd) Run(ctx context.Context) error {
	return appsUp(ctx, c.apps, c.Env, c.DBs)
}

type appsWaitCmd struct{}

func (c *appsWaitCmd) Run(ctx context.Context) error {
	return appsWait(ctx)
}

type appsTestCmd struct {
	appsFlag   `embed:""`
	envFlag    `embed:""`
	dbsFlag    `embed:""`
	Prometheus string `help:"Mimir host:port, instead of the one --env implies."`
}

func (c *appsTestCmd) Run(ctx context.Context) error {
	return appsTest(ctx, c.apps, c.Env, c.DBs, c.Prometheus)
}

type appsDownCmd struct {
	appsFlag `embed:""`
}

func (c *appsDownCmd) Run(ctx context.Context) error {
	return appsDown(ctx, c.apps)
}

type k3sUpCmd struct {
	Cluster bool   `help:"Also launch two worker nodes."`
	Name    string `arg:"" help:"Prefix of the VM names."`
}

func (c *k3sUpCmd) Run(ctx context.Context, root repoRoot) error {
	return k3sUp(ctx, string(root), c.Name, c.Cluster)
}

type k3sDownCmd struct {
	Cluster bool   `help:"Also delete the two worker nodes."`
	Name    string `arg:"" help:"Prefix of the VM names."`
}

func (c *k3sDownCmd) Run(ctx context.Context) error {
	return k3sDown(ctx, c.Name, c.Cluster)
}

type ciCheckCmd struct {
	Name string `arg:"" help:"The sample app."`
}

func (c *ciCheckCmd) Run(root repoRoot) error {
	apps, err := sampleApps(string(root), c.Name)
	if err != nil {
		return err
	}
	run, err := ciCheck(apps[0])
	fmt.Printf("run=%t\n", run)
	return err
}

func newParser(ctx context.Context, options ...kong.Option) (*kong.Kong, error) {
	return kong.New(&cli{}, append([]kong.Option{
		kong.Name("sampletool"),
		kong.Description("Control plane for integration sample apps."),
		kong.UsageOnError(),
		kong.BindTo(ctx, (*context.Context)(nil)),
		kong.BindToProvider(findRepoRoot),
	}, options...)...)
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	parser, err := newParser(ctx)
	if err != nil {
		panic(err)
	}
	command, err := parser.Parse(os.Args[1:])
	parser.FatalIfErrorf(err)
	parser.FatalIfErrorf(command.Run())
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
