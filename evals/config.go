package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"go.yaml.in/yaml/v3"
)

// harnessFiles are the files a variant replaces in each trial's copy.
var harnessFiles = []string{"AGENTS.md", "CLAUDE.md", ".claude"}

// task is tasks/<name>/task.yaml. Its seed is tasks/<name>/reference.patch,
// applied in reverse, and the reference agent applies it forwards.
type task struct {
	name     string
	dir      string
	Kind     string `yaml:"kind"`
	Source   string `yaml:"source"`
	Tier     string `yaml:"tier"`
	MaxTurns int    `yaml:"max_turns"`
	Prompt   string `yaml:"prompt"`
	// Rubric says what a full-marks fix looks like, for people reading transcripts.
	Rubric  string `yaml:"rubric"`
	Graders struct {
		Scope struct {
			Allowed   []string `yaml:"allowed"`
			Forbidden []string `yaml:"forbidden"`
			Required  []string `yaml:"required"`
		} `yaml:"scope"`
		LintFixed []struct {
			App      string `yaml:"app"`
			Contains string `yaml:"contains"`
		} `yaml:"lint_fixed"`
		Checks []check `yaml:"checks"`
	} `yaml:"graders"`
	VM struct {
		Commands []string `yaml:"commands"`
	} `yaml:"vm"`
}

// check is one of a task's reference checks. Type picks which fields apply.
type check struct {
	Name string `yaml:"name"`
	Type string `yaml:"type"` // regex, same_as_reference, keep_regex_covers or command

	Files   []string `yaml:"files"`   // regex
	Pattern string   `yaml:"pattern"` // regex
	Expect  string   `yaml:"expect"`  // regex: present (the default) in every file, or absent from all

	File string `yaml:"file"` // same_as_reference, keep_regex_covers
	Mode string `yaml:"mode"` // same_as_reference: lines (the default) or tokens

	MetricsFile string   `yaml:"metrics_file"` // keep_regex_covers
	Skip        []string `yaml:"skip"`         // keep_regex_covers

	Run     string `yaml:"run"`     // command
	Timeout int    `yaml:"timeout"` // command, in seconds
}

// variant is variants/<name>/variant.yaml plus the harness files beside it.
type variant struct {
	name        string
	dir         string
	Description string            `yaml:"description"`
	Model       string            `yaml:"model"`
	Effort      string            `yaml:"effort"`
	MaxTurns    int               `yaml:"max_turns"`
	Env         map[string]string `yaml:"env"`
	Args        []string          `yaml:"args"`
}

// readYAML decodes a file strictly, so a misspelt key is an error.
func readYAML(path string, v any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	dec := yaml.NewDecoder(bytes.NewReader(data))
	dec.KnownFields(true)
	if err := dec.Decode(v); err != nil {
		return fmt.Errorf("%s: %w", path, err)
	}
	return nil
}

func loadTask(evals, name string) (*task, error) {
	t := &task{name: name, dir: filepath.Join(evals, "tasks", name)}
	if err := readYAML(filepath.Join(t.dir, "task.yaml"), t); err != nil {
		return nil, fmt.Errorf("task %s: %w", name, err)
	}
	if t.Tier == "" {
		t.Tier = "static"
	}
	return t, nil
}

// taskNames lists every task, or only static ones unless vm is set.
func taskNames(evals string, vm bool) ([]string, error) {
	paths, err := filepath.Glob(filepath.Join(evals, "tasks", "*", "task.yaml"))
	if err != nil {
		return nil, err
	}
	var names []string
	for _, p := range paths {
		name := filepath.Base(filepath.Dir(p))
		t, err := loadTask(evals, name)
		if err != nil {
			return nil, err
		}
		if t.Tier == "static" || vm {
			names = append(names, name)
		}
	}
	return names, nil
}

func loadVariant(evals, name string) (*variant, error) {
	v := &variant{name: name, dir: filepath.Join(evals, "variants", name)}
	if err := readYAML(filepath.Join(v.dir, "variant.yaml"), v); err != nil {
		return nil, fmt.Errorf("variant %s: %w", name, err)
	}
	return v, nil
}

// hashFiles returns a short hash of the named files and directories below
// root, following symlinks, so a record shows when a variant changed.
func hashFiles(root string, names []string) (string, error) {
	h := sha256.New()
	for _, name := range names {
		files, err := regularFiles(filepath.Join(root, name))
		if err != nil {
			return "", err
		}
		for _, f := range files {
			data, err := os.ReadFile(f)
			if err != nil {
				return "", err
			}
			rel, _ := filepath.Rel(root, f)
			h.Write([]byte(rel))
			h.Write(data)
		}
	}
	return hex.EncodeToString(h.Sum(nil))[:12], nil
}

// regularFiles lists the files at or below path, sorted, following symlinks
// and leaving out settings.local.json. A missing path has none.
func regularFiles(path string) ([]string, error) {
	info, err := os.Stat(path)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if !info.IsDir() {
		return []string{path}, nil
	}
	real, err := filepath.EvalSymlinks(path)
	if err != nil {
		return nil, err
	}
	var files []string
	err = filepath.WalkDir(real, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || d.Name() == "settings.local.json" {
			return err
		}
		rel, _ := filepath.Rel(real, p)
		sub, err := regularFiles(filepath.Join(path, rel))
		files = append(files, sub...)
		return err
	})
	slices.Sort(files)
	return files, err
}

// truncate shortens s to its last n bytes, for error output.
func truncate(s string, n int) string {
	s = strings.TrimSpace(s)
	if len(s) > n {
		return s[len(s)-n:]
	}
	return s
}

// head shortens s to its first n bytes, for details.
func head(s string, n int) string {
	if len(s) > n {
		return s[:n]
	}
	return s
}
