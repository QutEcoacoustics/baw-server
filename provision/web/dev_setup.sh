#!/bin/bash

set -e

# git-lfs needed for working with dev container (not for prod)
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
export DEBIAN_FRONTEND=noninteractive 
apt-get update && apt-get install -y --no-install-recommends \
    git \
    git-lfs \
    && rm -rf /var/lib/apt/lists/*
git lfs install

USERNAME=baw_web

# docker container now missing .bashrc by default. Useful for interactive situations
/bin/cp /etc/skel/.bashrc "/home/$USERNAME/.bashrc"
chown $USERNAME "/home/$USERNAME/.bashrc"

SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" &&
    mkdir -p /commandhistory &&
    chmod 777 /commandhistory &&
    touch /commandhistory/.bash_history &&
    chown -R $USERNAME /commandhistory &&
    echo $SNIPPET >>"/home/$USERNAME/.bashrc"

mkdir -p /home/$USERNAME/.vscode-server/extensions \
    /home/$USERNAME/.vscode-server-insiders/extensions &&
    chown -R $USERNAME \
        /home/$USERNAME/.vscode-server \
        /home/$USERNAME/.vscode-server-insiders

git config --global core.editor "code --wait"

# we're generating some powershell scripts from the server, thus we need powershell to test them
# currently this is dev time only dependency
source /etc/os-release
cd /tmp
curl -LOJ https://packages.microsoft.com/config/${ID}/${VERSION_ID}/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
apt-get update && apt-get install -y powershell
rm packages-microsoft-prod.deb
