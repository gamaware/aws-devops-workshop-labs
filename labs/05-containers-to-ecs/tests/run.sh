#!/usr/bin/env bash
# Grader for lab 05: from a Dockerfile to an ECS task definition, checked locally.
# Usage: labs/05-containers-to-ecs/tests/run.sh <starter-or-solution-directory>
set -euo pipefail

# shellcheck source=../../../scripts/lib/grader.sh
source "$(dirname "$0")/../../../scripts/lib/grader.sh"
TESTS="$(cd "$(dirname "$0")" && pwd)"
TARGET="$(resolve_target "$@")"
require_tool uv python3 docker hadolint curl

cp -R "$TARGET/." "$GRADER_WORK/"
# The grader tests read the copied target from LAB_TARGET.
export LAB_TARGET="$GRADER_WORK"

setup "Docker daemon is running" docker info
setup "the app compiles" python3 -c "import ast, sys; ast.parse(open(sys.argv[1]).read())" "$GRADER_WORK/app/server.py"
setup "task definition is valid JSON" python3 -m json.tool "$GRADER_WORK/ecs/task-definition.json" /dev/null

check "Dockerfile passes hadolint" hadolint "$GRADER_WORK/Dockerfile"
check "image and task definition follow the Fargate hardening checklist" \
  pytest_run "$TESTS/test_grader.py"
check "image has no pip, runs read-only as non-root without capabilities, turns healthy, serves /products" \
  "$TESTS/smoke.sh" "$GRADER_WORK"

finish
