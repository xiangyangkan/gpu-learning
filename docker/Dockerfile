ARG BASE_IMAGE=nvcr.io/nvidia/pytorch:23.12-py3

# add sshd support
# no key arguement for the base image
FROM ${BASE_IMAGE} as base

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Needed for string substitution
SHELL ["/bin/bash", "-c"]

# change timezone
ARG TZ="Asia/Shanghai"
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo ${TZ} > /etc/timezone

# supervisor config
RUN mkdir -p /var/run/sshd
COPY supervisord.conf /

# SSH config
ARG UBUNTU_MIRROR=http://launchpadlibrarian.net
ARG UPDATE_CUDA_SOURCE=true
ARG ARCH=x86_64
RUN if [ "${UPDATE_CUDA_SOURCE}" = "true" ]; then \
        apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub; \
    fi
RUN apt-get update --fix-missing && apt-get install --allow-unauthenticated -y \
    openssh-server pwgen supervisor proxychains redsocks libnfnetlink0 && \
    if [ "${ARCH}" = "aarch64" ]; then \
        iptables_installer="iptables_1.6.0-2ubuntu3_arm64.deb"; \
        libxtables_installer="libxtables11_1.6.0-2ubuntu3_arm64.deb"; \
        wget --quiet "${UBUNTU_MIRROR}/240591460/${iptables_installer}"; \
        wget --quiet "${UBUNTU_MIRROR}/240591461/${libxtables_installer}"; \
    else \
        iptables_installer="iptables_1.6.0-2ubuntu3_amd64.deb"; \
        libxtables_installer="libxtables11_1.6.0-2ubuntu3_amd64.deb"; \
        wget --quiet "${UBUNTU_MIRROR}/240591163/${iptables_installer}"; \
        wget --quiet "${UBUNTU_MIRROR}/240591164/${libxtables_installer}"; \
    fi && \
    dpkg -i ${libxtables_installer} ${iptables_installer} && \
    rm ${libxtables_installer} ${iptables_installer} && \
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

COPY proxychains.conf /etc/proxychains.conf
COPY redsocks.conf /etc/redsocks.conf
COPY bashrc /etc/bash.bashrc
COPY configure_repos.sh /configure_repos.sh
RUN chmod a+rwx /etc/bash.bashrc && chmod +x /configure_repos.sh
RUN env | egrep -v "^(LS_COLORS=|SSH_CONNECTION=|USER=|PWD=|HOME=|SSH_CLIENT=|SSH_TTY=|MAIL=|TERM=|SHELL=|SHLVL=|LOGNAME=|PS1=|_=)" > /etc/environment

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]

# add conda
# key arguement for the conda image: PYTHON_VERSION, CONDA_VERSION
FROM ${BASE_IMAGE} as conda

# install conda
ENV PYTHON_VERSION=${PYTHON_VERSION:-3.10}
ENV CONDA_DIR=/opt/conda
ENV PATH="${CONDA_DIR}/bin:${PATH}"
ARG CONDA_MIRROR=https://repo.anaconda.com/miniconda
ARG CONDA_VERSION=23.11.0-2
RUN set -x && \
    # Miniforge installer
    miniforge_arch=$(uname -m) && \
    miniforge_installer="Miniconda3-py${PYTHON_VERSION//./}_${CONDA_VERSION}-Linux-${miniforge_arch}.sh" && \
    wget --quiet "${CONDA_MIRROR}/${miniforge_installer}" && \
    /bin/bash "${miniforge_installer}" -f -b -p "${CONDA_DIR}" && \
    rm "${miniforge_installer}" && \
    # Conda configuration see https://conda.io/projects/conda/en/latest/configuration.html
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    mamba list python | grep '^python ' | tr -s ' ' | cut -d ' ' -f 1,2 >> "${CONDA_DIR}/conda-meta/pinned" && \
    # Using conda to update all packages: https://github.com/mamba-org/mamba/issues/1092
    conda clean --all -f -y

# add cmake and bazelisk
# key arguement for the build image: CMAKE_VERSION, BAZELISK_VERSION
FROM ${BASE_IMAGE} as build

# install cmake
ARG CMAKE_VERSION=3.26.5
ARG CMAKE_MIRROR=https://github.com/Kitware/CMake/releases/download
ENV CMAKE_DIR=/usr/local
RUN set -x && \
    cmake_sh="cmake-${CMAKE_VERSION}-Linux-x86_64.sh" && \
    wget --quiet "${CMAKE_MIRROR}/v${CMAKE_VERSION}/${cmake_sh}" && \
    chmod +x ${cmake_sh} && \
    ./${cmake_sh} --prefix=${CMAKE_DIR} --exclude-subdir --skip-license && \
    rm ${cmake_sh}

