# Lab 03 instructor notes: CDK in Python with assertions and cdk-nag

Lab directory: [labs/03-cdk-python-assertions](../labs/03-cdk-python-assertions/). Background reading for you:
[docs/explanation](../docs/explanation/).

## Timing

Suggested duration: 90 minutes.

| Part | Minutes |
| --- | --- |
| Brief | 5 |
| Opening demo | 5 |
| Work time | 65 |
| Debrief | 15 |

In a 1:1 session, plan exercises 1 to 3 for the session and exercise 4 as practice.

## Learning goals

By the end, participants can:

- Synthesize an environment-agnostic CDK stack without AWS credentials.
- Read cdk-nag AwsSolutions findings and fix the resource behind each one.
- Acknowledge a rule that does not apply, on the narrowest construct, with a reason a reviewer can check.
- Write fine-grained assertions with `aws_cdk.assertions.Template` and `Match`.
- Explain `RemovalPolicy.RETAIN` and what `cdk destroy` leaves behind.

## Opening demo (5 minutes)

1. Run `make check LAB=03` on the starter. Point at `ok     the stack synthesizes (without cdk-nag)`: the code
   runs, so everything after it is about objectives.
2. Show the two cdk-nag findings in the output: `AwsSolutions-S1` (no server access logs) and `AwsSolutions-S10`
   (no TLS requirement), both on `GradedAssets/Assets/Resource`. That is exercise 1.
3. Open `starter/app.py` and show `Validations.of(app).add_plugins(AwsSolutionsChecks(...))`. This lab uses
   cdk-nag 3, which plugs into the CDK validation framework. Say it now: `NagSuppressions` from cdk-nag 2 no
   longer exists; acknowledgments use `Validations.of(construct).acknowledge(Acknowledgment(id=..., reason=...))`.
4. Show `test_grader.py`'s `MIN_REASON_LENGTH = 20` and the check that the assets bucket carries no
   acknowledgment.

## Exercise map

| Exercise | File | Grader check | Grader tests |
| --- | --- | --- | --- |
| 1: read the findings | none (run the grader or synth) | `cdk-nag passes and the template keeps data private, encrypted and retained` | `test_cdk_nag_aws_solutions_checks_pass` shows the findings |
| 2: log bucket and its acknowledgment | `harbor_assets/storage_stack.py` | same check | `test_two_buckets_assets_and_access_logs`, `test_every_bucket_blocks_public_access_and_is_encrypted`, `test_every_bucket_denies_requests_without_tls`, `test_buckets_are_retained_when_the_stack_is_deleted`, `test_acknowledged_rules_carry_a_reason_and_skip_the_assets_bucket` |
| 3: harden the assets bucket | `harbor_assets/storage_stack.py` | same check | `test_cdk_nag_aws_solutions_checks_pass`, `test_assets_bucket_is_versioned_and_logs_to_the_log_bucket`, plus the bucket-wide tests above |
| 4: own tests | `tests/test_storage_stack.py` | `own tests: the learner's assertion tests pass` and `own tests: 3 or more assertion tests` | the learner's own `test_` functions |

## Common mistakes

**Suppressions in the cdk-nag 2 style.** `from cdk_nag import NagSuppressions` fails with an `ImportError` in
cdk-nag 3. The stack cannot even load, so the grader stops at the precondition:

```text
BROKEN the stack synthesizes (without cdk-nag)
```

Point the learner at the Exercise 2 comment: `Validations.of(self.log_bucket).acknowledge(Acknowledgment(...))`,
with `Acknowledgment` imported from `aws_cdk`.

**Acknowledgment on the stack instead of the log bucket.** `Validations.of(self).acknowledge(...)` applies to
every construct in the stack, including the assets bucket:

```text
E   AssertionError: fix the assets bucket instead of acknowledging its findings
```

The same failure appears when a learner acknowledges `AwsSolutions-S1` or `AwsSolutions-S10` on the assets
bucket instead of adding access logs and `enforce_ssl=True`.

**A short reason.** A reason under 20 characters, such as `"not needed"`, fails with a
message that ends in `AwsSolutions-S1 needs a real reason`. A good reason names the constraint: the log bucket
cannot log to itself.

**Only one bucket.** Learners who add logging by pointing the assets bucket at itself, or who forget
`self.log_bucket`, see `assert 1 == 2` from `test_two_buckets_assets_and_access_logs`.

**TLS on one bucket only.** `enforce_ssl=True` must be on both buckets. The failure lists the bucket without a
policy: `every bucket needs a policy that denies aws:SecureTransport = false`.

**Tests the grader does not count.** The grader counts lines that start with `def test_` in `tests/test_*.py`.
The grader skips indented test methods inside a class: `test functions found: 1 (need 3 or more)`.

**Waiting for the first synthesis.** Each check synthesizes the stack through jsii and Node.js. The first run in
a session takes longer; tell learners to wait for the `RESULT` line before they run the grader again.

## Debrief questions

1. cdk-nag found two problems on the starter. Which other AwsSolutions rules did your final stack have to satisfy?
2. When is an acknowledgment the right answer, and what makes a reason good enough for a reviewer?
3. Your own tests and the grader both inspect the template. What is the difference between a snapshot test and
   the fine-grained assertions you wrote?
4. Both buckets use `RemovalPolicy.RETAIN`. What happens to them on `cdk destroy`, and who cleans them up?
5. The grader passes a log bucket encrypted with `KMS_MANAGED`, but S3 server access logging only delivers to
   targets with SSE-S3 default encryption. What kind of check would catch that?

## Stretch goals

- Add a test that uses `Match.object_like` to assert the 90-day expiration rule on the log bucket.
- Add a CDK Aspect that fails synthesis when any bucket lacks `RemovalPolicy.RETAIN`, and a test for it.
- Add the `HIPAASecurityChecks` or `NIST80053R5Checks` pack from cdk-nag and discuss the new findings.

## If you have a sandbox

Optional, in a sandbox account only (see [Use a sandbox account](../docs/how-to/use-a-sandbox-account.md)). The
CDK CLI needs network access and a bootstrapped account and Region.

```bash
cd labs/03-cdk-python-assertions/solution
uv run --project ../../.. npx aws-cdk@2 bootstrap
uv run --project ../../.. npx aws-cdk@2 deploy HarborAssets
```

`cdk synth` and `cdk deploy` fail while cdk-nag reports findings, which shows the team that the rule pack is a
gate, not a report. Upload one object and show the access log appear in the log bucket under `assets/` after a
few minutes.

Cleanup: `cdk destroy` leaves both buckets because of `RemovalPolicy.RETAIN`. Delete them by hand:

```bash
uv run --project ../../.. npx aws-cdk@2 destroy HarborAssets
aws s3 ls | grep -i harborassets                        # find the two retained buckets
```

In the S3 console, select each bucket, choose "Empty" (it deletes every object version, which matters for the
versioned assets bucket), then "Delete". Leave the `CDKToolkit` stack if the participant plans to use CDK again;
otherwise delete it
and its staging bucket.
