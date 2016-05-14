# docker tips - 一些关在本地测试docker的小技巧

### 关于安装使用

安装完docker后，如果不想每次运行docker都要输入`sudo`或者以root运行docker,那么可以给`/usr/bin/docker`设置一个`s`标志位：`sudo chmod +s /usr/bin/docker`，这样每次运行`docker`就直接以root运行了。


### 一些fuctions和aliases

- `docker-c` - 清理已经停止运行的容器
```bash
fucntion docker-c(){ # Clean
    echo `docker ps -a | cut -d ' ' -f 1` | cut -d ' ' -f 2- | xargs docker rm
}
```

- `docker-srm` - 停止运行并删除正在运行的容器
```bash
function docker-srm() { # Stop and ReMove
    docker stop $1 && docker rm $1
}
```

- `docker-rmni` - 删除标签为\<none\>的镜像
```bash
function docker-rmni(){ # ReMove None Images
    read -p "Are you sure?[y/n]" yon
    [[ "$yon" =~ [Y|y] ]] && echo "Removing..." || echo "Interrupt and exit." && return 1 
    docker images | grep '<none>' | tr -d ' ' | cut -d '>' -f 3 | for c in `xargs`; do { docker rmi `echo $c | head -c 12`; };  done
}
```

- `dps` & `dpsa` - `docker ps` 和 `docker ps -a`的别名
```bash
alias dps='docker ps'
alias dpsa='docker ps -a'
```

- `docker-ip` - 输出容器的IP地址
```bash
alias docker-ip="sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}'"
```
