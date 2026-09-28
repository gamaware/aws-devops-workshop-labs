"""CDK entry point: `cdk synth` from this directory runs the AWS Solutions checks from cdk-nag."""

from aws_cdk import App, Tags, Validations
from cdk_nag import AwsSolutionsChecks

from harbor_assets.storage_stack import AssetsStack

app = App()
# No env: the stack is environment-agnostic, so synthesis needs no AWS credentials or lookups.
AssetsStack(app, "HarborAssets")
Tags.of(app).add("project", "harbor-goods")
Validations.of(app).add_plugins(AwsSolutionsChecks(app, write_suppressions_to_cloud_formation=True))
app.synth()
