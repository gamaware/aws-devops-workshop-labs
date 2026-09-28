# Lab 02 instructor notes: Terraform module testing

Lab directory: [labs/02-terraform-module-testing](../labs/02-terraform-module-testing/). Background reading for
you: [docs/explanation](../docs/explanation/).

## Timing

Suggested duration: 85 minutes.

| Part | Minutes |
| --- | --- |
| Brief | 5 |
| Opening demo | 5 |
| Work time | 60 |
| Debrief | 15 |

In a 1:1 session, plan exercises 1 to 5 for the session and 6 to 9 as practice.

## Learning goals

By the end, participants can:

- Design a module interface: input validation that fails at plan time with a clear message.
- Build an SQS queue with a dead-letter queue, a redrive policy and a redrive allow policy.
- Write `terraform test` files with `mock_provider`, `assert` and `expect_failures`.
- Choose between `command = plan` and `command = apply` in a mocked test.
- Treat an example directory as a usage document and a test fixture.

## Opening demo (5 minutes)

1. Run `make check LAB=02` on the starter. Point out that the first objective already passes: the starter ships
   one test, and it passes. The other two fail.
2. Read `run blocks found: 1 (need 3 or more)`. The grader checks the participant's own suite, not only the module.
3. Open `tests/queue_grader.tftest.hcl` and show the `override_resource` blocks: they give the two queues fixed
   ARNs, so the grader can tell them apart. Mention the `Invalid override target` warning: it stays until
   exercise 4 creates `aws_sqs_queue.dlq`, and it is not the failure.
4. Show the seven `skip` lines after the first failed run block, and say that exercise 1 unlocks the rest.

## Exercise map

All exercises from 1 to 8 feed one check, `module: validations, dead-letter queue, encryption and outputs meet the
contract`. The run block names tell you which exercise failed.

| Exercise | File | Grader check | Run block |
| --- | --- | --- | --- |
| 1: name validation | `modules/queue/variables.tf` | contract check | `rejects_an_invalid_name` |
| 2: tag validations | `modules/queue/variables.tf` | contract check | `rejects_tags_without_an_owner`, `rejects_an_unknown_environment_tag` |
| 3: `max_receive_count` | `modules/queue/variables.tf` | contract check | `rejects_a_receive_count_of_zero`, `rejects_a_receive_count_above_ten` |
| 4: dead-letter queue | `modules/queue/main.tf` | contract check | `failed_messages_reach_the_dead_letter_queue` |
| 5: redrive policy | `modules/queue/main.tf` | contract check | `failed_messages_reach_the_dead_letter_queue` |
| 6: encryption and tags | `modules/queue/main.tf` | contract check | `both_queues_are_encrypted_and_tagged` |
| 7: redrive allow policy | `modules/queue/main.tf` | contract check | `failed_messages_reach_the_dead_letter_queue` |
| 8: `dlq_url`, `dlq_arn` outputs | `modules/queue/outputs.tf` | contract check | `outputs_expose_both_queues` |
| 9: own tests | `modules/queue/tests/queue.tftest.hcl` | `module: the participant's own terraform test suite passes` and `module: the own suite has 3+ run blocks, including an expect_failures test` | the participant's own run blocks |

## Common mistakes

**Only the first failure shows.** After one run block fails, Terraform skips the rest of the file:

```text
  run "rejects_an_invalid_name"... fail
Error: Missing expected failure
  run "rejects_a_receive_count_of_zero"... skip
  run "rejects_a_receive_count_above_ten"... skip
  ...
Failure! 0 passed, 1 failed, 7 skipped.
```

Participants who start with the dead-letter queue see the same output as before and think the grader ignores their
work. Work the exercises in order, or run the grader's file yourself and read the first `fail` line.

**Redrive allow policy written inline on the dead-letter queue.** `aws_sqs_queue` accepts a
`redrive_allow_policy` argument, but the dead-letter queue then references the main queue while the main queue
references the dead-letter queue:

```text
BROKEN modules/queue: terraform validate
       Error: Cycle: aws_sqs_queue.dlq, aws_sqs_queue.this
```

Exercise 7 asks for the separate `aws_sqs_queue_redrive_allow_policy` resource because it breaks this cycle.

**The URL where the ARN belongs.** `sourceQueueArns = [aws_sqs_queue.this.id]` passes a URL. The assertion
`Only the main queue may use the dead-letter queue (redrive allow policy byQueue).` fails. `queue_url` in the
redrive allow policy resource takes the dead-letter queue's `id`; `sourceQueueArns` takes the main queue's `arn`.

**`maxReceiveCount` as a string.** Interpolating it, `"${var.max_receive_count}"`, makes `jsondecode` return
`"5"`, not `5`, and the check `max_receive_count must default to 5 and feed the redrive policy.` fails.

**Other resource names.** The grader and its overrides address `aws_sqs_queue.dlq`. A dead-letter queue named
`aws_sqs_queue.dead_letter` keeps the `Invalid override target` warning and ends in `Reference to undeclared
resource`.

**Own tests that assert on ARNs under `command = plan`.** ARNs are unknown at plan time, and under a mocked
provider they are random strings at apply time. Participants who assert
`aws_sqs_queue.dlq.arn == "arn:aws:sqs:..."` see their own suite fail. Assert on names, flags and tags, or add an
`override_resource` block like the grader does.

**Own suite too small.** The grader counts lines that start with `run "` in `modules/queue/tests/*.tftest.hcl`
and needs at least three, plus one `expect_failures`. Tests in another directory do not count.

## Debrief questions

1. Which validation gave the most useful error message, and who reads that message in real use?
2. Why does the dead-letter queue keep messages for 14 days while the main queue does not?
3. What does the redrive allow policy prevent that the redrive policy does not?
4. The tests use `mock_provider`. Which bugs would still reach a real `terraform apply`?
5. Where would you run this module's tests in CI, and how long would they take?

## Stretch goals

- Add a `visibility_timeout_seconds` validation (0 to 43200) and a run block that proves it.
- Add a `kms_key_arn` variable that switches from SSE-SQS to SSE-KMS, with tests for both paths.
- Add a CloudWatch alarm on the dead-letter queue's `ApproximateNumberOfMessagesVisible` and test its threshold.
- Write a test with `command = apply` and `override_resource` that checks the outputs of the example.

## If you have a sandbox

Optional, in a sandbox account only (see [Use a sandbox account](../docs/how-to/use-a-sandbox-account.md)). The
two queues cost nothing at lab volumes.

```bash
cd labs/02-terraform-module-testing/solution/examples/basic
terraform init && terraform apply
QUEUE_URL="$(terraform output -raw queue_url)"
aws sqs send-message --queue-url "$QUEUE_URL" --message-body '{"order":"HG-1001"}'
```

Receive the message three times without deleting it, with `--visibility-timeout 0`, and show it move to the
dead-letter queue after the maximum receive count (3 in the example).

Cleanup:

```bash
cd labs/02-terraform-module-testing/solution/examples/basic && terraform destroy
```
