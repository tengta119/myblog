---
title: JVM 学习总结
categories: [后端开发, JVM]
tags: [Java, JVM]
date: 2025-08-02 00:20:41
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-01.png
---
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-01.png)
>https://www.bilibili.com/video/BV1yE411Z7AP
# 内存结构

## 程序计数器
好的，我们来详细讲解一下 Java 虚拟机（JVM）内存结构中的**程序计数器**（Program Counter Register）。

我会从它是什么、为什么需要它、如何工作以及它的核心特点这几个方面来全面解释。

-----

### 什么是程序计数器？

程序计数器，也常被称为 PC 寄存器，是 JVM 内存模型中一块非常小的内存空间。你可以把它想象成是当前线程正在执行的**字节码指令的地址或行号指示器**。

简单来说，它就是一个“书签”，记录着虚拟机“读”到了哪一行代码，下一行应该“读”什么。

在 JVM 的规范中，每个 Java 线程都有其自己独立的程序计数器。这些计数器在线程创建时一同创建，并伴随线程的整个生命周期。

### 核心作用：为什么需要程序计数器？

JVM 的执行引擎需要依赖程序计数器来读取下一条需要执行的字节码指令。它的核心作用是**控制程序的执行流程**。

如果缺少程序计数器，JVM 将不知道下一步该执行哪条指令。以下是它发挥作用的关键场景：

1.  **顺序执行**：最基本的功能，执行完当前指令后，PC 寄存器会自动指向下一条指令，保证代码按顺序执行。
2.  **分支与循环**：当遇到 `if-else`、`switch`、`for`、`while` 等控制流语句时，JVM 会根据判断结果，修改 PC 寄存器的值，让它跳转到指定的分支或循环体的字节码地址。
3.  **异常处理**：当发生异常时，异常处理器会捕获异常，并修改 PC 寄存器的值，将其指向异常处理代码块（`catch` 块）的起始地址。
4.  **方法调用与返回**：调用一个新方法时，PC 寄存器会记录下调用位置的下一条指令地址，然后跳转到新方法的入口地址。方法返回时，再恢复 PC 寄存器的值，回到原来的调用位置继续执行。
5.  **多线程切换**：这是 PC 寄存器最重要的用途之一。在多线程环境中，CPU 会在不同线程之间快速切换。当一个线程被挂起（失去 CPU 时间片）时，它的 PC 寄存器会保存当前执行到的指令地址。当这个线程再次获得 CPU 时间片时，它就能通过 PC 寄存器中保存的地址，准确地从上次中断的地方继续执行，而不会“迷路”。

### 实现原理

程序计数器的实现与当前线程执行的方法类型有关：

1.  **当执行的是一个 Java 方法时**：

      * PC 寄存器中存储的是一个**字节码指令的地址**。这个地址是相对于方法区中当前方法字节码的偏移量。JVM 的执行引擎（如解释器）就是通过这个地址来获取下一条要执行的字节码指令。

2.  **当执行的是一个本地（Native）方法时**：

      * 本地方法是通过 JNI (Java Native Interface) 调用 C/C++ 等本地库实现的，其执行不归 JVM 管理，而是直接在底层操作系统上运行。
      * 在这种情况下，程序计数器的值是**未定义的（Undefined）**。因为 JVM 无法追踪到本地代码的执行位置。

从物理实现上讲，JVM 中的程序计数器通常会直接利用 CPU 的物理寄存器来实现，因为这能提供最快的读写速度。

### 主要特点

程序计数器有几个非常鲜明且重要的特点：

1.  **线程私有（Thread-Private）**

      * 这是它最核心的特性。每个线程都有自己独立的 PC 寄存器，互不干扰。这保证了在并发环境下，线程切换后能够正确恢复执行现场。如果所有线程共享一个 PC 寄存器，那么执行流程将彻底混乱。

2.  **不会发生内存溢出（No `OutOfMemoryError`）**

      * 程序计数器是 JVM 运行时数据区中**唯一一个**在 Java 虚拟机规范中没有规定任何 `OutOfMemoryError` 情况的区域。
      * 原因很简单：它占用的内存空间非常小（通常只占一个字长，如 32 位或 64 位），并且在线程创建时大小就已经确定，在运行期间不会改变。这点内存对于现代计算机来说几乎可以忽略不计。

3.  **极快的访问速度（Extremely Fast Access）**

      * 由于它通常由 CPU 寄存器直接实现，其读写操作是所有内存操作中最快的，几乎没有延迟。这是保证 JVM 执行效率的基础。

4.  **生命周期与线程同步**

      * 它的生命周期与所属的线程完全一致，随线程的创建而创建，随线程的销毁而销毁。

### 示例：PC 寄存器如何工作

让我们通过一个简单的例子来直观感受一下。

**Java 代码:**

```java
public class PCTest {
    public static void main(String[] args) {
        int a = 10;
        int b = 20;
        int c = a + b;
    }
}
```

使用 `javap -c PCTest` 命令可以查看其字节码：

```
public static void main(java.lang.String[]);
  Code:
     0: bipush        10   // 将 10 推到操作数栈顶
     2: istore_1           // 将栈顶的值存入局部变量表索引为 1 的位置 (a)
     3: bipush        20   // 将 20 推到操作数栈顶
     5: istore_2           // 将栈顶的值存入局部变量表索引为 2 的位置 (b)
     6: iload_1            // 从局部变量表加载 a
     7: iload_2            // 从局部变量表加载 b
     8: iadd               // 执行加法
     9: istore_3           // 将结果存入局部变量表索引为 3 的位置 (c)
    10: return             // 方法返回
```

**PC 寄存器的变化过程：**

1.  初始状态，PC 寄存器的值为 `0`。
2.  执行引擎读取地址 `0` 的指令 `bipush 10`。执行完毕后，PC 寄存器的值更新为下一条指令的地址 `2`。
3.  执行引擎读取地址 `2` 的指令 `istore_1`。执行完毕后，PC 寄存器的值更新为 `3`。
4.  执行引擎读取地址 `3` 的指令 `bipush 20`。执行完毕后，PC 寄存器的值更新为 `5`。
5.  ... 以此类推，PC 寄存器像一个指针一样，一步步地引导着整个程序的执行流程，直到遇到 `return` 指令。

-----

### 总结

| 特性 | 描述 |
| :--- | :--- |
| **定义** | 当前线程所执行的字节码指令的地址指示器。 |
| **作用** | 控制程序执行流程，实现分支、循环、跳转、异常处理、线程恢复等功能。 |
| **归属** | **线程私有**，每个线程独享一份。 |
| **内存** | 占用空间极小，是唯一**不会**发生 `OutOfMemoryError` 的区域。 |
| **实现** | 执行 Java 方法时，存储字节码地址；执行 Native 方法时，值为空（Undefined）。 |
| **速度** | 读写速度极快，通常由 CPU 寄存器实现。 |

