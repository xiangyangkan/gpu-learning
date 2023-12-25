#!/bin/bash

if [ -n "$ARTIFACTORY_URL" ]; then
    ARTIFACTORY_HOST=$(echo -e "$ARTIFACTORY_URL" | awk -F[/:] '{print $4}')
fi

# APT (Debian/Ubuntu) 或 RPM (Red Hat/CentOS) 仓库配置
configure_package_manager() {
    if [ -f /etc/debian_version ]; then
        # 获取发行版代号，如 'jammy'
        local distro
        distro=$(grep VERSION_CODENAME /etc/os-release | cut -d'=' -f2)

        # 获取仓库 key
        local repo_key
        if [ "$REPOSITORY_KEY_PREFIX" != "" ]; then
            repo_key="$REPOSITORY_KEY_PREFIX-debian"
        else
            repo_key="debian"
        fi

        # 配置 APT 源
        cat <<EOF | sudo tee /etc/apt/sources.list.d/jfrog.list
deb [trusted=yes] $ARTIFACTORY_URL/artifactory/$repo_key/ $distro main restricted
deb [trusted=yes] $ARTIFACTORY_URL/artifactory/$repo_key/ $distro-updates main restricted
deb [trusted=yes] $ARTIFACTORY_URL/artifactory/$repo_key/ $distro universe
deb [trusted=yes] $ARTIFACTORY_URL/artifactory/$repo_key/ $distro-updates universe
deb [trusted=yes] $ARTIFACTORY_URL/artifactory/$repo_key/ $distro multiverse
deb [trusted=yes] $ARTIFACTORY_URL/artifactory/$repo_key/ $distro-updates multiverse
deb [trusted=yes] $ARTIFACTORY_URL/artifactory/$repo_key/ $distro-backports main restricted universe multiverse
deb [trusted=yes] $ARTIFACTORY_URL/artifactory/$repo_key/ $distro-security main restricted
deb [trusted=yes] $ARTIFACTORY_URL/artifactory/$repo_key/ $distro-security universe
deb [trusted=yes] $ARTIFACTORY_URL/artifactory/$repo_key/ $distro-security multiverse
EOF
        # 备份原有源
        mv /etc/apt/sources.list /etc/apt/sources.list.bak
    elif [ -f /etc/redhat-release ]; then
        # 获取仓库 key
        local repo_key
        if [ "$REPOSITORY_KEY_PREFIX" != "" ]; then
            repo_key="$REPOSITORY_KEY_PREFIX-rpm"
        else
            repo_key="rpm"
        fi

        # Red Hat 或 CentOS
        cat <<EOF | sudo tee /etc/yum.repos.d/jfrog.repo
[jfrog]
name=JFrog Artifactory
baseurl=$ARTIFACTORY_URL/artifactory/$repo_key/
enabled=1
gpgcheck=0
EOF
        # 备份原有源
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
    else
        echo -e "Unsupported package manager. Neither APT nor RPM."
    fi
}

# pip (Python) 仓库配置
configure_pip() {
    if command -v pip &>/dev/null; then
        mkdir -p ~/.pip
        local timeout=300
        local repo_key
        if [ "$REPOSITORY_KEY_PREFIX" != "" ]; then
            repo_key="$REPOSITORY_KEY_PREFIX-pypi"
        else
            repo_key="pypi"
        fi

        pip_conf_list=(
          "$HOME/.pip/pip.conf"
          "$HOME/.config/pip/pip.conf"
          "/etc/pip.conf"
          "/etc/xdg/pip/pip.conf"
          "/usr/pip.conf"
        )

        for pip_conf_path in "${pip_conf_list[@]}"; do
            if [ -f "$pip_conf_path" ]; then
                echo -e "pip configuration file found, backing up..."
                mv "$pip_conf_path" "${pip_conf_path}.bak"
            fi
                echo -e "[global]
trusted-host = $ARTIFACTORY_HOST
index-url = $ARTIFACTORY_URL/artifactory/api/pypi/$repo_key/simple
timeout = $timeout" > "$pip_conf_path"
        done
    else
        echo -e "pip not found, skipping pip repository configuration."
    fi
}

# conda (Anaconda) 仓库配置
configure_conda() {
    if command -v conda &>/dev/null; then
        local repo_key
        if [ "$REPOSITORY_KEY_PREFIX" != "" ]; then
            repo_key="$REPOSITORY_KEY_PREFIX-conda"
        else
            repo_key="conda"
        fi
        if [ -f ~/.condarc ]; then
            echo -e "conda configuration file found, backing up..."
            mv ~/.condarc ~/.condarc.bak
        fi
        local repo_url="$ARTIFACTORY_URL/artifactory/$repo_key"
        echo -e "channels:
  - defaults
show_channel_urls: true
default_channels:
  - $repo_url
custom_channels:
  conda-forge: $repo_url
  nvidia: $repo_url
  pytorch: $repo_url
channel_alias: $repo_url
ssl_verify: false " >> ~/.condarc
    else
        echo -e "conda not found, skipping conda repository configuration."
    fi
}

# npm (Node.js) 仓库配置
configure_npm() {
    if command -v npm &>/dev/null; then
        local repo_key
        if [ "$REPOSITORY_KEY_PREFIX" != "" ]; then
            repo_key="$REPOSITORY_KEY_PREFIX-npm"
        else
            repo_key="npm"
        fi
        if [ -f ~/.npmrc ]; then
            echo -e "npm configuration file found, backing up..."
            mv ~/.npmrc ~/.npmrc.bak
        fi
        echo -e "registry=$ARTIFACTORY_URL/artifactory/api/npm/$repo_key/" >> ~/.npmrc
    else
        echo -e "npm not found, skipping npm repository configuration."
    fi
}

# Hugging Face 仓库配置
configure_huggingface() {
    echo -e "Hugging Face repository configuration is not standard and should be handled manually."
}

# 执行配置
if [[ -z "$ARTIFACTORY_URL" ]]; then
    echo -e "environment variables ARTIFACTORY_URL not set, skipping repository configuration."
else
    configure_package_manager
    configure_pip
    configure_conda
    configure_npm
    configure_huggingface
    echo -e "All repositories configured successfully."
fi