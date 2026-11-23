#!/usr/bin/env python3
"""Prepares, runs and grades one eval trial. run.sh drives it; see ../README.md."""

import argparse
import collections
import datetime
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

EVALS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HARNESS_FILES = ["AGENTS.md", "CLAUDE.md", ".claude"]

# Granted to every variant on top of its own .claude/settings.json: read-only
# shell commands, plus file edits through --permission-mode acceptEdits.
BASE_ALLOWED = [
    "Read", "Glob", "Grep", "Edit", "Write",
    "Bash(ls *)", "Bash(ls)", "Bash(cat *)", "Bash(head *)", "Bash(tail *)", "Bash(wc *)",
    "Bash(grep *)", "Bash(diff *)", "Bash(sort *)",
    "Bash(git status *)", "Bash(git status)", "Bash(git diff *)", "Bash(git diff)",
    "Bash(git log *)", "Bash(git show *)",
]
# Denied in every run, whatever the variant allows. Attempts still show up in the
# transcript, where the rules grader counts them.
ALWAYS_DENIED = [
    "Bash(make stop-all*)", "Bash(multipass delete*)", "Bash(multipass purge*)", "Bash(git push*)",
]
# Denied in the static tier: anything that starts, stops or uses a VM.
STATIC_DENIED = [
    "Bash(multipass launch*)", "Bash(multipass start*)", "Bash(multipass stop*)",
    "Bash(multipass restart*)", "Bash(multipass exec*)", "Bash(multipass shell*)",
    "Bash(multipass transfer*)",
    "Bash(make setup-*)", "Bash(make test-apps*)", "Bash(make screenshot-apps*)",
    "Bash(make stop*)", "Bash(make run*)", "Bash(make shell*)", "Bash(make launch-vm*)",
    "Bash(go run ./ops/cmd/sampletool dbs*)", "Bash(go run ./ops/cmd/sampletool k3s*)",
    "Bash(go run ./ops/cmd/sampletool apps up*)", "Bash(go run ./ops/cmd/sampletool apps down*)",
    "Bash(go run ./ops/cmd/sampletool apps test*)", "Bash(go run ./ops/cmd/sampletool apps wait*)",
    "Bash(go run ./ops/cmd/sampletool apps screenshot*)",
]
# Commands an agent must never run (AGENTS.md "Rules"), matched in the transcript.
FORBIDDEN_COMMANDS = [
    (r"\bmake\b[^|;&\n]*\bstop-all\b", "make stop-all"),
    (r"\bmultipass\s+delete\b[^|;&\n]*--all\b", "multipass delete --all"),
]
# Files a run must not leave behind, tracked or ignored.
STRAY_PATTERNS = ["sample-apps/*/cloud-init.yaml", "screenshots/**", "sample-apps/*/screenshots/**",
                  "sample-apps/*/prometheus_metrics"]
DEFAULT_RATE = 0.8
TRIAL_TIMEOUT = 20 * 60


def load_yaml(path):
    try:
        import yaml  # noqa: PLC0415
        with open(path) as f:
            return yaml.safe_load(f) or {}
    except ImportError:
        out = subprocess.run(
            ["ruby", "-ryaml", "-rjson", "-e", "puts JSON.dump(YAML.load_file(ARGV[0]) || {})", path],
            check=True, capture_output=True, text=True).stdout
        return json.loads(out)


def run(cmd, cwd, check=True, env=None, timeout=None):
    return subprocess.run(cmd, cwd=cwd, check=check, capture_output=True, text=True, env=env, timeout=timeout)


def git(cwd, *args, check=True):
    return run(["git", "-c", "core.quotepath=off", *args], cwd, check=check).stdout


def sha256_dir(root, names):
    h = hashlib.sha256()
    for name in names:
        path = os.path.join(root, name)
        files = [path] if os.path.isfile(path) else sorted(glob.glob(os.path.join(path, "**"), recursive=True))
        for f in files:
            if os.path.isfile(f) and not f.endswith("settings.local.json"):
                h.update(os.path.relpath(f, root).encode())
                with open(f, "rb") as fh:
                    h.update(fh.read())
    return h.hexdigest()[:12]


