#!/usr/bin/env bash
# Creates the scaffolder's own resources inside LocalStack on container ready.
# Mirrors infra/live/scaffolder/dev — key schema and queue names must match, or
# a green local run proves nothing about the deployed one.
set -euo pipefail

TABLE=internal-developer-platform-scaffolder-local

# One queue per worker, as in infra/live/scaffolder/dev. Locally a single
# container can serve both, but the names have to match the deployed ones or
# switching SCAFFOLDER_TASK_QUEUE_NAME to try the other worker fails.
QUEUES=(
  internal-developer-platform-scaffolder-state-tasks-local
  internal-developer-platform-scaffolder-github-tasks-local
)

awslocal dynamodb create-table \
  --table-name "$TABLE" \
  --attribute-definitions \
      AttributeName=PK,AttributeType=S \
      AttributeName=SK,AttributeType=S \
  --key-schema \
      AttributeName=PK,KeyType=HASH \
      AttributeName=SK,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST

awslocal dynamodb update-time-to-live \
  --table-name "$TABLE" \
  --time-to-live-specification "Enabled=true,AttributeName=ExpiresAt"

for queue in "${QUEUES[@]}"; do
  awslocal sqs create-queue --queue-name "$queue"
done

echo "scaffolder local resources ready"
