---
layout: post
title: "Docker：Dockerfile指令简介"
key: 2018-06-05
categories:
  - Docker
tags:
  - Docker
---

**注意**:本文内容基于docker `18.03.0-ce`

Dockerfile中每一条指令都会建立一层layer，UnionFS是有层数上限的（大多为128层）。 层数过多会导致数据读取减慢（[UnionFS简介](https://xftony.github.io/docker/2018/05/04/Docker%E5%9F%BA%E7%A1%80%E6%8A%80%E6%9C%AF-Union-File-System.html)），所以在Dockerfile中相同命令尽量进行合并([COPY/ADD除外](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#add-or-copy))。  
PS:Dockerfile执行中不区分指令的大小写，但一般默认都是用大写。
<!--more-->

### FROM   
格式：

    FROM <image> [AS <name>]
    FROM <image>[:<tag>] [AS <name>]
    FROM <image>[@<digest>] [AS <name>]

指定基础镜像，是Dockerfile中必备的一条指令。后续的指令都是在基础镜像的基础上进行操作。其中基础镜像可以是[DockerHub](https://hub.docker.com/)中的公开镜像，也可以是私有制做的镜像。如果想从头开始搭建的话，可以使用空镜像`scratch`，即你的操作是从第一层镜像上开始的。`scratch`所适用于不需要以操作系统为基础，所有库都已存在于可执行文件中了的对象。


### RUN

格式：

    RUN cmd arg1 arg2
    RUN ["executable", "arg1", "arg2"]

执行命令行命令，是Dockerfile中最常用的一条指令。 因为Dockerfile中每一条命令都会对应一层layer，为了避免层数过多，可以将多条命令合并，例如shell格式，多条命令可以通过`&&`进行组合。  
下面就是一条RUN命令：

    RUN apt-get update && \
    apt-get -y install \
    openssh-server \
    sudo \
    procps \
    wget \
    unzip \
    mc \
    ca-certificates \
    curl \
    software-properties-common \
    python-software-properties && \
    mkdir /var/run/sshd 
AUFS是RUN执行`rm` 可能会产生[bug](https://docs.docker.com/engine/reference/builder/#known-issues-run)


### ADD   
格式：

	ADD [--chown=<user>:<group>] <src>... <dst>
    ADD [--chown=<user>:<group>] ["<src>",... "<dst>"]

ADD将来`src`定义的源文件，源目录或者远程文件（URL），复制到`dst`指定的路径。其中`--chown`仅对linux的container生效，`src`中可以包含`*`或者`？`在内的通配符（满足Go的[filepath.Match](https://golang.org/pkg/path/filepath/#Match)规则）。`dst`如果不是绝对路径，则会认为是相对于`WORKDIR`指定的工作目录的相对路径。
>如果`src`为本地路径，则该路径必须是在当前目录下的，错误示例`ADD ../something /something`；   
>如果`src`是URL，且`dst`中不以`/`结尾，则`src`将被重命名并拷贝到为`dst`；   
>如果`src`是URL，且`dst`中以`/`结尾，则`src`将拷贝到为`dst`目录下，filename根据URL中获取；   
>如果`src`是文件夹，则文件夹下所有内容全部都会被复制到`dst`；
>如果`src`为本地tar则会被自动解压，URL中的则不会。

例如：

    ADD --chown=55:mygroup files* /somedir/
	ADD --chown=bin files* /somedir/
	ADD --chown=1 files* /somedir/
	ADD --chown=10:11 files* /somedir/

### COPY   
格式：

	COPY <src>... <dst>
	COPY ["<src1>",... "<dst>"]
将从构建上下文目录中 `src`（可以是`file`或者`dir`）复制到新的一层的镜像
内的 `dst` 位置。其中`src`可以是一个或者多个，也可以包含通配符（满足Go的[filepath.Match](https://golang.org/pkg/path/filepath/#Match)规则）。`dst`如果不是绝对路径，则会认为是相对于`WORKDIR`指定的工作目录的相对路径。COPY不支持URL其他与ADD类似。`COPY`的语义相对`ADD`更加明确，来自官方的提示:能用`COPY`尽量用`COPY`,
例如：

	COPY test/ /tmp/     //本地test目录拷贝到/tmp/下
	COPY test*.txt tmp/  // 本地的test*.txt保存在 WORKDIR/tmp/下

### CMD 
格式：  
 
    CMD cmd arg1 arg2
    CMD ["executable", "arg1", "arg2"]
    CMD ["arg1","arg2"]  //作为 ENTRYPOINT 的默认参数；

在启动容器的时候，指定默认的容器主进程的启动命令及参数。ubuntu的默认命令是`/bin/bash`。
    
    CMD ["/bin/bash"]
CMD指定的启动命令可以在 docker run的时候被修改。例如：  

    docker run -it ubuntu sh
`sh`将替代`/bin/bash`。当采用第三种格式的时候，需要存在`ENTRYPOINT`, `CMD`指令将作为其参数。

### LABEL
格式：
    
    LABEL <key>=<value> <key>=<value> <key>=<value> ...
以key-value的形式为image添加标签，新建的image会继承基础image（通过FROM添加的image）的key-value，若存在key相同的情况，则value去最近的赋值。
例如：

    LABEL multi.label1="value1" \
      multi.label2="value2" \
      other="value3"

### MAINTAINER
格式：

	MAINTAINER <name>
指定维护者信息，已被弃用。 推荐使用`LABEL`替代。

    LABEL maintainer="srl11@foxmail.com"

### EXPOSE  
格式：
    
    EXPOSE <port> [<port>/<protocol>...]
指定container监听的网络端口，但该命令并不会真正生效。若想生效需要在可以在`docker run`的时候通过`-p`进行指定。
例如：

    EXPOSE 80/tcp
    EXPOSE 80/udp   
若不指定协议，默认TCP。

### ENV  
格式：

	ENV <key> <value>
	ENV <key1>=<value1> <key2>=<value2>...

设置环境变量，之后的命令即可使用该环境变量。第一种格式会将`key`后(`key`空格之后)所有的字符，包括空格都当作`value`。第二种格式可以一次配置多个环境变量。

例如：
  
	ENV VERSION=1.0 DEBUG=on \
	NAME="Happy Feet"


### ENTRYPOINT  
格式：  
  
    ENTRYPOINT cmd arg1 arg2
    ENTRYPOINT ["executable", "arg1", "arg2"]  

在启动容器的时候，指定默认的容器主进程的启动命令及参数，与`CMD`一致。
例如：

    ENTRYPOINT [ "wget", "baidu.com"]

 当`ENTRYPOINT`存在时，`CMD`将被当作参数传递给`ENTRYPOINT`，即 `<ENTRYPOINT> "<CMD>"`。 `ENTERPOINT`可以在docker run的时候,通过`--entrypoint`被修改。在Dockerfile中至少要存在一个`CMD`或者`ENTRYPOINT`。
    

### VOLUME  
格式：

	VOLUME ["<path1>", "<path2>"...]
	VOLUME <path>
VOLUME指令创建一个具有指定名称的挂载点。数据卷的[详细介绍](https://docs.docker.com/engine/tutorials/dockervolumes/#/mount-a-host-directory-as-a-data-volume)   
>window-based 容器：VOLUME指定的必须是空文件夹或者不存在的目录，且不可以在`c盘`；  
>声明VOLUME后，Dockerfile中任何对其的修改都无效；  
>JSON格式(即第一种格式)必须使用双引号`""`, 单引号`''`无效；
>为了
例如：

	VOLUME [“/var/log/”]
	VOLUME /var/log
	VOLUME /var/log /var/db



### ARG
格式：  

    ARG <arg>[=<default>]
设置构建环境时的环境变量，容器运行时这些环境变量是不会存在的。
例如：
    
    ARG DEBUG=on

`ARG`可以在docker build的时候，使用`--build-arg <arg>=<value>`进行被替换。
例如： 

	ARG user1
	ARG buildno=1

### USER  
格式：

	USER <user>[:<group>] or
	USER <UID>[:<GID>]
`USER`指令设置运行image和Dockerfile中后续指令(`RUN`，`CMD`和`ENTRYPOINT`)，使用的用户名（或`UID`）和用户组（或`GID`）

例如：  

    USER xftony 

### WORKDIR  
格式：  

	WORKDIR /path/to/workdir

指定image工作目录。后续`WORKDIR`如果为相对路径，则会自动与之前的`WORKDIR`合并。
例如：  

	WORKDIR /a
	WORKDIR b
	WORKDIR c
	RUN pwd
`pwd`的结果为`/a/b/c`。


### ONBUILD  
格式：  

	ONBUILD [INSTRUCTION]
添加trigger，当该Dockerfile产生的image被引用的时候（即被FROM XXX）， FROM执行执行的时候会触发这些trigger。

其具体工作流程如下：
>1、当它遇到ONBUILD指令时，构建器会为正在build的image添加一个trigger，该指令不会影响当前的build；    
>2、在build结束时，所有trigger的列表都存储在image清单中的OnBuild键下。 可以使用docker inspect命令查看；     
>3、使用FROM指令将image用作base image。 作为处理FROM指令的一部分，下游构建器会查找ONBUILD的trigger，并按照它们的注册顺序执行它们。 如果任何trigger失败，那么FROM指令将中止，从而导致build失败。 如果所有trigger都成功，则FROM指令完成并且build继续照常；   
>4、trigger在执行后从最终image中清除，不会被继续继承。  

例如：  

	ONBUILD ADD . /app/src
	ONBUILD RUN /usr/local/bin/python-build --dir /app/src


### STOPSIGNAL   
格式：
    
    STOPSIGNAL signal
定义用于发送至comtainer使其退出的`system call signal`。

### HEALTHCHECK  
格式： 

	HEALTHCHECK [OPTIONS] CMD cmd 
	HEALTHCHECK NONE
`HEALTHCHECK [OPTIONS] CMD command`表示在container内执行cmd进行healthcheck，`HEALTHCHECK NONE`表示disable `bash-image`中的healthcheck。
OPTIONS包括：

	--interval=DURATION       //执行间隔，默认：30s
	--timeout=DURATION        //超时时间，默认：30s
	--start-period=DURATION   //容器启动等待时间，默认：0s
	--retries=N               //失败重试次数，超过则认为unhealth，默认：3次

例如：  

	HEALTHCHECK --interval=5m --timeout=3s  CMD curl -f http://localhost/ || exit 1
每个5分钟尝试连接本地webserver，超时时间为3s，失败则`exit-code`为1。 

### SHELL

格式：  

	SHELL ["executable", "parameters"]

指定`RUN`，`CMD`和`ENTRYPOINT`所使用的`SHELL`环境。
例如：
    
    SHELL ["/bin/sh", "-c"]

参考：[Dockerfile reference](https://docs.docker.com/engine/reference/builder/#from)  

以上～