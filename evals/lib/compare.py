#!/usr/bin/env python3
"""Prints pass rate per task and overall, with cost and turns, for one or two
result sets. compare.sh and run.sh call it; see ../README.md."""

import argparse
import collections
import glob
import json
import os
import sys

EVALS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(spec, merge_all, run):
    if spec.endswith(".jsonl") or os.path.sep in spec:
        files = [spec]
    else:
        files = sorted(glob.glob(os.path.join(EVALS, "results", f"????-??-??-{spec}.jsonl")))
        if not files:
            sys.exit(f"no results for variant {spec} in evals/results/")
        if not merge_all:
            files = files[-1:]
    records = []
    for path in files:
        with open(path) as f:
            records += [json.loads(line) for line in f if line.strip()]
    if run:
        records = [r for r in records if r.get("run") == run]
    label = spec if len(files) > 1 or not spec.endswith(".jsonl") else os.path.basename(spec)[:-6]
    return label, files, records


def stats(records):
    n = len(records)
    passed = sum(1 for r in records if r.get("pass"))
    costs = [r["cost_usd"] for r in records if isinstance(r.get("cost_usd"), (int, float))]
    turns = [r["turns"] for r in records if isinstance(r.get("turns"), int)]
    denied = [r.get("denied_count") or 0 for r in records]
    fails = collections.Counter(g for r in records for g, v in (r.get("graders") or {}).items() if not v["pass"])
    fails.update("error" for r in records if r.get("error") or r.get("is_error"))
    return {
        "n": n, "passed": passed,
        "rate": passed / n if n else 0,
        "cost": sum(costs) / len(costs) if costs else None,
        "cost_total": sum(costs),
        "turns": sum(turns) / len(turns) if turns else None,
        "denied": sum(denied) / n if n else 0,
        "fails": fails,
    }


def fmt_pass(s):
    return f"{s['passed']}/{s['n']} {s['rate']:4.0%}" if s["n"] else "-"


def fmt_num(v, money=False):
    if v is None:
        return "-"
    return f"${v:.2f}" if money else f"{v:.1f}"


def fmt_fails(s):
    return ", ".join(f"{g}×{c}" for g, c in s["fails"].most_common(3)) or "-"


def table(rows, headers):
    widths = [max(len(str(x)) for x in col) for col in zip(headers, *rows)]
    line = lambda r: "  ".join(str(x).ljust(w) for x, w in zip(r, widths)).rstrip()  # noqa: E731
    print(line(headers))
    print(line(["-" * w for w in widths]))
    for r in rows[:-1]:
        print(line(r))
    print(line(["-" * w for w in widths]))
    print(line(rows[-1]))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("specs", nargs="+", help="one or two variant names or .jsonl files")
    p.add_argument("--all", action="store_true", help="merge every dated file of a named variant")
    p.add_argument("--run", help="only records from this run id")
    args = p.parse_args()
    if len(args.specs) > 2:
        sys.exit("compare one or two result sets")
    sets = [load(s, args.all, args.run) for s in args.specs]
    tasks = sorted({r["task"] for _, _, recs in sets for r in recs})

    headers = ["task"]
    for label, _, _ in sets:
        headers += [f"{label} pass", "cost", "turns", "denied", "failed graders"]
    rows = []
    for t in tasks + ["overall"]:
        row = [t]
        for _, _, recs in sets:
            s = stats(recs if t == "overall" else [r for r in recs if r["task"] == t])
            row += [fmt_pass(s), fmt_num(s["cost"], True), fmt_num(s["turns"]), fmt_num(s["denied"]), fmt_fails(s)]
        rows.append(row)
    for label, files, recs in sets:
        models = sorted({r.get("model") or "?" for r in recs})
        hashes = sorted({r.get("variant_hash") or "?" for r in recs})
        s = stats(recs)
        print(f"{label}: {len(recs)} trials from {', '.join(os.path.basename(f) for f in files)}; "
              f"model {', '.join(models)}; harness {', '.join(hashes)}; total cost ${s['cost_total']:.2f}")
    print()
    table(rows, headers)
    print("\ncost and turns are means per trial; denied is permission denials per trial.")
    small = [t for t in tasks for _, _, recs in sets if 0 < len([r for r in recs if r["task"] == t]) < 3]
    if small:
        print(f"Fewer than 3 trials for {', '.join(sorted(set(small)))}: single runs are noisy, don't read much into them.")
    if len(sets) == 2:
        a, b = (stats(recs) for _, _, recs in sets)
        if a["n"] and b["n"]:
            print(f"Overall pass rate: {sets[0][0]} {a['rate']:.0%} vs {sets[1][0]} {b['rate']:.0%} "
                  f"({(b['rate'] - a['rate']) * 100:+.0f} points).")


if __name__ == "__main__":
    main()
