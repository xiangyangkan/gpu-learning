
function update_python_version() {
    local python_version="$1"
    declare -a vars
    vars=(
      "general/pytorch.Dockerfile"
      "general/tensorflow.Dockerfile"
      "general/tensorrt.Dockerfile"
      "general/triton.Dockerfile"
      "general/triton_backend.Dockerfile"
      "deepstream/deepstream.Dockerfile"
      # "nemo/nemo.Dockerfile" # nemo doesn't support python 3.10 yet
    )
    for var_name in "${vars[@]}"; do
      sed -i -e "s|^ENV PYTHON_VERSION=.*|ENV PYTHON_VERSION=${python_version}|" "$var_name"
    done
}

function update_ngc_version() {
 local ngc_version="$1"
 declare -a vars
  vars=(
    "general/pytorch.Dockerfile"
    "general/tensorflow.Dockerfile"
    "general/triton.Dockerfile"
    "general/triton_backend.Dockerfile"
    # "nemo/nemo.Dockerfile" # nemo doesn't support ngc 23.10 yet
  )
  for var_name in "${vars[@]}"; do
    sed -i -e "s|^ARG NGC_VERSION=.*|ARG NGC_VERSION=${ngc_version}|" "$var_name"
  done
}

function update_conda_version() {
    local conda_version="$1"
    declare -a vars
    vars=(
      "general/triton_backend.Dockerfile"
      "deepstream/deepstream.Dockerfile"
    )
    for var_name in "${vars[@]}"; do
      sed -i -e "s|^ARG CONDA_VERSION=.*|ARG CONDA_VERSION=${conda_version}|" "$var_name"
    done
}

function update_cmake_version() {
    local cmake_version="$1"
    declare -a vars
    vars=(
      "general/tensorrt.Dockerfile"
      "general/triton_backend.Dockerfile"
    )
    for var_name in "${vars[@]}"; do
      sed -i -e "s|^ENV CMAKE_VERSION=.*|ENV CMAKE_VERSION=${cmake_version}|" "$var_name"
    done
}

function update_tensorrt_version() {
    local tensorrt_version="$1"
    local cuda_version="$2"
    declare -a vars
    vars=(
      "general/tensorrt.Dockerfile"
    )
    for var_name in "${vars[@]}"; do
      sed -i -e "s|^ENV TRT_VERSION=.*|ENV TRT_VERSION=${tensorrt_version}|" "$var_name"
      sed -i -e "s|^ARG CUDA_VERSION=.*|ARG CUDA_VERSION=${cuda_version}|" "$var_name"
    done
}

function update_deepstream_version() {
    local deepstream_version="$1"
    local pyds_version="$2"
    declare -a vars
    vars=(
      "deepstream/deepstream.Dockerfile"
    )
    for var_name in "${vars[@]}"; do
      sed -i -e "s|DEEPSTREAM_VERSION=.*|DEEPSTREAM_VERSION=${deepstream_version}|" "$var_name"
      sed -i -e "s|PYDS_VERSION=.*|PYDS_VERSION=${pyds_version}|" "$var_name"
    done
}

function update_all() {
    local python_version="$1"
    local ngc_version="$2"
    local conda_version="$3"
    local cmake_version="$4"
    local tensorrt_version="$5"
    local cuda_version="$6"
    local deepstream_version="$7"
    local pyds_version="$8"
    update_python_version "$python_version"
    update_ngc_version "$ngc_version"
    update_conda_version "$conda_version"
    update_cmake_version "$cmake_version"
    update_tensorrt_version "$tensorrt_version" "$cuda_version"
    update_deepstream_version "$deepstream_version" "$pyds_version"
}

function build_pytorch_image() {
    local ngc_version="$1"
    docker build -t rivia/pytorch:"$ngc_version" -f general/pytorch.Dockerfile .
    docker push rivia/pytorch:"$ngc_version" && docker system prune -a -f
}

