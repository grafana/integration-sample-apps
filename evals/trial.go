package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// record is one trial, as a line of a results file.
type record struct {
	TS          string           `json:"ts"`
	Run         string           `json:"run"`
	Task        string           `json:"task"`
	Kind        string           `json:"kind"`
	Variant     string           `json:"variant"`
	VariantHash string           `json:"variant_hash"`
	Model       string           `json:"model"`
	Agent       string           `json:"agent"`
	Trial       int              `json:"trial"`
	Tier        string           `json:"tier"`
	Source      sourceInfo       `json:"source"`
	Pass        bool             `json:"pass"`
	Graders     map[string]grade `json:"graders,omitempty"`
	Files       []string         `json:"files_changed,omitempty"`
	agentResult
	// CommandsRun is unset when the agent's transcript doesn't show its commands.
	CommandsRun *int   `json:"commands_run,omitempty"`
	Error       string `json:"error,omitempty"`
}

// trialSpec is everything one trial needs.
type trialSpec struct {
	run      *runState
	variant  *variant
	task     *task
	agent    agent
	n        int
	maxTurns int
}

// runTrial prepares a copy of the snapshot, runs the agent in it and grades
// the result. A failure is recorded rather than returned, so one broken trial
// doesn't stop the run.
func runTrial(ctx context.Context, s trialSpec) record {
	r := s.run
	name := fmt.Sprintf("%s-%d", s.task.name, s.n)
	rec := record{
		TS: time.Now().Format(time.RFC3339), Run: r.id, Task: s.task.name, Kind: s.task.Kind,
		Variant: s.variant.name, Model: s.variant.Model, Agent: s.agent.name(), Trial: s.n,
		Tier: map[bool]string{false: "static", true: "vm"}[r.vm], Source: r.source,
	}
	work := filepath.Join(r.dir, "work", s.variant.name, name)
	if !r.keep {
		defer os.RemoveAll(work)
	}
	if err := gradeTrial(ctx, s, work, filepath.Join(r.logs, s.variant.name, name), &rec); err != nil {
		rec.Pass, rec.Error = false, head(err.Error(), 1000)
	}
	return rec
}

func gradeTrial(ctx context.Context, s trialSpec, work, logs string, rec *record) error {
	var err error
	if rec.VariantHash, err = hashFiles(s.variant.dir, append(harnessFiles, "variant.yaml")); err != nil {
		return err
	}
	base, err := prepare(ctx, work, s.run.src, s.variant, s.task)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(logs), 0o755); err != nil {
		return err
	}
	before := lint(ctx, work)

	agent, err := s.agent.run(ctx, agentTrial{work: work, transcript: logs + ".jsonl", task: s.task,
		variant: s.variant, maxTurns: s.maxTurns, vm: s.run.vm})
	if err != nil {
		return err
	}
	rec.agentResult = agent
	if agent.commandsKnown {
		n := len(agent.Commands)
		rec.CommandsRun = &n
	}

	changed, ignored, diff, err := changes(ctx, work, base)
	if err != nil {
		return err
	}
	if err := os.WriteFile(logs+".diff", []byte(diff), 0o644); err != nil {
		return err
	}
	after := lint(ctx, work)
	original := func(path string) string {
		out, _ := git(ctx, work, "show", base+":"+path)
		return out
	}
	g := map[string]grade{
		"lint":   gradeLint(before, after),
		"scope":  gradeScope(changed, s.task),
		"rules":  gradeRules(work, original, changed, agent.Commands),
		"strays": gradeStrays(changed, ignored),
	}
	if len(s.task.Graders.LintFixed) > 0 {
		g["lint_fixed"] = gradeLintFixed(after, s.task)
	}
	if len(s.task.Graders.Checks) > 0 {
		g["reference"] = gradeReference(ctx, work, s.run.src, s.task.Graders.Checks)
	}
	if s.run.vm && len(s.task.VM.Commands) > 0 {
		g["vm"] = gradeVM(ctx, work, s.task.VM.Commands, s.variant.Env)
	}
	rec.Graders, rec.Files = g, sortedKeys(changed)
	rec.Pass = !agent.IsError
	for _, v := range g {
		rec.Pass = rec.Pass && v.Pass
	}
	return nil
}

// prepare copies the snapshot to work, swaps in the variant's harness files,
// plants the task's bug and commits the result as the only commit of a new
// repository, so git log can't show the agent the bug. It returns that commit.
func prepare(ctx context.Context, work, src string, v *variant, t *task) (string, error) {
	if err := copyTree(src, work, false); err != nil {
		return "", err
	}
	for _, name := range harnessFiles {
		if err := os.RemoveAll(filepath.Join(work, name)); err != nil {
			return "", err
		}
		from := filepath.Join(v.dir, name)
		if _, err := os.Stat(from); err == nil {
			if err := copyEntry(from, filepath.Join(work, name), true); err != nil {
				return "", err
			}
		}
	}
	_ = os.Remove(filepath.Join(work, ".claude", "settings.local.json"))
	if err := applyPatch(ctx, work, t, true); err != nil {
		return "", err
	}
	for _, args := range [][]string{
		{"init", "-q", "-b", "main"},
		{"add", "-A"},
		{"-c", "user.name=eval", "-c", "user.email=eval@localhost", "commit", "-q", "-m", "Initial commit"},
	} {
		if _, err := git(ctx, work, args...); err != nil {
			return "", err
		}
	}
	out, err := git(ctx, work, "rev-parse", "HEAD")
	return strings.TrimSpace(out), err
}

// applyPatch applies the task's reference fix, or in reverse its seed.
func applyPatch(ctx context.Context, work string, t *task, reverse bool) error {
	args := []string{"apply", "--whitespace=nowarn"}
	if reverse {
		args = append(args, "-R")
	}
	if _, err := git(ctx, work, append(args, filepath.Join(t.dir, "reference.patch"))...); err != nil {
		return fmt.Errorf("reference.patch doesn't apply to this checkout: %w", err)
	}
	return nil
}

// changes returns the status of each path that differs from base, the
// ignored files, and the diff.
func changes(ctx context.Context, work, base string) (map[string]string, []string, string, error) {
	if _, err := git(ctx, work, "add", "-A"); err != nil {
		return nil, nil, "", err
	}
	nameStatus, err := git(ctx, work, "diff", "--cached", "--name-status", "--no-renames", base)
	if err != nil {
		return nil, nil, "", err
	}
	changed := map[string]string{}
	for _, line := range strings.Split(strings.TrimSpace(nameStatus), "\n") {
		if code, path, ok := strings.Cut(line, "\t"); ok {
			changed[path] = code
		}
	}
	status, err := git(ctx, work, "status", "--porcelain", "--ignored", "--untracked-files=all")
	if err != nil {
		return nil, nil, "", err
	}
	var ignored []string
	for _, line := range strings.Split(status, "\n") {
		if path, ok := strings.CutPrefix(line, "!! "); ok {
			ignored = append(ignored, path)
		}
	}
	diff, err := git(ctx, work, "diff", "--cached", base)
	return changed, ignored, diff, err
}
