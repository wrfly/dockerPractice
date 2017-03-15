# 启动集群
- docker-compose up
- 在任意一个容器里运行 `init.sh`

# 添加认证[Optional]
- 重新打镜像，把新的entripoint放进去，添加环境变量 `MONGODB_USER` 和 `MONGODB_PASS`
- compose文件里的 --auth --keyfile 取消注释