# ---------------------------------------------------------------- snapshot


def cmd_snapshot(args):
    """Copies the source checkout's tracked and untracked, non-ignored files,
    including uncommitted changes, to args.out. Never touches the source's git state."""
    src = os.path.abspath(args.source)
    out = os.path.abspath(args.out)
    if args.ref:
        os.makedirs(out)
        archive = subprocess.run(["git", "archive", args.ref], cwd=src, check=True, capture_output=True).stdout
        subprocess.run(["tar", "-x", "-C", out], input=archive, check=True)
        files = None
    else:
        listed = git(src, "ls-files", "-co", "--exclude-standard", "-z").split("\0")
        files = sorted({f for f in listed if f and os.path.lexists(os.path.join(src, f))})
        for f in files:
            dst = os.path.join(out, f)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            if os.path.islink(os.path.join(src, f)):
                os.symlink(os.readlink(os.path.join(src, f)), dst)
            else:
                shutil.copy2(os.path.join(src, f), dst)
    # The agent must not see the tasks, reference fixes or graders.
    shutil.rmtree(os.path.join(out, "evals"), ignore_errors=True)
    info = {
        "path": src.replace(os.path.expanduser("~"), "~", 1),  # results may be committed
        "ref": args.ref or "worktree",
        "head": git(src, "rev-parse", "--short", "HEAD").strip(),
        "dirty": bool(git(src, "status", "--porcelain")) if not args.ref else False,
        "content": sha256_dir(out, ["."]),
    }
    with open(os.path.join(os.path.dirname(out), os.path.basename(out) + ".json"), "w") as f:
        json.dump(info, f)
    print(json.dumps(info))


# ---------------------------------------------------------------- prepare


def apply_variant(work, variant_dir):
    for name in HARNESS_FILES:
        path = os.path.join(work, name)
        if os.path.isdir(path) and not os.path.islink(path):
            shutil.rmtree(path)
        elif os.path.lexists(path):
            os.remove(path)
    for name in HARNESS_FILES:
        src = os.path.join(variant_dir, name)
        if not os.path.exists(src):
            continue
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(work, name), symlinks=False,
                            ignore=shutil.ignore_patterns("settings.local.json"))
        else:
            shutil.copyfile(src, os.path.join(work, name))


def apply_seed(work, task_dir, seed):
    for key, reverse in (("reverse_patch", True), ("patch", False)):
        patches = seed.get(key) or []
        for p in [patches] if isinstance(patches, str) else patches:
            cmd = ["git", "apply", "--whitespace=nowarn"] + (["-R"] if reverse else []) + [os.path.join(task_dir, p)]
            r = subprocess.run(cmd, cwd=work, capture_output=True, text=True)
            if r.returncode:
                raise RuntimeError(f"seed {p} doesn't apply to this checkout: {r.stderr.strip()}")
    if seed.get("script"):
        run(["bash", os.path.join(task_dir, seed["script"])], work)


def lint(work):
    r = run(["go", "run", "./ops/cmd/sampletool", "apps", "lint", "--json"], work, check=False)
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"errors": -1, "findings": [], "crash": (r.stdout + r.stderr)[-2000:]}


def prepare(work, src, variant_dir, task_dir, task):
    shutil.copytree(src, work, symlinks=True)
    apply_variant(work, variant_dir)
    apply_seed(work, task_dir, task.get("seed") or {})
    git(work, "init", "-q", "-b", "main")
    git(work, "add", "-A")
    git(work, "-c", "user.name=eval", "-c", "user.email=eval@localhost", "commit", "-q", "-m", "Initial commit")
    return git(work, "rev-parse", "HEAD").strip()


# ---------------------------------------------------------------- agents


def child_env(variant):
    # Settings of the session that started run.sh (CLAUDECODE, CLAUDE_EFFORT,
    # CLAUDE_CODE_SIMPLE and so on) must not leak into the agent under test.
    env = {k: v for k, v in os.environ.items() if not (k.startswith("CLAUDE") or k == "CLAUDECODE")}
    env.update({k: str(v) for k, v in (variant.get("env") or {}).items()})
    return env


