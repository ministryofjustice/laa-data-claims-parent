#!/bin/sh
set -e

LOCALSTACK=claims-localstack

if ! docker inspect "$LOCALSTACK" >/dev/null 2>&1; then
  echo "LocalStack container '$LOCALSTACK' is not running. Run 'task infra' first." >&2
  exit 1
fi

echo "== SNS topics =="
docker exec "$LOCALSTACK" awslocal sns list-topics --query 'Topics[].TopicArn' --output text

echo "== SQS queues =="
docker exec "$LOCALSTACK" awslocal sqs list-queues --query 'QueueUrls' --output text

echo "== SNS subscriptions (subscribed queue endpoints) =="
docker exec "$LOCALSTACK" awslocal sns list-subscriptions --query 'Subscriptions[].Endpoint' --output text
