---
layout:     post
title:      Go Courese - Web FrameWork 
subtitle:   Gin 介绍与使用
date:       2021-06-18
author:     ethan.luo
header-img: img/post-bg-universe.jpg
catalog: true
tags:
    - go web
    - gin
---

Go 语言有非常的优秀的特性 (比如高并发、原生支持协程、泛型等等), 同时也贡献了非常多项目(可以 https://awesome-go.com/ 一览)，在 Web 开发这块也有非常多优秀的框架，如 Gin、Beego、Iris、Echo、Revel 等.
[Top Go Web Frameworks](https://github.com/mingrammer/go-web-framework-stars)

## Gin
官方介绍
```text
Gin is a web framework written in Go (Golang). It features a martini-like API with performance that is up to 40 times faster thanks to httprouter. If you need performance and good productivity, you will love Gin.
```

## Scaffold (脚手架)
为了快速使用 Gin, 我提供了 [Gin Scaffold](https://github.com/codeandcode0x/gin-scaffold) 程序。
提供如下功能:
- ORM 封装 (使用的 GORM, 对 Model Interface 可进行继承设计, 可方便的封装 DAO 层)
- Tracing (支持链路追踪)
- Http TimeOut (支持 Http 请求超时中断)


## 总结



参考: 
- https://developer.aliyun.com/article/608931






