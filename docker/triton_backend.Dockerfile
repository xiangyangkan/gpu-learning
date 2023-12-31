ARG NGC_VERSION=22.04
FROM nvcr.io/nvidia/tritonserver:${NGC_VERSION}-py3

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PYTHON_VERSION=3.8

# Needed for string substitution
SHELL ["/bin/bash", "-c"]

# change timezone
ARG TZ="Asia/Shanghai"
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo ${TZ} > /etc/timezone


# install conda
ENV CONDA_DIR=/opt/conda
ENV PATH="${CONDA_DIR}/bin:${PATH}"
# ARG CONDA_MIRROR=https://github.com/conda-forge/miniforge/releases/latest/download
ARG CONDA_MIRROR=https://repo.anaconda.com/miniconda
# Specify Python 3.8 Version
ARG CONDA_VERSION=4.12.0
RUN set -x && \
    # Miniforge installer
    miniforge_arch=$(uname -m) && \
    # miniforge_installer="Mambaforge-Linux-${miniforge_arch}.sh" && \
    miniforge_installer="Miniconda3-py38_${CONDA_VERSION}-Linux-${miniforge_arch}.sh" && \
    wget --quiet "${CONDA_MIRROR}/${miniforge_installer}" && \
    /bin/bash "${miniforge_installer}" -f -b -p "${CONDA_DIR}" && \
    rm "${miniforge_installer}" && \
    # Conda configuration see https://conda.io/projects/conda/en/latest/configuration.html
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    mamba list python | grep '^python ' | tr -s ' ' | cut -d ' ' -f 1,2 >> "${CONDA_DIR}/conda-meta/pinned" && \
    # Using conda to update all packages: https://github.com/mamba-org/mamba/issues/1092
    conda update --all --quiet --yes && \
    conda install numpy conda-pack && \
    conda clean --all -f -y


# extra dependencies
COPY python_requirements.txt debian_requirements.txt /
# NVIDIA has updated its signing keys as of April 27, 2022
RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub && \
    apt-get update --fix-missing && \
    cat /debian_requirements.txt | xargs apt-get install -y --no-install-recommends --allow-unauthenticated && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --user --upgrade pip && \
    pip install --no-cache-dir -r /python_requirements.txt


# install cmake
ENV CMAKE_VERSION=3.22.3
ENV CMAKE_DIR=/usr/local
ARG CMAKE_MIRROR=https://github.com/Kitware/CMake/releases/download
RUN set -x && \
    cmake_sh="cmake-${CMAKE_VERSION}-Linux-x86_64.sh" && \
    wget --quiet "${CMAKE_MIRROR}/v${CMAKE_VERSION}/${cmake_sh}" && \
    chmod +x ${cmake_sh} && \
    ./${cmake_sh} --prefix=${CMAKE_DIR} --exclude-subdir --skip-license && \
    rm ${cmake_sh}


# install bazelisk
ENV GOPATH=/usr/local/go
ENV PATH=$PATH:$GOPATH/bin
RUN add-apt-repository -y ppa:longsleep/golang-backports && \
    apt-get update --fix-missing && \
    apt-get install --no-install-recommends --allow-unauthenticated -y \
      golang \
      libssl-dev \
      libmbedtls-dev \
      autoconf \
      && \
    go install github.com/bazelbuild/bazelisk@latest && \
    ln -s /usr/local/go/bin/bazelisk /usr/local/go/bin/bazel

# supervisor config
RUN mkdir /var/run/sshd
COPY supervisord.conf /

# SSH config
RUN apt-get update --fix-missing && apt-get install --no-install-recommends --allow-unauthenticated -y \
    openssh-server pwgen supervisor rapidjson-dev libarchive-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    sed -i "s/.*UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config && \
    sed -i "s/.*UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config && \
    sed -i "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config && \
    sed -i "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
COPY set_root_pw.sh run_ssh.sh /
RUN chmod +x /*.sh && sed -i -e 's/\r$//' /*.sh
ENV AUTHORIZED_KEYS **None**
EXPOSE 22

COPY bashrc /etc/bash.bashrc
RUN chmod a+rwx /etc/bash.bashrc
RUN env | egrep -v "^(NVIDIA_BUILD_ID=|LS_COLORS=|SSH_CONNECTION=|USER=|PWD=|HOME=|SSH_CLIENT=|SSH_TTY=|MAIL=|TERM=|SHELL=|SHLVL=|LOGNAME=|PS1=|_=)" > /etc/environment

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]