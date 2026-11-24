package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"golang.org/x/sync/errgroup"
)

// runState is what every trial of a run shares.
type runState struct {
	id     string
	dir    string // temporary: the snapshot and the trials' copies
	src    string // the snapshot
	logs   string // results/runs/<id>: transcripts and diffs
	vm     bool
	keep   bool
	source sourceInfo
}

type stringList []string

func (s *stringList) String() string     { return strings.Join(*s, ",") }
func (s *stringList) Set(v string) error { *s = append(*s, v); return nil }

func runCmd(ctx context.Context, args []string) error {
	flags := flag.NewFlagSet("evals", flag.ContinueOnError)
	var variantNames stringList
	flags.Var(&variantNames, "variant", "a variant to run; repeat for several (default current)")
	tasksFlag := flags.String("tasks", "", "comma-separated tasks (default every task in the tier)")
	trials := flags.Int("trials", 3, "trials per task and variant")
	jobs := flags.Int("jobs", 3, "trials to run at once")
	vm := flags.Bool("vm", false, "run the VM tier, one trial at a time")
	model := flags.String("model", "", "override each variant's model")
	maxTurns := flags.Int("max-turns", 0, "override each task's turn limit")
	standIn := flags.String("agent", "", "reference or noop: check the graders with a stand-in instead of each variant's agent")
	source := flags.String("source", "..", "the checkout to snapshot")
	ref := flags.String("ref", "", "snapshot this commit instead of the working tree")
	keep := flags.Bool("keep", false, "keep the trial directories to inspect")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() > 0 {
		return fmt.Errorf("unexpected argument %q", flags.Arg(0))
	}

	evals, err := evalsDir()
	if err != nil {
		return err
	}
	if len(variantNames) == 0 {
		variantNames = stringList{"current"}
	}
	var variants []*variant
	agents := map[string]agent{}
	for _, name := range variantNames {
		v, err := loadVariant(evals, name)
		if err != nil {
			return err
		}
		if *model != "" {
			v.Model = *model
		}
		if agents[name], err = agentFor(*standIn, v); err != nil {
			return err
		}
		variants = append(variants, v)
	}
	names := strings.Split(*tasksFlag, ",")
	if *tasksFlag == "" {
		if names, err = taskNames(evals, *vm); err != nil {
			return err
		}
	}
	var tasks []*task
	for _, name := range names {
		t, err := loadTask(evals, name)
		if err != nil {
			return err
		}
		tasks = append(tasks, t)
	}
	if *vm && *jobs != 1 {
		fmt.Fprintln(os.Stderr, "--vm runs one trial at a time: parallel Multipass launches break VMs")
		*jobs = 1
	}
	for _, v := range variants {
		a, ok := agents[v.name].(commandAgent)
		switch {
		case !ok: // a stand-in
		case a.name() == "claude" && !claudeLoggedIn(ctx):
			return errors.New("claude isn't logged in: run 'claude auth login' first")
		case !a.restricted():
			fmt.Fprintf(os.Stderr, "%s: evals can't restrict what %s runs, so its command must sandbox it\n", v.name, a.name())
		}
	}

	sourceDir, err := filepath.Abs(*source)
	if err != nil {
		return err
	}
	// The physical path, so agents never see their directory as outside
	// themselves (/var is /private/var on macOS).
	tmp, err := filepath.EvalSymlinks(os.TempDir())
	if err != nil {
		return err
	}
	now := time.Now()
	r := &runState{id: fmt.Sprintf("%s-%d", now.Format("20060102-150405"), os.Getpid()), vm: *vm, keep: *keep}
	r.dir = filepath.Join(tmp, "sampleapps-evals", r.id)
	r.src = filepath.Join(r.dir, "src")
	r.logs = filepath.Join(evals, "results", "runs", r.id)
	if !*keep {
		defer os.RemoveAll(r.dir)
	}
	if *ref != "" {
		fmt.Printf("Snapshotting %s at %s\n", sourceDir, *ref)
	} else {
		fmt.Printf("Snapshotting %s (uncommitted changes included)\n", sourceDir)
	}
	if r.source, err = snapshot(ctx, sourceDir, *ref, r.src); err != nil {
		return err
	}
	// Warm Go's build cache, so the first lint in each trial is quick.
	if _, err := output(ctx, r.src, "go", "build", "-o", os.DevNull, "./ops/cmd/sampletool"); err != nil {
		return err
	}

	var specs []trialSpec
	results := map[string]string{}
	for _, v := range variants {
		// Only real agents' results are kept; the stand-ins only check the graders.
		results[v.name] = filepath.Join(evals, "results", now.Format("2006-01-02")+"-"+v.name+".jsonl")
		if *standIn != "" {
			results[v.name] = filepath.Join(r.logs, *standIn+"-"+v.name+".jsonl")
		}
		for _, t := range tasks {
			for n := 1; n <= *trials; n++ {
				specs = append(specs, trialSpec{run: r, variant: v, agent: agents[v.name], task: t, n: n, maxTurns: *maxTurns})
			}
		}
	}
	if err := os.MkdirAll(r.logs, 0o755); err != nil {
		return err
	}

	fmt.Printf("Running %d trials (%s tier, %d at a time)\n", len(specs),
		map[bool]string{false: "static", true: "vm"}[*vm], *jobs)
	var mu sync.Mutex // guards the results files and the output
	var g errgroup.Group
	g.SetLimit(*jobs)
	for _, s := range specs {
		g.Go(func() error {
			rec := runTrial(ctx, s)
			mu.Lock()
			defer mu.Unlock()
			fmt.Println(summary(rec))
			return appendRecord(results[s.variant.name], rec)
		})
	}
	if err := g.Wait(); err != nil {
		return err
	}
	if err := ctx.Err(); err != nil {
		return err
	}

	fmt.Println()
	for _, v := range variants {
		if err := compareCmd([]string{results[v.name], "--run", r.id}, os.Stdout); err != nil {
			return err
		}
		fmt.Println()
	}
	if *keep {
		fmt.Println("Kept trial directories in", filepath.Join(r.dir, "work"))
	}
	fmt.Println("Transcripts and diffs:", r.logs)
	return nil
}

// evalsDir is the working directory, which must be evals/.
func evalsDir() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	if _, err := os.Stat(filepath.Join(dir, "tasks")); err != nil {
		return "", errors.New("run from evals/: go -C evals run .")
	}
	return dir, nil
}

func appendRecord(path string, rec record) error {
	line, err := json.Marshal(rec)
	if err != nil {
		return err
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	if _, err := f.Write(append(line, '\n')); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}

func summary(rec record) string {
	s := fmt.Sprintf("%s %s/%s-%d", map[bool]string{true: "PASS", false: "FAIL"}[rec.Pass], rec.Variant, rec.Task, rec.Trial)
	if rec.CostUSD > 0 {
		s += fmt.Sprintf(" turns=%d cost=$%.2f", rec.Turns, rec.CostUSD)
	}
	var failed []string
	for _, name := range sortedKeys(rec.Graders) {
		if !rec.Graders[name].Pass {
			failed = append(failed, name)
		}
	}
	if len(failed) > 0 {
		s += " failed=" + strings.Join(failed, ",")
	}
	if rec.IsError {
		s += " stop=" + rec.Stop
	}
	if rec.Error != "" {
		s += " error=" + rec.Error
	}
	return s
}
