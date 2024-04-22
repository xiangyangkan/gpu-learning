#!/bin/bash

if [ -n "$ARTIFACTORY_URL" ]; then
    ARTIFACTORY_HOST=$(echo -e "$ARTIFACTORY_URL" | awk -F[/:] '{print $4}')
fi

# APT (Debian/Ubuntu) 或 RPM (Red Hat/CentOS) 仓库配置
# 需要在/usr/local/share/ca-certificates/目录下放置证书文件
function configure_package_manager() {
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
        echo -e "apt configuration file written to /etc/apt/sources.list.d/jfrog.list"
        # 备份原有源
        local config_file="/etc/apt/sources.list"
        local backup_file="/etc/apt/sources.list.bak"
        if [ -f "$backup_file" ]; then
            echo -e "backup file $backup_file found, skipping backup..."
        else
            mv "$config_file" "$backup_file"
        fi
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
        echo -e "yum configuration file written to /etc/yum.repos.d/jfrog.repo"
        # 备份原有源
        local config_file="/etc/yum.repos.d/CentOS-Base.repo"
        local backup_file="/etc/yum.repos.d/CentOS-Base.repo.bak"
        if [ -f "$backup_file" ]; then
            echo -e "backup file $backup_file found, skipping backup..."
        else
            mv "$config_file" "$backup_file"
        fi
    else
        echo -e "Unsupported package manager. Neither APT nor RPM."
    fi
}

# pip (Python) 仓库配置
# pip 本地代理下载无进度条显示，超时时间设置为 600 秒
function configure_pip() {
    if command -v pip &>/dev/null; then
        mkdir -p "$HOME/.pip"
        local timeout=600
        local repo_key
        local config_updated=0
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
                echo -e "pip configuration $pip_conf_path found, backing up..."
                local backup_file="${pip_conf_path}.bak"
                if [ -f "$backup_file" ]; then
                    echo -e "backup file $backup_file found, skipping backup..."
                else
                    mv "$pip_conf_path" "$backup_file"
                fi
                echo -e "[global]
trusted-host = $ARTIFACTORY_HOST
index-url = $ARTIFACTORY_URL/artifactory/api/pypi/$repo_key/simple
extra-index-url = https://pypi.org/simple
timeout = $timeout" > "$pip_conf_path"
                echo -e "pip configuration file written to $pip_conf_path"
                config_updated=1
            fi
        done

        # 如果没有更新任何配置文件，则在 $HOME/.pip/pip.conf 写入配置
        if [ "$config_updated" -eq 0 ]; then
            local pip_conf_default="$HOME/.pip/pip.conf"
            echo -e "[global]
trusted-host = $ARTIFACTORY_HOST
index-url = $ARTIFACTORY_URL/artifactory/api/pypi/$repo_key/simple
extra-index-url = https://pypi.org/simple
timeout = $timeout" > "$pip_conf_default"
            echo -e "pip configuration file written to $pip_conf_default"
        fi
    else
        echo -e "pip not found, skipping pip repository configuration."
    fi
}

# conda (Anaconda) 仓库配置
# conda 本地代理下载无进度条显示，超时时间设置为 600 秒
function configure_conda() {
    if command -v conda &>/dev/null; then
        local repo_key
        if [ "$REPOSITORY_KEY_PREFIX" != "" ]; then
            repo_key="$REPOSITORY_KEY_PREFIX-conda"
        else
            repo_key="conda"
        fi
        local config_file="$HOME/.condarc"
        local backup_file="$HOME/.condarc.bak"
        if [ -f "$config_file" ]; then
            echo -e "conda configuration file found, backing up..."
            if [ -f "$backup_file" ]; then
                echo -e "backup file $backup_file found, skipping backup..."
            else
                mv "$config_file" "$backup_file"
            fi
        fi
        local default_repo_url="$ARTIFACTORY_URL/artifactory/$repo_key-remote"
        local conda_forge_repo_url="$ARTIFACTORY_URL/artifactory/$repo_key-forge-remote"
        local nvidia_repo_url="$ARTIFACTORY_URL/artifactory/$repo_key-nvidia-remote"
        local pytorch_repo_url="$ARTIFACTORY_URL/artifactory/$repo_key-pytorch-remote"
        echo -e "
show_channel_urls: true
default_channels:
  - $default_repo_url
custom_channels:
  conda-forge: $conda_forge_repo_url
  nvidia: $nvidia_repo_url
  pytorch: $pytorch_repo_url
ssl_verify: false
remote_read_timeout_secs: 600 " > "$config_file"
        echo -e "conda configuration file written to $config_file"
    else
        echo -e "conda not found, skipping conda repository configuration."
    fi
}

