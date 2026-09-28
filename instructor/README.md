# Instructor guide

This folder holds everything you need to run the labs with a person or a team: how each engagement format uses
the repository, what to send participants before the first session, how to run one lab, how to unblock a participant,
and how to adapt a lab to a client's own stack.

The labs use a fictional retailer, Harbor Goods. Every lab runs offline by default: the graders use mocked
providers, synthesized templates and local Docker, so nobody needs AWS credentials to finish a lab. Participants
who want to see real resources use their own sandbox account. You never need access to the client's company
accounts. Deliver in English or Spanish; the lab code, grader output and these notes
stay in English.

## Files in this folder

| File | Use it for |
| --- | --- |
| [agenda-half-day.md](agenda-half-day.md) | Minute-by-minute agendas for a Terraform, CI/CD or CDK half day |
| [mentoring-notes-template.md](mentoring-notes-template.md) | The written notes you send after each 1:1 session |
| [01-terraform-remote-state.md](01-terraform-remote-state.md) | Lab 01 notes: remote state, bucket hardening, partial backend |
| [02-terraform-module-testing.md](02-terraform-module-testing.md) | Lab 02 notes: a reusable module with `terraform test` |
| [03-cdk-python-assertions.md](03-cdk-python-assertions.md) | Lab 03 notes: CDK in Python, assertions and cdk-nag |
| [04-github-actions-oidc.md](04-github-actions-oidc.md) | Lab 04 notes: GitHub Actions to AWS through OIDC |
| [05-containers-to-ecs.md](05-containers-to-ecs.md) | Lab 05 notes: a hardened image and a Fargate task definition |

## The participant loop

Every lab works the same way, so explain it once at the start:

1. Open the lab's `starter/` directory and edit the files in place. Comments marked `Exercise N` say what to add.
2. Run `make check LAB=NN` from the repository root. The grader prints one line per objective.
3. Read the first `FAIL` line, fix it, and run the grader again.
4. `make reset LAB=NN` restores the starter (it asks first; `RESET_YES=1` skips the question).

The grader exits with 0 when the code meets every objective, 1 when the code is valid but misses at least one
objective, and 2 when the target fails to load or validate or a tool is missing. An untouched starter always exits
with 1. Lines that start with `ok` are preconditions, `PASS` and `FAIL` are objectives, and `BROKEN` or `SETUP`
mean the grader could not run at all. See [the grader contract](../docs/reference/grader-contract.md) and
[the make targets](../docs/reference/make-targets.md).

## Formats

| Format | Shape | Labs | Timing |
| --- | --- | --- | --- |
| Starter | Three 1-hour 1:1 mentoring sessions, written notes after each | One lab per session, chosen with the participant | 10 min review, 40 min lab, 10 min recap |
| Standard | Remote half-day workshop on one topic, up to 12 people, recorded | Two labs from one track | 4 hours, see [agenda-half-day.md](agenda-half-day.md) |
| Advanced | Two half-day workshops plus a Q&A call a week later | Labs adapted to the client's stack | 2 x 4 hours, plus a 60-minute call |

### Starter: three 1:1 sessions

Agree on the goal in the first five minutes of session 1, then pick the path. A common Terraform path is lab 01,
lab 02, then lab 04; a CDK path is lab 03, lab 04, then lab 05.

- Minutes 0 to 10: review the notes from the last session and the practice the participant did since.
- Minutes 10 to 50: the participant drives and you pair. Run the 5-minute opening demo from the lab notes, then let
  the participant work through the exercises with `make check` after each one.
- Minutes 50 to 60: recap the concepts, agree on the practice, and note open questions.

A full lab takes 80 to 90 minutes, longer than one session. Stop at a clean point, record which checks pass, and
set the remaining exercises as practice. Send the notes within one working day using
[mentoring-notes-template.md](mentoring-notes-template.md).

### Standard: one half-day workshop

Pick one track and run two labs: Terraform (labs 01 and 02), CI/CD (labs 04 and 05) or CDK (labs 03 and 04).
Follow [agenda-half-day.md](agenda-half-day.md). Start the recording after the setup check, so the recording
starts with content, and stop it during breaks. Keep at most 12 participants: with more, you cannot watch every
grader output during work time.

### Advanced: two half-day workshops and a follow-up call

