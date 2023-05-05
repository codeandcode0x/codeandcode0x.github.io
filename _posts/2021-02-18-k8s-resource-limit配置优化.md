---
layout:     post
title:      K8s Resource Limit 配置优化
subtitle:   资源配置
date:       2021-02-18
author:     ethan.luo
header-img: img/blogs/yuzhou.jpg
catalog: true
tags:
    - k8s
    - resource
---

在 5000+ 的 pod 集群里，配置合理的 resource request 和 limit 非常重要。这里会聊到资源限制、QoS、ResourceQuota、LimitRange 等的使用。在容器数量众多的集群中，如何使用这些能做到将合适的资源分配给pod容器使用，既要保证充分利用资源，提高资源利用率，又要保证重要容器在运行周期内能够分配到足够的资源稳定运行。

## Resource request & limit
在 deployment 中定义 resource 中有两个基础指标：CPU 和 内存。 k8s 采用requests和limits 两种类型参数对资源进行预分配和使用限制：
- 当容器内存超过limit时，会被 OOM Killed。
- 当容器 cpu 超过limit时，不会被 Kill，但是会限制不超过 Limit 值。

### 合理设置 request 和 limit

- Pod 请求多少资源，就用多少资源，但在现实场景下，资源使用是不断变化的 。

- 如果 Pod 的资源使用量远低于请求量，那会导致资源（金钱）浪费；如果资源使用量高于请求量，那就会使节点出现性能问题。因此在实际操作中，我们可以把 Request 值上下浮动 25％ 作为一个良性参考标准。

- 而关于 Limit，设置合理的 Limit 数值其实需要尝试，因为它主要取决于应用程序的性质、需求模型、对错误的容忍度以及许多其他因素，没有固定答案。


## 容器服务质量（QoS）
Kubernetes 提供服务质量管理，根据容器的资源配置，将pod 分为Guaranteed, Burstable, BestEffort 3个级别。当资源紧张时根据分级决定调度和驱逐策略，这三个分级分别代表：

- Guaranteed: pod中所有容器都设置了limit和request， 并且相等（设置limit后假如没有设置request会自动设置为limit值）
- Burstable: pod中有容器未设置limit，或者limit和request不相等。这种类型的pod在调度节点时，可能出现节点超频的情况。
- BestEffort: pod中没有任何容器设置request和limit。



Kubernetes QoS 代码:

```go

func GetPodQOS(pod *core.Pod) core.PodQOSClass {
	requests := core.ResourceList{}
	limits := core.ResourceList{}
	zeroQuantity := resource.MustParse("0")
	isGuaranteed := true
	allContainers := []core.Container{}
	allContainers = append(allContainers, pod.Spec.Containers...)
	allContainers = append(allContainers, pod.Spec.InitContainers...)
	for _, container := range allContainers {
		// process requests
		for name, quantity := range container.Resources.Requests {
			if !isSupportedQoSComputeResource(name) {
				continue
			}
			if quantity.Cmp(zeroQuantity) == 1 {
				delta := quantity.DeepCopy()
				if _, exists := requests[name]; !exists {
					requests[name] = delta
				} else {
					delta.Add(requests[name])
					requests[name] = delta
				}
			}
		}
		// process limits
		qosLimitsFound := sets.NewString()
		for name, quantity := range container.Resources.Limits {
			if !isSupportedQoSComputeResource(name) {
				continue
			}
			if quantity.Cmp(zeroQuantity) == 1 {
				qosLimitsFound.Insert(string(name))
				delta := quantity.DeepCopy()
				if _, exists := limits[name]; !exists {
					limits[name] = delta
				} else {
					delta.Add(limits[name])
					limits[name] = delta
				}
			}
		}

		if !qosLimitsFound.HasAll(string(core.ResourceMemory), string(core.ResourceCPU)) {
			isGuaranteed = false
		}
	}
	if len(requests) == 0 && len(limits) == 0 {
		return core.PodQOSBestEffort
	}
	// Check is requests match limits for all resources.
	if isGuaranteed {
		for name, req := range requests {
			if lim, exists := limits[name]; !exists || lim.Cmp(req) != 0 {
				isGuaranteed = false
				break
			}
		}
	}
	if isGuaranteed &&
		len(requests) == len(limits) {
		return core.PodQOSGuaranteed
	}
	return core.PodQOSBurstable
}

```

