---
layout: post
title: "Kubernetes插件：Intel-SRIOV-CNI插件简介/修改"
key: 2018-04-18-sriov
categories:
  - Kubernetes
tags:
  - Kubernetes
---
[Github-blog](https://xftony.github.io/all.html)   
[CSDN-blog](https://blog.csdn.net/xftony)  

### sriov-cni简介   
sriov-cni是[hustcat/sriov-cni](https://github.com/hustcat/sriov-cni)开发的一种容器网络插件（Container Network Interface），它使得容器可以直接使用物理机中扩展出来的VF（virtual functions）。Intel在此基础上，为其添加了dpdk功能。本文介绍的sriov-cni的版本为[Intel版](https://github.com/Intel-Corp/sriov-cni)，修改也是基于Intel版本进行的修改，对应的版本是2017.10.12，具体commit为`f45d68b638df76261170bd585fb4014b99990548`

<!--more-->

### sriov-cni代码简介  
sriov-cni主要通过调用netlink包将vf修改到容器的namespace下，使得VF可以被容器直接调用。其中VF是指支持SRIOV的物理网卡所虚拟出的一个“网卡”或者说虚出来的一个实例，它会以一个独立网卡的形式呈现出来，每一个VF有它自己独享的PCI配置区域，并且可能与其他VF共享着同一个物理资源（公用同一个物理网口）
根据cni的标准定义两个函数cmdAdd和cmdDel，分别用于VF的添加和删除`skel.PluginMain(cmdAdd, cmdDel)`
cmdAdd和cmdDel基本是一对反过程，所以这里就只简单介绍一下cmdAdd函数。

	 func cmdAdd(args *skel.CmdArgs) error {
		n, err := loadConf(args.StdinData) // 将输入参数转化为NetConf变量n
		if err != nil {
			return fmt.Errorf("failed to load netconf: %v", err)
		}
		// 获取container的net命名空间，args.Netns是container的在host中的网络命名空间路径
		netns, err := ns.GetNS(args.Netns)
		if err != nil {
			return fmt.Errorf("failed to open netns %q: %v", netns, err)
		}
		defer netns.Close()

		if n.IF0NAME != "" {
			args.IfName = n.IF0NAME
		}
	    // 核心函数，配置VF，将VF移动到container的命名空间
		if err = setupVF(n, n.IF0, args.IfName, args.ContainerID, netns); err != nil {
			return fmt.Errorf("failed to set up pod interface %q from the device %q: %v", args.IfName, n.IF0, err)
		}
	
		// 在DPDK 和L2模式下， 无需调用IPAM进行IP分配
		var result *types.Result
		if n.DPDKMode != false || n.L2Mode != false {
			return result.Print()
		}
	
		// 调用IPAM插件，并返回配置
		result, err = ipam.ExecAdd(n.IPAM.Type, args.StdinData)
		if err != nil {
			return fmt.Errorf("failed to set up IPAM plugin type %q from the device %q: %v", n.IPAM.Type, n.IF0, err)
		}
		if result.IP4 == nil {
			return errors.New("IPAM plugin returned missing IPv4 config")
		}
	
		err = netns.Do(func(_ ns.NetNS) error {
			return ipam.ConfigureIface(args.IfName, result)
		})
		if err != nil {
			return err
		}
	
		result.DNS = n.DNS
	    //返回分配结果
		return result.Print()
	}

下面简单介绍一下sriov-cni的核心函数setupVF（），其基本实现步骤是，通过if0找到可用的VF，并设置为up，然后将VF移动到container的网络命名空间，重命名为ifName，即container内部看到的网卡名称

	func setupVF(conf *NetConf, ifName string, podifName string, cid string, netns ns.NetNS) error {
		var vfIdx int
		var infos []os.FileInfo
		var pciAddr string
	    //通过ifName获取if0，即m
		m, err := netlink.LinkByName(ifName)
		if err != nil {
			return fmt.Errorf("failed to lookup master %q: %v", conf.IF0, err)
		}
	    
		// 通过读取/sys/class/net/<if0>/device/sriov_numvfs 文件获取VF个数
		vfTotal, err := getsriovNumfs(ifName)
		if err != nil {
			return err
		}
	
		if vfTotal <= 0 {
			return fmt.Errorf("no virtual function in the device %q: %v", ifName)
		}
	    //遍历PF目录下的VF，找到一个满足条件的VF
		for vf := 0; vf <= (vfTotal - 1); vf++ {
			vfDir := fmt.Sprintf("/sys/class/net/%s/device/virtfn%d/net", ifName, vf)
			if _, err := os.Lstat(vfDir); err != nil {
				if vf == (vfTotal - 1) {
					return fmt.Errorf("failed to open the virtfn%d dir of the device %q: %v", vf, ifName, err)
				}
				continue
			}
	
			infos, err = ioutil.ReadDir(vfDir)
			if err != nil {
				return fmt.Errorf("failed to read the virtfn%d dir of the device %q: %v", vf, ifName, err)
			}
	
			if (len(infos) == 0) && (vf == (vfTotal - 1)) {
				return fmt.Errorf("no Virtual function exist in directory %s, last vf is virtfn%d", vfDir, vf)
			}
	
			if (len(infos) == 0) && (vf != (vfTotal - 1)) {
				continue
			}
	
			if len(infos) == maxSharedVf {
				conf.Sharedvf = true
			}
	
			if len(infos) <= maxSharedVf {
				vfIdx = vf
	            //获取PCI地址， host上“/sys/class/net/<if0>/device/<VF>”
				pciAddr, err = getpciaddress(ifName, vfIdx)
				if err != nil {
					return fmt.Errorf("err in getting pci address - %q", err)
				}
				break
			} else {
				return fmt.Errorf("mutiple network devices in directory %s", vfDir)
			}
		}
	
		// VF NIC name
		if len(infos) != 1 && len(infos) != maxSharedVf {
			return fmt.Errorf("no virutal network resources avaiable for the %q", conf.IF0)
		}
	
		if conf.Sharedvf != false && conf.L2Mode != true {
			return fmt.Errorf("l2enable mode must be true to use shared net interface %q", conf.IF0)
		}
	
		if conf.Vlan != 0 {
			if err = netlink.LinkSetVfVlan(m, vfIdx, conf.Vlan); err != nil {
				return fmt.Errorf("failed to set vf %d vlan: %v", vfIdx, err)
			}
	
			if conf.Sharedvf {
				if err = setSharedVfVlan(ifName, vfIdx, conf.Vlan); err != nil {
					return fmt.Errorf("failed to set shared vf %d vlan: %v", vfIdx, err)
				}
			}
		}
	    //如果是dpdk模式，为DPDKConf结构体赋值，
		if conf.DPDKMode != false {
			conf.DPDKConf.PCIaddr = pciAddr
			conf.DPDKConf.Ifname = podifName
			conf.DPDKConf.VFID = vfIdx
	        //配置文件以 containID-If0name 方式命名， 将其保存在conf.CNIDir目录下，即配置文件中cniDir，默认“/var/lib/cni/sriov”
	        //注意在k8s中这里的containID是pod中pod-container的id，而不是pod内真正执行服务的container的id。
			if err = savedpdkConf(cid, conf.CNIDir, conf); err != nil {
				return err
			}
	        //调用dpdk_tool脚本，更新VF驱动,划重点
			return enabledpdkmode(&conf.DPDKConf, infos[0].Name(), true)
		}
	
		// Sort links name if there are 2 or more PF links found for a VF;
		if len(infos) > 1 {
			// sort Links FileInfo by their Link indices
			sort.Sort(LinksByIndex(infos))
		}
	
		for i := 1; i <= len(infos); i++ {
			vfDev, err := netlink.LinkByName(infos[i-1].Name())
			if err != nil {
				return fmt.Errorf("failed to lookup vf device %q: %v", infos[i-1].Name(), err)
			}
	        //调用netlink库函数实现set link up， 类似`ip link set $link up`
			if err = netlink.LinkSetUp(vfDev); err != nil {
				return fmt.Errorf("failed to setup vf %d device: %v", vfIdx, err)
			}
	
			// 将VF移动到container的命名空间，类似`ip link set $link netns $ns`
			if err = netlink.LinkSetNsFd(vfDev, int(netns.Fd())); err != nil {
				return fmt.Errorf("failed to move vf %d to netns: %v", vfIdx, err)
			}
		}
	
		return netns.Do(func(_ ns.NetNS) error {
	
			ifName := podifName
			for i := 1; i <= len(infos); i++ {
				if len(infos) == maxSharedVf && i == len(infos) {
					ifName = podifName + fmt.Sprintf("d%d", i-1)
				}
	            //将该VF重命名为ifName
				err := renameLink(infos[i-1].Name(), ifName)
				if err != nil {
					return fmt.Errorf("failed to rename %d vf of the device %q to %q: %v", vfIdx, infos[i-1].Name(), ifName, err)
				}
	
				// for L2 mode enable the pod net interface
				if conf.L2Mode != false {
					err = setUpLink(ifName)
					if err != nil {
						return fmt.Errorf("failed to set up the pod interface name %q: %v", ifName, err)
					}
				}
			}
			return nil
		})
	}


### sriov修改版介绍
sriov实现了container中调用host VF的功能，在使用时也发现了一切不足之处（或许是我了解不足导致的误解，如是，请指正），例如：
>1、sriov-cni在保存dpdk配置的后，若dpdk驱动更新可能失败，但是配置不会被删除;  
>2、在k8s下使用，其保存dpdk配置的时候，使用的是pod-container-id（k8s会为每个pod创建一个container以提供相应网络服务等），对于container无法识别其被分配到的VF，因为container可以看到所有的包括分配给其他container的VF；(这里它目的可能只是为了保存删除时需要的信息，但是container内存在需要使用其dpdk信息的场景，所以可以修改一下)  
>3、sriov-cni进保存dpdk模式的配置信息，对于普通的sriov不会进行配置信息的保存；  
>4、不支持直接使用PF。 
 
对应修改：
>1、保存dpdk配置文件和开启dpdk驱动的代码顺序对调，保证在启动更新成功的情况下才会保存配置文件；  
>2、配置文件路径添加一级容器网络命名空间ID，从而使得容器内可以识别自身的配置文件；  
>3、添加netconf的配置保存；    
>4、类似VF，添加setupPF（），实现与setupVF（）基本一致。  

针对上述的“问题”，我做了一个修改版的，亲测可用。  [自提](https://github.com/xftony/sriov-cni)    
把这个`/bin/sriov`文件放到`/opt/cni/bin/`下即可

以上～
 