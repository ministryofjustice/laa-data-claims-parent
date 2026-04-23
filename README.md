# laa-data-claims-parent

Parent repository with common docker compose to help run multiple child
services locally within docker for a more lightweight development experience.

This will clone the following repositories:

- [laa-data-claims-api](https://github.com/ministryofjustice/laa-data-claims-api)
- [laa-data-claims-event-service](https://github.com/ministryofjustice/laa-data-claims-event-service)
- [laa-submit-a-bulk-claim](https://github.com/ministryofjustice/laa-submit-a-bulk-claim)
- [laa-amend-a-claim](https://github.com/ministryofjustice/laa-amend-a-claim)

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
├── laa-data-claims-api/
├── laa-data-claims-event-service/
└── laa-submit-a-bulk-claim/
└── laa-amend-a-claim/
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

- `claims-api`
- `event-service`
- `sabc-ui`
- `amend-ui`

If you wish to only run a subset of these child services, simply omit the service you don't
want to run via docker. In this example, I want the claims API and event service, but I will
be running the UI via IntelliJ:

```sh
docker-compose up -d claims-api event-service --build
```