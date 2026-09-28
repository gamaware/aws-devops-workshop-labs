# Lab 03: AWS CDK in Python with assertions and cdk-nag

Correct an S3 stack so it passes the AWS Solutions checks in cdk-nag, then use assertion tests to lock in the template
you intended.

## Objectives

After completing the lab, you can:

- use AWS CDK v2 in Python to define an S3 bucket alongside its access-log bucket;
- interpret cdk-nag findings and resolve them through code changes instead of suppressions;
- provide a verifiable reason when acknowledging a finding you cannot resolve;
- test specific template details with `aws_cdk.assertions.Template`;
- keep the stack environment-agnostic so you can synthesize without credentials.

## Prerequisites

- Familiarity with Python classes, functions and `pytest` tests.
- Install `uv`, Node.js 22 or 24 (which aws-cdk-lib runs on) and `make`, then run `make setup`. Follow
  [set up your machine](../../docs/how-to/set-up-your-machine.md).
- Optionally, use the CDK CLI via `npx aws-cdk@2` to run `synth` directly.
- You do not need an AWS account.

## Duration

Allow 85 minutes.

## Scenario

Harbor Goods uses S3 to serve its storefront's product images. The initial stack works, but fails when the security team
runs cdk-nag in the pipeline because access logging is missing and the bucket allows plain HTTP. The team also needs
tests to catch accidental changes that make a bucket public or deletable.

| Path | Purpose |
| --- | --- |
| `starter/harbor_assets/storage_stack.py` | The stack you fix |
| `starter/app.py`, `starter/cdk.json` | The CDK app, with the AWS Solutions checks turned on |
| `starter/tests/test_storage_stack.py` | Your assertion tests |

## Steps

Use `starter/` for your work; the numbers in its `Exercise` comments correspond to the steps here.

1. Start by running the grader and reviewing its cdk-nag findings:

   ```bash
   make setup
   make check LAB=03
   ```

   Alternatively, run the CDK CLI in the starter directory to synthesize:
   `uv run --project ../../.. npx aws-cdk@2 synth`.

2. **Define the access-log bucket** (exercise 2). Use `self.log_bucket` and the ID `AccessLogs`, setting
   `encryption=s3.BucketEncryption.S3_MANAGED` because S3 only delivers access logs to SSE-S3 buckets. Include
   `block_public_access=s3.BlockPublicAccess.BLOCK_ALL`, `enforce_ssl=True`, an expiration rule of 90 days and
   `removal_policy=RemovalPolicy.RETAIN`.

3. **Acknowledge the finding that cannot be resolved.** Because a log bucket cannot log access to itself, cdk-nag will
   always report `AwsSolutions-S1` for it. In cdk-nag v3, use the CDK's native acknowledgment API:

   ```python
   Validations.of(self.log_bucket).acknowledge(
       Acknowledgment(
           id="AwsSolutions-S1", reason="This bucket receives the access logs; logging it to itself would loop."
       )
   )
   ```

   Your reason must contain at least 20 characters to pass the grader, which also rejects any assets-bucket
   acknowledgment.

4. **Secure the assets bucket** (exercise 3). Configure encryption, block all public access, and set `enforce_ssl=True`,
   `versioned=True`, `server_access_logs_bucket=self.log_bucket` and `server_access_logs_prefix="assets/"`. Add a
   noncurrent-version expiration rule of 30 days and apply `RemovalPolicy.RETAIN`.

5. **Add assertion tests** in `tests/test_storage_stack.py` (exercise 4), writing at least two. Examples include:

   ```python
   def test_assets_bucket_is_versioned_and_logged(template: Template) -> None:
       template.has_resource_properties(
           "AWS::S3::Bucket",
           {"VersioningConfiguration": {"Status": "Enabled"}, "LoggingConfiguration": {"LogFilePrefix": "assets/"}},
       )
   ```

   To execute just your tests, run `uv run pytest labs/03-cdk-python-assertions/starter/tests`.

6. Repeat grading until `PASS` appears on every line:

   ```bash
   make check LAB=03
   ```

## Expected result

```text
ok     the stack synthesizes (without cdk-nag)
PASS   own tests: the participant's assertion tests pass
PASS   own tests: 3 or more assertion tests
PASS   cdk-nag passes and the template keeps data private, encrypted and retained
RESULT all objectives met
```

The [grader's tests](tests/test_grader.py) inspect the synthesized template for two private, encrypted buckets, SSE-S3
encryption on the log bucket, TLS-only policies on both, assets-bucket versioning and logging, and `Retain` on each
bucket. Use [`solution/`](solution/) for comparison.

## Reset

You deploy nothing during this lab. If you used `cdk deploy` in a sandbox, follow it with `cdk destroy`, then manually
empty and delete both buckets, which `RemovalPolicy.RETAIN` intentionally preserves. Afterward, restore the starter
files:

```bash
make reset LAB=03
```

## Going further

- Write a snapshot test, then discuss where it adds value and where it merely captures noise.
- Enable another rule pack, such as `NIST80053R5Checks`, to compare the findings against those from the AWS Solutions
  pack.
