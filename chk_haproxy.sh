#!/bin/bash

K8S_API_SERVER_STATE=$( curl -LSs --cacert /etc/kubernetes/ssl/kube-ca.pem --cert /etc/kubernetes/ssl/kube-node.pem --key /etc/kubernetes/ssl/kube-node-key.pem https://127.0.0.1:${HAPROXY_K8S_API_PORT}/healthz );

if [ "${K8S_API_SERVER_STATE}" == "ok" ]; then
    exit 0;
else
    ip addr del ${KEEPALIVED_HAPROXY_VIP} dev ${KEEPALIVED_INTERFACE}
    exit 1;

fi