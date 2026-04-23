#!/bin/bash

# Format:
# STAGING_DEPLOYMENT|STAGING_NAMESPACE|UAT_DEPLOYMENT|UAT_NAMESPACE|PROD_DEPLOYMENT|PROD_NAMESPACE|FRIENDLY_NAME
declare -a SERVICES=(
  "laa-data-claims-api|laa-data-claims-api-staging|main-data-claims-api|laa-data-claims-api-uat|laa-data-claims-api|laa-data-claims-api-prod|Data Claims API"
  "stg-submit-a-bulk-claim|laa-submit-a-bulk-claim-staging|uat-submit-a-bulk-claim|laa-submit-a-bulk-claim-uat|prod-submit-a-bulk-claim|laa-submit-a-bulk-claim-prod|Submit a Bulk Claim"
  "stg-data-claims-events|laa-data-claims-event-service-staging|uat-data-claims-events|laa-data-claims-event-service-uat|prod-data-claims-events|laa-data-claims-event-service-prod|Data Claims Event"
  "laa-fee-scheme-api-staging-deployment|laa-fee-scheme-api-staging|laa-fee-scheme-api-uat-deployment|laa-fee-scheme-api-uat|laa-fee-scheme-api-prod-deployment|laa-fee-scheme-api-prod|Fee Scheme API"
  "laa-amend-a-claim|laa-amend-a-claim-staging|laa-amend-a-claim|laa-amend-a-claim-uat|laa-amend-a-claim|laa-amend-a-claim-production|Amend a Claim"
)

get_image_tag() {
  IMAGE="$1"
  # Extract everything after the last colon
  echo "${IMAGE##*:}"
}

echo ""
echo "============================================="
echo "   LAA Deployments UAT vs STAGING vs PROD"
echo "============================================="
echo ""

for SERVICE in "${SERVICES[@]}"; do
  IFS='|' read -r DEPLOY_STG NS_STG DEPLOY_UAT NS_UAT DEPLOY_PROD NS_PROD NAME <<< "$SERVICE"

  echo "$NAME"
  echo "-------------------------------------"

  # Fetch full image strings
  IMG_STG=$(kubectl get deploy "$DEPLOY_STG" -n "$NS_STG" -o=jsonpath='{.spec.template.spec.containers[0].image}')
  IMG_UAT=$(kubectl get deploy "$DEPLOY_UAT" -n "$NS_UAT" -o=jsonpath='{.spec.template.spec.containers[0].image}')
  IMG_PROD=$(kubectl get deploy "$DEPLOY_PROD" -n "$NS_PROD" -o=jsonpath='{.spec.template.spec.containers[0].image}')

  # Extract tags only
  TAG_STG=$(get_image_tag "$IMG_STG")
  TAG_UAT=$(get_image_tag "$IMG_UAT")
  TAG_PROD=$(get_image_tag "$IMG_PROD")

  # Fetch timestamps
  TS_STG=$(kubectl get deploy "$DEPLOY_STG" -n "$NS_STG" -o=jsonpath='{.status.conditions[?(@.type=="Progressing")].lastUpdateTime}')
  TS_UAT=$(kubectl get deploy "$DEPLOY_UAT" -n "$NS_UAT" -o=jsonpath='{.status.conditions[?(@.type=="Progressing")].lastUpdateTime}')
  TS_PROD=$(kubectl get deploy "$DEPLOY_PROD" -n "$NS_PROD" -o=jsonpath='{.status.conditions[?(@.type=="Progressing")].lastUpdateTime}')

  # Output in UAT → Staging → Prod order
  echo "UAT:"
  echo "  Image Tag:        $TAG_UAT"
  echo "  Release Time:     $TS_UAT"
  echo ""

  echo "STAGING:"
  echo "  Image Tag:        $TAG_STG"
  echo "  Release Time:     $TS_STG"
  echo ""

  echo "PROD:"
  echo "  Image Tag:        $TAG_PROD"
  echo "  Release Time:     $TS_PROD"

  echo ""
  echo "============================================="
  echo ""
done
