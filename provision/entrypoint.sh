#!/bin/bash

#
# We want to run this command during development to make sure the system deps
# are installed
#

set -e

# echo -e "\n\n== Debug container permissions  ==\n\n"

# whoami
# ls -la

echo -e "\n\n== RAILS_ENV=$RAILS_ENV ==\n\n"

if [[ "$RAILS_ENV" == "development" ]] || [[ "$RAILS_ENV" == "test" ]]
then
    echo -e "\n\n== Set bundle to install dev and test groups ==\n\n"
    bundle config unset without
fi

echo -e "\n\n== Checking bundler install ==\n\n"

bundle check || bundle install

if [[ "$RAILS_ENV" == "devlopment" ]]
then
    echo -e "\n\n== Installing solargraph docs ==\n\n"
    # install docs for dev work
    solargraph download-core && solargraph bundle
fi

/home/baw_web/baw-server/bin/rake baw:db_prepare


echo -e "\n\n== Executing original command '$@' ==\n\n"
exec "$@"

