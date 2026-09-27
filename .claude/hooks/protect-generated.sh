#!/usr/bin/env bash
# Pre-edit hook: block hand edits to generated files. Exit 2 blocks the edit.
set -euo pipefail

FILE="$(jq --raw-output '.tool_input.file_path // empty')"

case "$FILE" in
  */uv.lock | */.terraform.lock.hcl)
    echo "Generated file: regenerate it (uv lock, terraform providers lock) instead of editing." >&2
    exit 2
    ;;
  */docs/diagrams/*.svg | */docs/diagrams/*.png)
    echo "Exported diagram: edit the .drawio source and export again." >&2
    exit 2
    ;;
esac
exit 0
