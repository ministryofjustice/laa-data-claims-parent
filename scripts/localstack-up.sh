#!/bin/sh
set -e

NETWORK=claims-local
LOCALSTACK=claims-localstack
DIR="$(cd "$(dirname "$0")/.." && pwd)"

docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK" >/dev/null

docker compose -f "$DIR/docker-compose.localstack.yml" up -d

printf "Waiting for LocalStack to be healthy"
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$LOCALSTACK" 2>/dev/null)" = "healthy" ]; do
  printf "."
  sleep 1
done
echo " ok."
