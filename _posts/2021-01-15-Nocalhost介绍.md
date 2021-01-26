---
layout:     post
title:      Nocalhost 云端开发 by CODING
subtitle:   云端开发已来
date:       2021-01-15
author:     ethan.luo
header-img: img/post-bg-keybord.jpg
catalog: true
tags:
    - Goroutine
    - Context
    - 任务调度
---

### 什么是云原生？

“云原生 Cloud Native”这个概念其实提了好几年了，但是一直没被重视，直到今年终于开始爆发了，几乎所有大厂都在忙着发布云原生的白皮书和路线图，生怕被时代落下。

我真正理解 Cloud Native 是从了解它的反义词开始的。对于不理解的东西尝试去看它的反面往往会豁然开朗。那 Cloud Native 的反面是啥呢？不是 Cloud in-Native 也不是 Non-Cloud Native，而是 Machine Native（这里顺便推荐一本书《反脆弱》，脆弱的反面不是坚强，而是反脆弱，很有意思的观点，值得一读。）。这是一个巨大的概念飞跃。从计算机诞生以来，一直都是有个机器的概念，是一个具象的，物理的机器。云的出现第一次把这个具象打破了，你所依赖的计算资源再也不是一台/多台机器，而是一朵云。不是说把一坨机器放一起就是云。云包含了大量对于硬件的抽象，以及服务能力的抽象，使得上层应用可以完全脱离对于物理硬件的依赖。过去我们写程序的时候，必须要考虑的三大件有“内存，硬盘，CPU”，这也是冯诺依曼架构的核心。 从某种意义上讲，云的出现使得计算机行业变相的突破了冯诺依曼架构，或者说也是应对摩尔定律到头了的解决方案。现在 Cloud Native/云原生的应用，已经完全摆脱了对于三大件的依赖，所有需要的资源都是通过云 API 获取。

