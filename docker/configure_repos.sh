#!/bin/bash

# 检查参数
if [ "$#" -ne 2 ]; then
    echo -e "Usage: $0 <Artifactory-URL> <Repository-Key-Prefix>"
    exit 1
fi

# Artifactory 基本 URL
ARTIFACTORY_URL=$1
# 提取ARTIFACTORY_URL中的主机名
ARTIFACTORY_HOST=$(echo -e "$ARTIFACTORY_URL" | awk -F[/:] '{print $4}')

# Repository 前缀
REPOSITORY_KEY_PREFIX=$2


# 检查是否在容器内运行
in_container() {
    grep -qE '/docker|/kubepods' /proc/1/cgroup
}


# Docker 仓库配置
configure_docker() {
    if ! in_container; then
        # daemon.json中registry-mirrors不能添加路径，否则会报错
        # echo -e '{"registry-mirrors": ["'"$ARTIFACTORY_URL"'/artifactory/'"$REPOSITORY_KEY_PREFIX'"-docker/"]}' | sudo tee /etc/docker/daemon.json
        echo -e '{"insecure-registries": ["'"$ARTIFACTORY_HOST"'"]}' | sudo tee /etc/docker/daemon.json
        # sudo systemctl restart docker
    else
        echo -e "Running inside a container, skipping Docker repository configuration."
    fi
}

# APT (Debian/Ubuntu) 或 RPM (Red Hat/CentOS) 仓库配置
configure_package_manager() {
    if [ -f /etc/debian_version ]; then
        # 获取发行版代号，如 'jammy'
        local distro
        distro=$(lsb_release -cs)

        # 配置 APT 源
        cat <<EOF | sudo tee /etc/apt/sources.list.d/jfrog.list
deb $ARTIFACTORY_URL/artifactory/$REPOSITORY_KEY_PREFIX-debian/ $distro main restricted
deb $ARTIFACTORY_URL/artifactory/$REPOSITORY_KEY_PREFIX-debian/ $distro-updates main restricted
deb $ARTIFACTORY_URL/artifactory/$REPOSITORY_KEY_PREFIX-debian/ $distro universe
deb $ARTIFACTORY_URL/artifactory/$REPOSITORY_KEY_PREFIX-debian/ $distro-updates universe
deb $ARTIFACTORY_URL/artifactory/$REPOSITORY_KEY_PREFIX-debian/ $distro multiverse
deb $ARTIFACTORY_URL/artifactory/$REPOSITORY_KEY_PREFIX-debian/ $distro-updates multiverse
deb $ARTIFACTORY_URL/artifactory/$REPOSITORY_KEY_PREFIX-debian/ $distro-backports main restricted universe multiverse
deb $ARTIFACTORY_URL/artifactory/$REPOSITORY_KEY_PREFIX-debian/ $distro-security main restricted
deb $ARTIFACTORY_URL/artifactory/$REPOSITORY_KEY_PREFIX-debian/ $distro-security universe
deb $ARTIFACTORY_URL/artifactory/$REPOSITORY_KEY_PREFIX-debian/ $distro-security multiverse
EOF
    elif [ -f /etc/redhat-release ]; then
        # Red Hat 或 CentOS
        cat <<EOF | sudo tee /etc/yum.repos.d/jfrog.repo
[jfrog]
name=JFrog Artifactory
baseurl=$ARTIFACTORY_URL/artifactory/$REPOSITORY_KEY_PREFIX-rpm/
enabled=1
gpgcheck=0
EOF
    else
        echo -e "Unsupported package manager. Neither APT nor RPM."
    fi
}

# pip (Python) 仓库配置
configure_pip() {
    if command -v pip &>/dev/null; then
        mkdir -p ~/.pip

        # 设置超时时间，例如30秒
        local timeout=300

        echo -e "[global]
trusted-host = $ARTIFACTORY_HOST
index-url = $ARTIFACTORY_URL/artifactory/api/pypi/$REPOSITORY_KEY_PREFIX-pypi/simple
timeout = $timeout" > ~/.pip/pip.conf
    else
        echo -e "pip not found, skipping pip repository configuration."
    fi
}

# conda (Anaconda) 仓库配置
configure_conda() {
    if command -v conda &>/dev/null; then
        echo -e "channels:\n  - $ARTIFACTORY_URL/artifactory/api/conda/$REPOSITORY_KEY_PREFIX-conda" >> ~/.condarc
    else
        echo -e "conda not found, skipping conda repository configuration."
    fi
}

# npm (Node.js) 仓库配置
configure_npm() {
    if command -v npm &>/dev/null; then
        echo -e "registry=$ARTIFACTORY_URL/artifactory/api/npm/$REPOSITORY_KEY_PREFIX-npm/" >> ~/.npmrc
    else
        echo -e "npm not found, skipping npm repository configuration."
    fi
}

# Hugging Face 仓库配置
configure_huggingface() {
    echo -e "Hugging Face repository configuration is not standard and should be handled manually."
}

# 执行配置
# configure_docker
configure_package_manager
configure_pip
configure_conda
configure_npm
configure_huggingface

echo -e "All repositories configured successfully."
