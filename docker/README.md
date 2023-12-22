# Unified GPU Environment 
训练推理一体化GPU环境搭建

## 固定CPU频率
启用CPU睿频时GPU训练效率会下降
- 禁用休眠  
  `cpupower idle-set -D 0`
- 启动性能模式   
  `cpupower -c all frequency-set -g performance`

## NFS挂载
用于多台GPU机器之间的文件共享(服务器重启后需要重新挂载)  
 `mount -t nfs -o vers=3,nolock,proto=tcp,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 
 xx.xx.xx.xx:/data /data/nfs`

## 构建镜像
```bash
sudo proxychains bash build.sh
```

> TensorRT的版本要与Triton Server版本保持兼容, 版本对应关系参考[支持矩阵](https://docs.nvidia.com/deeplearning/frameworks/support-matrix/index.html)

## 启动服务

1. 自定义`default.env`中的工作目录，用户名，密码，本地源配置；
2. 更新镜像到最新版:
    ```bash
    sudo proxychains bash general/replace.sh
    ```

3. 启动服务:
    ```bash
    cd general && sudo proxychains docker compose up -d
    ```

> 包括:
> 
> - Pytorch容器用于模型训练
> - Tensorflow容器用于模型训练
> - Triton Server容器用于模型推理
> - Triton Backend容器用于模型推理
> - TensorRT容器用于构建推理图