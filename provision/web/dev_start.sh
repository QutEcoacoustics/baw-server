#!/bin/bash

function log() {
    echo -e "\n==> $1"
}

set -e

# Set nullglob to return empty when wildcard fails
shopt -s nullglob

log "Reset passenger file"
cp ./provision/Passengerfile.development.json /home/baw_web/baw-server/Passengerfile.json

log "Truncating log files"
for f in /home/baw_web/baw-server/log/*.log; do
    # keep the last 10000 lines
    tail -n 10000 "$f" >tmp.log && mv tmp.log "$f"
done

log "Sleeping for infinity..."
exec sleep infinity