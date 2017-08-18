# Docker安装示例
### 1、安装docker
```markdown
sudo apt-get -y install docker.io
```
### 2、创建软链接
```markdown
sudo ln -sf /usr/bin/docker.io /usr/local/bin/docker
sudo  sed -i '$acomplete -F _docker docker' /etc/bash_completion.d/docker.io
```
### 3、设置自启动
```markdown
sudo update-rc.d docker.io defaults
```
### 4、创建并运行 docker容器
```markdown
docker run -it -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v /home/sdn/simrp:/home/simrp --net=none --name s2 eclipse1.1
```
### 5、启动容器
```markdown
sudo docker start host1
sudo docker exec -it host1 /bin/bash
```
### 6、建立容器间连接
将容器s1的eth1添加到br1上，并设置其ip为10.0.1.1/24
```markdown
sudo pipework br1 -i eth1 s1 10.0.1.1/24
```
### 7、阿里云镜像加速
请安装1.6.0以上版本的Docker。 
可以通过阿里云的镜像仓库下载： mirrors.aliyun.com/help/docker-engine
```markdown
curl -sSL http://acs-public-mirror.oss-cn-hangzhou.aliyuncs.com/docker-engine/internet | sh -
```
#### 配置Docker加速器:
您可以使用如下的脚本将mirror的配置添加到docker daemon的启动参数中。
```markdown
echo "DOCKER_OPTS=\"--registry-mirror=https://pee6w651.mirror.aliyuncs.com\"" | sudo tee -a /etc/default/docker
sudo service docker restart
```
