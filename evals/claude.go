package main

import (
	"bufio"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
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

// claude runs Claude Code with the variant's permission rules, and reads its
// stream-json transcript.
func claude() commandAgent {
	return commandAgent{
		label: "claude",
		argv: []string{"claude", "-p", "{prompt}", "--output-format", "stream-json", "--verbose",
			"--max-turns", "{max_turns}", "--model", "{model}",
			"--setting-sources", "project", "--strict-mcp-config", "--no-session-persistence",
			"--permission-mode", "acceptEdits", "--permission-prompts", "none"},
		trialArgs: claudeTrialArgs,
		parse:     parseClaudeTranscript,
	}
}

// claudeTrialArgs passes the variant's .claude/settings.json rules as flags:
// claude ignores permissions.allow in a folder nobody has trusted, which a
// trial's temporary copy never is.
func claudeTrialArgs(t agentTrial) []string {
	var settings struct {
		Permissions struct{ Allow, Deny []string }
	}
	if data, err := os.ReadFile(filepath.Join(t.work, ".claude", "settings.json")); err == nil {
		_ = json.Unmarshal(data, &settings)
	}
	deny := append(slices.Clone(alwaysDenied), settings.Permissions.Deny...)
	if !t.vm {
		deny = append(deny, staticDenied...)
	}
	args := append(append([]string{"--allowedTools"}, baseAllowed...), settings.Permissions.Allow...)
	args = append(append(args, "--disallowedTools"), deny...)
	if t.variant.Effort != "" {
		args = append(args, "--effort", t.variant.Effort)
	}
	return args
}

// parseClaudeTranscript reads claude's stream-json output.
func parseClaudeTranscript(path string) (agentResult, error) {
	r := agentResult{ToolCalls: map[string]int{}, Denied: []denial{}, IsError: true, Stop: "no result", commandsKnown: true}
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
