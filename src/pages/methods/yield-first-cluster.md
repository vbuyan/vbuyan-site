---
layout: ../../layouts/Page.astro
title: Yield-first cluster
kind: Method
date: "2026-11-17"
description: How to run Kubernetes next to production work on the same host, so that when resources run out, the cluster always loses.
---

Most guides assume Kubernetes owns its nodes. Sometimes it cannot: the host already runs production
work, and the cluster is a guest. A guest that can take memory, disk or the GPU away from production at
the wrong moment is worse than no cluster at all. A **yield-first cluster** is designed so that under any
kind of pressure it is the first thing to give resources back.

## The rule

> When the host runs short of anything, the cluster loses first, loses predictably, and comes back by itself.

## Four layers

1. **Hard ceiling.** The whole cluster, control plane included, lives in one cgroup with a memory cap
   (`systemReserved` with `enforceNodeAllocatable: [pods]`). It can never grow past it, no matter what is deployed.
2. **Early eviction.** kubelet evicts pods on low *host* memory, with a soft threshold and a grace period
   followed by a hard one, long before the host itself is in danger.
3. **Kernel-level priority.** systemd-oomd watches the cluster's slice with a stricter pressure limit than
   the host's own services, so under real pressure it kills cluster pods before production jobs.
4. **Absolute disk floors.** Disk eviction thresholds are absolute values sized for the pods, not the
   percentage defaults. On a large shared disk, `nodefs.available: 5%` is far more space than pods need,
   and production keeping the disk nearly full will evict everything. See the
   [eviction storm postmortem](/postmortems/2026-11-15-disk-pressure-eviction-storm/).

## Alerts that make it safe

Yielding silently is a failure of its own. Alert on:

- any node pressure condition (memory, disk, PID) for more than a few minutes;
- evicted pods present in the cluster;
- host available memory, with the cluster's share on the same panel.

## How to check it works

- Run the full stack during the heaviest production job and record the host's lowest available memory.
- Fill the disk past the floor on purpose and watch eviction and alerts happen in the right order.
- Review a week later: if production ever lost memory to the cluster, roll back to on-demand.

## Trade-offs

Cluster workloads get evicted under pressure, so they must be restartable: GitOps controllers and
CronJobs are, long stateful services are not. The cluster also needs its own monitoring off the node,
or it will lose its eyes exactly when it yields.