理解程序计数器是深入学习 JVM 内存模型和 Java 并发编程的基础。它虽然简单，却是整个 JVM 执行引擎能够有序工作的核心部件。

## Java 虚拟机栈
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-02.png)
栈帧：每个方法运行时需要的内存

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-03.png)

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-04.png)

### 什么是 Java 虚拟机栈？

Java 虚拟机栈是 **线程私有** 的内存区域，它的生命周期与线程相同。当一个线程被创建时，JVM 会为它分配一个对应的虚拟机栈；当线程结束时，这个栈也会被销毁。

它的核心作用是**为 Java 方法的执行提供内存模型**。每当一个方法被调用时，JVM 就会在当前线程的虚拟机栈中创建一个称为 **“栈帧”（Stack Frame）** 的数据结构，并将其推入（push）栈顶。当这个方法执行完毕后，对应的栈帧就会被弹出（pop）并销毁。

因此，对于一个线程来说，任何时候只有位于栈顶的栈帧是**活动的（Active）**，这个栈帧被称为**当前栈帧（Current Stack Frame）**，它对应的方法被称为**当前方法（Current Method）**。所有字节码指令的操作都只针对当前栈帧进行。

你可以把它想象成一个叠起来的盘子：

  * **调用一个新方法** = 往盘子堆顶部放一个新盘子。
  * **方法执行结束** = 从顶部拿走一个盘子。
  * **你永远只能使用最上面的那个盘子**。

这种后进先出（Last-In, First-Out, LIFO）的数据结构完美地契合了方法调用的层级关系。

### 栈帧的内部结构 

栈帧是虚拟机栈的基本元素，是方法执行期间所有数据的集合。每个栈帧都包含以下几个关键部分：

1.  **局部变量表（Local Variable Table）**

      * 这是一块用于存储**方法参数**和**方法内部定义的局部变量**的区域。
      * 它是一个以“槽”（Slot）为单位的数组，每个槽可以存放一个 `boolean`, `byte`, `char`, `short`, `int`, `float`, `reference`（对象引用）或 `returnAddress` 类型的数据。
      * `long` 和 `double` 类型的数据会占用两个连续的槽。
      * 对于实例方法（非 `static` 方法），局部变量表的第 0 个槽默认存放指向该方法所属对象的引用，即 `this`。
      * 局部变量表的大小在 Java 代码**编译成字节码时就已经确定**，并在方法运行期间保持不变。

2.  **操作数栈（Operand Stack）**

      * 这也是一个后进先出（LIFO）的栈，用于存放方法执行过程中的临时数据。它扮演着 JVM 执行引擎的**工作区**或**计算舞台**的角色。
      * 字节码指令会从局部变量表中加载数据，推入操作数栈，然后从操作数栈中弹出数据进行运算，最后再将运算结果推入操作数栈或存回局部变量表。
      * 例如，执行 `a + b` 时，会先把 `a` 和 `b` 的值依次压入操作数栈，然后执行 `iadd` 指令，该指令会弹出栈顶的两个值相加，再将结果压回栈顶。

3.  **动态链接（Dynamic Linking）**

      * 每个栈帧都包含一个指向运行时常量池中该栈帧所属方法的引用。
      * 这个引用的作用是为了支持方法调用过程中的**动态链接**。
      * 在编译时，一个方法调用另一个方法，是以符号引用（Symbolic Reference，比如方法的全限定名和描述符）的形式存在于 `.class` 文件中。在运行时，JVM 需要将这些符号引用转换为可以直接调用的内存地址，即直接引用（Direct Reference）。这个转换过程就是动态链接。

4.  **方法返回地址（Return Address）**

      * 当一个方法执行完毕后，需要返回到调用它的地方继续执行。方法返回地址就存储了这个“调用者的位置”。
      * 方法退出有两种方式：
          * **正常返回（Normal Completion）**：执行了 `return` 指令。调用者的 PC 计数器会恢复，程序继续正常执行。
          * **异常返回（Abrupt Completion）**：方法执行过程中抛出了未被捕获的异常。这种情况下，返回地址由异常处理器表来确定，而不会返回给调用者。

### 主要特点

1.  **线程私有（Thread-Private）**

      * 和程序计数器一样，虚拟机栈是线程隔离的。每个线程都有自己的栈，因此栈内的局部变量等数据对其他线程是不可见的。这也是为什么局部变量是**线程安全**的根本原因。

2.  **生命周期与线程同步**

      * 随线程创建而生，随线程结束而亡。

3.  **可能出现的两种异常**

      * `StackOverflowError`（栈溢出错误）：
          * **原因**：如果线程请求的栈深度大于虚拟机所允许的最大深度，就会抛出此错误。
          * **常见场景**：无限递归调用或方法调用层次过深（例如，一个方法调用自己没有出口）。
          * 栈的深度可以是固定的（通过 `-Xss` 参数设置），也可以是动态扩展的。
      * `OutOfMemoryError`（内存溢出错误）：
          * **原因**：如果虚拟机栈允许动态扩展，但在尝试扩展时无法申请到足够的内存，就会抛出此错误。或者，当创建一个新线程时，没有足够的内存来为其创建对应的虚拟机栈。
          * **说明**：相比于 `StackOverflowError`，这种 OOM 在虚拟机栈上相对少见，但理论上是可能发生的。
### 总结

Java 虚拟机栈是理解 Java 程序运行机制的核心。它通过栈帧来支持方法的调用和执行，管理着方法的局部变量、计算过程和返回逻辑。它的线程私有特性是 Java 实现多线程安全的重要基石之一，而 `StackOverflowError` 也是每个 Java 开发者都可能遇到的典型运行时错误。

### 线程诊断
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-05.png)
### 本地方法栈

## 堆
存放创建的对象

### 堆内存诊断
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-06.png)
* jvisualvm


## 方法区
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-07.png)
JDK8之后，字符串常量池和静态变量移到堆中了
### 1. 什么是方法区？

方法区和 Java 堆一样，是**所有线程共享**的内存区域。

根据《Java虚拟机规范》的定义，方法区是一个**逻辑上**的概念，它用于存储已被虚拟机加载的**类信息、常量、静态变量、即时编译器（JIT）编译后的代码缓存**等数据。

可以把它理解为存放“模板”的地方：我们用 `new` 关键字创建对象实例时，对象本身放在**堆**里，但创建这个对象所依据的 `class` 定义信息，则存放在**方法区**里。

**关键点**：
* **线程共享**：所有线程都可以访问方法区的数据。
* **逻辑概念**：它是一种规范，不同的 JVM 实现可以有不同的方式来实现它。最著名的实现就是我们接下来要讲的“永久代”和“元空间”。

---

### 2. 方法区的演进：从永久代到元空间

这是理解方法区最核心的部分，因为它的具体实现随着 Java 版本的更新发生了重大变化。我们主要讨论 Oracle 的 HotSpot 虚拟机。

