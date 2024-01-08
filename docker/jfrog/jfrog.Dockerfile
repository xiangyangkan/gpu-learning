ARG JFROG_ARTIFACTORY_VERSION=6.6.10
FROM releases-docker.jfrog.io/jfrog/artifactory-pro:${JFROG_ARTIFACTORY_VERSION}

USER root
# 不必在dockerfile中给echo命令添加-e参数
RUN echo "deb https://archive.debian.org/debian/ stretch main contrib non-free\n\
deb-src https://archive.debian.org/debian/ stretch main contrib non-free\n\
deb https://archive.debian.org/debian-security/ stretch/updates main contrib non-free\n\
deb-src https://archive.debian.org/debian-security/ stretch/updates main contrib non-free"  \
    > /etc/apt/sources.list && \
    touch /etc/apt/apt.conf.d/99verify-peer.conf && \
    echo >>/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }"

RUN apt-get update --fix-missing && apt-get --fix-broken install -y \
    sudo iptables dnsutils proxychains redsocks supervisor && \
    apt-get upgrade iptables -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY proxychains.conf /etc/proxychains.conf
COPY redsocks.conf /etc/redsocks.conf
COPY jfrog/supervisord.conf /
COPY jfrog/iptables.sh /
RUN chmod +x /iptables.sh

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/supervisord.conf"]
