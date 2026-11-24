package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// sourceInfo describes the checkout a run snapshotted.
type sourceInfo struct {
	Path    string `json:"path"`
	Ref     string `json:"ref"`
	Head    string `json:"head"`
	Dirty   bool   `json:"dirty"`
	Content string `json:"content"`
}

// output runs a command in dir and returns its stdout, with stderr in the error.
func output(ctx context.Context, dir, name string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Dir = dir
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return string(out), fmt.Errorf("%s %s: %w: %s", name, strings.Join(args, " "), err, truncate(stderr.String(), 500))
	}
	return string(out), nil
}

func git(ctx context.Context, dir string, args ...string) (string, error) {
	return output(ctx, dir, "git", append([]string{"-c", "core.quotepath=off"}, args...)...)
}

// snapshot copies source's tracked and untracked files that aren't ignored,
// uncommitted changes included, or the tree at ref, to out. It leaves out
// evals/, so agents can't read the tasks, and never changes source's git state.
func snapshot(ctx context.Context, source, ref, out string) (sourceInfo, error) {
	info := sourceInfo{Path: source, Ref: "worktree"}
	if home, err := os.UserHomeDir(); err == nil && strings.HasPrefix(source, home) {
		info.Path = "~" + strings.TrimPrefix(source, home) // results may be committed
	}
	if err := os.MkdirAll(out, 0o755); err != nil {
		return info, err
	}
	if ref != "" {
		info.Ref = ref
		tarball := out + ".tar"
		if _, err := git(ctx, source, "archive", "-o", tarball, ref); err != nil {
			return info, err
		}
		if _, err := output(ctx, out, "tar", "-xf", tarball); err != nil {
			return info, err
		}
	} else {
		listed, err := git(ctx, source, "ls-files", "-co", "--exclude-standard", "-z")
		if err != nil {
			return info, err
		}
		for _, f := range strings.Split(listed, "\x00") {
			if f == "" {
				continue
			}
			if _, err := os.Lstat(filepath.Join(source, f)); os.IsNotExist(err) {
				continue // deleted but not yet committed
			}
			if err := copyEntry(filepath.Join(source, f), filepath.Join(out, f), false); err != nil {
				return info, err
			}
		}
		status, err := git(ctx, source, "status", "--porcelain")
		if err != nil {
			return info, err
		}
		info.Dirty = status != ""
	}
	if err := os.RemoveAll(filepath.Join(out, "evals")); err != nil {
		return info, err
	}
	headSHA, err := git(ctx, source, "rev-parse", "--short", "HEAD")
	if err != nil {
		return info, err
	}
	info.Head = strings.TrimSpace(headSHA)
	info.Content, err = hashFiles(out, []string{"."})
	return info, err
}

// copyTree copies src to dst, keeping symlinks as links unless follow is set,
// and leaving out any directory named in skip.
func copyTree(src, dst string, follow bool, skip ...string) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, path)
		if info.IsDir() {
			for _, s := range skip {
				if info.Name() == s {
					return filepath.SkipDir
				}
			}
			return os.MkdirAll(filepath.Join(dst, rel), 0o755)
		}
		return copyEntry(path, filepath.Join(dst, rel), follow)
	})
}

// copyEntry copies a file, directory or symlink, creating dst's parent directories.
// With follow, a symlink is copied as what it points to, directories included.
func copyEntry(src, dst string, follow bool) error {
	info, err := os.Lstat(src)
	if err != nil {
		return err
	}
	if info.IsDir() {
		return copyTree(src, dst, follow)
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	if info.Mode()&os.ModeSymlink != 0 {
		if !follow {
			target, err := os.Readlink(src)
			if err != nil {
				return err
			}
			return os.Symlink(target, dst)
		}
		if info, err = os.Stat(src); err != nil {
			return err
		}
		if info.IsDir() {
			real, err := filepath.EvalSymlinks(src)
			if err != nil {
				return err
			}
			return copyTree(real, dst, true)
		}
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, info.Mode().Perm())
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}

// readFile returns a file's contents, and false when it doesn't exist.
func readFile(path string) (string, bool) {
	data, err := os.ReadFile(path)
	return string(data), err == nil
}
