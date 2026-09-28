#!/usr/bin/env bash
# Build the lab 05 image and run it the way ECS will: read-only root filesystem, all
# Linux capabilities dropped, no privilege escalation. Then probe it. The image must not
# run as root and must not ship pip.
# Usage: smoke.sh <directory-with-Dockerfile>
set -euo pipefail

CONTEXT="$1"
IMAGE="harbor-catalog:grader-$$"
CONTAINER=""

cleanup() {
  if [ "$CONTAINER" != "" ]; then
    docker rm --force "$CONTAINER" > /dev/null 2>&1 || true
  fi
  docker image rm --force "$IMAGE" > /dev/null 2>&1 || true
}
trap cleanup EXIT

docker build --quiet --tag "$IMAGE" "$CONTEXT" > /dev/null

user="$(docker image inspect --format '{{.Config.User}}' "$IMAGE")"
echo "image user: ${user:-<none, so root>}"
case "$user" in
  "" | root | 0 | 0:*) echo "the image runs as root" >&2; exit 1 ;;
esac

if docker run --rm --entrypoint python "$IMAGE" -c "import pip" > /dev/null 2>&1; then
  echo "pip is still in the image: the app does not need a package manager at run time" >&2
  exit 1
fi

CONTAINER="$(docker run --detach --read-only --cap-drop ALL --security-opt no-new-privileges \
  --publish 127.0.0.1::8080 "$IMAGE")"

status="starting"
for _ in {1..30}; do
  status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$CONTAINER")"
  [ "$status" = "starting" ] || break
  sleep 1
done
echo "health status: $status"
if [ "$status" != "healthy" ]; then
  docker logs "$CONTAINER" >&2
  exit 1
fi

port="$(docker port "$CONTAINER" 8080/tcp | head -n 1 | sed 's/.*://')"
products="$(curl --fail --silent --show-error "http://127.0.0.1:$port/products")"
count="$(printf '%s' "$products" | python3 -c 'import json, sys; print(len(json.load(sys.stdin)))')"
echo "GET /products returned $count products"
[ "$count" -eq 4 ]
