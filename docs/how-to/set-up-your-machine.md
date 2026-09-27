# Set up your machine

This guide installs the tools the lab graders need and confirms that the setup works. The graders run offline: you
need no AWS account for any lab.

## Required tools

| Tool | Version | Used by |
| --- | --- | --- |
| git | any recent | cloning, `make reset` |
| GNU make | any recent | every `make` target |
| uv | any recent | the locked Python environment (labs 03 to 05, linters) |
| Python 3 | 3.12 or later | lab 05 grader; uv installs its own copy for the rest |
| Terraform | 1.11 or later, CI uses 1.14.5 | labs 01 and 02 |
| Node.js | 22 or 24 | the jsii runtime behind `aws-cdk-lib` in lab 03 |
| Docker | Engine or Desktop, running | lab 05 |
| hadolint | 2.15.1 | lab 05 |
| curl | any | lab 05 smoke test |

## Optional tools

| Tool | When you need it |
| --- | --- |
| AWS CLI v2 | Only for the optional live steps in [use a sandbox account](use-a-sandbox-account.md) |
| AWS CDK CLI | Only to deploy lab 03; run it through `npx aws-cdk@2`, no global install needed |
| shellcheck | `make lint` and `make verify` |
| checkov | `make checkov` and `make verify` |
| trivy | `make trivy` and `make verify` |
| tflint | The pre-commit hooks, with the AWS ruleset from `.tflint.hcl` |

## Install on macOS

Install [Homebrew](https://brew.sh/), then:

```bash
brew install git make uv node@24 hadolint curl
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install --cask docker
```

Start Docker Desktop once so the daemon runs. For the optional tools:

```bash
brew install awscli shellcheck checkov trivy tflint
```

## Install on Linux

The commands below use Debian or Ubuntu package names. Adapt them to your distribution.

```bash
sudo apt-get update
sudo apt-get install -y git make curl unzip python3
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Install the rest from their upstream instructions:

- Terraform: the [HashiCorp APT repository](https://developer.hashicorp.com/terraform/install), or the 1.14.5
  zip from `releases.hashicorp.com` placed on your `PATH`.
- Node.js 22 or 24: [NodeSource](https://github.com/nodesource/distributions) or a version manager such as `nvm`.
- Docker Engine: the [Docker install guide](https://docs.docker.com/engine/install/). Add your user to the
  `docker` group so the grader can run `docker` without `sudo`.
- hadolint 2.15.1:

```bash
mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/hadolint \
  https://github.com/hadolint/hadolint/releases/download/v2.15.1/hadolint-linux-x86_64
chmod +x ~/.local/bin/hadolint
```

On ARM64 hosts, download `hadolint-linux-arm64` instead.

## Install on Windows

Run the labs inside WSL2. The graders are Bash scripts and do not run in PowerShell or Command Prompt.

1. In an administrator PowerShell, run `wsl --install -d Ubuntu` and restart.
2. Install Docker Desktop for Windows and turn on **Use the WSL 2 based engine** and the integration for your
   Ubuntu distribution.
3. Open the Ubuntu terminal and follow [install on Linux](#install-on-linux), skipping Docker Engine.
4. Clone the repository inside the WSL file system (for example `~/src`), not under `/mnt/c`. Git on `/mnt/c`
   loses the executable bit on the graders and runs slower.

## Install the Python environment

From the repository root:

```bash
make setup
```

`make setup` runs `uv sync --frozen`, which creates `.venv` with the exact versions in `uv.lock`: `aws-cdk-lib`,
`cdk-nag`, `pytest`, `actionlint`, `zizmor` and `ruff`.

## Check the setup

Grade the untouched lab 01 starter:

```bash
make check LAB=01
```

The first run downloads the AWS provider into `.cache/terraform-plugins`. Later labs download Python packages
and, for lab 05, the `python` base image. Later runs reuse all of them.

Read the result by its last lines:

| Output | Meaning | Action |
| --- | --- | --- |
| `FAIL` lines, then `RESULT n objective(s) not met`, and `make` reports error 1 | The setup works; the starter still needs your work | Start the lab |
| `SETUP  missing tool: <name>` | A required tool is not on your `PATH` | Install it, open a new shell, try again |
| `BROKEN <step>` and exit 2 | A precondition failed, for example `terraform init` | Read the indented log under the line; a network or version problem is the common cause |

Run `make check LAB=05` once as well: it confirms that Docker, hadolint and curl work.

See the [grader contract](../reference/grader-contract.md) for every exit code and the
[tooling reference](../reference/tooling.md) for pinned versions.
