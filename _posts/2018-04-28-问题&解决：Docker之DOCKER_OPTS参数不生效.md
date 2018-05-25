---
layout: post
title: "问题&解决：Docker之DOCKER_OPTS参数不生效"
key: 2018-04-28-3
categories:
  - Docker
tags:
  - Virtualization
  - Docker
  - 问题&解决
---


[Github-blog](https://xftony.github.io/docker/2018/04/28/问题&解决-Docker之DOCKER_OPTS参数不生效.html)    
[CSDN-blog](https://blog.csdn.net/xftony)

###  问题：DOCKER_OPTS参数不生效
最近更新了docker版本`Docker version 18.03.1-ce, build 9ee9f40`，更新docker源的时候发现，修改`/etc/default/docker`后，使用`docker info` 查看相关配置，配置无更新，即`DOCKER_OPTS`参数无法生效。
<!--more-->   
###  原因    
在新的版本中，`/etc/default/docker`默认不生效=。=  需要进行手动配置，使其生效。       
官方说明：  

	## 1.12.0 (2016-07-28)
	
	**IMPORTANT**: Docker 1.12 ships with an updated systemd unit file for rpm
	based installs (which includes RHEL, Fedora, CentOS, and Oracle Linux 7). When
	upgrading from an older version of docker, the upgrade process may not
	automatically install the updated version of the unit file, or fail to start
	the docker service if;
	
	- the systemd unit file (`/usr/lib/systemd/system/docker.service`) contains local changes, or
	- a systemd drop-in file is present, and contains `-H fd://` in the `ExecStart` directive

虽然说文档上说`docker.service`这个文件会在`/usr/lib/systemd/system/`下，但其真实路径是路径是`/lib/systemd/system/`。该路径是在默认的安装脚本中指定的`systemd/docker.service lib/systemd/system/`。


###  解决

1、在`/lib/systemd/system/docker.service`中添加`EnvironmentFile=-/etc/default/docker`，并修改ExecStart参数为`ExecStart=/usr/bin/dockerd -H fd:// $DOCKER_OPTS`
	
	# the default is not to use systemd for cgroups because the delegate issues still
	# exists and systemd currently does not support the cgroup feature set required
	# for containers run by docker
	EnvironmentFile=-/etc/default/docker
	ExecStart=/usr/bin/dockerd -H fd:// $DOCKER_OPTS
	ExecReload=/bin/kill -s HUP $MAINPID  

2、重启docker-daemon    

    systemctl daemon-reload

3、重启docker
 
    service docker restart

[Github-blog](https://xftony.github.io/docker/2018/04/28/问题&解决-Docker之DOCKER_OPTS参数不生效.html)     
[CSDN-blog](https://blog.csdn.net/xftony)