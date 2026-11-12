package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"maps"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/joho/godotenv"
)

// command runs a program in dir, streaming its output to the terminal.
func command(ctx context.Context, dir, name string, args ...string) error {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir, cmd.Stdin, cmd.Stdout, cmd.Stderr = dir, os.Stdin, os.Stdout, os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("%s %s: %w", name, strings.Join(args, " "), err)
	}
	return nil
}

func multipass(ctx context.Context, args ...string) error {
	return command(ctx, "", "multipass", args...)
}

func multipassOutput(ctx context.Context, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "multipass", args...)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("multipass %s: %w", strings.Join(args, " "), err)
	}
	return strings.TrimSpace(string(out)), nil
}

// multipassIP returns the first (internal) IPv4 address of a VM.
func multipassIP(ctx context.Context, vm string) (string, error) {
	out, err := multipassOutput(ctx, "info", vm, "--format", "json")
	if err != nil {
		return "", err
	}
	var info struct {
		Info map[string]struct{ IPv4 []string }
	}
	if err := json.Unmarshal([]byte(out), &info); err != nil || len(info.Info[vm].IPv4) == 0 {
		return "", fmt.Errorf("multipass instance %q has no IPv4 address (is it running?)", vm)
	}
	return info.Info[vm].IPv4[0], nil
}

const ubuntuRelease = "24.04"

// dockerCloudInit is Canonical's cloud-init for a VM with Docker installed.
const dockerCloudInit = "https://raw.githubusercontent.com/canonical/multipass/refs/heads/main/data/cloud-init-yaml/cloud-init-docker.yaml"

// dbsUp launches the databases VM and starts Mimir, Loki and optionally Grafana in it.
func dbsUp(ctx context.Context, root, name string, grafana bool) error {
	files, err := filepath.Glob(filepath.Join(root, "ops", "qa", "dbs", "*"))
	if err != nil || len(files) == 0 {
		return errors.New("no files found in ops/qa/dbs")
	}
	steps := [][]string{
		{"launch", ubuntuRelease, "--name", name, "--cpus", "2", "--memory", "4G", "--disk", "40G", "--cloud-init", dockerCloudInit},
		append(append([]string{"transfer", "--recursive"}, files...), name+":/home/ubuntu"),
		{"exec", name, "--", "bash", "-c", "docker-compose -f docker-compose.yaml up -d"},
	}
	if grafana {
		fmt.Println("Configuring extras for local development")
		steps = append(steps, []string{"exec", name, "--", "bash", "-c", "docker-compose -f docker-compose.grafana.yaml up -d"})
	}
	for _, step := range steps {
		if err := multipass(ctx, step...); err != nil {
			return err
		}
	}

	ip, err := multipassIP(ctx, name)
	if err != nil {
		return err
	}
	fmt.Println("IP of database deployment:")
	fmt.Println(ip)
	return nil
}

func dbsDown(ctx context.Context, name string) error {
	fmt.Println("Deleting databases")
	return errors.Join(multipass(ctx, "delete", name), multipass(ctx, "purge"))
}

const hardwareFile = ".hardware_requirements"

func k3sWorkers(name string) []string {
	return []string{name + "-k3s-worker-1", name + "-k3s-worker-2"}
}

// k3sUp launches <name>-k3s-main and, in cluster mode, two workers joined to
// it. A .hardware_requirements file in the working directory overrides the VM sizes.
func k3sUp(ctx context.Context, root, name string, cluster bool) error {
	// Cores, and gigabytes of memory and disk.
	hw := map[string]string{
		"PRIMARY_CPU": "4", "PRIMARY_MEMORY": "6", "PRIMARY_DISK": "20",
		"WORKER_CPU": "2", "WORKER_MEMORY": "6", "WORKER_DISK": "20",
	}
	overrides, err := godotenv.Read(hardwareFile)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return fmt.Errorf("%s: %w", hardwareFile, err)
	}
	maps.Copy(hw, overrides)
	launch := func(vm, role string, extra ...string) error {
		cpus, memory, disk := hw[role+"_CPU"], hw[role+"_MEMORY"]+"G", hw[role+"_DISK"]+"G"
		fmt.Printf("-- Launching %s: %s CPUs, %s memory, %s disk --\n", vm, cpus, memory, disk)
		args := []string{"launch", ubuntuRelease, "--name", vm, "--cpus", cpus, "--memory", memory, "--disk", disk}
		return multipass(ctx, append(args, extra...)...)
	}

	main := name + "-k3s-main"
	if err := launch(main, "PRIMARY", "--cloud-init", filepath.Join(root, "ops", "qa", "k3s-main-cloud-init.yaml")); err != nil || !cluster {
		return err
	}
	token, err := multipassOutput(ctx, "exec", main, "--", "sudo", "cat", "/var/lib/rancher/k3s/server/node-token")
	if err != nil {
		return err
	}
	ip, err := multipassIP(ctx, main)
	if err != nil {
		return err
	}
	join := fmt.Sprintf(`curl -sfL https://get.k3s.io | K3S_URL="https://%s:6443" K3S_TOKEN="%s" sh -`, ip, token)
	for _, worker := range k3sWorkers(name) {
		if err := launch(worker, "WORKER"); err != nil {
			return err
		}
		if err := multipass(ctx, "exec", worker, "--", "bash", "-c", join); err != nil {
			return err
		}
	}
	return nil
}

// k3sDown destroys the environment. Only the final purge decides the result,
// so VMs that are already gone do not fail `make stop`.
func k3sDown(ctx context.Context, name string, cluster bool) error {
	fmt.Printf("-- Destroying k3s environment for %s --\n", name)
	main := name + "-k3s-main"
	multipass(ctx, "stop", main)
	multipass(ctx, "delete", main)
	if cluster {
		fmt.Println("-- Cluster mode, tearing down worker nodes --")
		multipass(ctx, append([]string{"stop"}, k3sWorkers(name)...)...)
		multipass(ctx, append([]string{"delete"}, k3sWorkers(name)...)...)
	}
	return multipass(ctx, "purge")
}
