#!/bin/bash

#
# We want to run this command during development to m
#

set -e

echo -e "\n\n== Checking bundler install ==\n\n"

bundle check || bundle install --system --binstubs
echo "`pwd`"
$(dirname "$0")/migrate.sh

echo -e "\n\n== Executing original command '$@' ==\n\n"
exec "$@"

