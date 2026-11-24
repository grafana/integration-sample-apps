package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const trialTimeout = 20 * time.Minute

// agent works on a task's prompt in a trial's copy of the repository.
type agent interface {
	// name is what records call the agent.
	name() string
	run(ctx context.Context, t agentTrial) (agentResult, error)
}

// agentTrial is what an agent gets for one trial.
type agentTrial struct {
	work       string // the trial's copy, where the agent runs
	transcript string // where to save the agent's output
	task       *task
	variant    *variant
	maxTurns   int  // 0 unless --max-turns overrides the task's
	vm         bool // the VM tier: VM commands aren't denied
}

// agentResult is what an agent did in a trial. Only agents whose transcript
// is parsed report turns, cost, denials and commands.
type agentResult struct {
	Turns       int            `json:"turns"`
	CostUSD     float64        `json:"cost_usd"`
	DurationMS  int64          `json:"duration_ms"`
	DeniedCount int            `json:"denied_count"`
	Denied      []denial       `json:"denied"`
	IsError     bool           `json:"is_error"`
	Stop        string         `json:"stop"`
	ToolCalls   map[string]int `json:"tool_calls"`
	Stderr      string         `json:"stderr,omitempty"`
	// Commands are the shell commands the agent ran, when its transcript shows them.
	Commands      []string `json:"-"`
	commandsKnown bool
}

type denial struct {
	Tool  string `json:"tool"`
	Input string `json:"input"`
}

// agentFor picks a variant's agent, or a stand-in that checks the graders
// without a model.
func agentFor(standIn string, v *variant) (agent, error) {
	switch standIn {
	case "reference":
		return referenceAgent{}, nil
	case "noop":
		return noopAgent{}, nil
	case "":
	default:
		return nil, fmt.Errorf("unknown stand-in agent %q (want reference or noop)", standIn)
	}
	switch v.Agent {
	case "", "claude":
		return claude(), nil
	case "command":
		if len(v.Command) == 0 {
			return nil, fmt.Errorf("variant %s: agent: command needs a command", v.name)
		}
		return commandAgent{argv: v.Command}, nil
	default:
		return nil, fmt.Errorf("variant %s: unknown agent %q (want claude or command)", v.name, v.Agent)
	}
}

// turnLimit is the first limit set: --max-turns, the variant's, the task's, or 30.
func (t agentTrial) turnLimit() int {
	for _, n := range []int{t.maxTurns, t.variant.MaxTurns, t.task.MaxTurns} {
		if n > 0 {
			return n
		}
	}
	return 30
}

// commandAgent runs an agent CLI in the trial's copy. In argv, {prompt},
// {model}, {effort} and {max_turns} are replaced, and the variant's args go on
// the end. Support for a particular agent adds what it can:
type commandAgent struct {
	label string
	argv  []string
	// trialArgs adds arguments that depend on the trial, such as permission
	// rules. Without it, the run can't deny the agent anything.
	trialArgs func(agentTrial) []string
	// parse reads the transcript. Without it, a record has only the duration
	// and exit status, and the rules grader can't see the commands run.
	parse func(transcript string) (agentResult, error)
}

func (a commandAgent) name() string {
	if a.label != "" {
		return a.label
	}
	return filepath.Base(a.argv[0])
}

// restricted reports whether the run can deny the agent commands.
func (a commandAgent) restricted() bool { return a.trialArgs != nil }

func (a commandAgent) run(ctx context.Context, t agentTrial) (agentResult, error) {
	v := t.variant
	replacer := strings.NewReplacer("{prompt}", t.task.Prompt, "{model}", v.Model, "{effort}", v.Effort,
		"{max_turns}", strconv.Itoa(t.turnLimit()))
	var argv []string
	for _, arg := range a.argv {
		argv = append(argv, replacer.Replace(arg))
	}
	if a.trialArgs != nil {
		argv = append(argv, a.trialArgs(t)...)
	}
	argv = append(argv, v.Args...)

	out, err := os.Create(t.transcript)
	if err != nil {
		return agentResult{}, err
	}
	defer out.Close()
	ctx, cancel := context.WithTimeout(ctx, trialTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	var stderr bytes.Buffer
	cmd.Dir, cmd.Env, cmd.Stdout, cmd.Stderr = t.work, childEnv(v.Env), out, &stderr
	start := time.Now()
	runErr := cmd.Run()
	var exit *exec.ExitError
	if runErr != nil && !errors.As(runErr, &exit) && ctx.Err() == nil {
		return agentResult{}, runErr // it didn't start
	}

	r := agentResult{Stop: "exit 0"}
	if exit != nil {
		r.IsError, r.Stop = true, fmt.Sprintf("exit %d", exit.ExitCode())
	}
	if a.parse != nil {
		if r, err = a.parse(t.transcript); err != nil {
			return r, err
		}
	}
	if r.DurationMS == 0 {
		r.DurationMS = time.Since(start).Milliseconds()
	}
	if errors.Is(ctx.Err(), context.DeadlineExceeded) {
		r.IsError, r.Stop = true, "timeout"
	}
	if r.IsError {
		r.Stderr = truncate(stderr.String(), 1000)
	}
	return r, nil
}

// childEnv is the environment for agents and VM commands. The settings of
// the session that started the run (CLAUDECODE, CLAUDE_EFFORT and so on) must
// not leak into the agent under test.
func childEnv(extra map[string]string) []string {
	var env []string
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, "CLAUDE") {
			env = append(env, kv)
		}
	}
	for k, v := range extra {
		env = append(env, k+"="+v)
	}
	return env
}

// referenceAgent applies the task's reference fix.
type referenceAgent struct{}

func (referenceAgent) name() string { return "reference" }

func (referenceAgent) run(ctx context.Context, t agentTrial) (agentResult, error) {
	return agentResult{Stop: "reference", commandsKnown: true}, applyPatch(ctx, t.work, t.task, false)
}

// noopAgent changes nothing.
type noopAgent struct{}

func (noopAgent) name() string { return "noop" }

func (noopAgent) run(context.Context, agentTrial) (agentResult, error) {
	return agentResult{Stop: "noop", commandsKnown: true}, nil
}
