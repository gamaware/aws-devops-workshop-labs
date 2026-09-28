# Copilot code review instructions

When reviewing pull requests in this repository:

- Files under `labs/*/starter/` are exercises and are insecure or incomplete on purpose; do not flag their findings.
- Files under `labs/*/solution/` are model answers: flag any weakening of security, pinning or least privilege.
- A new grader check must pass on the solution and fail on the starter (`scripts/verify-labs.sh`).
- Tests must use mocked providers or local tools only and must never call AWS.
- Actions must be pinned by full commit SHA with the version in a comment; workflows start from `permissions: {}`.
- Only fictional names and AWS documentation example account IDs may appear; no real IDs, ARNs, IPs or emails.
- Lab READMEs keep their required sections in order: Objectives, Prerequisites, Duration, Scenario, Steps,
  Expected result, Reset.
- Verify conventional commit format in PR titles.
