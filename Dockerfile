# syntax=docker/dockerfile:1.4
# Debian releases:
#
FROM ruby:3.4.4-slim-bullseye
ARG app_name=baw-server
ARG app_user=baw_web
ARG version=
# This saves about 150MB by not installing some gems and documentation
ARG trimmed=false

# install audio tools and other binaries
# apt is cleaned automatically: https://github.com/GoogleContainerTools/base-images-docker/blob/master/debian/reproducible/overlay/etc/apt/apt.conf.d/docker-clean
RUN --mount=type=bind,source=./provision,target=/provision \
  apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  # - git: we'd like to remove git dependency but we have multiple git based dependencies
  # in our gem files
  # - curl is needed for passenger
  # - iproute2 install ip and basic network debugging tools
  # - gnupg is for validating apt public keys
  ca-certificates git curl gnupg iproute2 \
  # sqlite
  sqlite3 libsqlite3-dev libgmp-dev \
  # the following are for nokogiri and the like
  build-essential patch ruby-dev zlib1g-dev liblzma-dev \
  # needed to build the psych gem's native extensions
  libyaml-dev \
  # passenger needs the ps command and it's not longer included in the base image
  procps \
  # for the pg gem we need postgresql-client (also used by rails rake db commands)
  && /provision/web/install_postgresql_client.sh \
  # install audio tools and other binaries
  && /provision/web/install_audio_tools.sh

RUN --mount=type=bind,source=./provision,target=/provision \
  # create a user for the app
  addgroup --gid 1000 ${app_user} \
  && adduser --uid 1000 --gid 1000 --home /home/${app_user} --shell /bin/sh --disabled-password --gecos "" ${app_user} \
  && mkdir /home/${app_user}/${app_name} \
  && chown -R ${app_user}:${app_user} /home/${app_user} \
  # allow bundle install to work as app_user
  # modified from here: https://github.com/docker-library/ruby/blob/6a7df7a72b4a3d1b3e06ead303841b3fdaca560e/2.6/buster/slim/Dockerfile#L114
  && mkdir -p "$GEM_HOME/bin" \
  && chmod 777 "$GEM_HOME/bin" \
  # https://github.com/moby/moby/issues/20437
  && mkdir -p /home/${app_user}/${app_name} \
  && chmod g+srx /home/${app_user}/${app_name} \
  && chown -R 1000:1000 /home/${app_user} \
  && mkdir -p /home/${app_user}/${app_name}/tmp \
  && mkdir /data \
  && chown -R 1000:1000 /data \
  && (if [ "x${trimmed}" != "xtrue" ]; then /provision/web/dev_setup.sh ; fi)


ENV RAILS_ENV=production \
  APP_USER=${app_user} \
  APP_NAME=${app_name} \
  BAW_SERVER_VERSION=${version} \
  # enable binstubs to take priority
  PATH=./bin:$PATH \
  BUNDLE_PATH__SYSTEM="true" \
  # migrate the database before booting the app. Recommended to run once per-deploy across cluster and then disable.
  # Also, must be false for worker instances.
  MIGRATE_DB=false \
  # generate assets for rails app
  # must be done in context (i.e. in production for production, not in dev for production)
  # should not be done for workers and in dev/test environments
  GENERATE_ASSETS=false \
  BINDING=0.0.0.0 \
  RUBY_YJIT_ENABLE=1


# "Install" our metadata utility
COPY --from=qutecoacoustics/emu:7.0.3 --chown==${app_user} /emu /emu

# change the working directory to the user's home directory
WORKDIR /home/${app_user}/${app_name}

# add base dependency files for bundle install (so we don't invalidate docker cache)
COPY --chown=${app_user} Gemfile Gemfile.lock  /home/${app_user}/${app_name}/

# install deps
# skip installing gem documentation
# run this as the app user
RUN <<EOF
  su ${app_user} << "EOF2"
    echo "Running as: $(whoami) || $(id)"
    set -eux

    # last known version that worked
    # gem version 3.5.21
    # bundler version 2.5.21
    gem update --system 3.5.21

    # skip installing gem documentation
    if [ "x${trimmed}" = "xtrue" ]; then
      echo 'gem: --no-document' >> "$HOME/.gemrc"
      bundle config set without development test
    fi

    # ensure required bundler version is installed
    # https://bundler.io/blog/2019/05/14/solutions-for-cant-find-gem-bundler-with-executable-bundle.html
    gem install bundler -v "$(grep -A 1 'BUNDLED WITH' Gemfile.lock | tail -n 1)"

    # install baw-server
    bundle install
EOF2
EOF

# Add the Rails app
COPY --chown=${app_user} ./ /home/${app_user}/${app_name}

# copy the passenger production config
# use a mount/volume to override this file for other environments
#
# For development we use entrypoint to copy a development version into place
# Thus there is no conflict here
COPY --chown=${app_user}:${app_user} ./provision/Passengerfile.production.json /home/${app_user}/${app_name}/Passengerfile.json

# assign permissions to special things
RUN <<EOF bash
  set -ex

  # allow group to read
  chmod -R g+r .
  find . -type d -exec chmod g+srx {} \;

  # and write for assets compilation
  chmod -R g+ws ./public

  # ensure execute permissions for scripts
  chmod a+x ./provision/*.sh
  chmod a+x ./bin/*

  # https://github.com/moby/moby/issues/20437
  chmod 1777 ./tmp
EOF

USER ${app_user}

# precompile passenger standalone
RUN bundle exec passenger start --runtime-check-only

ENTRYPOINT [ "./provision/entrypoint.sh" ]
CMD [ "passenger", "start" ]
# used for prod
EXPOSE 8888
# used for dev
EXPOSE 3000
VOLUME [ "/data" ]
