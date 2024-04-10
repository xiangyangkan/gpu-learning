#!/bin/bash

function build_pytorch_image() {
    local jetson_version="$1"
    local python_version="$2"
    local base_image="dustynv/l4t-pytorch:${jetson_version}"
    local target_image="rivia/l4t-pytorch:${jetson_version}"
    docker buildx build --platform linux/arm64 --target base --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      --build-arg ARCH="aarch64" -t "${target_image}" -f Dockerfile . || exit 1
    docker push "${target_image}" && docker system prune -a -f
}

function build_text_generation_image() {
    local jetson_version="$1"
    local python_version="$2"
    local base_image="dustynv/text-generation-webui:${jetson_version}"
    local target_image="rivia/l4t-text-generation-webui:${jetson_version}"
    docker buildx build --platform linux/arm64 --target base --build-arg BASE_IMAGE="$base_image" --build-arg PYTHON_VERSION="$python_version" \
      --build-arg ARCH="aarch64" -t "${target_image}" -f Dockerfile . || exit 1
    docker push "${target_image}" && docker system prune -a -f
}

JETSON_VERSION="r36.2.0"
PYTHON_VERSION="3.10"
dos2unix ./*
build_pytorch_image "$JETSON_VERSION" "$PYTHON_VERSION" || exit 1
build_text_generation_image "$JETSON_VERSION" "$PYTHON_VERSION" || exit 1