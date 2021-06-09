#!/bin/bash

cat /etc/kubernetes/ssl/kube-node.pem /etc/kubernetes/ssl/kube-node-key.pem > /home/ssl-crt.pem

if [ ! "${INTERFACE}" ] || [ -z "${INTERFACE}" ]; then
  export INTERFACE=$( ip route show | grep default | awk -F'dev' '{print $2}' | awk -F' ' '{print $1}' )
fi

export RISE_TIME=${RISE_TIME-60}
export CONFD_AGE=${CONFD_AGE-'-log-level=debug -onetime -backend env'}
export KEEPALIVED_ARG=${KEEPALIVED_ARG:-'-D -g'}
export HAPROXY_ARG=${HAPROXY_ARG:-'-p /run/haproxy.pid -D -sf'}
export CROND_ARG=${CROND_ARG:-'-b -L /var/log/cron/cron.log'}

export RSYSLOG_PID="/var/run/rsyslogd.pid"
rm -f ${RSYSLOG_PID}

echo 'info: run crond'
crond -s /var/spool/cron/crontabs ${CROND_ARG}

echo 'info: run rsyslogd'
rsyslogd

echo 'info: run keepalived'
keepalived -f /usr/local/etc/keepalived/keepalived.conf ${KEEPALIVED_ARG}

echo 'info: run haproxy'
haproxy -f /usr/local/etc/haproxy/haproxy.cfg ${HAPROXY_ARG}

echo 'info: run clusterGetnodeip'
clusterGetnodeip -rise=${RISE_TIME} -confd-arg="${CONFD_AGE}"

