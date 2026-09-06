---
title: HashMap学习总结——JDK17
categories:
  - 编程语言
  - Java
tags:
  - Java
  - HashMap
  - JDK17
date: 2025-03-22 17:14:25
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgHashMap%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93%E2%80%94%E2%80%94JDK17-01.png
---
# HashMap构造方法

## HashMap(int initialCapacity, float loadFactor)

### loadFactor 加载因子
* **loadFactor** 是加载因子，默认是0.75，当 **实际节点数** / **总容量** 超过 **loadFactor** 会触发扩容机制

### initialCapacity 初始容量
HashMap内部的 **Node<K, V>** 数组的大小总为2的n次方，这个与求 **hash** 有关，会在  **put()**  方法内讨论，因此在构造方法内部，**threshold** 只能为比 **initialCapacity** 大的2的n次方
* **threshold**代表着哈希表进行扩容操作的阈值，当数组的实际容量超过 **threshold**， 会触发扩容机制，但在构造方法中，**threshold** 大小为HashMap的初始大小，其值会在第一次 **put()** 改变


#### tableSizeFor(int cap) 计算前导零
这个方法会将 **initialCapacity** 扩大到比 **initialCapacity** 大的2的n次方
```java
	//计算前导零
    public static int numberOfLeadingZeros(int i) {
        // HD, Count leading 0's
        if (i <= 0)
            return i == 0 ? 32 : 0;
        int n = 31;
        if (i >= 1 << 16) { n -= 16; i >>>= 16; }
        if (i >= 1 <<  8) { n -=  8; i >>>=  8; }
        if (i >= 1 <<  4) { n -=  4; i >>>=  4; }
        if (i >= 1 <<  2) { n -=  2; i >>>=  2; }
        return n - (i >>> 1);
    }
```
例如 18 的二进制为 `0000 0000 0000 0000 0000 0000 0001 0010` ，其前导零为27

```java
    static final int tableSizeFor(int cap) {
        int n = -1 >>> Integer.numberOfLeadingZeros(cap - 1);
        return (n < 0) ? 1 : (n >= MAXIMUM_CAPACITY) ? MAXIMUM_CAPACITY : n + 1;
    }
```
先把传入的容量 cap 减 1，这是为了处理 cap 本身就是 2 的幂次方的情况。要是 cap 已经是 2 的幂次方，减 1 之后就可以确保最终结果还是 cap 本身。
-1 在的二进制为 `1111 1111 1111 1111 1111 1111 1111 1111` ，-1 向右移动 **Integer.numberOfLeadingZeros(cap - 1)** 位，会出现从左边1开始到末尾全为1的情况，最后返回值再加上1，会变成2的n次方
**例如：**
```
0000 0000 0000 0000 0000 0000 0001 1111 + 1 --> 0000 0000 0000 0000 0000 0000 0010 0000 变成32
```
## HashMap(Map<? extends K, ? extends V> m)
**HashMap(Map<? extends K, ? extends V> m)** 会调用 **putMapEntries(Map<? extends K, ? extends V> m, boolean evict)** 方法。用 **map** 数组初始化HashMap，会先计算 **map** 数组的大小 **s** ，然后计算hash总容量应该为多少 ==float ft = ((float)s / loadFactor) + 1.0F;== ，再然后判断 **ft** 是否超出最大容量，如果是则将 **ft** 赋值为最大容量，最后遍历 **map** 数组将其存入 **hash** 中。
```java
    public HashMap(Map<? extends K, ? extends V> m) {
        this.loadFactor = DEFAULT_LOAD_FACTOR;
        putMapEntries(m, false);
    }

    final void putMapEntries(Map<? extends K, ? extends V> m, boolean evict) {
        int s = m.size();
        if (s > 0) {
            if (table == null) { // pre-size
                float ft = ((float)s / loadFactor) + 1.0F; //减少扩容的概率 比如说 s / loadFactor = 8，加一后变成9，在tableSizeFor方法中，threshold会变成16
                int t = ((ft < (float)MAXIMUM_CAPACITY) ?
                         (int)ft : MAXIMUM_CAPACITY);
                if (t > threshold)
                    threshold = tableSizeFor(t);
            } else {
                // Because of linked-list bucket constraints, we cannot
                // expand all at once, but can reduce total resize
                // effort by repeated doubling now vs later
                while (s > threshold && table.length < MAXIMUM_CAPACITY)
                    resize();
            }

            for (Entry<? extends K, ? extends V> e : m.entrySet()) {
                K key = e.getKey();
                V value = e.getValue();
                putVal(hash(key), key, value, false, evict);
            }
        }
    }
```

