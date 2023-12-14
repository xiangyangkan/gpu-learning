#!/bin/bash

# 检测操作系统类型
OS_TYPE=$(awk -F= '/^ID=/{print $2}' /etc/os-release)

# 定义配置文件路径
DEBIAN_CONFIG_FILE="/etc/apt/sources.list.d/jfrog.list"
REDHAT_CONFIG_FILE="/etc/yum.repos.d/jfrog.repo"
PIP_CONFIG_FILE="$HOME/.pip/pip.conf"
CONDA_CONFIG_FILE="$HOME/.condarc"
NPM_CONFIG_FILE="$HOME/.npmrc"

# 检查环境变量 REPO_HOST 是否已设置
if [ -z "$REPO_HOST" ]; then
    echo "环境变量 REPO_HOST 未设置。"

    # 根据操作系统类型屏蔽本地源配置文件
    if [[ $OS_TYPE == "ubuntu" || $OS_TYPE == "debian" ]]; then
        if [ -f "$DEBIAN_CONFIG_FILE" ]; then
            echo "正在屏蔽 Debian/Ubuntu 源配置文件..."
            sudo mv "$DEBIAN_CONFIG_FILE" "${DEBIAN_CONFIG_FILE}.disabled"
        else
            echo "未找到 Debian/Ubuntu 源配置文件."
        fi
    elif [[ $OS_TYPE == "centos" || $OS_TYPE == "rhel" ]]; then
        if [ -f "$REDHAT_CONFIG_FILE" ]; then
            echo "正在屏蔽 Red Hat/CentOS 源配置文件..."
            sudo mv "$REDHAT_CONFIG_FILE" "${REDHAT_CONFIG_FILE}.disabled"
        else
            echo "未找到 Red Hat/CentOS 源配置文件."
        fi
    else
        echo "不支持的操作系统类型: $OS_TYPE"
    fi

    # 屏蔽 pip 配置
    if [ -f "$PIP_CONFIG_FILE" ]; then
        echo "正在屏蔽 pip 配置文件..."
        mv "$PIP_CONFIG_FILE" "${PIP_CONFIG_FILE}.disabled"
    else
        echo "未找到 pip 配置文件."
    fi

    if [ -f "$CONDA_CONFIG_FILE" ]; then
        echo "正在屏蔽 conda 配置文件..."
        mv "$CONDA_CONFIG_FILE" "${CONDA_CONFIG_FILE}.disabled"
    else
        echo "未找到 conda 配置文件."
    fi

    if [ -f "$NPM_CONFIG_FILE" ]; then
        echo "正在屏蔽 npm 配置文件..."
        mv "$NPM_CONFIG_FILE" "${NPM_CONFIG_FILE}.disabled"
    else
        echo "未找到 npm 配置文件."
    fi

    exit 1
fi

# 准备要添加的 hosts 记录
HOST_ENTRY="$REPO_HOST jfrog.local"

# 检查记录是否已存在
if grep -q "jfrog.local" /etc/hosts; then
    echo "jfrog.local 已存在于 /etc/hosts 中，正在更新记录..."
    # 使用 sed 命令更新现有记录
    sudo sed -i "/jfrog.local/c\\$HOST_ENTRY" /etc/hosts
else
    echo "在 /etc/hosts 中添加新记录：$HOST_ENTRY"
    # 将新记录追加到 /etc/hosts
    echo "$HOST_ENTRY" | sudo tee -a /etc/hosts > /dev/null
fi

echo "完成。"
