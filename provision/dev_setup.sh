#!/bin/bash

set -e

RAILS_ENV=development /home/baw_web/baw-server/provision/entrypoint.sh
RAILS_ENV=test /home/baw_web/baw-server/provision/entrypoint.sh
