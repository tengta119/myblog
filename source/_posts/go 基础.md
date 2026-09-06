---
title: go 基础
categories:
  - 编程语言
  - Go
tags:
  - Go
date: 2025-10-03 16:01:51
description:
cover: https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imggo%20%E5%9F%BA%E7%A1%80-01.png
---
>没什么营养，单纯记录一下
## 基础

### 包、变量与函数

每个 Go 程序都由包构成。

程序从 `main` 包开始运行。

本程序通过导入路径 `"fmt"` 和 `"math/rand"` 来使用这两个包。

按照约定，包名与导入路径的最后一个元素一致。例如，`"math/rand"` 包中的源码均以 `package rand` 语句开始

![在这里插入图片描述](https://map-bed-lbwxxc.oss-cn-beijing.aliyuncs.com/imggo%20%E5%9F%BA%E7%A1%80-01.png)
```go
package main  
  
import (  
    "Math/rand"  
    "fmt")  
  
func main() {  
    fmt.Println(rand.Intn(100))  
}
```

```go
import (  
    "fmt"  
    "math")  
  
func main() {  
    fmt.Println(math.Sqrt(2))  
}
```

在 Go 中，如果一个名字以大写字母开头，那么它就是已导出的。例如，`Pizza` 就是个已导出名，`Pi` 也同样，它导出自 `math` 包。

`pizza` 和 `pi` 并未以大写字母开头，所以它们是未导出的。

在导入一个包时，你只能引用其中已导出的名字。 任何「未导出」的名字在该包外均无法访问。

执行代码，观察错误信息。

要修复错误，请将 `math.pi` 改名为 `math.Pi`，然后再试着执行一次。

```go
package main  
  
import (  
    "fmt"  
    "math")  
  
func main() {  
    fmt.Println(math.pi)  
}
```

```
# study
.\main.go:9:19: undefined: math.pi (but have Pi)
```

```go
package main  
  
import (  
    "fmt"  
)  
  
func add(x int, y int) int {  
    return x + y  
}  
  
func main() {  
    fmt.Println(add(1, 2))  
}
```

函数可接受零个或多个参数。

在本例中，`add` 接受两个 `int` 类型的参数。

注意类型在变量名的 **后面**。

```go
func swap(x string, y string) (string, string) {  
    return y, x  
}  
  
func main() {  
    x, y := swap("hello", "world")  
    fmt.Println(x, y)  
}
```

函数可以返回任意数量的返回值。

`swap` 函数返回了两个字符串。

```go
func split(sum int) (x int, y int) {  
    x = sum * 4 / 9  
    y = sum - x  
    return  
}  
  
func main() {  
    fmt.Println(split(17))  
}
```

Go 的返回值可被命名，它们会被视作定义在函数顶部的变量。

返回值的命名应当能反应其含义，它可以作为文档使用。

没有参数的 `return` 语句会直接返回已命名的返回值，也就是「裸」返回值。

裸返回语句应当仅用在下面这样的短函数中。在长的函数中它们会影响代码的可读性。

```go
var c, python, java bool  
  
func main() {  
    var i int  
    fmt.Println(i, c, python, java)  
}
```

`var` 语句用于声明一系列变量。和函数的参数列表一样，类型在最后。

如例中所示，`var` 语句可以出现在包或函数的层级。

```go
var i, j = 1, 2  
  
func main() {  
    var c, python, java = true, false, "no!"  
    fmt.Println(i, c, python, java)  
}
```

变量声明可以包含初始值，每个变量对应一个。

如果提供了初始值，则类型可以省略；变量会从初始值中推断出类型。

```go
func main() {  
    var i, j = 1, 2  
    k := 3  
    var c, python, java = true, false, "no!"  
    fmt.Println(i, j, k, c, python, java)  
}
```

在函数中，短赋值语句 `:=` 可在隐式确定类型的 `var` 声明中使用。

函数外的每个语句都 **必须** 以关键字开始（`var`、`func` 等），因此 `:=` 结构不能在函数外使用。

| 特性       | `var i = 1`           | `k := 3`        |
| -------- | --------------------- | --------------- |
| **作用域**  | 函数内和包级别（全局）           | **只能**在函数内部     |
| **类型声明** | 可以显式指定，也可以自动推断        | 总是自动推断          |
| **语法**   | `var <名字> [类型] = <值>` | `<名字> := <值>`   |
| **简洁性**  | 稍显冗长                  | 非常简洁，是 Go 的惯用风格 |
| **重复声明** | 不允许在同一作用域重复声明         | 允许，但必须至少有一个新变量  |


```go
package main  
import (  
    "fmt"  
    "math/cmplx")  
  
var (  
    ToBe   bool       = false  
    MaxInt uint64     = 1<<64 - 1  
    z      complex128 = cmplx.Sqrt(-5 + 12i)  
)  
  
func main() {  
    fmt.Printf("类型：%T 值：%v\n", ToBe, ToBe)  
    fmt.Printf("类型：%T 值：%v\n", MaxInt, MaxInt)  
    fmt.Printf("类型：%T 值：%v\n", z, z)  
}
```

```go
类型：bool 值：false
类型：uint64 值：18446744073709551615
类型：complex128 值：(2+3i)
```
bool

string

int  int8  int16  int32  int64
uint uint8 uint16 uint32 uint64 uintptr

byte // uint8 的别名

rune // int32 的别名
       // 表示一个 Unicode 码位

float32 float64

complex64 complex128

本例展示了几种类型的变量。 和导入语句一样，变量声明也可以「分组」成一个代码块。

`int`、`uint` 和 `uintptr` 类型在 32-位系统上通常为 32-位宽，在 64-位系统上则为 64-位宽。当你需要一个整数值时应使用 `int` 类型， 除非你有特殊的理由使用固定大小或无符号的整数类型。

```go
func main() {  
    var x, y = 3, 4  
    var f float64 = math.Sqrt(float64(x*x + y*y))  
    var z uint = uint(f)  
    fmt.Println(x, y, z)  
}
```

表达式 `T(v)` 将值 `v` 转换为类型 `T`。

一些数值类型的转换：

var i int = 42
var f float64 = float64(i)
var u uint = uint(f)

或者，更加简短的形式：

i := 42
f := float64(i)
u := uint(f)


```go
package main  
  
import "fmt"  
  
func main() {  
    v := 45.2121  
    fmt.Printf("类型：%T 值：%v\n", v, v)  
}
```

在声明一个变量而不指定其类型时（即使用不带类型的 `:=` 语法 `var =` 表达式语法），变量的类型会通过右值推断出来。

当声明的右值确定了类型时，新变量的类型与其相同：

var i int
j := i // j 也是一个 int

不过当右边包含未指明类型的数值常量时，新变量的类型就可能是 `int`、`float64` 或 `complex128` 了，这取决于常量的精度：

i := 42           // int
f := 3.142        // float64
g := 0.867 + 0.5i // complex128

试着修改示例代码中 `v` 的初始值，并观察它是如何影响类型的。

```go
package main  
  
import "fmt"  
  
const Pi = 3.14  
  
func main() {  
    const World = "世界"  
    fmt.Println("Hello", World)  
    fmt.Println("Happy", Pi, "Day")  
  
    const Truth = true  
    fmt.Println("Go rules?", Truth)  
}
```

常量的声明与变量类似，只不过使用 `const` 关键字。

常量可以是字符、字符串、布尔值或数值。

常量不能用 `:=` 语法声明。

```go
package main  
  
import "fmt"  
  
const (  
    // Big 将 1 左移 100 位来创建一个非常大的数字  
    // 即这个数的二进制是 1 后面跟着 100 个 0    Big = 1 << 100  
    // Small 再往右移 99 位，即 Small = 1 << 1，或者说 Small = 2    Small = Big >> 99  
)  
  
func needInt(x int) int { return x*10 + 1 }  
func needFloat(x float64) float64 {  
    return x * 0.1  
}  
  
func main() {  
    fmt.Println(needInt(Small))  
    fmt.Println(needFloat(Small))  
    fmt.Println(needFloat(Big))  
}
```

数值常量是高精度的 **值**。

一个未指定类型的常量由上下文来决定其类型。

再试着一下输出 `needInt(Big)` 吧。

（`int` 类型可以存储最大 64 位的整数，根据平台不同有时会更小。）


### 流程控制语句：for、if、else、switch 和 defer

```go
package main  
  
import "fmt"  
  
func main() {  
    sum := 0  
    for i := 0; i < 10; i++ {  
       sum += i  
    }  
    fmt.Println(sum)  
}
```

Go 只有一种循环结构：`for` 循环。

基本的 `for` 循环由三部分组成，它们用分号隔开：

- 初始化语句：在第一次迭代前执行
- 条件表达式：在每次迭代前求值
- 后置语句：在每次迭代的结尾执行

初始化语句通常为一句短变量声明，该变量声明仅在 `for` 语句的作用域中可见。

一旦条件表达式求值为 `false`，循环迭代就会终止。

**注意**：和 C、Java、JavaScript 之类的语言不同，Go 的 `for` 语句后面的三个构成部分外没有小括号， 大括号 `{ }` 则是必须的。

```go
package main  
  
import "fmt"  
  
func main() {  
    sum := 1  
    for sum < 1000 {  
       sum += sum  
    }  
    fmt.Println(sum)  
}
```

此时你可以去掉分号，因为 C 的 `while` 在 Go 中叫做 `for`。

```go
package main  
  
import (  
    "fmt"  
    "math")  
  
func sqrt(x float64) string {  
    if x < 0 {  
       return sqrt(-x) + "i"  
    }  
    return fmt.Sprint(math.Sqrt(x))  
}  
  
func main() {  
    fmt.Println(sqrt(2), sqrt(-4))  
}
```

Go 的 `if` 语句与 `for` 循环类似，表达式外无需小括号 `( )`，而大括号 `{ }` 则是必须的。

```go
func pow(x, n, lim float64) float64 {  
    if v := math.Pow(x, n); v < lim {  
       return v  
    }  
    return lim  
}  
  
func main() {  
    fmt.Println(pow(3, 2, 10))  
}
```

和 `for` 一样，`if` 语句可以在条件表达式前执行一个简短语句。

该语句声明的变量作用域仅在 `if` 之内。

```go
func pow(x, n, lim float64) float64 {  
    if v := math.Pow(x, n); v < lim {  
       return v  
    } else {  
       fmt.Printf("%g >= %g\n", v, lim)  
    }  
    // can't use v here, though  
    return lim  
}  
  
func main() {  
    fmt.Println(pow(3, 2, 10))  
}
```

在 `if` 的简短语句中声明的变量同样可以在对应的任何 `else` 块中使用。

```go
func main() {  
    fmt.Print("Go 运行的系统环境：")  
    switch os := runtime.GOOS; os {  
    case "darwin":  
       fmt.Println("OS X")  
    case "linux":  
       fmt.Println("Linux")  
    default:  
       fmt.Printf("%s\n", os)  
    }  
}
```

`switch` 语句是编写一连串 `if - else` 语句的简便方法。它运行第一个 `case` 值 值等于条件表达式的子句。

Go 的 `switch` 语句类似于 C、C++、Java、JavaScript 和 PHP 中的，不过 Go 只会运行选定的 `case`，而非之后所有的 `case`。 在效果上，Go 的做法相当于这些语言中为每个 `case` 后面自动添加了所需的 `break` 语句。在 Go 中，除非以 `fallthrough` 语句结束，否则分支会自动终止。 Go 的另一点重要的不同在于 `switch` 的 `case` 无需为常量，且取值不限于整数。

```go
func main() {  
    fmt.Println("周六是哪天？")  
    today := time.Now().Weekday()  
    switch time.Saturday {  
    case today + 0:  
       fmt.Println("今天")  
    case today + 1:  
       fmt.Println("明天。")  
    case today + 2:  
       fmt.Println("后天。")  
    default:  
       fmt.Println("很多天后。")  
    }  
}
```

`switch` 的 `case` 语句从上到下顺次执行，直到匹配成功时停止。

例如，

switch i {
case 0:
case f():
}

在 `i==0` 时，`f` 不会被调用。）

```go
func main() {  
    t := time.Now()  
    switch {  
    case t.Hour() < 12:  
       fmt.Println("早上好！")  
    case t.Hour() < 17:  
       fmt.Println("下午好！")  
    default:  
       fmt.Println("晚上好！")  
    }  
}
```

无条件的 `switch` 同 `switch true` 一样。

这种形式能将一长串 `if-then-else` 写得更加清晰。

```go
func main() {  
    defer fmt.Println("world")  
  
    fmt.Println("hello")  
}
```

defer 语句会将函数推迟到外层函数返回之后执行。

推迟调用的函数其参数会立即求值，但直到外层函数返回前该函数都不会被调用。

```go
func main() {  
    fmt.Println("counting")  
  
    for i := 0; i < 10; i++ {  
       defer fmt.Println(i)  
    }  
  
    fmt.Println("done")  
}
```

```
counting
done
9
8
7
6
5
4
3
2
1
0
```

推迟调用的函数调用会被压入一个栈中。 当外层函数返回时，被推迟的调用会按照后进先出的顺序调用。

更多关于 defer 语句的信息，请阅读[此博文](http://blog.go-zh.org/defer-panic-and-recover)。

### 更多类型：结构体、切片和映射

```go
func main() {  
    i, j := 42, 2701  
  
    p := &i         // 指向 i    fmt.Println(*p) // 通过指针读取 i 的值  
    *p = 21         // 通过指针设置 i 的值  
    fmt.Println(i)  // 查看 i 的值  
  
    p = &j         // 指向 j    *p = *p / 37   // 通过指针对 j 进行除法运算  
    fmt.Println(j) // 查看 j 的值  
}
```

Go 拥有指针。指针保存了值的内存地址。

类型 `*T` 是指向 `T` 类型值的指针，其零值为 `nil`。

var p *int

`&` 操作符会生成一个指向其操作数的指针。

i := 42
p = &i

`*` 操作符表示指针指向的底层值。

fmt.Println(*p) // 通过指针 p 读取 i
*p = 21         // 通过指针 p 设置 i

这也就是通常所说的「解引用」或「间接引用」。

与 C 不同，Go 没有指针运算。

```go
type Vertex struct {  
    X int  
    Y int  
}  
  
func main() {  
    fmt.Println(Vertex{1, 2})  
}
```

一个 结构体（`struct`）就是一组 字段（field）。

```go
type Vertex struct {  
    X int  
    Y int  
}  
  
func main() {  
    v := Vertex{1, 2}  
    v.X = 4  
    fmt.Println(v)  
}
```

结构体字段可通过点号 `.` 来访问。

```go
type Vertex struct {  
    X int  
    Y int  
}  
  
func main() {  
    v := Vertex{1, 2}  
    v.X = 4  
    p := &v  
    p.Y = 1e9  
    fmt.Println(v)  
}
```

结构体字段可通过结构体指针来访问。

如果我们有一个指向结构体的指针 `p` 那么可以通过 `(*p).X` 来访问其字段 `X`。 不过这么写太啰嗦了，所以语言也允许我们使用隐式解引用，直接写 `p.X` 就可以。

```go
type Vertex struct {  
    X int  
    Y int  
}  
  
var (  
    v1 = Vertex{1, 2}  // 创建一个 Vertex 类型的结构体  
    v2 = Vertex{X: 1}  // Y:0 被隐式地赋予零值  
    v3 = Vertex{}      // X:0 Y:0  
    p  = &Vertex{1, 2} // 创建一个 *Vertex 类型的结构体（指针）  
)  
  
func main() {  
    fmt.Println(v1, p, v2, v3)  
}
```

使用 `Name:` 语法可以仅列出部分字段（字段名的顺序无关）。

特殊的前缀 `&` 返回一个指向结构体的指针。

```go
func main() {  
    var a [2]string  
    a[0] = "Hello"  
    a[1] = "World"  
    fmt.Println(a[0], a[1])  
    fmt.Println(a)  
  
    primes := [6]int{2, 3, 5, 7, 11, 13}  
    fmt.Println(primes)  
}
```

类型 `[n]T` 表示一个数组，它拥有 `n` 个类型为 `T` 的值。

表达式

var a \[10]int

会将变量 `a` 声明为拥有 10 个整数的数组。

数组的长度是其类型的一部分，因此数组不能改变大小。 这看起来是个限制，不过没关系，Go 拥有更加方便的使用数组的方式。

```go
func main() {  
    primes := [6]int{2, 3, 5, 7, 11, 13}  
    var s []int = primes[1:4]  
    fmt.Println(s)  
}
```

每个数组的大小都是固定的。而切片则为数组元素提供了动态大小的、灵活的视角。 在实践中，切片比数组更常用。

类型 `[]T` 表示一个元素类型为 `T` 的切片。.

切片通过两个下标来界定，一个下界和一个上界，二者以冒号分隔：

a\[low : high]

它会选出一个半闭半开区间，包括第一个元素，但排除最后一个元素。

以下表达式创建了一个切片，它包含 `a` 中下标从 1 到 3 的元素：

a\[1:4]

```go
func main() {  
    names := []string{  
       "John",  
       "Paul",  
       "George",  
       "Ringo",  
    }  
    fmt.Println(names)  
  
    a := names[0:2]  
    b := names[1:3]  
    fmt.Println(a, b)  
    b[0] = "XX"  
    fmt.Println(a, b)  
    fmt.Println(names)  
}
```

切片就像数组的引用 切片并不存储任何数据，它只是描述了底层数组中的一段。

更改切片的元素会修改其底层数组中对应的元素。

和它共享底层数组的切片都会观测到这些修改。

```go
func main() {  
    q := []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}  
    fmt.Println(q)  
  
    r := []bool{true, false, true, true}  
    fmt.Println(r)  
  
    s := []struct {  
       i int  
       b bool  
    }{  
       {2, true},  
       {3, false},  
       {4, true},  
       {5, true},  
    }  
    fmt.Println(s)  
}
```

切片字面量类似于没有长度的数组字面量。

这是一个数组字面量：

\[3]bool{true, true, false}

下面这样则会创建一个和上面相同的数组，然后再构建一个引用了它的切片：

\[]bool{true, true, false}

```go
func main() {  
    s := []int{1, 2, 3, 4, 5}  
    s = s[1:4]  
    fmt.Println(s)  
  
    s = s[:2]  
    fmt.Println(s)  
  
    s = s[1:]  
    fmt.Println(s)  
}
```

在进行切片时，你可以利用它的默认行为来忽略上下界。

切片下界的默认值为 0，上界则是该切片的长度。

对于数组

var a \[10]int

来说，以下切片表达式和它是等价的：

a\[0:10]
a\[:10]
a\[0:]
a\[:]

```go
func printSlice(s []int) {  
    fmt.Printf("len=%d cap=%d %v\n", len(s), cap(s), s)  
}  
  
func main() {  
    s := []int{2, 3, 5, 7, 11, 13}  
    printSlice(s)  
  
    // 截取切片使其长度为 0    s = s[:0]  
    printSlice(s)  
  
    // 扩展其长度  
    s = s[:4]  
    printSlice(s)  
  
    // 舍弃前两个值  
    s = s[2:]  
    printSlice(s)  
}
```

```
len=6 cap=6 [2 3 5 7 11 13]
len=0 cap=6 []
len=4 cap=6 [2 3 5 7]
len=2 cap=4 [5 7]
```

切片拥有 **长度** 和 **容量**。

切片的长度就是它所包含的元素个数。

切片的容量是从它的第一个元素开始数，到其底层数组元素末尾的个数。

切片 `s` 的长度和容量可通过表达式 `len(s)` 和 `cap(s)` 来获取。

你可以通过重新切片来扩展一个切片，给它提供足够的容量。 试着修改示例程序中的切片操作，向外扩展它的长度，看看会发生什么。

```go
func printSlice(s []int) {  
    fmt.Printf("len=%d cap=%d %v\n", len(s), cap(s), s)  
}  
  
func main() {  
    var s []int  
    printSlice(s)  
    if s == nil {  
       fmt.Println("nil!")  
    }  
}
```

```
len=0 cap=0 []
nil!
```

切片的零值是 `nil`。

nil 切片的长度和容量为 0 且没有底层数组。

```go
func printSlice(s string, x []int) {  
    fmt.Printf("%s len=%d cap=%d %v\n",  
       s, len(x), cap(x), x)  
}  
  
func main() {  
    a := make([]int, 5)  
    printSlice("a", a)  
  
    b := make([]int, 0, 5)  
    printSlice("b", b)  
  
    c := b[:2]  
    printSlice("c", c)  
  
    d := c[2:5]  
    printSlice("d", d)  
}
```

```go
a len=5 cap=5 [0 0 0 0 0]
b len=0 cap=5 []
c len=2 cap=5 [0 0]
d len=3 cap=3 [0 0 0]
```

切片可以用内置函数 `make` 来创建，这也是你创建动态数组的方式。

`make` 函数会分配一个元素为零值的数组并返回一个引用了它的切片：

a := make(\[]int, 5)  // len(a)=5

要指定它的容量，需向 `make` 传入第三个参数：

b := make(\[]int, 0, 5) // len(b)=0, cap(b)=5

b = b\[:cap(b)] // len(b)=5, cap(b)=5
b = b\[1:]      // len(b)=4, cap(b)=4

```go
func main() {  
    // 创建一个井字棋（经典游戏）  
    board := [][]string{  
       []string{"_", "_", "_"},  
       []string{"_", "_", "_"},  
       []string{"_", "_", "_"},  
    }  
  
    // 两个玩家轮流打上 X 和 O    board[0][0] = "X"  
    board[2][2] = "O"  
    board[1][2] = "X"  
    board[1][0] = "O"  
    board[0][2] = "X"  
  
    for i := 0; i < len(board); i++ {  
       fmt.Printf("%s\n", strings.Join(board[i], " "))  
    }  
}
```

切片可以包含任何类型，当然也包括其他切片。

```go
func printSlice(s []int) {  
    fmt.Printf("len=%d cap=%d %v\n", len(s), cap(s), s)  
}  
  
func main() {  
    var a []int  
    printSlice(a)  
  
    a = append(a, 0)  
    printSlice(a)  
  
    a = append(a, 1)  
    printSlice(a)  
  
    // 可以一次性添加多个元素  
    a = append(a, 2, 3, 4)  
    printSlice(a)  
}
```

为切片追加新的元素是种常见的操作，为此 Go 提供了内置的 `append` 函数。内置函数的[文档](https://tour.go-zh.org/pkg/builtin/#append)对该函数有详细的介绍。

func append(s \[]T, vs ...T) \[]T

`append` 的第一个参数 `s` 是一个元素类型为 `T` 的切片，其余类型为 `T` 的值将会追加到该切片的末尾。

`append` 的结果是一个包含原切片所有元素加上新添加元素的切片。

当 `s` 的底层数组太小，不足以容纳所有给定的值时，它就会分配一个更大的数组。 返回的切片会指向这个新分配的数组。

（要了解关于切片的更多内容，请阅读文章 [Go 切片：用法和本质](https://tour.go-zh.org/blog/go-slices-usage-and-internals)。）

```go
var pow = []int{1, 2, 4, 8, 16, 32, 64, 128}  
  
func main() {  
    for i, v := range pow {  
       fmt.Printf("%d*%d = %d\n", i, v, v*v)  
    }  
}
```

`for` 循环的 `range` 形式可遍历切片或映射。

当使用 `for` 循环遍历切片时，每次迭代都会返回两个值。 第一个值为当前元素的下标，第二个值为该下标所对应元素的一份副本。

```go
var pow = []int{1, 2, 4, 8, 16, 32, 64, 128}  
  
func main() {  
    for i := range pow {  
       pow[i] = 1 << uint(i)  
    }  
  
    for _, v := range pow {  
       fmt.Printf("%d\n", v)  
    }  
}
```

可以将下标或值赋予 `_` 来忽略它。

for i, _ := range pow
for _, value := range pow

若你只需要索引，忽略第二个变量即可。

for i := range pow

```go
var m map[string]Vertex  
  
func main() {  
    m = make(map[string]Vertex)  
    m["Bell Labs"] = Vertex{  
       40.68433, -74.39967,  
    }  
    fmt.Println(m["Bell Labs"])  
}
```

`map` 映射将键映射到值。

映射的零值为 `nil` 。`nil` 映射既没有键，也不能添加键。

`make` 函数会返回给定类型的映射，并将其初始化备用。

```go
var m = map[string]Vertex{  
    "Bell Labs": Vertex{  
       40.68433, -74.39967,  
    },  
    "Google": Vertex{  
       37.42202, -122.08408,  
    },  
}  
  
func main() {  
    fmt.Println(m)  
}
```

映射的字面量和结构体类似，只不过必须有键名。

```go
var m = map[string]Vertex{  
    "Bell Labs": {40.68433, -74.39967},  
    "Google":    {37.42202, -122.08408},  
}  
  
func main() {  
    fmt.Println(m)  
}
```

若顶层类型只是一个类型名，那么你可以在字面量的元素中省略它。

```go
func main() {  
    m := make(map[string]int)  
  
    m["答案"] = 42  
    fmt.Println("值：", m["答案"])  
  
    m["答案"] = 48  
    fmt.Println("值：", m["答案"])  
  
    delete(m, "答案")  
    fmt.Println("值：", m["答案"])  
  
    v, ok := m["答案"]  
    fmt.Println("值：", v, "是否存在？", ok)  
  
}
```

在映射 `m` 中插入或修改元素：

m\[key] = elem

获取元素：

elem = m\[key]

删除元素：

delete(m, key)

通过双赋值检测某个键是否存在：

elem, ok = m\[key]

若 `key` 在 `m` 中，`ok` 为 `true` ；否则，`ok` 为 `false`。

若 `key` 不在映射中，则 `elem` 是该映射元素类型的零值。

**注**：若 `elem` 或 `ok` 还未声明，你可以使用短变量声明：

elem, ok := m\[key]

```go
func compute(fn func(float64, float64) float64) float64 {  
    return fn(3, 4)  
}  
  
func main() {  
    hypot := func(x, y float64) float64 {  
       return math.Sqrt(x*x + y*y)  
    }  
    fmt.Println(hypot(5, 12))  
  
    fmt.Println(compute(hypot))  
    fmt.Println(compute(math.Pow))  
}
```

函数也是值。它们可以像其他值一样传递。

函数值可以用作函数的参数或返回值。

```go
// 通常情况下，一个函数的局部变量会随着函数的返回而被销毁。但是，如果一个闭包引用了这些变量，它们的生命周期会被延长，直到没有任何闭包引用它们为止。  
func adder() func(int) int {  
    sum := 0  
    // 这个返回的匿名函数就是闭包。它没有自己的 sum 变量，而是引用了其外部函数 adder 的 sum 变量。  
    return func(x int) int {  
       sum += x  
       return sum  
    }  
}  
  
func main() {  
    pos, neg := adder(), adder()  
    for i := 0; i < 10; i++ {  
       fmt.Println(  
          pos(i),  
          neg(-2*i),  
       )  
    }  
}
```

Go 函数可以是一个闭包。闭包是一个函数值，它引用了其函数体之外的变量。 该函数可以访问并赋予其引用的变量值，换句话说，该函数被“绑定”到了这些变量。

例如，函数 `adder` 返回一个闭包。每个闭包都被绑定在其各自的 `sum` 变量上。


### 方法和接口

```go
type Vertex struct {  
    X, Y float64  
}  
  
func (v Vertex) Abs() float64 {  
    return math.Sqrt(v.X*v.X + v.Y*v.Y)  
}  
  
func main() {  
    v := Vertex{3, 4}  
    fmt.Println(v.Abs())  
}
```

Go 没有类。不过你可以为类型定义方法。

方法就是一类带特殊的 **接收者** 参数的函数。

方法接收者在它自己的参数列表内，位于 `func` 关键字和方法名之间。

在此例中，`Abs` 方法拥有一个名字为 `v`，类型为 `Vertex` 的接收者。

```go
type Vertex struct {  
    X, Y float64  
}  
  
func (v Vertex) Abs() float64 {  
    return math.Sqrt(v.X*v.X + v.Y*v.Y)  
}  
  
func Abs(v Vertex) float64 {  
    return math.Sqrt(v.X*v.X + v.Y*v.Y)  
}  
func main() {  
    v := Vertex{3, 4}  
    fmt.Println(v.Abs())  
    fmt.Println(Abs(v))  
}
```

记住：方法只是个带接收者参数的函数。

现在这个 `Abs` 的写法就是个正常的函数，功能并没有什么变化。


```go
type MyFloat float64  
  
func (f MyFloat) Abs() float64 {  
    if f < 0 {  
       return float64(-f)  
    }  
    return float64(f)  
}  
func main() {  
    f := MyFloat(-math.Sqrt2)  
    fmt.Println(f.Abs())  
}
```

你也可以为非结构体类型声明方法。

在此例中，我们看到了一个带 `Abs` 方法的数值类型 `MyFloat`。

你只能为在同一个包中定义的接收者类型声明方法，而不能为其它别的包中定义的类型 （包括 `int` 之类的内置类型）声明方法。

（译注：就是接收者的类型定义和方法声明必须在同一包内。）

```go
type Vertex struct {  
    X, Y float64  
}  
  
func (v Vertex) Abs() float64 {  
    return math.Sqrt(v.X*v.X + v.Y*v.Y)  
}  
  
func (v *Vertex) Scale(f float64) {  
    v.X = v.X * f  
    v.Y = v.Y * f  
}  
  
func main() {  
    v := Vertex{3, 4}  
    v.Scale(10)  
    fmt.Println(v.Abs())  
}
```

```
50
```

去掉 * 后
```
5
```

你可以为指针类型的接收者声明方法。

这意味着对于某类型 `T`，接收者的类型可以用 `*T` 的文法。 （此外，`T` 本身不能是指针，比如不能是 `*int`。）

例如，这里为 `*Vertex` 定义了 `Scale` 方法。

指针接收者的方法可以修改接收者指向的值（如这里的 `Scale` 所示）。 由于方法经常需要修改它的接收者，指针接收者比值接收者更常用。

试着移除第 16 行 `Scale` 函数声明中的 `*`，观察此程序的行为如何变化。

若使用值接收者，那么 `Scale` 方法会对原始 `Vertex` 值的副本进行操作。（对于函数的其它参数也是如此。）`Scale` 方法必须用指针接收者来更改 `main` 函数中声明的 `Vertex` 的值。

```go
type Vertex struct {  
    X, Y float64  
}  
  
func (v *Vertex) Scale(f float64) {  
    v.X = v.X * f  
    v.Y = v.Y * f  
}  
  
func ScaleFunc(v *Vertex, f float64) {  
    v.X = v.X * f  
    v.Y = v.Y * f  
}  
  
func main() {  
    v := Vertex{3, 4}  
    v.Scale(2)  
    ScaleFunc(&v, 10)  
  
    p := &Vertex{4, 3}  
    p.Scale(3)  
    ScaleFunc(p, 8)  
  
    fmt.Println(v, p)  
}
```

比较前两个程序，你大概会注意到带指针参数的函数必须接受一个指针：

var v Vertex
ScaleFunc(v, 5)  // 编译错误！
ScaleFunc(&v, 5) // OK

而接收者为指针的的方法被调用时，接收者既能是值又能是指针：

var v Vertex
v.Scale(5)  // OK
p := &v
p.Scale(10) // OK

对于语句 `v.Scale(5)` 来说，即便 `v` 是一个值而非指针，带指针接收者的方法也能被直接调用。 也就是说，由于 `Scale` 方法有一个指针接收者，为方便起见，Go 会将语句 `v.Scale(5)` 解释为 `(&v).Scale(5)`。

```go
type Vertex struct {  
    X, Y float64  
}  
  
func (v Vertex) Abs() float64 {  
    return math.Sqrt(v.X*v.X + v.Y*v.Y)  
}  
  
func AbsFunc(v Vertex) float64 {  
    return math.Sqrt(v.X*v.X + v.Y*v.Y)  
}  
  
func main() {  
    v := Vertex{3, 4}  
    fmt.Println(v.Abs())  
    fmt.Println(AbsFunc(v))  
  
    p := &Vertex{4, 3}  
    fmt.Println(p.Abs())  
    fmt.Println(AbsFunc(*p))  
}
```

反之也一样：

接受一个值作为参数的函数必须接受一个指定类型的值：

var v Vertex
fmt.Println(AbsFunc(v))  // OK
fmt.Println(AbsFunc(&v)) // 编译错误！

而以值为接收者的方法被调用时，接收者既能为值又能为指针：

var v Vertex
fmt.Println(v.Abs()) // OK
p := &v
fmt.Println(p.Abs()) // OK

这种情况下，方法调用 `p.Abs()` 会被解释为 `(*p).Abs()`。

```go
func (v *Vertex) Scale(f float64) {  
    v.X = v.X * f  
    v.Y = v.Y * f  
}  
  
func (v *Vertex) Abs() float64 {  
    return math.Sqrt(v.X*v.X + v.Y*v.Y)  
}  
  
func main() {  
    v := &Vertex{3, 4}  
    fmt.Printf("缩放前：%+v，绝对值：%v\n", v, v.Abs())  
    v.Scale(5)  
    fmt.Printf("缩放后：%+v，绝对值：%v\n", v, v.Abs())  
}
```

使用指针接收者的原因有二：

首先，方法能够修改其接收者指向的值。

其次，这样可以避免在每次调用方法时复制该值。若值的类型为大型结构体时，这样会更加高效。

在本例中，`Scale` 和 `Abs` 接收者的类型为 `*Vertex`，即便 `Abs` 并不需要修改其接收者。

通常来说，所有给定类型的方法都应该有值或指针接收者，但并不应该二者混用。 （我们会在接下来几页中明白为什么。）

```go
type Abser interface {  
    Abs() float64  
}  
  
func main() {  
    var a Abser  
    f := MyFloat(-math.Sqrt2)  
    v := Vertex{3, 4}  
    a = f  // a MyFloat 实现了 Abser    a = &v // a *Vertex 实现了 Abser    // 下面一行，v 是一个 Vertex（而不是 *Vertex） 所以没有实现 Abser。  
    //a = v 错误代码  
    fmt.Println(a.Abs())  
}  
  
type MyFloat float64  
  
func (f MyFloat) Abs() float64 {  
    if f < 0 {  
       return float64(-f)  
    }  
    return float64(f)  
}  
  
type Vertex struct {  
    X, Y float64  
}  
  
func (v *Vertex) Abs() float64 {  
    return math.Sqrt(v.X*v.X + v.Y*v.Y)  
}
```

**接口类型** 的定义为一组方法签名。

接口类型的变量可以持有任何实现了这些方法的值。

**注意:** 示例代码的第 22 行存在一个错误。由于 `Abs` 方法只为 `*Vertex` （指针类型）定义，因此 `Vertex`（值类型）并未实现 `Abser`。



```go
type I interface {  
    M()  
}  
  
type T struct {  
    S string  
}  
  
// M 此方法表示类型 T 实现了接口 I，不过我们并不需要显式声明这一点。  
func (t T) M() {  
    fmt.Println(t.S)  
}  
  
func main() {  
    var i I = T{"hello"}  
    i.M()  
}
```

类型通过实现一个接口的所有方法来实现该接口。既然无需专门显式声明，也就没有“implements”关键字。

隐式接口从接口的实现中解耦了定义，这样接口的实现可以出现在任何包中，无需提前准备。

因此，也就无需在每一个实现上增加新的接口名称，这样同时也鼓励了明确的接口定义。

```go
type I interface {  
    M()  
}  
  
type T struct {  
    S string  
}  
  
func (t *T) M() {  
    fmt.Println(t.S)  
}  
  
type F float64  
  
func (f F) M() {  
    fmt.Println(f)  
}  
  
func main() {  
    var i I  
  
    i = &T{"Hello"}  
    describe(i)  
    i.M()  
  
    i = F(math.Pi)  
    describe(i)  
    i.M()  
}  
  
func describe(i I) {  
    fmt.Printf("(%v, %T)\n", i, i)  
}
```

```go
(&{Hello}, *main.T)
Hello
(3.141592653589793, main.F)
3.141592653589793
```

接口也是值。它们可以像其它值一样传递。

接口值可以用作函数的参数或返回值。

在内部，接口值可以看做包含值和具体类型的元组：

(value, type)

接口值保存了一个具体底层类型的具体值。

接口值调用方法时会执行其底层类型的同名方法。

```go
type I interface {  
    M()  
}  
  
type T struct {  
    S string  
}  
  
func (t *T) M() {  
    if t == nil {  
       fmt.Println("<nil>")  
       return  
    }  
    fmt.Println(t.S)  
}  
func main() {  
    var i I  
  
    var t *T  
    i = t  
    describe(i)  
    i.M()  
  
    i = &T{"hello"}  
    describe(i)  
    i.M()  
}  
  
func describe(i I) {  
    fmt.Printf("(%v, %T)\n", i, i)  
}
```

即便接口内的具体值为 nil，方法仍然会被 nil 接收者调用。

在一些语言中，这会触发一个空指针异常，但在 Go 中通常会写一些方法来优雅地处理它（如本例中的 `M` 方法）。

**注意:** 保存了 nil 具体值的接口其自身并不为 nil。

```go
type I interface {  
    M()  
}  
  
func main() {  
    var i I  
    describe(i)  
    i.M()  
}  
  
func describe(i I) {  
    fmt.Printf("(%v, %T)\n", i, i)  
}
```

```
(<nil>, <nil>)
panic: runtime error: invalid memory address or nil pointer dereference
[signal 0xc0000005 code=0x0 addr=0x0 pc=0x7ff736300499]

goroutine 1 [running]:
main.main()
	D:/desktop/go-project/study/main.go:14 +0x19
```

nil 接口值既不保存值也不保存具体类型。

为 nil 接口调用方法会产生运行时错误，因为接口的元组内并未包含能够指明该调用哪个 **具体** 方法的类型。

```go
func main() {  
    var i interface{}  
    describe(i)  
  
    i = 42  
    describe(i)  
  
    i = "hello"  
    describe(i)  
}  
  
func describe(i interface{}) {  
    fmt.Printf("(%v, %T)\n", i, i)  
}
```

指定了零个方法的接口值被称为 *空接口：*

interface{}

空接口可保存任何类型的值。（因为每个类型都至少实现了零个方法。）

空接口被用来处理未知类型的值。例如，`fmt.Print` 可接受类型为 `interface{}` 的任意数量的参数。

```go
func main() {  
    var i interface{} = "hello"  
    s := i.(string)  
    fmt.Println(s)  
  
    s, ok := i.(string)  
    fmt.Println(s, ok)  
  
    f, ok := i.(float64)  
    fmt.Println(f, ok)  
  
    f = i.(float64) // panic  
    fmt.Println(f)  
}
```

```
hello
hello true
0 false
panic: interface conversion: interface {} is string, not float64

goroutine 1 [running]:
main.main()
	D:/desktop/go-project/study/main.go:16 +0x13f
```

**类型断言** 提供了访问接口值底层具体值的方式。

t := i.(T)

该语句断言接口值 `i` 保存了具体类型 `T`，并将其底层类型为 `T` 的值赋予变量 `t`。

若 `i` 并未保存 `T` 类型的值，该语句就会触发一个 panic。

为了 **判断** 一个接口值是否保存了一个特定的类型，类型断言可返回两个值：其底层值以及一个报告断言是否成功的布尔值。

t, ok := i.(T)

若 `i` 保存了一个 `T`，那么 `t` 将会是其底层值，而 `ok` 为 `true`。

否则，`ok` 将为 `false` 而 `t` 将为 `T` 类型的零值，程序并不会产生 panic。

请注意这种语法和读取一个映射时的相同之处。

```go
func do(i interface{}) {  
    switch v := i.(type) {  
    case int:  
       fmt.Printf("二倍的 %v 是 %v\n", v, v*2)  
    case string:  
       fmt.Printf("%q 长度为 %v 字节\n", v, len(v))  
    default:  
       fmt.Printf("我不知道类型 %T!\n", v)  
    }  
}  
  
func main() {  
    do(21)  
    do("hello")  
    do(true)  
}
```

**类型选择** 是一种按顺序从几个类型断言中选择分支的结构。

类型选择与一般的 switch 语句相似，不过类型选择中的 case 为类型（而非值）， 它们针对给定接口值所存储的值的类型进行比较。

switch v := i.(type) {
case T:
    // v 的类型为 T
case S:
    // v 的类型为 S
default:
    // 没有匹配，v 与 i 的类型相同
}

类型选择中的声明与类型断言 `i.(T)` 的语法相同，只是具体类型 `T` 被替换成了关键字 `type`。

此选择语句判断接口值 `i` 保存的值类型是 `T` 还是 `S`。在 `T` 或 `S` 的情况下，变量 `v` 会分别按 `T` 或 `S` 类型保存 `i` 拥有的值。在默认（即没有匹配）的情况下，变量 `v` 与 `i` 的接口类型和值相同。

```go
type Person struct {  
    Name string  
    Age  int  
}  
  
func (p Person) String() string {  
    return fmt.Sprintf("%v (%v years)", p.Name, p.Age)  
}  
  
func main() {  
    a := Person{"Arthur Dent", 42}  
    z := Person{"Zaphod Beeblebrox", 9001}  
    fmt.Println(a, z)  
}
```

```
Arthur Dent (42 years) Zaphod Beeblebrox (9001 years)
```

[`fmt`](https://go-zh.org/pkg/fmt/) 包中定义的 [`Stringer`](https://go-zh.org/pkg/fmt/#Stringer) 是最普遍的接口之一。

type Stringer interface {
    String() string
}

`Stringer` 是一个可以用字符串描述自己的类型。`fmt` 包（还有很多包）都通过此接口来打印值。

```go
type MyError struct {  
    When time.Time  
    What string  
}  
  
func (e *MyError) Error() string {  
    return fmt.Sprintf("at %v, %s", e.When, e.What)  
}  
  
func run() error {  
    return &MyError{  
       time.Now(),  
       "it didn't work",  
    }  
}  
  
func main() {  
    if err := run(); err != nil {  
       fmt.Println(err)  
    }  
}
```

Go 程序使用 `error` 值来表示错误状态。

与 `fmt.Stringer` 类似，`error` 类型是一个内建接口：

type error interface {
    Error() string
}

（与 `fmt.Stringer` 类似，`fmt` 包也会根据对 `error` 的实现来打印值。）

通常函数会返回一个 `error` 值，调用它的代码应当判断这个错误是否等于 `nil` 来进行错误处理。

i, err := strconv.Atoi("42")
if err != nil {
    fmt.Printf("couldn't convert number: %v\n", err)
    return
}
fmt.Println("Converted integer:", i)

`error` 为 nil 时表示成功；非 nil 的 `error` 表示失败。

```go
func main() {  
    r := strings.NewReader("Hello Reader!")  
    b := make([]byte, 8)  
    for {  
       n, err := r.Read(b)  
       fmt.Printf("n = %v, err = %v\n", n, err)  
       fmt.Printf("b = %v\n", b)  
       if err == io.EOF {  
          break  
       }  
    }  
}
```

```
n = 8, err = <nil>
b = [72 101 108 108 111 32 82 101]
n = 5, err = <nil>
b = [97 100 101 114 33 32 82 101]
n = 0, err = EOF
b = [97 100 101 114 33 32 82 101]
```

`io` 包指定了 `io.Reader` 接口，它表示数据流的读取端。

Go 标准库包含了该接口的[许多实现](https://cs.opensource.google/search?q=Read%5C\(%5Cw%2B%5Cs%5C%5B%5C%5Dbyte%5C\)&ss=go%2Fgo)，包括文件、网络连接、压缩和加密等等。

`io.Reader` 接口有一个 `Read` 方法：

func (T) Read(b \[]byte) (n int, err error)

`Read` 用数据填充给定的字节切片并返回填充的字节数和错误值。在遇到数据流的结尾时，它会返回一个 `io.EOF` 错误。

示例代码创建了一个 [`strings.Reader`](https://go-zh.org/pkg/strings/#Reader) 并以每次 8 字节的速度读取它的输出。

```go
func main() {  
    m := image.NewRGBA(image.Rect(0, 0, 100, 100))  
    fmt.Println(m.Bounds())  
    fmt.Println(m.At(0, 0).RGBA())  
}
```

[`image`](https://go-zh.org/pkg/image/#Image) 包定义了 `Image` 接口：

package image

type Image interface {
    ColorModel() color.Model
    Bounds() Rectangle
    At(x, y int) color.Color
}

**注意:** `Bounds` 方法的返回值 `Rectangle` 实际上是一个 [`image.Rectangle`](https://go-zh.org/pkg/image/#Rectangle)，它在 `image` 包中声明。

（请参阅[文档](https://go-zh.org/pkg/image/#Image)了解全部信息。）

`color.Color` 和 `color.Model` 类型也是接口，但是通常因为直接使用预定义的实现 `image.RGBA` 和 `image.RGBAModel` 而被忽视了。这些接口和类型由 [`image/color`](https://go-zh.org/pkg/image/color/) 包定义。

### 泛型

```go
func Index[T comparable](s []T, x T) int {  
    for i, v := range s {  
       if v == x {  
          return i  
       }  
    }  
    return -1  
}  
  
func main() {  
    // Index 可以在整数切片上使用  
    si := []int{10, 20, 15, -10}  
    fmt.Println(Index(si, 15))  
  
    // Index 也可以在字符串切片上使用  
    ss := []string{"foo", "bar", "baz"}  
    fmt.Println(Index(ss, "hello"))  
}
```

可以使用类型参数编写 Go 函数来处理多种类型。 函数的类型参数出现在函数参数之前的方括号之间。

func Index\[T comparable](s \[]T, x T) int

此声明意味着 `s` 是满足内置约束 `comparable` 的任何类型 `T` 的切片。 `x` 也是相同类型的值。

`comparable` 是一个有用的约束，它能让我们对任意满足该类型的值使用 `==` 和 `!=` 运算符。在此示例中，我们使用它将值与所有切片元素进行比较，直到找到匹配项。 该 `Index` 函数适用于任何支持比较的类型。

```go
type ListNode[T any] struct {  
    next *ListNode[T]  
    val  T  
}  
  
func newListNode[T any](val T) *ListNode[T] {  
    return &ListNode[T]{val: val}  
}  
  
func main() {  
    List := newListNode[int](5)  
    List.next = newListNode[int](6)  
    List.next.next = newListNode[int](7)  
    for List != nil {  
       fmt.Println(List)  
       List = List.next  
    }  
}
```

```
&{0xc000026080 5}
&{0xc000026090 6}
&{<nil> 7}
```

除了泛型函数之外，Go 还支持泛型类型。 类型可以使用类型参数进行参数化，这对于实现通用数据结构非常有用。

此示例展示了能够保存任意类型值的单链表的简单类型声明。

作为练习，请为此链表的实现添加一些功能。

### 并发

```go
package main  
  
import (  
    "fmt"  
    "time")  
  
func say(s string) {  
    for i := 0; i < 5; i++ {  
       time.Sleep(100 * time.Millisecond)  
       fmt.Println(s)  
    }  
}  
  
func main() {  
    go say("hello world")  
    say("hello world")  
}
```

Go 程（goroutine）是由 Go 运行时管理的轻量级线程。

go f(x, y, z)

会启动一个新的 Go 协程并执行

f(x, y, z)

`f`, `x`, `y` 和 `z` 的求值发生在当前的 Go 协程中，而 `f` 的执行发生在新的 Go 协程中。

Go 程在相同的地址空间中运行，因此在访问共享的内存时必须进行同步。[`sync`](https://go-zh.org/pkg/sync/) 包提供了这种能力，不过在 Go 中并不经常用到，因为还有其它的办法

```go
func sum(s []int, c chan int) {  
    sum := 0  
    for _, v := range s {  
       sum += v  
    }  
    c <- sum  
}  
  
func main() {  
    s := []int{7, 2, 8, -9, 4, 0}  
    c := make(chan int)  
    go sum(s[:len(s)/2], c)  
    go sum(s[len(s)/2:], c)  
    x, y := <-c, <-c  
    fmt.Println(x, y, x+y)  
}
```

信道是带有类型的管道，你可以通过它用信道操作符 `<-` 来发送或者接收值。

ch <- v    // 将 v 发送至信道 ch。
v := <-ch  // 从 ch 接收值并赋予 v。

（“箭头”就是数据流的方向。）

和映射与切片一样，信道在使用前必须创建：

ch := make(chan int)

默认情况下，发送和接收操作在另一端准备好之前都会阻塞。这使得 Go 程可以在没有显式的锁或竞态变量的情况下进行同步。

以下示例对切片中的数进行求和，将任务分配给两个 Go 程。一旦两个 Go 程完成了它们的计算，它就能算出最终的结果。

```go
func main() {  
    ch := make(chan int, 2)  
    ch <- 1  
    ch <- 2  
    fmt.Println(<-ch)  
    fmt.Println(<-ch)  
}
```

信道可以是 **带缓冲的**。将缓冲长度作为第二个参数提供给 `make` 来初始化一个带缓冲的信道：

ch := make(chan int, 100)

仅当信道的缓冲区填满后，向其发送数据时才会阻塞。当缓冲区为空时，接受方会阻塞。

```go
func fibonacci(n int, c chan int) {  
    x, y := 0, 1  
    for i := 0; i < n; i++ {  
       c <- x  
       x, y = y, x+y  
    }  
    close(c)  
}  
  
func main() {  
    c := make(chan int, 10)  
    go fibonacci(cap(c), c)  
    for i := range c {  
       fmt.Println(i)  
    }  
}
```

发送者可通过 `close` 关闭一个信道来表示没有需要发送的值了。接收者可以通过为接收表达式分配第二个参数来测试信道是否被关闭：若没有值可以接收且信道已被关闭，那么在执行完

v, ok := <-ch

此时 `ok` 会被设置为 `false`。

循环 `for i := range c` 会不断从信道接收值，直到它被关闭。

**注意**： 只应由发送者关闭信道，而不应油接收者关闭。向一个已经关闭的信道发送数据会引发程序 panic。

**还要注意**： 信道与文件不同，通常情况下无需关闭它们。只有在必须告诉接收者不再有需要发送的值时才有必要关闭，例如终止一个 `range` 循环。

```go
func fibonacci(c, quit chan int) {  
    x, y := 0, 1  
    for {  
       select {  
       case c <- x:  
          x, y = y, x+y  
       case <-quit:  
          fmt.Println("quit")  
          return  
       }  
    }  
}  
  
func main() {  
    c := make(chan int)  
    quit := make(chan int)  
    go func() {  
       for i := 0; i < 10; i++ {  
          fmt.Println(<-c)  
       }  
       quit <- 0  
    }()  
    fibonacci(c, quit)  
}
```

`select` 语句使一个 Go 程可以等待多个通信操作。

`select` 会阻塞到某个分支可以继续执行为止，这时就会执行该分支。当多个分支都准备好时会随机选择一个执行

```go
func main() {  
    tick := time.Tick(100 * time.Millisecond)  
    boom := time.After(500 * time.Millisecond)  
    for {  
       select {  
       case <-tick:  
          fmt.Println("tick.")  
       case <-boom:  
          fmt.Println("BOOM!")  
          return  
       default:  
          fmt.Println("    .")  
          time.Sleep(50 * time.Millisecond)  
       }  
    }  
}
```

当 `select` 中的其它分支都没有准备好时，`default` 分支就会执行。

为了在尝试发送或者接收时不发生阻塞，可使用 `default` 分支：

select {
case i := <-c:
    // 使用 i
default:
    // 从 c 中接收会阻塞时执行
}

```go
package main  
  
import (  
    "fmt"  
    "sync"    "time")  
  
// SafeCounter 是并发安全的  
type SafeCounter struct {  
    mu sync.Mutex  
    v  map[string]int  
}  
  
// Inc 对给定键的计数加一  
func (c *SafeCounter) Inc(key string) {  
    c.mu.Lock()  
    // 锁定使得一次只有一个 Go 协程可以访问映射 c.v。  
    c.v[key]++  
    c.mu.Unlock()  
}  
  
// Value 返回给定键的计数的当前值。  
func (c *SafeCounter) Value(key string) int {  
    c.mu.Lock()  
    // 锁定使得一次只有一个 Go 协程可以访问映射 c.v。  
    defer c.mu.Unlock()  
    return c.v[key]  
}  
  
func main() {  
    c := SafeCounter{v: make(map[string]int)}  
    for i := 0; i < 1000; i++ {  
       go c.Inc("somekey")  
    }  
  
    time.Sleep(time.Second)  
    fmt.Println(c.Value("somekey"))  
}
```

我们已经看到信道非常适合在各个 Go 程间进行通信。

但是如果我们并不需要通信呢？比如说，若我们只是想保证每次只有一个 Go 程能够访问一个共享的变量，从而避免冲突？

这里涉及的概念叫做 *互斥（mutual*exclusion）* ，我们通常使用 *互斥锁（Mutex）* 这一数据结构来提供这种机制。

Go 标准库中提供了 [`sync.Mutex`](https://go-zh.org/pkg/sync/#Mutex) 互斥锁类型及其两个方法：

- `Lock`
- `Unlock`

我们可以通过在代码前调用 `Lock` 方法，在代码后调用 `Unlock` 方法来保证一段代码的互斥执行。参见 `Inc` 方法。

我们也可以用 `defer` 语句来保证互斥锁一定会被解锁。参见 `Value` 方法。

## end

你可以从[安装 Go](https://go-zh.org/doc/install/) 开始。

一旦安装了 Go，Go [文档](https://go-zh.org/doc/)是一个极好的 应当继续阅读的内容。 它包含了参考、指南、视频等等更多资料。

了解如何组织 Go 代码并在其上工作，参阅[此视频](https://www.youtube.com/watch?v=XCsL89YtqCs)，或者阅读[如何编写 Go 代码](https://tour.go-zh.org/doc/code.html)。

如果你需要标准库方面的帮助，请参考[包手册](https://go-zh.org/pkg/)。如果是语言本身的帮助，阅读[语言规范](https://tour.go-zh.org/ref/spec)是件令人愉快的事情。

进一步探索 Go 的并发模型，参阅 [Go 并发模型](https://www.youtube.com/watch?v=f6kdp27TYZs)([幻灯片](https://talks.go-zh.org/2012/concurrency.slide))以及[深入 Go 并发模型](https://www.youtube.com/watch?v=QDDwwePbDtw)([幻灯片](https://talks.go-zh.org/2013/advconc.slide))并阅读[通过通信共享内存](https://tour.go-zh.org/doc/codewalk/sharemem/)的代码之旅。

想要开始编写 Web 应用，请参阅[一个简单的编程环境](https://vimeo.com/53221558)([幻灯片](https://talks.go-zh.org/2012/simple.slide))并阅读[编写 Web 应用](https://tour.go-zh.org/doc/articles/wiki/)的指南。

[函数：Go 中的一等公民](https://tour.go-zh.org/doc/codewalk/functions/)展示了有趣的函数类型。

[Go 博客](https://blog.go-zh.org/)有着众多关于 Go 的文章和信息。

[Go 技术论坛](https://learnku.com/go)有大量关于 Go 的中文文档和 Go 官方博客的翻译。

[mikespook 的博客](https://www.mikespook.com/tag/golang/)中有大量中文的关于 Go 的文章和翻译。

开源电子书 [Go Web 编程](https://github.com/astaxie/build-web-application-with-golang)和 [Go 入门指南](https://github.com/Unknwon/the-way-to-go_ZH_CN)能够帮助你更加深入的了解和学习 Go 语言。

访问 [go-zh.org](https://go-zh.org/) 了解更多内容。



