#!/bin/bash

if [[ -z "$RAILS_ENV" ]]; then
    echo "Must provide RAILS_ENV environment variable must be set!" 1>&2
    exit 1
fi

echo -e "\n\n== Checking database status ==\n\n"

# this is a custom rake task in /lib/tasks/database_status.rake
bundle exec rake db:status

RESULT=$?
echo -e "\n\n== Database status is $RESULT ==\n\n"

if [[ $RESULT == 0 ]]; then
    echo -e "\n\n== Database is ready ==\n\n"
elif [[ $RESULT == 1 ]]; then
    echo "\n\n== Database does not exist, running db:setup. ==\n\n"
    bundle exec rake db:setup db:migrate db:seed || exit 1
elif [[ $RESULT == 2 ]]; then
    echo -e "\n\n== Database needs to be migrated, running db:migrate. ==\n\n"
    bundle exec rake db:migrate db:seed || exit 1
else
    echo -e "\n\n== Unknown error occurred executing db:status '$RESULT'. ==\n\n"
    exit 1
fi
