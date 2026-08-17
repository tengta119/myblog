---
title: ThreadPoolExecutor源码阅读以及手写简单线程池 —— JDK17
categories: [后端开发, Java源码]
tags: [Java, 线程池, JDK17]
date: 2025-05-10 18:00:46
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgThreadPoolExecutor%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%E4%BB%A5%E5%8F%8A%E6%89%8B%E5%86%99%E7%AE%80%E5%8D%95%E7%BA%BF%E7%A8%8B%E6%B1%A0%20%E2%80%94%E2%80%94%20JDK17-01.png
---
# ThreadPoolExecutor
* 固定大小的线程池 Executors.newFixedThreadPool(int nThreads);，适合用于任务数量确定，且对线程数有明确要求的场景。例如，IO 密集型任务、数据库连接池等。

* 缓存线程池 Executors.newCachedThreadPool();，适用于短时间内任务量波动较大的场景。例如，短时间内有大量的文件处理任务或网络请求。

* 定时任务线程池 Executors.newScheduledThreadPool(int corePoolSize);，适用于需要定时执行任务的场景。例如，定时发送邮件、定时备份数据等。

* 单线程线程池 Executors.newSingleThreadExecutor();，适用于需要按顺序执行任务的场景。例如，日志记录、文件处理等

## 线程池的状态
有 5 种状态，它们的转换遵循严格的状态流转规则，不同状态控制着线程池的任务调度和关闭行为。
状态由 RUNNING → SHUTDOWN → STOP → TIDYING → TERMINATED 依次流转。
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgThreadPoolExecutor%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%E4%BB%A5%E5%8F%8A%E6%89%8B%E5%86%99%E7%AE%80%E5%8D%95%E7%BA%BF%E7%A8%8B%E6%B1%A0%20%E2%80%94%E2%80%94%20JDK17-01.png)
RUNNING 状态的线程池可以接收新任务，并处理阻塞队列中的任务；SHUTDOWN 状态的线程池不会接收新任务，但会处理阻塞队列中的任务；STOP 状态的线程池不会接收新任务，也不会处理阻塞队列中的任务，并且会尝试中断正在执行的任务；TIDYING 状态表示所有任务已经终止；TERMINATED 状态表示线程池完全关闭，所有线程销毁

## 重要参数

①、corePoolSize：核心线程数，长期存活，执行任务的主力。

②、maximumPoolSize：线程池允许的最大线程数。

③、workQueue：任务队列，存储等待执行的任务。

④、handler：拒绝策略，任务超载时的处理方式。也就是线程数达到 maximumPoolSiz，任务队列也满了的时候，就会触发拒绝策略。

⑤、threadFactory：线程工厂，用于创建线程，可自定义线程名。

⑥、keepAliveTime：非核心线程的存活时间，空闲时间超过该值就销毁。

⑦、unit：keepAliveTime 参数的时间单位：

### handler -  拒绝策略
* AbortPolicy：默认的拒绝策略，会抛 RejectedExecutionException 异常。

* CallerRunsPolicy：让提交任务的线程自己来执行这个任务，也就是调用 execute 方法的线程。

* DiscardOldestPolicy：等待队列会丢弃队列中最老的一个任务，也就是队列中等待最久的任务，然后尝试重新提交被拒绝的任务。

* DiscardPolicy：丢弃被拒绝的任务，不做任何处理也不抛出异常。
* 也可以自己实现 RejectedExecutionHandler 接口来定义自己的淘汰策略

### workQueue - 阻塞队列
* ArrayBlockingQueue：一个有界的先进先出的阻塞队列，底层是一个数组，适合固定大小的线程池。
* LinkedBlockingQueue：底层是链表，如果不指定大小，默认大小是 Integer.MAX_VALUE，几乎相当于一个无界队列
* PriorityBlockingQueue：一个支持优先级排序的无界阻塞队列。任务按照其自然顺序或 Comparator 来排序
* DelayQueue：类似于 PriorityBlockingQueue，由二叉堆实现的无界优先级阻塞队列
* SynchronousQueue：每个插入操作必须等待另一个线程的移除操作，同样，任何一个移除操作都必须等待另一个线程的插入操作