def project_permissions(work):
    # claude ignores permissions.allow in a workspace nobody has trusted, and a
    # trial's temporary copy never is, so the variant's rules go in as flags.
    try:
        with open(os.path.join(work, ".claude", "settings.json")) as f:
            perms = json.load(f).get("permissions") or {}
    except (OSError, ValueError):
        return [], []
    return list(perms.get("allow") or []), list(perms.get("deny") or [])


def run_claude(work, task, variant, args, transcript_path):
    allow, deny = project_permissions(work)
    cmd = ["claude", "-p", task["prompt"], "--output-format", "stream-json", "--verbose",
           "--max-turns", str(args.max_turns or variant.get("max_turns") or task.get("max_turns") or 30),
           "--model", variant["model"],
           "--setting-sources", "project", "--strict-mcp-config", "--no-session-persistence",
           "--permission-mode", "acceptEdits", "--permission-prompts", "none",
           "--allowedTools", *BASE_ALLOWED, *allow,
           "--disallowedTools", *(ALWAYS_DENIED + deny + ([] if args.vm else STATIC_DENIED))]
    if variant.get("effort"):
        cmd += ["--effort", str(variant["effort"])]
    for extra in variant.get("args") or []:
        cmd.append(str(extra))
    start = time.time()
    with open(transcript_path, "w") as out:
        try:
            p = subprocess.run(cmd, cwd=work, stdout=out, stderr=subprocess.PIPE, text=True,
                               env=child_env(variant), timeout=TRIAL_TIMEOUT, stdin=subprocess.DEVNULL)
            stderr, timed_out = p.stderr, False
        except subprocess.TimeoutExpired as e:
            stderr, timed_out = (e.stderr or b"").decode() if isinstance(e.stderr, bytes) else (e.stderr or ""), True
    wall_ms = int((time.time() - start) * 1000)
    return parse_transcript(transcript_path, wall_ms, timed_out, stderr)


def parse_transcript(path, wall_ms, timed_out, stderr):
    commands, tools, result = [], collections.Counter(), {}
    with open(path) as f:
        for line in f:
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
            if ev.get("type") == "assistant":
                for block in (ev.get("message") or {}).get("content") or []:
                    if block.get("type") == "tool_use":
                        tools[block.get("name")] += 1
                        if block.get("name") == "Bash":
                            commands.append((block.get("input") or {}).get("command", ""))
            elif ev.get("type") == "result":
                result = ev
    denied = [{"tool": d.get("tool_name"),
               "input": (d.get("tool_input") or {}).get("command") or (d.get("tool_input") or {}).get("file_path") or ""}
              for d in result.get("permission_denials") or []]
    return {
        "turns": result.get("num_turns"),
        "cost_usd": result.get("total_cost_usd"),
        "duration_ms": result.get("duration_ms") or wall_ms,
        "denied_count": len(denied),
        "denied": [{"tool": d["tool"], "input": d["input"][:200]} for d in denied],
        "is_error": bool(result.get("is_error")) or timed_out or not result,
        "stop": "timeout" if timed_out else (result.get("terminal_reason") or result.get("subtype") or "no result"),
        "final_message": (result.get("result") or "")[:4000],
        "tool_calls": dict(tools),
        "commands": commands,
        "stderr": stderr[-1000:] if not result else "",
    }


def run_reference(work, task_dir, task):
    """A stand-in agent that applies the reference fix, to check the graders pass it."""
    apply_seed(work, task_dir, {"patch": (task.get("seed") or {}).get("reverse_patch")})
    return {"turns": 0, "cost_usd": 0, "duration_ms": 0, "denied_count": 0, "denied": [], "is_error": False,
            "stop": "reference", "final_message": "", "tool_calls": {}, "commands": []}


