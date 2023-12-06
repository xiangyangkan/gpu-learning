# GPU视频流分析服务

## 步骤

1. 自定义`default.env`中的工作目录，用户名，密码；
2. 更新镜像到最新版:
    ```bash
    sudo bash replace.sh
    ```

3. 启动服务:
    ```bash
    sudo docker compose up -d
    ```