#!/bin/bash


echo -e "\n\n== Checking database status ==\n\n"

# this is a custom rake task in /lib/tasks/database_status.rake
bundle exec rake db:status

RESULT=$?
echo -e "\n\n== Database status is $RESULT ==\n\n"

if [[ $RESULT == 0 ]]; then
    echo -e "\n\n== Database is ready ==\n\n"
elif [[ $RESULT == 1 ]]; then
    echo "\n\n== Database does not exist, running db:setup. ==\n\n"
    bundle exec rake db:setup db:migrate RAILS_ENV=development
    bundle exec rake db:setup db:migrate RAILS_ENV=test
elif [[ $RESULT == 2 ]]; then
    echo -e "\n\n== Database needs to be migrated, running db:migrate. ==\n\n"
    bundle exec rake db:migrate RAILS_ENV=development
    bundle exec rake db:migrate RAILS_ENV=development
else
    echo -e "\n\n== Unknown error occurred executing db:status '$RESULT'. ==\n\n"
fi

echo -e "\n\n== Executing original command '$@' ==\n\n"
exec "$@"

