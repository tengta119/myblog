---
title: JUC学习总结
categories: [后端开发, Java并发]
tags: [Java, JUC]
date: 2024-12-27 17:11:17
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost02-01.png
---
# 锁
## 锁机制原理
`synchronized`使用的锁就是存储在Java对象头中的，在Java中，对象存储在内存中，而每个对象内部，都有一部分空间用于存储对象头信息，其中就包含锁的信息
* monitorenter：每个对象都有一个`monitor`监视器与之对应，而monitorenter就是获取**监视器**的所有权，一但获取，其他线程就无法再回去
* monitorenter：释放锁
```java
public class Main {

    public static void main(String[] args) {
        synchronized (Main.class) {
            System.out.println("Hello, World!");
        }
    }
}
```
```txt
    Code:
      stack=2, locals=3, args_size=1
         0: ldc           #7                  // class com/example/Main
         2: dup
         3: astore_1
         4: monitorenter
         5: getstatic     #9                  // Field java/lang/System.out:Ljava/io/PrintStream;
         8: ldc           #15                 // String Hello, World!
        10: invokevirtual #17                 // Method java/io/PrintStream.println:(Ljava/lang/String;)V
        13: aload_1
        14: monitorexit
        15: goto          23
        18: astore_2
        19: aload_1
        20: monitorexit
        21: aload_2
        22: athrow
        23: return

```
在第四行代码monitorenter成功获取Main对象后，执行代码，如果程序没有报错，则释放锁然后跳转到23行执行return语句，如果程序出错，则执行第20行代码，也释放锁，然后抛出异常，这样保证异常处理部分确保在异常发生时，仍然会释放锁

在 Java 中，对象头是对象在内存中存储的一部分，包含了 JVM 用于管理对象的信息。对象头通常由以下几个部分组成：

## Mark Word
- **存储信息**：Mark Word 是对象头中最重要的部分，存储了对象的运行时数据，包括哈希码（HashCode）、GC 分代年龄、锁状态标志等。
- **锁状态**：根据对象的锁状态，Mark Word 的内容会有所不同。它可以表示偏向锁、轻量级锁、重量级锁的状态。

## CAS
CAS 操作涉及三个操作数：
- **内存位置（V）**：需要更新的变量。
- **预期值（A）**：期望当前变量的值。
- **新值（B）**：需要更新的新值。

 操作步骤：
1. **比较**：检查内存位置的当前值是否等于预期值。
2. **交换**：如果相等，将内存位置的值更新为新值。
3. **返回结果**：如果不相等，不做任何操作，并返回当前值。
## 重量级锁
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost02-01.png)
每个等待锁的线程都会被封装成ObjectWaiter对象，ObjectWaiter首先会进入 Entry Set等着，当线程获取到对象的`monitor`后进入 The Owner 区域并把`monitor`中的`owner`变量设置为当前线程，同时`monitor`中的计数器`count`加1，若线程调用`wait()`方法，将释放当前持有的`monitor`，`owner`变量恢复为`null`，`count`自减1，同时该线程进入 WaitSet集合中等待被唤醒。若当前线程执行完毕也将释放`monitor`并复位变量的值，以便其他线程进入获取对象的`monitor`
## 轻量级锁
虽然重量级锁设计的什么合理，但是线程阻塞和唤醒需要操作系统的参与，会导致线程进入内核态，开销较大，这是引入**轻量级锁**。
**工作机制**：
当线程尝试获取锁时，会在当前线程的栈帧中创建一个锁记录，其中保存对象头的 Mark Word 的拷贝。接下来使用CAS操作将对象的Mark Word更新为轻量级锁状态，如果CAS操作失败了的话，那么说明可能这时有线程已经进入这个同步代码块了，这时虚拟机会再次检查对象的Mark Word，是否指向当前线程的栈帧，如果是，说明不是其他线程，而是当前线程已经有了这个对象的锁，直接放心大胆进同步代码块即可。如果不是，那确实是被其他线程占用了。
## 偏向锁

当一个线程第一次获取锁时，JVM 会在对象头中记录该线程的 ID，并将锁标记为“偏向锁”状态，如果该线程再次尝试获取锁，不需要进行任何同步操作或 CAS（Compare-And-Swap）操作，直接进入临界区，如果另一个线程尝试获取这个锁，则偏向锁会被撤销，升级为轻量级锁或重量级锁。