#### a) Java 8 之前：永久代

在 Java 8 之前的版本中，HotSpot 虚拟机使用**永久代**来实现方法区。

* **特点**：永久代是 **Java 堆的一部分**。这意味着它和其他对象一样，受到 JVM 堆内存大小的限制，并且由 JVM 的垃圾回收器来管理。
* **缺点**：
    1.  **大小固定**：永久代有一个固定的最大尺寸（可以通过 `-XX:MaxPermSize` 设置）。在动态加载大量类（如使用 CGLIB 动态代理、启动大量 Web 应用）的场景下，非常容易耗尽空间，从而抛出 `java.lang.OutOfMemoryError: PermGen space` 异常。
    2.  **GC效率低**：对永久代的垃圾回收（主要是卸载不再使用的类）条件苛刻且效率不高，一次针对永久代的 Full GC 会带来较长的“Stop-The-World”暂停。

#### b) Java 8 及之后：元空间

为了解决永久代的这些问题，从 Java 8 开始，HotSpot 虚拟机移除了永久代，并引入了一个新的实现——**元空间**。

* **最大变化**：元空间**不再位于 Java 堆中，而是直接使用本地内存（Native Memory）**。
* **优点**：
    1.  **解除大小限制**：理论上，只要你的服务器物理内存足够，元空间就可以一直扩展，从根本上解决了 `PermGen space` 的 OOM 问题。当然，你也可以通过 `-XX:MaxMetaspaceSize` 来设定其最大值，以防它无节制地消耗系统内存。
    2.  **更好的性能**：将类的元数据从堆中移出，使得 Full GC 时需要扫描和处理的内容变少，有助于降低 GC 带来的暂停时间。

**总结一下二者的核心区别：**

| 特性 | 永久代 (PermGen) | 元空间 (Metaspace) |
| :--- | :--- | :--- |
| **存在版本** | JDK 1.7 及之前 | JDK 1.8 及之后 |
| **内存位置** | **Java 堆** 的一部分 | **本地内存** (Native Memory)，独立于堆 |
| **大小限制** | 固定，由 `-XX:MaxPermSize` 控制 | 默认只受限于物理内存，可由 `-XX:MaxMetaspaceSize` 控制 |
| **常见错误** | `OutOfMemoryError: PermGen space` | `OutOfMemoryError: Metaspace` |

---

### 3. 方法区（元空间）里到底存了什么？

无论是永久代还是元空间，它们作为方法区的实现，存储的内容大体一致：

1.  **类型信息（Class Information）**：
    * 类的完整有效名称（包名.类名）。
    * 类的直接父类的完整有效名称。
    * 类的修饰符（public, abstract, final 等）。
    * 类的直接实现接口的有序列表。

2.  **字段信息（Field Information）**：
    * 类的所有字段（成员变量）的名称、类型和修饰符。

3.  **方法信息（Method Information）**：
    * 类的所有方法的名称、返回类型、参数数量和类型、修饰符。
    * 方法的字节码（Bytecode）、操作数栈大小、局部变量表大小等。

4.  **静态变量（Static Variables）**：
    * 被 `static` 关键字修饰的类变量。这些变量与类直接关联，而不是与对象实例关联。

5.  **运行时常量池（Runtime Constant Pool）**：
    * 这是方法区中非常重要的一部分，是每个类或接口的常量池的运行时表示形式。
    * 它包含编译期生成的各种字面量（如文本字符串、`final`常量值）和符号引用（如类和接口的全限定名、字段和方法的名称和描述符）。
    * 当程序运行时，JVM 会将这些符号引用解析为直接引用（内存地址）。

6.  **JIT 编译后的代码缓存**：
    * JVM 会将频繁执行的“热点”字节码编译为本地机器码以提升性能，这部分编译后的代码也存储在方法区中。

---

### 4. 一个特殊区域：字符串常量池

这是一个经常与方法区一起讨论但又比较特殊的地方。它的位置也发生了变迁：

* **JDK 1.6 及之前**：字符串常量池存放在**永久代**中。
* **JDK 1.7 开始**：字符串常量池被从永久代**移动到了 Java 堆**中。

**为什么移动？**
因为永久代的空间有限且垃圾回收效率低。程序中通常会创建大量的字符串，如果都放在永久代，很容易引发 `PermGen space` 错误。将它移到空间更大、GC 更频繁的堆区，是一个更合理的设计。

因此，在 Java 8 及以后的版本中，**方法区的实现是元空间（在本地内存），而字符串常量池则在堆内存中**。

希望这个讲解能帮你清晰地区分方法区、永久代和元空间这些概念。


### StringTable 
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-08.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-09.png)
s3 和 s5 相等
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-10.png)
字符串池去重

## 直接内存 - 系统系统内存
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-11.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-12.png)
### 1. 什么是直接内存？

直接内存（Direct Memory）是指**在 Java 堆之外，直接向操作系统申请的内存空间**。它不归 JVM 的垃圾回收器（Garbage Collector）直接管理，而是由 Java 程序通过代码（主要是 NIO 相关 API）来分配、使用和释放。

程序可以通过 `java.nio.ByteBuffer.allocateDirect(int capacity)` 方法来分配一块直接内存。这个方法返回的是一个 `DirectByteBuffer` 对象，这个对象本身在 Java 堆上，但它内部引用了一块位于堆外的、由操作系统管理的本地内存。

### 2. 为什么要使用直接内存？（核心动机）

使用直接内存最核心的目的是**提升 I/O 操作的性能**，特别是网络和文件 I/O。为了理解这一点，我们需要对比传统 I/O 和使用直接内存的 NIO 的区别。

#### a) 传统的 I/O 操作（使用堆内存）

1.  Java 程序发起读操作，需要在\*\*堆（Heap）\*\*上创建一个 `byte[]` 缓冲区。
2.  操作系统从磁盘或网卡读取数据，先将数据放入**操作系统内核的缓冲区**中。
3.  然后，数据从**内核缓冲区**被**复制**到 Java **堆上的 `byte[]` 缓冲区**中。
4.  之后，Java 程序才能处理堆上的这些数据。

**缺点**：在这个过程中，数据存在一次**不必要的拷贝**（从内核空间 -\> JVM 堆空间）。当处理大量数据时，这次拷贝会带来明显的性能开销和 CPU 占用。

#### b) 使用直接内存的 I/O 操作 (NIO)

1.  Java 程序通过 `ByteBuffer.allocateDirect()` 在**堆外**分配一块直接内存。
2.  Java 程序发起读操作，操作系统直接将数据从磁盘或网卡读入这块**直接内存**中。
3.  Java 程序直接操作这块内存。

**优点**：这个过程**省去了从内核空间到 JVM 堆空间的拷贝**。数据直接在操作系统和应用程序的“共享区域”（直接内存）中传递，大大减少了数据拷贝次数，提升了 I/O 效率。这种机制通常被称为\*\*零拷贝（Zero-Copy）\*\*的一种形式。

