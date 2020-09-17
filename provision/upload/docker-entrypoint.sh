#!/bin/sh

set -eu

chown -R "${PUID}:${GUID}" /data /etc/sftpgo /srv/sftpgo/config /srv/sftpgo/backups

su-exec "${PUID}:${GUID}"  /bin/sftpgo initprovider

exec su-exec "${PUID}:${GUID}"  /bin/sftpgo "$@"
