#!/bin/bash

cat /etc/kubernetes/ssl/kube-node.pem /etc/kubernetes/ssl/kube-node-key.pem > /home/ssl-crt.pem

if [ ! "${KEEPALIVED_INTERFACE}" ] || [ -z "${KEEPALIVED_INTERFACE}" ]; then
  export KEEPALIVED_INTERFACE=$( ip route show | grep default | awk -F'dev' '{print $2}' | awk -F' ' '{print $1}' )
fi

export KEEPALIVED_ARG=${KEEPALIVED_ARG:-'-D -g -X'}
export KEEPALIVED_INTERFACE=${KEEPALIVED_INTERFACE:-eth0}
export KEEPALIVED_VIRTUAL_ROUTER_ID=${KEEPALIVED_VIRTUAL_ROUTER_ID:-51}
export KEEPALIVED_AUTH_PASS=${KEEPALIVED_AUTH_PASS:-passw0rd}
export KEEPALIVED_PRIORITY=${KEEPALIVED_PRIORITY:-100}

export KEEPALIVED_HAPROXY_VIP=${KEEPALIVED_HAPROXY_VIP}
export KEEPALIVED_HAPROXY_IMAGES=${KEEPALIVED_HAPROXY_IMAGES:-registry.cn-shenzhen.aliyuncs.com/rancher/keepalived-haproxy-vip}

export HAPROXY_K8S_API_PORT=${HAPROXY_K8S_API_PORT:-9443}
export HAPROXY_STATE_PORT=${HAPROXY_STATE_PORT:-10086}
export HAPROXY_ARG=${HAPROXY_ARG:-'-p /run/haproxy.pid -D -sf'}

export RISE_TIME=${RISE_TIME-60}
export CONFD_AGE=${CONFD_AGE-'-log-level=debug -onetime -backend env'}

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

