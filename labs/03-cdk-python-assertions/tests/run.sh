#!/usr/bin/env bash
# Grader for lab 03: AWS CDK in Python with assertions and cdk-nag.
# Usage: labs/03-cdk-python-assertions/tests/run.sh <starter-or-solution-directory>
set -euo pipefail

# shellcheck source=../../../scripts/lib/grader.sh
source "$(dirname "$0")/../../../scripts/lib/grader.sh"
TESTS="$(cd "$(dirname "$0")" && pwd)"
TARGET="$(resolve_target "$@")"
require_tool uv node

cp -R "$TARGET/." "$GRADER_WORK/"
rm -rf "$GRADER_WORK/cdk.out"

# py: run Python from the repository's locked environment (aws-cdk-lib, cdk-nag, pytest).
py() {
  uv run --project "$REPO_ROOT" --frozen --quiet "$@"
}

# count_tests: number of test functions in the learner's own test files.
count_tests() {
  cat "$GRADER_WORK"/tests/test_*.py 2> /dev/null | grep -Ec '^def test_' || true
}

own_suite_is_substantial() {
  local tests
  tests="$(count_tests)"
  echo "test functions found: $tests (need 3 or more)"
  [ "$tests" -ge 3 ]
}

setup "the stack synthesizes (without cdk-nag)" \
  py python -c "import sys; sys.path.insert(0, '$GRADER_WORK')
from aws_cdk import App
from harbor_assets.storage_stack import AssetsStack
app = App(); AssetsStack(app, 'Probe'); app.synth()"

check "own tests: the learner's assertion tests pass" \
  py pytest -q -p no:cacheprovider --tb=line "$GRADER_WORK/tests"
check "own tests: 3 or more assertion tests" \
  own_suite_is_substantial
check "cdk-nag passes and the template keeps data private, encrypted and retained" \
  env LAB_TARGET="$GRADER_WORK" uv run --project "$REPO_ROOT" --frozen --quiet \
  pytest -q -p no:cacheprovider --tb=line "$TESTS/test_grader.py"

finish
