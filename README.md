# Baw::Workers

Bioacoustics Workbench workers.

[![Build Status](https://travis-ci.org/QutBioacoustics/baw-workers.png?branch=master)](https://travis-ci.org/QutBioacoustics/baw-workers)
[![Dependency Status](https://gemnasium.com/QutBioacoustics/baw-workers.png)](https://gemnasium.com/QutBioacoustics/baw-workers)
[![Code Climate](https://codeclimate.com/github/QutBioacoustics/baw-workers.png)](https://codeclimate.com/github/QutBioacoustics/baw-workers)
[![Test Coverage](https://codeclimate.com/github/QutBioacoustics/baw-workers/badges/coverage.svg)](https://codeclimate.com/github/QutBioacoustics/baw-workers)
[![Coverage Status](https://coveralls.io/repos/QutBioacoustics/baw-workers/badge.png)](https://coveralls.io/r/QutBioacoustics/baw-workers)
[![Inline docs](http://inch-ci.org/github/QutBioacoustics/baw-workers.png?branch=master)](http://inch-ci.org/github/QutBioacoustics/baw-workers)

[Rubydoc](http://rubydoc.info/github/QutBioacoustics/baw-workers/frames) is available.

This project provides workers and file storage. Workers that can process various long-running or intensive tasks. File storage provides helper methods for calculating paths to original and cached files.

## Installation

Add this line to your application's Gemfile:

    gem 'baw-workers', git: 'https://github.com/QutBioacoustics/baw-workers.git'

or clone the repository to the current directory:

    git clone https://github.com/QutBioacoustics/baw-workers.git

And then execute:

    $ bundle install

## File Storage

There are classes for working with file storage paths:

 - original audio files
 - caches for 
    - cut audio
    - generated spectrograms
    - analysis results. 

## Running Workers

A `worker` runs an `action`. Actions are simply a process to follow. Actions can get input from the settings file when run standalone and/or from Resque jobs (when running as a Resque dequeue worker).

Then answer these questions:

 - which environment? (e.g. staging, production, development, test)
 - which worker? (e.g. audio_check, harvester, media, analysis)
 - which processing model? (e.g. standalone, resque)

Based on the answers to these questions

 - pick an existing config file (and check that the settings match the file name),
 - or create a new config file based on an existing one, named in a similar way.

Once you've got your config file, then a worker can be started.
Workers are run using rake tasks. A list of the available rake tasks can be obtained 
by running this command in the `baw-workers` cloned directory or the directory containing your `Gemfile`:

    bundle exec rake -T

There are two steps that a worker can run:

 - preliminary processing (step 1), which can finish by adding a job to a Resque queue or continuing directly to step 2.
 - final processing (step 2), which can start by reserving a job from a Resque queue or directly receiving data from step 1.

There are three ways to run a worker:

 - standalone: this will run steps 1 and 2 sequentially in the same process
 - Resque enqueue: this will run step 1 and enqueue a job using Resque
 - Resque dequeue: this will reserve a job using Resque and run step 2

### Configuration Hints

Some things to check and look out for when creating and modifying worker config files.

#### `settings.resque.queues_to_process`

This setting is only needed when running a Resque dequeue worker. 
It specifies a priority array of the Resque queues to reserve jobs from.
The jobs in a queue specify the action class that will be used to process that job.

#### `settings.resque.connection`

The connection settings are passed directly to Resque to configure the Redis connection.

#### `settings.resque.namespace`

The [Redis namespace](https://github.com/resque/resque). This should usually be left as 'resque'.

#### `settings.resque.background_pid_file`

Specify a `background_pid_file` to have a Resque dequeue worker run in the background.
The `output_log_file` and `error_log_file` settings will only be used when a Resque dequeue worker is running in the background.

#### `settings.actions`

Each action has some settings specific to that action.
An action is the actual processing that job arguments will be used to carry out.
Every action has a `queue` and `dry_run` setting. The `queue` is the name of the queue 


### Examples for running a worker


Replace `'<settings_file>'` with the full path to the settings file to use for the worker.

#### Standalone

    bundle exec rake baw:action:analysis:standalone:from_files['<settings_file>']
    bundle exec rake baw:action:audio_check:standalone:from_csv['<settings_file>']
    bundle exec rake baw:action:harvest:standalone:from_files['<settings_file>']
    # media action can only be run as a Resque dequeue worker
    

#### Resque enqueue

    bundle exec rake baw:action:analysis:resque:from_files['<settings_file>']
    bundle exec rake baw:action:audio_check:resque:from_csv['<settings_file>']
    bundle exec rake baw:action:harvest:resque:from_files['<settings_file>']
    # media action can only be run as a Resque dequeue worker
    
#### Resque dequeue

A Resque dequeue worker can process any queue with any type of job.

    bundle exec rake baw:worker:run['<settings_file>'] 

## Actions

This project provides four actions. Actions are classes that implement a potentially long-running process.

### Analysis

Runs analysers over audio files. This action analyses an entire single audio file.

 1. Resque jobs can be queued from [baw-server](https://github.com/QutBioacoustics/baw-server) and processed later by a Resque dequeue worker.
 1. A directory can be analysed manually by setting the `analyser_id` and `to_do_path` for the analysis action in the settings file.

### Audio Check

Runs checks on original audio recording files. This action checks an entire single audio file.

 - Gets audio files to check from a csv file in a specific format by specifying the setting `to_do_csv_path`.

### Harvest

Harvests audio files to be accessible by [baw-server](https://github.com/QutBioacoustics/baw-server) via the file storage system. 

 - The harvester will recognise valid audio files in two ways: file name in a recognised format, and optionally a directory config file. Depending on the file name format used, a directory config file may or may not be required.
 - Audio files can be harvested by specifying the setting `to_do_path` and the `config_file_name`.

### Media

Cuts audio files and generates spectrograms.

 -  Resque jobs can be queued on demand from [baw-server](https://github.com/QutBioacoustics/baw-server)
and processed later by a Resque dequeue worker.

## Contributing

1. Fork it (https://github.com/QutBioacoustics/baw-workers)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
