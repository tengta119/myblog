---
title: 基于Java与Netty的RPC框架
categories:
  - 微服务与分布式
tags:
  - Java
  - RPC
  - Netty
  - ZooKeeper
date: 2025-02-24 21:35:43
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%9F%BA%E4%BA%8EJava%E4%B8%8ENetty%E7%9A%84RPC%E6%A1%86%E6%9E%B6-01.png
---
# 1.1 - 基本的rpc调用
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%9F%BA%E4%BA%8EJava%E4%B8%8ENetty%E7%9A%84RPC%E6%A1%86%E6%9E%B6-01.png#pic_center)

# 1.2 - 引入netty框架
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%9F%BA%E4%BA%8EJava%E4%B8%8ENetty%E7%9A%84RPC%E6%A1%86%E6%9E%B6-02.png#pic_center)

## Client

客户端有服务端的**功能接口**，因此通过此接口创建代理对象，此对象内部会有netty的客户端，当用户调用代理对象的方法时，netty的客户端会向服务端发送请求并返回数据

## Server

在服务端启动后，会把自身放入一个map中，在收到请求后且是RpcRequest时，会触发NettyRPCServerHandler处理器，根据RpcRequest中的interfaceName信息，找到服务端的实例，再调用相关的方法，最后返回结果



# 1.3 - 引入zookeeper作为注册中心
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%9F%BA%E4%BA%8EJava%E4%B8%8ENetty%E7%9A%84RPC%E6%A1%86%E6%9E%B6-03.png#pic_center)

# 2.1 - 自定义编码器
解码器和序列化器

## BUG

**fastJson：** 接口的方法的参数类型要用包装类，负责会出现类型不匹配的bug

```ba
MyDecoder解码失败java.lang.ClassCastException: class java.lang.Integer cannot be cast to class com.alibaba.fastjson.JSONObject (java.lang.Integer is in module java.base of loader 'bootstrap'; com.alibaba.fastjson.JSONObject is in unnamed module of loader 'app')
```



# 2.2 - 在客户端建立本地服务缓存并实现动态更新

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%9F%BA%E4%BA%8EJava%E4%B8%8ENetty%E7%9A%84RPC%E6%A1%86%E6%9E%B6-04.png#pic_center)




# 3.1 - 负载均衡

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%9F%BA%E4%BA%8EJava%E4%B8%8ENetty%E7%9A%84RPC%E6%A1%86%E6%9E%B6-05.png#pic_center)


负载均衡算法

```java
    //虚假节点的数量 一个真实节点对应5个虚拟节点
    private static final int VIRTUAL_NUM = 5;

    //虚拟节点的分配
    private SortedMap<Integer, String> shards = new TreeMap<>();

    //真实节点列表
    private List<String> realNodes = new ArrayList<>();

    //模拟初始服务器
    private String[] servers = null;

    private void init(List<String> serviceList) {
        for (String server : serviceList) {
            realNodes.add(server);
            System.out.println("真实节点[" + server + "] 被添加");
            for (int i = 0; i < VIRTUAL_NUM; i++) {
                String virtualNode = server + "&&VN" + i;
                int hash = getHash(virtualNode);
                shards.put(hash, virtualNode);
                System.out.println("虚拟节点[" + virtualNode + "] hash:" + hash + "，被添加");
            }
        }
    }

    public String getServer(String node, List<String> serviceList) {
        this.init(serviceList);
        int hash = getHash(node);
        Integer key = null;
        SortedMap<Integer, String> subMap = shards.tailMap(hash);
        if (subMap.isEmpty()) {
            key = shards.lastKey();
        } else {
            key = subMap.firstKey();
        }
        String virtualNode = shards.get(key);
        return virtualNode.substring(0, virtualNode.indexOf("&&"));
    }

    /**
     * @param: str
     * @return: int
     * @description: FNV1_32_HASH算法
     */
    private static int getHash(String str) {
        final int p = 16777619;
        int hash = (int) 2166136261L;
        for (int i = 0; i < str.length(); i++) {
            hash = (hash ^ str.charAt(i)) * p;
        }
        hash += hash << 13;
        hash ^= hash >> 7;
        hash += hash << 3;
        hash ^= hash >> 17;
        hash += hash << 5;
        if (hash < 0) {
            hash = Math.abs(hash);
        }
        return hash;
    }

    public String balance(List<String> addressList) {
        String random = UUID.randomUUID().toString();
        return getServer(random, addressList);
    }
```



# 3.2 - 超时重试&白名单

使用 **guavaRetry** 实现超时重连

在 **zk** 上新增节点 **MyRPC/CanRetry** 代表可以超时重试的服务

## Client

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%9F%BA%E4%BA%8EJava%E4%B8%8ENetty%E7%9A%84RPC%E6%A1%86%E6%9E%B6-06.png#pic_center)


