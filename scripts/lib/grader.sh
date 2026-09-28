# shellcheck shell=bash
# Shared helpers for the lab graders (labs/NN-*/tests/run.sh). Source it; do not run it.
#
# Exit codes of every grader, relied on by scripts/verify-labs.sh:
#   0  every objective is met
#   1  the target is valid but at least one objective is not met (the expected state of a starter)
#   2  the target is broken or a tool is missing (it cannot even be graded)
#
# A tool that is missing or crashes inside a check is a hard error (exit 2), never a failed
# or skipped objective: see HARD_ERROR, pytest_run and zizmor_run below.
# GRADER_REPORT: optional file path. Each failed objective and its full, untruncated output
# go there; scripts/verify-labs.sh reads it instead of the shortened console output.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GRADER_FAILURES=0
HARD_ERROR=99
GRADER_LOG="$(mktemp)"
GRADER_WORK="$(mktemp -d)"
trap 'rm -rf "$GRADER_LOG" "$GRADER_WORK"' EXIT

# Terraform providers are downloaded once and reused by every lab.
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$REPO_ROOT/.cache/terraform-plugins}"
export TF_IN_AUTOMATION=1
export CHECKPOINT_DISABLE=1
export JSII_SILENCE_WARNING_UNTESTED_NODE_VERSION=1
mkdir -p "$TF_PLUGIN_CACHE_DIR"

# resolve_target DIR: print the absolute path of the directory to grade, or exit 2.
resolve_target() {
  if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
    echo "usage: $(basename "$0") <starter-or-solution-directory>" >&2
    exit 2
  fi
  (cd "$1" && pwd)
}

# require_tool NAME...: exit 2 when a tool the grader needs is not installed.
require_tool() {
  local tool
  for tool in "$@"; do
    if ! command -v "$tool" > /dev/null 2>&1; then
      echo "SETUP  missing tool: $tool (see docs/reference/tooling.md)" >&2
      exit 2
    fi
  done
}

# setup DESCRIPTION COMMAND...: a precondition. Failing it means the target is broken (exit 2).
setup() {
  local description="$1"
  shift
  if "$@" > "$GRADER_LOG" 2>&1; then
    echo "ok     $description"
  else
    echo "BROKEN $description"
    sed 's/^/       /' "$GRADER_LOG" | tail -n 40
    exit 2
  fi
}

# check DESCRIPTION COMMAND...: one objective. Failures are counted and reported at the end.
# A command that exits with HARD_ERROR could not grade at all: the grader stops with exit 2.
check() {
  local description="$1" code=0
  shift
  "$@" > "$GRADER_LOG" 2>&1 || code=$?
  if [ "$code" -eq 0 ]; then
    echo "PASS   $description"
    return
  fi
  # 126 and 127: the shell could not run the command at all.
  if [ "$code" -eq "$HARD_ERROR" ] || [ "$code" -eq 126 ] || [ "$code" -eq 127 ]; then
    echo "BROKEN $description (a tool is missing or crashed)"
    sed 's/^/       /' "$GRADER_LOG" | tail -n 40
    exit 2
  fi
  echo "FAIL   $description"
  sed 's/^/       /' "$GRADER_LOG" | tail -n 40
  if [ "${GRADER_REPORT:-}" != "" ]; then
    echo "FAIL   $description" >> "$GRADER_REPORT"
    cat "$GRADER_LOG" >> "$GRADER_REPORT"
  fi
  GRADER_FAILURES=$((GRADER_FAILURES + 1))
}

# pytest_run ARGS...: run pytest from the locked environment. Exit 0 when every test passes and
# 1 when tests fail. Anything else (pytest or a module missing, collection or usage errors, no
# tests collected, skipped tests) returns HARD_ERROR, so a broken environment never looks like
# a graded answer.
pytest_run() {
  local code=0 output
  output="$(mktemp)"
  uv run --project "$REPO_ROOT" --frozen --quiet pytest -q -p no:cacheprovider --tb=line -rfEs "$@" > "$output" 2>&1 \
    || code=$?
  cat "$output"
  if [ "$code" -gt 1 ]; then
    echo "pytest exited with $code: environment or collection error, not a graded result"
    code="$HARD_ERROR"
  elif grep -Eq '^SKIPPED|[0-9]+ skipped' "$output"; then
    echo "pytest skipped tests: every grader test must run"
    code="$HARD_ERROR"
  fi
  rm -f "$output"
  return "$code"
}

# zizmor_run ARGS...: zizmor from the locked environment. Exit codes 10 to 14 mean findings
# (return 1); 0 means clean; anything else is a tool error (HARD_ERROR).
zizmor_run() {
  local code=0
  uv run --project "$REPO_ROOT" --frozen --quiet zizmor "$@" || code=$?
  case "$code" in
    0) return 0 ;;
    1[0-4]) return 1 ;;
    *)
      echo "zizmor exited with $code: tool error, not a graded result"
      return "$HARD_ERROR"
      ;;
  esac
}

# tf_test DIR TESTS_DIR: run the grader's .tftest.hcl files from TESTS_DIR against the configuration in DIR.
# terraform test only accepts a test directory inside the configuration, so the tests are copied in.
tf_test() {
  local dir="$1" tests="$2"
  rm -rf "$dir/grader"
  mkdir -p "$dir/grader"
  cp "$tests"/*.tftest.hcl "$dir/grader/"
  terraform -chdir="$dir" test -no-color -test-directory=grader
}

# tf_init DIR: offline-safe init (no backend) of a copied configuration.
tf_init() {
  terraform -chdir="$1" init -backend=false -input=false -no-color
}

# finish: report and exit with the grader's contract code.
finish() {
  if [ "$GRADER_FAILURES" -gt 0 ]; then
    echo "RESULT $GRADER_FAILURES objective(s) not met"
    exit 1
  fi
  echo "RESULT all objectives met"
  exit 0
}