![ltm.png](http://codeandcode0x.github.io/img/nocalhost1.png)
（冯诺依曼计算机结构）

最近流行的 Serverless 技术，也是这一理念的延申。这里的最终效果就是往云上扔一个应用，就能顺畅的跑起来，至于怎么调度计算资源，用哪里的计算资源，那是云的事情。正如你把电风扇的插头插到墙上就应该能转，至于这个电怎么来的，电网怎么运行的，风力还是火力，你关心嘛？ 


### 上云三步曲

把云比作电是一个对于美好未来的想象。时代的变迁是个漫长的过程，涉及到对于现有系统的大量改造。我们把 Machine Native 时代的应用叫做传统应用，Cloud Native 时代的应用叫做云应用。传统应用和云应用的差别一点都不比汽油车和电动车的差别小。所以要实现真正的“上云”必须要对传统应用做改造，这是一个巨大的工程，也是巨大的产业机会，我称之为数字化的城中村旧改。这个世界上确实没啥新鲜事，都是换了个模式换了个技术把做过的事情一遍一遍的重复。类似的事情还有从 PC 转向移动互联网的时候，大量的 PC 应用再造了一遍。

现在很多企业喊上云，云厂商也帮着企业上云。十多年云计算的发展，还没有接触过云的企业可以说是绝无仅有。但是到目前为止绝大部分企业完成的只是上云 1.0，也就是把传统应用搬到了云上。对于企业来讲，这样的上云相当于把云厂商当成了高级的 IDC 机房。这当然是不能体现云最终价值的。

于是云原生概念出现了，你不光要上云还得云原生，这叫上云 2.0。也就是把传统应用改造成云应用。这里涉及到的点大概有，把应用拆成微服务，容器化，数据库也别自己装 MySQL 了，直接用云数据库，还有其他比如缓存，监控，日志啥的，云统统给你搞定，你管好应用的业务逻辑就好了。改造完了以后你会发现，这个应用大量依赖云的能力，从某种意义上讲你的应用再也不能在你自己的机器上跑起来了。所以我给云原生下了一个定义“离开云活不了，叫做云原生”。这个时代早晚要来的，我们现在离开了电也活不了。

![ltm.png](http://codeandcode0x.github.io/img/nocalhost2.png)
 （云原生架构）

当你的应用云原生以后，你会发现另外一个问题，开发这些应用变得非常困难，因为你的开发工具都是为开发传统应用准备的，为了开发云应用，你必须调整自己的开发工具和开发方式。这里就需要上云三步曲的最后一步，开发云原生，也就是上云 3.0。

有时候想想云厂商也挺坏的，一步一步的让客户上套，美其名曰推动时代发展，数字化新基建。


### Nocalhost

我们公司一直是坚定的云计算实践者，有啥新东西就用啥。我们大概在一年前就已经基本完成了上云 2.0，但随之而来很多开发的问题：

开发没有办法拥有自己的开发环境，无法在自己的机器上跑起来整个 CODING，150 个微服务。
共享的测试环境经常被搞坏，更新维护困难。
开发测试环境无法使用云的 PaaS 服务（云数据库，缓存等等）跟生产环境不一致。
每次我跟新同事交流的时候，都会提到开发环境的问题，效率低下。这使得我不得不深入调查这里的问题根源在哪里。2020 年上半年我们也找了不少已经深入使用微服务和容器的团队交流，大家普遍都会遇到上面的问题，通常的解决方案是搭建共享的开发测试环境，但这是一个治标不治本的 workaround。这里的本质问题就是云应用和传统应用的架构差别，导致开发工具和开发方式必须做出改变。国外也有一些项目在尝试解决这个问题，但这确实是一个新领域。

云给我们带来便利的时候，也给我们带来了各种开发的不便。有时候怀念，做一个单机应用是多么的纯粹，多么的简单快乐。我想写过程序的都会熟悉下面的画面：

![ltm.png](http://codeandcode0x.github.io/img/nocalhost3.png)

在笔记本上装一个 LAMP，然后就跑起来了。调试的时候改完代码，保存，刷新页面就能看到效果，行云流水。而现在云原生的体系结构使得开发的调试变得非常困难，你改个代码要等 10 分钟才能看到效果，甚至更长时间，这种感受堪比打王者荣耀的时候卡顿，想把手机砸了。这个时候开发往往会去泡杯咖啡，被迫摸鱼……

我们产品团队在调研了各种技术以后，认为有可能做一个产品解决云原生开发的问题，使得云应用的开发体验接近传统应用的开发体验。以前看 Localhost 感觉它就是个代号，最近研究云才越来越觉得这个名字的深切含义，甚至感到一丝惭愧，相见恨晚。这个词的表述也很达意：“Local”“Host”——本地的机器。然而在云原生时代，开发环境搬到了云上，从某种意义上讲 local 没有 host 了，或者说没有 local 了，这个机制也就不再能解决开发的问题。那 localhost 的反面是啥，no localhost ？合并一下取名 Nocalhost（https://nocalhost.dev）。

![ltm.png](http://codeandcode0x.github.io/img/nocalhost4.png)

Localhost 是一个很伟大的发明，它使得开发者不需要网络环境就能完成网络应用的开发，极大的提高了开发调试的反馈循环。但历史的车轮滚滚向前，一代代技术推陈出新，曾经的辉煌都会被写入历史。

再见，localhost！


### Nocalhost 使用介绍 (https://nocalhost.dev)

Before start
Prerequisites:

A Kubernetes(1.16+) Cluster(prefer to be provided by the Cloud platform or Minikube, 2 Core 4 Gi memory)
Configure kubectl for you to be able to access above cluster as admin
RBAC must be enabled in above cluster
Install Helm3
Install Visual Studio Code(1.52+)
Install Git
Kubernetes api-server can be accessed internal and external

### Step 1: Install nhctl and VSCode extension
Reference link: https://nocalhost.dev/installation/

### Step 2: Initialize the cluster and setup Nocalhost Server
Option 1: Kubernetes provided by the Cloud platform, such as Tencent TKE
For TKE clusters, configure open external network access: 0.0.0.0/0 or cluster egress IP to achieve access to the Kubernetes api-server internal and external.

Initialize at terminal:


nhctl init -n nocalhost -p 7000
Option 2: If you use a Kubernetes cluster such as minikube, kind, k3s, microk8s, etc., use the following command to initialize:

nhctl init -n nocalhost -t nodeport
About Kubernetes without LoadBalancer and PV

Use NodePort instead of LoadBalancer, close DB persistence(DO NOT USE FOR PRODUCTION)


nhctl init -n nocalhost -t nodeport -p 7000 --force --set mariadb.primary.persistence.enabled=false
Waiting for the initialization process:

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/1.png)


After the initialization:

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/2.png)

MINIKUBE WARN: Please do not close above terminal for the port to be able to keep forwarding

nhctl init command flags

--namespace: to specify which namespace to install.(create automately)
--port: to specify which port Nocalhost Web to listen.(Default 80)
--set: to overide values for Nocalhost's Helm Chart
--type: to specify service type of Nocalhost Web(nodeport or loadbalaner)
--force: to specify if delete old data before initialization


### Step 3: Configure and login Nocalhost Server in VSCode
Open the VSCode extension page, click on the “Config Server URL” button at left:

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/3.png)

Input the access address from Step Two, press Enter to save Input the username and password respectively, press Enter to save:

Username: foo@nocalhost.dev
Password: 123456
After login, you can find:

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/4.png)

### Step 4: Install demo application: bookinfo
Click the installation icon at the left to install application bookinfo

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/5.png)

After it, Nocalhost starts to execute the installation.

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/6.png)

You can click on the refresh icon to check the status of installation and startup process

After all microservices startup, you will find

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/7.png)

Now, you can visit the appliction website:

http://127.0.0.1:39080/productpage

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/8.png)

### Step 5: Start DevMode
Switch the service to the DevMode by clicking on the green hammer icon.

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/9.png)

Select “Clone from Git repo” and specify a local address for Nocalhost to clone the source code.

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/10.png)

After the source code is checked out, Nocalhost will open a new VSCode window, and continue to switch to the DevMode.

When it is completed (it will take long time when it is the first time to run it), you will find:

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/11.png)

Under the DevMode, the main process will not startup by default for the DevContainer, and therefore it will not respond the request from the website. While refresh the webpage, the webpage will be on error and will be recovered, until you start up again.

You can execute sh run.sh to start your process.

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/12.png)

### Step 6: Change the code and check the result
You can try to change a piece of code, refresh and check the result. For example: add "Hello Nocalhost!" at line 355 in the file productpage.py. Do not forget to save the file. 😎

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/13.png)

Refresh the webpage, here is the outcome: http://127.0.0.1:39080/productpage 😄

![ltm.png](http://codeandcode0x.github.io/img/nocalhost/14.png)

Congratulations!
You have had a great experience about the Cloud Native development through above Nocalhost simple tutorial. You can start to try to configure and use the Nocalhost in the real project now.

Any feedback is welcomed. Github Issues: https://github.com/nocalhost/nocalhost
