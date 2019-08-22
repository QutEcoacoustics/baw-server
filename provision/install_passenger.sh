#!/usr/bin/env bash


# adapted from
# https://www.phusionpassenger.com/library/install/nginx/install/oss/stretch/
# https://www.phusionpassenger.com/library/walkthroughs/deploy/ruby/ownserver/nginx/oss/stretch/deploy_app.html

# to be copied into the container and run


# Step 1: install Passenger packages

# done by parent container
#apt-get update

apt-get install -y dirmngr gnupg
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
apt-get install -y apt-transport-https ca-certificates

# why do we need sh? (sh = dash on this debian)
sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger stretch main > /etc/apt/sources.list.d/passenger.list'
apt-get update


apt-get install -y libnginx-mod-http-passenger

# Remove the default site
rm /etc/nginx/sites-enabled/default


# Step 2: enable the Passenger Nginx module and restart Nginx

#Ensure the config files are in-place
# ln = create symbolic link
# don't seem to need this everything already in place
#if [ ! -f /etc/nginx/modules-enabled/50-mod-http-passenger.conf ]; then sudo ln -s /usr/share/nginx/modules-available/mod-http-passenger.load /etc/nginx/modules-enabled/50-mod-http-passenger.conf ; fi
#sudo ls /etc/nginx/conf.d/mod-http-passenger.conf

service nginx restart


# Step 3: check installation

# don't need to run this during automated installation, this is when going through manually.
# /usr/bin/passenger-config validate-install
# /usr/sbin/passenger-memory-stats


# https://www.phusionpassenger.com/library/walkthroughs/deploy/ruby/ownserver/nginx/oss/stretch/deploy_app.html



# ensure that that user has your SSH key installed
su myappuser -c "mkdir -p ~myappuser/.ssh"
su myappuser -c "touch ~myappuser/.ssh/authorized_keys"
su myappuser -c "cat ~myappuser/.ssh/authorized_keys >> ~myappuser/.ssh/authorized_keys"
su myappuser -c "chown -R myappuser: ~myappuser/.ssh"
su myappuser -c "chmod 700 ~myappuser/.ssh"
su myappuser -c "chmod 600 ~myappuser/.ssh/*"



