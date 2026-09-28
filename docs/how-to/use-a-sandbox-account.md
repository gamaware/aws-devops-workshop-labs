# Use a sandbox account

Every lab is complete offline: `make check` grades it with no AWS account. This guide covers the optional live
steps, which deploy your work to a personal sandbox account so you can see the real resources. Skip it if you
have no sandbox.

## Rules for the account

- Use a separate account that you own and that holds nothing else, for example a new free-tier account or an
  account in your own AWS Organization.
- Never use a company or client account, including Harbor Goods workload accounts. The labs create and delete
  buckets, queues and IAM roles.
- Destroy what you create at the end of each lab. The cleanup steps are below.

## Prepare the account

1. Create a budget with an email alert before you deploy anything, for example a monthly cost budget of USD 5
   under **Billing and Cost Management, Budgets**.
2. Sign in without long-lived access keys. Pick one:
   - IAM Identity Center: create a user and a permission set, then run `aws configure sso` and name the profile,
     for example `sandbox`. Sign in again later with `aws sso login --profile sandbox`.
   - A role that you assume for short-lived credentials, configured as a profile with `role_arn` and
     `source_profile` in `~/.aws/config`.
3. Select the profile in each shell you use for the labs, and confirm the account:

```bash
export AWS_PROFILE=sandbox
aws sts get-caller-identity
```

Terraform, the CDK CLI and the AWS CLI all read `AWS_PROFILE`. Setting it per shell, not in your shell profile,
keeps a forgotten terminal from pointing at the wrong account.

## Which labs have a live step

| Lab | Live step | Cost |
| --- | --- | --- |
| 01 Terraform remote state | Apply `bootstrap`, then `app` with `backend.hcl` | Free tier: S3 requests, one standard SSM parameter |
| 02 Terraform module testing | Apply `examples/basic` | Free tier: two SQS queues |
| 03 CDK in Python | `npx aws-cdk@2 bootstrap`, then deploy; optional | Small: the bootstrap stack keeps an S3 bucket and an ECR repository |
| 04 GitHub Actions with OIDC | Your own GitHub repository, OIDC provider and role | Free tier: one S3 bucket |
| 05 Containers to ECS | None: `docker build` and `docker run` on your machine are the lab | None |

Work in the lab's `starter` directory, where your answers are. Run `make check` first: deploy only code that
passes its grader.

## Lab 01: remote state

Create the state bucket with local state:

```bash
cd labs/01-terraform-remote-state/starter/bootstrap
cp terraform.tfvars.example terraform.tfvars   # set a unique bucket_name
terraform init
terraform apply
terraform output backend_config
```

Point the app stack at the bucket and apply it:

```bash
cd ../app
cp backend.hcl.example backend.hcl             # set bucket from the output above
terraform init -backend-config=backend.hcl
terraform apply -var environment=dev
```

Both `terraform.tfvars` and `backend.hcl` are in `.gitignore`.

Clean up in reverse order. The bucket keeps every state version, so `terraform destroy` refuses to delete it
until `force_destroy` is `true` in the state. Apply that change first, then destroy:

```bash
terraform destroy -var environment=dev
cd ../bootstrap
terraform apply -var force_destroy=true
terraform destroy -var force_destroy=true
```

The bootstrap state lives in `bootstrap/terraform.tfstate` on your disk. Destroy before you run `make reset`: the
reset deletes that file, and without it Terraform no longer knows about the bucket.

## Lab 02: module testing

```bash
cd labs/02-terraform-module-testing/starter/examples/basic
terraform init
terraform apply
terraform destroy
```

The example creates `harbor-orders` and `harbor-orders-dlq` in `us-east-1`.

## Lab 03: CDK in Python

The CDK app runs `python3 app.py`, so activate the repository's environment first. Bootstrapping creates the
`CDKToolkit` stack once per account and Region; deploying is optional.

```bash
source .venv/bin/activate
cd labs/03-cdk-python-assertions/starter
npx aws-cdk@2 bootstrap
npx aws-cdk@2 deploy
```

Clean up:

```bash
npx aws-cdk@2 destroy
```

Both buckets use `RemovalPolicy.RETAIN`, so `cdk destroy` deletes the stack and leaves the buckets. Delete them
by hand: in the S3 console, select each bucket whose name starts with `harborassets-`, choose **Empty** (this
removes every object version of the versioned assets bucket), then **Delete**. If you no longer need CDK in the
account, delete the `CDKToolkit` stack and then empty and delete its `cdk-*-assets-*` bucket the same way.

## Lab 04: GitHub Actions with OIDC

The lab files use the example account `111122223333`, the repository `harbor-goods/storefront` and the bucket
`harbor-goods-storefront-static`. Replace them with your own values in your copy, never in this repository.

1. Create a GitHub repository you own. Copy `static/` to its root and `workflows/deploy.yml` to
   `.github/workflows/deploy.yml`.
2. In the repository settings, create an environment named `production`.
3. Create the static assets bucket with a globally unique name:

   ```bash
   aws s3 mb s3://YOUR_STATIC_BUCKET --region us-east-1
   ```

4. Create the GitHub OIDC provider, once per account:

   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com
   ```

5. Edit your copy of `iam/trust-policy.json`: set your account ID in the `Federated` ARN and your
   `OWNER/REPOSITORY` in the `sub` condition, keeping `:environment:production`. Create the role:

   ```bash
   aws iam create-role --role-name harbor-storefront-deploy \
     --assume-role-policy-document file://iam/trust-policy.json
   ```

6. Edit your copy of `iam/deploy-policy.json` to name your bucket, and attach it as an inline policy:

   ```bash
   aws iam put-role-policy --role-name harbor-storefront-deploy \
     --policy-name deploy-static --policy-document file://iam/deploy-policy.json
   ```

7. In `.github/workflows/deploy.yml`, set `role-to-assume` to your role ARN and `BUCKET` to your bucket. Push to
   `main` and watch the `deploy` job assume the role and sync the static assets.

Clean up:

```bash
aws iam delete-role-policy --role-name harbor-storefront-deploy --policy-name deploy-static
aws iam delete-role --role-name harbor-storefront-deploy
aws s3 rb s3://YOUR_STATIC_BUCKET --force
```

Delete the OIDC provider too if nothing else uses it (`aws iam list-open-id-connect-providers` shows its ARN,
`aws iam delete-open-id-connect-provider` removes it), and delete or archive the GitHub repository.

## Lab 05: containers to ECS

The core of the lab is local: `docker build` and `docker run --read-only --cap-drop ALL`, as the grader's smoke
test does. Registering the task definition and running it on ECS needs an ECR repository, a VPC, an ECS cluster
and IAM roles, which this workshop leaves out of scope.

## Check for leftovers

Lab 01 tags its resources with `project=harbor-goods`. List anything still tagged:

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=project,Values=harbor-goods --region us-east-1
```

An empty `ResourceTagMappingList` means lab 01 is clean. The lab 02 queues and the lab 03 buckets do not carry
that tag, so check them by name:

```bash
aws sqs list-queues --queue-name-prefix harbor-orders --region us-east-1
aws s3 ls | grep -i harborassets
aws cloudformation describe-stacks --stack-name HarborAssets --region us-east-1
```

Deleted SQS queues can stay listed for up to a minute. A `does not exist` error from the last command means the
stack no longer exists.
