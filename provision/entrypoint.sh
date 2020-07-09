#!/bin/bash

#
# We want to run this command during development to make sure the system deps
# are installed
#

set -e

# echo -e "\n\n== Debug container permissions  ==\n\n"

# whoami
# ls -la

echo -e "\n\n== Checking bundler install ==\n\n"

bundle check || bundle install


/home/baw_web/baw-server/bin/rake baw:db_prepare


echo -e "\n\n== Executing original command '$@' ==\n\n"
exec "$@"