# install bazelisk
ARG BAZELISK_VERSION=1.18.0
ENV GOPATH=/usr/local/go
ENV PATH=$PATH:$GOPATH/bin
RUN apt-get update --fix-missing && \
    apt-get install --no-install-recommends --allow-unauthenticated -y software-properties-common gnupg && \
    add-apt-repository -y ppa:longsleep/golang-backports && \
    apt-get update --fix-missing && \
    apt-get install --no-install-recommends --allow-unauthenticated -y \
      golang \
      libssl-dev \
      libmbedtls-dev \
      autoconf \
      && \
    go install github.com/bazelbuild/bazelisk@v$BAZELISK_VERSION && \
    ln -s /usr/local/go/bin/bazelisk /usr/local/go/bin/bazel

# add gst-python, pyds and ffmpeg
# key arguement for the deepstream image: ARCH, DEEPSTREAM_VERSION, PYDS_VERSION
FROM ${BASE_IMAGE} as deepstream

# install gst-python and pyds
ARG ARCH=x86_64
ARG DEEPSTREAM_VERSION=6.4-triton-multiarch
ARG PYDS_MIRROR=https://github.com/NVIDIA-AI-IOT/deepstream_dockers/blob/dev/ds
ARG PYDS_VERSION=1.1.10
RUN set -x && \
    version="${DEEPSTREAM_VERSION%%-*}" && \
    echo "version=${version}" && \
    installer_sh="user_deepstream_python_apps_install.sh" && \
    wget --quiet "${PYDS_MIRROR}/ds${version}/${ARCH}/${installer_sh}" && \
    chmod +x ${installer_sh} && \
    ./${installer_sh} --version "${PYDS_VERSION}" && \
    rm ${installer_sh}

# install ffmpeg
RUN sed -i "s/deb https\:\/\/developer/# deb https\:\/\/developer/g" /etc/apt/sources.list && \
    apt-get update --fix-missing && apt-get install --no-install-recommends --allow-unauthenticated -y \
      libpython${PYTHON_VERSION}-dev \
      python-gi-dev \
      libgirepository1.0-dev \
      libcairo2-dev \
      apt-transport-https \
      ca-certificates \
      ffmpeg  \
      && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# set tensorrt library environments
# no key arguement for the tensorrt image
FROM ${BASE_IMAGE} as tensorrt

# Set environment and working directory
# key arguement for the tensorrt image: TRT_LIBPATH, TRT_OSSPATH
ENV TRT_LIBPATH=${TRT_LIBPATH:-/usr/lib/x86_64-linux-gnu}
ENV TRT_OSSPATH=${TRT_OSSPATH:-/usr/local/tensorrt/lib}
ENV PATH="${PATH}:/usr/local/bin/ngc-cli"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${TRT_OSSPATH}:${TRT_LIBPATH}"

# add extra dependencies and jupyter lab
# key arguement for the devel image: PYTHON_VERSION
FROM base as devel

# extra dependencies
ENV PYTHON_VERSION=${PYTHON_VERSION:-3.10}
COPY python_requirements.txt debian_requirements.txt /
RUN apt-get update --fix-missing && \
    cat /debian_requirements.txt | xargs apt-get install -y --no-install-recommends --allow-unauthenticated && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --upgrade pip && \
    ln -snf /usr/local/bin/pip /usr/bin/pip${PYTHON_VERSION} && \
    pip install --no-cache-dir -r /python_requirements.txt

# jupyter lab config
COPY jupyter_server_config.py /root/.jupyter/
COPY jupyter_notebook_config.py /root/.jupyter/
COPY run_jupyter.sh /
RUN chmod +x /run_jupyter.sh && \
    pip install --upgrade requests && \
    pip install --no-cache-dir jupyter_http_over_ws && \
    jupyter-server extension enable --py jupyter_http_over_ws && \
    python3 -m ipykernel.kernelspec
EXPOSE 8888

# deal with vim and matplotlib Mojibake
COPY simhei.ttf /opt/conda/lib/python${PYTHON_VERSION}/site-packages/matplotlib/mpl-data/fonts/ttf/
RUN echo "set encoding=utf-8 nobomb" >> /etc/vim/vimrc && \
    echo "set termencoding=utf-8" >> /etc/vim/vimrc && \
    echo "set fileencodings=utf-8,gbk,utf-16le,cp1252,iso-8859-15,ucs-bom" >> /etc/vim/vimrc && \
    echo "set fileformats=unix,dos,mac" >> /etc/vim/vimrc && \
    rm -rf /root/.cache/matplotlib
