---
layout:     post
title:      深入解析 Go Context 与 协程
subtitle:   使用 Go Context 和通道做任务管理
date:       2020-11-15
author:     ethan.luo
header-img: img/post-bg-universe.jpg
catalog: true
tags:
    - Goroutine
    - Context
    - 任务调度
---

## 前言
Go 语言提供了 Context 标准库是为了解决复杂的并发场景下，对协程有更好的控制。Context 的作用和它的名字很像，上下文，即子协程的下上文。Context 有两个主要的功能:

- **通知子协程退出**（正常退出，超时退出等）;
- **传递必要的参数** ;


## Context

## context.WithCancel

context.WithCancel() 创建可取消的 Context 对象，即可以主动通知子协程退出。
使用 Context 改写上述的例子，效果与 select+chan 相同。

```go
func doTask(ctx context.Context, job string) {
	for {
		select {
		case <-ctx.Done():
			fmt.Println("stop", job)
			return
		default:
			fmt.Println(job, "send request")
			time.Sleep(1 * time.Second)
		}
	}
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	go doTask(ctx, "task1")
	time.Sleep(2 * time.Second)
	cancel()
}
```

- context.Backgroud() 创建根 Context，通常在 main 函数、初始化和测试代码中创建，作为顶层 Context。
- context.WithCancel(parent) 创建可取消的子 Context，同时返回函数 cancel。
- 在子协程中，使用 select 调用 <-ctx.Done() 判断是否需要退出。
- 主协程中，调用 cancel() 函数通知子协程退出。

## context.WithValue
如果需要往子协程中传递参数，可以使用 context.WithValue()。

```go
type Options struct{ Interval time.Duration }

func doTask(ctx context.Context, name string) {
	for {
		select {
		case <-ctx.Done():
			fmt.Println("stop", name)
			return
		default:
			fmt.Println(name, "send request")
			op := ctx.Value("options").(*Options)
			time.Sleep(op.Interval * time.Second)
		}
	}
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	vCtx := context.WithValue(ctx, "options", &Options{1})

	go doTask(vCtx, "task1")
	go doTask(vCtx, "task2")

	time.Sleep(3 * time.Second)
	cancel()
	time.Sleep(3 * time.Second)
}
```

- context.WithValue() 创建了一个基于 ctx 的子 Context，并携带了值 options。
- 在子协程中，使用 ctx.Value("options") 获取到传递的值，读取/修改该值。

## context.WithTimeout
如果需要控制子协程的执行时间，可以使用 context.WithTimeout 创建具有超时通知机制的 Context 对象。

```go
func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	go doTask(ctx, "task1")
	go doTask(ctx, "task2")

	time.Sleep(3 * time.Second)
	fmt.Println("before cancel")
	cancel()
	time.Sleep(3 * time.Second)
}

```

WithTimeout()的使用与 WithCancel() 类似，多了一个参数，用于设置超时时间。

因为超时时间设置为 2s，但是 main 函数中，3s 后才会调用 cancel()，因此，在调用 cancel() 函数前，子协程因为超时已经退出了。

## context.WithDeadline

超时退出可以控制子协程的最长执行时间，那 context.WithDeadline() 则可以控制子协程的最迟退出时间。

```go
func doTask(ctx context.Context, name string) {
	for {
		select {
		case <-ctx.Done():
			fmt.Println("stop", name, ctx.Err())
			return
		default:
			fmt.Println(name, "send request")
			time.Sleep(1 * time.Second)
		}
	}
}

func main() {
	ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(1*time.Second))
	go doTask(ctx, "task1")
	go doTask(ctx, "task2")

	time.Sleep(3 * time.Second)
	fmt.Println("before cancel")
	cancel()
	time.Sleep(3 * time.Second)
}

```

- WithDeadline 用于设置截止时间。在这个例子中，将截止时间设置为1s后，cancel() 函数在 3s 后调用，因此子协程将在调用 cancel() 函数前结束。
- 在子协程中，可以通过 ctx.Err() 获取到子协程退出的错误原因。

可以看到，子协程 task1 和 task2 均是因为截止时间到了而退出。


## 通道

我们先看 chan 的实例

```go

//chan 同步通道 (无缓存通道)
func ChanNoCache() {
	ch := make(chan int, 0)

	go func() {
		var sum int = 0
		for i :=0; i<10; i++ {
			sum = sum + i
		}
		ch <- sum
	}()
	//在计算sum和的goroutine没有执行完，把值赋给ch通道之前，
	//fmt.Println(<-ch)会一直等待
	log.Println(<-ch)

}

//chan 通道 (有缓存)
func ChanWithCache()  string {
	response := make(chan string, 3)

	go func() { response <- http.Request("https://godoc.org/google.golang.org/grpc") }()
	go func() { response <- http.Request("https://godoc.org/debug/gosym") }()
	go func() { response <- http.Request("https://godoc.org/context") }()

	//输出所有数据
	for i:=0 ; i< cap(response); i++ {
		log.Println(<-response)
		log.Println("----------", i)
	}

	//返回最快的获取到数据
	return <- response
}

//pipeline 管道
func Pipeline() {
	begin := make(chan int, 0)
	end := make(chan int, 0)

	go func() {
		begin <- 10
	}()


	go func() {
		num := <- begin
		end <- num
	}()

	log.Println(<-end)

}


```

- 通道 (同步和缓存)
- 管道 (生产者和消费者)

在多个goroutine并发中，我们不仅可以通过原子函数和互斥锁保证对共享资源的安全访问，消除竞争的状态，还可以通过使用通道，在多个goroutine发送和接受共享的数据，达到数据同步的目的。

通道，他有点像在两个routine之间架设的管道，一个goroutine可以往这个管道里塞数据，另外一个可以从这个管道里取数据，有点类似于我们说的队列。

通道类型和Map这些类型一样，可以使用内置的make函数声明初始化，这里我们初始化了一个chan int类型的通道，所以我们只能往这个通道里发送int类型的数据，当然接收也只能是int类型的数据。

管道: 把上一个操作的输出，当成下一个操作的输入，连起来，做一连串的处理操作。我们把一个通道的输出，当成下一个通道的输入也能达到管道的效果 。

## 通道 + Context 设计任务调度

```
package main

import (
	"context"
	"strconv"
	"fmt"
)


func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	i := 0
	for {
		generateJob(ctx, "itask" + strconv.Itoa(i))
		i++
		if i> 10000 {
			break
		}
	}
}

//生成 job
func generateJob(parent context.Context, value string) {
	ch := make(chan int, 0)
	ctx, cancel := context.WithCancel(parent)
	go doTask(ch, ctx, value)
	<-ch
	cancel()
}


//执行任务
func doTask(ch chan<- int, ctx context.Context, job string) {
	select {
	case <-ctx.Done():
		fmt.Println("job is closed", job)
		return
	default:
		fmt.Println(job, "is running")
		ch <- 1
	}
}


```

- 用通道来控制协程执行的状态 "ch <- 1", 当 <-ch 接受完传值后任务即结束 ;
- 这里用了 context.Background() 作为父会话, 然后在子协程中调用 cancel() 结束; 


## 结束语



### 参考
- [godoc](https://godoc.org/context#example-WithValue)


