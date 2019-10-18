#!/bin/bash
set -e

# Historical note:
# no longer installing libpng or wav2png

# add-apt-repository ppa:jonathonf/ffmpeg-4

apt-get update

apt-get install -y --no-install-recommends \
    imagemagick \
    wavpack \
    libsox-fmt-all \
    sox \
    shntool \
    mp3splt \
    g++ \
    libsndfile1-dev \
    apt-transport-https \
    ffmpeg \
    imagemagick


    # link ffmpeg to /usr/bin/local
ln -s /usr/bin/ffmpeg /usr/local/bin/ffmpeg \
    && ln -s /usr/bin/ffprobe /usr/local/bin/ffprobe
