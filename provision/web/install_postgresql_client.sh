#!/bin/bash
set -e


curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg

# load os version as env vars
. /etc/os-release

echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt/ $VERSION_CODENAME-pgdg main" > /etc/apt/sources.list.d/pgdg.list


apt-get update

apt-get install -y --no-install-recommends libpq-dev postgresql-client-18
