#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly SERVICE_DIR="${ROOT_DIR}/laa-data-claims-api"
readonly SCRIPTS="${SERVICE_DIR}/.github/actions/snyk-report"
readonly IMAGE="laa-data-claims-api:local"

usage() {
  cat <<'EOF'
Usage: scripts/snyk/snyk-report.sh [--rebuild]

Generates the Claims API Snyk report and Slack summary (the same scripts the
snyk-report GitHub action uses) from a scan of the local image
laa-data-claims-api:local. The image is built if it does not exist.

Options:
  --rebuild   Rebuild the image before scanning
  -h, --help  Show this help text

Environment (SNYK_* values are also read from .env):
  SNYK_TOKEN                 Snyk auth token
  SNYK_ORG                   Snyk org to scan under (optional)
  SNYK_SEVERITY_THRESHOLD    low | medium | high | critical (default: medium)
EOF
}

rebuild=0
for arg in "$@"; do
  case "$arg" in
    --rebuild) rebuild=1 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

# Load only SNYK_* from .env: its GITHUB_TOKEN would override gh's login and Gradle's package credentials
if [ -f "${ROOT_DIR}/.env" ]; then
  while IFS='=' read -r key value; do
    case "$key" in SNYK_*) export "$key=$value" ;; esac
  done < "${ROOT_DIR}/.env"
fi
export REPO="${REPO:-ministryofjustice/laa-data-claims-api}"

# Scripts write snyk-*.json/md and slack-summary.txt to the current directory
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
cd "$work_dir"

image_scan_result=local
build_args=()
if [ "$rebuild" -eq 1 ] || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "== Building and scanning a local image (output hidden unless it fails) =="
else
  echo "== Scanning existing local image $IMAGE (use --rebuild to rebuild) =="
  build_args=(--skip-build)
fi
scan_args=(--sarif-file-output="$work_dir/snyk-report.sarif")
[ -n "${SNYK_ORG:-}" ] && scan_args+=(--org="$SNYK_ORG")
scan_log="$work_dir/scan.log"
status=0
"${SCRIPT_DIR}/container-scan.sh" claims-api ${build_args[@]+"${build_args[@]}"} \
  --severity-threshold "${SNYK_SEVERITY_THRESHOLD:-medium}" -- "${scan_args[@]}" > "$scan_log" 2>&1 || status=$?
# Snyk exits 1 when it finds vulnerabilities (still produces SARIF); 2+ or no SARIF means the build/scan itself failed
if [ "$status" -ge 2 ] || [ ! -s "$work_dir/snyk-report.sarif" ]; then
  cat "$scan_log" >&2
  echo "Local build/scan failed (exit $status)" >&2
  exit 1
fi
if [ "$status" -eq 0 ]; then
  image_scan_result=success
  echo "Scan passed"
else
  image_scan_result=failure
  echo "Scan found vulnerabilities (details in the report below)"
fi
export SARIF_FILE="$work_dir/snyk-report.sarif"
export REF="local build of $(git -C "$SERVICE_DIR" rev-parse --short HEAD)"

echo; echo "== fetch-alerts.sh =="
output="$("$SCRIPTS/fetch-alerts.sh")"
echo "$output"
export ALERT_COUNT="${output#count=}"

echo; echo "== build-report.sh =="
IMAGE_SCAN_RESULT="$image_scan_result" "$SCRIPTS/build-report.sh"

echo; echo "== build-slack-summary.sh =="
IMAGE_SCAN_RESULT="$image_scan_result" ALERTS_OUTCOME=success RUN_URL="https://github.com/$REPO/actions" \
  "$SCRIPTS/build-slack-summary.sh"
echo; echo "-- slack-summary.txt --"; cat slack-summary.txt