## volatile关键字
* 原子性：其实之前讲过很多次了，就是要做什么事情要么做完，要么就不做，不存在做一半的情况。
* 可见性：指当多个线程访问同一个变量时，一个线程修改了这个变量的值，其他线程能够立即看得到修改的值。
* 有序性：即程序执行的顺序按照代码的先后顺序执行。

而**volatile**就是保证可见性，当写一个`volatile`变量时，JMM会把该线程本地内存中的变量强制刷新到主内存中去，并且这个写会操作会导致其他线程中的`volatile`变量缓存无效，这样，另一个线程修改了这个变时，当前线程会立即得知，并将工作内存中的变量更新为最新的版本。


## Lock和Condition接口
在 Java 并发编程中，`Lock` 和 `Condition` 是 `java.util.concurrent.locks` 包中提供的两个核心接口，用于替代传统的 `synchronized` 和 `Object` 的 `wait/notify` 方法，提供更灵活和可控的线程同步机制。
### Lock

**Lock 接口：**

`Lock` 是一个比 `synchronized` 关键字更灵活的锁机制接口，允许显式地获取和释放锁。
**常有方法：**

1. **`void lock()`**  
   - 获取锁。如果锁已经被其他线程持有，则当前线程会进入阻塞状态，直到获取到锁。

2. **`void lockInterruptibly()`**  
   - 获取锁，但可以响应中断。如果线程在等待锁的过程中被中断，会抛出 `InterruptedException`。

3. **`boolean tryLock()`**  
   - 尝试获取锁。如果锁可用，则立即返回 `true`；如果锁不可用，则立即返回 `false`，不会阻塞线程。

4. **`boolean tryLock(long time, TimeUnit unit)`**  
   - 在指定的时间内尝试获取锁。如果在超时时间内获取到锁，返回 `true`；否则返回 `false`。

5. **`void unlock()`**  
   - 释放锁。必须在成功获取锁后调用，否则可能会导致异常。

6. **`Condition newCondition()`**  
   - 返回一个与当前锁绑定的 `Condition` 实例，用于实现线程间的等待和通知机制。

---

```java
    static int i = 0;
    public static void main(String[] args) throws InterruptedException {
        Lock lock = new ReentrantLock();
        Runnable action = () -> {
            for (int j = 0; j < 100; j++) {
                lock.lock();
                i++;
                lock.unlock();
            }
        };
        new Thread(action).start();
        new Thread(action).start();
        Thread.sleep(1000);
        System.out.println(i);
    }
```
输出为200

### Condition
`Condition` 是一个线程协作工具，用于替代传统的 `Object.wait()` 和 `Object.notify()` 方法。它与 `Lock` 配合使用，允许线程在某些条件下等待或被唤醒。

每个 `Lock` 可以通过 `newCondition()` 方法创建一个或多个 `Condition` 实例。`Condition` 提供了更细粒度的线程等待和通知机制。

**常用方法：**

1. **`void await()`**  
   - 当前线程进入等待状态，直到被其他线程唤醒或中断。
   - 等价于 `Object.wait()`。

2. **`void awaitUninterruptibly()`**  
   - 当前线程进入等待状态，但不会响应中断。

3. **`boolean await(long time, TimeUnit unit)`**  
   - 当前线程进入等待状态，直到被唤醒、中断，或超时时间到。

4. **`void signal()`**  
   - 唤醒一个等待线程。等价于 `Object.notify()`。

5. **`void signalAll()`**  
   - 唤醒所有等待线程。等价于 `Object.notifyAll()`。

```java
public static void main(String[] args) throws InterruptedException {
    Lock testLock = new ReentrantLock();
    Condition condition = testLock.newCondition();
    new Thread(() -> {
        testLock.lock();   //和synchronized一样，必须持有锁的情况下才能使用await
        System.out.println("线程1进入等待状态！");
        try {
            condition.await();   //进入等待状态
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        System.out.println("线程1等待结束！");
        testLock.unlock();
    }).start();
    Thread.sleep(100); //防止线程2先跑
    new Thread(() -> {
        testLock.lock();
        System.out.println("线程2开始唤醒其他等待线程");
        condition.signal();   //唤醒线程1，但是此时线程1还必须要拿到锁才能继续运行
        System.out.println("线程2结束");
        testLock.unlock();   //这里释放锁之后，线程1就可以拿到锁继续运行了
    }).start();
}
```

