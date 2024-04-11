#!/bin/bash
WORKING_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

function build_pytorch_image() {
    local ngc_version="$1"
    local python_version="$2"
    local base_image="nvcr.io/nvidia/pytorch:$ngc_version-py3"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/pytorch:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/pytorch:"$ngc_version" && docker system prune -a -f
}

function build_tensorflow_image() {
    local ngc_version="$1"
    local python_version="$2"
    local base_image="nvcr.io/nvidia/tensorflow:$ngc_version-tf2-py3"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/tensorflow:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/tensorflow:"$ngc_version" && docker system prune -a -f
}

function build_triton_server_image() {
    local ngc_version="$1"
    local base_image="nvcr.io/nvidia/tritonserver:$ngc_version-py3"
    docker build --target base --build-arg BASE_IMAGE="$base_image" \
      -t rivia/tritonserver:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/tritonserver:"$ngc_version" && docker system prune -a -f
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
    docker push rivia/tensorrt:"$ngc_version" && docker system prune -a -f
}

function build_trtllm_image() {
    local trtllm_version="$1"
    local python_version="$2"
    local base_image="tensorrt_llm/release:latest"
    local stage_image="trtllm:devel"
    git clone -b "v$trtllm_version" https://github.com/NVIDIA/TensorRT-LLM.git general/TensorRT-LLM
    cd general/TensorRT-LLM || exit 1
    git submodule update --init --recursive
    git lfs install
    git lfs pull
    docker build --target release --build-arg BUILD_WHEEL_ARGS="--clean --python_bindings --trt_root /usr/local/tensorrt" \
      --file docker/Dockerfile.multi --tag $base_image . || exit 1
    cd "$WORKING_DIR" || exit 1
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t $stage_image -f Dockerfile . || exit 1
    docker build --target tensorrt --build-arg BASE_IMAGE="$stage_image" \
      -t rivia/tensorrt_llm:"$trtllm_version" -f Dockerfile . || exit 1
    docker push rivia/tensorrt_llm:"$trtllm_version" && docker system prune -a -f
}

function build_triton_backend_image() {
    local ngc_version="$1"
    local python_version="$2"
    local conda_version="$3"
    local cmake_version="$4"
    local bazelisk_version="$5"
    local backend_type="$6"
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
    local stage_1_image="triton_backend:base"
    local stage_2_image="triton_backend:conda"
    local stage_3_image="triton_backend:build"
    docker build --target base --build-arg BASE_IMAGE="$base_image" \
      -t $stage_1_image -f Dockerfile . || exit 1
    docker build --target conda --build-arg BASE_IMAGE="$stage_1_image" \
      --build-arg PYTHON_VERSION="$python_version" --build-arg CONDA_VERSION="$conda_version" \
      -t $stage_2_image -f Dockerfile . || exit 1
    docker build --target devel --build-arg BASE_IMAGE="$stage_2_image" --build-arg PYTHON_VERSION="$python_version" \
      -t $stage_3_image -f Dockerfile . || exit 1
    docker build --target build --build-arg BASE_IMAGE="$stage_3_image" \
      --build-arg CMAKE_VERSION="$cmake_version" --build-arg BAZELISK_VERSION="$bazelisk_version" \
      -t rivia/triton_backend:"$tag" -f Dockerfile . || exit 1
    docker push rivia/triton_backend:"$tag" && docker system prune -a -f
}

function build_deepstream_image() {
    local deepstream_version="$1"
    local python_version="$2"
    local pyds_version="$3"
    local arch="$4"
    local base_image="nvcr.io/nvidia/deepstream:$deepstream_version"
    local stage_image="deepstream:devel"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t $stage_image -f Dockerfile . || exit 1
    docker build --target deepstream --build-arg BASE_IMAGE="$stage_image" --build-arg ARCH="$arch" \
      --build-arg DEEPSTREAM_VERSION="$deepstream_version" --build-arg PYDS_VERSION="$pyds_version" \
      -t rivia/deepstream:"$deepstream_version" -f Dockerfile . || exit 1
    docker push rivia/deepstream:"$deepstream_version" && docker system prune -a -f
}

function build_nemo_image() {
    local ngc_version="$1"
    local python_version="$2"
    local base_image="nvcr.io/nvidia/nemo:$ngc_version"
    docker build --target devel --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      -t rivia/nemo:"$ngc_version" -f Dockerfile . || exit 1
    docker push rivia/nemo:"$ngc_version" && docker system prune -a -f
}


NGC_VERSION="23.12"
PYTHON_VERSION="3.10"
CONDA_VERSION="23.11.0-2"
CMAKE_VERSION="3.28.1"
BAZELISK_VERSION="1.18.0"
DEEPSTREAM_VERSION="6.4-triton-multiarch"
PYDS_VERSION="1.1.10"
TRTLLM_VERSION="0.7.1"
dos2unix ./*
build_pytorch_image "$NGC_VERSION" "$PYTHON_VERSION" || exit 1
build_tensorflow_image "$NGC_VERSION" "$PYTHON_VERSION" || exit 1
build_triton_server_image "$NGC_VERSION" || exit 1
build_tensorrt_image "$NGC_VERSION" "$PYTHON_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" || exit 1
build_trtllm_image "$TRTLLM_VERSION" "$PYTHON_VERSION" || exit 1
build_triton_backend_image "$NGC_VERSION" "$PYTHON_VERSION" "$CONDA_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" "general" || exit 1
build_triton_backend_image "$NGC_VERSION" "$PYTHON_VERSION" "$CONDA_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" "trtllm" || exit 1
build_triton_backend_image "$NGC_VERSION" "$PYTHON_VERSION" "$CONDA_VERSION" "$CMAKE_VERSION" "$BAZELISK_VERSION" "vllm" || exit 1
build_deepstream_image "$DEEPSTREAM_VERSION" "$PYTHON_VERSION" "$PYDS_VERSION" "x86_64" || exit 1
build_nemo_image 23.08 3.8 || exit 1
