#!/usr/bin/env bash
# Put a lab's starter back to its original state: discard your edits, delete files you
# added, and remove local caches (.terraform, cdk.out). Does not touch AWS: if you applied
# anything to a sandbox account, run the lab's Reset steps first.
# Usage: scripts/reset-lab.sh <lab-number>   (set RESET_YES=1 to skip the question)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
matches=("$REPO_ROOT"/labs/"${1:?usage: reset-lab.sh <lab-number>}"-*/starter)
STARTER="${matches[0]}"
[ -d "$STARTER" ] || { echo "no starter for lab $1" >&2; exit 2; }

relative="${STARTER#"$REPO_ROOT"/}"
echo "This discards every change under $relative:"
git -C "$REPO_ROOT" status --short --untracked-files=all --ignored -- "$relative"
if [ "${RESET_YES:-0}" != "1" ]; then
  read -r -p "Continue? [y/N] " answer
  [ "$answer" = "y" ] || exit 1
fi

git -C "$REPO_ROOT" restore --source=HEAD --staged --worktree -- "$relative"
git -C "$REPO_ROOT" clean -d --force -x --quiet -- "$relative"
echo "Lab $1 starter restored."
