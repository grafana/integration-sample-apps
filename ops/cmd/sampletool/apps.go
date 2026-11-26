package main

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"time"
)

// app is one directory below sample-apps/.
type app struct{ name, dir string }

// sampleApps resolves a comma-separated list of sample-app names.
func sampleApps(root, list string) ([]app, error) {
	var apps []app
	for _, name := range strings.Split(list, ",") {
		if name == "" {
			continue
		}
		dir := filepath.Join(root, sampleAppsDir, name)
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

// metricsFiles lists the app's expected-metrics files, sorted by name. Hidden
// files, such as macOS's .DS_Store, and directories are skipped.
func (a app) metricsFiles() []string {
	dir := filepath.Join(a.dir, metricsDir)
	entries, _ := os.ReadDir(dir)
	var files []string
	for _, entry := range entries {
		if !entry.IsDir() && !strings.HasPrefix(entry.Name(), ".") {
			files = append(files, filepath.Join(dir, entry.Name()))
		}
	}
	return files
}

// endpoints returns the Mimir and Loki host:port of an environment.
func endpoints(ctx context.Context, env, dbsName string) (prometheus, loki string, err error) {
	switch env {
	case "local":
		ip, err := multipassIP(ctx, dbsName)
		return net.JoinHostPort(ip, mimirPort), net.JoinHostPort(ip, lokiPort), err
	case "k3d":
		return net.JoinHostPort(k3dMimirHost, k3dPort), net.JoinHostPort(k3dLokiHost, k3dPort), nil
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
		var before map[string]bool
		if env == "k3d" {
			if before, err = multipassVMs(ctx); err != nil {
				return err
			}
		}
		fmt.Printf("-- Spawning sample-app %s --\n", a.name)
		if err := command(ctx, a.dir, "make", "PROMETHEUS_INSTANCE="+prometheus, "LOKI_INSTANCE="+loki, "run-ci"); err != nil {
			return err
		}
		if env == "k3d" {
			after, err := multipassVMs(ctx)
			if err != nil {
				return err
			}
			launched := newVMs(before, after)
			if len(launched) == 0 {
				return fmt.Errorf("%s launched no Multipass VMs to add the k3d hostnames to", a.name)
			}
			for _, vm := range launched {
				if err := configureK3dDNS(ctx, vm); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

// newVMs returns the VMs in after that aren't in before, sorted by name.
func newVMs(before, after map[string]bool) []string {
	var vms []string
	for vm := range after {
		if !before[vm] {
			vms = append(vms, vm)
		}
	}
	slices.Sort(vms)
	return vms
}

// k3dHostsScript replaces the VM's /etc/hosts entry for the k3d hostnames with
// one for the address in $1.
var k3dHostsScript = fmt.Sprintf(`sed -i '/[[:space:]]%s[[:space:]]/d' /etc/hosts && echo "$1 %s %s" >> /etc/hosts`,
	regexp.QuoteMeta(k3dLokiHost), k3dLokiHost, k3dMimirHost)

// configureK3dDNS points loki.k3d.localhost and mimir.k3d.localhost at the VM's
// DNS server, which is the host that runs k3d.
func configureK3dDNS(ctx context.Context, vm string) error {
	status, err := multipassOutput(ctx, "exec", vm, "--", "resolvectl", "status")
	if err != nil {
		return err
	}
	ip, ok := currentDNSServer(status)
	if !ok {
		return fmt.Errorf("%s: resolvectl status shows no IPv4 DNS server", vm)
	}
	fmt.Printf("Pointing the k3d hostnames at %s on %s\n", ip, vm)
	return multipass(ctx, "exec", vm, "--", "sudo", "sh", "-c", k3dHostsScript, "sh", ip)
}

var dnsServerLine = regexp.MustCompile(`Current DNS Server:\s*(\S+)`)

// currentDNSServer returns the first IPv4 "Current DNS Server" in the output of
// resolvectl status.
func currentDNSServer(status string) (string, bool) {
	for _, m := range dnsServerLine.FindAllStringSubmatch(status, -1) {
		if addr, err := netip.ParseAddr(m[1]); err == nil && addr.Is4() {
			return addr.String(), true
		}
	}
	return "", false
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
	bypass := exists(filepath.Join(a.dir, ciBypassFile))
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
