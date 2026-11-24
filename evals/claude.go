package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"time"
)

// baseAllowed is granted to every variant on top of its own
// .claude/settings.json: read-only shell commands, plus edits.
var baseAllowed = []string{
	"Read", "Glob", "Grep", "Edit", "Write",
	"Bash(ls *)", "Bash(ls)", "Bash(cat *)", "Bash(head *)", "Bash(tail *)", "Bash(wc *)",
	"Bash(grep *)", "Bash(diff *)", "Bash(sort *)",
	"Bash(git status *)", "Bash(git status)", "Bash(git diff *)", "Bash(git diff)",
	"Bash(git log *)", "Bash(git show *)",
}

// alwaysDenied is denied in every run, whatever the variant allows. Attempts
// still show in the transcript, where the rules grader counts them.
var alwaysDenied = []string{
	"Bash(make stop-all*)", "Bash(multipass delete*)", "Bash(multipass purge*)", "Bash(git push*)",
}

// staticDenied is denied in the static tier: anything that starts, stops or uses a VM.
var staticDenied = []string{
	"Bash(multipass launch*)", "Bash(multipass start*)", "Bash(multipass stop*)",
	"Bash(multipass restart*)", "Bash(multipass exec*)", "Bash(multipass shell*)",
	"Bash(multipass transfer*)",
	"Bash(make setup-*)", "Bash(make test-apps*)", "Bash(make screenshot-apps*)",
	"Bash(make stop*)", "Bash(make run*)", "Bash(make shell*)", "Bash(make launch-vm*)",
	"Bash(go run ./ops/cmd/sampletool dbs*)", "Bash(go run ./ops/cmd/sampletool k3s*)",
	"Bash(go run ./ops/cmd/sampletool apps up*)", "Bash(go run ./ops/cmd/sampletool apps down*)",
	"Bash(go run ./ops/cmd/sampletool apps test*)", "Bash(go run ./ops/cmd/sampletool apps wait*)",
	"Bash(go run ./ops/cmd/sampletool apps screenshot*)",
}

const trialTimeout = 20 * time.Minute

// agentResult is what an agent did in a trial.
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
	Commands    []string       `json:"-"`
}

type denial struct {
	Tool  string `json:"tool"`
	Input string `json:"input"`
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

// projectPermissions returns the variant's permission rules. claude ignores
// permissions.allow in a folder nobody has trusted, which a trial's temporary
// copy never is, so they go in as flags.
func projectPermissions(work string) (allow, deny []string) {
	data, err := os.ReadFile(filepath.Join(work, ".claude", "settings.json"))
	if err != nil {
		return nil, nil
	}
	var settings struct {
		Permissions struct{ Allow, Deny []string }
	}
	_ = json.Unmarshal(data, &settings)
	return settings.Permissions.Allow, settings.Permissions.Deny
}

func runClaude(ctx context.Context, work string, t *task, v *variant, maxTurns int, vm bool, transcript string) (agentResult, error) {
	for _, n := range []int{maxTurns, v.MaxTurns, t.MaxTurns, 30} {
		if n > 0 {
			maxTurns = n
			break
		}
	}
	allow, deny := projectPermissions(work)
	deny = append(slices.Clone(alwaysDenied), deny...)
	if !vm {
		deny = append(deny, staticDenied...)
	}
	args := []string{"-p", t.Prompt, "--output-format", "stream-json", "--verbose",
		"--max-turns", strconv.Itoa(maxTurns), "--model", v.Model,
		"--setting-sources", "project", "--strict-mcp-config", "--no-session-persistence",
		"--permission-mode", "acceptEdits", "--permission-prompts", "none",
		"--allowedTools"}
	args = append(append(args, baseAllowed...), allow...)
	args = append(append(args, "--disallowedTools"), deny...)
	if v.Effort != "" {
		args = append(args, "--effort", v.Effort)
	}
	args = append(args, v.Args...)

	out, err := os.Create(transcript)
	if err != nil {
		return agentResult{}, err
	}
	defer out.Close()
	ctx, cancel := context.WithTimeout(ctx, trialTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, "claude", args...)
	cmd.Dir, cmd.Env, cmd.Stdout = work, childEnv(v.Env), out
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	start := time.Now()
	runErr := cmd.Run()
	timedOut := errors.Is(ctx.Err(), context.DeadlineExceeded)
	if err := out.Sync(); err != nil {
		return agentResult{}, err
	}
	r, err := parseTranscript(transcript)
	if err != nil {
		return r, err
	}
	if r.DurationMS == 0 {
		r.DurationMS = time.Since(start).Milliseconds()
	}
	if timedOut {
		r.IsError, r.Stop = true, "timeout"
	}
	if r.Stop == "no result" {
		r.Stderr = truncate(stderr.String(), 1000)
		if runErr != nil && r.Stderr == "" {
			r.Stderr = runErr.Error()
		}
	}
	return r, nil
}

// parseTranscript reads claude's stream-json output.
func parseTranscript(path string) (agentResult, error) {
	r := agentResult{ToolCalls: map[string]int{}, Denied: []denial{}, IsError: true, Stop: "no result"}
	f, err := os.Open(path)
	if err != nil {
		return r, err
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	sc.Buffer(nil, 64<<20)
	for sc.Scan() {
		var ev struct {
			Type    string `json:"type"`
			Message struct {
				Content []struct {
					Type  string `json:"type"`
					Name  string `json:"name"`
					Input struct {
						Command string `json:"command"`
					} `json:"input"`
				} `json:"content"`
			} `json:"message"`
			Subtype           string  `json:"subtype"`
			IsError           bool    `json:"is_error"`
			NumTurns          int     `json:"num_turns"`
			TotalCostUSD      float64 `json:"total_cost_usd"`
			DurationMS        int64   `json:"duration_ms"`
			TerminalReason    string  `json:"terminal_reason"`
			PermissionDenials []struct {
				ToolName  string `json:"tool_name"`
				ToolInput struct {
					Command  string `json:"command"`
					FilePath string `json:"file_path"`
				} `json:"tool_input"`
			} `json:"permission_denials"`
		}
		if json.Unmarshal(sc.Bytes(), &ev) != nil {
			continue
		}
		switch ev.Type {
		case "assistant":
			for _, b := range ev.Message.Content {
				if b.Type == "tool_use" {
					r.ToolCalls[b.Name]++
					if b.Name == "Bash" {
						r.Commands = append(r.Commands, b.Input.Command)
					}
				}
			}
		case "result":
			r.Turns, r.CostUSD, r.DurationMS, r.IsError = ev.NumTurns, ev.TotalCostUSD, ev.DurationMS, ev.IsError
			r.Stop = ev.TerminalReason
			if r.Stop == "" {
				r.Stop = ev.Subtype
			}
			for _, d := range ev.PermissionDenials {
				input := d.ToolInput.Command
				if input == "" {
					input = d.ToolInput.FilePath
				}
				r.Denied = append(r.Denied, denial{Tool: d.ToolName, Input: head(input, 200)})
			}
			r.DeniedCount = len(r.Denied)
		}
	}
	return r, sc.Err()
}

// claudeLoggedIn reports whether `claude auth status` shows a login.
func claudeLoggedIn(ctx context.Context) bool {
	out, err := output(ctx, "", "claude", "auth", "status")
	var status struct {
		LoggedIn bool `json:"loggedIn"`
	}
	return err == nil && json.Unmarshal([]byte(out), &status) == nil && status.LoggedIn
}
