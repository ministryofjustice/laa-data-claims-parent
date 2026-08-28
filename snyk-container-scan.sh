#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="${SCRIPT_DIR}"

service=""
service_dir=""
image_name=""
severity_threshold="${SNYK_SEVERITY_THRESHOLD:-high}"
skip_build=0
extra_snyk_args=()

usage() {
  cat <<'EOF'
Usage: ./snyk-container-scan.sh <service> [options] [-- <extra snyk args>]

Builds a service image locally and runs a Snyk container scan.

Services:
  claims-api | event-service | notify | amend | submit | oidc-mock

Options:
  --image-name <name>            Docker image name to build and scan
                                 (default: <service-directory>:local)
  --severity-threshold <level>   low | medium | high | critical
                                 (default: high, or SNYK_SEVERITY_THRESHOLD)
  --skip-build                   Scan an existing local image without rebuilding it
  -h, --help                     Show this help text

Authentication:
  The script supports the same Snyk credentials used in CI when exported locally:
    SNYK_TOKEN
    SNYK_CLIENT_ID + SNYK_CLIENT_SECRET

Examples:
  ./snyk-container-scan.sh notify
  ./snyk-container-scan.sh claims-api --severity-threshold critical
  ./snyk-container-scan.sh oidc-mock --skip-build -- --json
EOF
}

configure_service() {
  case "$1" in
    claims-api)
      service_dir="laa-data-claims-api"
      ;;
    event-service)
      service_dir="laa-data-claims-event-service"
      ;;
    notify)
      service_dir="laa-data-claims-notify-service"
      ;;
    amend)
      service_dir="laa-amend-a-claim"
      ;;
    submit)
      service_dir="laa-submit-a-bulk-claim"
      ;;
    oidc-mock)
      service_dir="laa-oidc-mock-server"
      ;;
    *)
      echo "Unknown service: $1" >&2
      usage >&2
      exit 1
      ;;
  esac

  image_name="${service_dir}:local"
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Missing required command: ${command_name}" >&2
    exit 1
  fi
}

authenticate_snyk() {
  if [[ -n "${SNYK_TOKEN:-}" ]]; then
    snyk auth "${SNYK_TOKEN}" >/dev/null
  elif [[ -n "${SNYK_CLIENT_ID:-}" || -n "${SNYK_CLIENT_SECRET:-}" ]]; then
    if [[ -z "${SNYK_CLIENT_ID:-}" || -z "${SNYK_CLIENT_SECRET:-}" ]]; then
      echo "Both SNYK_CLIENT_ID and SNYK_CLIENT_SECRET must be set together." >&2
      exit 1
    fi

    snyk auth --auth-type=oauth \
      --client-id="${SNYK_CLIENT_ID}" \
      --client-secret="${SNYK_CLIENT_SECRET}" >/dev/null
  elif ! snyk whoami >/dev/null 2>&1; then
    echo "Snyk CLI is not authenticated or the saved session has expired." >&2
    echo "Run 'snyk auth' or export SNYK_TOKEN or SNYK_CLIENT_ID and SNYK_CLIENT_SECRET." >&2
    exit 1
  fi

  if ! snyk whoami >/dev/null 2>&1; then
    echo "Snyk authentication failed." >&2
    echo "Re-run 'snyk auth' or refresh SNYK_TOKEN / SNYK_CLIENT_ID / SNYK_CLIENT_SECRET." >&2
    exit 1
  fi
}

run_snyk_container_test() {
  local snyk_args=(
    container test "${image_name}"
    --severity-threshold="${severity_threshold}"
  )

  if [[ -f .snyk ]]; then
    snyk_args+=(--policy-path=.snyk)
  fi

  if [[ "${#extra_snyk_args[@]}" -gt 0 ]]; then
    snyk_args+=("${extra_snyk_args[@]}")
  fi

  snyk "${snyk_args[@]}"
}

while (($# > 0)); do
  case "$1" in
    --image-name)
      image_name="${2:?Missing value for --image-name}"
      shift 2
      ;;
    --severity-threshold)
      severity_threshold="${2:?Missing value for --severity-threshold}"
      shift 2
      ;;
    --skip-build)
      skip_build=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_snyk_args=("$@")
      break
      ;;
    claims-api|event-service|notify|amend|submit|oidc-mock)
      if [[ -n "${service}" ]]; then
        echo "Only one service can be scanned at a time." >&2
        exit 1
      fi
      service="$1"
      configure_service "${service}"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${service}" ]]; then
  echo "A service is required." >&2
  usage >&2
  exit 1
fi

case "${severity_threshold}" in
  low|medium|high|critical) ;;
  *)
    echo "Invalid severity threshold: ${severity_threshold}" >&2
    echo "Expected one of: low, medium, high, critical" >&2
    exit 1
    ;;
esac

require_command docker
require_command snyk

readonly SERVICE_ROOT="${REPO_ROOT}/${service_dir}"

if [[ ! -x "${SERVICE_ROOT}/gradlew" ]]; then
  echo "Gradle wrapper not found or not executable at ${SERVICE_ROOT}/gradlew" >&2
  exit 1
fi

if [[ "${skip_build}" -eq 0 ]]; then
  (
    cd "${SERVICE_ROOT}"
    ./gradlew assemble --build-cache
    docker build --tag "${image_name}" .
  )
fi

authenticate_snyk

(
  cd "${SERVICE_ROOT}"
  run_snyk_container_test
)