### QoS对容器影响

#### OOM

Kubernetes会根据QoS设置oom的评分调整参数oom_score_adj，oom_killer 根据 内存使用情况算出oom_score， 并且和oom_score_adj综合评价，进程的评分越高，当发生oom时越优先被kill。

QoS	oom_score_adj
Guaranteed	-998
BestEffort	1000
Burstable	min(max(2, 1000 - (1000 * memoryRequestBytes) / machineMemoryCapacityBytes), 999)
当节点内存不足时，QoS为Guaranteed 的pod 最后被kill。 而BestEffort 级别的pod优先被kill。 其次是Burstable，根据计算公式 oom_score_adj 值范围2到999，设置的request越大，oom_score_adj越低，oom时保护程度越高。

oom_score 计算代码:

```go

const (
	// KubeletOOMScoreAdj is the OOM score adjustment for Kubelet
	KubeletOOMScoreAdj int = -999
	// KubeProxyOOMScoreAdj is the OOM score adjustment for kube-proxy
	KubeProxyOOMScoreAdj  int = -999
	guaranteedOOMScoreAdj int = -997
	besteffortOOMScoreAdj int = 1000
)

// GetContainerOOMScoreAdjust returns the amount by which the OOM score of all processes in the
// container should be adjusted.
// The OOM score of a process is the percentage of memory it consumes
// multiplied by 10 (barring exceptional cases) + a configurable quantity which is between -1000
// and 1000. Containers with higher OOM scores are killed if the system runs out of memory.
// See https://lwn.net/Articles/391222/ for more information.
func GetContainerOOMScoreAdjust(pod *v1.Pod, container *v1.Container, memoryCapacity int64) int {
	if types.IsCriticalPod(pod) {
		// Critical pods should be the last to get killed.
		return guaranteedOOMScoreAdj
	}

	switch v1qos.GetPodQOS(pod) {
	case v1.PodQOSGuaranteed:
		// Guaranteed containers should be the last to get killed.
		return guaranteedOOMScoreAdj
	case v1.PodQOSBestEffort:
		return besteffortOOMScoreAdj
	}

	// Burstable containers are a middle tier, between Guaranteed and Best-Effort. Ideally,
	// we want to protect Burstable containers that consume less memory than requested.
	// The formula below is a heuristic. A container requesting for 10% of a system's
	// memory will have an OOM score adjust of 900. If a process in container Y
	// uses over 10% of memory, its OOM score will be 1000. The idea is that containers
	// which use more than their request will have an OOM score of 1000 and will be prime
	// targets for OOM kills.
	// Note that this is a heuristic, it won't work if a container has many small processes.
	memoryRequest := container.Resources.Requests.Memory().Value()
	oomScoreAdjust := 1000 - (1000*memoryRequest)/memoryCapacity
	// A guaranteed pod using 100% of memory can have an OOM score of 10. Ensure
	// that burstable pods have a higher OOM score adjustment.
	if int(oomScoreAdjust) < (1000 + guaranteedOOMScoreAdj) {
		return (1000 + guaranteedOOMScoreAdj)
	}
	// Give burstable pods a higher chance of survival over besteffort pods.
	if int(oomScoreAdjust) == besteffortOOMScoreAdj {
		return int(oomScoreAdjust - 1)
	}
	return int(oomScoreAdjust)
}

```

#### Pod 驱逐

当节点的内存和cpu资源不足，开始驱逐节点上的pod时。QoS同样会影响驱逐的优先级。顺序如下：

- 1. kubelet 优先驱逐 BestEffort 的 pod 和实际占用资源大于 requests 的 Burstable pod。

- 2. 接下来驱逐实际占用资源小于 request 的 Burstable pod。

