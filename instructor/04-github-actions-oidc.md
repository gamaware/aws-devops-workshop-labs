# Lab 04 instructor notes: GitHub Actions to AWS with OIDC

Lab directory: [labs/04-github-actions-oidc](../labs/04-github-actions-oidc/). Background reading for you:
[docs/explanation](../docs/explanation/). Claim fixtures: [fixtures/oidc-claims](../fixtures/oidc-claims/).

## Timing

Suggested duration: 80 minutes.

| Part | Minutes |
| --- | --- |
| Brief | 5 |
| Opening demo | 5 |
| Work time | 55 |
| Debrief | 15 |

In a 1:1 session, plan the two IAM policies and the first workflow tasks for the session and the rest as practice.

## Learning goals

By the end, participants can:

- Replace stored AWS access keys with a role that GitHub Actions assumes through OIDC.
- Write a trust policy that admits one repository, one environment and the STS audience, and nothing else.
- Scope a deploy policy to one bucket and the three S3 actions a sync needs.
- Harden a workflow: `permissions: {}` by default, `id-token: write` on the deploy job only, SHA-pinned actions,
  `persist-credentials: false`, timeouts, and a deploy that runs only for pushes to `main`.
- Read zizmor findings and the offline OIDC dry run.

## Opening demo (5 minutes)

1. Show `starter/workflows/deploy.yml`: it deploys on every push and pull request with keys from repository
   secrets. Ask the group what a pull request from a fork could do with it.
2. Run the dry run on the starter trust policy:

   ```bash
   uv run python labs/04-github-actions-oidc/tests/oidc_dry_run.py \
     labs/04-github-actions-oidc/starter/iam/trust-policy.json
   ```

   Five of the six cases print `<-- mismatch`: the wildcard subject `repo:harbor-goods/*` admits another
   repository, a feature branch, a pull request, the staging environment and a token for the wrong audience.
3. Open `fixtures/oidc-claims/push-main-production.json` and show the `sub` claim
   `repo:harbor-goods/storefront:environment:production`. When a job names an environment, the environment
   replaces the branch in the subject.
4. Run `make check LAB=04` and point at the zizmor findings, then at the pytest failure summary.

## Exercise map

The starter workflow lists five `Exercise N` comments at the top of `workflows/deploy.yml`; Exercise 5 points to
the two IAM policies. The table splits each exercise into tasks and maps them to grader tests in
`tests/test_grader.py`, all reported under one check:
`workflow uses OIDC, SHA pins, least privilege; trust and deploy policies are tight`. The zizmor check,
`workflow passes zizmor's security audit (offline)`, covers exercises 1, 3 and 4 from another angle.

| Exercise | Task | File | Grader tests |
| --- | --- | --- | --- |
| 1 | `permissions: {}` at the top; `contents: read` and `id-token: write` on deploy | `workflows/deploy.yml` | `test_workflow_grants_no_permissions_by_default`, `test_only_the_deploy_job_can_request_an_oidc_token` |
| 2 | Split into `validate` and `deploy` jobs; deploy needs validate, runs for pushes to `main`, uses `production` | `workflows/deploy.yml` | `test_deploy_runs_only_for_pushes_to_main_in_production` |
| 2 | `timeout-minutes` on every job | `workflows/deploy.yml` | `test_every_job_has_a_timeout` |
| 3 | Replace the keys with `role-to-assume` | `workflows/deploy.yml` | `test_no_long_lived_aws_keys`, `test_the_deploy_role_is_assumed_with_oidc` |
| 4 | Pin every action to a 40-character commit SHA | `workflows/deploy.yml` | `test_every_action_is_pinned_to_a_commit_sha` |
| 4 | `persist-credentials: false` on every checkout | `workflows/deploy.yml` | `test_checkout_does_not_keep_the_github_token` |
| 5 | Trust only production deploys of `harbor-goods/storefront`, audience `sts.amazonaws.com` | `iam/trust-policy.json` | `test_trust_policy_admits_only_production_deploys_from_main`, `test_trust_policy_matches_the_subject_exactly` |
| 5 | Limit the deploy policy to the static assets bucket | `iam/deploy-policy.json` | `test_deploy_policy_is_limited_to_the_static_assets_bucket` |

Exercise 4 needs commit SHAs, which need network access to look up. If the network blocks GitHub, give participants
the pins from the solution workflow.

## Common mistakes

**A narrower wildcard that is still a wildcard.** `repo:harbor-goods/storefront:*` blocks the other repository
but still admits pull requests, feature branches and staging:

