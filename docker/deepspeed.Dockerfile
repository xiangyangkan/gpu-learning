FROM deepspeed/deepspeed:latest

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PYTHON_VERSION=3.6

# Needed for string substitution
SHELL ["/bin/bash", "-c"]
USER root

# change timezone
ARG TZ="Asia/Shanghai"
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo ${TZ} > /etc/timezone

# extra dependencies
COPY python_requirements.txt debian_requirements.txt /
RUN apt-get update --fix-missing && \
    cat /debian_requirements.txt | xargs apt-get install -y --no-install-recommends --allow-unauthenticated && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
        default-libmysqlclient-dev  \
        libpq-dev \
        sasl2-bin \
        libsasl2-2 \
        libsasl2-dev \
        libsasl2-modules && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --user --upgrade pip && \
    pip install --no-cache-dir pybind11 thrift sasl thrift_sasl smart_open==2.0.0 && \
    pip install --no-cache-dir \
        jupyterlab \
        SQLAlchemy \
        mysqlclient \
        psycopg2 \
        pyhive \
        elasticsearch \
        redis \
        redis-py-cluster \
        aredis \
        shapely \
        gensim \
        hnswlib \
        pandarallel \
        minio \
        gunicorn \
        uvicorn \
        fastapi \
        ujson \
        pyarrow==3.0.0 \
        fastparquet==0.5.0 \
        dask[dataframe] \
        bert-serving-server[http] \
        clickhouse-driver \
        openpyxl \
        uvloop \
        httptools \
        seaborn \
        nvidia-ml-py \
        oss2

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
    pip install --no-cache-dir jupyter_http_over_ws && \
    jupyter serverextension enable --py jupyter_http_over_ws && \
    python -m ipykernel.kernelspec

# deal with vim and matplotlib Mojibake
#COPY simhei.ttf /usr/local/lib/python${PYTHON_VERSION}/site-packages/matplotlib/mpl-data/fonts/ttf/
COPY simhei.ttf /usr/local/lib/python${PYTHON_VERSION}/dist-packages/matplotlib/mpl-data/fonts/ttf/
RUN echo "set encoding=utf-8 nobomb" >> /etc/vim/vimrc && \
    echo "set termencoding=utf-8" >> /etc/vim/vimrc && \
    echo "set fileencodings=utf-8,gbk,utf-16le,cp1252,iso-8859-15,ucs-bom" >> /etc/vim/vimrc && \
    echo "set fileformats=unix,dos,mac" >> /etc/vim/vimrc && \
    rm -rf /root/.cache/matplotlib

 supervisor config
RUN mkdir /var/run/sshd && \
    apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends --allow-unauthenticated supervisor
COPY supervisord.conf /

EXPOSE 8888

COPY bashrc /etc/bash.bashrc
RUN chmod a+rwx /etc/bash.bashrc
RUN env | egrep -v "^(LS_COLORS=|SSH_CONNECTION=|USER=|PWD=|HOME=|SSH_CLIENT=|SSH_TTY=|MAIL=|TERM=|SHELL=|SHLVL=|LOGNAME=|PS1=|_=)" > /etc/environment

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]
