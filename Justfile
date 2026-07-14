COMPOSE := "docker compose"
APPS := "claims-api event-service notify-service sabc-ui amend-ui"

# List available recipes
_default:
    @just --list

# Start (or no-op) the single shared LocalStack instance on the shared network
localstack:
    ./scripts/localstack-up.sh

# Stop the shared LocalStack instance
localstack-down:
    {{COMPOSE}} -f docker-compose.localstack.yml down

# Start shared LocalStack and provision ALL services' SNS/SQS resources (full fan-out)
infra: localstack
    {{COMPOSE}} run --rm claims-api-localstack-init
    {{COMPOSE}} run --rm event-service-localstack-init
    {{COMPOSE}} run --rm notify-service-localstack-init
    ./scripts/show-resources.sh

# Build and start the full stack in Docker
up: localstack
    {{COMPOSE}} up -d --build {{APPS}}

# Stop and remove all containers (keeps volumes)
down:
    {{COMPOSE}} --profile application down

# Tear everything down including volumes, then rebuild and start the full stack
reset:
    {{COMPOSE}} --profile application down -v
    @just up

# Provision infra for debugging one app in your IDE. Usage: just debug <app>
debug app="": infra
    ./scripts/debug-hints.sh {{app}}

# List the SNS topic, SQS queues and subscriptions currently in LocalStack
resources:
    ./scripts/show-resources.sh

# Show all stack containers across every repo (filters by the shared network)
ps:
    docker ps -a --filter network=claims-local

# Tail container logs. Usage: just logs <service>
logs *service:
    {{COMPOSE}} logs -f {{service}}

# Publish a PARSE_BULK_SUBMISSION event to claims-api-queue (local smoke test)
publish-bulk:
    ./laa-data-claims-event-service/docker-scripts/publish-bulk-submission-event.sh

# Publish a VALIDATE_SUBMISSION event to claims-api-queue (local smoke test)
publish-validation:
    ./laa-data-claims-event-service/docker-scripts/publish-submission-validation-event.sh

# Publish a SUBMISSION_VALIDATION_SUCCEEDED event so notify-queue receives it.
# Usage: just publish-notify [<submission-id>]
publish-notify submission_id="0561d67b-30ed-412e-8231-f6296a53538d":
    @echo "Publishing SUBMISSION_VALIDATION_SUCCEEDED for submission_id={{submission_id}}"
    docker exec claims-localstack awslocal sns publish \
        --topic-arn arn:aws:sns:us-east-1:000000000000:claims-events \
        --message '{"submission_id":"{{submission_id}}"}' \
        --message-attributes '{"SubmissionEventType":{"DataType":"String","StringValue":"SUBMISSION_VALIDATION_SUCCEEDED"}}'
