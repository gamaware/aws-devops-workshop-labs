# shellcheck shell=bash
# Shared helpers for the lab graders (labs/NN-*/tests/run.sh). Source it; do not run it.
#
# Exit codes of every grader, relied on by scripts/verify-labs.sh:
#   0  every objective is met
#   1  the target is valid but at least one objective is not met (the expected state of a starter)
#   2  the target is broken or a tool is missing (it cannot even be graded)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GRADER_FAILURES=0
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
check() {
  local description="$1"
  shift
  if "$@" > "$GRADER_LOG" 2>&1; then
    echo "PASS   $description"
  else
    echo "FAIL   $description"
    sed 's/^/       /' "$GRADER_LOG" | tail -n 40
    GRADER_FAILURES=$((GRADER_FAILURES + 1))
  fi
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
