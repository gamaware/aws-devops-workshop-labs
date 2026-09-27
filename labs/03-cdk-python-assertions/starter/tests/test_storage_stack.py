"""The learner's own tests: fine-grained assertions on the synthesized template.

Exercise 4: add at least two more tests, for example that the assets bucket is
versioned and that every bucket policy denies requests without TLS.
"""

import pytest
from aws_cdk import App
from aws_cdk.assertions import Template

from harbor_assets.storage_stack import AssetsStack


@pytest.fixture(scope="module")
def template() -> Template:
    return Template.from_stack(AssetsStack(App(), "TestAssets"))


def test_stack_has_buckets(template: Template) -> None:
    assert template.find_resources("AWS::S3::Bucket")
