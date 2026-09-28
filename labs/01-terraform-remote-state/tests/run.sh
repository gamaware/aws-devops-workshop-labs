#!/usr/bin/env bash
# Grader for lab 01: Terraform fundamentals and the remote-state pattern.
# Usage: labs/01-terraform-remote-state/tests/run.sh <starter-or-solution-directory>
set -euo pipefail

# shellcheck source=../../../scripts/lib/grader.sh
source "$(dirname "$0")/../../../scripts/lib/grader.sh"
TESTS="$(cd "$(dirname "$0")" && pwd)"
TARGET="$(resolve_target "$@")"
require_tool terraform

# has_setting KEY VALUE FILE: FILE sets KEY to VALUE (HCL "key = value" on one line).
has_setting() {
  grep -Eq "^$1[[:space:]]*=[[:space:]]*$2[[:space:]]*$" "$3"
}

cp -R "$TARGET/." "$GRADER_WORK/"
rm -rf "$GRADER_WORK"/*/.terraform

for stack in bootstrap app; do
  setup "$stack: terraform init" tf_init "$GRADER_WORK/$stack"
  setup "$stack: terraform validate" terraform -chdir="$GRADER_WORK/$stack" validate -no-color
done

check "bootstrap: state bucket is versioned, encrypted, private and TLS-only" \
  tf_test "$GRADER_WORK/bootstrap" "$TESTS/bootstrap"
check "app: environment is validated and parameters are namespaced" \
  tf_test "$GRADER_WORK/app" "$TESTS/app"
check "app: declares a partial S3 backend" \
  grep -Eq '^[[:space:]]*backend[[:space:]]+"s3"[[:space:]]*\{[[:space:]]*\}' "$GRADER_WORK/app/versions.tf"
check "app: backend.hcl.example turns on S3 native locking" \
  has_setting use_lockfile true "$GRADER_WORK/app/backend.hcl.example"
check "app: backend.hcl.example turns on encryption" \
  has_setting encrypt true "$GRADER_WORK/app/backend.hcl.example"
check "app: backend.hcl.example keeps one state key per stack and environment" \
  has_setting key '"storefront/dev/terraform\.tfstate"' "$GRADER_WORK/app/backend.hcl.example"

finish
