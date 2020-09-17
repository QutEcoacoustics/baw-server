Taken from: https://github.com/drakkan/sftpgo/tree/master/docker/sftpgo/alpine

# SFTPGo with Docker and Alpine

This DockerFile is made to build image to host multiple instances of SFTPGo started with different users.

## Example

It is recommend you use a dedicated linux user to do uploading.
For dev purposes we use the standard ubuntu user (1000:1000).

See our docker-compose file for an example container invocation.

We have set the entrypoint script to always check if the database is initiated.
This does a `sftpgo initprovider` check on every boot. If not needed, sftpgo does
nothing, returns 0, and continues to run `CMD` (for which the default is `serve`)

Here is an example boot command using most of the available options.

```bash
# Start the image
sudo docker rm sftpgo && sudo docker run --name sftpgo \
  -e SFTPGO_LOG_FILE_PATH= \
  -e SFTPGO_CONFIG_DIR=/srv/sftpgo/config \
  -e SFTPGO_HTTPD__TEMPLATES_PATH=/srv/sftpgo/web/templates \
  -e SFTPGO_HTTPD__STATIC_FILES_PATH=/srv/sftpgo/web/static \
  -e SFTPGO_HTTPD__BACKUPS_PATH=/srv/sftpgo/backups \
  -p 8080:8080 \
  -p 2022:2022 \
  -e PUID=1003 \
  -e GUID=1003 \
  -v /home/sftpuser/conf/:/srv/sftpgo/config \
  -v /home/sftpuser/data:/data \
  -v /home/sftpuser/backups:/srv/sftpgo/backups \
  sftpgo
```

If you want to enable FTP/S you also need the publish the FTP port and the FTP passive port range, defined in your `Dockerfile`, by adding, for example, the following options to the `docker run` command `-p 2121:2121 -p 50000-50100:50000-50100`. The same goes for WebDAV, you need to publish the configured port.

The script `entrypoint.sh` makes sure to correct the permissions of directories and start the process with the right user.

Several images can be run with different parameters.


# Dev authentication

Password for dev authentication is:

- username: upload_admin
- password: password

Stored in `config/httpd_auth`, generated with `htpasswd`.

DO NOT USE THIS CONFIGURATION FOR PRODUCTION!

# Production setup
In production ensure:

- docker binds the 8080 port to an internal subnet
- that certificates are setup and used for the connection
- that the admin password is long, strong, and random!

Also add a dedicated user for uploads, ensure they do not have a login shell:

```
RUN mkdir -p ${DATA_DIR} ${CONFIG_DIR} ${WEB_DIR} ${BACKUPS_DIR}
RUN groupadd --system -g ${GID} ${GROUPNAME}
RUN useradd --system --create-home --no-log-init --home-dir ${HOME_DIR} --comment "SFTPGo user" --shell /bin/false --gid ${GID} --uid ${UID} ${USERNAME}
```

# Binding home directory

In our use case for this uploader service, we wish to expose the `harvester_to_do` directory.

So mount `<persistent_storage_base_dir>/harvester_to_do` to `/data`
