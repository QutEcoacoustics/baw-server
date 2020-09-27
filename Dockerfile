# Debian releases:
#
FROM ruby:2.6-slim-buster
ARG app_name=baw-server
ARG app_user=baw_web
ARG version=
# This saves about 150MB by not installing some gems and documentation
ARG trimmed=false

# install audio tools and other binaries
COPY ./provision/install_audio_tools.sh ./provision/install_postgresql_client.sh  /tmp/

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
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
  && chmod u+x /tmp/*.sh  \
  # for the pg gem we need postgresql-client (also used by rails rake db commands)
  && /tmp/install_postgresql_client.sh \
  # install audio tools and other binaries
  && /tmp/install_audio_tools.sh \
  && apt-get clean \
  && rm -rf /tmp/*.sh \
  && rm -rf /var/lib/apt/lists/*
RUN \
  # create a user for the app
  # -D is for defaults, which includes NO PASSWORD
  # adduser myappuser
  # we use useradd instead of adduser, since it can be done without any interactivity
  # might need to do some other stuff achieve the full effect of adduser.
  groupadd -g 1000 ${app_user} \
  && useradd -u 1000 -g ${app_user} ${app_user} \
  && mkdir -p /home/${app_user}/${app_name} \
  && chown -R ${app_user}:${app_user} /home/${app_user} \
  # allow bundle install to work as app_user
  # modified from here: https://github.com/docker-library/ruby/blob/6a7df7a72b4a3d1b3e06ead303841b3fdaca560e/2.6/buster/slim/Dockerfile#L114
  && mkdir -p "$GEM_HOME/bin" \
  && chmod 777 "$GEM_HOME/bin"


ENV RAILS_ENV=production \
  APP_USER=${app_user} \
  APP_NAME=${app_name} \
  BAW_SERVER_VERSION=${version} \
  # enable binstubs to take priority
  PATH=./bin:$PATH \
  BUNDLE_PATH__SYSTEM="true" \
  # migrate the database before booting the app. Recommended to run once per-deploy across cluster and then disable.
  # Also, must be false for worker instances.
  MIGRATE_DB=false


USER ${app_user}

# change the working directory to the user's home directory
WORKDIR /home/${app_user}/${app_name}

# add base dependency files for bundle install (so we don't invalidate docker cache)
COPY --chown=${app_user} Gemfile Gemfile.lock  /home/${app_user}/${app_name}/

# install deps
# skip installing gem documentation
RUN true \
  # temporarily upgrade bundler until we can jump to ruby 2.7
  && gem update --system \
  && gem install bundler \
  && ([ "x${trimmed}" != "xtrue" ] && echo 'gem: --no-rdoc --no-ri' >> "$HOME/.gemrc") || true \
  && ([ "x${trimmed}" = "xtrue" ] && bundle config set without development test) || true \
  # install baw-server
  && bundle install \
  # install docs for dev work
  && ([ "x${trimmed}" != "xtrue" ] && solargraph download-core && solargraph bundle) || true

# Add the Rails app
COPY --chown=${app_user} ./ /home/${app_user}/${app_name}

# copy the passenger production config
# use a mount/volume to override this file for other environments
#
# For development we use entrypoint to copy a development version into place
# Thus there is no conflict here
COPY --chown=${app_user} ./provision/Passengerfile.production.json /home/${app_user}/${app_name}/Passengerfile.json

# asign permissions to special things
RUN  chmod a+x ./provision/*.sh \
  && chmod a+x ./bin/*

# precompile passenger standalone
RUN bundle exec passenger start --runtime-check-only

ENTRYPOINT [ "./provision/entrypoint.sh" ]
CMD [ "passenger", "start" ]
# used for prod
EXPOSE 8888
# used for dev
EXPOSE 3000
VOLUME [ "/data" ]
