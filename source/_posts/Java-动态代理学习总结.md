---
title: Java-动态代理学习总结
categories:
  - 编程语言
  - Java
tags:
  - Java
  - 动态代理
date: 2025-02-17 19:57:30
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJava-%E5%8A%A8%E6%80%81%E4%BB%A3%E7%90%86%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-01.png
---
>https://www.bilibili.com/video/BV1ue411N7GX
# 什么是代理
* **自己的理解：** 
类似与Spring中的AOP，是对原有代码的增强，也是对原有代码的封装
* **官话：**
在Java中，代理（Proxy）是一种设计模式，用于控制对某个对象的访问。代理模式通过创建一个代理对象，来替代原始对象，以实现对原始对象的访问控制。代理对象和原始对象实现相同的接口，客户端对象可以透明地使用代理对象。

# 例子
实体类
```java
public class BigStar implements Star {

    private String name;

    public BigStar(String name) {
        this.name = name;
    }

    public String sing(String song) {
        System.out.println(this.name + " 正在唱:" + song);
        return "谢谢";
    }

    public String dance(String dance) {
        System.out.println(this.name + "正在跳:" + dance);
        return "谢谢";
    }
    
}
```
接口
```java
public interface Star {

    public String sing(String name);

    public String dance(String name);
}
```
动态代理类
```java
public class ProxyUtil {

//    newProxyInstance(ClassLoader loader, 类加载器
//                     Class<?>[] interfaces, 指定生成的代理长什么样，也就是那些方法
//                     InvocationHandler h) 指定生成的代理对象要干什么事情
    //使用方法
    //Star star =  ProxyUtil.createProxy(s);
    //star.sing(); -> 调用invoke方法
    public static Star createProxy(BigStar bigStar) {
        Star starProxy = (Star) Proxy.newProxyInstance(ProxyUtil.class.getClassLoader(),
                new Class[]{Star.class}, new InvocationHandler() {

                    @Override
                    //回调方法               调用该方法的对象，调用的方法，      对象
                    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
                        // 代理对象要做的事，代码实习
                        if (method.getName().equals("sing")) {
                            System.out.println("唱歌，花费10万");
                        } else if (method.getName().equals("dance")) {
                            System.out.println("跳舞，花费20万");
                        }
                        return method.invoke(bigStar, args);
                    }
                });
        return starProxy;
    };
}
```
运行代码
```java
        BigStar bigStar = new BigStar("nick");
        Star star = ProxyUtil.createProxy(bigStar);
        System.out.println(star);
        System.out.println(star.sing("mick"));
        System.out.println(star.dance("sas"));
```
运行结果
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJava-%E5%8A%A8%E6%80%81%E4%BB%A3%E7%90%86%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-01.png)
打印出star，发现还是实体类，证实了动态代理是对原有代码的封装与加强

# 运行流程
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJava-%E5%8A%A8%E6%80%81%E4%BB%A3%E7%90%86%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-02.png)


