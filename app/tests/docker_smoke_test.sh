#!/usr/bin/env bash
# Acceptance checks for the Docker image — run after any Dockerfile change.
# Not part of the pytest suite: these assert properties of the built image/
# container itself, not application logic.
set -euo pipefail

cd "$(dirname "$0")/.."
IMAGE_TAG="contactform-app:smoke-test"
CONTAINER_NAME="contactform-smoke-test"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "== 1. Image builds =="
docker build -t "$IMAGE_TAG" .

echo "== 2. Container runs as non-root =="
USER_ID=$(docker run --rm "$IMAGE_TAG" id -u)
if [ "$USER_ID" = "0" ]; then
  echo "FAIL: container is running as root (uid 0)"
  exit 1
fi
echo "OK: running as uid $USER_ID"

echo "== 3. Serves via gunicorn, not the Flask dev server =="
# DB_PORT/DB_PASSWORD are overridable so this works both against local
# Compose Postgres (port 5433) and a CI-provided Postgres service (5432).
DB_PORT="${SMOKE_DB_PORT:-5433}"
DB_PASSWORD="${SMOKE_DB_PASSWORD:-localdevpassword}"
docker run -d --name "$CONTAINER_NAME" \
  --add-host=host.docker.internal:host-gateway \
  -e DB_HOST=host.docker.internal -e DB_PORT="$DB_PORT" \
  -e DB_NAME=contactform -e DB_USER=contactform -e DB_PASSWORD="$DB_PASSWORD" \
  -p 5001:5000 "$IMAGE_TAG"

sleep 3
PROCESS=$(docker top "$CONTAINER_NAME" | grep gunicorn || true)
if [ -z "$PROCESS" ]; then
  echo "FAIL: gunicorn process not found in container"
  docker logs "$CONTAINER_NAME"
  exit 1
fi
echo "OK: gunicorn is running"

echo "== 4. /healthz responds =="
for i in $(seq 1 10); do
  if curl -sf http://localhost:5001/healthz >/dev/null; then
    echo "OK: /healthz responded"
    exit 0
  fi
  sleep 1
done

echo "FAIL: /healthz never responded"
docker logs "$CONTAINER_NAME"
exit 1
