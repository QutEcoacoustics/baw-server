# Debian releases:
# 
FROM ruby:2.6-slim-buster AS baw-server-core

ARG app_name=baw-server
ARG environment=development
ARG app_user=baw_web

COPY ./provision/install_passenger.sh /install_passenger.sh


RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    # create a user for the app
    # -D is for defaults, which includes NO PASSWORD
    # adduser myappuser
    # we use useradd instead of adduser, since it can be done without any interactivity
    # might need to do some other stuff achieve the full effect of adduser.
    && useradd -m ${app_user} \
    && mkdir -p /home/${app_user}/${app_name} \
    && chown -R ${app_user}:${app_user} /home/${app_user}/${app_name} 
#&& bash /install_passenger.sh



USER ${app_user}

# change the working directory to the user's home directory
WORKDIR /home/${app_user}/${app_name}

# copy the passenger config
COPY ./provision/passenger.${environment}.json /home/${app_user}/${app_name}/passenger.json

# copy Gemfile and Gemfile.lock to install dependencies
COPY ./Gemfile Gemfile.lock /home/${app_user}/${app_name}/
#RUN chown -R ${app_user}:${app_user} /home/${app_user}/${app_name} && \

EXPOSE 3000


FROM baw-server-core AS baw-server-dev

# nano for editing files, wrk for load testing passenger
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    nano \
    && rm -rf /var/lib/apt/lists/*
USER ${app_user}
RUN bundle install --binstubs --path vendor/bundle

# Add the Rails app
COPY ./ /home/${app_user}/${app_name}

FROM baw-server-core AS baw-server

RUN bundle install --without 'development' --binstubs --clean  --deployment

# Add the Rails app
COPY ./ /home/${app_user}/${app_name}