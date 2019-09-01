# Debian releases:
#
FROM ruby:2.6-slim-buster AS baw-server-core

ARG app_name=baw-server
ARG app_user=baw_web

# install audio tools and other binaries
COPY ./provision/install_audio_tools.sh /install_audio_tools.sh
RUN chmod u+x /install_audio_tools.sh

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    # - we'd like to remove git dependency but we have multiple git based dependencies
    # in our gem files
    # - curl is needed for passenger
    # - nano not needed for prod
    ca-certificates curl nano git \
    # sqlite
    sqlite3 libsqlite3-dev libgmp-dev \
    # the following are for nokogiri and the like
    build-essential patch ruby-dev zlib1g-dev liblzma-dev \
    # for the postgre gem and postgresql-client rails rake db commands
    libpq-dev postgresql-client \
    && rm -rf /var/lib/apt/lists/* \
    # create a user for the app
    # -D is for defaults, which includes NO PASSWORD
    # adduser myappuser
    # we use useradd instead of adduser, since it can be done without any interactivity
    # might need to do some other stuff achieve the full effect of adduser.
    && groupadd -r ${app_user} \
    && useradd -r -g ${app_user} ${app_user} \
    && mkdir -p /home/${app_user}/${app_name} \
    && chown -R ${app_user}:${app_user} /home/${app_user}
#&& bash /install_passenger.sh

# install audio tools and other binaries
RUN ./install_audio_tools.sh

USER ${app_user}

# change the working directory to the user's home directory
WORKDIR /home/${app_user}/${app_name}

# Add the Rails app
COPY --chown=${app_user} ./ /home/${app_user}/${app_name}

# copy the passenger config
# use a mount/volume to override this file for other environments
COPY ./provision/Passengerfile.production.json /home/${app_user}/${app_name}/Passengerfile.json


EXPOSE 3000
ENV RAILS_ENV=${environment} APP_USER=${app_user} APP_NAME=${app_name}

ENTRYPOINT [ "bundle", "exec" ]
CMD [ "passenger", "start" ]

FROM baw-server-core AS baw-server-dev

USER ${app_user}

RUN bundle install --system \
    # precompile passenger standalone
    && bundle exec passenger start --runtime-check-only

# RUN chmod u+x ./provision/entrypoint.sh
RUN chmod 777 ./provision/entrypoint.sh
ENTRYPOINT ./provision/entrypoint.sh
CMD []




FROM baw-server-core AS baw-server

# install deps
RUN bundle install --system --without 'development' 'test' \
    && bundle exec passenger start --runtime-check-only
