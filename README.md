# baw-server

The bioacoustic workbench server. Manages the structure and audio data. Provides an API for clients access.

[![Dependency Status](https://gemnasium.com/QutBioacoustics/baw-server.png)](https://gemnasium.com/QutBioacoustics/baw-server)
[![Code Climate](https://codeclimate.com/github/QutBioacoustics/baw-server.png)](https://codeclimate.com/github/QutBioacoustics/baw-server)


## Install instructions

Change directory to your cloned directory and then

	$ bundle install
	$ bundle update

To run the server you'll need to create some configuration files.
Create a `/config/settings/development.yml` and `/config/settings/test.yml` based on `/config/settings/default.yml`.

You may need to install some additional tools for working with audio and images.

 - [ImageMagick](http://www.imagemagick.org/) is used by [paperclip](https://github.com/thoughtbot/paperclip).
    - Set the path to the directory containing `convert.exe` in the settings file(s) at `Settings.paths.image_magick_dir` and in `/lib/modules/spectrogram.rb`.
 - [WavPack](http://www.wavpack.com/) is used to expand compressed `.wv` files.
    - Set the path to `wvunpack.exe` in `/lib/modules/audio.rb`.
 - [SoX](http://sox.sourceforge.net/) is used to create spectrograms and resample audio.
    - Set the path to `sox.exe` in `/lib/modules/audio.rb` and `/lib/modules/spectrogram.rb`.
 - [shnTool](http://www.etree.org/shnutils/shntool/) is a tool for quickly segmenting large `.wav` files.
    - It is not currently used, but may be in the future.
 - [mp3splt](http://mp3splt.sourceforge.net/mp3splt_page/home.php) is a tool for quickly segmenting large `.mp3` files.
    - Set the path to `mp3splt.exe` in `/lib/modules/audio.rb`.
 - [ffmpeg](http://www.ffmpeg.org/) is used for audio conversion and gathering audio file information.
    - Set the path to `ffmpeg.exe` and `ffprobe.exe` in `/lib/modules/audio.rb`.

## Testing

First create the `/config/settings/test.yml` settings file. 
Then create the test databas (you may need to use `rake db:create RAILS_ENV=test`). 
Then migrate and seed the test databse using `rake db:migrate db:seed RAILS_ENV=test`.

The tests are run using Guard:

    $ bundle exec guard
    $ [1] guard(main)>

Press enter to execute all tests. Guard will monitor for changes and the relevant tests will be run as files are saved.

Tests can also be run with a specified seed using rspec:

    $ rspec --seed <number>


Documentation can be generated from tests using [rspec_api_documentation](https://github.com/zipmark/rspec_api_documentation).

## Deploying

We deploy using [Capistrano](https://github.com/capistrano/capistrano).
You can create the required settings files for your particular environment.

## Harvester

An audio file harvester is included. The configuration files are similar to those for the web server,
and the default settings file can be found in `/lib/external/harvester/harvester_default.yml`.
There are a few different ways to run it:

 - `\lib\external\harvester\listen_and_harvest.rb`: Start harvester from the command line. It will watch for added files.
 - `\lib\external\harvester\daemonized_listener.rb`: Starts the harvester as a daemon to watch for file changes.
 - `\lib\external\harvester\harvest_directory.rb`: Run harvester once from the command line.

Instructions for using the harvester are available on the website from any `Site` page
(the view can be found in `/app/views/sites/upload_instructions.html.haml`).

## Licence
Apache License, Version 2.0