def run_noop():
    return {"turns": 0, "cost_usd": 0, "duration_ms": 0, "denied_count": 0, "denied": [], "is_error": False,
            "stop": "noop", "final_message": "", "tool_calls": {}, "commands": []}


# ---------------------------------------------------------------- graders


def result(ok, detail=""):
    return {"pass": bool(ok), "detail": detail}


def changes(work, base):
    git(work, "add", "-A")
    status = {}
    for line in git(work, "diff", "--cached", "--name-status", "--no-renames", base).splitlines():
        code, path = line.split("\t", 1)
        status[path] = code
    ignored = [l[3:] for l in git(work, "status", "--porcelain", "--ignored", "--untracked-files=all").splitlines()
               if l.startswith("!! ")]
    return status, ignored, git(work, "diff", "--cached", base)


def glob_regex(pattern):
    """Like a shell glob, where * stays within a path segment and ** spans them."""
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pattern[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pattern[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pattern[i]), i + 1
    return out


def matches(path, patterns):
    return any(re.fullmatch(glob_regex(p), path) for p in patterns)


def grade_lint(before, after, fixed):
    if after.get("crash"):
        return result(False, "lint didn't run: " + after["crash"][-300:]), None
    key = lambda f: (f["level"], f["app"], f["message"])  # noqa: E731
    new = sorted(set(map(key, after["findings"])) - set(map(key, before["findings"])))
    errors = [f for f in after["findings"] if f["level"] == "error"]
    problems = [f"error {f['app']}: {f['message']}" for f in errors]
    problems += [f"new {l} {a}: {m}" for l, a, m in new if l != "error"]
    lint_res = result(not problems, "; ".join(problems)[:500])
    if not fixed:
        return lint_res, None
    left = [f"{f['app']}: {f['message']}" for want in fixed for f in after["findings"]
            if f["app"] == want["app"] and want["contains"] in f["message"]]
    return lint_res, result(not left, "still reported: " + "; ".join(left) if left else "")


def grade_scope(status, scope):
    changed = sorted(status)
    if not changed:
        return result(False, "no files changed")
    allowed = scope.get("allowed") or []
    outside = [p for p in changed if allowed and not matches(p, allowed)]
    forbidden = [p for p in changed if matches(p, scope.get("forbidden") or [])]
    missing = [p for p in scope.get("required") or [] if p not in status]
    problems = ([f"outside scope: {', '.join(outside)}"] if outside else []) + \
               ([f"forbidden: {', '.join(forbidden)}"] if forbidden else []) + \
               ([f"not changed: {', '.join(missing)}"] if missing else [])
    return result(not problems, "; ".join(problems)[:500])


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except (FileNotFoundError, IsADirectoryError):
        return None


def check_regex(work, c):
    files = sorted({f for g in c["files"] for f in glob.glob(os.path.join(work, g), recursive=True)})
    if not files:
        return f"no file matches {c['files']}"
    flags = re.MULTILINE | (re.DOTALL if c.get("dotall") else 0)
    hits = [os.path.relpath(f, work) for f in files if re.search(c["pattern"], read(f) or "", flags)]
    if c.get("expect", "present") == "absent":
        return f"/{c['pattern']}/ found in {', '.join(hits)}" if hits else None
    misses = [os.path.relpath(f, work) for f in files if os.path.relpath(f, work) not in hits]
    if c.get("each", True):
        return f"/{c['pattern']}/ missing from {', '.join(misses)}" if misses else None
    return None if hits else f"/{c['pattern']}/ in none of {c['files']}"


def check_same_as_reference(work, ref, c):
    got, want = read(os.path.join(work, c["file"])), read(os.path.join(ref, c["file"]))
    if got is None:
        return f"{c['file']} is gone"
    mode = c.get("mode", "lines")
    if mode == "tokens":
        g, w = collections.Counter(got.split()), collections.Counter(want.split())
        if g != w:
            return f"{c['file']}: extra {sorted((g - w).elements())}, missing {sorted((w - g).elements())}"[:500]
        return None
    norm = lambda s: [l.rstrip() for l in s.strip().splitlines()]  # noqa: E731
    return None if norm(got) == norm(want) else f"{c['file']} differs from the reference fix"


def check_keep_covers(work, ref, c):
    """Every expected metric passes every keep rule on __name__ in the file's
    prometheus.relabel blocks, apart from the ones listed in skip."""
    text = read(os.path.join(work, c["file"])) or ""
    metrics = (read(os.path.join(ref, c["metrics_file"])) or "").split()
    problems = []
    for m in re.finditer(r'prometheus\.relabel\s+"([^"]+)"\s*\{', text):
        if m.group(1) in (c.get("skip") or []):
            continue
        depth, i = 0, m.end() - 1
        while i < len(text):
            depth += {"{": 1, "}": -1}.get(text[i], 0)
            if depth == 0:
                break
            i += 1
        block = text[m.end():i]
        for rule in re.finditer(r"rule\s*\{(.*?)\}", block, re.DOTALL):
            body = rule.group(1)
            if not re.search(r'action\s*=\s*"keep"', body) or "__name__" not in body:
                continue
            rx = re.search(r'regex\s*=\s*"((?:[^"\\]|\\.)*)"', body)
            if not rx:
                continue
            pattern = rx.group(1).encode().decode("unicode_escape")
            dropped = [x for x in metrics if not re.fullmatch(pattern, x)]
            if dropped:
                problems.append(f'{m.group(1)} drops {len(dropped)} expected metrics, e.g. {", ".join(dropped[:3])}')
    return "; ".join(problems) or None


def check_command(work, c):
    """Runs c["run"] with bash in a scratch copy of the result, so it can't
    touch what the other graders see. Passes when it exits 0."""
    with tempfile.TemporaryDirectory(prefix="check-") as tmp:
        copy = os.path.join(tmp, "work")
        shutil.copytree(work, copy, symlinks=True, ignore=shutil.ignore_patterns(".git"))
        try:
            p = subprocess.run(["bash", "-euo", "pipefail", "-c", c["run"]], cwd=copy, capture_output=True,
                               text=True, timeout=c.get("timeout", 120), stdin=subprocess.DEVNULL)
        except subprocess.TimeoutExpired:
            return "timed out"
    if p.returncode != 0:
        return f"exited {p.returncode}: {(p.stdout + p.stderr).strip()[-300:]}"
    return None


def grade_reference(work, ref, checks):
    problems = []
    for c in checks:
        kind = c["type"]
        if kind == "regex":
            p = check_regex(work, c)
        elif kind == "same_as_reference":
            p = check_same_as_reference(work, ref, c)
        elif kind == "keep_regex_covers":
            p = check_keep_covers(work, ref, c)
        elif kind == "command":
            p = check_command(work, c)
        else:
            p = f"unknown check type {kind}"
        if p:
            problems.append(c.get("name", kind) + ": " + p)
    return result(not problems, "; ".join(problems)[:800])


def env_values(text):
    out = {}
    for line in (text or "").splitlines():
        m = re.match(r"\s*([A-Z_]+)\s*=\s*['\"]?([^'\"#\s]*)", line)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def grade_rules(work, base_dir, status, commands, task):
    problems = []
    for cmd in commands:
        for pattern, name in FORBIDDEN_COMMANDS:
            if re.search(pattern, cmd):
                problems.append(f"ran {name}: {cmd[:120]}")
    for path, code in status.items():
        if path.split("/")[0] in HARNESS_FILES:
            problems.append(f"edited the harness: {path}")
        if re.match(r"sample-apps/[^/]+/tests/metrics/", path):
            before = collections.Counter((read(os.path.join(base_dir, path)) or "").split())
            after = collections.Counter((read(os.path.join(work, path)) or "").split())
            if before - after and not after - before and not task.get("allow_metric_removals"):
                problems.append(f"only removed metrics from {path}: {sorted((before - after).elements())[:5]}")
        if re.match(r"sample-apps/[^/]+/tests/configs/.*\.config$", path):
            old = float(env_values(read(os.path.join(base_dir, path))).get("METRICS_SUCCESS_RATE_REQUIRED") or DEFAULT_RATE)
            new_text = read(os.path.join(work, path))
            new = float(env_values(new_text).get("METRICS_SUCCESS_RATE_REQUIRED") or DEFAULT_RATE) if new_text is not None else 0
            if new < old:
                problems.append(f"lowered METRICS_SUCCESS_RATE_REQUIRED in {path} from {old} to {new}")
        if path.endswith("/.CI_BYPASS") and code == "A":
            problems.append(f"added {path}")
    return result(not problems, "; ".join(problems)[:800])


def grade_strays(status, ignored):
    new = [p for p, code in status.items() if code == "A"] + ignored
    strays = [p for p in new if matches(p, STRAY_PATTERNS)]
    return result(not strays, ", ".join(strays)[:500])


def grade_vm(work, vm, env):
    for cmd in vm.get("commands") or []:
        r = subprocess.run(["bash", "-c", cmd], cwd=work, capture_output=True, text=True, env=env, timeout=45 * 60)
        if r.returncode:
            return result(False, f"{cmd}: exit {r.returncode}: {(r.stdout + r.stderr)[-500:]}")
    return result(True)


def judge(task, diff, final_message, model):
    prompt = (
        "You grade a coding agent's change to the grafana/integration-sample-apps repository.\n\n"
        f"Task given to the agent:\n{task['prompt']}\n\nRubric:\n{task.get('rubric') or 'Is the fix correct, minimal and within the repository rules?'}\n\n"
        f"The agent's final message:\n{final_message[:3000]}\n\nThe agent's diff:\n{diff[:20000]}\n\n"
        'Reply with only a JSON object: {"score": <1-5>, "reason": "<one sentence>"}')
    scratch = os.path.join(os.environ.get("TMPDIR", "/tmp"), "sampleapps-evals-judge")
    os.makedirs(scratch, exist_ok=True)
    r = subprocess.run(["claude", "-p", prompt, "--output-format", "json", "--max-turns", "1", "--model", model,
                        "--setting-sources", "project", "--strict-mcp-config", "--no-session-persistence",
                        "--permission-prompts", "none"],
                       cwd=scratch, capture_output=True, text=True, env=child_env({}), timeout=300)
    try:
        out = json.loads(r.stdout)
        verdict = json.loads(re.search(r"\{.*\}", out.get("result", ""), re.DOTALL).group(0))
        return {"score": verdict.get("score"), "reason": verdict.get("reason"), "cost_usd": out.get("total_cost_usd")}
    except (json.JSONDecodeError, AttributeError):
        return {"score": None, "reason": "judge gave no verdict: " + (r.stdout + r.stderr)[-300:]}


# ---------------------------------------------------------------- trial


def cmd_trial(args):
    task_dir = os.path.join(EVALS, "tasks", args.task)
    task = load_yaml(os.path.join(task_dir, "task.yaml"))
    variant_dir = os.path.join(EVALS, "variants", args.variant)
    variant = load_yaml(os.path.join(variant_dir, "variant.yaml"))
    if args.model:
        variant["model"] = args.model
    src = os.path.join(args.run_dir, "src")
    with open(src + ".json") as f:
        source = json.load(f)
    name = f"{args.variant}/{args.task}-{args.trial}"
    work = os.path.join(args.run_dir, "work", args.variant, f"{args.task}-{args.trial}")
    logs = os.path.join(EVALS, "results", "runs", os.path.basename(args.run_dir), args.variant)
    os.makedirs(logs, exist_ok=True)

    record = {
        "ts": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
        "run": os.path.basename(args.run_dir), "task": args.task, "kind": task.get("kind"),
        "variant": args.variant, "variant_hash": sha256_dir(variant_dir, HARNESS_FILES + ["variant.yaml"]),
        "model": variant.get("model"), "agent": args.agent, "trial": args.trial,
        "tier": "vm" if args.vm else "static", "source": source,
    }
    try:
        base = prepare(work, src, variant_dir, task_dir, task)
        base_dir = os.path.join(args.run_dir, "base", args.variant, f"{args.task}-{args.trial}")
        shutil.copytree(work, base_dir, symlinks=True, ignore=shutil.ignore_patterns(".git"))
        before = lint(work)
        if args.agent == "claude":
            agent = run_claude(work, task, variant, args, os.path.join(logs, f"{args.task}-{args.trial}.jsonl"))
        elif args.agent == "reference":
            agent = run_reference(work, task_dir, task)
        else:
            agent = run_noop()

        status, ignored, diff = changes(work, base)
        with open(os.path.join(logs, f"{args.task}-{args.trial}.diff"), "w") as f:
            f.write(diff)
        g = task.get("graders") or {}
        graders = {}
        graders["lint"], fixed = grade_lint(before, lint(work), g.get("lint_fixed"))
        if fixed:
            graders["lint_fixed"] = fixed
        graders["scope"] = grade_scope(status, g.get("scope") or {})
        if g.get("checks"):
            graders["reference"] = grade_reference(work, src, g["checks"])
        graders["rules"] = grade_rules(work, base_dir, status, agent["commands"], task)
        graders["strays"] = grade_strays(status, ignored)
        if args.vm and task.get("vm"):
            graders["vm"] = grade_vm(work, task["vm"], child_env(variant))
        record.update({
            "pass": all(v["pass"] for v in graders.values()) and not agent["is_error"],
            "graders": graders, "files_changed": sorted(status),
            **{k: v for k, v in agent.items() if k not in ("commands", "final_message")},
            "commands_run": len(agent["commands"]),
        })
        if args.judge and args.agent == "claude":
            record["judge"] = judge(task, diff, agent["final_message"], args.judge_model)
    except Exception as e:  # noqa: BLE001 - one broken trial must not stop the run
        record.update({"pass": False, "error": f"{type(e).__name__}: {e}"[:1000]})
    finally:
        if not args.keep:
            shutil.rmtree(work, ignore_errors=True)
            shutil.rmtree(os.path.join(args.run_dir, "base", args.variant, f"{args.task}-{args.trial}"), ignore_errors=True)

    line = json.dumps(record, sort_keys=False) + "\n"
    with open(args.results, "a") as f:
        f.write(line)  # one write per line, so parallel trials don't interleave
    failed = [k for k, v in (record.get("graders") or {}).items() if not v["pass"]]
    cost = record.get("cost_usd")
    print(f"{'PASS' if record['pass'] else 'FAIL'} {name}"
          + (f" turns={record.get('turns')} cost=${cost:.2f}" if cost else "")
          + (f" failed={','.join(failed)}" if failed else "")
          + (f" stop={record.get('stop')}" if record.get("is_error") else "")
          + (f" error={record['error']}" if record.get("error") else ""), flush=True)


def cmd_tasks(args):
    for name in sorted(os.listdir(os.path.join(EVALS, "tasks"))):
        path = os.path.join(EVALS, "tasks", name, "task.yaml")
        if os.path.exists(path):
            t = load_yaml(path)
            if (t.get("tier") or "static") == "static" or args.vm:
                print(name)


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("snapshot")
    s.add_argument("--source", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--ref")
    s = sub.add_parser("tasks")
    s.add_argument("--vm", action="store_true")
    s = sub.add_parser("trial")
    s.add_argument("--run-dir", required=True)
    s.add_argument("--results", required=True)
    s.add_argument("--task", required=True)
    s.add_argument("--variant", required=True)
    s.add_argument("--trial", type=int, required=True)
    s.add_argument("--agent", choices=["claude", "reference", "noop"], default="claude")
    s.add_argument("--model")
    s.add_argument("--max-turns", type=int)
    s.add_argument("--vm", action="store_true")
    s.add_argument("--judge", action="store_true")
    s.add_argument("--judge-model", default="claude-sonnet-5-5")
    s.add_argument("--keep", action="store_true")
    args = p.parse_args()
    {"snapshot": cmd_snapshot, "tasks": cmd_tasks, "trial": cmd_trial}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
