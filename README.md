# baw-server

The bioacoustic workbench server. Manages the structure and audio data. Provides an API for client access.

[![Dependency Status](https://gemnasium.com/QutBioacoustics/baw-server.png)](https://gemnasium.com/QutBioacoustics/baw-server)
[![Documentation](https://img.shields.io/badge/docs-rdoc.info-blue.svg)](http://www.rubydoc.info/github/QutBioacoustics/baw-server)
[![Code Climate](https://codeclimate.com/github/QutBioacoustics/baw-server/badges/gpa.svg)](https://codeclimate.com/github/QutBioacoustics/baw-server)
[![Test Coverage](https://codeclimate.com/github/QutBioacoustics/baw-server/badges/coverage.svg)](https://codeclimate.com/github/QutBioacoustics/baw-server/coverage)

## Branches

### master (latest release)

[![Build Status](https://travis-ci.org/QutBioacoustics/baw-server.png?branch=master)](https://travis-ci.org/QutBioacoustics/baw-server)
[![Documentation Status](http://inch-ci.org/github/QutBioacoustics/baw-server.png?branch=master)](http://inch-ci.org/github/QutBioacoustics/baw-server)
[![Coverage Status](https://coveralls.io/repos/github/QutBioacoustics/baw-server/badge.svg?branch=master)](https://coveralls.io/github/QutBioacoustics/baw-server?branch=master)

### develop (most recent commits)

[![Build Status](https://travis-ci.org/QutBioacoustics/baw-server.png?branch=develop)](https://travis-ci.org/QutBioacoustics/baw-server)
[![Documentation Status](http://inch-ci.org/github/QutBioacoustics/baw-server.png?branch=develop)](http://inch-ci.org/github/QutBioacoustics/baw-server)
[![Coverage Status](https://coveralls.io/repos/github/QutBioacoustics/baw-server/badge.svg?branch=develop)](https://coveralls.io/github/QutBioacoustics/baw-server?branch=develop)

## Dependencies

This project's dev environment is managed by [Vagrant](https://www.vagrantup.com/downloads.html) and Ansible. Ensure Vagrant `v1.8.1` or greater is installed on your dev machine.

Audio processing and other long-running tasks are performed using [baw-workers](https://github.com/QutBioacoustics/baw-workers).

## Contributing

See the [git-flow.md](./git-flow.md) document for guidelines on making changes.

## Environment Setup

Clone this repo, then change directory to your cloned directory and on your **host** machine run

	$ vagrant up

This will prepare a complete development environment. To see what is involved in the setup, look at the  [`provision/vagrant.yml`](provision/vagrant.yml) and [`bin/setup`](bin/setup) files.

### Reprovision

To reprovision your environment, on your **host** machine run:

    $ vagrant provision

or

    $ vagrant up --provision

### Destroy your environment

If you wish to remove the baw-server development environment completely,  on your **host** machine run:

    $ vagrant destroy

This will **completely delete the development VM**.

## Development

Start by running, on your **host** machine:

    $ vagrant up
    $ vagrant ssh
	# in the dev machine
	$ cd ~/baw-server

Sometimes you may need to update dependencies first:

    ~/baw-server$ bundle install

End by suspending the virtual machine:

    # exit the ssh session
	$ exit
	# on the host machine:
    $ vagrant halt

When running the server in `development` or `test` modes, these configuration files will be used:

 - `/config/settings/development.yml`
 - `/config/settings/test.yml`

They are based on files based on `/config/settings/default.yml`.

### Web Server

To start the development server

    $ thin start

### Tests
The tests are run using Guard:

    $ bundle exec guard
    $ [1] guard(main)>

Press enter to execute all tests. Guard will monitor for changes and the relevant tests will be run as files are modified.

Tests can also be run with a specified seed using rspec:

    $ rspec --seed <number>

## Documentation

Documentation can be generated from tests using [rspec_api_documentation](https://github.com/zipmark/rspec_api_documentation):

    $ bin/rake docs:generate GENERATE_DOC=true

## Other commands
These commands should be executed automatically but are listed because they are helpful to know.


- Create the test database: `bin/rake db:create RAILS_ENV=test`
- Then migrate and seed the test database: `bin/rake db:migrate db:seed RAILS_ENV=test`
- Prepare the local development database:`bin/rake db:setup RAILS_ENV=development`
- Run rspec tests: `bin/rspec`
- Generate API documentation: `bin/rake docs:generate GENERATE_DOC=true`


## Production setup and deploying

Create production settings file `config/settings/production.yml` based on `config/settings/default.yml`.  
Create staging settings file `config/settings/staging.yml` based on `config/settings/default.yml`.

We deploy using Ansible (and in particular [Ansistrano](http://ansistrano.com/)).
Our Ansible playbooks are currently private but we have plans to release them.

If you want to use background workers, you'll need to set up [Redis](http://redis.io/).

## Credits

This project was originally created and maintained by [@cofiem](https://github.com/cofiem) - all the amazing things it does are a credit to them.

## Licence
Apache License, Version 2.0
