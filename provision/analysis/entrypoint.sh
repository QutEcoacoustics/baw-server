#!/bin/sh

#set -x
set -m
set -e

pbs_conf_file=/etc/pbs.conf
mom_conf_file=/var/spool/pbs/mom_priv/config
hostname=$(hostname)

echo "[entrypoint] run at $(date -Is)"

# replace hostname in pbs.conf
echo "[sed] template $pbs_conf_file"
sed -i "s/PBS_SERVER=.*/PBS_SERVER=$hostname/" $pbs_conf_file

# replace mom_priv/config
echo "[sed] template $mom_conf_file"
sed -i "s/\$clienthost .*/\$clienthost $hostname/" $mom_conf_file

echo "[kill] kill any existing rsyslogd process"
pkill -F /var/run/rsyslogd.pid --echo || true
rm /var/run/rsyslogd.pid || true

echo "[start] start rsyslogd"
rsyslogd -n &
echo "[start] start sshd"
/usr/sbin/sshd -f /etc/ssh/sshd_config
echo "[start] start pbs"
/etc/init.d/pbs start

# sometimes pbs doesn't actually finish starting before we try to use qmgr
echo "[sleep] waiting for pbs"
sleep 1


echo "[PBS] enable history"
/opt/pbs/bin/qmgr -c "set server job_history_enable=True"
echo "[PBS] set scheduler iteration"
/opt/pbs/bin/qmgr -c "set server scheduler_iteration = 1"
echo "[PBS] set log_events"
/opt/pbs/bin/qmgr -c "s s log_events=511"
# The hpc we're trying to simulate has a max queue limit even though it's not
# default, replicate it here
echo "[PBS] set server max_queued"
/opt/pbs/bin/qmgr -c "set server max_queued = [u:PBS_GENERIC=10]"
# limit max run to make testing easier - particularly queries about jobs waiting
# in queues
echo "[PBS] set server max_run"
/opt/pbs/bin/qmgr -c "set server max_run = [u:PBS_GENERIC=5]"

# Allows pbsuser to run containers
echo "[docker] set permissions for docker sock"
chown root:docker /var/run/docker.sock
chmod g+rwx /var/run/docker.sock

echo "[exec] execute original command"
exec "$@"
