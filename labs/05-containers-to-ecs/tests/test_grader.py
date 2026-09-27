"""Grader for lab 05: a hardened image and an ECS task definition ready for Fargate.

Run through tests/run.sh, which sets LAB_TARGET to the copied starter or solution.
"""

import json
import os
import re
from pathlib import Path

import pytest

TARGET = Path(os.environ["LAB_TARGET"])
DIGEST = re.compile(r"@sha256:[0-9a-f]{64}$")
ECR_IMAGE = re.compile(r"^\d{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/[a-z0-9._/-]+@sha256:[0-9a-f]{64}$")
SECRET_WORDS = re.compile(r"PASS(WORD)?|PWD|SECRET|TOKEN|KEY|CREDENTIAL|PRIVATE", re.IGNORECASE)
# Valid Fargate CPU (units) to memory (MiB) combinations for the small task sizes.
FARGATE_SIZES = {
    "256": {"512", "1024", "2048"},
    "512": {"1024", "2048", "3072", "4096"},
    "1024": {str(gib * 1024) for gib in range(2, 9)},
}


def instructions() -> list[tuple[str, str]]:
    """Dockerfile instructions as (KEYWORD, arguments), with continuation lines joined."""
    text = (TARGET / "Dockerfile").read_text().replace("\\\n", " ")
    result = []
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            keyword, _, arguments = line.partition(" ")
            result.append((keyword.upper(), arguments.strip()))
    return result


def last(keyword: str) -> str | None:
    values = [arguments for name, arguments in instructions() if name == keyword]
    return values[-1] if values else None


@pytest.fixture(scope="module")
def task() -> dict:
    return json.loads((TARGET / "ecs" / "task-definition.json").read_text())


@pytest.fixture(scope="module")
def container(task: dict) -> dict:
    containers = task["containerDefinitions"]
    assert len(containers) == 1, "this lab runs a single container"
    return containers[0]


# Dockerfile


def test_base_image_is_pinned_by_digest() -> None:
    base = last("FROM")
    assert base and DIGEST.search(base.split()[0]), "pin the base image with @sha256:<digest>"


def test_image_copies_only_what_the_app_needs() -> None:
    copies = [arguments for name, arguments in instructions() if name == "COPY"]
    assert copies and all(not re.match(r"^\.\s", arguments) for arguments in copies), "do not COPY . (everything)"


def test_image_runs_as_a_numeric_non_root_user() -> None:
    user = last("USER")
    assert user and re.fullmatch(r"[1-9]\d*(:[1-9]\d*)?", user), "set USER to a numeric UID other than 0"


def test_image_has_a_healthcheck() -> None:
    healthcheck = last("HEALTHCHECK")
    assert healthcheck and "/health" in healthcheck


def test_cmd_uses_the_exec_form() -> None:
    cmd = last("CMD")
    assert cmd and cmd.startswith("["), 'use CMD ["python", ...] so python is PID 1 and receives SIGTERM'


def test_python_does_not_write_bytecode() -> None:
    env = " ".join(arguments for name, arguments in instructions() if name == "ENV")
    assert "PYTHONDONTWRITEBYTECODE=1" in env, "a read-only root filesystem has no room for .pyc files"


# Task definition


def test_task_targets_fargate_with_a_valid_size(task: dict) -> None:
    assert task.get("requiresCompatibilities") == ["FARGATE"]
    assert task.get("networkMode") == "awsvpc", "Fargate requires the awsvpc network mode"
    cpu, memory = str(task.get("cpu")), str(task.get("memory"))
    assert memory in FARGATE_SIZES.get(cpu, set()), f"cpu {cpu} with memory {memory} is not a Fargate size"


def test_task_has_an_execution_role(task: dict) -> None:
    assert re.fullmatch(r"arn:aws:iam::\d{12}:role/[\w+=,.@-]+", task.get("executionRoleArn", "")), (
        "ECS needs an execution role to pull from ECR, write logs and read secrets"
    )


def test_image_comes_from_ecr_by_digest(container: dict) -> None:
    assert ECR_IMAGE.match(container["image"]), "reference the ECR image by digest, never by tag"


def test_container_is_locked_down(container: dict) -> None:
    assert container.get("user") and not container["user"].startswith("0"), "run as a non-root user"
    assert container.get("readonlyRootFilesystem") is True
    assert container.get("privileged", False) is False
    assert container.get("linuxParameters", {}).get("capabilities", {}).get("drop") == ["ALL"]


def test_container_user_and_port_match_the_image(container: dict) -> None:
    assert container.get("user") == last("USER"), "task and image must agree on the user"
    exposed = {int(port.split("/")[0]) for port in (last("EXPOSE") or "").split()}
    for mapping in container.get("portMappings", []):
        assert mapping["containerPort"] in exposed, "map the port the image exposes"
        assert mapping.get("hostPort", mapping["containerPort"]) == mapping["containerPort"], (
            "with awsvpc the host port equals the container port"
        )


def test_logs_go_to_cloudwatch(container: dict) -> None:
    logging = container.get("logConfiguration", {})
    assert logging.get("logDriver") == "awslogs"
    options = logging.get("options", {})
    assert {"awslogs-group", "awslogs-region", "awslogs-stream-prefix"} <= set(options)


def test_container_has_a_health_check(container: dict) -> None:
    command = container.get("healthCheck", {}).get("command", [])
    assert command[:1] in (["CMD"], ["CMD-SHELL"]) and any("/health" in part for part in command)


def test_secrets_come_from_secrets_manager_not_plain_environment(container: dict) -> None:
    leaked = [item["name"] for item in container.get("environment", []) if SECRET_WORDS.search(item["name"])]
    assert not leaked, f"move these to `secrets` with valueFrom: {leaked}"
    for secret in container.get("secrets", []):
        assert re.match(r"^arn:aws:(secretsmanager|ssm):", secret["valueFrom"])
