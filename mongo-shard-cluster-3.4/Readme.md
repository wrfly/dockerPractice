# 构建镜像
./build.sh

# 启动集群
docker-compose up

# 检查状态
docker exec -ti $(docker ps |grep mongos3_1 | head -c 10) mongo admin -u admin -p pass --eval "db.runCommand( { listshards : 1 } );"

# 其他：
用户名：admin
密码： pass