**一句话总结动机**：**通过在堆外分配内存，避免了 JVM 堆与操作系统内核之间的数据拷贝，从而提高了 I/O 性能。**

### 3. 直接内存的管理

#### 分配与释放

  * **分配**：通过 `ByteBuffer.allocateDirect()`。这个操作的成本比在堆上分配对象要高，因为它涉及到对操作系统的调用。
  * **释放**：这是一个关键点。直接内存不受 JVM GC 的直接管理。它的回收依赖于一个巧妙的机制：
    1.  `DirectByteBuffer` 对象本身是普通的 Java 对象，存放在**堆**上，受 GC 管理。
    2.  当 `DirectByteBuffer` 对象没有任何引用，即将被 GC 回收时，JVM 会通过一种叫做 **`Cleaner`** (在旧版本中是 `PhantomReference` 和 `Finalizer`) 的机制来触发一个操作。
    3.  这个操作会调用底层的 C 代码（例如 `Unsafe.freeMemory()`），最终释放掉 `DirectByteBuffer` 对象所引用的那块**堆外直接内存**。

#### 潜在风险

这种间接的回收机制可能带来一个严重的问题：`OutOfMemoryError: Direct buffer memory`。

  * **原因**：如果程序大量分配直接内存，但此时 Java 堆内存的使用率很低，导致迟迟没有触发垃圾回收（特别是 Full GC）。那么，大量的 `DirectByteBuffer` 对象就不会被回收，其关联的直接内存也得不到释放。最终，即使堆内存还很充足，直接内存也可能被耗尽，从而抛出 OOM 异常。

### 4. 直接内存的特点总结

| 优点 👍 | 缺点 👎 |
| :--- | :--- |
| **I/O 性能高**：减少了数据拷贝，特别适合网络编程（如 Netty）、文件读写等场景。 | **分配/释放开销大**：向操作系统申请内存比在堆上分配对象更慢。 |
| **减少 GC 影响**：由于大块数据在堆外，Full GC 时无需扫描和移动这部分数据，可以降低 GC 暂停时间（STW）。 | **内存管理复杂**：回收不及时可能导致内存泄漏或 OOM，排查问题相对困难。 |
| **可用于进程间共享**：虽然 Java 本身不直接支持，但一些高级用法可以利用直接内存实现进程间通信。 | **不受 JVM 堆大小限制**：它的上限由 `-XX:MaxDirectMemorySize` 参数控制（默认与 `-Xmx` 相同），但最终受限于物理内存。 |

### 5. 什么时候使用直接内存？

  * 需要进行大量 I/O 操作的场景，例如：
      * 高性能网络框架（**Netty**、Mina 等底层都广泛使用了直接内存）。
      * 需要与本地代码（JNI）进行大量数据交换。
      * 频繁读写大文件。
  * 当数据需要长期驻留内存且不希望受 GC 影响时。

总而言之，直接内存是 JVM 提供的一把性能优化的“利剑”，它通过牺牲一定的安全性和易用性，换取了在特定场景下（主要是 I/O）的极致性能。

# 垃圾回收
## 如何判断对象可以回收

* **引用计数法**
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-13.png)
* 可达性分析算法

### 四种引用
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-14.png)  
![](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-15.png)


#### 1. 强引用（Strong Reference）

这是我们日常编程中最常见、最普通的引用类型。

  * **定义**：通过 `new` 关键字创建对象，并将其赋值给一个引用变量时，这个变量就是对该对象的强引用。
    ```java
    Object obj = new Object(); // obj 就是一个强引用，指向新创建的 Object 实例
    ```
  * **GC 行为**：**只要一个对象存在强引用，垃圾回收器就永远不会回收它**，即使系统内存严重不足，宁可抛出 `OutOfMemoryError` 异常也不会回收。
  * **生命周期**：对象的生命周期由强引用的作用域决定。要让对象被回收，必须将所有指向它的强引用断开，例如设置为 `null`。
    ```java
    obj = null; // 断开强引用，现在对象可以被 GC 回收了
    ```
  * **用途**：程序中绝大多数对象的存活都依赖于强引用。

-----

#### 2. 软引用（Soft Reference）

软引用用来描述一些**还有用，但非必需**的对象。

  * **定义**：通过 `java.lang.ref.SoftReference` 类来实现。
    ```java
    Object obj = new Object();
    SoftReference<Object> softRef = new SoftReference<>(obj);
    obj = null; // 断开强引用，现在对象只被软引用关联
    ```
  * **GC 行为**：**当系统内存充足时，垃圾回收器不会回收被软引用的对象。只有在系统内存即将耗尽（即将发生 `OutOfMemoryError`）时，垃圾回收器才会回收这些对象。**
  * **生命周期**：可以存活多次 GC，直到内存紧张时才被回收。
  * **用途**：最适合的场景是实现**内存敏感的高速缓存（Memory-sensitive Cache）**。
      * 例如，一个图片浏览器可以把加载过的图片用软引用缓存起来。内存够用时，用户再次打开图片就能立刻显示。内存不够时，GC 会自动回收这些图片缓存，避免程序崩溃，程序只需重新从磁盘加载即可。

* **引用队列**：配合引用队列回收软引用对象
-----

#### 3. 弱引用（Weak Reference）

弱引用的强度比软引用更弱，它描述的是**可有可无**的对象。

  * **定义**：通过 `java.lang.ref.WeakReference` 类来实现。
    ```java
    Object obj = new Object();
    WeakReference<Object> weakRef = new WeakReference<>(obj);
    obj = null; // 断开强引用，现在对象只被弱引用关联
    ```
  * **GC 行为**：**无论当前内存是否充足，只要垃圾回收器开始工作，被弱引用的对象就一定会被回收。** 它的生存期只能持续到下一次垃圾回收发生之前。
  * **生命周期**：非常短暂，一次 GC 就可能“阵亡”。
  * **用途**：
    1.  **防止内存泄漏**：在一些监听器（Listener）或回调（Callback）模式中非常有用。如果一个对象被一个长生命周期的集合所持有，但我们希望在该对象没有其他强引用时能被及时回收，就可以使用弱引用。`WeakHashMap` 就是一个典型的应用。
    2.  **ThreadLocal**：`ThreadLocalMap` 的键（Key）就是对 `ThreadLocal` 实例的弱引用。这样，当外部不再有对 `ThreadLocal` 实例的强引用时，即使线程还在运行，这个键也会被回收，从而避免了内存泄漏。

##### 弱引用中，若 new Object() 被回收后，weakRef 的值是不是为 null

答案是：**`weakRef` 的值不会变为 `null`，但是调用 `weakRef.get()` 的结果会变为 `null`。**

我们来拆解一下这个过程，这能帮助你更深刻地理解引用的概念。


深入解析

我们回顾一下代码：

