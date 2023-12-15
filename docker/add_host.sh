#!/bin/bash

# 定义配置文件路径
DEBIAN_CONFIG_FILE="/etc/apt/sources.list.d/jfrog.list"
REDHAT_CONFIG_FILE="/etc/yum.repos.d/jfrog.repo"
PIP_CONFIG_FILE="$HOME/.pip/pip.conf"
CONDA_CONFIG_FILE="$HOME/.condarc"
NPM_CONFIG_FILE="$HOME/.npmrc"

# 检查环境变量 REPO_HOST 是否已设置
if [ -z "$REPO_HOST" ]; then
    echo -e "environment variable REPO_HOST not set, skipping host configuration."

    # 屏蔽 APT 或 YUM 配置
    if [ -f /etc/debian_version ]; then
        # Debian 或 Ubuntu
        if [ -f "$DEBIAN_CONFIG_FILE" ]; then
            echo -e "Disabling APT source configuration..."
            mv "$DEBIAN_CONFIG_FILE" "${DEBIAN_CONFIG_FILE}.disabled"
        else
            echo -e "APT source configuration file not found."
        fi
    elif [ -f /etc/redhat-release ]; then
        # Red Hat 或 CentOS
        if [ -f "$REDHAT_CONFIG_FILE" ]; then
            echo -e "Disabling YUM source configuration..."
            mv "$REDHAT_CONFIG_FILE" "${REDHAT_CONFIG_FILE}.disabled"
        else
            echo -e "YUM source configuration file not found."
        fi
    else
        echo -e "Unsupported package manager. Neither APT nor YUM."
    fi

    # 屏蔽 pip 配置
    if command -v pip &>/dev/null; then
        if [ -f "$PIP_CONFIG_FILE" ]; then
            echo -e "Disabling pip configuration..."
            mv "$PIP_CONFIG_FILE" "${PIP_CONFIG_FILE}.disabled"
        else
            echo -e "pip configuration file not found."
        fi
    else
        echo -e "pip not found, skipping pip repository configuration."
    fi

    # 屏蔽 conda 配置
    if command -v conda &>/dev/null; then
        if [ -f "$CONDA_CONFIG_FILE" ]; then
            echo -e "Disabling conda configuration..."
            mv "$CONDA_CONFIG_FILE" "${CONDA_CONFIG_FILE}.disabled"
        else
            echo -e "conda configuration file not found."
        fi
    else
        echo -e "conda not found, skipping conda repository configuration."
    fi

    # 屏蔽 npm 配置
    if command -v npm &>/dev/null; then
        if [ -f "$NPM_CONFIG_FILE" ]; then
            echo -e "Disabling npm configuration..."
            mv "$NPM_CONFIG_FILE" "${NPM_CONFIG_FILE}.disabled"
        else
            echo -e "npm configuration file not found."
        fi
    else
        echo -e "npm not found, skipping npm repository configuration."
    fi

    exit 0
fi

# 准备要添加的 hosts 记录
HOST_ENTRY="$REPO_HOST jfrog.local"

# 检查记录是否已存在
if grep -q "jfrog.local" /etc/hosts; then
    echo -e "update /etc/hosts with $HOST_ENTRY"
    # 使用 sed 命令更新现有记录
    sudo sed -i "/jfrog.local/c\\$HOST_ENTRY" /etc/hosts
else
    echo "add $HOST_ENTRY to /etc/hosts"
    # 将新记录追加到 /etc/hosts
    echo -e "$HOST_ENTRY" | sudo tee -a /etc/hosts > /dev/null
fi