## 可重入锁
简单来说就是可以对一个线程进行反复加锁
```java
    public static void main(String[] args) throws InterruptedException {
        Lock lock = new ReentrantLock();
        lock.lock();
        lock.lock();
        new Thread(() -> {
            System.out.println("线程尝试获取锁");
            lock.lock();
            System.out.println("线程获取锁成功");
        }).start();
        lock.unlock();
        System.out.println("主线程释放锁");
        lock.unlock();
        System.out.println("主线程释放锁");
    }
```
## 公平锁和非公平锁
* 公平锁：多个线程按照申请锁的顺序去获得锁，线程会直接进入队列去排队，永远都是队列的第一位才能得到锁。
* 非公平锁：多个线程去获取锁的时候，会直接去尝试获取，获取不到，再去进入等待队列，如果能获取到，就直接获取到锁。

## 读写锁
它是针对读写场景出现的，上文的可重入锁，是一种排他锁，当一个线程获得锁后，另一个线程必须等待其释放，而读写锁允许在同一时间内多个线程获得同一样的锁

* 读锁：在没有任何线程占用写锁的情况下，同一时间可以有多个线程加读锁。
* 写锁：在没有任何线程占用读锁的情况下，同一时间只能有一个线程加写锁。

```java
    public static void main(String[] args) throws InterruptedException {
        ReentrantReadWriteLock lock = new ReentrantReadWriteLock();
        lock.writeLock().lock();
        lock.writeLock().lock();
        new Thread(() -> {
            lock.writeLock().lock();
            System.out.println("获得写锁");
            lock.writeLock().unlock();
        }).start();

        lock.writeLock().unlock();
        System.out.println("释放写锁");
        lock.writeLock().unlock();
        System.out.println("释放写锁");
    }
```
### 锁降级和锁升级
锁降级指的是写锁降级为读锁。当一个线程持有写锁的情况下，虽然其他线程不能加读锁，但是线程自己是可以加读锁的：

```java
public static void main(String[] args) throws InterruptedException {
    ReentrantReadWriteLock lock = new ReentrantReadWriteLock();
    lock.writeLock().lock();
    lock.readLock().lock();
    System.out.println("成功加读锁！");
}
```

那么，如果我们在同时加了写锁和读锁的情况下，释放写锁，是否其他的线程就可以一起加读锁了呢？

```java
public static void main(String[] args) throws InterruptedException {
    ReentrantReadWriteLock lock = new ReentrantReadWriteLock();
    lock.writeLock().lock();
    lock.readLock().lock();
    new Thread(() -> {
        System.out.println("开始加读锁！");
        lock.readLock().lock();
        System.out.println("读锁添加成功！");
    }).start();
    TimeUnit.SECONDS.sleep(1);
    lock.writeLock().unlock();    //如果释放写锁，会怎么样？
}
```

可以看到，一旦写锁被释放，那么主线程就只剩下读锁了，因为读锁可以被多个线程共享，所以这时第二个线程也添加了读锁。而这种操作，就被称之为"锁降级"（注意不是先释放写锁再加读锁，而是持有写锁的情况下申请读锁再释放写锁）


# 原子类
 **常用 Atomic 类的使用示例：**

**（1）AtomicInteger**

`AtomicInteger` 是最常用的原子类之一，用于对 `int` 类型的变量进行原子操作。
```java
public class AtomicInteger extends Number implements java.io.Serializable {
	...
    private volatile int value;
    ...
```
查看其源代码，发现value设置了volatile保证了可见性
```java
    public final int getAndAddInt(Object o, long offset, int delta) {
        int v;
        do {
            v = getIntVolatile(o, offset);
        } while (!weakCompareAndSetInt(o, offset, v, v + delta));
        return v;
    }
```
`getIntVolatile(o, offset)`不断获取当前值，然后调用`weakCompareAndSetInt(o, offset, v, v + delta)`进行CAS操作，如果成功则说明自增成功，如果失败则说明其他线程改变了当前的值，进行下一次循环，实现了原子操作
**示例代码**：
```java
public class AtomicIntegerExample {
    public static void main(String[] args) {
        AtomicInteger atomicInteger = new AtomicInteger(0);

        // 原子性加 1
        System.out.println("Increment: " + atomicInteger.incrementAndGet()); // 输出 1

        // 原子性减 1
        System.out.println("Decrement: " + atomicInteger.decrementAndGet()); // 输出 0

        // 获取当前值并设置新值
        System.out.println("Get and Set: " + atomicInteger.getAndSet(5)); // 输出 0（旧值）
        System.out.println("Current Value: " + atomicInteger.get()); // 输出 5

        // CAS 操作：如果当前值为 5，则更新为 10
        boolean updated = atomicInteger.compareAndSet(5, 10);
        System.out.println("Compare and Set: " + updated); // 输出 true
        System.out.println("Updated Value: " + atomicInteger.get()); // 输出 10
    }
}
```

