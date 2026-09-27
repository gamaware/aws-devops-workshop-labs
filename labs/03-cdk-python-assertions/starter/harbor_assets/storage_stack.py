"""Product images for the Harbor Goods storefront, stored in S3 with access logs."""

from aws_cdk import CfnOutput, Stack
from aws_cdk import aws_s3 as s3
from constructs import Construct


class AssetsStack(Stack):
    """An assets bucket and the bucket that receives its server access logs."""

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Exercise 1: run `npx aws-cdk@2 synth` (or the grader) and read the cdk-nag findings.
        # Exercise 2: create self.log_bucket ("AccessLogs") for server access logs: SSE-S3,
        #   all public access blocked, TLS enforced, a 90-day expiration rule, RemovalPolicy.RETAIN.
        #   It cannot log to itself: acknowledge AwsSolutions-S1 on it with
        #   Validations.of(...).acknowledge(Acknowledgment(id=..., reason=...)) and a real reason.
        # Exercise 3: harden the assets bucket below: encryption, public access blocked, TLS
        #   enforced, versioning, access logs to self.log_bucket with the prefix "assets/",
        #   noncurrent versions expiring after 30 days, RemovalPolicy.RETAIN.
        self.assets_bucket = s3.Bucket(self, "Assets")

        CfnOutput(self, "AssetsBucketName", value=self.assets_bucket.bucket_name)
