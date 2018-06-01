---
layout: post
title: "Docker技术基础：Linux namespaces"
key: 2018-04-25
categories:
  - Docker
tags:
  - Linux
  - Namespace
  - Docker
---
[Github-blog](https://xftony.github.io/all.html)     
[CSDN-blog](https://blog.csdn.net/xftony/article/details/80160172)  

### Linux内核支持的namespaces   
<!--more-->
[详细介绍](http://man7.org/linux/man-pages/man7/namespaces.7.html)

    名称         宏定义            隔离内容
    Cgroup      CLONE_NEWCGROUP   Cgroup root directory (since Linux 4.6)
	IPC         CLONE_NEWIPC      System V IPC, POSIX message queues (since Linux 2.6.19)
	Network     CLONE_NEWNET      Network devices, stacks, ports, etc. (since Linux 2.6.24)
	Mount       CLONE_NEWNS       Mount points (since Linux 2.4.19)
	PID         CLONE_NEWPID      Process IDs (since Linux 2.6.24)
	User        CLONE_NEWUSER     User and group IDs (started in Linux 2.6.23 and completed in Linux 3.8)
	UTS         CLONE_NEWUTS      Hostname and NIS domain name (since Linux 2.6.19)

### namespace添加    
创建一个命名空间的方法是使用clone()系统调用。其具体函数为`int clone(int(*child_func)(void *), void *child_stack, int flags, void*arg);`。在go语言中，可以通过调用syscall创建新的命名空间。 如下，该段代码为“sh”创建了一个UTS namespace和一个IPC namespace。PS：代码摘自[《自己动手写Docker》](https://book.douban.com/subject/27082348/)  

	root@xftony:~/test# cat main.go 
	package main
	import ( "log"
	  "os"
	 "os/exec"
	  "syscall")
	func main () {
	    cmd := exec.Command ( "sh")
	    cmd.SysProcAttr = &syscall.SysProcAttr{
	        Cloneflags: syscall.CLONE_NEWUTS | syscall.CLONE_NEWIPC,
	    }
	    cmd.Stdin = os.Stdin
	    cmd.Stdout = os.Stdout
	    cmd.Stderr = os.Stderr
	    if err:= cmd.Run() ; err != nil {
	        log.Fatal(err)
	    }
	}

### namespace查看   
       
    //查看进程所属的namespace，以进程18为例： 
    root@xftony:~/test# ll /proc/18/ns    
    total 0    
	dr-x--x--x 2 root root 0 Apr 25 21:14 ./    
	dr-xr-xr-x 9 root root 0 Apr 25 19:41 ../   
	lrwxrwxrwx 1 root root 0 Apr 25 21:39 cgroup -> cgroup:[4026531835]    
	lrwxrwxrwx 1 root root 0 Apr 25 21:14 ipc -> ipc:[4026531839]   
	lrwxrwxrwx 1 root root 0 Apr 25 21:14 mnt -> mnt:[4026531840]    
	lrwxrwxrwx 1 root root 0 Apr 25 21:14 net -> net:[4026531957]   
	lrwxrwxrwx 1 root root 0 Apr 25 21:14 pid -> pid:[4026531836]    
	lrwxrwxrwx 1 root root 0 Apr 25 21:14 user -> user:[4026531837]   
	lrwxrwxrwx 1 root root 0 Apr 25 21:14 uts -> uts:[4026531838]

### namespace维持    
当一个namespace中的所有进程都退出时，该namespace将会被销毁。当然还有其他方法让namespace一直存在，假设我们有一个进程号为1000的进程，以ipc namespace为例：

通过`mount --bind`命令。例如`mount --bind /proc/1000/ns/ipc /other/file`，就算属于这个`ipc namespace`的所有进程都退出了，只要`/other/file`还在，这个`ipc namespace`就一直存在，其他进程就可以利用`/other/file`，通过`setns`函数加入到这个namespace

在其他namespace的进程中打开`/proc/1000/ns/ipc`文件，并一直持有这个文件描述符不关闭，以后就可以用`setns`函数加入这个namespace。

以上～
   