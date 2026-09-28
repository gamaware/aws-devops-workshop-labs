#!/usr/bin/env bash
# Manual end-to-end test of the Terraform lab solutions against a real AWS account
# (make test-live). Never runs in CI. Uses the maintainer's "dev" profile only, tags every
# resource purpose=portfolio-test, destroys everything on exit (success, failure or Ctrl-C)
# and then checks that nothing tagged with this run is left.
#
# What it proves that the mocked tests cannot:
#   lab 01  the state bucket applies; the app stack keeps its state in it through the S3
#           backend with native locking, and the SSM parameter exists
#   lab 02  the queue module creates both queues and the redrive policy AWS accepts
# Labs 03 to 05 are not deployed: 03 needs a bootstrapped CDK account, 04 a real GitHub
# repository, 05 an ECR repository and a VPC. Their graders already run them locally.
#
# Cost: under USD 0.01 for a run of a few minutes (S3 requests, SQS, a standard SSM parameter).
# Env: LIVE_REGION (default us-east-1), LIVE_YES=1 skips the confirmation prompt.
# Output goes to a temporary directory outside the repository.
set -euo pipefail

PROFILE="dev"
REGION="${LIVE_REGION:-us-east-1}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_ID="$(date +%s | tail -c 7)"
WORK="$(mktemp -d)"
BUCKET="harbor-labs-tfstate-$RUN_ID"
TAG_KEY="purpose"
TAG_VALUE="portfolio-test"

echo "Account for this run (profile $PROFILE):"
aws sts get-caller-identity --profile "$PROFILE" --output table
if [ "${LIVE_YES:-0}" != "1" ]; then
  read -r -p "Create and destroy lab resources (run $RUN_ID) in $REGION on this account? [y/N] " answer
  [ "$answer" = "y" ] || exit 1
fi

# Terraform reads the profile from the environment; scoped to this script.
export AWS_PROFILE="$PROFILE"
export AWS_REGION="$REGION"
export TF_IN_AUTOMATION=1

aws_cli() {
  aws --profile "$PROFILE" --region "$REGION" "$@"
}

# Copy the solutions and add an override file with the test tags, so the lab code stays
# exactly as participants see it. Terraform merges *_override.tf files into the configuration.
add_test_tags() {
  local stack="$1" lab="$2"
  cat > "$stack/live_override.tf" << HCL
provider "aws" {
  region = "$REGION"
  default_tags {
    tags = {
      project    = "harbor-goods"
      lab        = "$lab"
      managed-by = "terraform"
      $TAG_KEY   = "$TAG_VALUE"
      run        = "$RUN_ID"
    }
  }
}
HCL
}

mkdir -p "$WORK/lab01" "$WORK/lab02"
cp -R "$REPO_ROOT/labs/01-terraform-remote-state/solution/." "$WORK/lab01/"
cp -R "$REPO_ROOT/labs/02-terraform-module-testing/solution/." "$WORK/lab02/"
find "$WORK" -name .terraform -type d -prune -exec rm -rf {} +
BOOTSTRAP="$WORK/lab01/bootstrap"
APP="$WORK/lab01/app"
QUEUE="$WORK/lab02/examples/basic"
add_test_tags "$BOOTSTRAP" "01-terraform-remote-state"
add_test_tags "$APP" "01-terraform-remote-state"
add_test_tags "$QUEUE" "02-terraform-module-testing"

cat > "$APP/backend.hcl" << HCL
bucket       = "$BUCKET"
key          = "storefront/dev/terraform.tfstate"
region       = "$REGION"
encrypt      = true
use_lockfile = true
HCL

teardown() {
  set +e
  echo "--- teardown"
  terraform -chdir="$QUEUE" destroy -input=false -auto-approve
  terraform -chdir="$APP" destroy -input=false -auto-approve -var environment=dev
  terraform -chdir="$BOOTSTRAP" destroy -input=false -auto-approve -var "bucket_name=$BUCKET" -var force_destroy=true

  echo "--- leftovers tagged run=$RUN_ID (deleted SQS queues can stay listed for up to a minute)"
  local left="unknown"
  for _ in 1 2 3 4 5 6; do
    left="$(aws_cli resourcegroupstaggingapi get-resources \
      --tag-filters "Key=$TAG_KEY,Values=$TAG_VALUE" "Key=run,Values=$RUN_ID" \
      --query 'ResourceTagMappingList[].ResourceARN' --output json)"
    [ "$left" = "[]" ] && break
    sleep 10
  done
  rm -rf "$WORK"
  if [ "$left" != "[]" ]; then
    echo "LEFTOVER RESOURCES, delete them by hand:" >&2
    echo "$left" >&2
    exit 1
  fi
  echo "Nothing left behind."
}
trap teardown EXIT

echo "--- lab 01: state bucket (local state)"
terraform -chdir="$BOOTSTRAP" init -input=false
terraform -chdir="$BOOTSTRAP" apply -input=false -auto-approve -var "bucket_name=$BUCKET" -var force_destroy=true

echo "--- lab 01: app stack (state in the bucket, S3 native locking)"
terraform -chdir="$APP" init -input=false -backend-config=backend.hcl
terraform -chdir="$APP" apply -input=false -auto-approve -var environment=dev
aws_cli s3api head-object --bucket "$BUCKET" --key storefront/dev/terraform.tfstate > /dev/null
aws_cli ssm get-parameter --name /harbor-goods/dev/storefront/feature-flags --query Parameter.Value --output text
echo "state object and parameter found"

echo "--- lab 02: queue module example"
terraform -chdir="$QUEUE" init -input=false
terraform -chdir="$QUEUE" apply -input=false -auto-approve
queue_url="$(terraform -chdir="$QUEUE" output -raw queue_url)"
aws_cli sqs get-queue-attributes --queue-url "$queue_url" --attribute-names RedrivePolicy SqsManagedSseEnabled \
  --query Attributes --output json
echo "live test passed; tearing down"