## 提交任务
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgThreadPoolExecutor%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%E4%BB%A5%E5%8F%8A%E6%89%8B%E5%86%99%E7%AE%80%E5%8D%95%E7%BA%BF%E7%A8%8B%E6%B1%A0%20%E2%80%94%E2%80%94%20JDK17-02.png)

### execute - 提交任务
```java
/**
 * 在将来的某个时间执行给定的任务。
 * 该任务可能在新线程中执行，也可能在现有的工作线程中执行。
 * 如果由于此执行器已关闭或已达到其容量而无法提交任务，
 * 则该任务将由当前的RejectedExecutionHandler处理。
 *
 * @param command 要执行的任务
 * @throws NullPointerException 如果命令为空
 */
public void execute(Runnable command) {
    // 检查任务是否为空，为空则抛出空指针异常
    if (command == null)
        throw new NullPointerException();
    
    // 获取ctl变量的值，ctl包含了线程池的运行状态和工作线程数量
    int c = ctl.get();
    
    // 步骤1：如果当前工作线程数量少于核心线程数
    if (workerCountOf(c) < corePoolSize) {
        // 尝试创建新线程执行任务（core参数为true表示使用核心线程数限制）
        if (addWorker(command, true))
            return;
        // 如果添加失败，重新获取ctl值，因为可能状态已变化
        c = ctl.get();
    }
    
    // 步骤2：如果线程池正在运行且任务可以成功加入工作队列
    if (isRunning(c) && workQueue.offer(command)) {
        // 入队后再次检查状态
        int recheck = ctl.get();
        // 如果线程池不再运行且成功从队列中移除任务
        if (! isRunning(recheck) && remove(command))
            // 拒绝该任务（使用拒绝策略处理）
            reject(command);
        // 如果线程池仍在运行但没有工作线程
        else if (workerCountOf(recheck) == 0)
            // 创建一个新的工作线程（null表示不指定初始任务，false表示使用最大线程数限制）
            addWorker(null, false);
    }
    // 步骤3：如果任务无法入队（队列已满），尝试创建新线程（使用最大线程数限制）
    else if (!addWorker(command, false))
        // 如果创建失败（可能线程数已达到maximumPoolSize或线程池已关闭），拒绝任务
        reject(command);
}
```

1. 如果运行的线程少于corePoolSize，则尝试启动一个新线程并将给定的命令作为其第一个任务。对addWorker的调用会原子性地检查运行状态和工作线程数量，通过返回false来防止在不应该添加线程时添加线程的误判情况。

 2. 如果任务可以成功加入队列，那么我们仍然需要双重检查是否应该添加一个线程（因为自上次检查后现有线程可能已死亡）或者自进入此方法后线程池已关闭。因此我们重新检查状态，如果线程池已停止则必要时回滚入队操作，或者如果没有线程则启动一个新线程。

3. 如果无法将任务入队，则尝试添加一个新线程。如果失败，我们知道线程池已关闭或已饱和，因此拒绝该任务。

### addWorker - 添加线程
```java
        for (int c = ctl.get();;) {
            // Check if queue empty only if necessary.
            if (runStateAtLeast(c, SHUTDOWN)
                && (runStateAtLeast(c, STOP)
                    || firstTask != null
                    || workQueue.isEmpty()))
                return false;

            for (;;) {
            	// 线程数量大于 corePoolSize 或者 maximumPoolSize，添加线程失败
                if (workerCountOf(c)
                    >= ((core ? corePoolSize : maximumPoolSize) & COUNT_MASK))
                    return false;
                // 尝试通过 CAS 使得 c 自增
                if (compareAndIncrementWorkerCount(c))
                    break retry;
                c = ctl.get();  // Re-read ctl
                if (runStateAtLeast(c, SHUTDOWN))
                    continue retry;
                // else CAS failed due to workerCount change; retry inner loop
            }
        }
```
这段代码主要为了并发情况下，线程数量的问题，其内部的循环尝试通过 CAS 增加线程的数量 c，如果成功则通过 retry 退出外部循环继续向下执行，如果失败，则继续尝试，直到成功或者条件不符。

