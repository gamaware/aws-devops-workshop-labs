"""Offline dry run of a GitHub OIDC trust policy.

Evaluates an IAM role trust policy against sample GitHub Actions token claims
(fixtures/oidc-claims/*.json) and reports which workflow runs could assume the role.
It covers the subset of IAM policy logic that trust policies for GitHub OIDC use:
Allow and Deny statements, Action with wildcards, and the StringEquals,
StringLike, StringNotEquals and StringNotLike condition operators.

It never calls AWS. It is a teaching aid, not a replacement for IAM Access Analyzer
or a real AssumeRoleWithWebIdentity call.

Usage:
    uv run python labs/04-github-actions-oidc/tests/oidc_dry_run.py <trust-policy.json> [claims-dir]
"""

import argparse
import json
import re
import sys
from pathlib import Path

PROVIDER = "token.actions.githubusercontent.com"
ACTION = "sts:AssumeRoleWithWebIdentity"
DEFAULT_CLAIMS = Path(__file__).resolve().parents[3] / "fixtures" / "oidc-claims"


def as_list(value: object) -> list:
    return value if isinstance(value, list) else [value]


def like(pattern: str, value: str) -> bool:
    """IAM StringLike: * matches any sequence and ? one character, case-sensitive.

    Every other character is literal. Shell globs (fnmatch) also treat [...] as a character class,
    which IAM does not, so the pattern is translated to a regular expression by hand.
    """
    wildcards = {"*": ".*", "?": "."}
    regex = "".join(wildcards.get(char, re.escape(char)) for char in pattern)
    return re.fullmatch(regex, value, flags=re.DOTALL) is not None


OPERATORS = {
    "StringEquals": lambda expected, actual: actual in expected,
    "StringLike": lambda expected, actual: any(like(pattern, actual) for pattern in expected),
    "StringNotEquals": lambda expected, actual: actual not in expected,
    "StringNotLike": lambda expected, actual: not any(like(pattern, actual) for pattern in expected),
}


def condition_matches(condition: dict, claims: dict) -> bool:
    """Every operator and every key must match (IAM ANDs them). A missing claim fails all but StringNot*."""
    for operator, keys in condition.items():
        if operator not in OPERATORS:
            raise ValueError(f"unsupported condition operator: {operator}")
        for key, expected in keys.items():
            if not key.startswith(f"{PROVIDER}:"):
                raise ValueError(f"unsupported condition key: {key}")
            claim = key.split(":", 1)[1]
            if claim not in claims:
                # IAM evaluates a negated operator as true when the key is absent from the request.
                if operator.startswith("StringNot"):
                    continue
                return False
            if not OPERATORS[operator](as_list(expected), claims[claim]):
                return False
    return True


def statement_applies(statement: dict, claims: dict) -> bool:
    unsupported = {"NotAction", "NotPrincipal", "NotResource"} & set(statement)
    if unsupported:
        raise ValueError(f"unsupported statement element: {sorted(unsupported)}")
    federated = as_list(statement.get("Principal", {}).get("Federated", []))
    trusts_github = any(principal.endswith(f":oidc-provider/{PROVIDER}") for principal in federated)
    # IAM action names are case-insensitive and accept * and ? wildcards.
    allows_action = any(like(action.lower(), ACTION.lower()) for action in as_list(statement.get("Action", [])))
    return trusts_github and allows_action and condition_matches(statement.get("Condition", {}), claims)


def evaluate(policy: dict, claims: dict) -> str:
    """Return "allow" or "deny": an explicit Deny wins, then any Allow, else the implicit deny."""
    statements = as_list(policy.get("Statement", []))
    if any(s.get("Effect") == "Deny" and statement_applies(s, claims) for s in statements):
        return "deny"
    if any(s.get("Effect") == "Allow" and statement_applies(s, claims) for s in statements):
        return "allow"
    return "deny"


def run(policy_path: Path, claims_dir: Path) -> list[tuple[str, str, str]]:
    """Evaluate every claims file; return (case, expected, actual) rows."""
    policy = json.loads(policy_path.read_text())
    rows = []
    for claims_file in sorted(claims_dir.glob("*.json")):
        claims = json.loads(claims_file.read_text())
        rows.append((claims_file.stem, claims["_expected"], evaluate(policy, claims)))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("policy", type=Path, help="trust policy JSON file")
    parser.add_argument("claims_dir", type=Path, nargs="?", default=DEFAULT_CLAIMS, help="directory of claims JSON")
    args = parser.parse_args()

    rows = run(args.policy, args.claims_dir)
    mismatches = 0
    print(f"{'case':<24} {'expected':<9} {'result':<7}")
    for case, expected, actual in rows:
        flag = "" if expected == actual else "  <-- mismatch"
        mismatches += expected != actual
        print(f"{case:<24} {expected:<9} {actual:<7}{flag}")
    print(f"{len(rows) - mismatches} of {len(rows)} cases behave as expected")
    return 1 if mismatches else 0


if __name__ == "__main__":
    sys.exit(main())