```java
// 1. obj 是对 new Object() 的强引用
Object obj = new Object();

// 2. weakRef 是对 new WeakReference<>() 这个“包装盒”对象的强引用
//    这个“包装盒”里面用弱引用的方式装着最初的 new Object()
WeakReference<Object> weakRef = new WeakReference<>(obj);

// 3. 断开唯一的强引用
obj = null;
```

在这里，你需要区分两个东西：

1.  **被引用的对象 (Referent)**：即 `new Object()` 创建的那个实例。我们称它为“目标对象”。
2.  **引用对象本身 (Reference Object)**：即 `new WeakReference<>()` 创建的那个实例。它像一个包装盒，里面装着目标对象的地址。我们这里的变量 `weakRef` 就是对这个“包装盒”的强引用。

**当垃圾回收发生时：**

1.  GC 发现“目标对象” (`new Object()`) 已经没有任何**强引用**指向它了，只有一个来自 `weakRef` 这个“包装盒”的弱引用。
2.  根据弱引用的规则，GC 决定**回收“目标对象”**，释放它占用的内存。
3.  在回收的同时，GC 会**清空** `weakRef` 这个“包装盒”里的内容（即目标对象的地址）。
4.  此时，`weakRef` 这个变量仍然存在，它仍然强引用着那个 `WeakReference` “包装盒”对象。所以，`weakRef` 本身**绝对不是 `null`**。
5.  但是，因为“包装盒”里的东西已经被清空了，所以当你试图通过 `weakRef.get()` 去获取“目标对象”时，就会得到 `null`。

 一个生动的比喻

  * `new Object()` 是一个**气球**。
  * `Object obj = ...` 是你手里**紧紧攥着**气球的绳子（强引用）。
  * `WeakReference<Object> weakRef = ...` 是你把绳子的另一端**轻轻地挂在**一个钩子上（弱引用），而 `weakRef` 变量是你对这个**钩子**本身的引用。

现在，你松开了手里紧攥的绳子 (`obj = null;`)。

一阵风吹来（GC 执行），风的力量足以吹走那个只是被轻轻挂在钩子上的气球。

结果是：

  * **气球 (`new Object()`) 飞走了（被回收）。**
  * **钩子 (`weakRef` 这个 `WeakReference` 对象) 还好好地在墙上 (`weakRef != null`)。**
  * **但你再去看钩子上时，已经没有气球了 (`weakRef.get() == null`)。**

代码验证

我们可以写一小段代码来清晰地验证这一点：

```java
import java.lang.ref.WeakReference;

public class WeakReferenceTest {
    public static void main(String[] args) {
        // 创建一个对象，并用强引用指向它
        Object myObject = new Object();
        System.out.println("1. 目标对象刚创建: " + myObject);

        // 创建一个弱引用，指向这个对象
        WeakReference<Object> weakRef = new WeakReference<>(myObject);
        System.out.println("2. weakRef 包装盒对象: " + weakRef);
        System.out.println("   通过 get() 获取目标对象: " + weakRef.get());

        // 断开唯一的强引用
        myObject = null;
        System.out.println("\n3. 断开强引用后...");

        // 建议 JVM 进行垃圾回收
        System.gc();

        System.out.println("\n4. GC 之后...");
        System.out.println("   weakRef 包装盒对象是否为 null? " + (weakRef == null)); // 输出 false
        System.out.println("   通过 get() 获取目标对象: " + weakRef.get()); // 输出 null
    }
}
```

**输出结果：**

```
1. 目标对象刚创建: java.lang.Object@1b6d3586
2. weakRef 包装盒对象: java.lang.ref.WeakReference@4554617c
   通过 get() 获取目标对象: java.lang.Object@1b6d3586

3. 断开强引用后...

4. GC 之后...
   weakRef 包装盒对象是否为 null? false
   通过 get() 获取目标对象: null
```

这个结果清晰地证明了我们的结论：`weakRef` 变量本身不为 `null`，但其内部引用的对象在 GC 后无法再通过 `get()` 方法访问到。

-----

#### 4. 虚引用（Phantom Reference）

虚引用也称“幻影引用”或“幽灵引用”，是所有引用类型中最弱的一种。

  * **定义**：通过 `java.lang.ref.PhantomReference` 类来实现。它必须和一个\*\*引用队列（ReferenceQueue）\*\*联合使用。
    ```java
    Object obj = new Object();
    ReferenceQueue<Object> queue = new ReferenceQueue<>();
    PhantomReference<Object> phantomRef = new PhantomReference<>(obj, queue);
    obj = null;
    ```
  * **GC 行为**：
      * 一个对象是否有虚引用，**完全不影响其生命周期**。在任何时候，对象都可能被垃圾回收器回收。
      * 通过虚引用的 `get()` 方法**永远无法获取到对象实例**，`phantomRef.get()` 总是返回 `null`。
  * **唯一作用**：**跟踪对象被垃圾回收的状态**。当一个被虚引用关联的对象即将被回收时，JVM 会在回收该对象之前，将这个虚引用对象本身（`phantomRef`）放入与之关联的引用队列（`queue`）中。
  * **用途**：主要用于管理**堆外内存（Direct Memory）**。
      * 例如 `DirectByteBuffer`，当它的 Java 对象被回收时，我们需要一个可靠的通知机制来释放它所占用的本地内存（Native Memory）。通过为其设置一个虚引用和引用队列，一个专门的线程可以监视这个队列。一旦从队列中获取到了虚引用，就说明其关联的 Java 对象已被回收，此时就可以安全地执行本地内存的释放操作。这种方式比 `finalize()` 方法更可靠、更高效。

-----

#### 总结对比

| 引用类型 | 强度 | 回收时机 | 主要用途 |
| :--- | :--- | :--- | :--- |
| **强引用 (Strong)** | 最强 | 从不回收（除非引用断开） | 普通的对象引用，程序的基石 |
| **软引用 (Soft)** | 较强 | 内存不足时回收 | 实现内存敏感的缓存 |
| **弱引用 (Weak)** | 较弱 | 下一次 GC 时必定回收 | 防止内存泄漏，如 `WeakHashMap` |
| **虚引用 (Phantom)** | 最弱 | `get()` 永远返回 `null`，只作通知 | 跟踪对象回收状态，管理堆外内存 |

## 垃圾回收算法
* 标记清除
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-16.png)

* 标记整理
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-17.png)
* 复制

![ ](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-18.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-19.png)
`to` 总是空闲的一块空间

## 分代垃圾回收

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-20.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-21.png)

## 垃圾回收器
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-22.png)
### 串行
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-23.png)
### 吞吐量优先
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-24.png)
### 响应时间优先
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-25.png)
**初始标记**，指的是寻找所有被 GCRoots 引用的对象，该阶段需要「Stop the World」。这个步骤仅仅只是标记一下 GC Roots 能直接关联到的对象，并不需要做整个引用的扫描，因此速度很快。