Run an intake call two weeks before day 1. Ask for the stack in general terms (IaC tool and version, CI system,
container platform, naming and tagging rules). Do not ask for account IDs, credentials or access. Adapt one or two
labs to that stack (see [Adapt a lab to a client stack](#adapt-a-lab-to-a-client-stack)). A typical split:

- Day 1: the closest standard lab, then its adapted version, so participants see the pattern twice.
- Day 2: a second adapted lab and a longer debrief on how the team applies it at work.
- Q&A call, one week later, 60 minutes: questions from applying the labs to real work, plus the stretch goals
  participants tried.

## Pre-work checklist for participants

Send this list at least five working days before the first session and ask everyone to confirm the last step.

- [ ] Install the tools in [Set up your machine](../docs/how-to/set-up-your-machine.md): `git`, `make`, `uv`,
      Terraform 1.11 or later, Node.js (lab 03), Docker and hadolint (lab 05).
- [ ] Clone the repository and run `make setup` from its root. It installs the locked Python environment.
- [ ] Run `make check LAB=01`. Seeing `FAIL` lines and `RESULT 6 objective(s) not met` means the setup works:
      the untouched starter fails by design. A `SETUP  missing tool` or `BROKEN` line means something is missing.
- [ ] For the CI/CD track, start Docker, run `make check LAB=05`, and confirm the same pattern (`FAIL` lines, no
      `BROKEN`). This also downloads the base image.
- [ ] Optional: read [Use a sandbox account](../docs/how-to/use-a-sandbox-account.md) if you want to deploy
      anything. Never use a company account for the labs.
- [ ] Reply with the last lines of the `make check LAB=01` output, or with the error you got.

The first `make check` downloads Terraform providers and Python packages. On a slow or filtered network this takes
minutes, which is why it belongs in the pre-work and not in the session.

## Room and remote setup

- Use a video tool with screen sharing and breakout rooms. Test that you can move people between rooms.
- Share your terminal with a font size of 18 or larger and a light theme. Close notifications.
- Keep one terminal on `labs/NN-*/starter` and a second one on the solution for your own reference, off screen.
- Post the command for the current lab in the chat: `make check LAB=01`. People paste it more than they type it.
- Open a shared document with one row per participant and the columns "setup ok", "checks passing" and "stuck on".
  Ask participants to update it; scan it every 10 minutes during work time.
- Record only the main room. Tell participants before you start recording.
- For a mixed-language group, run the talk in the agreed language and leave the code, commands and grader output in
  English.

## Run one lab

Every lab uses the same four-part rhythm. The per-lab notes give the timings and content.

1. **Brief, 3 to 5 minutes.** State the scenario in two sentences, the learning goals, and what "done" looks like:
   `RESULT all objectives met`.
2. **Demo, 5 minutes.** Run the opening demo from the lab notes. Always run `make check LAB=NN` on the untouched
   starter on screen and read one `FAIL` line aloud, so everyone knows how to read the output.
3. **Work time.** Participants work alone or in pairs. Visit breakout rooms in order. Ask "which check are you on?"
   before you look at code.
4. **Debrief, 10 to 15 minutes.** Use the debrief questions from the lab notes. Ask one participant to share a
   passing solution that differs from the reference solution and discuss the trade-off.

Announce the time left at the halfway point and five minutes before the end. People who finish early take the
stretch goals.

## Handle stuck participants

Work through these steps in order and stop as soon as the participant moves again.

1. **One failing check at a time.** Ask the participant to read the first `FAIL` line and its message aloud. Most
   blocks come from reading all the output at once. The grader shows the last 40 lines of each failing check, so
   the first failure inside a check can scroll away. Run the underlying test on its own to see it in full:

   ```bash
   # Labs 03, 04 and 05: one grader test at a time, with full output
   LAB_TARGET=labs/04-github-actions-oidc/starter PYTHONPATH=labs/04-github-actions-oidc/tests \
     uv run pytest labs/04-github-actions-oidc/tests/test_grader.py -k trust_policy
   ```

2. **Pair.** Put the participant with someone who passed that check, in a breakout room, for five minutes. The helper
   explains; the stuck participant types.
3. **Compare with the solution, one file only.** Grade the solution to prove the check can pass, then show the diff
   for the one file behind the failing check:

   ```bash
   make check LAB=01 TARGET=solution
   git diff --no-index labs/01-terraform-remote-state/starter/app/versions.tf \
     labs/01-terraform-remote-state/solution/app/versions.tf
   ```

4. **Reset.** If the starter is in a state the participant cannot explain, run `make reset LAB=NN` and redo the
   exercises that passed. It takes less time than debugging a broken edit.

A `BROKEN` line means the code no longer parses, validates or synthesizes. Fix that before you look at any
`FAIL` line: the grader stops at the first broken precondition.

## Adapt a lab to a client stack

The Advanced format adapts labs to the client's tools and conventions: their module layout, their tagging rules,
their CI system. You build the adapted lab from the client's description, never from their accounts or code.

1. Copy the closest lab to the next free number, for example `cp -R labs/02-terraform-module-testing
   labs/06-harbor-goods-network-module`, and delete its `.terraform` and `cdk.out` directories if present.
2. Replace `solution/` with a working version that meets the client's conventions, then copy it to `starter/` and
   remove what the participants should build. Leave an `Exercise N` comment at each place.
3. Keep the grader contract: `tests/run.sh` takes the starter or solution directory, sources
   `scripts/lib/grader.sh`, uses `setup` for preconditions and `check` for objectives, and ends with `finish`.
   It exits with 0, 1 or 2 as described in [the grader contract](../docs/reference/grader-contract.md). Keep it
   offline: mocked providers, synthesized templates, fixtures.
4. Write the lab's `README.md` with the sections the docs check expects (Objectives, Prerequisites, Duration,
   Scenario, Steps, Expected result, Reset), add `instructor/NN-name.md`, and link the lab from the root README.
5. Run `scripts/verify-labs.sh NN`. It must report `ok`: the solution exits with 0 and the untouched starter
   exits with 1, failing exactly the checks listed in `tests/starter-failures.txt`. A starter that passes asks for
   no work; the grader cannot grade a starter that exits with 2.
6. Run `make docs-check` and do a dry run of the lab yourself, from the starter, with a timer.

Keep the Harbor Goods names in adapted labs unless the client asks otherwise. Their real names, account IDs or
internal hostnames never go into the repository.
