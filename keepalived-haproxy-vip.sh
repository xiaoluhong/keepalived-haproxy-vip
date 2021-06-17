KEEPALIVED_HAPROXY_IMAGES='registry.cn-shenzhen.aliyuncs.com/rancher/keepalived-haproxy-vip'
KEEPALIVED_HAPROXY_VIP='172.16.131.100/24'
KEEPALIVED_INTERFACE=eth0
KEEPALIVED_ARG='-D -g -X'
KEEPALIVED_PRIORITY=100
KEEPALIVED_VIRTUAL_ROUTER_ID=$( echo ${RANDOM: 0:2} )
KEEPALIVED_AUTH_PASS=$( openssl rand --hex 4 )

HAPROXY_STATE_PORT=10086
HAPROXY_K8S_API_PORT=9443
HAPRXOY_NODEPORT=30186

RISE_TIME='60' # 默认每 60 秒获取一次节点 IP 信息
CONFD_AGE='-log-level=debug -onetime -backend env'

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: keepalived-haproxy-vip
---

apiVersion: v1
kind: Service
metadata:
  annotations:
    field.cattle.io/targetWorkloadIds: '["deployment:keepalived-haproxy-vip:keepalived-haproxy-vip"]'
    workload.cattle.io/targetWorkloadIdNoop: "true"
    workload.cattle.io/workloadPortBased: "true"
  labels:
    cattle.io/creator: norman
  name: keepalived-haproxy-vip-nodeport
  namespace: keepalived-haproxy-vip
spec:
  externalTrafficPolicy: Cluster
  ports:
  - name: 30086tcp01
    nodePort: ${HAPRXOY_NODEPORT}
    port: ${HAPROXY_STATE_PORT}
    protocol: TCP
    targetPort: ${HAPROXY_STATE_PORT}
  selector:
    app: keepalived-haproxy-vip
  sessionAffinity: None
  type: NodePort
---

apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app: keepalived-haproxy-vip
  name: keepalived-haproxy-vip
  namespace: keepalived-haproxy-vip
---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
  name: keepalived-haproxy-vip
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "watch", "list"]
---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
  name: keepalived-haproxy-vip-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: keepalived-haproxy-vip
subjects:
- kind: ServiceAccount
  name: keepalived-haproxy-vip
  namespace: keepalived-haproxy-vip
---

apiVersion: apps/v1
kind: DaemonSet
metadata:
  annotations:
  generation: 1
  labels:
    cattle.io/creator: norman
  name: keepalived-haproxy-vip
  namespace: keepalived-haproxy-vip
spec:
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: keepalived-haproxy-vip
  template:
    metadata:
      annotations:
        field.cattle.io/ports: '[[]]'
      labels:
        app: keepalived-haproxy-vip
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - preference:
              matchExpressions:
              - key: node-role.kubernetes.io/controlplane
                operator: In
                values:
                - "true"
            weight: 100
          - preference:
              matchExpressions:
              - key: node-role.kubernetes.io/control-plane
                operator: In
                values:
                - "true"
            weight: 99
          - preference:
              matchExpressions:
              - key: node-role.kubernetes.io/master
                operator: In
                values:
                - "true"
            weight: 98
          - preference:
              matchExpressions:
              - key: cattle.io/cluster-agent
                operator: In
                values:
                - "true"
            weight: 97
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: beta.kubernetes.io/os
                operator: NotIn
                values:
                - windows
              - key: app
                operator: In
                values:
                - keepalived-haproxy-vip
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - keepalived-haproxy-vip
              topologyKey: kubernetes.io/hostname
            weight: 100
      containers:
      - env:
        - name: HAPROXY_K8S_API_PORT
          value: '${HAPROXY_K8S_API_PORT}'
        - name: HAPROXY_STATE_PORT
          value: '${HAPROXY_STATE_PORT}'
        - name: RISE_TIME
          value: '${RISE_TIME}'
        - name: CONFD_AGE
          value: ${CONFD_AGE}
        - name: KEEPALIVED_AUTH_PASS
          value: ${KEEPALIVED_AUTH_PASS}
        - name: KEEPALIVED_INTERFACE
          value: ${KEEPALIVED_INTERFACE}
        - name: KEEPALIVED_ARG
          value: ${KEEPALIVED_ARG}
        - name: KEEPALIVED_PRIORITY
          value: '${KEEPALIVED_PRIORITY}'
        - name: KEEPALIVED_HAPROXY_VIP
          value: '${KEEPALIVED_HAPROXY_VIP}'
        - name: KEEPALIVED_VIRTUAL_ROUTER_ID
          value: '${KEEPALIVED_VIRTUAL_ROUTER_ID}'
        image: ${KEEPALIVED_HAPROXY_IMAGES}
        imagePullPolicy: Always
        name: keepalived-haproxy-vip
        readinessProbe:
          exec:
            command:
            - /usr/bin/chk_haproxy.sh
          failureThreshold: 3
          initialDelaySeconds: 10
          periodSeconds: 2
          successThreshold: 2
          timeoutSeconds: 2
        livenessProbe:
          exec:
            command:
            - /usr/bin/chk_haproxy.sh
          failureThreshold: 3
          initialDelaySeconds: 10
          periodSeconds: 2
          successThreshold: 1
          timeoutSeconds: 2
        resources:
          limits:
            cpu: "8"
            memory: 8000Mi
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /etc/kubernetes/ssl/
          name: k8s-ssl
          readOnly: true
      dnsPolicy: ClusterFirstWithHostNet
      hostNetwork: true
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      serviceAccount: keepalived-haproxy-vip
      serviceAccountName: keepalived-haproxy-vip
      terminationGracePeriodSeconds: 30
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/controlplane
        value: "true"
      volumes:
      - hostPath:
          path: /etc/kubernetes/ssl/
          type: ""
        name: k8s-ssl
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
EOF