#!/bin/bash

#
# We want to run this command during development to make sure the system deps
# are installed
#

set -e

echo -e "\n== Debug container permissions  ==\n"
ls -la

echo "==> Booting baw-server container. "
echo "==> $(id)"
echo "==> RAILS_ENV=$RAILS_ENV"

echo -e "== Checking bundler install ==\n"

bundle check || bundle install

if [[ "$RAILS_ENV" == "development" ]]
then
    # reset passenger file
    cp ./provision/Passengerfile.development.json /home/baw_web/baw-server/Passengerfile.json
fi

echo -e "\n== Checking database ==\n"
/home/baw_web/baw-server/bin/rake baw:db_prepare

if [[ "$GENERATE_ASSETS" = "true" ]]
then
    if find /home/baw_web/baw-server/public/assets/ -name '*manifest*json' -printf 1 -quit -type f| grep -q 1
    then
        echo -e "\n== Assets already generated, skipping generation =="
    else
        echo -e "\n== Generating assets ==\n"

        /home/baw_web/baw-server/bin/rails assets:precompile
    fi
else
    echo -e "\n== GENERATE_ASSETS is '$GENERATE_ASSETS' (not 'true'), skipping generation =="
fi

echo -e "\n== Executing original command '$@' ==\n"
exec "$@"