```java
       boolean workerStarted = false;
        boolean workerAdded = false;
        Worker w = null;
        try {
        	// 其内部线程工厂创建线程，并包装成 Worker 类
            w = new Worker(firstTask);
            final Thread t = w.thread;
            if (t != null) {
                final ReentrantLock mainLock = this.mainLock;
                mainLock.lock();
                try {
                    // Recheck while holding lock.
                    // Back out on ThreadFactory failure or if
                    // shut down before lock acquired.
                    int c = ctl.get();

                    if (isRunning(c) ||
                        (runStateLessThan(c, STOP) && firstTask == null)) {
                        if (t.getState() != Thread.State.NEW)
                            throw new IllegalThreadStateException();
                        workers.add(w);
                        workerAdded = true;
                        int s = workers.size();
                        if (s > largestPoolSize)
                            largestPoolSize = s;
                    }
                } finally {
                    mainLock.unlock();
                }
                if (workerAdded) {
                    t.start();
                    workerStarted = true;
                }
            }
        } finally {
            if (! workerStarted)
                addWorkerFailed(w);
        }
        return workerStarted;
    }
```
当执行到这段代码时，说明线程已经创建成功，接下来将新创建的 worker 添加到 workers 集合中，如果添加成功，则启动该 woker，开始处理任务

### runWorker - 线程运行
```java
    final void runWorker(Worker w) {
        Thread wt = Thread.currentThread();
        Runnable task = w.firstTask;
        w.firstTask = null;
        w.unlock(); // allow interrupts
        boolean completedAbruptly = true;
        try {
            while (task != null || (task = getTask()) != null) {
                w.lock();
                // 如果线程池正在停止，并确保线程已经中断
           		// 如果线程没有中断并且线程池已经达到停止状态，中断线程
                if ((runStateAtLeast(ctl.get(), STOP) ||
                     (Thread.interrupted() &&
                      runStateAtLeast(ctl.get(), STOP))) &&
                    !wt.isInterrupted())
                    wt.interrupt();
                try {
                	// 任务执行前的自定义操作
                    beforeExecute(wt, task);
                    try {
                    	// 实际执行任务
                        task.run();
                        afterExecute(task, null);
                    } catch (Throwable ex) {
                        afterExecute(task, ex);
                        throw ex;
                    }
                } finally {
                    task = null;
                    w.completedTasks++;
                    w.unlock();
                }
            }
            completedAbruptly = false;
        } finally {
            processWorkerExit(w, completedAbruptly);
        }
    }
```
`while (task != null || (task = getTask()) != null)` ：只要当前任务不为 null 或者从任务队列中能获取到新任务，就继续循环。getTask() 方法用于从任务队列中获取任务

因为 Worker 继承了 AQS，每次在执行任务之前都会调用 Worker 的 lock 方法，执行完任务之后，会调用 unlock 方法，这样做的目的就可以通过 Woker 的加锁状态判断出当前线程是否正在执行任务。

如果想知道线程是否正在执行任务，只需要调用 Woker 的 tryLock 方法，根据是否加锁成功就能判断，加锁成功说明当前线程没有加锁，也就没有执行任务了，在调用 shutdown 方法关闭线程池的时候，就时用这种方式来判断线程有没有在执行任务，如果没有的话，会尝试打断没有执行任务的线程

`completedAbruptly` 表示线程是否正常退，出如果在任务执行过程中出现异常，completedAbruptly 的值将保持为 true。在 finally 块中，无论任务是正常完成还是意外终止，都会执行 processWorkerExit(w, completedAbruptly) 方法。该方法会根据 completedAbruptly  的值来决定如何处理工作线程的退出。如果 completedAbruptly 为 true，可能会采取一些额外的措施来处理意外终止的情况，例如记录错误信息、进行资源清理或尝试重新启动线程等。如果为 false，则表示任务正常完成，可能会进行一些常规的清理操作

