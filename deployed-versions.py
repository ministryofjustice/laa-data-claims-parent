#!/usr/bin/env python3
"""Show which commit each environment is running, and how far behind main it is.

Reads the image tag from each deployment via kubectl, resolves it to a commit in
the local submodule, then lists the main commits that environment is missing.

Usage: ./deployed-versions.py
"""

import json
import shlex
import subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent

# (friendly name, submodule dir, image tag prefix, [(env, namespace, deployment)])
SERVICES = [
    (
        "Submit a Bulk Claim",
        "laa-submit-a-bulk-claim",
        "submit-a-bulk-claim-",
        [
            ("UAT", "laa-submit-a-bulk-claim-uat", "uat-submit-a-bulk-claim"),
            ("STAGING", "laa-submit-a-bulk-claim-staging", "stg-submit-a-bulk-claim"),
            ("PROD", "laa-submit-a-bulk-claim-prod", "prod-submit-a-bulk-claim"),
        ],
    ),
    (
        "Amend a Claim",
        "laa-amend-a-claim",
        "",
        [
            ("UAT", "laa-amend-a-claim-uat", "laa-amend-a-claim"),
            ("STAGING", "laa-amend-a-claim-staging", "laa-amend-a-claim"),
            ("PROD", "laa-amend-a-claim-production", "laa-amend-a-claim"),
        ],
    ),
    (
        "Notify Service",
        "laa-data-claims-notify-service",
        "laa-notify-service-",
        [
            ("UAT", "laa-data-claims-notify-service-uat", "uat-laa-data-claims-notify-service"),
            ("STAGING", "laa-data-claims-notify-service-staging", "stg-laa-data-claims-notify-service"),
            ("PROD", "laa-data-claims-notify-service-prod", "prod-laa-data-claims-notify-service"),
        ],
    ),
]

# Above this many missing commits, just say "more than LIMIT" instead of listing them
LIMIT = 50


def run(cmd, cwd=None):
    result = subprocess.run(shlex.split(cmd), cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"{cmd} exited {result.returncode}")
    return result.stdout.strip()


def deployed_tag(namespace, deployment):
    """Return (image tag, last rollout time) for a deployment."""
    deploy = json.loads(run(f"kubectl get deploy {deployment} -n {namespace} -o json"))
    image = deploy["spec"]["template"]["spec"]["containers"][0]["image"]
    updated = next(
        (c.get("lastUpdateTime", "") for c in deploy.get("status", {}).get("conditions", [])
         if c["type"] == "Progressing"),
        "",
    )
    if updated:
        updated = datetime.fromisoformat(updated.replace("Z", "+00:00")).astimezone().strftime("%Y-%m-%d %H:%M %Z")
    return image.rsplit(":", 1)[-1], updated


def report(name, subdir, prefix, envs):
    repo = ROOT / subdir

    run("git fetch --quiet origin main", cwd=repo)
    main = run("git rev-parse origin/main", cwd=repo)

    print(f"\n{name}  (origin/main @ {main[:7]})")
    print("-" * 60)

    with ThreadPoolExecutor() as pool:
        lookups = list(pool.map(lambda e: _safe(deployed_tag, e[1], e[2]), envs))

    for (env, namespace, _), (result, error) in zip(envs, lookups):
        if error:
            print(f"  {env:<8} kubectl failed ({namespace}): {error}")
            continue
        tag, updated = result
        sha = tag.removeprefix(prefix)
        when = f"deployed {updated or 'unknown'}"
        log, error = _safe(run, f"git log -{LIMIT + 1} --format='%h %s' {sha}..{main}", repo)
        if error:
            print(f"  {env:<8} {sha[:7]}  {when}  git log failed: {error}")
            continue
        missing = log.splitlines()

        if len(missing) > LIMIT:
            status = f"behind main by more than {LIMIT}"
        elif missing:
            status = f"behind main by {len(missing)}"
        else:
            status = "up to date with main"
        print(f"  {env:<8} {sha[:7]}  {when}  {status}")
        if len(missing) <= LIMIT:
            for line in missing:
                print(f"             - {line}")


def _safe(fn, *args):
    try:
        return fn(*args), None
    except Exception as e:  # report and carry on with other envs
        return None, e


def main():
    for service in SERVICES:
        report(*service)
    print()


if __name__ == "__main__":
    main()
