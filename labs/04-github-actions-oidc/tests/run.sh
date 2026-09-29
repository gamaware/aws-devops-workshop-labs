#!/usr/bin/env bash
# Grader for lab 04: GitHub Actions CI with OIDC to AWS, checked offline.
# Usage: labs/04-github-actions-oidc/tests/run.sh <starter-or-solution-directory>
set -euo pipefail

# shellcheck source=../../../scripts/lib/grader.sh
source "$(dirname "$0")/../../../scripts/lib/grader.sh"
TESTS="$(cd "$(dirname "$0")" && pwd)"
TARGET="$(resolve_target "$@")"
require_tool uv

cp -R "$TARGET/." "$GRADER_WORK/"
# The grader tests read the copied target from LAB_TARGET.
export LAB_TARGET="$GRADER_WORK"
export PYTHONPATH="$TESTS"
WORKFLOW="$GRADER_WORK/workflows/deploy.yml"

# py: run a tool from the repository's locked environment (actionlint, zizmor, pytest).
py() {
  uv run --project "$REPO_ROOT" --frozen --quiet "$@"
}

setup "zizmor is installed" py zizmor --version
setup "workflow is valid GitHub Actions syntax (actionlint)" py actionlint -no-color "$WORKFLOW"
setup "IAM policies are valid JSON" py python -m json.tool "$GRADER_WORK/iam/trust-policy.json" /dev/null
setup "deploy policy is valid JSON" py python -m json.tool "$GRADER_WORK/iam/deploy-policy.json" /dev/null

check "workflow passes zizmor's security audit (offline)" \
  zizmor_run --offline --no-progress --min-severity low "$WORKFLOW"
check "workflow uses OIDC, SHA pins, scoped permissions; trust and deploy policies are tight" \
  pytest_run "$TESTS/test_grader.py"

finish