---

**（2）AtomicReference**

`AtomicReference` 用于对引用类型的变量进行原子操作。

**示例代码**：
```java
public class AtomicReferenceExample {
    public static void main(String[] args) {
        AtomicReference<String> atomicReference = new AtomicReference<>("Initial");

        // 获取当前值
        System.out.println("Current Value: " + atomicReference.get()); // 输出 "Initial"

        // 使用 CAS 更新值
        boolean updated = atomicReference.compareAndSet("Initial", "Updated");
        System.out.println("Compare and Set: " + updated); // 输出 true
        System.out.println("Updated Value: " + atomicReference.get()); // 输出 "Updated"
    }
}
```



**AtomicStampedReference**

`AtomicStampedReference` 用于解决 **ABA 问题**，通过引入版本号（时间戳）来判断值是否被修改过。

**示例代码**：
```java
public class AtomicStampedReferenceExample {
    public static void main(String[] args) {
        AtomicStampedReference<String> stampedReference = new AtomicStampedReference<>("Initial", 1);

        int[] stampHolder = new int[1];
        String currentValue = stampedReference.get(stampHolder);
        int currentStamp = stampHolder[0];

        // 打印当前值和版本号
        System.out.println("Current Value: " + currentValue); // 输出 "Initial"
        System.out.println("Current Stamp: " + currentStamp); // 输出 1

        // CAS 操作（更新值和版本号）
        boolean updated = stampedReference.compareAndSet("Initial", "Updated", currentStamp, currentStamp + 1);
        System.out.println("Compare and Set: " + updated); // 输出 true
        System.out.println("Updated Value: " + stampedReference.getReference()); // 输出 "Updated"
        System.out.println("Updated Stamp: " + stampedReference.getStamp()); // 输出 2
    }
}
```

---

**LongAdder**
![csdnJUC](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost02-02.png)
`LongAdder`会将对value值的CAS操作分散为对数组`cells`中多个元素的CAS操作（内部维护一个Cell[] as数组，每个Cell里面有一个初始值为0的long型变量，在高并发时会进行分散CAS，就是不同的线程可以对数组中不同的元素进行CAS自增，这样就避免了所有线程都对同一个值进行CAS），只需要最后再将结果加起来即可。


**示例代码**：
```java
public class LongAdderExample {
    public static void main(String[] args) {
        LongAdder longAdder = new LongAdder();

        // 累加操作
        longAdder.add(10);
        longAdder.increment(); // 增加 1
        longAdder.increment(); // 增加 1

        // 获取当前值
        System.out.println("Current Value: " + longAdder.sum()); // 输出 12
    }
}
```

# 并发容器
## CopyOnWriteArrayList
```java
        CopyOnWriteArrayList<String> list = new CopyOnWriteArrayList<>();
        list.add("test");
```
```java
    public boolean add(E e) {
        synchronized (lock) {
            Object[] es = getArray();
            int len = es.length;
            es = Arrays.copyOf(es, len + 1);
            es[len] = e;
            setArray(es);
            return true;
        }
    }
```
查看其**add**源代码，发现使用内部对象**lock**作为锁，确保在多线程环境下只有一个线程可以执行此代码块

