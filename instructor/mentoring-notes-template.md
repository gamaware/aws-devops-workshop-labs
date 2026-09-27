# Mentoring session notes template

Send these notes within one working day of each 1:1 session in the Starter format. Copy the block below into an
email or a shared document, fill in each section, and delete the guidance lines in parentheses. Keep it under one
page: the learner reads it before the next session.

```markdown
# Session N of 3: short topic

Participant: name
Mentor: name
Format: Starter, 1:1, 60 minutes

## Goals for this session

- (Two or three goals agreed at the start, in the learner's words.)

## What we did

- (The lab and exercises covered, for example "Lab 01, exercises 1 to 5".)
- (Grader state at the end, for example "4 of 6 checks passing; open: backend.hcl.example".)
- (One sentence on each concept discussed.)

## What you can do now

- (Skills stated as actions, for example "Declare a partial S3 backend and pass its values at init time".)

## Open questions

- (Questions we did not finish, and the answer if you found it after the session.)

## Practice before the next session

1. (The exact exercises to finish, with the command: make check LAB=NN.)
2. (One stretch goal from the lab notes, marked optional.)
3. (Expected time: 30 to 60 minutes.)

## Links

- Lab: labs/NN-name/ in the workshop repository
- Setup help: docs/how-to/set-up-your-machine.md
- Sandbox guide, only if you deploy: docs/how-to/use-a-sandbox-account.md

## Next session

- Planned topic: (lab or theme)
- Bring: (the grader output from your practice, and any error text you want to discuss)
```

## Tips for writing the notes

- Record the grader state as check names, not as percentages. "The partial backend check passes" tells the
  learner more than "80 % done".
- Write skills as actions the learner can repeat without you.
- Keep answers to open questions short and link the source you used.
- Never include credentials, account IDs or internal names from the learner's employer. Use the Harbor Goods
  names from the labs.
