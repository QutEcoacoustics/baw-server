#!/bin/bash

# The -e flag causes the script to exit as soon as one command returns a non-zero exit code.
# The -v flag makes the shell print all lines in the script before executing them.
set -ev

# download, extract, build, and add wac2wavcmd to path
mkdir -p /tmp/wac2wav
wget https://github.com/QutBioacoustics/wac2wavcmd/archive/master.zip -O /tmp/master.zip
unzip -o /tmp/master.zip -d /tmp
make -C /tmp/wac2wavcmd-master/
mv /tmp/wac2wavcmd-master/wac2wavcmd /tmp/wac2wav/wac2wavcmd
export PATH=/tmp/wac2wav/:$PATH

# Set permanent access up. If we Don't have sudo access, fail gracefully and assume in test env.
sudo ln -s /tmp/wac2wav/wac2wavcmd /usr/local/bin/wac2wavcmd || true