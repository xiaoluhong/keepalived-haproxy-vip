FROM    golang:1.16.3 AS builder

RUN     cd / \
    &&  git clone https://github.com/MrYuanZhen/kubernetes_tools.git \
    &&  cd /kubernetes_tools/clusterGetnodeip \
    &&  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build

FROM    alpine:edge

# Get confd
ENV     CONFD_VERSION 0.16.0
ARG     KEEPALIVED_VERSION=2.2.2

# Get kubectl
RUN     apk update \
    &&  apk upgrade \
    &&  apk add --no-cache \
        autoconf \
        wget \
        curl \
        curl-dev \
        libexecinfo \
        libexecinfo-dev \
        gcc \
        bash \
        ipset \
        ipset-dev \
        bash-completion \
        vim \
        rsyslog \
        ca-certificates \
        logrotate \
        rsync \
        dcron \
        ipvsadm \
        net-tools \
        iputils \
        iptables \
        iptables-dev \
        libnfnetlink \
        libnfnetlink-dev \
        libnl3 \
        libnl3-dev \
        make \
        file-dev \
        musl-dev \
        openssl \
        libmagic \
        openssl-dev \
        libnftnl-dev \
        pcre2-dev \
        haproxy \
    &&  mkdir -p /tmp/keepalived /container/keepalived-sources /etc/keepalived \
    &&  cd /tmp/keepalived \
    &&  curl -o keepalived.tar.gz -SL http://keepalived.org/software/keepalived-${KEEPALIVED_VERSION}.tar.gz \
    &&  tar -xzf keepalived.tar.gz --strip 1 -C /container/keepalived-sources \
    &&  cd /container/keepalived-sources \
    &&  ./configure \
        --disable-dynamic-linking \
        --enable-log-file \
        --enable-strict-config-checks \
        --enable-mem-check \
        --enable-mem-check-log \
        --enable-timer-check \
        --enable-debug \
        --enable-checker-debug \
        --enable-script-debug \
        --enable-regex \
    &&  make \
    &&  make install \
    &&  rm -rf /tmp/keepalived \
    &&  rm -rf /container/keepalived-sources \
    &&  apk --no-cache del \
        libnftnl-dev \
        autoconf \
        gcc \
        ipset-dev \
        file-dev \
        iptables-dev \
        libnfnetlink-dev \
        libnl3-dev \
        make \
        musl-dev \
        openssl-dev \
    &&  mkdir -p /etc/rsyslog.d/ /var/log/cron \
    &&  mkdir -m 0644 -p /var/spool/cron/crontabs /etc/cron.d \
    &&  touch /var/log/cron/cron.log /var/log/haproxy.log /var/log/keepalived.log \
    &&  sed -i '/imklog/s/^/#/' /etc/rsyslog.conf \
    &&  sed -i '/*.info;au/s/^/#/' /etc/rsyslog.conf \
    &&  rm -rf /var/cache/apk/*

RUN     curl -LSs -O https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl \
    &&  mv ./kubectl /usr/local/bin/kubectl \
    &&  chmod +x /usr/local/bin/kubectl \
    &&  curl -LSs -o /usr/bin/confd https://github.com/kelseyhightower/confd/releases/download/v${CONFD_VERSION}/confd-${CONFD_VERSION}-linux-amd64

COPY    confd/ /etc/confd/
COPY    endpoint.sh /endpoint.sh
COPY    haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY    keepalived.conf /usr/local/etc/keepalived/keepalived.conf
COPY    rsyslog.conf /etc/rsyslog.d/
COPY    logrotate.cfg /etc/logrotate.d/logrotate
COPY    chk_haproxy.sh /usr/bin/chk_haproxy.sh

# 此处添加小工具
COPY    --from=builder /kubernetes_tools/clusterGetnodeip/clusterGetnodeip /usr/bin/clusterGetnodeip

RUN     chmod +x /usr/bin/confd /endpoint.sh /usr/bin/clusterGetnodeip /usr/bin/chk_haproxy.sh

WORKDIR /var/log

CMD     /endpoint.sh
