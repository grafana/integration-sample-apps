#!/usr/bin/env bash
# Compares two variants' results: pass rate per task and overall, cost and turns.
#
#   evals/compare.sh <a> <b> [--all] [--run RUN_ID]
#
# <a> and <b> are variant names (their latest results file) or .jsonl paths;
# --all merges every dated file of a named variant.
exec python3 "$(dirname "$0")/lib/compare.py" "$@"
