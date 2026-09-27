# Lab 05 instructor notes: containers to ECS

Lab directory: [labs/05-containers-to-ecs](../labs/05-containers-to-ecs/). Background reading for you:
[docs/explanation](../docs/explanation/).

## Timing

Suggested duration: 95 minutes.

| Part | Minutes |
| --- | --- |
| Brief | 5 |
| Opening demo | 5 |
| Work time | 70 |
| Debrief | 15 |

In a 1:1 session, plan the six Dockerfile exercises for the session and the task definition as practice.

## Learning goals

By the end, participants can:

- Build a small, reproducible image: base pinned by digest, only the files the app needs, no package manager.
- Run the image as a numeric non-root user with a read-only root filesystem and no Linux capabilities.
- Write a `HEALTHCHECK` that works in a slim image and an exec-form `CMD` that receives `SIGTERM`.
- Turn an EC2-era task definition into a Fargate one: `awsvpc`, a valid CPU and memory size, an execution role,
  an ECR image by digest, `awslogs`, a container health check, and secrets from Secrets Manager or Parameter Store.

## Opening demo (5 minutes)

1. Confirm Docker is running on your machine, then run `make check LAB=05` on the starter. Point at the three
   failing checks: hadolint, the file checklist, and the smoke test.
2. Read the smoke test output: `image user: <none, so root>` and `the image runs as root`. Explain that
   `tests/smoke.sh` builds the image and runs it the way ECS will: `--read-only`, `--cap-drop ALL`,
   `--security-opt no-new-privileges`.
3. Open `starter/ecs/task-definition.json` and point at `"privileged": true`, `"hostPort": 80` and
   `CATALOG_DB_PASSWORD` in plain `environment`. Ask the group which of these they have seen in production.

## Exercise map

The Dockerfile comments number exercises 1 to 6. The task definition has no `Exercise` comments; treat it as
exercise 7 and use the grader tests as its checklist. The file checks all report under
`image and task definition follow the Fargate hardening checklist`; the run-time checks report under
`image has no pip, runs read-only as non-root without capabilities, turns healthy, serves /products`.

| Exercise | File | Grader check | Grader test or smoke step |
| --- | --- | --- | --- |
| 1: pin the base by digest | `Dockerfile` | checklist | `test_base_image_is_pinned_by_digest` |
| 2: copy only two files | `Dockerfile`, `.dockerignore` | checklist | `test_image_copies_only_what_the_app_needs` (`.dockerignore` is not graded) |
| 3: numeric non-root user | `Dockerfile` | checklist and smoke | `test_image_runs_as_a_numeric_non_root_user`; smoke `image user` |
| 4: `HEALTHCHECK` on `/health` | `Dockerfile` | checklist and smoke | `test_image_has_a_healthcheck`; smoke `health status` |
| 5: exec-form `CMD` | `Dockerfile` | `Dockerfile passes hadolint` and checklist | hadolint `DL3025`; `test_cmd_uses_the_exec_form` |
| 6: remove pip, set `PYTHONDONTWRITEBYTECODE=1` | `Dockerfile` | smoke and checklist | smoke `import pip`; `test_python_does_not_write_bytecode` |
| 7: Fargate task definition | `ecs/task-definition.json` | checklist | `test_task_targets_fargate_with_a_valid_size`, `test_task_has_an_execution_role`, `test_image_comes_from_ecr_by_digest`, `test_container_is_locked_down`, `test_container_user_and_port_match_the_image`, `test_logs_go_to_cloudwatch`, `test_container_has_a_health_check`, `test_secrets_come_from_secrets_manager_not_plain_environment` |

## Common mistakes

**A health check that calls curl.** `python:3.14-slim` has no curl, so `HEALTHCHECK CMD curl -f
http://127.0.0.1:8080/health` fails inside the container. The file check passes (it only looks for `/health`),
and the smoke test fails with `health status: unhealthy` followed by the container logs. Use Python's
`urllib.request`, as the Exercise 4 comment says.

**A health check with the default interval.** Docker runs the first probe after the interval, 30 seconds by
default, and the smoke test polls for about 30 seconds. The status can still read `health status: starting` when
the test gives up. Set `--interval` and `--start-period`, and `--start-interval` for fast checks while the
container starts.

**pip removed after `USER`.** A `RUN python -m pip uninstall --yes pip` placed after `USER 10001:10001` runs as
the unprivileged user and cannot write to `site-packages`, so `docker build` fails inside the smoke test. Remove
pip before you switch users. If pip is still there, the smoke test prints
`pip is still in the image: the app does not need a package manager at run time`.

