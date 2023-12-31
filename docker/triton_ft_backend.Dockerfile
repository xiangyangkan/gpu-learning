# Copyright (c) 2021-2202, NVIDIA CORPORATION. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# -------------------------------------------------- #
# This is a Docker image dedicated to develop
# FasterTransformer backend. If you don't want to build the
# backend together with tritonserver, start from here
# -------------------------------------------------- #

ARG TRITON_VERSION=22.04
ARG BASE_IMAGE=nvcr.io/nvidia/tritonserver:${TRITON_VERSION}-py3
FROM ${BASE_IMAGE} as server-builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    zip unzip wget build-essential autoconf autogen gdb \
    python3.8 python3-pip python3-dev rapidjson-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace/build/

# CMake
RUN CMAKE_VERSION=3.22 && \
    CMAKE_BUILD=3.22.3 && \
    wget -nv https://cmake.org/files/v${CMAKE_VERSION}/cmake-${CMAKE_BUILD}.tar.gz && \
    tar -xf cmake-${CMAKE_BUILD}.tar.gz && \
    cd cmake-${CMAKE_BUILD} && \
    ./bootstrap --parallel=$(grep -c ^processor /proc/cpuinfo) -- -DCMAKE_USE_OPENSSL=OFF && \
    make -j"$(grep -c ^processor /proc/cpuinfo)" install && \
    cd /workspace/build/ && \
    rm -rf /workspace/build/cmake-${CMAKE_BUILD}

# backend build
WORKDIR /workspace/build/fastertransformer_backend
ADD cmake cmake
ADD src src
ADD CMakeLists.txt CMakeLists.txt
ADD README.md README.md
ADD LICENSE LICENSE

ARG FORCE_BACKEND_REBUILD=0
RUN mkdir build -p && \
    cd build && \
    cmake \
      -D CMAKE_EXPORT_COMPILE_COMMANDS=1 \
      -D CMAKE_BUILD_TYPE=Release \
      -D CMAKE_INSTALL_PREFIX=/opt/tritonserver \
      -D TRITON_COMMON_REPO_TAG="r${NVIDIA_TRITON_SERVER_VERSION}" \
      -D TRITON_CORE_REPO_TAG="r${NVIDIA_TRITON_SERVER_VERSION}" \
      -D TRITON_BACKEND_REPO_TAG="r${NVIDIA_TRITON_SERVER_VERSION}" \
      .. && \
    make -j"$(grep -c ^processor /proc/cpuinfo)" install

FROM ${BASE_IMAGE} as server

ENV NCCL_LAUNCH_MODE=GROUP

COPY --from=server-builder /opt/tritonserver/backends/fastertransformer /opt/tritonserver/backends/fastertransformer

# set workspace
ENV WORKSPACE /workspace
WORKDIR /workspace

# Install pytorch
RUN pip3 install torch==1.9.1+cu111 -f https://download.pytorch.org/whl/torch_stable.html  && \
    pip3 install --extra-index-url https://pypi.ngc.nvidia.com regex fire tritonclient[all]

# for debug
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends openssh-server zsh tmux mosh locales-all clangd sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/g' /etc/ssh/sshd_config
RUN mkdir /var/run/sshd -p

ADD . /workspace/fastertransformer_backend

# jupyter lab config
COPY docker/jupyter_server_config.py /root/.jupyter/
COPY docker/jupyter_notebook_config.py /root/.jupyter/
COPY docker/run_jupyter.sh /
RUN chmod +x /run_jupyter.sh && \
    pip install --no-cache-dir jupyterlab jupyter_http_over_ws && \
    jupyter serverextension enable --py jupyter_http_over_ws && \
    python3 -m ipykernel.kernelspec
EXPOSE 8888

# SSH config
RUN apt-get update --fix-missing && apt-get install --no-install-recommends --allow-unauthenticated -y \
    openssh-server pwgen && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    sed -i "s/.*UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config && \
    sed -i "s/.*UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config && \
    sed -i "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config && \
    sed -i "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
COPY docker/set_root_pw.sh docker/run_ssh.sh /
RUN chmod +x /*.sh && sed -i -e 's/\r$//' /*.sh
ENV AUTHORIZED_KEYS **None**
EXPOSE 22

# supervisor config
RUN apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends --allow-unauthenticated supervisor
COPY docker/supervisord.conf /

COPY docker/bashrc /etc/bash.bashrc
RUN chmod a+rwx /etc/bash.bashrc

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]
