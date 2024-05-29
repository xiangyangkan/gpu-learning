#!/bin/bash
WORKING_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENABLE_PRUNE="true"

function docker_prune() {
    if [ "$ENABLE_PRUNE" = "true" ]; then
      docker system prune -a -f || exit 1
    fi
}

function build_pytorch_image() {
    local ngc_version="$1"
    local python_version="$2"
    local base_image="nvcr.io/nvidia/pytorch:$ngc_version-py3"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/pytorch:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/pytorch:"$ngc_version" && docker_prune
}

function build_tensorflow_image() {
    local ngc_version="$1"
    local python_version="$2"
    local base_image="nvcr.io/nvidia/tensorflow:$ngc_version-tf2-py3"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/tensorflow:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/tensorflow:"$ngc_version" && docker_prune
}

function build_triton_server_image() {
    local ngc_version="$1"
    local base_image="nvcr.io/nvidia/tritonserver:$ngc_version-py3"
    docker build --target base --build-arg BASE_IMAGE="$base_image" \
      -t rivia/tritonserver:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/tritonserver:"$ngc_version" && docker_prune
}

function build_tensorrt_image() {
    local ngc_version="$1"
    local python_version="$2"
    local cmake_version="$3"
    local bazelisk_version="$4"
    local base_image="nvcr.io/nvidia/tensorrt:$ngc_version-py3"
    local stage_image="tensorrt:devel"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t $stage_image -f Dockerfile . || exit 1
    docker build --target build --build-arg BASE_IMAGE="$stage_image" \
      --build-arg CMAKE_VERSION="$cmake_version" --build-arg BAZELISK_VERSION="$bazelisk_version" \
      -t rivia/tensorrt:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/tensorrt:"$ngc_version" && docker_prune
}

function build_trtllm_image() {
    local trtllm_version="$1"
    local python_version="$2"
    local base_image="tensorrt_llm/release:latest"
    local stage_image="trtllm:devel"
    rm -rf general/TensorRT-LLM
    git clone -b "v$trtllm_version" https://github.com/NVIDIA/TensorRT-LLM.git general/TensorRT-LLM
    cd general/TensorRT-LLM || exit 1
    git submodule update --init --recursive
    apt install -y git-lfs && git lfs pull || exit 1
    docker build --target release --build-arg BUILD_WHEEL_ARGS="--clean --trt_root /usr/local/tensorrt --python_bindings --benchmarks" \
      --file docker/Dockerfile.multi --tag $base_image . || exit 1
    cd "$WORKING_DIR" || exit 1
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t $stage_image -f Dockerfile . || exit 1
    docker build --target tensorrt --build-arg BASE_IMAGE="$stage_image" \
      -t rivia/tensorrt_llm:"$trtllm_version" -f Dockerfile . || exit 1
    docker push rivia/tensorrt_llm:"$trtllm_version" && docker_prune
}

function build_trtllm_backend_from_scratch() {
    local ngc_version="$1"
    local trtllm_version="$2"
    local tensorrt_version="$3"
    rm -rf general/tensorrtllm_backend
    rm -rf general/server
    # 使用`triton-inference-server/tensorrtllm_backend`的主分支最新代码
    git clone https://github.com/triton-inference-server/tensorrtllm_backend.git general/tensorrtllm_backend
    # 使用`triton-inference-server/server`的主分支最新代码
    git clone https://github.com/triton-inference-server/server.git general/server
    cd "$WORKING_DIR/general/tensorrtllm_backend" || exit 1
    git submodule update --init --recursive
    apt install -y git-lfs && git lfs pull || exit 1

    BASE_IMAGE="nvcr.io/nvidia/pytorch:${ngc_version}-py3"
    TRT_URL_x86="https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/${tensorrt_version%.*}/tars/TensorRT-${tensorrt_version}.Linux.x86_64-gnu.cuda-12.4.tar.gz"
    TRT_URL_ARM="https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/${tensorrt_version%.*}/tars/TensorRT-${tensorrt_version}.ubuntu-22.04.aarch64-gnu.cuda-12.4.tar.gz"
    TRTLLM_BASE_IMAGE=trtllm_base
    # 使用`TensorRT-LLM`的主分支最新代码编译
    TENSORRTLLM_BACKEND_REPO_TAG=main
    docker build -t ${TRTLLM_BASE_IMAGE} \
                 --build-arg BASE_IMAGE="${BASE_IMAGE}" \
                 --build-arg TRT_VER="${tensorrt_version}" \
                 --build-arg RELEASE_URL_TRT_x86="${TRT_URL_x86}" \
                 --build-arg RELEASE_URL_TRT_ARM="${TRT_URL_ARM}" \
                 -f dockerfile/Dockerfile.triton.trt_llm_backend . || exit 1

    cd "$WORKING_DIR/general/server" || exit 1
    python3 ./build.py -v --no-container-interactive --enable-logging --enable-stats --enable-tracing \
              --enable-metrics --enable-gpu-metrics --enable-cpu-metrics \
              --filesystem=gcs --filesystem=s3 --filesystem=azure_storage \
              --endpoint=http --endpoint=grpc --endpoint=sagemaker --endpoint=vertex-ai \
              --backend=ensemble --enable-gpu --endpoint=http --endpoint=grpc \
              --no-container-pull \
              --image=base,${TRTLLM_BASE_IMAGE} \
              --backend=tensorrtllm:${TENSORRTLLM_BACKEND_REPO_TAG} \
              --backend=python:"r${ngc_version}" || exit 1

    local stage_image="triton_backend:base"
    local tag="latest-trtllm"
    docker build --target base --build-arg BASE_IMAGE="tritonserver:latest" \
      -t $stage_image -f Dockerfile . || exit 1
    docker build --target devel --build-arg BASE_IMAGE="$stage_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/triton_backend:"$tag" -f Dockerfile . || exit 1
    docker push rivia/triton_backend:"$tag" && docker_prune
}

