#!/bin/sh
set -e

APP="$1"

case "$APP" in
  claims-api)
    echo "claims-api: application.yml already targets http://localhost:4566 (SQS+SNS)"
    echo "and Postgres on localhost:5432. It sets NO AWS credentials, so add these"
    echo "to your run config's Environment variables (LocalStack ignores the values,"
    echo "but the AWS SDK requires them to be present):"
    echo "  AWS_ACCESS_KEY_ID=dummy-access-key"
    echo "  AWS_SECRET_ACCESS_KEY=dummy-secret-key"
    echo "  AWS_REGION=us-east-1"
    ;;
  event-service)
    echo "event-service: set the Spring profile 'wiremock' in your run config"
    echo "(Active profiles: wiremock  /  -Dspring.profiles.active=wiremock)."
    echo "That profile provides everything: the LocalStack endpoint (localhost:4566),"
    echo "dummy AWS credentials, region, the claims-api-queue name and the WireMock hosts."
    ;;
  notify-service)
    echo "notify-service: set the Spring profile 'local' in your run config"
    echo "(Active profiles: local  /  -Dspring.profiles.active=local)."
    echo "That profile provides dummy AWS credentials, the LocalStack endpoint"
    echo "(localhost:4566), the region (us-east-1) and the notify-queue name."
    echo "NOTE: on older checkouts the local profile lacked the region and"
    echo "defaulted to eu-west-2 - if so, also set AWS_REGION=us-east-1."
    ;;
  "")
    echo "Usage: task debug -- <app>   (claims-api | event-service | notify-service)" >&2
    exit 1
    ;;
  *)
    echo "Unknown app '$APP'. Use one of: claims-api, event-service, notify-service" >&2
    exit 1
    ;;
esac

echo ""
echo "Infrastructure is up. Now start '$APP' from your IDE (do NOT also run it in Docker)."
