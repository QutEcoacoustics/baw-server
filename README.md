# baw-audio-tools

Bioacoustics Workbench audio tools. Contains the audio, spectrogram, and caching tools for the Bioacoustics Workbench project.

[![Build Status](https://travis-ci.org/QutBioacoustics/baw-audio-tools.png?branch=master)](https://travis-ci.org/QutBioacoustics/baw-audio-tools)
[![Dependency Status](https://gemnasium.com/QutBioacoustics/baw-audio-tools.png)](https://gemnasium.com/QutBioacoustics/baw-audio-tools)
[![Code Climate](https://codeclimate.com/github/QutBioacoustics/baw-audio-tools.png)](https://codeclimate.com/github/QutBioacoustics/baw-audio-tools)
[![Test Coverage](https://codeclimate.com/github/QutBioacoustics/baw-audio-tools/coverage.png)](https://codeclimate.com/github/QutBioacoustics/baw-audio-tools)
[![Documentation Status](http://inch-ci.org/github/QutBioacoustics/baw-audio-tools.png?branch=master)](http://inch-ci.org/github/QutBioacoustics/baw-audio-tools)
[![Documentation](https://img.shields.io/badge/docs-rdoc.info-blue.svg)](http://www.rubydoc.info/github/QutBioacoustics/baw-audio-tools)

## Installation

Add this line to your application's Gemfile:

    gem 'baw-audio-tools', git: 'https://github.com/QutBioacoustics/baw-audio-tools.git'

And then execute:

    $ bundle

## Dependencies

You may need to install some additional tools for working with audio and images, and for processing long-running tasks.

 - [ImageMagick](http://www.imagemagick.org/) is used by [paperclip](https://github.com/thoughtbot/paperclip).
 - [WavPack](http://www.wavpack.com/) is used to expand compressed `.wv` files.
 - [SoX](http://sox.sourceforge.net/) is used to create spectrograms and resample audio.
 - [shnTool](http://www.etree.org/shnutils/shntool/) is a tool for quickly segmenting large `.wav` files.
 - [mp3splt](http://mp3splt.sourceforge.net/mp3splt_page/home.php) is a tool for quickly segmenting large `.mp3` files.
 - [ffmpeg](http://www.ffmpeg.org/) is used for audio conversion and gathering audio file information.
 - [wav2png](https://github.com/beschulz/wav2png) is used to generate waveform images.
 - [redis](http://redis.io/) is used by [Resque](https://github.com/resque/resque/tree/v1.25.2) to manage long-running tasks.

Audio tools from apt: imagemagick, wavpack, sox, shntool, mp3splt. Ffmpeg is installed from a binary, and wav2png can be built from source.

    sudo apt-get install make g++ libsndfile1-dev libpng++-dev libpng12-dev libboost-program-options-dev imagemagick wavpack libsox-fmt-all sox shntool mp3splt libav-tools

Download, build and install wav2png:

    cd ~/Downloads
    git clone https://github.com/beschulz/wav2png.git
    make -C ./wav2png/build all
    sudo mv ./wav2png/bin/Linux/wav2png /usr/local/bin/

Download and install latest ffmpeg:

    cd ~/Downloads
    mkdir ./ffmpeg
    wget http://johnvansickle.com/ffmpeg/releases/ffmpeg-release-64bit-static.tar.xz
    tar -xf ffmpeg/download-ffmpeg.tar.xz  -C ./ffmpeg/ --strip=1
    sudo mv ./ffmpeg/ffmpeg /usr/local/bin/ffmpeg
    sudo mv ./ffprobe/ffprobe /usr/local/bin/ffprobe
