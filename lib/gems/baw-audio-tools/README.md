# baw-audio-tools

Bioacoustics Workbench audio tools. Contains the audio, spectrogram, and caching tools for the Bioacoustics Workbench project.

This code was historically maintained in https://github.com/QutEcoacoustics/baw-workers
but was incorporated into this repository for ease of maintenance.

Old readme follows:
---

## Dependencies

You may need to install some additional tools for working with audio and images, and for processing long-running tasks.

 - [ImageMagick](http://www.imagemagick.org/) is used by [paperclip](https://github.com/thoughtbot/paperclip).
 - [WavPack](http://www.wavpack.com/) is used to expand compressed `.wv` files.
 - [SoX](http://sox.sourceforge.net/) is used to create spectrograms and resample audio.
 - [shnTool](http://www.etree.org/shnutils/shntool/) is a tool for quickly segmenting large `.wav` files.
 - [mp3splt](http://mp3splt.sourceforge.net/mp3splt_page/home.php) is a tool for quickly segmenting large `.mp3` files.
 - [ffmpeg](http://www.ffmpeg.org/) is used for audio conversion and gathering audio file information.
 - [wac2wav](https://github.com/QutBioacoustics/wac2wavcmd) is used to convert from `.wac` to `.wav`.
 - [redis](http://redis.io/) is used by [Resque](https://github.com/resque/resque/tree/v1.25.2) to manage long-running tasks.

Audio tools from apt: imagemagick, wavpack, sox, shntool, mp3splt. Ffmpeg is installed from a binary.

    sudo apt-get install make g++ libsndfile1-dev libpng++-dev libpng12-dev libboost-program-options-dev imagemagick wavpack libsox-fmt-all sox shntool mp3splt libav-tools



Download and install latest ffmpeg:

    cd ~/Downloads
    mkdir ./ffmpeg
    wget -O download-ffmpeg.tar.xz http://johnvansickle.com/ffmpeg/releases/ffmpeg-release-64bit-static.tar.xz
    tar -xf download-ffmpeg.tar.xz  -C ./ffmpeg/ --strip=1
    sudo mv ./ffmpeg/ffmpeg /usr/local/bin/ffmpeg
    sudo mv ./ffmpeg/ffprobe /usr/local/bin/ffprobe

Download, build, and install wac2wav:

    cd ~/Downloads
    wget -O wac2wavcmd-master.zip https://github.com/QutBioacoustics/wac2wavcmd/archive/master.zip
    unzip wac2wavcmd-master.zip
    cd wac2wavcmd-master
    make
    sudo cp ./wac2wavcmd /usr/local/bin/