### getTask - 获取任务
```java
    private Runnable getTask() {
    // 标志，表示最后一个poll()操作是否超时
    boolean timedOut = false;

    // 无限循环，直到获取到任务或决定工作线程应该退出
    for (;;) {
        int c = ctl.get();
        int rs = runStateOf(c);

        // 如果线程池状态是SHUTDOWN或更高（如STOP）并且任务队列为空，那么工作线程应该减少并退出
        if (rs >= SHUTDOWN && (rs >= STOP || workQueue.isEmpty())) {
            decrementWorkerCount();
            return null;
        }

        int wc = workerCountOf(c);

        // 检查工作线程是否应当在没有任务执行时，经过keepAliveTime之后被终止
        boolean timed = allowCoreThreadTimeOut || wc > corePoolSize;

        // 如果工作线程数超出最大线程数或者超出核心线程数且上一次poll()超时，并且队列为空或工作线程数大于1，
        // 则尝试减少工作线程数
        if ((wc > maximumPoolSize || (timed && timedOut))
            && (wc > 1 || workQueue.isEmpty())) {
            if (compareAndDecrementWorkerCount(c))
                return null;
            continue;
        }

        try {
            // 根据timed标志，决定是无限期等待任务，还是等待keepAliveTime时间
            Runnable r = timed ?
                workQueue.poll(keepAliveTime, TimeUnit.NANOSECONDS) :  // 指定时间内等待
                workQueue.take();  // 无限期等待
            if (r != null)  // 成功获取到任务
                return r;
            // 如果poll()超时，则设置timedOut标志
            timedOut = true;
        } catch (InterruptedException retry) {
            // 如果在等待任务时线程被中断，重置timedOut标志并重新尝试获取任务
            timedOut = false;
        }
    }
}
```
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgThreadPoolExecutor%E6%BA%90%E7%A0%81%E9%98%85%E8%AF%BB%E4%BB%A5%E5%8F%8A%E6%89%8B%E5%86%99%E7%AE%80%E5%8D%95%E7%BA%BF%E7%A8%8B%E6%B1%A0%20%E2%80%94%E2%80%94%20JDK17-03.png)

# MyThreadPool - 手写简单线程池
MyThreadPool 有两个内部类，一个是 CoreThread，另一个是 SupportThread，

## CoreThread - 核心线程
```java
    class CoreThread extends Thread {
        @Override
        public void run() {
            while (true) {
                try {
                    Runnable command = blockingQueue.take();
                    command.run();
                } catch (InterruptedException e) {
                    throw new RuntimeException(e);
                }
            }
        }
    }
```
CoreThread 会一直尝试从阻塞队列中获取任务，如果获取不到，则会阻塞

## SupportThread - 非核心线程
```java
    class SupportThread extends Thread {
        @Override
        public void run() {
            while (true) {
                try {
                    Runnable command = blockingQueue.poll(timeout, timeUnit);
                    if (command != null) {
                        command.run();
                    }
                    break;
                } catch (InterruptedException e) {
                    throw new RuntimeException(e);
                }
            }
            System.out.println(Thread.currentThread().getName() + "线程结束了");
        }
    }
```
SupportThread 相比 CoreThread 只会阻塞一段时间，如果在规定的时间内没有获取任务，则该 SupportThread 会退出

## execute - 提交任务
```java
    void execute(Runnable command) {
        if (coreList.size() <= corePoolSize) {
            CoreThread thread = new CoreThread();
            coreList.add(thread);
            thread.start();
        }
        if (blockingQueue.offer(command)) {
            return;
        }
        if (coreList.size() + supportList.size() <= corePoolSize) {
            SupportThread thread = new SupportThread();
            supportList.add(thread);
            thread.start();
        }
        if (!blockingQueue.offer(command)) {
            rejectHandle.reject(command, this);
        }
    }
```
仿照 ThreadPoolExecutor 的 execute，先尝试是否可以增加核心线程，如果失败则尝试是否可以添加到阻塞队列，如果失败，尝试增加非核心队列，如果失败则执行拒绝策略

