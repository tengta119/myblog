---
title: Java并发编程基础篇
categories: [后端开发, Java并发]
tags: [Java, 多线程]
date: 2024-12-09 19:28:39
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost01-01.png
---
# 并发编程线程基础

## 进程与线程
**进程**是系统分配资源的基本单位，**线程**是进程的一个执行路径，一个进程可以有多个线程，线程之间共享进程的资源
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost01-01.png#pic_center)
在Java中，启动main函数时，其实启动的是一个JVM的进程，尔main函数所在的线程是主线程

## 线程的创建与运行

### 继承Thread
```java
public class ThreadTest {

    public static class MyThread extends Thread {

        private final String message;

        public MyThread(String message) {
            super();
            this.message = message;
        }

        @Override
        public void run() {
            System.out.println( message + "MyThread.run()");
        }
    }

    public static void main(String[] args) {
        MyThread myThread = new MyThread("这是参数");
        myThread.start(); //
    }
}
```
### 实现Runnable接口的run方法
```java
public class RunableTask implements Runnable{
    @Override
    public void run() {
        System.out.println("RunableTask.run()");
    }

    public static void main(String[] args) {
        RunableTask runableTask = new RunableTask();
        new Thread(runableTask).start();
        new Thread(runableTask).start();
    }
}
```
### FutureTask
```java
public class CallerTask implements Callable<String> {

    private final String message;

    public CallerTask(String message) {

        this.message = message;
    }

    @Override
    public String call() throws Exception {
        return message +  "hello";
    }

    public static void main(String[] args) throws ExecutionException, InterruptedException {
        FutureTask<String> futureTask = new FutureTask<>(new CallerTask("这是参数"));
        new Thread(futureTask).start();
        String result = futureTask.get();
        System.out.printf(result);
    }
}
```

## wait，synchronized，notify，volatile
* synchronized：当多个线程需要对共享变量进行操作时，为避免同时对变量进行操作所引起的错误，需要使用synchronized()拿到**共享变量的监视器锁**
* synchronized内存语意：进入到**synchronized**块后，使用到该变量时直接从主内存中获取，而不是线程的工作内存，退出**synchronized**指的是对共享变量的改变刷新到主内存中
* wait：线程在拿到**共享变量的监视器锁**后调用wait()函数，使自己挂起停止运行，并释放共享变量的监视器锁
* notify： 线程在拿到**共享变量的监视器锁**后调用notify()函数，通知一个线程进入等待状态（由JVM决定）尝试获取共享变量的监视器锁，但此线程还会进行运行，直到线程结束
* volatile：当一个变量被声明为volatile后，线程会把值刷新到主内存中，当其他线程读取该变量中，会从主内存直接获取

## ThreadLocal
在线程中对ThreadLocal赋值时，实际上是**调用该线程**的线程的ThreadLocalMap中以该线程为key，赋的值的为值来创建当前线程的对应的HashMap,
<font color="red">注意<font>：使用完这些变量后要及时删除，否则可能会造成内存溢出
```java
public class ThreadLocalTest {

    static void print(String str) {
        System.out.println(str + ":" + localVariable.get());
        localVariable.remove();
    }

    static ThreadLocal<String> localVariable = new ThreadLocal<String>();

    public static void main(String[] args) {
        Thread threadOne = new Thread(new Runnable() {
            @Override
            public void run() {
                localVariable.set("threadOne local variable");
                print("threadOne");
                System.out.println("threadOne remove after" + ":" + localVariable.get());
            }
        });

        Thread threadTwo = new Thread(new Runnable() {
            @Override
            public void run() {
                localVariable.set("threadTwo local variable");
                print("threadTwo");
                System.out.println("threadTwo remove after" + ":" + localVariable.get());
            }
        });

        threadOne.start();
        threadTwo.start();
    }


}
```

