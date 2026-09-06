---
title: NIO学习总结
categories:
  - 编程语言
  - Java
tags:
  - Java
  - NIO
date: 2025-01-01 10:31:33
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost04-01.png
---
# ByteBuffer
## 基本使用
```java
        try(FileChannel fileChannel = new FileInputStream("data/data.txt").getChannel()) {
            ByteBuffer buffer = ByteBuffer.allocate(10); //创建一个容量为 10 字节的缓冲区 ByteBuffer
            while (true) {
                buffer.clear();
                int read = fileChannel.read(buffer);
                if (read == -1) {
                    break;
                }
                buffer.flip(); //切换到“读模式”
                while (buffer.hasRemaining()) {
                    log.info("{}", (char) buffer.get());
                }
            }
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
```
### 开辟缓冲区
```java
        System.out.println(ByteBuffer.allocate(16));
        System.out.println(ByteBuffer.allocateDirect(16));
        /*
               class java.nio.HeapByteBuffer-jaVa堆内存，读写效率较低，受到GC的影响
               class java.ni0.DirectByteBuffer-直接内存，读写效率高（少一次拷贝），不会受GC影响，分配的效率间，可能会造成内存泄露
         */
    }
```
### 读写
```java
        ByteBuffer buffer = ByteBuffer.allocate(10);
        buffer.put(new byte[]{0x61, 0x62, 0x63, 0x64});
        buffer.flip();
        buffer.get(new byte[4]);
        ByteBufferUtil.debugAll(buffer);
        buffer.rewind();
        ByteBufferUtil.debugAll(buffer);

        buffer.mark();
        System.out.println((char) buffer.get());
        System.out.println((char) buffer.get());
        buffer.reset();
        System.out.println((char) buffer.get());
        System.out.println((char) buffer.get());
```
### 字符串转ByteBuffer
```java
        //1.字符串转为ByteBuffer
        String str = "你好，world";
        ByteBuffer bufferStr = ByteBuffer.allocate(32);
        bufferStr.put(str.getBytes());
        ByteBufferUtil.debugAll(bufferStr);

        //2.Charset
        ByteBuffer bufferCharset = StandardCharsets.UTF_8.encode("你好，world");
        ByteBufferUtil.debugAll(bufferCharset);

        //warp
        ByteBuffer bufferWarp = ByteBuffer.wrap("你好，world".getBytes());
        ByteBufferUtil.debugAll(bufferWarp);

        //ByteBuffer转为字符串
        String str1 = StandardCharsets.UTF_8.decode(bufferCharset).toString();
        System.out.println(str1);
```
### Gathering
将一个文件里的内容，写入多个buffer中
```java
        ByteBuffer buffer1 = ByteBuffer.wrap("Hello".getBytes());
        ByteBuffer buffer2 = ByteBuffer.wrap("World ".getBytes());
        ByteBuffer buffer3 = ByteBuffer.wrap("你好".getBytes());
        try (FileChannel channel = new RandomAccessFile("data/words.txt", "rw").getChannel()) {

            channel.write(new ByteBuffer[]{buffer1, buffer2, buffer3});

        } catch (IOException e) {
            e.printStackTrace();
        }
```
### Scattering
将多个buffer写入同一个文件中
```java
        try (FileChannel channel = new RandomAccessFile("data/part3.txt", "r").getChannel()) {

            ByteBuffer buffer1 = ByteBuffer.allocate(3);
            ByteBuffer buffer2 = ByteBuffer.allocate(3);
            ByteBuffer buffer3 = ByteBuffer.allocate(5);
            channel.read(new ByteBuffer[]{buffer1, buffer2, buffer3});
            buffer1.flip();
            buffer2.flip();
            buffer3.flip();
        } catch (IOException e) {
            e.printStackTrace();
        }
```
## ByteBuffer运行过程
调用allocate()方法后，相当于在堆内存中创建一个存放数据的数组，有三个指针
* 写模式下，position 是写入位置，limit 等于容量
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost04-01.png)
下图为向buffer写入数据
![](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost04-02.png)
调用flip()方法后Limit = Position，Position = 0
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost04-03.png)

可以调用get()读取数据，并将Position加一
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost04-04.png)
compact()方法是将未读取的数据前移，并将Limit赋值给Position，然后将Capacity赋值给Limit 
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost04-05.png)

