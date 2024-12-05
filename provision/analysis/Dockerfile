# syntax=docker/dockerfile:latest

#
# THIS IS A SIMULATION OF A HPC ENVIRONMENT
#
# NEVER, EVER, USE THIS IMAGE IN A PRODUCTION SCENARIO.
#

FROM opensuse/leap:15

# https://www.openpbs.org/Download.aspx#download
ARG pbs_package=openpbs_22.05.11.opensuse_leap_15.3.zip

#
# Basic setup
#

# zip used for pbs install
# tar & gzip used for doxker cli install
RUN zypper --non-interactive refresh && \
    zypper --non-interactive install tar gzip unzip sudo nano \
    openssl certmonger curl python3

#
# rsyslogd
#

# grc: generic log colourizer makes logs easier to read
RUN zypper --non-interactive install rsyslog grc

COPY rsyslog.conf /etc/rsyslog.conf
COPY conf.pbs /usr/share/grc/conf.pbs

ENV TERM=xterm-256color
RUN --mount=type=bind,source=.,target=/build <<-EOF
    # append default log conf
    cat /build/conf.pbs /usr/share/grc/conf.log > /usr/share/grc/conf.log2
    # overwrite the original
    mv  /usr/share/grc/conf.log2  /usr/share/grc/conf.log
EOF

#
# sshd
#

RUN <<-EOF
    set -e
    # openssh-server for sshd, openssh-clinets for the scp command (used to send files to this container)
    zypper --non-interactive install openssh-server openssh-clients

    # Enable root accounts
    echo 'root:password' | chpasswd

    # Configure SSHD
    mkdir -p /var/run/sshd ; chmod -rx /var/run/sshd
EOF

# http://stackoverflow.com/questions/2419412/ssh-connection-stop-at-debug1-ssh2-msg-kexinit-sent
COPY ./ssh_host_* /etc/ssh/

# Configure and deploy ssh keys
RUN --mount=type=bind,source=.,target=/build <<-EOF
    set -e
    # Bad security, add a user and sudo instead!
    sed -ri 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config

    # http://stackoverflow.com/questions/18173889/cannot-access-centos-sshd-on-docker
    sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config
    sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config

    mkdir -p /root/.ssh/
    cat /build/client_key.pub > ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
    chmod 600 /etc/ssh/ssh_host_rsa_key
EOF

#
# configure PBS
#

ENV PBS_START_MOM=1
ENV PBS_SYSLOG=1
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

RUN <<-EOF
    set -e
    mkdir /pbs
    cd /pbs
    curl -L -k -O https://vcdn.altair.com/rl/OpenPBS/${pbs_package}
    ls -la

    # -j = junk paths, don't make directories
    unzip -j ${pbs_package}
    ls -laR

    rm *debuginfo*.rpm

    zypper --non-interactive install  --allow-unsigned-rpm openpbs-server-*.rpm
EOF

COPY pbs.conf /etc/pbs.conf
COPY --chmod=444 mom_config /var/spool/pbs/mom_priv/config

#
# Install docker-cli (but not the daemon)
# https://stackoverflow.com/a/43594065/224512
#

ENV DOCKERVERSION=20.10.17
RUN \
    curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz \
    && tar xzvf docker-${DOCKERVERSION}.tgz --strip 1 \
    -C /usr/local/bin docker/docker \
    && rm docker-${DOCKERVERSION}.tgz

#
# COPY entrypoint
#

COPY ./entrypoint.sh /entrypoint.sh

#
# Create pbsuser, set default settings
#

RUN --mount=type=bind,source=.,target=/build <<-EOF
    set -e

    chmod +x /entrypoint.sh

    useradd -m -u 1000 -U pbsuser
    echo 'pbsuser:password' | chpasswd
    mkdir -p  /home/pbsuser/.ssh
    cat /build/client_key.pub > /home/pbsuser/.ssh/authorized_keys

    # allow accessing the host docker instance
    groupadd docker
    usermod -aG docker pbsuser

    # (chmod/chown is in entrypoint.sh)
EOF

# our generic mounting point
VOLUME /data

EXPOSE 22

ENTRYPOINT [ "/entrypoint.sh" ]

CMD grc tail -f /var/log/syslog /var/log/auth.log

#  echo "/usr/bin/sleep 1 && echo 'hello'" | qsub -
