---
layout:     post
title:      深入解析 Go Context 与 协程
subtitle:   使用 Go Context 和通道做任务管理
date:       2020-11-15
author:     ethan.luo
header-img: img/post-bg-map.jpg
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

```
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

	go doTask(vCtx, "worker1")
	go doTask(vCtx, "worker2")

	time.Sleep(3 * time.Second)
	cancel()
	time.Sleep(3 * time.Second)
}
```

- context.WithValue() 创建了一个基于 ctx 的子 Context，并携带了值 options。
- 在子协程中，使用 ctx.Value("options") 获取到传递的值，读取/修改该值。

## context.WithTimeout
如果需要控制子协程的执行时间，可以使用 context.WithTimeout 创建具有超时通知机制的 Context 对象。

```
func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	go doTask(ctx, "worker1")
	go doTask(ctx, "worker2")

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

```
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
	go doTask(ctx, "worker1")
	go doTask(ctx, "worker2")

	time.Sleep(3 * time.Second)
	fmt.Println("before cancel")
	cancel()
	time.Sleep(3 * time.Second)
}

```

- WithDeadline 用于设置截止时间。在这个例子中，将截止时间设置为1s后，cancel() 函数在 3s 后调用，因此子协程将在调用 cancel() 函数前结束。
- 在子协程中，可以通过 ctx.Err() 获取到子协程退出的错误原因。

可以看到，子协程 worker1 和 worker2 均是因为截止时间到了而退出。


## chan + Context 设计任务调度



## 结束语



### 参考

- [WWDC 2018 Keynote](https://developer.apple.com/videos/play/wwdc2018/101/)
- [Apple WWDC 2018: what's new? All the announcements from the keynote](https://www.techradar.com/news/apple-wwdc-2018-keynote)
- [iOS 加入「防沉迷」，macOS 有了暗色主题，今年的 WWDC 重点都在系统上](http://www.ifanr.com/1043270)
- [苹果 WWDC 2018：最全总结看这里，不错过任何重点](https://sspai.com/post/44816)
 

