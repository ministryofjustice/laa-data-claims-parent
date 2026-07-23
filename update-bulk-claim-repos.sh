#!/usr/bin/env bash

for repo in \
  laa-data-claims-api \
  laa-data-claims-event-service \
  laa-submit-a-bulk-claim \
  laa-amend-a-claim \
  laa-data-claims-notify-service \
  laa-oidc-mock-server
do
  if [ -e "$repo/.git" ]; then
    echo "=== Updating $repo ==="
    (
      cd "$repo" || exit
      git fetch
      git checkout main
      git pull
    )
  fi
done
