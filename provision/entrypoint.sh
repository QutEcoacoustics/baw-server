#!/bin/bash

#
# We want to run this command during development to make sure the system deps
# are installed
#

function log() {
    echo -e "\n==> $1"
}

set -e
set -x

echo "Booting baw-server container. "

log "Debug container permissions"
ls -la

echo "$(id)"
echo "RAILS_ENV=$RAILS_ENV"

log "== Checking bundler install"
bundle check || bundle install

if [[ "$MIGRATE_DB" = "true" ]]; then
    log "Checking database"
    /home/baw_web/baw-server/bin/rake baw:db_prepare
else
    log "MIGRATE_DB is '$MIGRATE_DB' (not 'true'), skipping migration"
fi

if [[ "$GENERATE_ASSETS" = "true" ]]; then
    if find /home/baw_web/baw-server/public/assets/ -name '*manifest*json' -printf 1 -quit -type f | grep -q 1; then
        log "Assets already generated, skipping generation"
    else
        log "Generating assets"

        /home/baw_web/baw-server/bin/rails assets:precompile
    fi
else
    log "GENERATE_ASSETS is '$GENERATE_ASSETS' (not 'true'), skipping generation"
fi

log "Executing original command '" "${@}" "'"
exec "${@}"
