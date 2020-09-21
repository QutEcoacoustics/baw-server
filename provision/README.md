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
    2. Database migration is run (`rake baw:db_prepare`) for the `development` and `test` environments
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
    2. Database migration is run (`rake baw:db_prepare`) for the `development` and `test` environments
    3. VSCode **overrides** docker-compose command with: `sleep infinity`

### Production

Some things are different.

- Entrypoint is the same.
- A single pre-deploy instance of the container is run to call `rake baw:db_prepare`
  (so not every application booting tries to migrate at once)
- Default command is `passenger start`

