"""Grader for lab 03: the assets stack passes cdk-nag and keeps its data safe.

Run through tests/run.sh, which sets LAB_TARGET to the copied starter or solution.
"""

import json
import os
import sys
import tempfile
from pathlib import Path

import pytest
from aws_cdk import App, Aspects, Validations
from aws_cdk.assertions import Template
from cdk_nag import AwsSolutionsChecks, WriteNagSuppressionsToCloudFormationAspect

TARGET = Path(os.environ["LAB_TARGET"])
sys.path.insert(0, str(TARGET))

from harbor_assets.storage_stack import AssetsStack  # noqa: E402

MIN_REASON_LENGTH = 20


def nag_violations() -> list[str]:
    """Synthesize the stack with the AWS Solutions pack and return its unacknowledged findings."""
    outdir = tempfile.mkdtemp(prefix="lab03-")
    app = App(outdir=outdir)
    AssetsStack(app, "GradedAssets")
    Validations.of(app).add_plugins(AwsSolutionsChecks(app))
    try:
        app.synth()
    except RuntimeError:
        report = json.loads(Path(outdir, "validation-report.json").read_text())
        return [
            f"{violation['ruleName']} on {construct['constructPath']}: {violation['description']}"
            for plugin in report["pluginReports"]
            for violation in plugin["violations"]
            for construct in violation["violatingConstructs"]
        ]
    return []


@pytest.fixture(scope="module")
def resources() -> dict:
    """The synthesized template, with each acknowledged cdk-nag rule copied into the resource metadata."""
    app = App()
    stack = AssetsStack(app, "GradedAssets")
    Aspects.of(app).add(WriteNagSuppressionsToCloudFormationAspect())
    return Template.from_stack(stack).to_json()["Resources"]


def of_type(resources: dict, resource_type: str) -> dict:
    return {name: body for name, body in resources.items() if body["Type"] == resource_type}


def test_cdk_nag_aws_solutions_checks_pass() -> None:
    violations = nag_violations()
    assert not violations, "cdk-nag AwsSolutions findings:\n  " + "\n  ".join(violations)


def test_two_buckets_assets_and_access_logs(resources: dict) -> None:
    assert len(of_type(resources, "AWS::S3::Bucket")) == 2


def test_every_bucket_blocks_public_access_and_is_encrypted(resources: dict) -> None:
    for name, bucket in of_type(resources, "AWS::S3::Bucket").items():
        properties = bucket.get("Properties", {})
        blocks = properties.get("PublicAccessBlockConfiguration", {})
        assert len(blocks) == 4 and all(blocks.values()), f"{name}: public access not fully blocked"
        assert "BucketEncryption" in properties, f"{name}: no default encryption"


def test_assets_bucket_is_versioned_and_logs_to_the_log_bucket(resources: dict) -> None:
    buckets = of_type(resources, "AWS::S3::Bucket")
    logged = [body["Properties"] for body in buckets.values() if "LoggingConfiguration" in body.get("Properties", {})]
    assert len(logged) == 1, "exactly one bucket (the assets bucket) sends server access logs"
    assets = logged[0]
    assert assets.get("VersioningConfiguration", {}).get("Status") == "Enabled", "assets bucket must be versioned"
    destination = assets["LoggingConfiguration"]["DestinationBucketName"]
    assert destination.get("Ref") in buckets, "access logs must go to the log bucket in this stack"


def test_log_bucket_uses_sse_s3(resources: dict) -> None:
    buckets = of_type(resources, "AWS::S3::Bucket")
    targets = {
        body["Properties"]["LoggingConfiguration"]["DestinationBucketName"].get("Ref")
        for body in buckets.values()
        if "LoggingConfiguration" in body.get("Properties", {})
    }
    for name in targets & set(buckets):
        rules = buckets[name]["Properties"].get("BucketEncryption", {}).get("ServerSideEncryptionConfiguration", [])
        algorithms = {rule["ServerSideEncryptionByDefault"]["SSEAlgorithm"] for rule in rules}
        assert algorithms == {"AES256"}, f"{name}: S3 delivers access logs only to SSE-S3 (AES256) buckets"


def test_every_bucket_denies_requests_without_tls(resources: dict) -> None:
    buckets = of_type(resources, "AWS::S3::Bucket")
    protected = set()
    for policy in of_type(resources, "AWS::S3::BucketPolicy").values():
        statements = policy["Properties"]["PolicyDocument"]["Statement"]
        if any(
            statement["Effect"] == "Deny"
            and statement.get("Condition", {}).get("Bool", {}).get("aws:SecureTransport") == "false"
            for statement in statements
        ):
            protected.add(policy["Properties"]["Bucket"]["Ref"])
    assert protected == set(buckets), "every bucket needs a policy that denies aws:SecureTransport = false"


def test_buckets_are_retained_when_the_stack_is_deleted(resources: dict) -> None:
    for name, bucket in of_type(resources, "AWS::S3::Bucket").items():
        assert bucket.get("DeletionPolicy") == "Retain", f"{name}: deleting the stack would delete the data"


def test_acknowledged_rules_carry_a_reason_and_skip_the_assets_bucket(resources: dict) -> None:
    for name, body in resources.items():
        suppressed = body.get("Metadata", {}).get("cdk_nag", {}).get("rules_to_suppress", [])
        for rule in suppressed:
            assert len(rule.get("reason", "")) >= MIN_REASON_LENGTH, f"{name}: {rule['id']} needs a real reason"
        if "LoggingConfiguration" in body.get("Properties", {}):
            assert not suppressed, "fix the assets bucket instead of acknowledging its findings"