# npm (Node.js) 仓库配置
function configure_npm() {
    if command -v npm &>/dev/null; then
        local repo_key
        if [ "$REPOSITORY_KEY_PREFIX" != "" ]; then
            repo_key="$REPOSITORY_KEY_PREFIX-npm"
        else
            repo_key="npm"
        fi
        local config_file="$HOME/.npmrc"
        local backup_file="$HOME/.npmrc.bak"
        if [ -f "$config_file" ]; then
            echo -e "npm configuration file found, backing up..."
            if [ -f "$backup_file" ]; then
                echo -e "backup file $backup_file found, skipping backup..."
            else
                mv "$config_file" "$backup_file"
            fi
        fi
        echo -e "registry=$ARTIFACTORY_URL/artifactory/api/npm/$repo_key/
strict-ssl=false" >> "$config_file"
        echo -e "npm configuration file written to $config_file"
    else
        echo -e "npm not found, skipping npm repository configuration."
    fi
}

# Hugging Face 仓库配置
function configure_huggingface() {
    echo -e "Hugging Face repository configuration is not standard and should be handled manually."
}

function update_ssl_certificate() {
    url=$1

    # 默认端口是 443
    port=443

    # 解析 URL
    if [[ $url =~ ^https?://([^:/]+)(:([0-9]+))?$ ]]; then
        hostname=${BASH_REMATCH[1]}
        [ -n "${BASH_REMATCH[3]}" ] && port=${BASH_REMATCH[3]}
    elif [[ $url =~ ^([^:/]+)(:([0-9]+))?$ ]]; then
        hostname=${BASH_REMATCH[1]}
        [ -n "${BASH_REMATCH[3]}" ] && port=${BASH_REMATCH[3]}
    else
        echo -e "invalid url: $url"
        return 1
    fi

    cert_file="$hostname.crt"
    echo -e "obtaining certificate for $hostname:$port"

    # 使用 OpenSSL 获取并保存证书
    echo | openssl s_client -servername "$hostname" -connect "$hostname:$port" 2>/dev/null | openssl x509 > "$cert_file"
    if [ ! -f "$cert_file" ]; then
        echo -e "failed to obtain certificate for $hostname:$port"
        return 1
    fi
    echo -e "certificate saved to $cert_file"

    # 根据操作系统类型，更新证书存储
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        mkdir -p /usr/local/share/ca-certificates/
        sudo mv "$cert_file" /usr/local/share/ca-certificates/
        sudo update-ca-certificates
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RedHat
        mkdir -p /etc/pki/ca-trust/source/anchors/
        sudo mv "$cert_file" /etc/pki/ca-trust/source/anchors/
        sudo update-ca-trust extract
    else
        echo -e "Unsupported package manager. Neither APT nor RPM."
        return 1
    fi

    echo -e "certificate updated successfully"
}

function add_transparent_proxy() {
  sudo iptables -t nat -N REDSOCKS
  sudo iptables -t nat -A REDSOCKS -d 0.0.0.0/8 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 10.0.0.0/8 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 100.64.0.0/10 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 127.0.0.0/8 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 169.254.0.0/16 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 172.16.0.0/12 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 192.168.0.0/16 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 198.18.0.0/15 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 224.0.0.0/4 -j RETURN
  sudo iptables -t nat -A REDSOCKS -d 240.0.0.0/4 -j RETURN
  sudo iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports 12345
  sudo iptables -t nat -A OUTPUT -p tcp -j REDSOCKS
  sudo service redsocks restart
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
    update_ssl_certificate "$ARTIFACTORY_URL"
    echo -e "All repositories configured successfully."

    if [[ -n "$TRANSPARENT_PROXY" ]]; then
      add_transparent_proxy
    fi
fi