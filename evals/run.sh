#!/usr/bin/env bash
# Runs eval tasks against harness variants. See evals/README.md.
#
#   evals/run.sh [--variant NAME]... [--tasks a,b] [--trials N] [--jobs N] [--vm]
#                [--model ID] [--max-turns N] [--judge] [--agent claude|reference|noop]
#                [--source DIR] [--ref REF] [--keep]
set -euo pipefail

EVALS="$(cd "$(dirname "$0")" && pwd)"
LIB="$EVALS/lib/evals.py"
SOURCE="$(cd "$EVALS/.." && pwd)"
VARIANTS=()
TASKS=""
TRIALS=3
JOBS=3
VM=""
MODEL=""
MAX_TURNS=""
JUDGE=""
AGENT="claude"
REF=""
KEEP=""

usage() { sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --variant) VARIANTS+=("$2"); shift 2 ;;
    --tasks) TASKS="$2"; shift 2 ;;
    --trials) TRIALS="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --vm) VM="--vm"; shift ;;
    --model) MODEL="$2"; shift 2 ;;
    --max-turns) MAX_TURNS="$2"; shift 2 ;;
    --judge) JUDGE="--judge"; shift ;;
    --agent) AGENT="$2"; shift 2 ;;
    --source) SOURCE="$(cd "$2" && pwd)"; shift 2 ;;
    --ref) REF="$2"; shift 2 ;;
    --keep) KEEP="--keep"; shift ;;
    -h|--help) usage ;;
    *) echo "unknown flag: $1" >&2; usage 2 ;;
  esac
done
[ ${#VARIANTS[@]} -gt 0 ] || VARIANTS=(current)

for v in "${VARIANTS[@]}"; do
  [ -f "$EVALS/variants/$v/variant.yaml" ] || { echo "no variant $v (evals/variants/$v/variant.yaml)" >&2; exit 2; }
done
if [ -z "$TASKS" ]; then
  TASKS="$(python3 "$LIB" tasks $VM | paste -sd, -)"
fi
for t in ${TASKS//,/ }; do
  [ -f "$EVALS/tasks/$t/task.yaml" ] || { echo "no task $t (evals/tasks/$t/task.yaml)" >&2; exit 2; }
done
if [ -n "$VM" ] && [ "$JOBS" != 1 ]; then
  echo "--vm runs one trial at a time: parallel Multipass launches break VMs" >&2
  JOBS=1
fi
if [ "$AGENT" = claude ] && ! claude auth status 2>/dev/null | grep -q '"loggedIn": true'; then
  echo "claude isn't logged in: run 'claude auth login' first" >&2
  exit 2
fi

DATE="$(date +%Y-%m-%d)"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
TMP_ROOT="${EVALS_TMPDIR:-${TMPDIR:-/tmp}}"
# The physical path, so the agent never sees the trial directory as outside itself (/var is /private/var on macOS).
RUN_DIR="$(cd "$TMP_ROOT" && pwd -P)/sampleapps-evals/$RUN_ID"
mkdir -p "$RUN_DIR" "$EVALS/results"
trap '[ -n "$KEEP" ] || rm -rf "$RUN_DIR"' EXIT

echo "Snapshotting $SOURCE${REF:+ at $REF} (uncommitted changes included)"
python3 "$LIB" snapshot --source "$SOURCE" --out "$RUN_DIR/src" ${REF:+--ref "$REF"} >/dev/null
# Warm Go's build cache so the first lint in each trial is fast.
(cd "$RUN_DIR/src" && go build -o /dev/null ./ops/cmd/sampletool)

RESULTS=()
: > "$RUN_DIR/trials"
for v in "${VARIANTS[@]}"; do
  if [ "$AGENT" = claude ]; then
    out="$EVALS/results/$DATE-$v.jsonl"
  else
    out="$EVALS/results/runs/$RUN_ID/$AGENT-$v.jsonl"
    mkdir -p "$(dirname "$out")"
  fi
  RESULTS+=("$out")
  for t in ${TASKS//,/ }; do
    for i in $(seq 1 "$TRIALS"); do
      printf '%s %s %s %s\n' "$v" "$t" "$i" "$out" >> "$RUN_DIR/trials"
    done
  done
done

echo "Running $(wc -l < "$RUN_DIR/trials" | tr -d ' ') trials ($AGENT agent, ${VM:+vm}${VM:-static} tier, $JOBS at a time)"
export LIB RUN_DIR AGENT MODEL MAX_TURNS VM JUDGE KEEP
# xargs stops at the first failing command, so a trial always exits 0; its
# failure is in the results file.
xargs -P "$JOBS" -L 1 bash -c '
  python3 "$LIB" trial --run-dir "$RUN_DIR" --variant "$0" --task "$1" --trial "$2" --results "$3" \
    --agent "$AGENT" ${MODEL:+--model "$MODEL"} ${MAX_TURNS:+--max-turns "$MAX_TURNS"} $VM $JUDGE $KEEP || true
' < "$RUN_DIR/trials"

echo
for out in "${RESULTS[@]}"; do
  python3 "$EVALS/lib/compare.py" --run "$RUN_ID" "$out"
done
[ -z "$KEEP" ] || echo "Kept trial directories in $RUN_DIR/work"
echo "Transcripts and diffs: $EVALS/results/runs/$RUN_ID/"