# Nio
## 阻塞与非阻塞
### 阻塞
阻塞是指一个线程在等待一个请求，如果请求没有发过来，那么线程会一直等待
```java
        ByteBuffer buffer = ByteBuffer.allocate(1024);
        ServerSocketChannel ssc = ServerSocketChannel.open(); //创建服务器
        ssc.bind(new InetSocketAddress(8098)); //监听端口
        List<SocketChannel> channels = Lists.newArrayList();
        while (true){
            SocketChannel channel = ssc.accept(); //阻塞方法, 线程停止运行
            if (channel != null){
                channels.add(channel);
            }
            for (SocketChannel socketChannel : channels) {
                int read = socketChannel.read(buffer);//阻塞方法， 线程停止运行
                if (read > 0) {
                    buffer.flip();
                    ByteBufferUtil.debugRead(buffer);
                    buffer.clear();
                }

            }
        }
```
* accept() 方法是一个阻塞操作，当没有客户端连接时，服务端线程会一直等待连接，线程停止运行，假如此时客户端发送数据，服务器也接收不到，因为服务端程序停止在**SocketChannel channel = ssc.accept()**，等待连接
* 同理socketChannel.read()也是阻塞方法，如果接收不到数据会一直阻塞，程序停止运行。

### 非阻塞
```java
        ByteBuffer buffer = ByteBuffer.allocate(1024);
        ServerSocketChannel ssc = ServerSocketChannel.open(); //创建服务器
        ssc.bind(new InetSocketAddress(8098)); //监听端口
        ssc.configureBlocking(false); //非阻塞模式
        List<SocketChannel> channels = Lists.newArrayList();
        while (true){
            SocketChannel channel = ssc.accept(); //阻塞方法, 线程停止运行 => 非阻塞模式
            if (channel != null){
                channels.add(channel);
                channel.configureBlocking(false); //切换到非阻塞模式
            }
            for (SocketChannel socketChannel : channels) {
                int read = socketChannel.read(buffer);//阻塞方法， 线程停止运行 => 非阻塞模式
                if (read > 0) {
                    buffer.flip();
                    ByteBufferUtil.debugRead(buffer);
                    buffer.clear();
                }

            }
        }
```
* ServerSocketChannel切换到非阻塞模式，接收不到客户端连接，返回null，程序继续运行
* SocketChannel切换到非阻塞模式，接收不到数据，返回0，程序继续运行
<font color='red'>但此时while会一直运行，造成性能损失</font>

