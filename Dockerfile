FROM ruby:2.5-stretch AS baw-server-core

ARG app_name=baw-server
ARG environment=development
ARG app_user=baw-web

COPY ./provision/install_passenger.sh /install_passenger.sh

RUN apt-get update && apt-get upgrade && \
    # create a user for the app
    # -D is for defaults, which includes NO PASSWORD
    # adduser myappuser
    # we use useradd instead of adduser, since it can be done without any interactivity
    # might need to do some other stuff achieve the full effect of adduser.
    useradd -m myappuser
#&& bash /install_passenger.sh

# change the working directory to the user's home directory
WORKDIR /home/myappuser/myapp

COPY ./passenger_conf/myapp.conf /etc/nginx/sites-enabled/


## add the app

COPY ./myapp/Gemfile /home/myappuser/myapp
COPY ./myapp/Gemfile.lock /home/myappuser/myapp

RUN bundle install

# Add the Rails app
COPY ./myapp /home/myappuser/myapp
RUN chown -R myappuser:myappuser /home/myappuser/myapp

EXPOSE 3000

FROM baw-server-core AS baw-server-dev

# nano for editing files, wrk for load testing passenger
RUN apt-get install -y nano wrk