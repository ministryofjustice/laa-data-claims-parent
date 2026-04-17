#!/usr/bin/env bash

for repo in \
  laa-data-claims-api \
  laa-data-claims-event-service \
  laa-submit-a-bulk-claim \
  update-bulk-claim-repos
do
  if [ -d "$repo/.git" ]; then
    echo "=== Updating $repo ==="
    (
      cd "$repo" || exit
      git fetch
      git checkout main
      git pull
    )
  fi
done
