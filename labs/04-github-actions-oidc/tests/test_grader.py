"""Grader for lab 04: a GitHub Actions deploy that reaches AWS through OIDC, not stored keys.

Run through tests/run.sh, which sets LAB_TARGET to the copied starter or solution.
"""

import json
import os
import re
from pathlib import Path

import pytest
import yaml

from oidc_dry_run import DEFAULT_CLAIMS, run

TARGET = Path(os.environ["LAB_TARGET"])
SHA_PIN = re.compile(r"^[\w.-]+/[\w.-]+(/[\w./-]+)?@[0-9a-f]{40}$")
BUCKET_ARN = "arn:aws:s3:::harbor-goods-storefront-static"
PRODUCTION_SUBJECT = "repo:harbor-goods/storefront:environment:production"
ALLOWED_ACTIONS = {"s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"}


@pytest.fixture(scope="module")
def workflow() -> dict:
    return yaml.safe_load((TARGET / "workflows" / "deploy.yml").read_text())


@pytest.fixture(scope="module")
def jobs(workflow: dict) -> dict:
    return workflow["jobs"]


def steps(jobs: dict) -> list[dict]:
    return [step for job in jobs.values() for step in job.get("steps", [])]


def as_list(value: object) -> list:
    return value if isinstance(value, list) else [value]


def test_no_long_lived_aws_keys(jobs: dict) -> None:
    text = (TARGET / "workflows" / "deploy.yml").read_text()
    assert "secrets.AWS_" not in text, "the workflow still reads AWS keys from repository secrets"
    for step in steps(jobs):
        inputs = step.get("with", {})
        assert "aws-access-key-id" not in inputs and "aws-secret-access-key" not in inputs


def test_every_action_is_pinned_to_a_commit_sha(jobs: dict) -> None:
    unpinned = [step["uses"] for step in steps(jobs) if "uses" in step and not SHA_PIN.match(step["uses"])]
    assert not unpinned, f"pin these to a full 40-character commit SHA: {unpinned}"


def test_workflow_grants_no_permissions_by_default(workflow: dict) -> None:
    assert workflow.get("permissions") == {}, "set `permissions: {}` at the top of the workflow"


def test_only_the_deploy_job_can_request_an_oidc_token(jobs: dict) -> None:
    with_token = {name for name, job in jobs.items() if job.get("permissions", {}).get("id-token") == "write"}
    assert with_token == {"deploy"}, f"id-token: write belongs to the deploy job only, found on: {sorted(with_token)}"
    assert jobs["deploy"]["permissions"] == {"contents": "read", "id-token": "write"}


def test_deploy_runs_only_for_pushes_to_main_in_production(jobs: dict) -> None:
    deploy = jobs["deploy"]
    condition = " ".join(deploy.get("if", "").replace("${{", "").replace("}}", "").split())
    accepted = {
        "github.event_name == 'push' && github.ref == 'refs/heads/main'",
        "github.ref == 'refs/heads/main' && github.event_name == 'push'",
    }
    assert condition in accepted, "deploy must run only for pushes to refs/heads/main"
    environment = deploy.get("environment")
    name = environment.get("name") if isinstance(environment, dict) else environment
    assert name == "production", "the deploy job must use the production environment"
    assert "validate" in as_list(deploy.get("needs", [])), "deploy must wait for the validate job"


def test_the_deploy_role_is_assumed_with_oidc(jobs: dict) -> None:
    action = "aws-actions/configure-aws-credentials@"
    credential_steps = [step for step in jobs["deploy"]["steps"] if step.get("uses", "").startswith(action)]
    assert len(credential_steps) == 1, "use aws-actions/configure-aws-credentials once, in the deploy job"
    inputs = credential_steps[0].get("with", {})
    assert re.fullmatch(r"arn:aws:iam::\d{12}:role/[\w+=,.@-]+", inputs.get("role-to-assume", ""))
    assert inputs.get("aws-region")


def test_checkout_does_not_keep_the_github_token(jobs: dict) -> None:
    for step in steps(jobs):
        if step.get("uses", "").startswith("actions/checkout@"):
            assert step.get("with", {}).get("persist-credentials") is False


def test_every_job_has_a_timeout(jobs: dict) -> None:
    missing = [name for name, job in jobs.items() if "timeout-minutes" not in job]
    assert not missing, f"add timeout-minutes to: {missing}"


def test_trust_policy_admits_only_production_deploys_from_main() -> None:
    rows = run(TARGET / "iam" / "trust-policy.json", DEFAULT_CLAIMS)
    wrong = [f"{case}: expected {expected}, got {actual}" for case, expected, actual in rows if expected != actual]
    assert not wrong, "trust policy dry run:\n  " + "\n  ".join(wrong)


def test_trust_policy_matches_the_subject_exactly() -> None:
    policy = json.loads((TARGET / "iam" / "trust-policy.json").read_text())
    for statement in as_list(policy["Statement"]):
        condition = statement.get("Condition", {})
        assert "StringLike" not in condition, "use StringEquals: the subject is known exactly"
        subjects = as_list(condition.get("StringEquals", {}).get("token.actions.githubusercontent.com:sub", []))
        assert subjects == [PRODUCTION_SUBJECT], f"every statement must admit only {PRODUCTION_SUBJECT}"


def test_deploy_policy_is_limited_to_the_static_assets_bucket() -> None:
    policy = json.loads((TARGET / "iam" / "deploy-policy.json").read_text())
    for statement in as_list(policy["Statement"]):
        assert statement["Effect"] == "Allow"
        actions = set(as_list(statement["Action"]))
        assert actions <= ALLOWED_ACTIONS, f"unexpected actions: {sorted(actions - ALLOWED_ACTIONS)}"
        for resource in as_list(statement["Resource"]):
            assert resource in (BUCKET_ARN, f"{BUCKET_ARN}/*"), f"resource outside the static assets bucket: {resource}"