function build_tensorflow_image() {
    local ngc_version="$1"
    docker build -t rivia/tensorflow:"$ngc_version" -f general/tensorflow.Dockerfile .
    docker push rivia/tensorflow:"$ngc_version" && docker system prune -a -f
}

function build_triton_server_image() {
    local ngc_version="$1"
    docker build -t rivia/tritonserver:"$ngc_version" -f general/triton.Dockerfile .
    docker push rivia/tritonserver:"$ngc_version" && docker system prune -a -f
}

function build_tensorrt_image() {
    local ngc_version="$1"
    local tensorrt_version="$2"
    docker build -t rivia/tensorrt:"$tensorrt_version-r$ngc_version" -f general/tensorrt.Dockerfile .
    docker push rivia/tensorrt:"$tensorrt_version-r$ngc_version" && docker system prune -a -f
}

function build_triton_backend_image() {
    local ngc_version="$1"
    docker build -t rivia/triton_backend:"$ngc_version" -f general/triton_backend.Dockerfile .
    docker push rivia/triton_backend:"$ngc_version" && docker system prune -a -f
}

function build_triton_trtllm_backend_image() {
    local ngc_version="$1"
    cp general/triton_backend.Dockerfile general/triton_trtllm_backend.Dockerfile
    sed -i -e "s|py3|trtllm-python-py3|" general/triton_trtllm_backend.Dockerfile
    docker build -t rivia/triton_backend:"${ngc_version}-trtllm" -f general/triton_trtllm_backend.Dockerfile .
    docker push rivia/triton_backend:"${ngc_version}-trtllm" && docker system prune -a -f
}

function build_triton_vllm_backend_image() {
    local ngc_version="$1"
    cp general/triton_backend.Dockerfile general/triton_vllm_backend.Dockerfile
    sed -i -e "s|py3|vllm-python-py3|" general/triton_vllm_backend.Dockerfile
    docker build -t rivia/triton_backend:"${ngc_version}-vllm" -f general/triton_vllm_backend.Dockerfile .
    docker push rivia/triton_backend:"${ngc_version}-vllm" && docker system prune -a -f
}

function build_deepstream_image() {
    local deepstream_version="$1"
    docker build -t rivia/deepstream:"$deepstream_version" -f deepstream/deepstream.Dockerfile .
    docker push rivia/deepstream:"$deepstream_version" && docker system prune -a -f
}

function build_nemo_image() {
    local ngc_version="$1"
    docker build -t rivia/nemo:"$ngc_version" -f nemo/nemo.Dockerfile .
    docker push rivia/nemo:"$ngc_version" && docker system prune -a -f
}


PYTHON_VERSION="3.10"
NGC_VERSION="23.12"
CONDA_VERSION="23.11.0-2"
CMAKE_VERSION="3.28.1"
TRT_VERSION="8.6.1.6"
CUDA_VERSION="12.1.1"
DEEPSTREAM_VERSION="6.4-triton-multiarch"
PYDS_VERSION="1.1.10"
update_all "$PYTHON_VERSION" "$NGC_VERSION" "$CONDA_VERSION" "$CMAKE_VERSION" "$TRT_VERSION" "$CUDA_VERSION" "$DEEPSTREAM_VERSION" "$PYDS_VERSION" || exit 1
build_pytorch_image "$NGC_VERSION" || exit 1
build_tensorflow_image "$NGC_VERSION" || exit 1
build_triton_server_image "$NGC_VERSION" || exit 1
build_tensorrt_image "$NGC_VERSION" "$TRT_VERSION" || exit 1
build_triton_backend_image "$NGC_VERSION" || exit 1
build_triton_trtllm_backend_image "$NGC_VERSION" || exit 1
build_triton_vllm_backend_image "$NGC_VERSION" || exit 1
build_deepstream_image "$DEEPSTREAM_VERSION" || exit 1
build_nemo_image 23.08 || exit 1
