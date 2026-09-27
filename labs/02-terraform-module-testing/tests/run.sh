#!/usr/bin/env bash
# Grader for lab 02: a reusable Terraform module with its own terraform test suite.
# Usage: labs/02-terraform-module-testing/tests/run.sh <starter-or-solution-directory>
set -euo pipefail

# shellcheck source=../../../scripts/lib/grader.sh
source "$(dirname "$0")/../../../scripts/lib/grader.sh"
TESTS="$(cd "$(dirname "$0")" && pwd)"
TARGET="$(resolve_target "$@")"
require_tool terraform

cp -R "$TARGET/." "$GRADER_WORK/"
find "$GRADER_WORK" -name .terraform -type d -prune -exec rm -rf {} +
MODULE="$GRADER_WORK/modules/queue"
EXAMPLE="$GRADER_WORK/examples/basic"

for dir in "$MODULE" "$EXAMPLE"; do
  name="${dir#"$GRADER_WORK"/}"
  setup "$name: terraform init" tf_init "$dir"
  setup "$name: terraform validate" terraform -chdir="$dir" validate -no-color
done

# count_runs: number of run blocks in the participant's own test files.
count_runs() {
  cat "$MODULE"/tests/*.tftest.hcl 2> /dev/null | grep -Ec '^[[:space:]]*run[[:space:]]+"' || true
}

# own_suite_is_substantial: at least three run blocks, one of them testing a validation.
own_suite_is_substantial() {
  local runs
  runs="$(count_runs)"
  echo "run blocks found: $runs (need 3 or more)"
  [ "$runs" -ge 3 ] && grep -q 'expect_failures' "$MODULE"/tests/*.tftest.hcl
}

check "module: the participant's own terraform test suite passes" \
  terraform -chdir="$MODULE" test -no-color
check "module: the own suite has 3+ run blocks, including an expect_failures test" \
  own_suite_is_substantial
check "module: validations, dead-letter queue, encryption and outputs meet the contract" \
  tf_test "$MODULE" "$TESTS"

finish
