# baw-server

The bioacoustic workbench server. Manages the structure and audio data. Provides an API for clients access.

[![Build Status](https://travis-ci.org/QutBioacoustics/baw-server.png?branch=master)](https://travis-ci.org/QutBioacoustics/baw-server)
[![Dependency Status](https://gemnasium.com/QutBioacoustics/baw-server.png)](https://gemnasium.com/QutBioacoustics/baw-server)
[![Code Climate](https://codeclimate.com/github/QutBioacoustics/baw-server.png)](https://codeclimate.com/github/QutBioacoustics/baw-server)
[![Test Coverage](https://codeclimate.com/github/QutBioacoustics/baw-server/coverage.png)](https://codeclimate.com/github/QutBioacoustics/baw-server)
[![Coverage Status](https://coveralls.io/repos/QutBioacoustics/baw-server/badge.png)](https://coveralls.io/r/QutBioacoustics/baw-server)
[![Inline docs](http://inch-ci.org/github/QutBioacoustics/baw-server.png?branch=master)](http://inch-ci.org/github/QutBioacoustics/baw-server)

[Rubydoc](http://rubydoc.info/github/QutBioacoustics/baw-server/frames) is available.

## Install instructions

Change directory to your cloned directory and run

	$ bin/setup

This will do some basic setup and give some information about what to do next.
To see the setup instructions again, look at the file `bin/setup`. 

To run the server you'll need to create some configuration files.
Create a `/config/settings/development.yml` and `/config/settings/test.yml` based on `/config/settings/default.yml`.

## Dependencies

Audio processing and other long-running tasks are performed using [baw-workers](https://github.com/QutBioacoustics/baw-workers).

You may need to install baw-workers' dependencies.

## Development and Testing

First create the `/config/settings/test.yml` settings file. 
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

## Deploying

We deploy using [Capistrano](https://github.com/capistrano/capistrano). See the `bin/setup` script for more information.

## Licence
Apache License, Version 2.0
