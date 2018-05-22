---
layout: post
title: "Docker技术基础：Union File System"
key: 2018-05-04
categories:
  - Docker
tags:
  - File System
  - Docker
---
[Github-blog](https://xftony.github.io/docker/2018/05/04/Docker基础技术-Union-File-System.html)     
[CSDN](https://blog.csdn.net/xftony)   

### Docker images and layers
在介绍Docker存储驱动之前，我们先介绍一下Docker是如何建立image，又如何在image的基础上创建容器的。
Docker的image是由一组layers组合起来得到的，每一层layer对应的是Dockerfile中的一条指令。这些layers中，一层layer为R/W layer，即 container layer，其他layers均为read-only layer（分析见[Union File System](#UFS)）。    
PS： Dockerfile中只允许最后一个CMD或ENTRYPOINT生效，也与之对应，Dockerfile中其他命令生成的layer为Read-only的，CMD或ENTRYPOINT生成的layer是R/W的。  
以ubuntu:15.04的image为例，其image结构示意图如下（截自docker docs）：  
  ![image](https://raw.githubusercontent.com/xftony/xftony.github.io/master/_image/20180504-Docker基础技术：Union File System-1.png)     

当创建多台容器的时候，我们所有的写操作都是发生在R/W层，其FS结构示意图如下：
  ![image](https://raw.githubusercontent.com/xftony/xftony.github.io/master/_image/20180504-Docker基础技术：Union File System-2.png)   


### Union File System
Docker的存储驱动的实现是基于
<span id="UFS">Union File System</span>，简称UnionFS，他是一种为Linux 、FreeBSD 和NetBSD 操作系统设计的，把其他文件系统联合到一个联合挂载点的文件系统服务。它用到了一个重要的资源管理技术,叫写时复制。写时复制（copy-on-write），也叫隐式共享，是一种对可修改资源实现高效复制的资源管理技术。对于一个重复资源，若不修改，则无需立刻创建一个新的资源，该资源可以被共享使用。当发生修改的时候，才会创建新资源。这会大大减少对于未修改资源复制的消耗。Docker正式基于此去创建images和containers。关于Docker中Union file system的应用官方文档介绍如下：

    ## Union file system
	Union file systems implement a [union
	mount](https://en.wikipedia.org/wiki/Union_mount) and operate by creating
	layers. Docker uses union file systems in conjunction with
	[copy-on-write](#copy-on-write 划重点) techniques to provide the building blocks for
	containers, making them very lightweight and fast.
	
	For more on Docker and union file systems, see [Docker and AUFS in
	practice](https://docs.docker.com/engine/userguide/storagedriver/aufs-driver/),
	[Docker and Btrfs in
	practice](https://docs.docker.com/engine/userguide/storagedriver/btrfs-driver/),
	and [Docker and OverlayFS in
	practice](https://docs.docker.com/engine/userguide/storagedriver/overlayfs-driver/)
	
	Example implementations of union file systems are
	[UnionFS](https://en.wikipedia.org/wiki/UnionFS),
	[AUFS](https://en.wikipedia.org/wiki/Aufs), and
	[Btrfs](https://btrfs.wiki.kernel.org/index.php/Main_Page).

### AUFS  
AUFS，全称Advanced Multi-Layered Unification Filesystem。AUFS重写了早期的U nionFS 1.x，提升了其可靠性和性能，是早期Docker版本的默认的存储驱动。（Docker-CE目前默认使用OverlayFS）。  

![image](https://raw.githubusercontent.com/xftony/xftony.github.io/master/_image/20180504-Docker基础技术：Union File System-3.jpg)   

Ubuntu/Debian（Stretch之前的版本）上的Docker-CE可以通过配置`DOCKER_OPTS="-s=aufs"`进行修改，同时内核中需要加载AUFS module，image的增删变动都会发生在`/var/lib/docker/aufs`目录下。  

##### AUFS下文件读操作   
1、文件存在于container-layer：直接从container-layer进行读取；  
2、文件不存在于container-layer：自container-layer下一层开始，逐层向下搜索，找到该文件，并从找到文件的那一层layer中读取文件；  
3、当文件同时存在于container-layer和image-layer，读取container-layer中的文件。
简而言之，从container-layer开始，逐层向下搜索，找到该文件即读取，停止搜索。

##### AUFS下修改文件或目录  
**写操作**    
1、对container-layer中已存在的文件进行写操作：直接在该文件中进行操作（新文件直接在container-layer创建&修改）；  
2、对image-layers中已存在的文件进行写操作：将该文件完整复制到container-layer，然后在container-layer对这份copy进行写操作；  
**删除**  
1、删除container-layer中的文件/目录：直接删除；  
2、删除image-layers中的文件：在container-layer中创建`whiteout`file，image-layer中的文件不会被删除，但是会因为`whiteout`而变得对container而言不可见；  
3、删除image-layers中的目录：在container-layer中创建`opaque`file，作用同`whiteout`；  
**重命名**  
1、container-layer文件/目录重命名：直接操作；  
2、image-layer文件重命名：  
3、image-layer目录重命名：在docker的AUFS中没有支持，会触发`EXDEV`。  

##### AUFS优点  
1、可以在多个运行的container中高效的共享image，可以实现容器的快速启动，并减少磁盘占用量；
2、共享image-layers的方式，可以高效的是使用page cache

##### AUFS缺点    
1、性能上不如overlay2；
2、当文件进行写操作的时候，如果文件过大，或者文件位于底层的image中，则可能会引入高延迟。


### OverlayFS  
OverlayFS也是采用UFS模式，但相对于AUFS，其性能更高。在Docker中主要有overlay和overlay2两种实现。Docker-CE默认采用overlay2。  

    root@xftony:/var/lib/docker# docker info
		Containers: 0
		 Running: 0
		 Paused: 0
		 Stopped: 0
		Images: 0
		Server Version: 18.03.0-ce
		Storage Driver: overlay2
        ......

OverlayFS中使用了两个目录，把一个目录置放于另一个之上，并且对外提供单个统一的视角。下层的目录叫做lowerdir，上层的叫做upperdir。对外展示的统一视图称作merged。创建一个容器，overlay驱动联合镜像层和一个新目录给容器。镜像顶层是overlay中的**只读**lowerdir，容器的新目录是**可读写**的upperdir。它们默认存储于`/var/lib/docker/overlay2/`目录下。如下所示，是刚下载好一个image后，该目录下的文件结构：     

	root@xftony:/var/lib/docker/overlay2# tree -L 2
	.
	├── 82f20fe6e3d9c9a33560b18bd0dcab53afeadca03bb7daea174e736d3ac4ee2d
	│   ├── diff
	│   ├── link
	│   ├── lower
	│   └── work
	├── 8fa01a5986e8a08c5c6af11c88015013841b89496a8d6cb65d6186dad03a12e6
	│   ├── diff
	│   └── link
	├── a6219957a4e46e40b78cf5d20624e0b42f51a12f83dd2b4c683e33a5932d634b
	│   ├── diff
	│   ├── link
	│   ├── lower
	│   └── work
	├── bce6bd75c4c2900eb51d3b103073a158ea17be3708461714f19eddb9e2bc9713
	│   ├── diff
	│   ├── link
	│   ├── lower
	│   └── work
	├── dbafc7976ac255df27aea16935b901745c1cf66487f142ec01b047998f139122
	│   ├── diff
	│   ├── link
	│   ├── lower
	│   └── work
	└── l
	    ├── CMR5LVSFJRXC7QA2ZF5MWLQB5Z -> ../82f20fe6e3d9c9a33560b18bd0dcab53afeadca03bb7daea174e736d3ac4ee2d/diff
	    ├── ENKIS3HQUBTP5TXRBSEBREVFSB -> ../a6219957a4e46e40b78cf5d20624e0b42f51a12f83dd2b4c683e33a5932d634b/diff
	    ├── EOAX5LBZ75SSQHO6VOVXVMEP6E -> ../dbafc7976ac255df27aea16935b901745c1cf66487f142ec01b047998f139122/diff
	    ├── OAFOUB3QEZRY42E4ERJHP6NVJG -> ../8fa01a5986e8a08c5c6af11c88015013841b89496a8d6cb65d6186dad03a12e6/diff
	    └── XR6454BGFPITLDXL4D7MPQEUHZ -> ../bce6bd75c4c2900eb51d3b103073a158ea17be3708461714f19eddb9e2bc9713/diff  

其中  
>`l`:目录下存储了多个软链接，使用短名指向其他各层；  
>`其他一级目录`：例如8fa01a5986e8a08c5等目录，为lowerdir，是一层层的镜像；   
>`diff`：包含该层镜像的具体内容，即`upperdir`和`lowerdir`，此处都为`lowerdir`；    
>`link`：记录该目录对应的短名；  
>`lower`：记录该目录的所有lowerdir，每一级间使用`:` 分隔；   
>`work`：该目录是OverlayFS功能需要的，会被如copy_up之类的操作使用；   

现在，我们使用该镜像创建一个container。创建成功后，会发overlay2目录下多了两个目录，`l`目录下也多了两个连接（我已经手动去掉了原有的目录结构）：    

	root@xftony:/var/lib/docker/overlay2# tree -L 2
	.
	├── 671ffb27cc5e04f7f7a6c2e61b82c74514df0ff57a2fb47fd45bb1902aa86688
	│   ├── diff
	│   ├── link
	│   ├── lower
	│   ├── merged
	│   └── work
	├── 671ffb27cc5e04f7f7a6c2e61b82c74514df0ff57a2fb47fd45bb1902aa86688-init
	│   ├── diff
	│   ├── link
	│   ├── lower
	│   └── work
	├── ...
	└── l
	    ├── 43XFRTJKKACM22VJ5VHRS4RJE4 -> ../671ffb27cc5e04f7f7a6c2e61b82c74514df0ff57a2fb47fd45bb1902aa86688/diff
	    ├── CAAAXEW6Q6BCCOG5XVXVVJN2PY -> ../671ffb27cc5e04f7f7a6c2e61b82c74514df0ff57a2fb47fd45bb1902aa86688-init/diff
	    ├── 
        ...

其中   
>`XXX-init`：这是顶层的`lowerdir`的父目录,因此也是只读的，它的目的是为了初始化container配置信息，譬如hostname等信息,`XXX`对应的是`upperdir`的父目录名；        
>`XXX`：这是`upperdir`的父目录，可读写，container的写操作都会发生在该层；    
>`merged`：该目录就是container的mount point，这就是暴露的`lowerdir`和`upperdir`的统一视图。任何对容器的改变也影响这个目录。  

此时可以通过mount查看overlay统一试图中的mount状态：   
   
    root@xftony:/var/lib/docker/overlay2# mount |grep overlay
	overlay on /var/lib/docker/overlay2/671ffb27cc5e04f7f7a6c2e61b82c74514df0ff57a2fb47fd45bb1902aa86688/merged type overlay (rw,relatime,
	lowerdir=/var/lib/docker/overlay2/l/CAAAXEW6Q6BCCOG5XVXVVJN2PY:
	/var/lib/docker/overlay2/l/CMR5LVSFJRXC7QA2ZF5MWLQB5Z:
	/var/lib/docker/overlay2/l/ENKIS3HQUBTP5TXRBSEBREVFSB:
	/var/lib/docker/overlay2/l/XR6454BGFPITLDXL4D7MPQEUHZ:
	/var/lib/docker/overlay2/l/EOAX5LBZ75SSQHO6VOVXVMEP6E:
	/var/lib/docker/overlay2/l/OAFOUB3QEZRY42E4ERJHP6NVJG,
	upperdir=/var/lib/docker/overlay2/671ffb27cc5e04f7f7a6c2e61b82c74514df0ff57a2fb47fd45bb1902aa86688/diff,
	workdir=/var/lib/docker/overlay2/671ffb27cc5e04f7f7a6c2e61b82c74514df0ff57a2fb47fd45bb1902aa86688/work)

##### OverlayFS下读写操作：   
目前感觉基本与AUFS一致，等后续理解深一点在补。
官方介绍在此[docker.docs](https://docs.docker.com/storage/storagedriver/overlayfs-driver/#how-container-reads-and-writes-work-with-overlay-or-overlay2)。   


##### OverlayFS优点    
1、可以在多个运行的container中高效的共享image，可以实现容器的快速启动，并减少磁盘占用量；  
2、支持页缓存共享，可以高效的是使用page cache；  
3、相较于AUFS等，性能更好。  

##### OverlayFS缺点    
1、只支持POSIX标准的一个子集，与其他文件系统的存在不兼容性，如对open和rename操作的支持；  

### BtrFS， DeviceMapper，ZFS，VFS
待补。。。


[Github-blog](https://xftony.github.io/docker/2018/05/04/Docker基础技术-Union-File-System.html)   
[CSDN](https://blog.csdn.net/xftony)