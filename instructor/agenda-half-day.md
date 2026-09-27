# Half-day agendas

Each agenda fills four hours with two labs, two breaks and a wrap-up. Times are offsets from the start of the
session. Start the recording after the setup check and pause it during breaks.

## Terraform half day (labs 01 and 02)

| Offset | Minutes | Block | Notes |
| --- | --- | --- | --- |
| 0:00 | 15 | Welcome, goals, setup check | Everyone runs `make check LAB=01` and confirms `FAIL` lines, no `BROKEN` |
| 0:15 | 15 | Concepts: state, backends, locking | Why local state breaks in a team; the bootstrap problem; S3 native locking |
| 0:30 | 10 | Lab 01 brief and demo | See [01-terraform-remote-state.md](01-terraform-remote-state.md) |
| 0:40 | 60 | Lab 01 work time | Exercises 1 to 4 (bootstrap) first, then 5 to 8 (app) |
| 1:40 | 15 | Lab 01 debrief | Two or three debrief questions, one participant solution on screen |
| 1:55 | 15 | Break | |
| 2:10 | 10 | Lab 02 brief and demo | See [02-terraform-module-testing.md](02-terraform-module-testing.md) |
| 2:20 | 60 | Lab 02 work time | Variables and validations first, then the dead-letter queue, then tests |
| 3:20 | 15 | Lab 02 debrief | Mocked tests versus a real plan; what to test in a module |
| 3:35 | 5 | Break | |
| 3:40 | 15 | Optional sandbox walkthrough | You apply lab 01 in your own sandbox on screen, then destroy it |
| 3:55 | 5 | Wrap-up | Stretch goals as practice, where to ask questions, feedback form |

## CI/CD half day (labs 04 and 05)

Lab 05 needs Docker. Confirm in the pre-work that `make check LAB=05` runs without `BROKEN` lines, because the
first build downloads the base image.

| Offset | Minutes | Block | Notes |
| --- | --- | --- | --- |
| 0:00 | 15 | Welcome, goals, setup check | `make check LAB=04` and `make check LAB=05` both print `FAIL` lines |
| 0:15 | 15 | Concepts: OIDC federation | Stored keys versus short-lived tokens; the `sub` and `aud` claims |
| 0:30 | 10 | Lab 04 brief and demo | See [04-github-actions-oidc.md](04-github-actions-oidc.md) |
| 0:40 | 55 | Lab 04 work time | Trust policy and deploy policy first, then the workflow |
| 1:35 | 15 | Lab 04 debrief | Run the OIDC dry run on a participant's trust policy |
| 1:50 | 15 | Break | |
| 2:05 | 10 | Lab 05 brief and demo | See [05-containers-to-ecs.md](05-containers-to-ecs.md) |
| 2:15 | 65 | Lab 05 work time | Dockerfile exercises 1 to 6, then the task definition |
| 3:20 | 15 | Lab 05 debrief | What ECS enforces at run time versus what the image promises |
| 3:35 | 5 | Break | |
| 3:40 | 15 | Connect the two labs | Sketch the pipeline that builds the lab 05 image and deploys it with the lab 04 role |
| 3:55 | 5 | Wrap-up | Stretch goals as practice, feedback form |

## CDK half day (labs 03 and 04)

Lab 03 needs Node.js for the CDK runtime. The first synthesis in a session takes longer than later ones.

| Offset | Minutes | Block | Notes |
| --- | --- | --- | --- |
| 0:00 | 15 | Welcome, goals, setup check | `make check LAB=03` prints `ok     the stack synthesizes` and `FAIL` lines |
| 0:15 | 15 | Concepts: constructs, synthesis, testing templates | Fine-grained assertions; rule packs; acknowledging a finding |
| 0:30 | 10 | Lab 03 brief and demo | See [03-cdk-python-assertions.md](03-cdk-python-assertions.md) |
| 0:40 | 60 | Lab 03 work time | Read the cdk-nag findings, build the log bucket, harden the assets bucket, add tests |
| 1:40 | 15 | Lab 03 debrief | When to acknowledge a rule and when to fix the resource |
| 1:55 | 15 | Break | |
| 2:10 | 10 | Lab 04 brief and demo | See [04-github-actions-oidc.md](04-github-actions-oidc.md) |
| 2:20 | 60 | Lab 04 work time | Trust policy and deploy policy first, then the workflow |
| 3:20 | 15 | Lab 04 debrief | Which job needs `id-token: write`, and why pull requests never get it |
| 3:35 | 5 | Break | |
| 3:40 | 15 | Connect the two labs | Where `cdk deploy` fits in the lab 04 workflow, and what role it would assume |
| 3:55 | 5 | Wrap-up | Stretch goals as practice, feedback form |

## Adjust the timing

- If most participants finish early, extend the debrief and start the stretch goals together on screen.
- If a lab runs long, cut the concepts block of the next lab to five minutes; do not cut breaks or debriefs.
- If more than a third of the group cannot pass the same check, stop work time and solve that one check together.
