#!/bin/bash

#
# We want to run this command during development to make sure the system deps
# are installed and the database is ready
#

set -e

echo -e "\n\n== Checking bundler install ==\n\n"

bundle check || bundle install --system

echo -e "\n\n== Executing original command '$@' ==\n\n"
exec "$@"

