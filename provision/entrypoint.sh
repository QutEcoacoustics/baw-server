#!/bin/bash

#
# We want to run this command during development to make sure the system deps
# are installed
#

set -e

echo -e "\n\n== Debug container permissions  ==\n\n"

whoami
ls -la

echo -e "\n\n== Checking bundler install ==\n\n"

bundle check || bundle install --system

if [[ -z "${MIGRATE_DB+x}" || "${MIGRATE_DB,,}" == "false" ]]; then
  echo -e "\n\n== Skipping database status checks ==\n\n"
else
  /home/baw_web/baw-server/provision/migrate.sh
fi

echo -e "\n\n== Executing original command '$@' ==\n\n"
exec "$@"

