# Lab 05: From a Dockerfile to an ECS task definition

Prepare a container image for Fargate: harden it, test it locally with Fargate's restrictions, and revise an Amazon ECS
task definition until it is ready to use on Fargate.

## Objectives

After completing the lab, you can:

- create a Dockerfile that pins its base by digest, uses a non-root user, includes a health check and sets an exec-form
  `CMD`;
- probe a container running with a read-only filesystem and no Linux capabilities;
- describe how each security and operations field in a Fargate task definition works;
- replace a secret in plain environment variables with AWS Secrets Manager references;
- check a Dockerfile using hadolint.

## Prerequisites

- Have Docker running locally, plus `uv`, `hadolint` and `make`; follow
  [set up your machine](../../docs/how-to/set-up-your-machine.md).
- Know Docker basics: `build`, `run` and ports.
- You do not need an AWS account. Read [Containers on Fargate](../../docs/explanation/containers-on-fargate.md) for the
  reasoning behind the lab's choices.

## Duration

Allow 90 minutes.

## Scenario

The small Harbor Goods catalog API runs on Python's standard library alone. Its developer supplied a Dockerfile that
runs on a laptop and copied an EC2 example for the ECS task definition. The platform team plans to run the service
behind a load balancer on Fargate using a read-only root filesystem. The team will reject a plain-text database
password.

| Path | Purpose |
| --- | --- |
| `starter/app/` | The API (`server.py`) and its data; you do not need to change it |
| `starter/Dockerfile`, `starter/.dockerignore` | The image you harden |
| `starter/ecs/task-definition.json` | The task definition you review and fix |

## Steps

Use `starter/` as your working directory. Follow the Dockerfile's numbered `Exercise` comments for steps 2 and 3.

1. Build and run the unchanged starter, then check its grade:

   ```bash
   cd labs/05-containers-to-ecs/starter
   docker build -t harbor-catalog:dev .
   docker run --rm -p 8080:8080 harbor-catalog:dev      # in another terminal: curl localhost:8080/products
   cd ../../.. && make check LAB=05
   ```

2. **Harden your Dockerfile** (exercises 1 to 6):
   - look up the base digest with `docker buildx imagetools inspect python:3.14-slim` and pin the base to it;
   - restrict both copying and the `.dockerignore` allowlist to `app/server.py` and `app/products.json`;
   - use `ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1`, since a read-only filesystem cannot accommodate `.pyc`
     files;
   - uninstall pip before `USER` by adding `RUN python -m pip uninstall --yes --root-user-action=ignore pip`;
   - specify `USER 10001:10001` so ECS can verify the numeric user is not root;
   - add a Python-based `HEALTHCHECK` for `http://127.0.0.1:8080/health`, since the image lacks `curl`;
   - use the exec-form `CMD ["python", "server.py"]` to run Python as PID 1 so it receives ECS's `SIGTERM`.

3. **Match the ECS runtime restrictions.** Build again, then start the container read-only with no capabilities:

   ```bash
   docker run --rm --read-only --cap-drop ALL --security-opt no-new-privileges -p 8080:8080 harbor-catalog:dev
   docker ps          # STATUS turns (healthy) after a few seconds
   ```

4. **Revise the task definition** (`ecs/task-definition.json`). Address every row:

   | Field | Change to |
   | --- | --- |
   | `requiresCompatibilities`, `networkMode` | `["FARGATE"]`, `"awsvpc"` |
   | `cpu`, `memory` (task level) | a valid Fargate size, for example `"256"` and `"512"` |
   | `executionRoleArn` | `arn:aws:iam::111122223333:role/harbor-catalog-execution` (pulls the image, writes logs, reads secrets) |
   | `image` | the ECR image by digest: `111122223333.dkr.ecr.us-east-1.amazonaws.com/harbor-catalog@sha256:...` |
   | `user`, `readonlyRootFilesystem`, `privileged` | `"10001:10001"` (same as the image), `true`, `false` |
   | `linuxParameters.capabilities.drop` | `["ALL"]` |
   | `portMappings` | `containerPort` 8080 and no different `hostPort` (awsvpc maps them one to one) |
   | `CATALOG_DB_PASSWORD` | out of `environment`, into `secrets` with `valueFrom` a Secrets Manager ARN |
   | `logConfiguration` | `awslogs` with `awslogs-group`, `awslogs-region` and `awslogs-stream-prefix` |
   | `healthCheck` | the same Python command as the Dockerfile, as `["CMD", "python", "-c", "..."]` |

   You can remove the starter's container-level `memory`: the task-level size accommodates the single container.

5. Repeat grading until `PASS` appears on every line:

   ```bash
   make check LAB=05
   ```

## Expected result

```text
PASS   Dockerfile passes hadolint
PASS   image and task definition follow the Fargate hardening checklist
PASS   image has no pip, runs read-only as non-root without capabilities, turns healthy, serves /products
RESULT all objectives met
```

For the final check, the grader builds your image, starts it with `--read-only --cap-drop ALL`, waits for the health
check, then requests `/products`. Use [`solution/`](solution/) for comparison and
[`tests/test_grader.py`](tests/test_grader.py) for the checklist.

## Reset

Delete the local images and return the starter files to their original state:

```bash
docker image rm harbor-catalog:dev
make reset LAB=05
```

## Going further

- ARM64 is the solution's target in `runtimePlatform`. Use `docker buildx build --platform linux/arm64` to build for
  that target, then discuss the effects on cost and the build pipeline.
- You need an ECR repository, a VPC and a cluster to register and run the task definition. Build all three with
  Terraform in the [ECS Fargate lab](https://github.com/gamaware/aws-ecs-fargate-deploy-lab).
