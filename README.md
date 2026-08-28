# laa-data-claims-parent

Parent repository with common docker compose to help run multiple child
services locally within docker for a more lightweight development experience.

This will clone the following repositories:

- [laa-amend-a-claim](https://github.com/ministryofjustice/laa-amend-a-claim)
- [laa-data-claims-api](https://github.com/ministryofjustice/laa-data-claims-api)
- [laa-data-claims-event-service](https://github.com/ministryofjustice/laa-data-claims-event-service)
- [laa-data-claims-notify-service](https://github.com/ministryofjustice/laa-data-claims-notify-service)
- [laa-submit-a-bulk-claim](https://github.com/ministryofjustice/laa-submit-a-bulk-claim)

## Setup (via already cloned child repositories)

If you have already got the various child repositories cloned, you can just copy the
`docker-compose.yml` file
to the root of the three repositories in the following file structure.

You will also need to make sure you have a file called `.env` in the root of this repository.
There is an example file called `env_example` within the repo with what variables you need to set.
You can also ask another developer for the values within data stewardship.

Your folder structure should look like this:

```text
.
├── docker-compose.yml
├── .env
└── laa-amend-a-claim/
├── laa-data-claims-api/
├── laa-data-claims-event-service/
└── laa-data-claims-notify-service/
└── laa-submit-a-bulk-claim/
```

## Setup (via fresh clone)

If you wish to use this repository as a base to clone other repositories, run the following command
to get the latest versions of the child repositories:

```sh
# Initialize and fetch submodules (for new clones)
git submodule update --init --remote --recursive
```

You will also need to make sure you have a file called `.env` in the root of this repository.
There is an example file called `env_example` within the repo with what variables you need to set.
You can also ask another developer for the values within data stewardship.

## Running child services via docker

Using the `docker-compose.yml` file in the root of this repository, you can start all child services
via docker:

```sh
docker-compose up -d claims-api event-service sabc-ui amend-ui --build
```

Or to tear everything down and start it all again each time:

```sh
docker-compose down -v; docker-compose up -d claims-api event-service sabc-ui amend-ui --build
```

In further runs, if you don't wish to build the services, you can omit the `--build` flag to 
save time.

Note the four service names:

- `amend-ui`
- `claims-api`
- `event-service`
- `notify-service`
- `sabc-ui`

If you wish to only run a subset of these child services, simply omit the service you don't
want to run via docker. In this example, I want the claims API and event service, but I will
be running the UI via IntelliJ:

```sh
docker-compose up -d claims-api event-service --build
```

## Task runner

This repository uses [Task](https://taskfile.dev/) to provide shortcuts for common operations
across the child services. Install Task by following the
[installation guide](https://taskfile.dev/installation/), then list the available commands with:

```sh
task
```

Common tasks include:

```sh
# Assemble every child service
task assemble:all

# Assemble one child service
task assemble:api

# Start Submit a Bulk Claim and its dependencies
task up:submit

# Start Amend a Claim and its dependencies
task up:amend

# Stop all services and remove their volumes
task down
```

Run `task --list-all` to see each task and its description.

## Snyk container scanning

The root [`snyk-container-scan.sh`](snyk-container-scan.sh) script builds a child service's JAR and
Docker image, then scans the image for operating system and application dependency vulnerabilities
with `snyk container test`.

### Prerequisites

- Docker
- [Snyk CLI](https://docs.snyk.io/developer-tools/snyk-cli/install-or-update-the-snyk-cli)
- Snyk authentication using `snyk auth`, `SNYK_TOKEN`, or both `SNYK_CLIENT_ID` and
	`SNYK_CLIENT_SECRET`

Scan one service using its Task target:

```sh
task snyk:container:claims-api
task snyk:container:event-service
task snyk:container:notify
task snyk:container:amend
task snyk:container:submit
task snyk:container:oidc-mock
```

To build and scan every service sequentially, run:

```sh
task snyk:container:all
```

The default severity threshold is `high`. Pass script options or additional Snyk CLI arguments
after `--`:

```sh
# Only report critical vulnerabilities
task snyk:container:notify -- --severity-threshold critical

# Scan an image that has already been built
task snyk:container:notify -- --skip-build

# Request JSON output from Snyk
task snyk:container:notify -- --skip-build -- --json
```

Set `SNYK_SEVERITY_THRESHOLD` to change the default threshold for all scans. Each scan uses the
selected child repository's `.snyk` policy when one exists; the OIDC mock server currently has no
policy file.

Run `./snyk-container-scan.sh --help` for direct script usage and all supported options.

## Exposed ports

Given there being multiple services, ports are named based on the service and what part of that
service is exposed. The last two digits identify the service:

| Service                | Suffix |
|------------------------|--------|
| Amend a Claim          | `90`   |
| Claims API             | `80`   |
| Event Service          | `81`   |
| Notify Service         | `83`   |
| Submit a Bulk Claim    | `82`   |

Each service exposes the following ports, where `XX` is the service suffix above:

| Purpose      | Port   |
|--------------|--------|
| App          | `80XX` |
| Actuator     | `81XX` |
| Remote JVM   | `50XX` |

So for example, the Claims API (`80`) exposes:

| Purpose      | Port   |
|--------------|--------|
| App          | `8080` |
| Actuator     | `8180` |
| Remote JVM   | `5080` |

> **Note:** The Event Service and Notify Service does not expose an app port.