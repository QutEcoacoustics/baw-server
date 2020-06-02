#!/bin/bash
set -e


curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# load os version as env vars
. /etc/os-release

echo "deb http://apt.postgresql.org/pub/repos/apt/ $VERSION_CODENAME-pgdg main" > /etc/apt/sources.list.d/pgdg.list


apt-get update

apt-get install -y --no-install-recommends libpq-dev postgresql-client-12
