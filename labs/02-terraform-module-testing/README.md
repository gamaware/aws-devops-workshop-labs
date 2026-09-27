# Lab 02: A Terraform module and its terraform test suite

Build a reusable module from a bare SQS queue, add input validation and a dead-letter queue, and verify its behavior
with `terraform test`.

## Objectives

After completing this lab, you can:

- organize a reusable module into `main.tf`, `variables.tf`, `outputs.tf` and `versions.tf`, alongside a working
  example;
- enforce input requirements and a tagging standard through `validation` blocks;
- connect an SQS dead-letter queue using a redrive policy and a redrive allow policy;
- create `terraform test` run blocks that use `mock_provider`, `assert` and `expect_failures`;
- describe what mocked tests verify and what requires a real account.

## Prerequisites

- Complete Lab 01 or bring familiarity with Terraform variables, resources and outputs.
- Have Terraform 1.11 or later and `make` available; follow
  [set up your machine](../../docs/how-to/set-up-your-machine.md).
- You do not need an AWS account.

## Duration

Allow 60 to 90 minutes.

## Scenario

Harbor Goods sends order events through SQS. Teams copy the same queue code but end up with different versions. Some
omit a dead-letter queue, letting a malformed order block processing. Others lack an owner tag, leaving nobody able to
identify whom to call. The platform team wants a single module whose defaults provide the right behavior and whose tests
prevent anyone from breaking it.

| Path | Purpose |
| --- | --- |
| `starter/modules/queue/` | The module you finish |
| `starter/modules/queue/tests/` | The module's own tests, which you extend |
| `starter/examples/basic/` | A usage example that also serves as a test fixture |

## Steps

Make your changes in `starter/`, following the numbered `Exercise` comments that correspond to these steps.

1. Start by running the grader to inspect the contract:

   ```bash
   make check LAB=02
   ```

2. **Check the name** (`modules/queue/variables.tf`, exercise 1): require 1 to 76 lowercase letters, digits or hyphens,
   with a letter or digit first. This keeps `<name>-dlq` within the SQS limit of 80 characters.

3. **Require standard tags** (exercise 2). Give `tags` two `validation` blocks: require both `owner` and `environment`
   in the map, and restrict `environment` to `dev`, `staging` or `prod`. You can use `contains(keys(var.tags), "owner")`
   and `lookup(var.tags, "environment", "")` for these checks.

4. **Define `max_receive_count`** (exercise 3): use a number with a default of 5, allowing only whole numbers from 1 to
   10.

5. **Configure the dead-letter queue** (`modules/queue/main.tf`, exercises 4 to 7):
   - create `aws_sqs_queue.dlq` with the name `"${var.name}-dlq"` and retain messages for 14 days (`1209600` seconds);
   - set `redrive_policy` on `aws_sqs_queue.this` using
     `jsonencode({ deadLetterTargetArn = aws_sqs_queue.dlq.arn, maxReceiveCount = var.max_receive_count })`;
   - apply `sqs_managed_sse_enabled = true` and `tags = var.tags` to each queue;
   - configure `aws_sqs_queue_redrive_allow_policy.dlq` using `redrivePermission = "byQueue"` and the main queue's ARN
     to prevent any other queue from using this dead-letter queue.

6. **Publish outputs for both queues** (`modules/queue/outputs.tf`, exercise 8): introduce `dlq_url` and `dlq_arn`.

7. **Expand the module's tests** (`modules/queue/tests/queue.tftest.hcl`, exercise 9). Write at least two additional
   `run` blocks, including one that uses `expect_failures` to verify that a validation rejects invalid input:

   ```hcl
   run "rejects_a_receive_count_above_ten" {
     command = plan

     variables {
       max_receive_count = 11
     }

     expect_failures = [var.max_receive_count]
   }
   ```

   After `terraform init`, run these tests separately with
   `terraform -chdir=labs/02-terraform-module-testing/starter/modules/queue test`.

8. Repeat grading until `PASS` appears on every line:

   ```bash
   make check LAB=02
   ```

## Expected result

```text
PASS   module: the learner's own terraform test suite passes
PASS   module: the own suite has 3+ run blocks, including an expect_failures test
PASS   module: validations, dead-letter queue, encryption and outputs meet the contract
RESULT all objectives met
```

The grader executes your tests before running its [contract tests](tests/queue_grader.tftest.hcl). Check your module
against [`solution/modules/queue/`](solution/modules/queue/).

Terraform skips the remaining blocks in a file after a `run` block fails, so address failures in order from the top.

## Reset

You create no AWS resources in this lab unless you applied `examples/basic` to a sandbox. If you did, destroy those
resources first:

```bash
terraform -chdir=labs/02-terraform-module-testing/starter/examples/basic destroy
```

Next, return the starter files to their original state:

```bash
make reset LAB=02
```

## Going further

- Introduce a `precondition` that rejects a `visibility_timeout_seconds` value shorter than a consumer timeout you
  supply.
- Mocked tests cannot establish whether AWS accepts the redrive policy. Review
  [what offline tests prove](../../docs/explanation/what-offline-tests-prove.md), then choose the one real apply you
  would add.