## 事件触发
**Selector**是线程与Channel的桥梁，以往线程每次只能处理一个Channel，要么处理连接事件，要么处理可读事件。
而引入Selector后，可以将Channel注册在Selector上（相当于Channel添加到Selector这个集合中），每个由这个Channel所触发的事件，会放在SelectionKey中，然后由selector.select()进行阻塞，一旦有事件发生，就会处理。
### 读事件
```java
    public static void main(String[] args) throws IOException {
//        ByteBuffer buffer = ByteBuffer.allocate(1024);
        Selector selector = Selector.open();
        ServerSocketChannel ssc = ServerSocketChannel.open(); //创建服务器
        ssc.configureBlocking(false);
        //SelectionKey就是将来事件发生后，通过它可以知道事件和哪个channel的事件
        SelectionKey sscKey = ssc.register(selector, 0, null);
        sscKey.interestOps(SelectionKey.OP_ACCEPT);
        log.debug(sscKey.toString());
        ssc.bind(new InetSocketAddress(8098)); //监听端口

        while (true){
            selector.select();
            Iterator<SelectionKey> iter = selector.selectedKeys().iterator();
            while (iter.hasNext()){
                SelectionKey key = iter.next();
                iter.remove(); //处理key时，要从selectedKeys集合中别除，否则下次处理就会有问题
                if (key.isAcceptable()){
                    ServerSocketChannel server = (ServerSocketChannel) key.channel();
                    SocketChannel sc = server.accept();
                    sc.configureBlocking(false);
                    ByteBuffer buffer = ByteBuffer.allocate(16); //附件
                    //将一个byteBuffer作为附件关联到selectionKey上
                    SelectionKey scKey = sc.register(selector, 0, buffer);
                    scKey.interestOps(SelectionKey.OP_READ);
                    log.debug(sc.toString());
                } else if (key.isReadable()){
                    try {
                        SocketChannel sc = (SocketChannel) key.channel();
                        ByteBuffer buffer = (ByteBuffer)key.attachment();
                        int read = sc.read(buffer); //如果是正常断开，read的方法的返回值是-1
                        if (read == -1) {
                            key.cancel();
                        } else {
                            split(buffer);
                            if (buffer.position() == buffer.limit()) {
                                buffer.flip();
                                ByteBuffer newBuffer = ByteBuffer.allocate(buffer.capacity() * 2); //扩容
                                newBuffer.put(buffer);
                                key.attach(newBuffer);
                            }
                        }
                    } catch (IOException e) {
                        key.cancel(); //因为客户端断开了，因此需要将key取消（从selector的keys集合中真正别除key)
                    }
                }
            }
        }
    }

    private static void split(ByteBuffer source) {
        source.flip();
        for (int i = 0; i < source.limit(); i++) {
            if (source.get(i) == '\n') {
                int length = i + 1 - source.position();
                ByteBuffer target = ByteBuffer.allocate(length);

                for (int j = 0; j < length; j++) {
                    target.put(source.get());
                }
                ByteBufferUtil.debugAll(target);
            }
        }

        source.compact();
    }
```
在这段代码中，先将服务器的channel注册在selector中，并对accept做出反应
```java
        Selector selector = Selector.open();
        ServerSocketChannel ssc = ServerSocketChannel.open(); //创建服务器
        ssc.configureBlocking(false);
        //SelectionKey就是将来事件发生后，通过它可以知道事件和哪个channel的事件
        SelectionKey sscKey = ssc.register(selector, 0, null);
        sscKey.interestOps(SelectionKey.OP_ACCEPT);
        log.debug(sscKey.toString());
        ssc.bind(new InetSocketAddress(8098)); //监听端口
```
一旦客户端连接服务器，**selector.select();**就会触发，将事件添加到SelectionKey中，<font color='red'>但注意，处理事件后要将该事件移除，否则会造成空指针异常，iter.remove()</font>
```java
                if (key.isAcceptable()){
                    ServerSocketChannel server = (ServerSocketChannel) key.channel();
                    SocketChannel sc = server.accept();
                    sc.configureBlocking(false);
                    ByteBuffer buffer = ByteBuffer.allocate(16); //附件
                    //将一个byteBuffer作为附件关联到selectionKey上
                    SelectionKey scKey = sc.register(selector, 0, buffer);
                    scKey.interestOps(SelectionKey.OP_READ);
                    log.debug(sc.toString());
                } 
```
这段代码处理accept事件，并将客户端的channel注册在selector上，对可读事件进行反应，下次客户端发来数据，该channel会触发可读事件并添加到SelectionKey中，等待处理
```java
else if (key.isReadable()){
                    try {
                        SocketChannel sc = (SocketChannel) key.channel();
                        ByteBuffer buffer = (ByteBuffer)key.attachment();
                        int read = sc.read(buffer); //如果是正常断开，read的方法的返回值是-1
                        if (read == -1) {
                            key.cancel();
                        } else {
                            split(buffer);
                            if (buffer.position() == buffer.limit()) {
                                buffer.flip();
                                ByteBuffer newBuffer = ByteBuffer.allocate(buffer.capacity() * 2); //扩容
                                newBuffer.put(buffer);
                                key.attach(newBuffer);
                            }
                        }
                    } catch (IOException e) {
                        key.cancel(); //因为客户端断开了，因此需要将key取消（从selector的keys集合中真正别除key)
                    }
                }
```
可读事件触发的原理是，nio内部有一个可读缓冲区，如果该缓冲区还有数据就会触发可读事件，由此可以处理消息超过可读范围的问题。
用一个'\n'换行符表示一端内容的结束，如果发现**buffer.position() == buffer.limit()**，说明内容超出buffer的容量，需要扩容。扩容结束后，因为可读缓存区还有内容，会接着触发可读事件，并将内容写入扩容后的buffer，直到完整读到一段内容