**Bytecode on a read-only filesystem.** The container starts without `PYTHONDONTWRITEBYTECODE=1`: Python skips
the `.pyc` write when the filesystem refuses it. Learners who test with `docker run --read-only`, see it work,
and skip the setting then get `a read-only root filesystem has no room for .pyc files`. Use it to discuss why
the image should state its run-time contract instead of relying on silent fallbacks.

**A user name instead of a number.** `USER app` fails `set USER to a numeric UID other than 0`. A numeric UID
lets ECS and Kubernetes verify "not root" without reading `/etc/passwd`. The UID does not need an entry in
`/etc/passwd` for this app.

**Image and task disagree.** `test_container_user_and_port_match_the_image` compares strings: `"10001"` in the
task and `10001:10001` in the Dockerfile fail with `task and image must agree on the user`. With `awsvpc`, drop
`hostPort` or set it to the container port; `"hostPort": 80` fails with
`with awsvpc the host port equals the container port`.

**CPU and memory in the container only.** Fargate needs task-level `cpu` and `memory` from the valid pairs, for
example `"cpu": "256"` with `"memory": "512"`. The starter has only a container-level `memory`.

**Secrets renamed, not moved.** The grader flags plain `environment` names that contain `PASSWORD`, `SECRET`,
`TOKEN`, `API_KEY` or `PRIVATE`. Renaming `CATALOG_DB_PASSWORD` to `DB_PASS` passes that check and still leaves
the value in plain text, so check this one by eye. Move the value to `secrets` with a `valueFrom` ARN from Secrets
Manager or Parameter Store.

**Shell-form `CMD`.** `CMD python app/server.py` runs under `/bin/sh -c`, so `SIGTERM` from ECS reaches the shell,
not Python. hadolint reports `DL3025`; the checklist reports `use CMD ["python", ...] so python is PID 1`.

## Debrief questions

1. Which hardening steps does the image enforce, and which only the task definition can enforce?
2. What changes for an attacker who gets code execution in this container, compared with the starter?
3. Why reference the image by digest in the task definition when the tag is easier to read?
4. The execution role and the task role are different roles. Which one reads the database secret, and which one
   would the app use to call S3?
5. How would the lab 04 pipeline build this image, push it, and register the task definition with the new digest?

## Stretch goals

- Add a multi-stage build that runs the app's syntax check in the first stage and copies only the result.
- Add `trivy image` to your local loop and compare the findings for the starter and the final image.
- Add a task role with read access to one S3 prefix and reference it with `taskRoleArn`.
- Convert the task definition to Terraform with `aws_ecs_task_definition` and reuse lab 02's testing approach.

## If you have a sandbox

Optional, in a sandbox account only (see [Use a sandbox account](../docs/how-to/use-a-sandbox-account.md)).
Fargate has no free tier: a 0.25 vCPU task costs cents per hour, so stop it in the same session. Store the secret
as a Parameter Store `SecureString` (standard tier, no charge); `valueFrom` then takes an
`arn:aws:ssm:...:parameter/...` ARN, which the grader accepts.

The solution sets `runtimePlatform` to `ARM64`. Build for that platform, or change it to `X86_64`:

```bash
cd labs/05-containers-to-ecs/solution
aws ecr create-repository --repository-name harbor-catalog
aws ecr get-login-password | docker login --username AWS --password-stdin \
  "111122223333.dkr.ecr.us-east-1.amazonaws.com"
docker buildx build --platform linux/arm64 --push \
  --tag "111122223333.dkr.ecr.us-east-1.amazonaws.com/harbor-catalog:lab" .
```

Replace `111122223333` with the sandbox account ID. Then:

1. Copy the pushed image digest into `image` (`...harbor-catalog@sha256:...`).
2. Create the log group `/ecs/harbor-catalog`, the `SecureString` parameter, and an execution role with the
   `AmazonECSTaskExecutionRolePolicy` managed policy plus `ssm:GetParameters` on that parameter.
3. Register the task definition, create a cluster, and run one task in a public subnet of the default VPC with a
   public IP and a security group that allows port 8080 from your IP only.
4. Call `/products` on the task's public IP and show the request log lines in CloudWatch Logs.

Cleanup:

```bash
aws ecs stop-task --cluster harbor-lab --task TASK_ARN
aws ecs deregister-task-definition --task-definition harbor-catalog:1
aws ecs delete-cluster --cluster harbor-lab
aws ecr delete-repository --repository-name harbor-catalog --force
aws logs delete-log-group --log-group-name /ecs/harbor-catalog
aws ssm delete-parameter --name /harbor/catalog/db-password
```

Delete the execution role and the security group last, after the task has stopped.
