"""The learner's own tests: fine-grained assertions on the synthesized template."""

import pytest
from aws_cdk import App
from aws_cdk.assertions import Match, Template

from harbor_assets.storage_stack import AssetsStack


@pytest.fixture(scope="module")
def template() -> Template:
    return Template.from_stack(AssetsStack(App(), "TestAssets"))


def test_creates_an_assets_bucket_and_a_log_bucket(template: Template) -> None:
    template.resource_count_is("AWS::S3::Bucket", 2)


def test_assets_bucket_is_versioned_and_logged(template: Template) -> None:
    template.has_resource_properties(
        "AWS::S3::Bucket",
        {
            "VersioningConfiguration": {"Status": "Enabled"},
            "LoggingConfiguration": {"LogFilePrefix": "assets/"},
        },
    )


def test_buckets_block_all_public_access(template: Template) -> None:
    buckets = template.find_resources("AWS::S3::Bucket")
    for bucket in buckets.values():
        assert bucket["Properties"]["PublicAccessBlockConfiguration"] == {
            "BlockPublicAcls": True,
            "BlockPublicPolicy": True,
            "IgnorePublicAcls": True,
            "RestrictPublicBuckets": True,
        }


def test_bucket_policies_deny_plain_http(template: Template) -> None:
    template.has_resource_properties(
        "AWS::S3::BucketPolicy",
        {
            "PolicyDocument": {
                "Statement": Match.array_with(
                    [Match.object_like({"Effect": "Deny", "Condition": {"Bool": {"aws:SecureTransport": "false"}}})]
                )
            }
        },
    )


def test_buckets_survive_stack_deletion(template: Template) -> None:
    for bucket in template.find_resources("AWS::S3::Bucket").values():
        assert bucket["DeletionPolicy"] == "Retain"
