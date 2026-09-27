# One entry point for local runs and CI. `make verify` is what CI runs: it proves every
# solution meets its objectives and every untouched starter still needs work, then lints
# and scans the repository. Offline: no AWS credentials and no AWS API calls. The first run
# downloads Python packages (uv), Terraform providers, the python base image and the Trivy
# database; later runs reuse them.

SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

LAB ?=
TARGET ?= starter
UV := uv run --frozen --quiet
TF_DIRS := $(sort $(dir $(wildcard labs/*/*/*/versions.tf labs/*/*/*/*/versions.tf)))
export TF_PLUGIN_CACHE_DIR := $(CURDIR)/.cache/terraform-plugins
export JSII_SILENCE_WARNING_UNTESTED_NODE_VERSION := 1

.PHONY: help setup verify lint tflint labs docs-check checkov trivy check reset test-live clean

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-11s %s\n", $$1, $$2}'

setup: ## Install the locked Python environment (aws-cdk-lib, cdk-nag, pytest, actionlint, zizmor, ruff)
	uv sync --frozen

verify: setup lint tflint labs docs-check checkov trivy ## Run every offline check (what CI runs)
	@echo "make verify: all checks passed"

lint: ## ruff, terraform fmt and shellcheck
	$(UV) ruff check .
	$(UV) ruff format --check .
	terraform fmt -check -recursive labs
	shellcheck --severity=warning scripts/*.sh scripts/lib/*.sh labs/*/tests/*.sh

tflint: ## tflint (AWS ruleset, .tflint.hcl) on every Terraform directory, starters included
	for dir in $(TF_DIRS); do \
	  echo "--- $$dir"; \
	  terraform -chdir=$$dir init -backend=false -input=false > /dev/null; \
	  (cd $$dir && tflint --init --config=$(CURDIR)/.tflint.hcl > /dev/null && tflint --config=$(CURDIR)/.tflint.hcl); \
	done

labs: ## Grade every solution (must pass) and every starter (must fail): scripts/verify-labs.sh
	scripts/verify-labs.sh

docs-check: ## Lab structure, required README sections, instructor notes, relative links
	$(UV) python scripts/check_docs.py

checkov: ## Policy checks on the lab solutions (.checkov.yaml); starters are graded, not scanned
	checkov --config-file .checkov.yaml

trivy: ## Trivy misconfiguration and secret scan; starters are graded, not scanned
	trivy fs --quiet --scanners misconfig,secret --exit-code 1 --severity HIGH,CRITICAL \
	  --skip-dirs 'labs/*/starter' --skip-dirs '**/.terraform' --skip-dirs .venv --skip-dirs .cache .

check: ## Grade your work: make check LAB=01 [TARGET=starter|solution]
	@test -n "$(LAB)" || { echo "usage: make check LAB=01 [TARGET=starter]"; exit 2; }
	labs/$(LAB)-*/tests/run.sh labs/$(LAB)-*/$(TARGET)

reset: ## Discard your changes to a starter: make reset LAB=01 (asks first)
	@test -n "$(LAB)" || { echo "usage: make reset LAB=01"; exit 2; }
	scripts/reset-lab.sh $(LAB)

test-live: ## Manual, maintainer only: apply labs 01 and 02 to the dev account, verify, destroy (docs/how-to/run-the-live-test.md)
	scripts/test-live.sh

clean: ## Remove caches and build output (keeps the Python environment)
	rm -rf .cache
	find labs -name .terraform -type d -prune -exec rm -rf {} +
	find labs -name cdk.out -type d -prune -exec rm -rf {} +
	find labs -name __pycache__ -type d -prune -exec rm -rf {} +
