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
WORKFLOW="$GRADER_WORK/workflows/deploy.yml"

# py: run a tool from the repository's locked environment (actionlint, zizmor, pytest).
py() {
  uv run --project "$REPO_ROOT" --frozen --quiet "$@"
}

setup "workflow is valid GitHub Actions syntax (actionlint)" py actionlint -no-color "$WORKFLOW"
setup "IAM policies are valid JSON" py python -m json.tool "$GRADER_WORK/iam/trust-policy.json" /dev/null
setup "deploy policy is valid JSON" py python -m json.tool "$GRADER_WORK/iam/deploy-policy.json" /dev/null

check "workflow passes zizmor's security audit (offline)" \
  py zizmor --offline --no-progress --min-severity low "$WORKFLOW"
check "workflow uses OIDC, SHA pins, least privilege; trust and deploy policies are tight" \
  env LAB_TARGET="$GRADER_WORK" PYTHONPATH="$TESTS" uv run --project "$REPO_ROOT" --frozen --quiet \
  pytest -q -p no:cacheprovider --tb=line "$TESTS/test_grader.py"

finish