# put(K key, V value) 
## hash(Object key) 	求hash值
```java
    static final int hash(Object key) {
        int h;
        return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
    }

	putVal(hash(key), key, value, false, evict);
	
    final V putVal(int hash, K key, V value, boolean onlyIfAbsent, boolean evict) {
        Node<K,V>[] tab; Node<K,V> p; int n, i;
	    。。。。。。
        if ((p = tab[i = (n - 1) & hash]) == null)
            tab[i] = newNode(hash, key, value, null);
        。。。。。。
    }
```
将h右移16位，目的是h的高位也能参与到后续的桶索引计算中，进而减少哈希冲突的可能性
如果 **n** 是2的n次方，那么 ==(n - 1) & hash =\= n & hash== ，相当于求余，提升效率
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgHashMap%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93%E2%80%94%E2%80%94JDK17-01.png#pic_center)
## putVal(int hash, K key, V value, boolean onlyIfAbsent, boolean evict) 插入或更新
1. 在第一次插入数据时，会初始化table数组
```java
        if ((tab = table) == null || (n = tab.length) == 0)
            n = (tab = resize()).length;
```
2. 然后计算索引并查看索引所在的位置是否有元素
```java
						// 因为tab的大小为2的n次方，所有(n - 1) & hash == n % hash
        if ((p = tab[i = (n - 1) & hash]) == null)
            tab[i] = newNode(hash, key, value, null);
```
**情况1：** 原位置的key等于插入的key，将原数据 **p** 赋值给 **e**
```java
			//既考虑了引用相等的情况，又考虑了内容相等的情况
            if (p.hash == hash && ((k = p.key) == key || (key != null && key.equals(k))))
                e = p;
```

**情况2：** 要插入的位置是红黑树
```java
            else if (p instanceof TreeNode)
                e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
```
**情况3：** 要插入的位置是 **链表**
```java
               for (int binCount = 0; ; ++binCount) {
               		//先将 p.next 赋值给 e，如果e为空则表示要插入的位置是链表末尾，如果e不为空，继续遍历
                    if ((e = p.next) == null) {
                        p.next = newNode(hash, key, value, null);
						// 检测是否需要转换为红黑树
                        if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                            treeifyBin(tab, hash);
                        break;
                    }
                    // 找到原数据的 key 与要插入的 key 相等，终止遍历
                    if (e.hash == hash &&
                        ((k = e.key) == key || (key != null && key.equals(k))))
                        break;
                    p = e;
                }
```

**元素e的情况：**
元素 **e** 不为空说明要更新数据，而不是要插入数据
```java
            if (e != null) { // existing mapping for key
                V oldValue = e.value;
                if (!onlyIfAbsent || oldValue == null)
                    e.value = value;
                afterNodeAccess(e);
                return oldValue;
            }
```

**最后：**
操作数加一，并检查是否需要扩容
```java
        ++modCount;
        if (++size > threshold)
            resize();
        afterNodeInsertion(evict);
        return null;
```