```text
E   AssertionError: trust policy dry run:
        feature-branch: expected deny, got allow
        pull-request: expected deny, got allow
        staging-environment: expected deny, got allow
```

`StringLike` with `*` matches any sequence. You know the exact subject, so the grader also requires
`StringEquals` and fails with `use StringEquals: the subject is known exactly`.

**No audience condition.** A policy that checks only `sub` admits a token minted for another audience:
`wrong-audience: expected deny, got allow`. Add `token.actions.githubusercontent.com:aud` equal to
`sts.amazonaws.com` in the same `StringEquals` block.

**Branch subject with an environment job.** `repo:harbor-goods/storefront:ref:refs/heads/main` looks right, but a
job with `environment: production` gets the environment subject, so IAM denies the real deploy:
`push-main-production: expected allow, got deny`.

**`s3:*` or a wildcard resource.** The grader allows only `s3:ListBucket`, `s3:PutObject` and `s3:DeleteObject`,
which the solution grants, plus an optional `s3:GetObject`, on `arn:aws:s3:::harbor-goods-storefront-static` and its
objects:
`unexpected actions: ['s3:*']`.

**Deploy guarded only by the trigger.** Removing `pull_request` from `on:` is not enough. The grader reads the
deploy job's `if:` and needs both `github.event_name == 'push'` and `refs/heads/main` in it. Expressions use
single quotes; a double-quoted string fails actionlint, which is a precondition, so the grader reports `BROKEN`.

**Checking the trigger with PyYAML.** Participants who inspect the workflow in Python find that
`yaml.safe_load` turns the `on:` key into the boolean `True` (YAML 1.1), so `workflow["on"]` raises `KeyError`.
That is why the grader checks the job condition instead of the trigger block. Mention it when someone writes
their own check.

**A placeholder account in the role ARN.** `role-to-assume` must match `arn:aws:iam::<12 digits>:role/<name>`.
`YOUR_ACCOUNT_ID` fails; use the documentation account `111122223333`.

**Renamed jobs or extra permissions.** The tests look up the jobs `validate` and `deploy` by name, and the deploy
job's permissions must be exactly `contents: read` and `id-token: write`.

**Output cut off.** The grader shows the last 40 lines per check, so zizmor's first findings scroll away. Run
`uv run zizmor --offline labs/04-github-actions-oidc/starter/workflows/deploy.yml` for the full list.

## Debrief questions

1. Which claim in the token decides which workflow runs can assume the role, and who controls that claim?
2. Why does the `validate` job run for pull requests while the `deploy` job never gets an OIDC token for them?
3. What does the `production` environment add beyond the subject claim (reviewers, wait timers, branch rules)?
4. A tag moves; a commit SHA does not. How do you keep SHA pins up to date without editing them by hand?
5. The dry run is offline. What would you use to check a trust policy against a real account?

## Stretch goals

- Add a `staging` environment and a second role whose trust policy admits only
  `repo:harbor-goods/storefront:environment:staging`, and add a claims fixture that proves it.
- Add a `StringNotEquals` deny statement for `job_workflow_ref` so only one reusable workflow can deploy.
- Add a Dependabot configuration for GitHub Actions that updates the SHA pins.

## If you have a sandbox

Optional, in a sandbox account and a personal GitHub repository only (see
[Use a sandbox account](../docs/how-to/use-a-sandbox-account.md)). Never use the client's organization.

1. In IAM, add an OpenID Connect identity provider for `https://token.actions.githubusercontent.com` with the
   audience `sts.amazonaws.com`, unless the account already has one.
2. Create an S3 bucket for the site. Copy the solution's `deploy-policy.json` and replace the bucket name.
3. Copy the solution's `trust-policy.json`, set the account ID in the provider ARN, and set the subject to
   `repo:YOUR_GITHUB_USER/YOUR_REPO:environment:production`. Create the role with it and attach the deploy
   policy as an inline policy.
4. In the GitHub repository, create an environment named `production`. Copy the solution workflow to
   `.github/workflows/deploy.yml`, the `static/` directory to the repository root, and set `role-to-assume` and the
   bucket name.
5. Push to `main`, watch the run, and open the role's CloudTrail `AssumeRoleWithWebIdentity` event. Then open a
   pull request and show that GitHub skips the deploy job.

Cleanup:

```bash
aws s3 rm "s3://YOUR_STATIC_BUCKET" --recursive && aws s3 rb "s3://YOUR_STATIC_BUCKET"
aws iam delete-role-policy --role-name harbor-storefront-deploy --policy-name deploy
aws iam delete-role --role-name harbor-storefront-deploy
```

Delete the OIDC provider only if you created it for this lab, and delete the workflow file from the repository.