function build_triton_backend_image() {
    local ngc_version="$1"
    local python_version="$2"
    local conda_version="$3"
    local cmake_version="$4"
    local bazelisk_version="$5"
    local backend_type="$6"
    local cmake_version="$3"
    local bazelisk_version="$4"
    local backend_type="$5"
    local base_image
    if [[ "$backend_type" == "trtllm" ]]; then
      base_image="nvcr.io/nvidia/tritonserver:$ngc_version-trtllm-python-py3"
      tag="$ngc_version-trtllm"
    elif [[ "$backend_type" == "vllm" ]]; then
      base_image="nvcr.io/nvidia/tritonserver:$ngc_version-vllm-python-py3"
      tag="$ngc_version-vllm"
    else
      base_image="nvcr.io/nvidia/tritonserver:$ngc_version-py3"
      tag="$ngc_version"
    fi
    local stage_image="triton_backend:base"
    docker build --target base --build-arg BASE_IMAGE="$base_image" \
      -t $stage_image -f Dockerfile . || exit 1
    docker build --target devel --build-arg BASE_IMAGE="$stage_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/triton_backend:"$tag" -f Dockerfile . || exit 1
    docker push rivia/triton_backend:"$tag" && docker_prune
}

function build_deepstream_image() {
    local deepstream_version="$1"
    local python_version="$2"
    local pyds_version="$3"
    local arch="$4"
    if [[ "$arch" == "x86_64" ]]; then
      local base_image="nvcr.io/nvidia/deepstream:$deepstream_version"
    else
      local base_image="dustynv/deepstream:$deepstream_version"
    fi
    local stage_image="deepstream:devel"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t $stage_image -f Dockerfile . || exit 1
    docker build --target deepstream --build-arg BASE_IMAGE="$stage_image" --build-arg ARCH="$arch" \
      --build-arg DEEPSTREAM_VERSION="$deepstream_version" --build-arg PYDS_VERSION="$pyds_version" \
      -t rivia/deepstream:"$deepstream_version" -f Dockerfile . || exit 1
    docker push rivia/deepstream:"$deepstream_version" && docker_prune
}

function build_nemo_image() {
    local ngc_version="$1"
    local python_version="$2"
    local base_image="nvcr.io/nvidia/nemo:$ngc_version"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/nemo:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/nemo:"$ngc_version" && docker_prune
}

function build_lmdeploy_image() {
    local lmdeploy_version="$1"
    local python_version="$2"
    local base_image="openmmlab/lmdeploy:v$lmdeploy_version"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t "rivia/pytorch:lmdeploy-$lmdeploy_version" -f Dockerfile . || exit 1
    docker push "rivia/pytorch:lmdeploy-$lmdeploy_version" && docker_prune
}


NGC_VERSION="24.05"
PYTHON_VERSION="3.10"
CMAKE_VERSION="3.28.4"
BAZELISK_VERSION="1.19.0"
USE_JETSON="false"
DEEPSTREAM_VERSION="6.4-triton-multiarch"
JETSON_VERSION="r36.2.0"
PYDS_VERSION="1.1.10"
TRTLLM_VERSION="0.9.0"
TENSORRT_VERSION="10.0.1.6"
LMDEPLOY_VERSION="0.4.2"
CUSTOM_TRTLLM_BACKEND="true"
dos2unix ./*

build_pytorch_image "$NGC_VERSION" "$PYTHON_VERSION" || exit 1
build_tensorflow_image "$NGC_VERSION" "$PYTHON_VERSION" || exit 1
build_triton_server_image "$NGC_VERSION" || exit 1
build_tensorrt_image "$NGC_VERSION" "$PYTHON_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" || exit 1
build_trtllm_image "$TRTLLM_VERSION" "$PYTHON_VERSION" || exit 1
build_triton_backend_image "$NGC_VERSION" "$PYTHON_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" "general" || exit 1
build_triton_backend_image "$NGC_VERSION" "$PYTHON_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" "vllm" || exit 1
if [ "$CUSTOM_TRTLLM_BACKEND" = "true" ]; then
  # 自构建的会保留编译文件，不会删除, 会多大约 20G 空间
  build_trtllm_backend_base_image "$NGC_VERSION" "$TRTLLM_VERSION" "$TENSORRT_VERSION" || exit 1
fi
build_triton_backend_image "$NGC_VERSION" "$PYTHON_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" "trtllm" || exit 1
if [ "$USE_JETSON" = "true" ]; then
  build_deepstream_image "$JETSON_VERSION" "$PYTHON_VERSION" "$PYDS_VERSION" "jetson" || exit 1
else
  build_deepstream_image "$DEEPSTREAM_VERSION" "$PYTHON_VERSION" "$PYDS_VERSION" "x86_64" || exit 1
fi
build_nemo_image 23.08 3.8 || exit 1
build_lmdeploy_image "$LMDEPLOY_VERSION" "3.8" || exit 1