**并发标记**，指的是对「初始标记阶段」标记的对象进行整个引用链的扫描，该阶段不需要「Stop the World」。 对整个引用链做扫描需要花费非常多的时间，因此通过垃圾回收线程与用户线程并发执行，可以降低垃圾回收的时间。

这也是 CMS 能极大降低 GC 停顿时间的核心原因，但这也带来了一些问题，即：并发标记的时候，引用可能发生变化，因此可能发生漏标（本应该回收的垃圾没有被回收）和多标（本不应该回收的垃圾被回收）了。

**重新标记**，指的是对「并发标记」阶段出现的问题进行校正，该阶段需要「Stop the World」。正如并发标记阶段说到的，由于垃圾回收算法和用户线程并发执行，虽然能降低响应时间，但是会发生漏标和多标的问题。所以对于 CMS 来说，它需要在这个阶段做一些校验，解决并发标记阶段发生的问题。

**并发清除**，指的是将标记为垃圾的对象进行清除，该阶段不需要「Stop the World」。 在这个阶段，垃圾回收线程与用户线程可以并发执行，因此并不影响用户的响应时间。
### G1
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-26.png)
G1（Garbage-First Garbage Collector）在 JDK 1.7 时引入，在 JDK 9 时取代 CMS 成为了默认的垃圾收集器。G1 有五个属性：分代、增量、并行、标记整理、STW。

①、分代：相信大家还记得我们上一讲中的年轻代和老年代，G1 也是基于这个思想进行设计的。它将堆内存分为多个大小相等的区域（Region），每个区域都可以是 Eden 区、Survivor 区或者 Old 区。


可以通过 -XX:G1HeapRegionSize=n 来设置 Region 的大小，可以设定为 1M、2M、4M、8M、16M、32M（不能超过）。

G1 有专门分配大对象的 Region 叫 Humongous 区，而不是让大对象直接进入老年代的 Region 中。在 G1 中，大对象的判定规则就是一个大对象超过了一个 Region 大小的 50%，比如每个 Region 是 2M，只要一个对象超过了 1M，就会被放入 Humongous 中，而且一个大对象如果太大，可能会横跨多个 Region 来存放。

G1 会根据各个区域的垃圾回收情况来决定下一次垃圾回收的区域，这样就避免了对整个堆内存进行垃圾回收，从而降低了垃圾回收的时间。

②、增量：G1 可以以增量方式执行垃圾回收，这意味着它不需要一次性回收整个堆空间，而是可以逐步、增量地清理。有助于控制停顿时间，尤其是在处理大型堆时。

③、并行：G1 垃圾回收器可以并行回收垃圾，这意味着它可以利用多个 CPU 来加速垃圾回收的速度，这一特性在年轻代的垃圾回收（Minor GC）中特别明显，因为年轻代的回收通常涉及较多的对象和较高的回收速率。

④、标记整理：在进行老年代的垃圾回收时，G1 使用标记-整理算法。这个过程分为两个阶段：标记存活的对象和整理（压缩）堆空间。通过整理，G1 能够避免内存碎片化，提高内存利用率。

年轻代的垃圾回收（Minor GC）使用复制算法，因为年轻代的对象通常是朝生夕死的。


⑤、STW：G1 也是基于「标记-清除」算法，因此在进行垃圾回收的时候，仍然需要「Stop the World」。不过，G1 在停顿时间上添加了预测机制，用户可以指定期望停顿时间。


G1 中存在三种 GC 模式，分别是 Young GC、Mixed GC 和 Full GC。


当 Eden 区的内存空间无法支持新对象的内存分配时，G1 会触发 Young GC。

当需要分配对象到 Humongous 区域或者堆内存的空间占比超过 -XX:G1HeapWastePercent 设置的 InitiatingHeapOccupancyPercent 值时，G1 会触发一次 concurrent marking，它的作用就是计算老年代中有多少空间需要被回收，当发现垃圾的占比达到 -XX:G1HeapWastePercent 中所设置的 G1HeapWastePercent 比例时，在下次 Young GC 后会触发一次 Mixed GC。

Mixed GC 是指回收年轻代的 Region 以及一部分老年代中的 Region。Mixed GC 和 Young GC 一样，采用的也是复制算法。

在 Mixed GC 过程中，如果发现老年代空间还是不足，此时如果 G1HeapWastePercent 设定过低，可能引发 Full GC。-XX:G1HeapWastePercent 默认是 5，意味着只有 5% 的堆是“浪费”的。如果浪费的堆的百分比大于 G1HeapWastePercent，则运行 Full GC。

在以 Region 为最小管理单元以及所采用的 GC 模式的基础上，G1 建立了停顿预测模型，即 Pause Prediction Model 。这也是 G1 非常被人所称道的特性。

我们可以借助 -XX:MaxGCPauseMillis 来设置期望的停顿时间（默认 200ms），G1 会根据这个值来计算出一个合理的 Young GC 的回收时间，然后根据这个时间来制定 Young GC 的回收计划。

### ZGC
ZGC 很牛逼，它的目标是：

* 停顿时间不超过 10ms；
* 停顿时间不会随着堆的大小，或者活跃对象的大小而增加；
* 支持 8MB~4TB 级别的堆，未来支持 16TB。

前面讲 G1 垃圾收集器的时候提到过，Young GC 和 Mixed GC 均采用的是复制算法，复制算法主要包括以下 3 个阶段：

①、标记阶段，从 GC Roots 开始，分析对象可达性，标记出活跃对象。

②、对象转移阶段，把活跃对象复制到新的内存地址上。

③、重定位阶段，因为转移导致对象地址发生了变化，在重定位阶段，所有指向对象旧地址的引用都要调整到对象新的地址上。

标记阶段因为只标记 GC Roots，耗时较短。但转移阶段和重定位阶段需要处理所有存活的对象，耗时较长，并且转移阶段是 STW 的，因此，G1 的性能瓶颈就主要卡在转移阶段。

与 G1 和 CMS 类似，ZGC 也采用了复制算法，只不过做了重大优化，ZGC 在标记、转移和重定位阶段几乎都是并发的，这是 ZGC 实现停顿时间小于 10ms 的关键所在。


ZGC 是怎么做到的呢？

* 指针染色（Colored Pointer）：一种用于标记对象状态的技术。
* 读屏障（Load Barrier）：一种在程序运行时插入到对象访问操作中的特殊检查，用于确保对象访问的正确性。

这两种技术可以让所有线程在并发的条件下就指针的颜色 (状态) 达成一致，而不是对象地址。因此，ZGC 可以并发的复制对象，这大大的降低了 GC 的停顿时间。

**指针染色**

在一个指针中，除了存储对象的实际地址外，还有额外的位被用来存储关于该对象的元数据信息。这些信息可能包括：

* 对象是否被移动了（即它是否在回收过程中被移动到了新的位置）。
* 对象的存活状态。
* 对象是否被锁定或有其他特殊状态。

