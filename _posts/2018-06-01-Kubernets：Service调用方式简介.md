---
layout: post
title: "Kubernets：External Service调用方式简介"
key: 2018-06-01
categories:
  - Kubernetes
tags:
  - Kubernetes
---

### Service简介  
Service定义了Pod的逻辑集合和访问该集合的策略，是真实服务的抽象。Service提供了一个统一的服务访问入口以及服务代理和发现机制，用户不需要了解后台Pod是如何运行。详细的[service介绍](https://kubernetes.io/docs/concepts/services-networking/service/)。本文仅讨论服务被调用的三种方式。
<!--more-->
### Service调用方式  
每一个服务都会有一个字段定义了该服务如何被调用（发现），这个字段的值可以为：

>ClusterIP:使用一个集群固定IP(默认);  
>NodePort：使用一个集群固定IP，但是额外在每个POD上均暴露这个服务，端口;    
>LoadBalancer：使用集群固定IP和NodePort，额外还会申请申请一个负载均衡器来转发到服务。   


##### ClusterIP
ClusterIP是k8s默认方式，ClusterIP的范围通过k8s API Server的启动参数 `--service-cluster-ip-range=19.254.0.0/16`配置。

**示例**  
所有包含“app:my-app”标签的pod将被该service代理，对外暴露80端口，绑定pod的也是80端口

	apiVersion: v1
	kind: Service
	metadata:  
	  name: my-internal-service
	selector:    
	  app: my-app
	spec:
	  type: ClusterIP
	  ports:  
	  - name: http
	    port: 80
	    targetPort: 80
	    protocol: TCP

**缺点**
>1、无法向外提供服务，通过proxy可以从外部访问，但是需要认证user;    
>2、不提供指定端口，访问指定端口会失败（ECONNREFUSED）。   


##### NodePort  
创建一个NodePort service，kube-proxy在每个node的eth0上创建一个端口（30000–32767），到达这些端口的请求会被proxy转发到这个服务。  
**示例**  
 
	kind: Service
	apiVersion: v1
	metadata:
	  name: service-test
	spec:
	  type: NodePort
	  selector:
	    app: service_test_pod
	  ports:
	  - port: 80
	    targetPort: http

	root@xftony:~/xftony/podYaml# kubectl get svc service-test
	NAME           CLUSTER-IP     EXTERNAL-IP   PORT(S)           AGE
	service-test   10.3.241.152   <none>        80:32213/TCP      1m
**缺点**
>1、内部使用的端口是非常规端口（30000–32767）；  
>2、端口与服务一对一匹配，端口数目有限，上限为2768个。    


##### LoadBalancer
创建一个loadbalancer类型的Service,使用IPTABLES和用户命名空间来代理虚拟IP。  

**示例**

	kind: Service
	apiVersion: v1
	metadata:
	  name: service-test
	spec:
	  type: LoadBalancer
	  selector:
	    app: service_test_pod
	  ports:
	  - port: 80
	    targetPort: http

**缺点**
>1、无法进行带宽控制；  
>2、loadBalancer与service之间一一对应，无法服务多个service


### 实例分析  
外部client访问到serverPod的具体过程如图所示(以前看过的图，忘记从哪里看到的了==)：

![外部访问示意图](https://raw.githubusercontent.com/xftony/xftony.github.io/master/_images/2018-06-01-Kubernets-External-Service调用方式简介.jpg)  

>1、client通过public IP访问load balancer；   
>2、load banlancer选择一个node然后重定向到该node的32213端口，即10.100.0.3:32213；  
>3、router将请求转发到相应node;    
>4、kube-proxy监听指定的端口，将该请求转发到对应的clusterIP，即10.3.241.152:80；   
>5、netfilter将该地址重定向到10.0.2.2:8080，即访问到指定的ServerPod。


以上～