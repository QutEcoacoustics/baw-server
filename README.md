# baw-server

The bioacoustic workbench server. Manages the structure and audio data. Provides an API for client access.

[![Build Status](https://travis-ci.org/QutBioacoustics/baw-server.png?branch=master)](https://travis-ci.org/QutBioacoustics/baw-server)
[![Dependency Status](https://gemnasium.com/QutBioacoustics/baw-server.png)](https://gemnasium.com/QutBioacoustics/baw-server)
[![Code Climate](https://codeclimate.com/github/QutBioacoustics/baw-server.png)](https://codeclimate.com/github/QutBioacoustics/baw-server)
[![Test Coverage](https://codeclimate.com/github/QutBioacoustics/baw-server/badges/coverage.svg)](https://codeclimate.com/github/QutBioacoustics/baw-server)
[![Documentation Status](http://inch-ci.org/github/QutBioacoustics/baw-server.png?branch=master)](http://inch-ci.org/github/QutBioacoustics/baw-server)
[![Documentation](https://img.shields.io/badge/docs-rdoc.info-blue.svg)](http://www.rubydoc.info/github/QutBioacoustics/baw-server)

## Dependencies

Audio processing and other long-running tasks are performed using [baw-workers](https://github.com/QutBioacoustics/baw-workers).

You may need to install baw-workers' dependencies.

## Development and Testing

Clone this repo, then change directory to your cloned directory and run

	$ bin/setup

This will do some basic setup and give some information about what to do next.

To see the setup instructions again, look at the file [`bin/setup`](bin/setup). 

To run the server you'll need to create some configuration files.

Create two configuration files based on `/config/settings/default.yml`:

 - `/config/settings/development.yml`
 - `/config/settings/test.yml`

Then create the test database using `rake db:create RAILS_ENV=test`.
Then migrate and seed the test database using `rake db:migrate db:seed RAILS_ENV=test`.

The tests are run using Guard:

    $ bundle exec guard
    $ [1] guard(main)>

Press enter to execute all tests. Guard will monitor for changes and the relevant tests will be run as files are modified.

Tests can also be run with a specified seed using rspec:

    $ rspec --seed <number>

Documentation can be generated from tests using [rspec_api_documentation](https://github.com/zipmark/rspec_api_documentation):

    $ bin/rake docs:generate GENERATE_DOC=true

## Production setup and deploying

See the `bin/setup` script for more information.

We deploy Ansible (and in particular [Ansistrano/](http://ansistrano.com/)).
Ansistrano playbooks are currently private but we have plans to release them.

If you want to use background workers, you'll need to set up [Redis](http://redis.io/).

## Licence
Apache License, Version 2.0