- 3. QoS 为 Guaranteed 的 pod 最后驱逐, kubelet 会保证 Guaranteed 的 pod 不会因为其他 pod 的资源消耗而被驱逐。
当QoS相同时，kubelet 根据 Priority 计算驱逐的优先级

## ResourceQuota & LimitRange

1. ResourceQuota: 资源配额，通过 ResourceQuota 对象来定义，对每个命名空间的资源消耗总量提供限制。 它可以限制命名空间中某种类型的对象的总数目上限，也可以限制命令空间中的 Pod 可以使用的计算资源的总上限。

2. LimitRange: 可以在 LimitRange 对象中指定最小和最大内存值。如果 Pod 不满足 LimitRange 施加的约束，则无法在命名空间中创建它。LimitRange 为命名空间设定的最小和最大内存限制只有在 Pod 创建和更新时才会强制执行。 如果你更新 LimitRange，它不会影响此前创建的 Pod。

做为集群管理员，你可能想规定 Pod 可以使用的内存总量限制。例如：

集群的每个节点有 2 GB 内存。你不想接受任何请求超过 2 GB 的 Pod，因为集群中没有节点可以满足。
集群由生产部门和开发部门共享。你希望允许产品部门的负载最多耗用 8 GB 内存， 但是开发部门的负载最多可使用 512 MiB。 这时，你可以为产品部门和开发部门分别创建名字空间，并为各个名字空间设置内存约束。


```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: mem-limit-range
  namespace: example
spec:
  limits:
  - default:  # default limit
      memory: 1Gi
      cpu: 2
    defaultRequest:  # default request
      memory: 512Mi
      cpu: 0.5
    max:  # max limit
      memory: 2Gi
      cpu: 4
    min:  # min request
      memory: 200Mi
      cpu: 200m
    maxLimitRequestRatio:  # max value for limit / request
      memory: 3
      cpu: 2
    type: Container # limit type, support: Container / Pod / PersistentVolumeClaim
```

limitRange支持的参数如下：

- default 代表默认的limit
- defaultRequest 代表默认的request
- max 代表limit的最大值
- min 代表request的最小值
- maxLimitRequestRatio 代表 limit / request的最大值。由于节点是根据pod request 调度资源，可以做到节点超卖，maxLimitRequestRatio 代表pod最大超卖比例。

## 总结

- Kubernetes 提供request 和 limit 两种方式设置容器资源。

- 为了提高资源利用率，k8s调度时根据pod 的request值计算调度策略，从而实现节点资源超卖。

- k8s根据limit限制pod使用资源，当内存超过limit时会触发oom。 且限制pod的cpu 不允许超过limit。

- 根据pod的 request和limit，k8s会为pod 计算服务质量，并分为Guaranteed, Burstable, BestEffort 这3级。当节点资源不足时，发生驱逐或者oom时， Guaranteed 级别的pod 优先保护， Burstable 节点次之（request越大，使用资源量越少 保护级别越高）， BestEffort 最先被驱逐。

- Kubernetes提供了RequestQuota和LimitRange 用于设置namespace 内pod 的资源范围 和 规模总量。 RequestQuota 用于设置各种类型对象的数量， cpu和内存的总量。 LimitRange 用于设置pod或者容器 request和limit 的默认值，最大最小值， 以及超卖比例（limit / request）。

- 对于一些重要的线上应用，我们应该合理设置limit和request，limit和request 设置一致，资源不足时k8s会优先保证这些pod正常运行。

- 为了提高资源利用率。 对一些非核心，并且资源不长期占用的应用，可以适当减少pod的request，这样pod在调度时可以被分配到资源不是十分充裕的节点，提高使用率。但是当节点的资源不足时，也会优先被驱逐或被oom kill。


参考: 
- https://developer.aliyun.com/article/608931
- https://kubernetes.io/zh/docs/concepts/policy/resource-quotas/
- https://kubernetes.io/zh/docs/tasks/administer-cluster/manage-resources/memory-constraint-namespace/






