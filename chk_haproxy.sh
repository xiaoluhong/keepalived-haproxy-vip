#!/bin/bash

API_SERVER_STATS=$( curl -LSs --cacert /etc/kubernetes/ssl/kube-ca.pem --cert /etc/kubernetes/ssl/kube-node.pem --key /etc/kubernetes/ssl/kube-node-key.pem https://127.0.0.1:9443/healthz );

if [ "${API_SERVER_STATS}" == "ok" ]; then
    exit 0;
else
    ip addr del ${VIP} dev ${INTERFACE}
    exit 1;

fi