## ConcurrentHashMap
```java
        ConcurrentHashMap<Integer, Integer> map = new ConcurrentHashMap<>();
        map.put(1, 1);
```
```java
final V putVal(K key, V value, boolean onlyIfAbsent) {
    if (key == null || value == null) throw new NullPointerException(); // 1. 检查空值
    int hash = spread(key.hashCode()); // 2. 计算哈希值
    int binCount = 0; // 3. 初始化计数器
    for (Node<K,V>[] tab = table;;) { // 4. 自旋开始
        Node<K,V> f; int n, i, fh; K fk; V fv;
        if (tab == null || (n = tab.length) == 0) // 5. 初始化表
            tab = initTable();
        else if ((f = tabAt(tab, i = (n - 1) & hash)) == null) { // 6. 桶为空
            if (casTabAt(tab, i, null, new Node<K,V>(hash, key, value)))
                break; // 7. 使用 CAS 插入新节点
        }
        else if ((fh = f.hash) == MOVED) // 8. 帮助扩容
            tab = helpTransfer(tab, f);
        else if (onlyIfAbsent // 9. 检查是否存在
                 && fh == hash
                 && ((fk = f.key) == key || (fk != null && key.equals(fk)))
                 && (fv = f.val) != null)
            return fv;
        else { // 10. 处理冲突
            V oldVal = null;
            synchronized (f) { // 11. 锁定桶
                if (tabAt(tab, i) == f) {
                    if (fh >= 0) { // 12. 链表处理
                        binCount = 1;
                        for (Node<K,V> e = f;; ++binCount) {
                            K ek;
                            if (e.hash == hash &&
                                ((ek = e.key) == key ||
                                 (ek != null && key.equals(ek)))) {
                                oldVal = e.val;
                                if (!onlyIfAbsent)
                                    e.val = value;
                                break;
                            }
                            Node<K,V> pred = e;
                            if ((e = e.next) == null) {
                                pred.next = new Node<K,V>(hash, key, value);
                                break;
                            }
                        }
                    }
                    else if (f instanceof TreeBin) { // 13. 红黑树处理
                        Node<K,V> p;
                        binCount = 2;
                        if ((p = ((TreeBin<K,V>)f).putTreeVal(hash, key, value)) != null) {
                            oldVal = p.val;
                            if (!onlyIfAbsent)
                                p.val = value;
                        }
                    }
                    else if (f instanceof ReservationNode)
                        throw new IllegalStateException("Recursive update");
                }
            }
            if (binCount != 0) {
                if (binCount >= TREEIFY_THRESHOLD) // 14. 转换为红黑树
                    treeifyBin(tab, i);
                if (oldVal != null)
                    return oldVal;
                break;
            }
        }
    }
    addCount(1L, binCount); // 15. 更新计数并检查扩容
    return null;
}

```
* 在第12中，使用头节点作为锁，确保只用一个线程在执行这段代码。
* `if (tabAt(tab, i) == f)`：在加锁后再次检查当前桶是否仍然是 f，确保在加锁前后桶未被其他线程修改。如果桶已被修改，则不执行后续逻辑。

# 阻塞队列
```java
public interface BlockingQueue<E> extends Queue<E> {
   	boolean add(E e);

    //入队，如果队列已满，返回false否则返回true（非阻塞）
    boolean offer(E e);

    //入队，如果队列已满，阻塞线程直到能入队为止
    void put(E e) throws InterruptedException;

    //入队，如果队列已满，阻塞线程直到能入队或超时、中断为止，入队成功返回true否则false
    boolean offer(E e, long timeout, TimeUnit unit)
        throws InterruptedException;

    //出队，如果队列为空，阻塞线程直到能出队为止
    E take() throws InterruptedException;

    //出队，如果队列为空，阻塞线程直到能出队超时、中断为止，出队成功正常返回，否则返回null
    E poll(long timeout, TimeUnit unit)
        throws InterruptedException;

    //返回此队列理想情况下（在没有内存或资源限制的情况下）可以不阻塞地入队的数量，如果没有限制，则返回 Integer.MAX_VALUE
    int remainingCapacity();

    boolean remove(Object o);

    public boolean contains(Object o);

  	//一次性从BlockingQueue中获取所有可用的数据对象（还可以指定获取数据的个数）
    int drainTo(Collection<? super E> c);

    int drainTo(Collection<? super E> c, int maxElements);
```
* ArrayBlockingQueue：有界带缓冲阻塞队列（就是队列是有容量限制的，装满了肯定是不能再装的，只能阻塞，数组实现）
* SynchronousQueue：无缓冲阻塞队列（相当于没有容量的ArrayBlockingQueue，因此只有阻塞的情况）
* LinkedBlockingQueue：无界带缓冲阻塞队列（没有容量限制，也可以限制容量，也会阻塞，链表实现）
* PriorityBlockingQueue - 是一个支持优先级的阻塞队列，元素的获取顺序按优先级决定。
* DelayQueue - 它能够实现延迟获取元素，同样支持优先级。

