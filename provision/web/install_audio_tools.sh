#!/bin/bash
set -e

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
    imagemagick \
    file


# link ffmpeg to /usr/bin/local
ln -s /usr/bin/ffmpeg /usr/local/bin/ffmpeg \
    && ln -s /usr/bin/ffprobe /usr/local/bin/ffprobe

mkdir /wac2wav \
    && cd /wac2wav \
    && curl -LOJ https://github.com/QutBioacoustics/wac2wavcmd/archive/master.tar.gz \
    && tar -xvzf wac2wavcmd-master.tar.gz --strip-components=1 \
    && make \
    && ln -s "/wac2wav/wac2wavcmd" /usr/local/bin/wac2wavcmd --force \
    && rm wac2wavcmd-master.tar.gz


