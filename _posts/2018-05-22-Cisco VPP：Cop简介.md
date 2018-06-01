---
layout: post
title: "Cisco VPP：Cop简介"
key: 2018-05-22
categories:
  - Vpp
tags:
  - Vpp
---
[Github-blog](https://xftony.github.io/all.html)     
[CSDN](https://blog.csdn.net/xftony)  

**注意**：本文使用的代码是2018.05.07提交的master分支上的code，其具体commitID是`c22fcba177bad2c755fdb6d4d52f2a799eceaf34`。  

### cop功能简介  
cop feature通过使用fib，实现数据包的依次匹配过滤功能。
目前的cop中仅存在一组功能节点`ip4-cop-whitelist`、`ip6-cop-whitelist`。它们主要的作用是通过添加fib表，对数据包进行**源地址**过滤。

<!--more-->     

### cop数据结构
其主要的数据结构是`cop_main_t`，其详细分解可见下图：  

![Cop数据结构](https://raw.githubusercontent.com/xftony/xftony.github.io/master/_images/2018-05-22-Cop数据结构2.png)  
 
图中将存放在cop\_main\_t结构体中的数据层层分解了，如你所见，分解到`vnet_config_main_t *cm`是一系列的指针，其中最重要的是两个指针分别是`vnet_conf_t *config_pool` 和 `u32 *config_string_heap`。   
![vnet_config_t数据结构](https://raw.githubusercontent.com/xftony/xftony.github.io/master/_images/2018-05-22-Cop数据结构3.png)  
 
![config_string_heap结构](https://raw.githubusercontent.com/xftony/xftony.github.io/master/_images/2018-05-22-Cop数据结构4.png)  
`config_pool`是通过`pool_get`函数进行分配，是一组vector；`config_string_heap`是通过`heap_alloc`函数进行分配的内存，其内存放的是真正的配置数据（fib-id）。



### cop函数简介  

##### interface cop功能的开关  

CLI命令为: `cop interface <interface-name> [disable]`  

	int cop_interface_enable_disable (u32 sw_if_index, int enable_disable)
	{
	  cop_main_t * cm = &cop_main;
	  vnet_sw_interface_t * sw;
	  int rv;
      /*开启cop，则将下一跳置为cop_input_node*/
	  u32 node_index = enable_disable ? cop_input_node.index : ~0;
	
	  /* sw是否为物理端口，不是则返回error： VNET_API_ERROR_INVALID_SW_IF_INDEX*/
	  sw = vnet_get_sw_interface (cm->vnet_main, sw_if_index);
	  if (sw->type != VNET_SW_INTERFACE_TYPE_HARDWARE)
	    return VNET_API_ERROR_INVALID_SW_IF_INDEX;
	  
      /*重定向到next_index，若next_index=~0，即disable，将不进行重定向*/
	  rv = vnet_hw_interface_rx_redirect_to_node (cm->vnet_main, sw_if_index, node_index);
	  return rv;
	}

##### 配置cop whitelist节点   

CLI命令：`cop whitelist <interface-name> [ip4][ip6][default][fib-id <NN>][disable]`

其对应的实现函数为`cop_interface_enable_disable` ，部分代码如下：

      //获取该端口原对应的配置信息，即index，此处得到的ci为～0
      ci = ccm->config_index_by_sw_if_index[a->sw_if_index];
      data->fib_index = fib_index;
      /*核心函数，feature的添加，详细的实现见xmind的截图，其大致过程是：
       *1、判断ci是否已存在，存在则将old_feature赋值为new_feature,并将新的配置将添加到new_feature;
       *2、 对new_feature按照feature_index(cop_feature_type_t)顺序快排;
       *3、 调用核心函数find_config_with_features,更新/创建config，各sw之间相同的config是可以共享的；
       *4、 配置引用次数reference_count自加，返回配置索引 */
      if (is_add)
	      ci = vnet_config_add_feature (vm, &ccm->config_main, ci, 
              next_to_add_del, data, sizeof (*data));
      else
	      ci = vnet_config_del_feature (vm, &ccm->config_main, ci, 
              next_to_add_del, data, sizeof (*data));
      //将得到的配置信息返回，存到对应sw的index中，便于快速查找
      ccm->config_index_by_sw_if_index[a->sw_if_index] = ci;


![image](https://raw.githubusercontent.com/xftony/xftony.github.io/master/_images/2018-05-22-Cop核心函数1.png)


### cop使用示例     
cop具体配置过程如下：  

    //添加一个用于cop的fib table
	ip table add 1000     
    //添加fib 1000，接收所有的数据包   
	ip route table 1000 add 0.0.0.0/0 via local  
    //添加fib 1001，默认drop所有数据包
    ip table add 1001
    //创建一个tap端口
	create tap id 1 host-ip4-addr 10.1.1.1/24
	set interface ip table tap1 1
	set interface state tap1 up
	set interface ip address tap1 10.1.1.2/24
    //开启tap1的cop 
	cop interface tap1
    //添加配置，即fib-id
	cop whitelist tap1 ip4 fib-id 1000
	cop whitelist tap1 ip4 fib-id 1001

其trace结果如下：  
  
    00:04:52:040822: virtio-input
	  virtio: hw_if_index 2 next-index 6 vring 0 len 98
	    hdr: flags 0x00 gso_type 0x00 hdr_len 0 gso_size 0 csum_start 0 csum_offset 0 num_buffers 1
	00:04:52:040833: cop-input
	  COP_INPUT: sw_if_index 2, next index 0
	00:04:52:040840: ip4-cop-whitelist
	  IP4_COP_WHITELIST: sw_if_index 2, next index 0
	  IP4_COP_WHITELIST: sw_if_index 2, next index 6
	00:04:52:040873: error-drop
	  ip4-cop-whitelist: ip4 cop whitelist packets dropped

数据包先进入`cop-input`节点，然后进入`ip4-cop-whitelist`，进行fib 1000的匹配，匹配成功，`next index`是自身，再次进入`ip4-cop-whitelist`进行fib 1001的匹配，drop。

以上～