# 线程池
## 线程池的使用
```java
    public ThreadPoolExecutor(int corePoolSize,
                              int maximumPoolSize,
                              long keepAliveTime,
                              TimeUnit unit,
                              BlockingQueue<Runnable> workQueue,
                              ThreadFactory threadFactory,
                              RejectedExecutionHandler handler) {
        if (corePoolSize < 0 ||
            maximumPoolSize <= 0 ||
            maximumPoolSize < corePoolSize ||
            keepAliveTime < 0)
            throw new IllegalArgumentException();
        if (workQueue == null || threadFactory == null || handler == null)
            throw new NullPointerException();
        this.corePoolSize = corePoolSize;
        this.maximumPoolSize = maximumPoolSize;
        this.workQueue = workQueue;
        this.keepAliveTime = unit.toNanos(keepAliveTime);
        this.threadFactory = threadFactory;
        this.handler = handler;
    }
```
这段代码是线程池的构造方法
* corePoolSize：**核心线程池大小**，我们每向线程池提交一个多线程任务时，都会创建一个新的`核心线程`，无论是否存在其他空闲线程，直到到达核心线程池大小为止，之后会尝试复用线程资源。当然也可以在一开始就全部初始化好，调用` prestartAllCoreThreads()`即可。
* maximumPoolSize：**最大线程池大小**，当目前线程池中所有的线程都处于运行状态，并且等待队列已满，那么就会直接尝试继续创建新的`非核心线程`运行，但是不能超过最大线程池大小。
* keepAliveTime：**线程最大空闲时间**，当一个`非核心线程`空闲超过一定时间，会自动销毁。
* unit：**线程最大空闲时间的时间单位**
* workQueue：**线程等待队列**，当线程池中核心线程数已满时，就会将任务暂时存到等待队列中，直到有线程资源可用为止，这里可以使用我们上一章学到的阻塞队列。
* threadFactory：**线程创建工厂**，我们可以干涉线程池中线程的创建过程，进行自定义。
* handler：**拒绝策略**，当等待队列和线程池都没有空间了，真的不能再来新的任务时，来了个新的多线程任务，那么只能拒绝了，这时就会根据当前设定的拒绝策略进行处理。

---
```java
    public static void main(String[] args) throws InterruptedException {
        ThreadPoolExecutor executor = new ThreadPoolExecutor(2, 4, 
        													 2, TimeUnit.SECONDS,
                                                             new ArrayBlockingQueue<Runnable>(2));
        for (int i = 0; i < 6; i++) {
            int fin = i;
            executor.execute(() -> {
                System.out.println("Task " + fin + " is running on thread " + Thread.currentThread().getName());
                try {
                    Thread.sleep(1000);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            });
        }

        TimeUnit.SECONDS.sleep(1);
        System.out.println(executor.getPoolSize());
        TimeUnit.SECONDS.sleep(3);
        System.out.println(executor.getPoolSize());

        executor.shutdownNow();
    }
    ---------------------------------------输出----------------------------------------------------
    Task 0 is running on thread pool-1-thread-1
	Task 1 is running on thread pool-1-thread-2
	Task 4 is running on thread pool-1-thread-3
	Task 5 is running on thread pool-1-thread-4
	4
	Task 3 is running on thread pool-1-thread-3
	Task 2 is running on thread pool-1-thread-1
	2
```
创建一个核心线程为2，最大线程为4，等待队列长度为2，空闲时间为2秒的线程池，在**Task 0**和**Task 1**开始执行后，核心队列已满，**Task 2**和**Task 3**进入阻塞队列，**Task 4**和**Task 5**发现阻塞队列也满了，但最大线程没满，开启新线程执行**Task 4**和**Task 5**。最后线程池中的任务结束，**Task 2**和**Task 3**调用线程池的线程执行任务。
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost02-03.jpeg)


