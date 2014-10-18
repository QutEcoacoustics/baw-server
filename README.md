# Baw::Workers

Bioacoustics Workbench workers.

[![Build Status](https://travis-ci.org/QutBioacoustics/baw-workers.png?branch=master)](https://travis-ci.org/QutBioacoustics/baw-workers)
[![Dependency Status](https://gemnasium.com/QutBioacoustics/baw-workers.png)](https://gemnasium.com/QutBioacoustics/baw-workers)
[![Code Climate](https://codeclimate.com/github/QutBioacoustics/baw-workers.png)](https://codeclimate.com/github/QutBioacoustics/baw-workers)
[![Test Coverage](https://codeclimate.com/github/QutBioacoustics/baw-workers/badges/coverage.svg)](https://codeclimate.com/github/QutBioacoustics/baw-workers)
[![Coverage Status](https://coveralls.io/repos/QutBioacoustics/baw-workers/badge.png)](https://coveralls.io/r/QutBioacoustics/baw-workers)
[![Inline docs](http://inch-ci.org/github/QutBioacoustics/baw-workers.png?branch=master)](http://inch-ci.org/github/QutBioacoustics/baw-workers)

[Rubydoc](http://rubydoc.info/github/QutBioacoustics/baw-workers/frames) is available.

Workers that can process various long-running or intensive tasks.

## Installation

Add this line to your application's Gemfile:

    gem 'baw-workers', git: 'https://github.com/QutBioacoustics/baw-workers.git'

or clone the repository to the current directory:

    git clone https://github.com/QutBioacoustics/baw-workers.git

And then execute:

    $ bundle install

## Actions


This project provides four actions. Actions are classes that implement a potentially long-running process.
A `Job` is an instance of an `Action`.

Actions can get input from the settings file when run standalone, or from Resque jobs when running as a Resque worker.

A resque worker can be set to process any queue by changing `queues_to_process` in the settings file. 
The jobs in a queue specify the action that will be used to process that job.
A standard Resque worker can be started using:

    bundle exec rake baw:worker:run['path_to_settings_file']

### Analysis

Runs analysers over audio files. This action analyses an entire single audio file.

Resque jobs can be enqueued from [baw-server](https://github.com/QutBioacoustics/baw-server).

A directory can be analysed manually by setting the `analyser_id` and `to_do_path` for the analysis action in the settings file.
Files can then be processed standalone:

    bundle exec rake baw:action:analysis:standalone:from_files['path_to_settings_file']

or enqueued using Resque and processed later by a standard Resque worker:

    bundle exec rake baw:action:analysis:resque:from_files['path_to_settings_file'] 

### Audio Check

Runs checks on original audio recording files. This action checks an entire single audio file.

Gets audio files to check from a csv file in a specific format by specifying the setting `to_do_csv_path` 
or enumerates existing files in a directory by specifying the setting `to_do_folder_path`. 

The files can be processed standalone:

    bundle exec rake baw:action:audio_check:standalone:from_csv['path_to_settings_file'] 
    bundle exec rake baw:action:audio_check:standalone:from_files['path_to_settings_file'] 

or enqueued using Resque and processed later by a standard Resque worker:

    bundle exec rake baw:action:audio_check:resque:from_csv['path_to_settings_file'] 
    bundle exec rake baw:action:audio_check:resque:from_files['path_to_settings_file'] 

### Harvest

Harvests audio files to be accessible by [baw-server](https://github.com/QutBioacoustics/baw-server) 
via the file storage system.

Audio files can be harvested by specifying the setting `to_do_path`. 
The `progressive_upload_directory` is treated specially: files in that directory do not require a config file as long as
their file names are in a recognised format.

Audio files can be processed standalone:

    bundle exec rake baw:action:harvest:standalone:from_files['path_to_settings_file'] 

or enqueued using Resque and processed later by a standard Resque worker:

    bundle exec rake baw:action:harvest:resque:from_files['path_to_settings_file'] 

### Media

Cuts audio files and generates spectrograms.

Resque jobs can be enqueued on demand from [baw-server](https://github.com/QutBioacoustics/baw-server)
and processed later by a Resque worker.

## File Storage

There are classes for working with file storage paths:

 - original audio files
 - caches for 
    - cut audio
    - generated spectrograms
    - analysis results. 

## Contributing

1. Fork it (https://github.com/QutBioacoustics/baw-workers)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
