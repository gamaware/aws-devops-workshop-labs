# Containers on Fargate

Lab 05 packages the Harbor Goods catalog API as a container image and describes it in an ECS task definition for
Fargate. This page explains each hardening choice in the image and where the task definition repeats or enforces
it.

## Image hardening

### Base image pinned by digest

```dockerfile
FROM python:3.14-slim@sha256:51dafde8...
```

A tag such as `3.14-slim` moves when the maintainers publish a rebuild. A digest names exact bytes, so every
build starts from the same image and a changed base shows up as a reviewed diff. Dependabot proposes new
digests weekly.

### No pip at run time

The app uses only the Python standard library. The Dockerfile uninstalls pip, which removes the package manager
and the libraries it vendors: fewer packages for a scanner to report and fewer tools for an attacker who gets a
shell.

### Numeric non-root user

```dockerfile
USER 10001:10001
```

A process that escapes a container as root has far more options than one running as an unprivileged user. A
numeric UID and GID let ECS and Kubernetes verify the user is not root without reading `/etc/passwd`
inside the image.

### Exec-form CMD and SIGTERM

```dockerfile
CMD ["python", "server.py"]
```

The exec form makes `python` process 1, with no shell in between. When ECS stops a task, it sends `SIGTERM`,
waits `stopTimeout` seconds and then sends `SIGKILL`. The server installs a `SIGTERM` handler and exits cleanly.
With the shell form, `/bin/sh` would receive the signal and ECS would kill the app at the timeout.

### Read-only root file system

The task runs with a read-only root file system, so an attacker cannot drop tools or change code in the container.
Python writes `.pyc` files next to modules by default, which fails on a read-only file system;
`PYTHONDONTWRITEBYTECODE=1` turns that off. `PYTHONUNBUFFERED=1` sends each log line to stdout as it happens.

### HEALTHCHECK without curl

The health check calls `/health` with Python's `urllib`, which is already in the image. Adding `curl` only for the
health check would add a package, and its vulnerabilities, to every image.

## How the task definition maps to the image

| Task definition field | Value | Why |
| --- | --- | --- |
| `requiresCompatibilities` | `FARGATE` | AWS runs the host; no EC2 instances to patch |
| `networkMode` | `awsvpc` | Required on Fargate: each task gets its own network interface and security group |
| `cpu`, `memory` | `256`, `512` | A valid Fargate size pair: 0.25 vCPU and 512 MiB |
| `runtimePlatform` | `LINUX`, `ARM64` | Graviton-based Fargate costs less per vCPU-hour; build the image for `arm64` |
| `executionRoleArn` | `harbor-catalog-execution` | Used by the ECS agent to pull the image from ECR, fetch secrets and write logs |
| `taskRoleArn` | not set | The role the app itself would use for AWS API calls; the catalog makes none |
| `image` | ECR repository `@sha256:...` | Deploys the exact image the pipeline scanned, not whatever a tag points to later |
| `user` | `10001:10001` | Repeats the image user, so a rebuilt image cannot fall back to root |
| `readonlyRootFilesystem` | `true` | Enforces the read-only root file system the image expects |
| `privileged` | `false` | No access to host devices |
| `linuxParameters.capabilities.drop` | `ALL` | The app binds port 8080 and needs no Linux capabilities |
| `linuxParameters.initProcessEnabled` | `true` | A small init process reaps zombie processes and forwards signals |
| `secrets` | `valueFrom` a Secrets Manager ARN | The execution role reads the value at start-up; it never appears in the task definition or in `environment` |
| `logConfiguration` | `awslogs` | Stdout lines go to the CloudWatch Logs group `/ecs/harbor-catalog` |
| `healthCheck` | same command as `HEALTHCHECK` | ECS replaces tasks that stop answering `/health` |
| `stopTimeout` | `20` | Seconds between `SIGTERM` and `SIGKILL` |

### Execution role and task role

The two roles serve different principals. The execution role belongs to the ECS agent and covers what happens
before and around the app: pull the image, read the secrets listed in `secrets`, create log streams. The task role
belongs to the app's own code. Keep them apart: a bug in the app then cannot read other secrets, and the agent's
permissions cannot leak into application calls.

## What the lab does not deploy

The grader builds and runs the image locally with the same restrictions ECS applies: `--read-only`,
`--cap-drop ALL` and `--security-opt no-new-privileges`. A real deployment also needs an ECR repository, a VPC with
private subnets and endpoints or a NAT gateway, an ECS cluster and service, a load balancer and the IAM roles. See
[what the offline tests prove](what-offline-tests-prove.md) for the gap and
[lab 05](../../labs/05-containers-to-ecs/README.md) to build the image and task definition.