### 写事件
```java
    public static void main(String[] args) throws IOException {
        ServerSocketChannel ssc = ServerSocketChannel.open();
        ssc.configureBlocking(false);

        Selector selector = Selector.open();
        ssc.register(selector, SelectionKey.OP_ACCEPT, null);

        ssc.bind(new InetSocketAddress(8084));
        while (true) {
            selector.select();
            Iterator<SelectionKey> iterator = selector.selectedKeys().iterator();

            while (iterator.hasNext()) {
                SelectionKey key = iterator.next();
                iterator.remove();

                if (key.isAcceptable()) {
                    SocketChannel sc = ssc.accept();
                    sc.configureBlocking(false);
                    SelectionKey scKey = sc.register(selector, SelectionKey.OP_READ, null);
                    StringBuilder sb = new StringBuilder();
                    for (int i = 0; i < 3000000; i++) {
                        sb.append("a");
                    }
                    ByteBuffer buffer = Charset.defaultCharset().encode(sb.toString());
                    if (buffer.hasRemaining()) {
                        //可写事件
                        //写事件（OP_WRITE）的触发条件是通道的写缓冲区有空闲空间,SocketChannel分别有独立的读缓冲区和写缓冲区
                        scKey.interestOps(scKey.interestOps() + SelectionKey.OP_WRITE);
                        scKey.attach(buffer);
                    }
                } else if (key.isWritable()) {
                    SocketChannel sc = (SocketChannel) key.channel();
                    ByteBuffer buffer = (ByteBuffer) key.attachment();
                    sc.write(buffer);
                    if (!buffer.hasRemaining()) {
                        key.attach(null);
                        key.interestOps(key.interestOps() - SelectionKey.OP_WRITE);
                    }
                }
            }
        }

    }
```
可写事件与可读事件差不多，nio内部有一个**可写缓冲区**，如果该缓冲区不为空，会触发可写事件，继续发送数据，直到数据发送完毕。

## 多线程
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgpost04-06.png)
现在的cpu都是多核，可以一个线程（boss）专门处理accept事件，一个线程（worker）专门处理可读事件。
在boos线程中发生accept事件后，将对应的SocketChannel传递到worker中，在其内部注册在selector中
```java
public class MultiThreadServer {

    public static void main(String[] args) throws IOException {
        ServerSocketChannel ssc = ServerSocketChannel.open();
        ssc.configureBlocking(false);
        Selector boss = Selector.open();
        SelectionKey sscKey = ssc.register(boss, 0, null);
        sscKey.interestOps(SelectionKey.OP_ACCEPT);
        Thread.currentThread().setName("boss");
        ssc.bind(new InetSocketAddress(9999));
        Worker[] workers = new Worker[2];
        for (int i = 0; i < workers.length; i++) {
            workers[i] = new Worker("worker-" + i);
        }
        AtomicInteger index = new AtomicInteger(0);
        while (true) {
            boss.select();
            Iterator<SelectionKey> iterator = boss.selectedKeys().iterator();
            while (iterator.hasNext()) {
                SelectionKey key = iterator.next();
                iterator.remove();
                if (key.isAcceptable()) {
                    ServerSocketChannel server = (ServerSocketChannel) key.channel();
                    SocketChannel sc = server.accept();
                    sc.configureBlocking(false);
                    workers[index.getAndIncrement() % workers.length].register(sc);
                    log.debug("关联后。。。{}", sc.getLocalAddress());
                }
            }
        }

    }

    static class  Worker implements Runnable {

        private Selector selector;
        private Thread thread;
        private String name;
        private ConcurrentLinkedQueue<Runnable> queue = new ConcurrentLinkedQueue<>();
        private volatile boolean flag = true;
        public Worker(String name) {
            this.name = name;
        }

        public void register(SocketChannel sc) throws IOException {
            if (flag) {
                thread = new Thread(this, name);
                selector = Selector.open();
                thread.start();
                flag = false;
            }
            //向队列添加任务，但没有立即执行
            queue.add(() -> {
                try {
                    sc.register(this.selector, SelectionKey.OP_READ);
                } catch (ClosedChannelException e) {
                    throw new RuntimeException(e);
                }
            });
            //唤醒selector
            selector.wakeup();
        }

        @Override
        public void run() {
            while (true) {
                try {
                    selector.select();
                    Runnable task = queue.poll();
                    if (task != null) {
                        task.run();
                    }
                    Iterator<SelectionKey> iter = selector.selectedKeys().iterator();
                    while (iter.hasNext()) {
                        SelectionKey key = iter.next();
                        iter.remove();

                        if (key.isReadable()) {
                            SocketChannel sc = (SocketChannel) key.channel();
                            log.debug("读后。。。{}", sc.getLocalAddress());
                            ByteBuffer buffer = ByteBuffer.allocate(1024);
                            sc.read(buffer);
                            buffer.flip();
                            ByteBufferUtil.debugRead(buffer);
                        }
                    }
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
            }
        }
    }
}
```


