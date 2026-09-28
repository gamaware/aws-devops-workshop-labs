# Lab 04: GitHub Actions to AWS with OIDC, checked offline

Move your deploy workflow from stored AWS keys to short-lived OpenID Connect (OIDC) credentials, narrow the IAM role's
permissions, and verify its trust policy with a dry run before a real token exists.

## Objectives

After completing the lab, you can:

- describe how `AssumeRoleWithWebIdentity` exchanges GitHub's OIDC token for AWS credentials;
- limit the workflow's `GITHUB_TOKEN` permissions and assign `id-token: write` to just one job;
- build a trust policy that accepts only one repository, one environment and one audience;
- limit a deploy policy's access to one bucket;
- check workflows with actionlint and zizmor and lock actions to commit SHAs.

## Prerequisites

- Bring basic YAML knowledge and familiarity with GitHub Actions jobs, steps and `uses:`.
- Have `uv` and `make` available, then run `make setup`. Follow
  [set up your machine](../../docs/how-to/set-up-your-machine.md).
- You need neither an AWS account nor a GitHub repository. Start with
  [OIDC federation](../../docs/explanation/oidc-federation.md) if the terminology is unfamiliar.

## Duration

Allow 80 minutes.

## Scenario

Harbor Goods publishes the storefront's static assets to S3, such as the maintenance page shown while the store is
being updated. The deployment workflow stores an IAM user's access key in repository secrets, executes on every push
and pull request, and grants `s3:*` across all buckets. Anyone able to open a pull request can edit the workflow and
read that key. A teammate's proposed OIDC trust policy accepts `repo:harbor-goods/*`.

| Path | Purpose |
| --- | --- |
| `starter/workflows/deploy.yml` | The workflow you fix (kept outside `.github/workflows`, so GitHub never runs it) |
| `starter/iam/trust-policy.json` | Who may assume the deploy role |
| `starter/iam/deploy-policy.json` | What the deploy role may do |
| [`fixtures/oidc-claims/`](../../fixtures/oidc-claims/) | Sample token claims: which runs should get in, and which should not |

![Deploy job trades a GitHub OIDC token for short-lived STS credentials to sync an S3 bucket](../../docs/diagrams/03-oidc-flow.svg)

## Steps

Use `starter/` for your changes. In `deploy.yml`, numbered `Exercise` comments correspond to steps 2 to 5.

1. Start by running both the grader and the trust-policy dry run:

   ```bash
   make setup
   make check LAB=04
   uv run python labs/04-github-actions-oidc/tests/oidc_dry_run.py labs/04-github-actions-oidc/starter/iam/trust-policy.json
   ```

   For each claims file, the dry run checks what the trust policy allows. The starter policy would let a pull request, a
   feature branch and even a different repository assume the role.

2. **Remove default permissions** (exercise 1). Set `permissions: {}` at the workflow's top level so each job must
   request the permissions it needs.

3. **Separate validation and deployment** (exercise 2). Configure `validate` to run for every event with
   `contents: read`. Configure `deploy` to:
   - execute only if `github.event_name == 'push' && github.ref == 'refs/heads/main'`;
   - depend on validation through `needs: validate`;
   - declare `environment: production` to add required reviewers and include the environment in the token's subject;
   - specify `timeout-minutes`, and set a timeout for `validate` as well.

4. **Adopt OIDC** (exercise 3). Assign `permissions: { contents: read, id-token: write }` exclusively to the deploy job.
   In `aws-actions/configure-aws-credentials`, remove both key inputs in favor of
   `role-to-assume: arn:aws:iam::111122223333:role/harbor-storefront-deploy`, retaining `aws-region`.

5. **Pin actions and adjust inputs** (exercise 4). Use a full commit SHA for each action and record its version in a
   comment, such as `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` and
   `aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd # v6.3.0`. Configure every checkout
   with `persist-credentials: false`. Supply the bucket name through `env:` for use in `run:`.

6. **Narrow role trust** (`iam/trust-policy.json`). Change the comparison from `StringLike` to `StringEquals` for both
   keys: require `token.actions.githubusercontent.com:aud` to equal `sts.amazonaws.com` and
   `token.actions.githubusercontent.com:sub` to equal `repo:harbor-goods/storefront:environment:production`. Repeat the
   dry run; all cases should now produce their expected results.

7. **Limit deployment access** (`iam/deploy-policy.json`). Grant `s3:ListBucket` for
   `arn:aws:s3:::harbor-goods-storefront-static`, with `s3:PutObject` and `s3:DeleteObject` restricted to its objects
   (`/*`). These permissions cover everything `aws s3 sync --delete` requires.

8. Repeat grading until `PASS` appears on every line:

   ```bash
   make check LAB=04
   ```

### Optional: run it for real

For the optional step, use a sandbox account and your own GitHub repository. Set up the IAM OIDC identity provider for
`token.actions.githubusercontent.com`, then create the role using both policy files, substituting your repository in the
subject. Add a `production` environment and place a copy of `deploy.yml` in `.github/workflows/`. Find the commands and
cleanup instructions in [Use a sandbox account](../../docs/how-to/use-a-sandbox-account.md).

## Expected result

```text
ok     workflow is valid GitHub Actions syntax (actionlint)
PASS   workflow passes zizmor's security audit (offline)
PASS   workflow uses OIDC, SHA pins, least privilege; trust and deploy policies are tight
RESULT all objectives met
```

You should see the dry-run report `6 of 6 cases behave as expected`. Review your work against [`solution/`](solution/)
and find the checks in [`tests/test_grader.py`](tests/test_grader.py).

## Reset

Unless you completed the optional step, nothing runs in AWS or GitHub. If you completed it, remove the role, identity
provider and static assets bucket before restoring the starter files:

```bash
make reset LAB=04
```

## Going further

- Create a claims file representing a reusable-workflow run, then determine whether the trust policy should check
  `job_workflow_ref` rather than `sub`.
- What can an attacker obtain through a pull request targeting the starter workflow? What can they obtain through one
  targeting the solution?
