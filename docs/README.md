# Documentation map

The documentation follows the [Diátaxis](https://diataxis.fr/) framework: each page answers one kind of question.

| Kind | Use it when you want to | Where |
| --- | --- | --- |
| Tutorials | Learn by doing, one lab at a time | The lab READMEs, listed below |
| How-to guides | Reach a specific goal on your own machine or account | [how-to/](#how-to-guides) |
| Reference | Look up a command, an exit code or a version | [reference/](#reference) |
| Explanation | Understand why the labs work the way they do | [explanation/](#explanation) |

## Tutorials

Work through the labs in order. Each README has objectives, steps, the expected result and reset steps.

1. [Terraform remote state](../labs/01-terraform-remote-state/README.md)
2. [Terraform module testing](../labs/02-terraform-module-testing/README.md)
3. [CDK in Python with assertions](../labs/03-cdk-python-assertions/README.md)
4. [GitHub Actions with OIDC](../labs/04-github-actions-oidc/README.md)
5. [Containers to ECS](../labs/05-containers-to-ecs/README.md)

## How-to guides

- [Set up your machine](how-to/set-up-your-machine.md)
- [Use a sandbox account](how-to/use-a-sandbox-account.md)
- [Run the live test](how-to/run-the-live-test.md) (maintainers)
- [Add a lab](how-to/add-a-lab.md) (maintainers)

## Reference

- [Grader contract](reference/grader-contract.md)
- [Make targets](reference/make-targets.md)
- [Tooling and pinned versions](reference/tooling.md)

## Explanation

- [Remote state and locking](explanation/remote-state-and-locking.md)
- [What the offline tests prove](explanation/what-offline-tests-prove.md)
- [GitHub OIDC federation to AWS](explanation/oidc-federation.md)
- [Containers on Fargate](explanation/containers-on-fargate.md)

## Instructor material and decisions

- [Instructor notes](../instructor/README.md): timing, common mistakes and discussion prompts per lab.
- [Architecture decision records](adr/README.md): why the repository works the way it does.

## Diagrams

- [Context](diagrams/01-context.svg): participants, their laptops, the lab repository, the optional sandbox
  account and the client accounts the labs never touch.
- [Lab path](diagrams/02-lab-path.svg): the five labs in order and the AWS services each one uses.
- [OIDC flow](diagrams/03-oidc-flow.svg): the token exchange behind lab 04.

Each diagram has an editable `.drawio` source and a `.png` export next to it.
