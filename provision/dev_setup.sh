#!/bin/bash

set -e

# git-lfs needed for working with dev container (not for prod)
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
DEBIAN_FRONTEND=noninteractive apt-get install git-lfs
git lfs install

USERNAME=baw_web

# docker container now missing .bashrc by default. Useful for interactive situations
/bin/cp /etc/skel/.bashrc "/home/$USERNAME/.bashrc"
chown $USERNAME "/home/$USERNAME/.bashrc"

SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir -p /commandhistory \
    && chmod 777 /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME /commandhistory \
    && echo $SNIPPET >> "/home/$USERNAME/.bashrc"
