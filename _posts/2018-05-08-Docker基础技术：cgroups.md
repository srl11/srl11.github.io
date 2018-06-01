---
layout: post
title: "Docker技术基础：Cgroups"
key: "Docker技术基础：Cgroups"
categories:
  - Docker
tags:
  - Cgroups
  - Docker
---
[Github-blog](https://xftony.github.io/all.html)       
[CSDN](https://blog.csdn.net/xftony)  

##  cgroups简介

cgroups(control groups)包含三个组件，分别为cgroup、hierarchy，以及subsystem。  
<!--more-->  
### cgroup   

cgroup是对进程分组管理的一种机制，cgroups中的资源控制都以cgroup为单位实现。cgroup表示按某种资源控制标准划分而成的任务组，包含一个或多个子系统。一个任务可以加入某个cgroup，也可以从某个cgroup迁移到另外一个cgroup。
    
### subsystem    
subsystem 是一组资源控制的模块，主要包含cpuset, cpu, cpuacct, blkio, memory, devices, freezer, net_cls, net_prio, perf_event, hugetlb, pids。具体介绍如下：    
    
    cpuset     在多核机器上设置cgroup 中进程可以使用的CPU 和内存   
    cpu        设置cgroup 中进程的CPU 被调度的策略  
    cpuacct    可以统计cgroup 中进程的CPU 占用  
    blkio      设置对块设备（比如硬盘）输入输出的访问控制  
    memory     用于控制cgroup 中进程的内存占用  
    devices    控制cgroup 中进程对设备的访问  
    freezer    用于挂起和恢复cgroup 中的进程  
    net_cls    用于将cgroup 中进程产生的网络包分类，以便Linux 的tc (traffic con位oller）可以根据分类区分出来自某个cgroup 的包并做限流或监控  
    net_prio   设置cgroup 中进程产生的网络流量的优先级  
    perf_event 增加了对每group的监测跟踪的能力，即可以监测属于某个特定的group的所有线程以及运行在特定CPU上的线程  
    hugetlb    限制HugeTLB(huge translation lookaside buffer)的使用，TLB是MMU中的一块高速缓存(也是一种cache，是CPU内核和物理内存之间的cache)，它缓存最近查找过的VA对应的页表项   
    pids       限制cgroup及其所有子孙cgroup里面能创建的总的task数量    

查看kernel支持的subsystem可以使用`lssubsys`命令：  

		root@xftony:~# lssubsys -a
		cpuset
		cpu,cpuacct
		blkio
		memory
		devices
		freezer
		net_cls,net_prio
		perf_event
		hugetlb
		pids   

同时可以在`/sys/fs/cgroup/memory`目录下可以查看：  
 
      root@xftony:/sys/fs/cgroup# ls
		blkio    cpu,cpuacct  freezer  net_cls           perf_event
		cpu      cpuset       hugetlb  net_cls,net_prio  pids
		cpuacct  devices      memory   net_prio          systemd
     

### hierarchy    

把一组cgroup串成一个树状的结构，一个这样的树便是一个hierarchy。一个系统可以有多个hierarchy。通过这种树状结构，cgroups可以做到继承。    
下面这个例子就是一颗hierarchy， 其中c0是其根节点，c1、c2是c0的子节点，会继承c0的限制，c1、c2可以在cgroup-test的基础上定制特殊的资源限制条件。   

	root@xftony:~/test/c0# tree
	.
	├── c1
	│   ├── cgroup.clone_children
	│   ├── cgroup.procs
	│   ├── notify_on_release
	│   └── tasks
	├── c2
	│   ├── cgroup.clone_children
	│   ├── cgroup.procs
	│   ├── notify_on_release
	│   └── tasks
	├── cgroup.clone_children
	├── cgroup.procs
	├── cgroup.sane_behavior
	├── notify_on_release
	├── release_agent
	└── tasks

###  cgroup、subsystem、hierarchy三者关系    
1、一个subsystem只能附加到一个hierarchy上面；  
2、一个hierarcy可以附加多个subsystem；  
3、一个进程可以作为多个cgroup的成员，但是这些cgroup必须不在同一个hierarchy上。在不同的hierarchy上可以拥有多个subsystem，进行多个条件限制；   
4、一个进程fork出来的子进程开始时一定跟父进程在同一个cgroup中，后面可以根据需要将其移动到其他cgroup中；    
5、创建好一个hierarchy后，所有的进程都会加入这个hierarchy的根结点（暂时觉得很奇怪==);    
6、cgroups里面的task内放置遵循该cgroup的进行id（pid），同一个hierarchy里面，只能有一个。   


##  cgroups测试：

### cgroup的创建
创建一个挂载点，即创建一个文件夹，存放cgroup文件:  

    #mkdir cgroup-test  

挂载一个hierachy，不关联任何subsystem
      
    #mount -t cgroup -o none,name=cgroup-root cgroup-root1 ./cgroup-test   
    //此时使用mount查看可以看到   
    root@pgw-dev-4:~/test/cgroup-test# mount |grep cgroup 
    cgroup-root1 on /root/test/cgroup-test type cgroup (rw,relatime,name=cgroup-root)     
cgroup-test 目录下会生成一组默认文件：  

	root@pgw-dev-4:~/test/cgroup-test# ls  
	cgroup.clone_children  cgroup.procs cgroup.sane_behavior notify_on_release  release_agent  tasks   

`cgroup.procs`内为树中当前节点的所有进程ID；  
`tasks`文件内存放所有隶属于跟cgroup节点的线程ID；    
`cgroup.sane_behavior`标记`sane_behavior`是否生效,"Linux 3.16-rc2"后，该flag在non-default模式下已删除;    
`notify_on release`和`release_agent`会一起使用，`notify_on release`标识当这个cgroup最后一个进程退出的时候是否执行了release_agent;   
`release_agent`是一个路径，通常用作进程退出之后自动清理掉不再使用的cgroup。
  
查看`cgroup.procs`和`tasks`，我们可以看到系统中正在运行的进程和线程ID；    

此时我们在创建一个新的hierachy `c0`

     #mount -t cgroup -o cpuset,name=c0-cpuset c0 ./c0
所有的`cgroup.procs`和`tasks`也都会加到c0内的`cgroup.procs`和`tasks`。  

### subsystem的挂载

subsystem默认的mount的位置是在`/sys/fs/cgroup/XXX`，可以使用`lssubsys -am`命令查看。因为**一个subsystem只能附加到一个hierarchy上面**，因此在测试前，我们想将一些subsustem从原位置上umount，此处我们以memory和cpuset为例：
  
##### umount subsystem

    umount /sys/fs/cgroup/cpuset/cpuset

##### mount subsystem 
然后我们在创建c0, c0上不绑subsustem，然后在c0下创建c1, c1上mount cpuset子系统：

    mkdir c0
	mount -t cgroup -o none c0 ./c0
	mkdir c1;　cd c1
    mount -t cgroup -o cpuset  c0 ./c1


其得到的cgroup结构为：

	root@xftony:~/test# tree -L 3
	.
	└── c0
	    ├── c1
	    │   ├── cgroup.clone_children
	    │   ├── cgroup.procs
	    │   ├── cgroup.sane_behavior
	    │   ├── cpuset.cpu_exclusive
	    │   ├── cpuset.cpus
	    │   ├── cpuset.effective_cpus
	    │   ├── cpuset.effective_mems
	    │   ├── cpuset.mem_exclusive
	    │   ├── cpuset.mem_hardwall
	    │   ├── cpuset.memory_migrate
	    │   ├── cpuset.memory_pressure
	    │   ├── cpuset.memory_pressure_enabled
	    │   ├── cpuset.memory_spread_page
	    │   ├── cpuset.memory_spread_slab
	    │   ├── cpuset.mems
	    │   ├── cpuset.sched_load_balance
	    │   ├── cpuset.sched_relax_domain_level
	    │   ├── notify_on_release
	    │   ├── release_agent
	    │   └── tasks
	    ├── cgroup.clone_children
	    ├── cgroup.procs
	    ├── cgroup.sane_behavior
	    ├── notify_on_release
	    ├── release_agent
	    └── tasks

### cgroup的使用

在c1目录下创建测试目录`cputest`，然后设置`cpu`限制。  
    
    cd c1
    mkdir cputest; cd cputest
    //仅允许使用 Cpu1
    echo 1 > cpuset.cpus

启动测试程序：  
   
    root@xftony:~/test# cat test.sh
    touch /root/test/my.lock
	lock_file=/root/test/my.lock
	x=0
	while [ -f $lock_file ];do
	    x=$x+1
	done;
    root@xftony:~/test#./test.sh

此时top查看其内存cpu占用情况：    

	%Cpu0  : 75.0 us, 23.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  2.0 st
	%Cpu1  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
	%Cpu2  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
	%Cpu3  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
    PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND                                     
	32664 root      20   0   23268   5828   2228 R  99.3  0.1   1:13.56 bash  

我们将该脚本的pid：`32664`加入到`cputest`的`tasks`下：
    
    root@xftony:~/test/c0/c1/cputest#echo 32664 > tasks

此时在top中，该进程已经迁移到`Cpu1`中：

    %Cpu0  :  0.0 us,  0.3 sy,  0.0 ni, 99.7 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
	%Cpu1  : 77.1 us, 22.9 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
	%Cpu2  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
	%Cpu3  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
	PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND                                     
	32664 root      20   0   25060   7636   2228 R 100.0  0.1   5:09.95 bash

top中cpu各参数含义：

	us 用户空间占用CPU百分比
	sy 内核空间占用CPU百分比
	ni 用户进程空间内改变过优先级的进程占用CPU百分比
	id 空闲CPU百分比
	wa 等待输入输出的CPU时间百分比
	hi 硬件中断
	si 软件中断 
	st: 实时

以上～ 
