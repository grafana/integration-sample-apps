package main

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// fakeMultipass puts a stand-in multipass on PATH that fails every command
// except the ones listed.
func fakeMultipass(t *testing.T, working ...string) {
	t.Helper()
	dir := t.TempDir()
	script := "#!/bin/sh\ncase \"$1\" in " + strings.Join(append(working, "-"), "|") + ") exit 0;; esac\nexit 1\n"
	if err := os.WriteFile(filepath.Join(dir, "multipass"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", dir)
}

func TestK3sDownToleratesMissingVMs(t *testing.T) {
	fakeMultipass(t, "purge")
	if err := k3sDown(context.Background(), "demo", true); err != nil {
		t.Errorf("with only purge working: %v", err)
	}
	fakeMultipass(t)
	if err := k3sDown(context.Background(), "demo", true); err == nil {
		t.Error("with multipass failing entirely: want an error")
	}
}
