---
layout: post
title: "问题&解决：cgroups之cpuset中tasks无法加入新的pid"
key: 2018-05-08-2
categories:
  - Docker
tags:
  - cgroups
  - Docker
  - 问题&解决
---


[Github-blog](https://xftony.github.io/docker/2018/05/08/问题&解决-cgroups之cpuset中tasks无法加入新的pid.html)   
[CSDN-blog](https://blog.csdn.net/xftony)

### 问题：cpuset中tasks无法加入新的pid    

	root@xftony:~/test/c0/c1/cputest# echo 4847 > tasks  
     -bash: echo: write error: No space left on device

### 原因   

在添加tasks之前，`cpuset.cpus`和`cpuset.mems`需要提前进行配置。`cpuset.cpus`中为该组cgroup中可用的cpu_node, 默认情况下，配置了所有的可用cpu。`cpuset.mems`中为该组cgroup中可用的mem_node，默认为空。
NUMA模式下，处理器被划分成多个“节点”（node），每个节点被分配有的本地存储器空间。 每个节点被分配有的本地存储器空间. 所有节点中的处理器都可以访问全部的系统物理存储器，但是访问本节点内的存储器所需要的时间，比访问某些远程节点内的存储器所花的时间要少得多。  
同时内存也被分割成多个区域（BANK，也叫“簇”），依据簇与处理器的“距离”不同, 访问不同簇的代码也会不同. 比如，可能把内存的一个簇指派给每个处理器，或则某个簇和设备卡很近，很适合DMA，那么就指派给该设备。因此当前的多数系统会把内存系统分割成2块区域，一块是专门给CPU去访问，一块是给外围设备板卡的DMA去访问。    
Linux把物理内存划分为三个层次来管理    

|    层次          |   描述   |     
|:--------------:|:---------------:|   
| 存储节点(Node)   | CPU被划分为多个节点(node), 内存则被分簇, 每个CPU对应一个本地物理内存, 即一个CPU-node对应一个内存簇bank，即每个内存簇被认为是一个节点 |      
| 管理区(Zone)	    |每个物理内存节点node被划分为多个内存管理区域, 用于表示不同范围的内存, 内核可以使用不同的映射方式映射物理内存 |  
| 页面(Page)	     | 内存被细分为多个页面帧, 页面是最基本的页面分配的单位　|    

[memory node详细介绍](https://blog.csdn.net/gatieme/article/details/52384075) 

### 解决    

为其指定特定的memory_node，例如指定0号内存节点：    
 
    echo 0 > cpuset.mems

此时，tasks就可以添加新的pid：   

    echo 4847 > tasks 


[Github-blog](https://xftony.github.io/docker/2018/05/08/问题&解决-cgroups之cpuset中tasks无法加入新的pid.html)  
[CSDN-blog](https://blog.csdn.net/xftony)