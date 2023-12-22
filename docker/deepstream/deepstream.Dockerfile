ARG DEEPSTREAM_VERSION=6.3-triton-multiarch
FROM nvcr.io/nvidia/deepstream:${DEEPSTREAM_VERSION}

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PYTHON_VERSION=3.8
ENV DEEPSTREAM_VERSION=6.3-triton-multiarch

# Needed for string substitution
SHELL ["/bin/bash", "-c"]

# change timezone
ARG TZ="Asia/Shanghai"
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo ${TZ} > /etc/timezone


# extra dependencies
COPY python_requirements.txt debian_requirements.txt /
RUN apt-get update --fix-missing && \
    cat /debian_requirements.txt | xargs apt-get install -y --no-install-recommends --allow-unauthenticated && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --user --upgrade pip && \
    ln -s /usr/local/bin/pip /usr/bin/pip${PYTHON_VERSION} && \
    pip install --no-cache-dir -r /python_requirements.txt


# install gst-python and pyds
ARG ARCH=x86_64
ARG PYDS_MIRROR=https://github.com/NVIDIA-AI-IOT/deepstream_dockers/blob/dev/ds
RUN set -x && \
    version="${DEEPSTREAM_VERSION%%-*}" && \
    echo "version=${version}" && \
    installer_sh="user_deepstream_python_apps_install.sh" && \
    wget --quiet "${PYDS_MIRROR}/ds${version}/${ARCH}/${installer_sh}" && \
    chmod +x ${installer_sh} && \
    ./${installer_sh} --build-bindings -r "dev/ds/ds${version}" && \
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


# SSH config
RUN apt-get update --fix-missing && apt-get install --no-install-recommends --allow-unauthenticated -y \
    openssh-server pwgen && \
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


# jupyter lab config
COPY jupyter_server_config.py /root/.jupyter/
COPY jupyter_notebook_config.py /root/.jupyter/
COPY run_jupyter.sh /
RUN chmod +x /run_jupyter.sh && \
    pip install --upgrade requests && \
    pip install --no-cache-dir jupyter_http_over_ws && \
    jupyter-server extension enable --py jupyter_http_over_ws && \
    python3 -m ipykernel.kernelspec


# deal with vim and matplotlib Mojibake
COPY simhei.ttf /opt/conda/lib/python${PYTHON_VERSION}/site-packages/matplotlib/mpl-data/fonts/ttf/
RUN echo "set encoding=utf-8 nobomb" >> /etc/vim/vimrc && \
    echo "set termencoding=utf-8" >> /etc/vim/vimrc && \
    echo "set fileencodings=utf-8,gbk,utf-16le,cp1252,iso-8859-15,ucs-bom" >> /etc/vim/vimrc && \
    echo "set fileformats=unix,dos,mac" >> /etc/vim/vimrc && \
    rm -rf /root/.cache/matplotlib

# supervisor config
RUN mkdir /var/run/sshd && \
    apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends --allow-unauthenticated supervisor
COPY supervisord.conf /

EXPOSE 8888

COPY proxychains.conf /etc/proxychains.conf
COPY bashrc /etc/bash.bashrc
COPY configure_repos.sh /configure_repos.sh
RUN chmod a+rwx /etc/bash.bashrc && chmod +x /configure_repos.sh
RUN env | egrep -v "^(LS_COLORS=|SSH_CONNECTION=|USER=|PWD=|HOME=|SSH_CLIENT=|SSH_TTY=|MAIL=|TERM=|SHELL=|SHLVL=|LOGNAME=|PS1=|_=)" > /etc/environment

ENTRYPOINT ["/usr/bin/supervisord", "-c"]

CMD ["/supervisord.conf"]