## Server

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%9F%BA%E4%BA%8EJava%E4%B8%8ENetty%E7%9A%84RPC%E6%A1%86%E6%9E%B6-07.png#pic_center)




# 4.1 - 服务-限流

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%9F%BA%E4%BA%8EJava%E4%B8%8ENetty%E7%9A%84RPC%E6%A1%86%E6%9E%B6-08.png#pic_center)




# 4.2 - 服务-熔断

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%9F%BA%E4%BA%8EJava%E4%B8%8ENetty%E7%9A%84RPC%E6%A1%86%E6%9E%B6-09.png#pic_center)

# 6.1 - 日志链路追踪
使用 **Slf4j** 的 **MDC** 日志记录时提供额外的上下文信息，
客户端在进行方法调用前会将 **traceID** 保存在 **MDC** 种，之后在正式发送请求前，会将 **traceID** 相关内容存入保存到Channel属性，因为在 **channel** 发送数据时， **netty** 内部会新起一个 **channel** 线程用于发送数据，如果不把 **traceID** 相关内容存入保存到Channel属性，那么在编码过程种会无法获取 **traceID** 相关内容，那么服务端就会无法实现日志链路追踪
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/img%E5%9F%BA%E4%BA%8EJava%E4%B8%8ENetty%E7%9A%84RPC%E6%A1%86%E6%9E%B6-10.png)

## BUG

### 反序列化出现错误， 无法返回Resonse.fail()

错误代码

```java
    public Object deserialize(byte[] bytes, int messageType) {
        Object obj = null;
        // 传输的消息分为request与response
        switch (messageType){
            case 0:
                RpcRequest request = JSON.parseObject(bytes, RpcRequest.class);
                Object[] objects = new Object[request.getParams().length];
                // 把json字串转化成对应的对象， fastjson可以读出基本数据类型，不用转化
                // 对转换后的request中的params属性逐个进行类型判断
                for(int i = 0; i < objects.length; i++){
                    Class<?> paramsType = request.getParamType()[i];
                    //判断每个对象类型是否和paramsTypes中的一致
                    if (!paramsType.isAssignableFrom(request.getParams()[i].getClass())){
                        //如果不一致，就行进行类型转换
                        objects[i] = JSONObject.toJavaObject((JSONObject) request.getParams()[i], request.getParamType()[i]);
                    }else{
                        //如果一致就直接赋给objects[i]
                        objects[i] = request.getParams()[i];
                    }
                }
                request.setParams(objects);
                obj = request;
                break;
            case 1:
                RpcResponse response = JSON.parseObject(bytes, RpcResponse.class);
                Class<?> dataType = response.getDataType();
                //判断转化后的response对象中的data的类型是否正确
                if(! dataType.isAssignableFrom(response.getData().getClass())){
                    response.setData(JSONObject.toJavaObject((JSONObject) response.getData(),dataType));
                }
                obj = response;
                break;
            default:
                System.out.println("暂时不支持此种消息");
                throw new RuntimeException();
        }
        return obj;
    }
```

正确代码

```java
    public Object deserialize(byte[] bytes, int messageType) {
        Object obj = null;
        // 传输的消息分为request与response
        switch (messageType){
            case 0:
                RpcRequest request = JSON.parseObject(bytes, RpcRequest.class);
                Object[] objects = new Object[request.getParams().length];
                // 把json字串转化成对应的对象， fastjson可以读出基本数据类型，不用转化
                // 对转换后的request中的params属性逐个进行类型判断
                for(int i = 0; i < objects.length; i++){
                    Class<?> paramsType = request.getParamType()[i];
                    //判断每个对象类型是否和paramsTypes中的一致
                    if (!paramsType.isAssignableFrom(request.getParams()[i].getClass())){
                        //如果不一致，就行进行类型转换
                        objects[i] = JSONObject.toJavaObject((JSONObject) request.getParams()[i],request.getParamType()[i]);
                    }else{
                        //如果一致就直接赋给objects[i]
                        objects[i] = request.getParams()[i];
                    }
                }
                request.setParams(objects);
                obj = request;
                break;
            case 1:
                RpcResponse response = JSON.parseObject(bytes, RpcResponse.class);
                // 如果类型为空，说明返回错误
                if(response.getDataType()==null){
                    obj = RpcResponse.fail();
                    break;
                }
                Class<?> dataType = response.getDataType();
                //判断转化后的response对象中的data的类型是否正确
                if(!dataType.isAssignableFrom(response.getData().getClass())){
                    response.setData(JSONObject.toJavaObject((JSONObject) response.getData(),dataType));
                }
                obj = response;
                break;
            default:
                System.out.println("暂时不支持此种消息");
                throw new RuntimeException();
        }
        return obj;
    }

);
                }
                obj = response;
                break;
            default:
                System.out.println("暂时不支持此种消息");
                throw new RuntimeException();
        }
        return obj;
    }
````