## resize() 扩容
因为每次扩容都是翻倍，与原来计算的 (n-1)&hash的结果相比，只是多了一个bit位，所以节点要么就在原来的位置，要么就被分配到"**原位置+旧容量**"这个位置
例如我们从16扩展为32时
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgHashMap%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93%E2%80%94%E2%80%94JDK17-02.png#pic_center)
因此元素在重新计算hash之后，因为n变为2倍，那么n-1的标记范围在高位多1bit(红色)，因此新的index就会发生这样的变化：
![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgHashMap%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93%E2%80%94%E2%80%94JDK17-03.png#pic_center)
说明：5是假设计算出来的原来的索引。这样就验证了上述所描述的：扩容之后所以节点要么就在原来的位置，要么就被分配到"**原位置+旧容量**"这个位置。

 因此，我们在扩充HashMap的时候，不需要重新计算hash，只需要看看原来的hash值新增的那个bit是1还是0就可以了，是0的话索引没变，是1的话索引变成“原索引+oldCap(**原位置+旧容量**)”。可以看看下图为16扩充为32的resize示意图：
 ![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imgHashMap%E5%AD%A6%E4%B9%A0%E6%80%BB%E7%BB%93%E2%80%94%E2%80%94JDK17-04.png#pic_center)

**第一次扩容的代码逻辑：**
```java
    final Node<K,V>[] resize() {
    	//获取原 table 数组
        Node<K,V>[] oldTab = table;
        //计算原数组的最大容量 
        int oldCap = (oldTab == null) ? 0 : oldTab.length;
        //获取原数组的阈值
        int oldThr = threshold;
        int newCap, newThr = 0;
        //最开始的容量为16
        newCap = DEFAULT_INITIAL_CAPACITY;
        //最开始的阈值为12
        newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
        //赋值为12
        threshold = newThr;
        //创建新数组
        @SuppressWarnings({"rawtypes","unchecked"})
        Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
        table = newTab;
		//返回
        return newTab;
    }
```

**正常扩容逻辑：**
```java
        Node<K,V>[] oldTab = table;
        int oldCap = (oldTab == null) ? 0 : oldTab.length;
        int oldThr = threshold;
        int newCap, newThr = 0;
        //扩容到原来的2倍 16 --> 32
		newCap = oldCap << 1;
		//阈值扩容到原来的2倍 12 --> 24
		newThr = oldThr << 1; // double threshold
		threshold = newThr;
		//创建新的Node数组
        @SuppressWarnings({"rawtypes","unchecked"})
        Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
        table = newTab;
        //遍历原来所有的节点
        for (int j = 0; j < oldCap; ++j) {
            Node<K,V> e;
            ///将原节点赋值给e
            if ((e = oldTab[j]) != null) {
            	//置为null 便于垃圾回收
                oldTab[j] = null;
                if (e.next == null)
                	//说明只有单个节点，直接插入新数组
                    newTab[e.hash & (newCap - 1)] = e;
                else if (e instanceof TreeNode)
                	//红黑树，我不会
                    ((TreeNode<K,V>)e).split(this, newTab, j, oldCap);
                else { 
					// 定义低位链表的头节点和尾节点，初始化为 null
					Node<K,V> loHead = null, loTail = null;
					// 定义高位链表的头节点和尾节点，初始化为 null
					Node<K,V> hiHead = null, hiTail = null;
					// 用于临时存储当前节点的下一个节点
					Node<K,V> next;
					// 开始遍历链表
					do {
					    // 保存当前节点的下一个节点
					    next = e.next;
					    // 判断当前节点的哈希值与原容量进行按位与运算的结果是否为 0
					    if ((e.hash & oldCap) == 0) {
					        // 如果低位链表的尾节点为 null，说明链表为空，将当前节点设为低位链表的头节点
					        if (loTail == null)
					            loHead = e;
					        else
					            // 否则，将当前节点添加到低位链表的尾部
					            loTail.next = e;
					        // 更新低位链表的尾节点为当前节点
					        loTail = e;
					    }
					    else {
					        // 如果高位链表的尾节点为 null，说明链表为空，将当前节点设为高位链表的头节点
					        if (hiTail == null)
					            hiHead = e;
					        else
					            // 否则，将当前节点添加到高位链表的尾部
					            hiTail.next = e;
					        // 更新高位链表的尾节点为当前节点
					        hiTail = e;
					    }
					// 继续遍历链表，直到当前节点为 null
					} while ((e = next) != null);
					// 如果低位链表的尾节点不为 null，说明低位链表有节点
					if (loTail != null) {
					    // 将低位链表的尾节点的 next 指针置为 null，截断链表
					    loTail.next = null;
					    // 将低位链表的头节点插入到新哈希表的原索引位置
					    newTab[j] = loHead;
					}
					// 如果高位链表的尾节点不为 null，说明高位链表有节点
					if (hiTail != null) {
					    // 将高位链表的尾节点的 next 指针置为 null，截断链表
					    hiTail.next = null;
					    // 将高位链表的头节点插入到新哈希表的原索引加上原容量的位置
					    newTab[j + oldCap] = hiHead;
					}
                }
            }
        }
```


