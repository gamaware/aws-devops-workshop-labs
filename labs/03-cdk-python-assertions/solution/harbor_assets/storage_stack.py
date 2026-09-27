"""Product images for the Harbor Goods storefront, stored in S3 with access logs."""

from aws_cdk import Acknowledgment, CfnOutput, Duration, RemovalPolicy, Stack, Validations
from aws_cdk import aws_s3 as s3
from constructs import Construct


class AssetsStack(Stack):
    """An assets bucket and the bucket that receives its server access logs."""

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # S3 server access logs can only be delivered to a bucket encrypted with SSE-S3.
        self.log_bucket = s3.Bucket(
            self,
            "AccessLogs",
            encryption=s3.BucketEncryption.S3_MANAGED,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
            lifecycle_rules=[s3.LifecycleRule(expiration=Duration.days(90))],
            removal_policy=RemovalPolicy.RETAIN,
        )
        Validations.of(self.log_bucket).acknowledge(
            Acknowledgment(
                id="AwsSolutions-S1",
                reason="This bucket receives the access logs; logging it to itself would create a loop.",
            )
        )

        self.assets_bucket = s3.Bucket(
            self,
            "Assets",
            encryption=s3.BucketEncryption.S3_MANAGED,
            block_public_access=s3.BlockPublicAccess.BLOCK_ALL,
            enforce_ssl=True,
            versioned=True,
            server_access_logs_bucket=self.log_bucket,
            server_access_logs_prefix="assets/",
            lifecycle_rules=[s3.LifecycleRule(noncurrent_version_expiration=Duration.days(30))],
            removal_policy=RemovalPolicy.RETAIN,
        )

        CfnOutput(self, "AssetsBucketName", value=self.assets_bucket.bucket_name)
