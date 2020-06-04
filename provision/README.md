# Provision

Scripts in this folder should relate to building or setting up containers
or environments for this application.

## Flavours

There are two container flavours:

- Web (runs the web server)
- Worker (runs a worker)

## Workflows

### Docker-compose (and GitHub Actions)

1. docker-compose up
2. (other dependent containers are started)
3. The <mark>worker</mark> containers are started
    1. Entrypoint is set to `entrypoint.sh`
    2. Database migration is not run
4. The <mark>web</mark> container is started
    1. Entrypoint is set to `entrypoint.sh`
    2. Database migration is run (`migrate.sh`) for the `development` environment
    3. Command is run from docker-compose: `bundle exec rails server`

### VSCode

1. VSCode runs its own docker compose command:

  `docker-compose -f docker-compose.yml -f .devcontainer/docker-compose.yml`

2. (other dependent containers are started)
3. The <mark>worker</mark> containers are started
    1. Entrypoint is set to `entrypoint.sh`
    2. Database migration is not run
4. The <mark>web</mark> container is started
    1. Entrypoint is set to `entrypoint.sh`
    2. Database migration is run (`migrate.sh`)
    3. VSCode **overrides** docker-compose command with: `sleep infinity`
    4. VSCode runs the _postCreationCommand_ which we've configured to run `dev_setup.sh`. Dev setup runs:
        1. The `migrate.sh` script for the `development` environment
        2. The `migrate.sh` script for the `test` environment

### Production

Everything is different.

- Entrypoint is `bundle exec`
- Default command is `passenger start`
- Out of band processes call `migrate.sh` when needed
