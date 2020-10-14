#!/bin/bash

set -e

# git-lfs needed for working with dev container (not for prod)
curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
DEBIAN_FRONTEND=noninteractive apt-get install git-lfs
git lfs install


