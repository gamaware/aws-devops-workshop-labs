#!/usr/bin/env bash
# Prove that every lab works as an exercise: the solution meets every objective
# (grader exit 0) and the untouched starter is valid but incomplete (grader exit 1).
# A starter that passes, or one the grader cannot even run (exit 2), fails the build.
# Usage: scripts/verify-labs.sh [lab-number...]   e.g. scripts/verify-labs.sh 01 04
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

labs=()
if [ "$#" -eq 0 ]; then
  for dir in "$REPO_ROOT"/labs/[0-9][0-9]-*/; do
    labs+=("$(basename "$dir")")
  done
else
  for number in "$@"; do
    matches=("$REPO_ROOT"/labs/"$number"-*/)
    [ -d "${matches[0]}" ] || { echo "no lab $number" >&2; exit 2; }
    labs+=("$(basename "${matches[0]}")")
  done
fi

failures=0
printf '%-32s %-10s %-10s %s\n' "lab" "solution" "starter" "verdict"
for lab in "${labs[@]}"; do
  grader="$REPO_ROOT/labs/$lab/tests/run.sh"
  solution_code=0
  starter_code=0
  "$grader" "$REPO_ROOT/labs/$lab/solution" > "$LOG_DIR/$lab-solution.log" 2>&1 || solution_code=$?
  "$grader" "$REPO_ROOT/labs/$lab/starter" > "$LOG_DIR/$lab-starter.log" 2>&1 || starter_code=$?

  verdict="ok"
  if [ "$solution_code" -ne 0 ]; then
    verdict="solution does not pass"
    cat "$LOG_DIR/$lab-solution.log"
  elif [ "$starter_code" -eq 0 ]; then
    verdict="starter already passes: the exercise asks for no work"
  elif [ "$starter_code" -ne 1 ]; then
    verdict="starter is broken: it cannot be graded"
    cat "$LOG_DIR/$lab-starter.log"
  fi
  [ "$verdict" = "ok" ] || failures=$((failures + 1))
  printf '%-32s %-10s %-10s %s\n' "$lab" "exit $solution_code" "exit $starter_code" "$verdict"
done

if [ "$failures" -gt 0 ]; then
  echo "verify-labs: $failures lab(s) failed"
  exit 1
fi
echo "verify-labs: ${#labs[@]} lab(s) ok (solutions pass, starters fail as intended)"