通过在指针中嵌入这些信息，ZGC 在标记和转移阶段会更快，因为通过指针上的颜色就能区分出对象状态，不用额外做内存访问。

ZGC仅支持64位系统，它把64位虚拟地址空间划分为多个子空间，如下图所示：


其中，0-4TB 对应 Java 堆，4TB-8TB 被称为 M0 地址空间，8TB-12TB 被称为 M1 地址空间，12TB-16TB 预留未使用，16TB-20TB 被称为 Remapped 空间。

当创建对象时，首先在堆空间申请一个虚拟地址，该虚拟地址并不会映射到真正的物理地址。同时，ZGC 会在 M0、M1、Remapped 空间中为该对象分别申请一个虚拟地址，且三个虚拟地址都映射到同一个物理地址。

不过，三个空间在同一时间只有一个空间有效。ZGC 之所以设置这三个虚拟地址，是因为 ZGC 采用的是“空间换时间”的思想，去降低 GC 的停顿时间。

与上述地址空间划分相对应，ZGC实际仅使用64位地址空间的第0-41位，而第42-45位存储元数据，第47-63位固定为0。

由于仅用了第 0~43 位存储对象地址，
 = 16TB，所以 ZGC 最大支持 16TB 的堆。

至于对象的存活信息，则存储在42-45位中，这与传统的垃圾回收并将对象存活信息放在对象头中完全不同。

**读屏障**

当程序尝试读取一个对象时，读屏障会触发以下操作：

* 检查指针染色：读屏障首先检查指向对象的指针的颜色信息。
* 处理移动的对象：如果指针表示对象已经被移动（例如，在垃圾回收过程中），读屏障将确保返回对象的新位置。
* 确保一致性：通过这种方式，ZGC 能够在并发移动对象时保持内存访问的一致性，从而减少对应用程序停顿的需要。


**ZGC读屏障如何实现呢？**

来看下面这段伪代码，涉及 JVM 的底层 C++ 代码：

```java
// 伪代码示例，展示读屏障的概念性实现
Object* read_barrier(Object* ref) {
    if (is_forwarded(ref)) {
        return get_forwarded_address(ref); // 获取对象的新地址
    }
    return ref; // 对象未移动，返回原始引用
}
```

* read_barrier 代表读屏障。
* 如果对象已被移动（is_forwarded(ref)），方法返回对象的新地址（get_forwarded_address(ref)）。
* 如果对象未被移动，方法返回原始的对象引用。

读屏障可能被GC线程和业务线程触发，并且只会在访问堆内对象时触发，访问的对象位于GC Roots时不会触发，这也是扫描GC Roots时需要STW的原因。

下面是一个简化的示例代码，展示了读屏障的触发时机。

```java
Object o = obj.FieldA   // 从堆中读取引用，需要加入屏障
<Load barrier>
Object p = o  // 无需加入屏障，因为不是从堆中读取引用
o.dosomething() // 无需加入屏障，因为不是从堆中读取引用
int i =  obj.FieldB  //无需加入屏障，因为不是对象引用
```
**ZGC 的工作过程**

ZGC 周期由三个 STW 暂停和四个并发阶段组成：标记/重新映射( M/R )、并发引用处理( RP )、并发转移准备( EC ) 和并发转移( RE )。


Stop-The-World 暂停阶段

* 标记开始（Mark Start）STW 暂停：这是 ZGC 的开始，进行 GC Roots 的初始标记。在这个短暂的停顿期间，ZGC 标记所有从 GC Root 直接可达的对象。

* 重新映射开始（Relocation Start）STW 暂停：在并发阶段之后，这个 STW 暂停是为了准备对象的重定位。在这个阶段，ZGC 选择将要清理的内存区域，并建立必要的数据结构以进行对象移动。

* 暂停结束（Pause End）STW 暂停：ZGC 结束。在这个短暂的停顿中，完成所有与该 GC 周期相关的最终清理工作。

并发阶段

* 并发标记/重新映射 (M/R) ：这个阶段包括并发标记和并发重新映射。在并发标记中，ZGC 遍历对象图，标记所有可达的对象。然后，在并发重新映射中，ZGC 更新指向移动对象的所有引用。

* 并发引用处理 (RP) ：在这个阶段，ZGC 处理各种引用类型（如软引用、弱引用、虚引用和幽灵引用）。这些引用的处理通常需要特殊的考虑，因为它们与对象的可达性和生命周期密切相关。

* 并发转移准备 (EC) ：这是为对象转移做准备的阶段。ZGC 确定哪些内存区域将被清理，并准备相关的数据结构。

* 并发转移 (RE) ：在这个阶段，ZGC 将存活的对象从旧位置移动到新位置。由于这一过程是并发执行的，因此应用程序可以在大多数垃圾回收工作进行时继续运行。


ZGC 的两个关键技术：**指针染色** 和 **读屏障**，不仅应用在并发转移阶段，还应用在并发标记阶段：将对象设置为已标记，传统的垃圾回收器需要进行一次内存访问，并将对象存活信息放在对象头中；而在ZGC中，只需要设置指针地址的第42-45位即可，并且因为是寄存器访问，所以速度比访问内存更快。

# 类加载与字节码技术
## 类文件结构

好的，我们来深入探讨一下 Java 虚拟机（JVM）中一个非常基础且核心的概念——**类文件结构（Class File Structure）**。

每一个 `.java` 文件经过 Java 编译器（`javac`）编译后，都会生成一个对应的 `.class` 文件。这个 `.class` 文件并不只是简单的字节码指令集合，而是一个遵循着《Java虚拟机规范》严格定义的、高度结构化的二进制文件。正是这种与平台无关的严谨结构，才使得 Java 能够实现“一次编译，到处运行”（Write Once, Run Anywhere）。

可以把 `.class` 文件想象成一份详细的“建筑蓝图”，JVM 就是根据这份蓝图来加载类、创建对象并执行代码的。

类文件是一个由 8 位字节组成的二进制流。它的内部数据项严格按照预定义的顺序排列，没有任何分隔符。整个文件结构就像一个紧凑的C语言结构体。

文件中的数据类型可以分为两类：

  * **无符号数**：以 `u1`, `u2`, `u4`, `u8` 分别代表 1、2、4、8 个字节的无符号数。它们用来表示数字、索引、数量等。
  * **表（Table）**：由多个无符号数或其他表作为数据项构成的复合结构。整个类文件本质上就是一张大表。

一个标准的类文件结构按顺序包含以下部分：

| 数据项名称 | 数据类型 | 描述 |
| :--- | :--- | :--- |
| `magic` | `u4` | 魔数，固定为 `0xCAFEBABE` |
| `minor_version` | `u2` | 次版本号 |
| `major_version` | `u2` | 主版本号 |
| `constant_pool_count` | `u2` | 常量池大小 |
| `constant_pool[]` | cp\_info | 常量池内容 |
| `access_flags` | `u2` | 类的访问标志 |
| `this_class` | `u2` | 类索引 |
| `super_class` | `u2` | 父类索引 |
| `interfaces_count` | `u2` | 接口数量 |
| `interfaces[]` | `u2` | 接口索引集合 |
| `fields_count` | `u2` | 字段数量 |
| `fields[]` | field\_info | 字段表集合 |
| `methods_count` | `u2` | 方法数量 |
| `methods[]` | method\_info | 方法表集合 |
| `attributes_count` | `u2` | 属性数量 |
| `attributes[]` | attribute\_info | 属性表集合 |

-----

**二、核心组件详解**

**1\. 魔数 (Magic Number)**

  * **作用**：每个 `.class` 文件的头 4 个字节都是 `0xCAFEBABE`。这是一个十六进制的“魔数”，用于快速地识别一个文件是否是可能被 JVM 接受的类文件。如果不是这个值，JVM 会直接拒绝加载。
  * **趣闻**：这个词是 Java 创始人 James Gosling 创造的，据说是他在一家咖啡馆时想到的，所以包含了 Cafe（咖啡）和 Babe（宝贝）的组合。

**2\. 版本号 (Version)**

  * **作用**：紧跟魔数的是次版本号和主版本号，它们共同标识了该类文件的编译器版本。JVM 会拒绝加载版本号高于自身的类文件，但可以兼容执行版本号较低的类文件。

**3\. 常量池 (Constant Pool)**

  * **作用**：这是类文件结构中**最核心、最庞大的数据项目**。可以把它理解为这个类的“资源仓库”或“符号表”。
  * **内容**：它存储了两大类常量：
    1.  **字面量 (Literals)**：如文本字符串（`"Hello, World!"`）、`final` 常量值（`final int a = 10;`）等。
    2.  **符号引用 (Symbolic References)**：这是它的主要部分，包含了对类、接口、字段和方法的描述信息。例如：
          * 类的全限定名 (`java/lang/Object`)
          * 字段的名称和描述符 (`name`, `Ljava/lang/String;`)
          * 方法的名称和描述符 (`main`, `([Ljava/lang/String;)V`)
  * **意义**：在加载时，JVM 通过这些符号引用来找到对应的实际内存地址（这个过程叫**动态链接**），从而将各个类联系起来。

**4\. 访问标志 (Access Flags)**

  * **作用**：这是一个 2 字节的位掩码，用于表示这个类或接口的访问权限和属性，比如 `ACC_PUBLIC` (是否为 public)、`ACC_FINAL` (是否为 final)、`ACC_INTERFACE` (是否为接口)、`ACC_ABSTRACT` (是否为抽象类) 等。

**5\. 类、父类和接口索引**

  * **作用**：这三项分别指向常量池中的一个 `CONSTANT_Class_info` 常量，通过这个索引可以找到本类、父类和所实现接口的全限定名。

**6\. 字段表 (Fields Table)**

  * **作用**：描述类中声明的所有字段（成员变量），包括静态变量和实例变量。
  * **内容**：每个字段的信息包括：访问标志（public, private, static, final 等）、字段名索引、字段描述符索引（例如 `I` 代表 `int`，`Ljava/lang/String;` 代表 `String` 类型）以及可能的属性（如 `ConstantValue` 属性用于 final 静态变量）。

**7\. 方法表 (Methods Table)**

  * **作用**：描述类中声明的所有方法。
  * **内容**：每个方法的信息包括：访问标志（public, static, synchronized 等）、方法名索引、方法描述符索引（例如 `()V` 代表无参无返回值的构造函数）以及属性表。
  * **核心中的核心——`Code` 属性**：如果一个方法不是抽象的或本地的，那么它的属性表中必定有一个\*\*`Code` 属性\*\*。`Code` 属性里存放了该方法的**Java 字节码指令**、操作数栈的最大深度、局部变量表的大小等执行代码所需的一切信息。

**8\. 属性表 (Attributes Table)**

  * **作用**：这是最具扩展性的部分，用于描述类、字段或方法的一些额外信息。JVM 规范预定义了很多属性，同时也允许编译器厂商自定义属性。
  * **常见属性**：
      * `Code`: 存放方法的字节码。
      * `SourceFile`: 记录生成此 class 文件的源文件名（如 `MyClass.java`），用于异常堆栈的显示。
      * `LineNumberTable`: 建立字节码行号与 Java 源码行号的对应关系，是调试器和异常堆栈定位的关键。
      * `Exceptions`: 列出方法声明中 `throws` 的所有受查异常。

-----

**三、如何查看类文件结构？**

我们不需要用十六进制编辑器去手动分析。JDK 提供了一个强大的工具——**`javap`**（Java Class File Disassembler）。

假设有这样一个简单的类：

```java
public class Test {
    public void sayHello() {
        System.out.println("Hello, JVM!");
    }
}
```

编译后，在命令行中执行 `javap -v Test.class`，你将看到一个非常详细的、格式化的类文件结构报告，它会清晰地展示出魔数、版本、常量池、方法表、Code属性中的字节码等所有我们上面提到的内容。这是学习和理解类文件结构最直观的方式。

## 多态原理
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-27.png)

## catch
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-28.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-29.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-30.png)
## 类加载
### 加载
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-31.png)
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-32.png)
### 连接
* 验证
* 准备
	* 为静态变量分配空间，分配空间在准备阶段完成，赋值在初始化阶段完成
		* 如果 static 变量是 final 的基本类型，以及字符串常量，那么编译阶段值就确定了，赋值在准备阶段完成 
		* 如果 static 变量是 fina l的，但属于引用类型，那么赋值也会在初始化阶段完成
* 解析
	* 将常量池中的符号引用解析为直接引用 

### 初始化
初始化即调用\<cint>()v, 虚拟机会保证这个类的『构造方法』的线程安全
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-33.png)
懒加载
```java
public class Singleton {
    
    private Singleton(){}

    public static class LazyHolder {
        private static final Singleton INSTANCE = new Singleton();
        static {
            System.out.println("已被实例化");
        }
    }

    public static Singleton getInstance() {
        return LazyHolder.INSTANCE;
    }
}
```
## 类加载器
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-34.png)
双亲委派


### 线程上下文类加载器

1、我来总结下，在 jre/lib 包下有一个 DriverManager，是启动类加载的，但是jdbc的驱动是各个厂商来实现的不在启动类加载路径下，启动类无法加载，而驱动管理需要用到这些驱动
2、只能打破双亲委派，启动类直接请求系统类加载器去classpath下加载驱动（正常是向上委托，这个反过来了），而打破双亲委派的就是这个线程上下文类加载器
3、过程就是：启动类加载器加载 DriverManager，DriverManager 代码里调用了线程上下文类加载器，这个加载器默认就是使用应用程序类加载器加载类，通过应用程序类加载器加载 jdbc驱动

### 自定义类加载器
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgJVM%20%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93-35.png)




























































